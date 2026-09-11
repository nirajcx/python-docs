# Vector Databases: ANN Search, HNSW, Systems Comparison & Hybrid Search

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [07-rag-fundamentals.md](./07-rag-fundamentals.md) | [09-rag-advanced.md](./09-rag-advanced.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md)

---

## 1. How Vector Databases Work Internally: Exact vs. ANN Search

Searching for the exact nearest neighbor (**kNN**) requires comparing the query vector against every single vector in the database (brute-force linear scan: $O(N \cdot D)$). At 10 million 1536-dimensional vectors, exact search takes several seconds per query—completely unacceptable for real-time APIs.

To solve this, vector databases trade an imperceptible amount of mathematical precision (typically $< 1\%$ accuracy loss) for exponential speed gains using **Approximate Nearest Neighbor (ANN)** indexing.

```
       Exact kNN (Linear Scan)                   HNSW (Hierarchical Graph)
      Query compares against all N            Multi-layer skip-graph navigation
      Complexity: O(N * D)                    Complexity: O(log N * D)
┌─────────────────────────────────┐      Layer 2:  (•) ─────────────► (•)
│ •  •  •  •  •  •  •  •  •  •  • │                 │                   │
│ •  •  •  •  •  •  •  •  •  •  • │      Layer 1:  (•) ──► (•) ───────► (•)
│ •  •  •  •  [Q] •  •  •  •  •  •│                 │       │           │
│ •  •  •  •  •  •  •  •  •  •  • │      Layer 0:  (•)─(•)─(•)─(•)─(•)─(•) (Dense Data)
└─────────────────────────────────┘
```

---

## 2. Core ANN Indexing Algorithms: HNSW vs. IVF

### 1. HNSW (Hierarchical Navigable Small World) — Gold Standard
Inspired by the multi-layer **skip-list**:
- **Layer 0 (Bottom)**: Contains every vector as a node, connected by edges to its closest neighbors (small-world graph with clustering).
- **Upper Layers**: Contain progressively sparser subsets of vectors with long-range "expressway" connections.
- **Search Process**: The query starts at the top sparse layer, takes greedy hops toward the closest node, drops down to the next layer, and repeats until reaching Layer 0 for fine-grained local beam search.

#### Key HNSW Tuning Parameters:
- **`M`** (Max connections per node, e.g. 16–64): Higher $M$ increases recall and graph connectivity at the cost of higher RAM usage and slower index build time.
- **`efConstruction`** (Exploration depth during build, e.g. 100–200): Controls index quality at ingestion time.
- **`efSearch`** (Exploration depth during query, e.g. 64–128): Runtime query parameter; higher `efSearch` increases recall at the cost of query latency.

### 2. IVF (Inverted File Index)
Clusters vectors into $K$ Voronoi cells using $k$-means:
- During ingestion, vectors are assigned to their nearest cluster centroid.
- At query time, the search only scans vectors inside the top $nprobe$ closest centroids, skipping the rest of the dataset.
- **Trade-off**: Lower RAM usage than HNSW, but lower recall on high-dimensional data and vulnerable to skewed clusters.

### 3. Vector Quantization (Compression)
- **Scalar Quantization (SQ8)**: Compresses 32-bit floats (`float32`) down to 8-bit integers (`int8`), reducing RAM by **$4\times$** with negligible recall drop.
- **Product Quantization (PQ)**: Splits high-dimensional vectors into sub-vectors and clusters them into codebooks, reducing RAM by up to **$16\times$** at the cost of slight precision loss.

---

## 3. Vector Database Comparison Matrix

| Database | Architecture | Hosting / Deployment | Metadata Filtering | Standout Strength | Weakness / Gotcha |
|---|---|---|---|---|---|
| **Qdrant** | Rust-native, Raft distributed | Open-Source / Cloud / Docker | Single-stage payload index | Extremely fast, payload-aware HNSW, low memory | Requires self-hosted ops if not using cloud |
| **ChromaDB** | Python / ClickHouse / DuckDB | Embedded (in-memory) / Docker | Post-filtering / SQLite index | Zero setup for local PoCs and testing | Not designed for multi-million distributed scale |
| **Pinecone** | Proprietary SaaS | Managed Serverless Cloud | Built-in metadata index | Zero infrastructure management, auto-scaling | Vendor lock-in, recurring cloud API costs |
| **FAISS** | C++ core with Python bindings | Pure library (Meta) | Manual / None (vectors only) | Fastest raw in-memory vector compute, GPU support | Not a database (no persistence, no CRUD, no auth) |
| **Pgvector** | PostgreSQL extension | Existing Postgres instance | Native SQL `WHERE` clauses | ACID compliance, zero new infra | Consumes Postgres RAM, slower build at 10M+ scale |

