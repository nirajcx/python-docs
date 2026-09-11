# LLM Inference Mechanics: PagedAttention, KV Cache Math, vLLM & PEFT/LoRA

> **Target Audience:** FAANG / Tier-1 AI Infrastructure & GenAI Engineers  
> **Evaluation Focus:** Prefill vs Decode, Memory Bandwidth Bottlenecks, PagedAttention Virtual Paging, Continuous Batching, Quantization  
> **Cross-References:** [10-llm-integration.md](./10-llm-integration.md) | [21-memory-optimization-and-leaks.md](../01-python-core/21-memory-optimization-and-leaks.md) | [25-genai-security-and-guardrails.md](./25-genai-security-and-guardrails.md)

---

## 1. LLM Inference Mechanics: Prefill vs. Decode Phases

Autoregressive transformer inference consists of two fundamentally distinct operational phases with opposite hardware bottlenecks:

```
                            Prefill Phase vs. Decode Phase
                            
           PREFILL PHASE (Prompt Processing)             DECODE PHASE (Token Generation)
          ┌──────────────────────────────────┐          ┌──────────────────────────────────┐
Operation │ Processes ALL input tokens       │          │ Generates ONE token at a time    │
          │ in parallel (T1, T2, T3 ... TN)  │          │ autoregressively: Tn -> Tn+1     │
          ├──────────────────────────────────┤          ├──────────────────────────────────┤
Hardware  │ COMPUTE-BOUND (GEMM)             │          │ MEMORY-BANDWIDTH BOUND (GEMV)    │
Bottleneck│ High Arithmetic Intensity        │          │ Low Arithmetic Intensity         │
          │ Saturated GPU Tensor Cores       │          │ Saturated HBM Memory Bus         │
          ├──────────────────────────────────┤          ├──────────────────────────────────┤
Metric    │ Time-To-First-Token (TTFT)       │          │ Inter-Token Latency (ITL) /      │
          │ Measured in milliseconds         │          │ Tokens-Per-Second (TPS)          │
          └──────────────────────────────────┘          └──────────────────────────────────┘
```

### Why Decode is Memory-Bandwidth Bound
In the decode phase, predicting a single token requires streaming **the entire model weight tensor** from GPU High Bandwidth Memory (HBM) into SRAM cache to multiply with a single vector.  
- A 70B model in `fp16` (140 GB weights) on an NVIDIA A100 (2.0 TB/s memory bandwidth):
  $$\text{Theoretical Max Single-Stream Speed} = \frac{2,000\text{ GB/s}}{140\text{ GB}} \approx 14.3\text{ tokens/sec}$$
Tensor cores sit idle $>90\%$ of the time waiting for weights to travel across the memory bus!  
**The Solution:** **Batching**. Processing 64 requests simultaneously reads the weights once and multiplies them against 64 vectors, converting memory-bound GEMV into compute-bound GEMM.

---

## 2. KV Cache Internals & Exact Mathematical Sizing

In the attention mechanism, calculating attention scores requires Query ($\mathbf{Q}$), Key ($\mathbf{K}$), and Value ($\mathbf{V}$) matrices:
$$\text{Attention}(\mathbf{Q}, \mathbf{K}, \mathbf{V}) = \text{softmax}\left(\frac{\mathbf{Q} \mathbf{K}^T}{\sqrt{d_k}}\right) \mathbf{V}$$

To avoid recomputing $\mathbf{K}$ and $\mathbf{V}$ for all preceding tokens on every single generation step ($O(N^2)$ waste), past Key and Value tensors are saved in GPU RAM as the **KV Cache**.

### Exact KV Cache Sizing Formula
For a transformer model:
$$\text{KV Bytes per Token} = 2 \times n_{\text{layers}} \times n_{\text{kv\_heads}} \times d_{\text{head}} \times b_{\text{precision}}$$
Where:
- $2$: Accounts for both Key and Value vectors.
- $n_{\text{layers}}$: Number of transformer layers.
- $n_{\text{kv\_heads}}$: Number of Key-Value attention heads.
- $d_{\text{head}}$: Dimension per head ($\text{hidden\_dim} / n_{\text{heads}}$).
- $b_{\text{precision}}$: Bytes per float (2 for `fp16`/`bf16`, 1 for `fp8`, 0.5 for `int4`).

