# RAG Fundamentals: Architecture, Chunking, Embeddings & Retrieval

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [08-vector-databases.md](./08-vector-databases.md) | [09-rag-advanced.md](./09-rag-advanced.md) | [10-llm-integration.md](./10-llm-integration.md)

---

## 1. What is RAG & Why is it Needed?

**Retrieval-Augmented Generation (RAG)** is an architectural pattern that dynamically retrieves relevant factual documents from an external knowledge base and injects them into an LLM's prompt context at inference time.

```
                          ┌──────────────────────────┐
                          │ User Query / Prompt      │
                          └─────────────┬────────────┘
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 │ 1. Vector Search Query                      │
                 ▼                                             ▼
       ┌──────────────────┐                           ┌──────────────────┐
       │ Dense Embedding  │                           │ Keyword Index    │
       │ Vector Database  │                           │ (BM25 / SQLite)  │
       └─────────┬────────┘                           └────────┬─────────┘
                 │                                             │
                 └──────────────────────┬──────────────────────┘
                                        │ 2. Top-K Relevant Document Chunks
                                        ▼
                          ┌──────────────────────────┐
                          │ Augmented System Prompt   │
                          │ Context: [Doc1, Doc2...] │
                          │ Question: User Query     │
                          └─────────────┬────────────┘
                                        │ 3. Inference
                                        ▼
                          ┌──────────────────────────┐
                          │ Foundation LLM           │
                          │ (GPT-4o, Claude 3.5...)  │
                          └─────────────┬────────────┘
                                        │
                                        ▼
                          ┌──────────────────────────┐
                          │ Factual, Grounded Answer │
                          │ + Source Citations       │
                          └──────────────────────────┘
```

### RAG vs. Fine-Tuning vs. Long Context
| Criterion | RAG | Fine-Tuning | Long Context Window (1M+ tokens) |
|---|---|---|---|
| **Data Freshness** | Real-time (instant DB upserts) | Static (requires continuous retraining) | Fresh (whatever is passed in prompt) |
| **Hallucinations** | Low (grounded strictly in citations) | High (model internalizes facts probabilistically) | Medium ("Lost in the middle" effect) |
| **Cost per Query** | Low (only top-$k$ tokens sent to LLM) | Low (no external retrieval overhead) | **Extremely Expensive** (paying for 1M input tokens per query) |
| **Auditability** | Transparent (exact document source IDs) | Black box (cannot inspect weights) | Transparent (prompt inspection) |
| **Best For** | Enterprise doc search, manuals, dynamic data | Teaching style, tone, structured output, grammar | Single long document one-off analysis |

### 🧠 Junior vs. Senior Answer: "Should we fine-tune a model to learn our internal company documents?"
- **Junior Answer**: "Yes, fine-tuning will train the model weights so it knows everything about our company."
- **Senior Answer**: "No, fine-tuning is an antipattern for factual knowledge injection. LLM weights represent probabilistic token distributions, not a deterministic database; fine-tuning often induces hallucinations, requires expensive compute, and cannot handle frequently updating documents or strict tenant-level access permissions. RAG is the industry standard for factual grounding because you can update the vector store instantaneously, cite verifiable sources, enforce document-level RBAC, and swap foundation models with zero retraining."

---

## 2. Chunking Strategies & The Context Trade-Off

Document chunking is the single most critical factor determining RAG retrieval accuracy.

```
                    The Chunk Size Dilemma
 Small Chunks (128-256 tokens)        Large Chunks (1024-2048 tokens)
┌──────────────────────────────┐     ┌──────────────────────────────┐
│ [+] Precise semantic matches │     │ [+] Broad contextual nuance  │
│ [-] Lost sentence context    │     │ [-] Diluted embeddings       │
│ [-] Fragmented facts         │     │ [-] Wasted LLM context tokens│
└──────────────────────────────┘     └──────────────────────────────┘
```

### 1. Fixed-Size Chunking with Overlap (Baseline)
Splits by a fixed number of tokens or characters with a rolling overlap (e.g. 500 characters with 50 character overlap) so sentences split across boundaries remain understandable.

### 2. Recursive Character Text Splitting (Production Standard)
Iteratively attempts to split on natural document boundaries: paragraphs (`\n\n`), then sentences (`\n`), then words (` `), and finally characters (`""`) until chunks fall under the maximum token size.

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,        # Target characters/tokens per chunk
    chunk_overlap=64,      # Overlap to preserve context across boundaries
    separators=["\n\n", "\n", ". ", " ", ""],
    length_function=len,
    is_separator_regex=False,
)

