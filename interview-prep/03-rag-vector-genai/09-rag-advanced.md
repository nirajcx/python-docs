# Advanced RAG: Re-Ranking, Query Transformation, Evaluation & Agentic Loops

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [07-rag-fundamentals.md](./07-rag-fundamentals.md) | [08-vector-databases.md](./08-vector-databases.md) | [10-llm-integration.md](./10-llm-integration.md)

---

## 1. Advanced Two-Stage Retrieval: Bi-Encoders vs. Cross-Encoders (Re-Ranking)

Naive RAG retrieves the Top-$K$ (e.g., 5) documents using vector similarity and feeds them straight to the LLM. In production, this fails because embedding vector models (**Bi-Encoders**) compress entire sentences into a single vector, losing fine-grained word interactions.

**Production Solution: Two-Stage Retrieval Pipeline**
1. **Stage 1 (Retrieval - Bi-Encoder)**: Fast vector search over millions of chunks to retrieve candidate Top-25 chunks in ~15ms.
2. **Stage 2 (Re-Ranking - Cross-Encoder)**: Run a heavy Cross-Encoder model (e.g. Cohere Rerank or `bge-reranker`) over the Top-25 candidates to calculate full cross-attention between `(Query, Document)` pairs, outputting the sharpest Top-5 chunks.

```
                    Bi-Encoder vs. Cross-Encoder
 Bi-Encoder (Stage 1: Vector DB)        Cross-Encoder (Stage 2: Re-Ranker)
┌──────────────┐     ┌──────────────┐   ┌────────────────────────────────┐
│ Query Vector │     │ Doc Vector   │   │ Query + Document Concatenated  │
└──────┬───────┘     └──────┬───────┘   └───────────────┬────────────────┘
       │                    │                           │
       ▼                    ▼                           ▼
 ┌──────────────────────────────────┐   ┌────────────────────────────────┐
 │ Fast Cosine / Dot Product (SIMD) │   │ Full Cross-Attention Layers    │
 └──────────────────────────────────┘   │ All words attend to all words! │
                                        └───────────────┬────────────────┘
                                                        │
                                                        ▼
                                                 Precision Score (0-1)
```

### In-Process Re-ranking with FlashRank
For microservices where calling Cohere API introduces network latency and external costs, **FlashRank** runs tiny quantized cross-encoders locally in CPU memory in ~20ms.

```python
from flashrank import Ranker, RerankRequest

# Lightweight in-process CPU cross-encoder (~40MB model)
ranker = Ranker(model_name="ms-marco-TinyBERT-L-2-v2", cache_dir="/tmp/models")

def rerank_search_results(query: str, raw_chunks: list[dict], top_n: int = 3) -> list[dict]:
    rerank_request = RerankRequest(
        query=query,
        passages=[{"id": c["id"], "text": c["content"]} for c in raw_chunks]
    )
    # Re-scores candidates using deep cross-attention
    results = ranker.rerank(rerank_request)
    return results[:top_n]
```

---

## 2. Query Transformation & Expansion

Users write poor, vague, or conversational queries. Sending raw conversational queries directly to a vector store degrades retrieval.

```
Conversational History:
User: "What is the warranty policy for the Siraaj platform?"
Assistant: "It includes 1 year hardware and 24/7 software support."
Follow-up: "Does it cover accidental water damage?"
                               │
               Raw Follow-up has NO context!
               Vector search on "Does it cover accidental water damage?" FAILS!
                               │
                               ▼
                 ┌──────────────────────────┐
                 │ Query Rewriter (LLM)     │
                 └─────────────┬────────────┘
                               │
                               ▼
 Resolved: "Does the Siraaj platform warranty cover accidental water damage?"
```

### 1. Query De-Contextualization (Conversation Rewriter)
```python
async def condense_conversational_query(chat_history: list[dict], follow_up_query: str) -> str:
    prompt = (
        "Given the following conversation history and a follow-up question, "
        "rephrase the follow-up question to be a standalone, self-contained search query. "
        "Do NOT answer the question, only rewrite it.\n\n"
        f"History:\n{chat_history}\n"
        f"Follow-up: {follow_up_query}\nStandalone Query:"
    )
    # Single fast LLM call (e.g. gpt-4o-mini) returns clean standalone search query
    rewritten_query = await call_fast_llm(prompt)
    return rewritten_query.strip()
```