### Real-World Example: Llama-3-70B (Grouped-Query Attention)
- Layers: $80$
- Hidden Dimension: $8,192$
- Query Heads: $64$, **KV Heads ($n_{\text{kv\_heads}}$)**: $8$ (GQA: 8 query heads share 1 KV head)
- Head Dimension: $8,192 / 64 = 128$
- Precision: 16-bit (`bf16` = 2 bytes)

$$\text{KV Bytes per Token} = 2 \times 80 \times 8 \times 128 \times 2 = 327,680\text{ bytes} \approx 320\text{ KB/token}$$

Across a production workload of **64 concurrent requests** with an average context length of **4,096 tokens**:
$$\text{Total KV Cache} = 64 \times 4096 \times 320\text{ KB} \approx \mathbf{83.88\text{ GB of VRAM!}}$$
*Takeaway:* The KV Cache consumes **more VRAM than the model weights themselves** under high concurrency!

---

## 3. PagedAttention & vLLM: Eliminating Memory Fragmentation

### The Legacy Memory Crisis (Naive Static Allocation)
Prior to vLLM, inference engines (HuggingFace, older TensorRT) pre-allocated contiguous GPU memory buffers based on the **maximum possible request length** (e.g. 4,096 tokens):
- **Internal Fragmentation**: If a request finishes at token 200, the remaining 3,896 pre-allocated token slots sit completely empty, locked, and unusable.
- **External Fragmentation**: Memory allocations of varying sizes create fragmented holes, causing Out-Of-Memory crashes even when 40% of GPU RAM is physically free.
- **Result:** **60–80% of GPU VRAM was wasted.**

```
       Naive Contiguous Allocation (Wastes 60-80% VRAM)
 [Prompt 1: 50 tokens] [ RESERVED BUT UNUSED: 4,046 TOKENS (LOCKED!)        ]
 [Prompt 2: 120 tokens][ RESERVED BUT UNUSED: 3,976 TOKENS (LOCKED!)        ]
 
       PagedAttention (vLLM): Virtual Memory Paging (Near 0% Waste)
 Logical KV Blocks (Request Scope)         Physical KV Blocks (GPU HBM)
 [Block 0] ──► Page Table Lookup ────────► [Physical Frame 42 (16 tokens)]
 [Block 1] ──► Page Table Lookup ────────► [Physical Frame 108 (16 tokens)]
 [Block 2] ──► Page Table Lookup ────────► [Physical Frame 15 (16 tokens)]
```

### PagedAttention Architecture:
1. Inspired by OS Virtual Memory paging.
2. Partitions the KV cache into fixed-size **Physical Blocks** (typically holding 16 or 32 tokens).
3. Blocks are allocated dynamically on-demand as new tokens are generated. They do **not** need to be physically contiguous in GPU RAM.
4. Uses a **Block Table** to map logical sequence blocks to non-contiguous physical GPU frames.
5. **Memory Sharing via Copy-on-Write (CoW)**:
   - In **Parallel Sampling** (generating 5 answers for 1 prompt) or **Beam Search**, all 5 streams point to the exact same physical prompt KV blocks! Blocks are only duplicated when generation diverges, cutting memory by another **$55\%$**.

---

## 4. Continuous Batching vs. Static Batching

- **Static Batching**: Waits for $N$ requests to arrive, batches them together, runs inference, and waits until the *longest request* in the batch finishes. Short requests that finish early sit idle, wasting compute.
- **Continuous Batching (Iteration-Level Scheduling - Orca / vLLM)**:
  - Operates at the **iteration / token level** rather than the request level.
  - At every generation step, requests that finished are immediately evicted, and newly arrived requests from the queue are slotted into the batch dynamically for their prefill phase.
  - Increases throughput by **$2\text{--}4\times$**.

---

## 5. Speculative Decoding & Quantization (AWQ, GPTQ, FP8)

### Speculative Decoding
Solves the memory-bandwidth bottleneck of large models:
1. A tiny **Draft Model** (e.g. Llama-3-1B) generates $K$ candidate tokens quickly (low latency).
2. The large **Target Model** (e.g. Llama-3-70B) runs a **single parallel forward pass** over all $K$ tokens simultaneously (compute-bound prefill efficiency).
3. If the target model accepts 4 out of 5 tokens, you achieved **$4\times$ higher throughput** with zero quality loss!