---

## 4. Metadata Filtering: Pre-Filtering vs. Post-Filtering

In enterprise applications (e.g. multi-tenant SaaS), a user can only search documents where `org_id == "tenant_A" AND is_archived == false`.

```
                    Metadata Filtering Strategies
 Pre-Filtering                           Post-Filtering (The Trap)
┌───────────────────────────────┐       ┌───────────────────────────────┐
│ 1. Filter rows by metadata    │       │ 1. Run vector ANN for Top-10  │
│ 2. Run vector ANN ONLY on     │       │ 2. Filter out non-matching    │
│    the filtered subset        │       │    chunks from Top-10         │
│ RESULT: Guaranteed 10 results!│       │ RESULT: Returns only 1 result!│
└───────────────────────────────┘       └───────────────────────────────┘
```

### The Post-Filtering Trap (The $k$-Shortage Problem)
If you request `top_k=5` and filter *after* running vector similarity:
If the 5 closest vector matches belong to `tenant_B`, post-filtering strips them all out, returning **0 results** to the user even though matching documents exist in the database!

### Modern Solution: Single-Stage Filtered HNSW (e.g., Qdrant)
Qdrant and modern engines traverse the HNSW graph while checking filter condition masks on the fly at each hop. If the candidate subset is too small ($< 1\%$), it dynamically switches to filtered exact search.

```python
# Production Qdrant Filtered Search Example
from qdrant_client import AsyncQdrantClient
from qdrant_client.http import models

client = AsyncQdrantClient(url="http://localhost:6333")

async def search_tenant_documents(query_vec: list[float], tenant_id: str):
    results = await client.search(
        collection_name="enterprise_docs",
        query_vector=query_vec,
        query_filter=models.Filter(
            must=[
                models.FieldCondition(
                    key="tenant_id",
                    match=models.MatchValue(value=tenant_id),
                ),
                models.FieldCondition(
                    key="status",
                    match=models.MatchValue(value="published"),
                ),
            ]
        ),
        limit=5,
    )
    return results
```

---

## 5. Hybrid Search: Dense + Sparse (BM25) & Reciprocal Rank Fusion (RRF)

Dense vectors excel at semantic similarity, but fail at exact keywords (e.g., SKU numbers `TX-90210`, error codes `ERR_CONN_REFUSED`, user emails). **Hybrid search** combines BM25 keyword search with dense vector search to achieve the best of both worlds.

```
       Query: "What is error code ERR_404 in Siraaj ERP?"
                │
        ┌───────┴───────┐
        ▼               ▼
 ┌──────────────┐ ┌──────────────┐
 │ BM25 Sparse  │ │ Dense Vector │
 │ (Exact Words)│ │ (Semantics)  │
 └──────┬───────┘ └──────┬───────┘
   Ranked List 1    Ranked List 2
        │               │
        └───────┬───────┘
                ▼
      ┌──────────────────┐
      │ Reciprocal Rank  │
      │ Fusion (RRF)     │
      └─────────┬────────┘
                ▼
      Final Blended Top-K
```

### Reciprocal Rank Fusion (RRF) Formula & Implementation
RRF combines ranked lists without needing to normalize disparate score scales (BM25 scores range from $0$ to $\infty$; Cosine ranges from $-1$ to $1$):

$$RRF(d) = \sum_{m \in M} \frac{1}{k + \text{rank}_m(d)}$$
Where $k$ is a smoothing constant (standard default: $60$), and $\text{rank}_m(d)$ is the 1-indexed position of document $d$ in system $m$.