### 2. Multi-Query Retrieval (Query Expansion)
Generates 3–5 alternative phrasing variations of the user's intent to capture different vocabulary:
- Query: *"How do I speed up my database?"*
- Variations:
  - *"Database indexing and query optimization techniques"*
  - *"How to tune PostgreSQL connection pool and cache hit ratio"*
  - *"Reducing database query latency strategies"*
- Retrieval runs across all variations, and results are deduplicated via **Reciprocal Rank Fusion (RRF)**.

### 3. HyDE (Hypothetical Document Embeddings)
- When queries are short, vector embeddings lack substance.
- **HyDE** prompts an LLM to generate a **hypothetical ideal answer** to the user question (even if hallucinated).
- It embeds the **hypothetical answer** rather than the query.
- Because the hypothetical answer has the structure, vocabulary, and length of a real document, its embedding lands closer to real document chunks in vector space.

---

## 3. RAG Evaluation Metrics (The Ragas / TruLens Triad)

You cannot improve what you do not measure. In production, RAG systems are evaluated continuously using automated **LLM-as-a-Judge** frameworks (e.g., **Ragas**, TruLens).

```
                        The RAG Evaluation Triad
                       ┌────────────────────────┐
                       │       User Query       │
                       └─────┬────────────┬─────┘
                             │            │
             Answer Relevance│            │Context Precision
                             ▼            ▼
     ┌──────────────┐ Context Faithfulness ┌──────────────┐
     │  Generated   │◄─────────────────────┤  Retrieved   │
     │    Answer    │ (Hallucination Test) │   Context    │
     └──────────────┘                      └──────────────┘
```

| Metric | What it Measures | How it is Calculated | What Failure Indicates |
|---|---|---|---|
| **Faithfulness / Groundedness** | Are all statements in the answer supported by retrieved context? | Fraction of answer claims verifiable in context | **Hallucination!** Model is making up facts not present in documents. |
| **Answer Relevance** | Does the answer directly address the user query? | LLM evaluates semantic alignment between query and generated response | Model rambles, gives evasive answers, or goes off on tangents. |
| **Context Precision** | Are relevant chunks ranked higher than irrelevant noise? | Precision@K of retrieved chunks against ground truth | Vector store / ranking algorithm is surfacing noise at rank 1–3. |
| **Context Recall** | Did the retriever find all information needed to answer? | Ground truth claims present in retrieved context | Ingestion chunking missed data, or $K$ is set too low. |

---

## 4. Common RAG Failure Modes & Production Fixes

| Failure Mode | Root Cause | Production Senior Fix |
|---|---|---|
| **1. Missed Retrieval** | Lexical mismatch (jargon, acronyms, part numbers). | Implement **Hybrid Search (BM25 + Dense HNSW)** with RRF. |
| **2. Fragmented Context** | Chunk size too small; sentence split across boundary. | Increase chunk size, add 20% overlap, or use **Parent-Document Retrieval**. |
| **3. Information Dilution** | Too many irrelevant chunks fed to LLM ($K=20$). | Add **Cross-Encoder Re-Ranking** (FlashRank/Cohere) to prune to Top-3 chunks. |
| **4. Hallucination Despite Good Chunks** | Weak LLM following instructions or contradictory docs. | Strict system prompt guardrails ("Answer ONLY using context"), temperature 0.0, or switch to GPT-4o / Claude 3.5. |
| **5. Query Mismatch** | Conversational pronoun references ("it", "they"). | Add an **LLM Query De-Contextualization** step before vector search. |

---

## 5. Agentic RAG vs. Naive RAG

Naive RAG is a static, single-hop linear script: `Query -> Embed -> Search -> Synthesize`. If retrieval returns bad chunks, the user gets an incorrect answer with zero recourse.

**Agentic RAG** introduces dynamic control flow, loops, and tools (using frameworks like **LangGraph**):
1. **Router**: Analyzes the query to decide whether to search Vector DB, query SQL database, search the web, or answer directly.
2. **Self-Correction / Reflection Loop**: Evaluates retrieved chunks. If relevance score is too low, the agent rewrites the search query and retries retrieval automatically.
3. **Multi-Hop Reasoning**: Breaks complex questions into sub-goals (e.g. *"Compare Siraaj's 2025 revenue to Wishan's 2025 revenue"* -> retrieves doc 1, retrieves doc 2, then compares).