### Modern Quantization Landscape
| Format | Quantized Target | Technique | Quality Impact | Best Used For |
|---|---|---|---|---|
| **AWQ** (Activation-Aware) | Weights only (`int4`) | Protects top 1% salient weight channels based on activations | Near zero perplexity loss | Real-time serving in vLLM / SGLang |
| **GPTQ** | Weights only (`int4`) | Second-order Taylor series error compensation | Minimal loss | Offline batch inference |
| **FP8** (NVIDIA Ada / Hopper) | Weights + Activations (`e4m3` / `e5m2`) | Native hardware floating-point 8-bit Tensor Cores | Zero loss | H100 / L40S production deployments ($2\times$ speedup) |
| **GGUF** (llama.cpp) | Mixed precision k-quants | Quantizes model into CPU/Apple Metal portable files | Low-to-moderate | Local edge / Ollama deployment |

---

## 6. Fine-Tuning: LoRA, QLoRA & Alignment (SFT vs. DPO)

### LoRA (Low-Rank Adaptation) Mathematical Foundation
Traditional fine-tuning updates all $N$ billion model weights: $W = W_0 + \Delta W$.  
LoRA hypothesizes that the weight update $\Delta W$ has a **low intrinsic rank** $r \ll d$:
$$\Delta W = B \cdot A$$
Where $W_0 \in \mathbb{R}^{d \times k}$, $B \in \mathbb{R}^{d \times r}$, and $A \in \mathbb{R}^{r \times k}$ (with $r \in [8, 64]$).
- $A$ is initialized with a Gaussian distribution; $B$ is initialized to $0$ (so $\Delta W = 0$ at step 0).
- Scales by constant: $\Delta W \times \frac{\alpha}{r}$.
- Reduces trainable parameters by **$>99\%$** (e.g. from 70B parameters down to 50M parameters), enabling fine-tuning on consumer GPUs.

### SFT vs. RLHF vs. DPO Alignment
- **SFT (Supervised Fine-Tuning)**: Trains model on high-quality `(Prompt, Ideal Response)` pairs using standard cross-entropy loss.
- **RLHF (Reinforcement Learning from Human Feedback via PPO)**: Trains a Reward Model on human preferences; updates policy using Proximal Policy Optimization. Complex, unstable, and computationally heavy.
- **DPO (Direct Preference Optimization)**: Mathematically derives the optimal policy directly from preference pairs `(Prompt, Chosen, Rejected)` using implicit reward modeling. Stable, requires zero reinforcement learning, and has become the industry standard.

---

## 7. Pointwise MNC Interview Questions & Answers

### Q1: Why does Grouped-Query Attention (GQA) reduce KV cache memory compared to Multi-Head Attention (MHA)?
**Answer:**
In standard MHA, every single Query head has an independent Key head and Value head ($1:1$ ratio). In GQA (used in Llama 3, Mistral), Query heads are partitioned into groups (e.g. 8 groups), and all Query heads within a group share a single Key and Value head ($8:1$ ratio). This reduces the physical number of Key and Value tensors by **$8\times$**, cutting the KV cache memory footprint by **$87.5\%$** with negligible impact on reasoning accuracy.

### Q2: What is the difference between latency and throughput in LLM serving, and how do batch size settings affect them?
**Answer:**
- **Latency (TTFT & ITL)**: Time required to generate tokens for a *single user*. Minimized by running small batch sizes (`batch_size=1`), maximizing GPU clock speeds, and running in pure compute prefill.
- **Throughput (Tokens/sec across all users)**: Total volume of tokens generated by the server cluster. Maximized by high batch sizes (e.g. `batch_size=64` or `128`) which amortizes weight reading across multiple streams, keeping GPU Tensor Cores fully utilized at the expense of slightly higher per-user latency.

### Q3: How does vLLM handle GPU memory allocation during startup?
**Answer:**
During initialization, vLLM profiles the GPU:
1. Loads model weights into VRAM.
2. Runs a dummy forward pass to measure activation memory peaks.
3. Allocates all remaining available GPU memory (`gpu_memory_utilization = 0.90` default) into a **pre-allocated pool of non-contiguous PagedAttention KV blocks**.
4. Disables PyTorch's native dynamic caching memory manager to prevent OS-level memory fragmentation during live inference.