```python
def reciprocal_rank_fusion(
    dense_ranks: list[str],
    sparse_ranks: list[str],
    k: int = 60,
    top_n: int = 5
) -> list[tuple[str, float]]:
    """Combines two ranked lists of document IDs using RRF."""
    rrf_scores: dict[str, float] = {}

    # Accumulate score from Dense results
    for rank, doc_id in enumerate(dense_ranks, start=1):
        rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + (1.0 / (k + rank))

    # Accumulate score from Sparse (BM25) results
    for rank, doc_id in enumerate(sparse_ranks, start=1):
        rrf_scores[doc_id] = rrf_scores.get(doc_id, 0.0) + (1.0 / (k + rank))

    # Sort descending by RRF score
    sorted_docs = sorted(rrf_scores.items(), key=lambda item: item[1], reverse=True)
    return sorted_docs[:top_n]

# Demonstration
dense_results = ["doc_A", "doc_B", "doc_C"]
sparse_results = ["doc_B", "doc_D", "doc_A"]
blended = reciprocal_rank_fusion(dense_results, sparse_results)
print(blended)
# doc_B ranks #1 because it appeared at rank 2 and rank 1 across both systems!
```

---

## 6. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why does HNSW consume so much RAM compared to relational databases?"**
   - HNSW graphs must retain vector representations and all inter-node edge lists in memory for fast graph hops. At 1536 dimensions, 1M `float32` vectors require $\approx 6.1\text{GB}$ for raw vectors alone, plus another $2\text{--}4\text{GB}$ for graph adjacency lists.
2. **"Can you delete or update vectors in an HNSW index easily?"**
   - In pure graphs, deleting a node leaves dangling edges and damages graph connectivity. Many engines handle deletions by setting a soft "tombstone" flag and rebuilding or rebalancing the graph asynchronously in background compaction cycles.
3. **"When would you choose Pinecone over self-hosted Qdrant?"**
   - Choose Pinecone when the team is small, has zero DevOps/infrastructure engineers, and needs an auto-scaling, serverless vector store with zero maintenance. Choose Qdrant when you need data sovereignty (on-premise / VPC), zero data egress costs, complex payload-filtering flexibility, or lower long-term cloud bills.

---

## 7. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between HNSW and IVF indexing?
**Answer:**
- **HNSW** constructs a multi-layer graph where nodes are vectors and edges represent proximity. It provides the highest query recall and lowest query latency ($O(\log N)$), but requires significantly higher RAM and takes longer to build and index.
- **IVF (Inverted File)** partitions the vector space into clusters around Voronoi centroids. During search, it only looks inside the closest $nprobe$ clusters. IVF has lower memory usage and faster index construction, but suffers lower recall and degraded performance if cluster distribution is uneven.

### Q2: Why is score normalization tricky when blending BM25 and Vector Search?
**Answer:**
BM25 scores are unbounded positive numbers dependent on term frequency and document length, where scores can range from $0.5$ to $40+$. Conversely, cosine similarity scores strictly range between $-1.0$ and $+1.0$. A naive linear combination (`score = 0.5 * bm25 + 0.5 * cosine`) is fragile and fails as corpus size changes. This is why **Reciprocal Rank Fusion (RRF)** is the industry standard: it ignores the raw score magnitudes entirely and evaluates purely on the relative **ordinal rank positions** of items across both retrieval lists.

### Q3: How do you handle multi-tenancy in a vector database?
**Answer:**
1. **Isolated Collections / Indexes per Tenant**: Best for strict compliance and security isolation, but creates high resource overhead if you have thousands of tenants.
2. **Shared Collection with Payload Metadata Filtering**: A single index where every vector includes a `tenant_id` payload. Queries enforce `filter={"tenant_id": current_tenant}`. Modern vector DBs like Qdrant optimize this natively with single-stage filtered HNSW.
3. **Namespace Partitioning**: (e.g. Pinecone namespaces) Logical partitions within a single index offering logical isolation without the overhead of spinning separate clusters.

### Q4: What is the curse of dimensionality in vector search?
**Answer:**
As vector dimensionality ($D$) increases (e.g. from 128 to 3072 dimensions), the volume of the space grows exponentially, and all points become roughly equidistant from one another. Distance metrics lose their discriminating power, and spatial indexing structures like KD-trees collapse to brute-force $O(N)$ linear scans. Modern ANN algorithms like HNSW mitigate this by building graphs based on relative nearest-neighbor topology rather than spatial grid partitioning.

### Q5: What is Scalar Quantization (SQ) and when should you enable it?
**Answer:**
Scalar Quantization (e.g. SQ8) maps 32-bit floating-point values into 8-bit integers using uniform linear binning. This reduces the in-memory footprint of vector embeddings by **$75\%$** ($4\times$ memory reduction) and accelerates vector distance computations using hardware-accelerated integer SIMD instructions. It should be enabled on large-scale datasets (millions of vectors) when RAM costs become a primary bottleneck, as the recall penalty is typically less than $1\text{--}2\%$.