```python
# Conceptual LangGraph Agentic Node Flow
# StateGraph:
#   [Analyze Query] ──► [Route Decision]
#                             │
#          ┌──────────────────┴──────────────────┐
#          ▼                                     ▼
#   [Vector Retriever]                     [SQL Database]
#          │                                     │
#          ▼                                     ▼
#   [Evaluate Chunks] ──(Relevance < 0.6)──► [Rewrite Query & Loop]
#          │
#    (Relevance >= 0.6)
#          ▼
#   [Synthesize Answer] ──► [Fact-Check Verification] ──► [Final Response]
```

---

## 6. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why not set Top-$K$ to 50 so the LLM gets everything?"**
   - Cost skyrockets (paying per input token), latency balloons, and LLMs suffer from "Lost in the Middle" attention degradation, causing hallucinations or ignored facts.
2. **"Does HyDE always improve retrieval?"**
   - No! HyDE is counterproductive for queries with obscure technical entities, specific codes, or dates. If the LLM hallucinates incorrect specifics in the hypothetical document, the embedding will match incorrect documents. HyDE is best suited for open-ended conceptual questions.
3. **"How do you benchmark RAG pipelines without human ground-truth labels?"**
   - Use synthetic test generation: Have an advanced LLM (e.g. GPT-4o) scan your document chunks and synthetically generate `(Question, Ground-Truth Chunk)` pairs. Run your pipeline against these pairs and compute automated Ragas metrics.

---

## 7. High-Probability Interview Questions & Model Answers

### Q1: What is the core difference between a Bi-Encoder and a Cross-Encoder?
**Answer:**
- A **Bi-Encoder** processes the query and the document independently through a transformer model, producing two separate dense embedding vectors. Comparison is done via cosine similarity or dot product in microseconds. It can scale to billions of documents via vector indexing, but lacks token-to-token cross-attention.
- A **Cross-Encoder** passes the query and document together as a concatenated pair (`[CLS] Query [SEP] Document [SEP]`) into a single transformer. Every token in the query attends to every token in the document across all self-attention layers. This produces unmatched ranking accuracy, but is computationally expensive ($O(N)$ transformer forward passes), which is why it is used exclusively as a second-stage re-ranker on small candidate sets (e.g. Top 20).

### Q2: How do you detect and prevent hallucinations in production RAG systems?
**Answer:**
1. **Prompt Guardrails**: Strict system instruction: *"Answer strictly based on the provided context. If the answer cannot be verified directly from the context, respond with 'Information not available in records'."*
2. **Deterministic Sampling**: Set `temperature=0.0`.
3. **Automated Post-Check (Faithfulness)**: Before sending the response to the user, pass the answer and retrieved context to a fast evaluator LLM to check if every statement in the response is logically entailed by the context. If not, trigger a fallback message.
4. **Citation Grounding**: Force the model to output source chunk IDs or quotes for every claim using JSON schema structured output.

### Q3: What is Context Compression, and why would you use it?
**Answer:**
Retrieved chunks often contain paragraphs of irrelevant text surrounding the single sentence containing the answer. Context compression passes the retrieved chunks through an LLM or small extraction model to extract only the sentences directly pertinent to the query, stripping out extraneous noise before injecting into the synthesis prompt. This saves tokens, reduces latency, and prevents the LLM from being distracted.

### Q4: Explain the difference between Multi-Query Retrieval and Sub-Question Decomposition.
**Answer:**
- **Multi-Query Retrieval** generates multiple alternative wordings of the *same* question to overcome vector embedding vocabulary limitations.
- **Sub-Question Decomposition** takes a *complex multi-part question* (e.g. *"What are the architectural differences between Siraaj and ERP systems, and which has higher throughput?"*) and breaks it down into distinct sub-questions: 1. *"What is Siraaj's architecture and throughput?"*, 2. *"What is the ERP system's architecture and throughput?"*. It retrieves documents for each sub-question independently and synthesizes a final comparative answer.

### Q5: How do you handle permissions / RBAC in an advanced RAG pipeline?
**Answer:**
Never rely on prompt instructions to enforce security (e.g. *"Do not show document X to user Y"* is easily bypassed with prompt injection).  
Enforce security at the **retrieval infrastructure layer**:
1. During ingestion, store authorized role and user IDs in the chunk payload metadata (`access_roles: ["admin", "finance"]`).
2. At query time, extract the authenticated user's roles from their verified JWT.
3. Inject these roles into the vector database filter query (`filter={"access_roles": {"$in": user_roles}}`).
4. The vector database mathematically excludes unauthorized chunks from the candidate set before scoring, ensuring unauthorized data never reaches the prompt.