sample_doc = """Machine learning models are trained on data.
Deep learning uses multi-layer neural networks.

Transformers revolutionized Natural Language Processing.
Self-attention mechanisms allow models to weigh the significance of all tokens."""

chunks = text_splitter.split_text(sample_doc)
```

### 3. Document-Aware / Markdown Chunking
Splits documents by hierarchical headers (`#`, `##`, `###`), markdown tables, or code blocks. This guarantees that an entire table or function is never chopped in half mid-row.

### 4. Semantic Chunking
Computes embeddings of consecutive sentences, measures cosine distance between adjacent sentences, and places a chunk split wherever the semantic distance exceeds a threshold (indicating a topical shift). High accuracy, but $5\times$ more embedding API calls during ingestion.

---

## 3. Embeddings: Dense Vectors & Mathematical Similarity

An **embedding** is a translation of discrete textual tokens into a continuous $D$-dimensional vector space where semantically similar concepts are clustered closely together.

### Popular Embedding Models
| Model | Provider | Dimensions | Context Window | Best For |
|---|---|---|---|---|
| `text-embedding-3-small` | OpenAI | 1536 (can truncate) | 8,191 tokens | Fast, cheap, solid all-rounder |
| `text-embedding-3-large` | OpenAI | 3072 | 8,191 tokens | Highest accuracy commercial API |
| `bge-large-en-v1.5` | BAAI (Open Source) | 1024 | 512 tokens | Self-hosted, MTEB benchmark leader |
| `nomic-embed-text` | Nomic (Open Source) | 768 | 8,192 tokens | Long-context open-weights model |

### Similarity Metrics Math
Given two vectors $\mathbf{u}$ and $\mathbf{v}$:

1. **Cosine Similarity**: Measures the cosine of the angle between two vectors (range: $-1$ to $1$). Ignores vector magnitude:
   $$\text{Cosine}(\mathbf{u}, \mathbf{v}) = \frac{\mathbf{u} \cdot \mathbf{v}}{\|\mathbf{u}\| \|\mathbf{v}\|} = \frac{\sum u_i v_i}{\sqrt{\sum u_i^2} \sqrt{\sum v_i^2}}$$

2. **Dot Product (Inner Product)**:
   $$\mathbf{u} \cdot \mathbf{v} = \sum_{i=1}^D u_i v_i$$
   *Crucial Property:* If both vectors are **$L_2$-normalized** (unit vectors where $\|\mathbf{u}\| = 1$), then:
   $$\text{Cosine Similarity} \equiv \text{Dot Product}$$
   *Production Tip:* Pre-normalizing vectors allows vector databases to use the ultra-fast Dot Product instruction (SIMD / AVX-512) instead of expensive square root computations.

3. **Euclidean Distance ($L_2$ Distance)**: Measures straight-line geometric distance. Lower is more similar:
   $$d(\mathbf{u}, \mathbf{v}) = \sqrt{\sum_{i=1}^D (u_i - v_i)^2}$$

---

## 4. End-to-End Production RAG Implementation

```python
import os
from openai import AsyncOpenAI
import numpy as np

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# INGESTION: Embed text chunks
async def generate_embeddings(texts: list[str]) -> list[list[float]]:
    response = await client.embeddings.create(
        model="text-embedding-3-small",
        input=texts
    )
    return [data.embedding for data in response.data]

def cosine_similarity(a: list[float], b: list[float]) -> float:
    va = np.array(a)
    vb = np.array(b)
    return float(np.dot(va, vb) / (np.linalg.norm(va) * np.linalg.norm(vb)))

# RETRIEVAL & SYNTHESIS
async def answer_rag_query(query: str, vector_store: list[dict], top_k: int = 3) -> str:
    # 1. Embed user query
    query_vector = (await generate_embeddings([query]))[0]

    # 2. Score candidates
    scored_chunks = []
    for item in vector_store:
        score = cosine_similarity(query_vector, item["vector"])
        scored_chunks.append((score, item["text"]))

    # 3. Sort & take Top-K
    scored_chunks.sort(key=lambda x: x[0], reverse=True)
    top_contexts = [text for _, text in scored_chunks[:top_k]]
    formatted_context = "\n---\n".join(top_contexts)

    # 4. Synthesize with LLM
    system_prompt = (
        "You are an expert enterprise assistant. Answer the question STRICTLY using "
        "the provided context below. If the answer cannot be found in the context, "
        "state 'I cannot find that information in the provided records.'\n\n"
        f"Context:\n{formatted_context}"
    )

    completion = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": query}
        ],
        temperature=0.0
    )
    return completion.choices[0].message.content
```

---

## 5. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What is the 'Lost in the Middle' problem?"**
   - Research shows LLMs pay highest attention to tokens at the very beginning and very end of their prompt context window. Information placed in the middle of a massive context block (e.g. 50 chunks) is frequently missed or ignored. *Fix:* Put the most relevant chunks at the beginning and end, or rerank down to top 3–5 chunks.
2. **"What happens if your chunk size is smaller than a single sentence?"**
   - The sentence is cut mid-thought, destroying the syntactic and semantic coherence of the embedding vector. The vector search will either fail to match or retrieve meaningless sentence fragments.
3. **"Can an embedding model be used across languages?"**
   - Models trained purely on English (like older sentence-transformers) will fail on multilingual text. Modern models like OpenAI's `text-embedding-3-*` and `bge-m3` are natively multilingual, mapping semantically equivalent sentences in English, Spanish, and Arabic into adjacent clusters in the same vector space.

---

## 6. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between dense retrieval and sparse retrieval?
**Answer:**
- **Sparse Retrieval (e.g., BM25, TF-IDF)** matches exact keywords and lexical terms. It calculates term frequencies penalized by document frequencies. It excels at finding exact error codes, part numbers, and unique names, but fails to understand synonyms or intent.
- **Dense Retrieval (Vector Embeddings)** maps text to continuous geometric vectors based on semantic meaning. It excels at conceptual similarity (e.g., matching "puppy" to "canine"), but can struggle with exact keyword matching or uncommon alphanumeric identifiers.

### Q2: How do you choose the right chunk size and overlap for a project?
**Answer:**
Chunk size depends on the nature of the documents and the target query types:
- **Small chunks (256-512 tokens)** are ideal for fine-grained factual lookups (e.g., FAQ questions, specific technical parameters).
- **Large chunks (1024-2048 tokens)** are needed when answers require understanding broader narrative context (e.g., legal contracts, architectural narratives).
- **Overlap (10-20% of chunk size)** is standard to ensure semantic continuity across sentence boundaries.
The senior approach is empirical validation: establish a golden evaluation test set (queries + ground truth chunks) and benchmark retrieval recall across multiple chunk size variations (e.g., 256, 512, 1024).

### Q3: Why is cosine similarity preferred over Euclidean distance for text embeddings?
**Answer:**
Euclidean distance ($L_2$) measures the geometric length between two points in space, which is heavily influenced by text length (word count) because longer texts naturally accumulate larger magnitude vectors. Cosine similarity normalizes for magnitude by dividing by the vector norms, measuring strictly the directional angle between concepts. Thus, a 5-word sentence and a 50-word paragraph describing the exact same concept will have a very high cosine similarity despite having vastly different Euclidean distances.

### Q4: What is Parent-Document Retrieval (or Small-to-Big Retrieval)?
**Answer:**
Parent-Document Retrieval solves the trade-off between embedding precision and synthesis context:
- During ingestion, the document is split into **large parent chunks** (e.g. 1000 tokens) and each parent is further divided into **small child chunks** (e.g. 200 tokens).
- Only the **child chunks** are embedded and indexed in the vector database for high semantic precision.
- At retrieval time, when a child chunk matches the query, the retriever fetches its **parent chunk** from storage and feeds the parent chunk into the LLM context. This gives the embedding search surgical precision while providing the LLM full surrounding context.

### Q5: How do you handle table data in documents during RAG ingestion?
**Answer:**
Standard text splitters chop tables across row boundaries, corrupting the column-to-cell relationships. Production solutions:
1. Parse tables into structured Markdown or HTML during extraction using OCR/document parsers (e.g. Unstructured, PyMuPDF, or Marker).
2. Generate an LLM summary of the table and embed the summary for search, but store the raw Markdown table in metadata to pass into the prompt context upon retrieval.
3. For heavy structured tabular datasets, do not use vector RAG; use Text-to-SQL over a relational database instead.
