# System Design for Python & AI Engineers: APIs, Caching, Queues & End-to-End RAG

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md) | [08-vector-databases.md](../03-rag-vector-genai/08-vector-databases.md) | [10-llm-integration.md](../03-rag-vector-genai/10-llm-integration.md)

---

## 1. REST API Design & Scalable Standards

### HTTP Methods & Idempotency
An operation is **idempotent** if making multiple identical requests has the same intended effect on the server as making a single request.

| Method | Idempotent? | Safe? (Read-Only) | Purpose |
|---|---|---|---|
| `GET` | **Yes** | **Yes** | Retrieve resource representation without side effects. |
| `POST` | **No** | **No** | Create a new subordinate resource or trigger an action. |
| `PUT` | **Yes** | **No** | Full replacement of target resource (upsert). |
| `PATCH`| **No** / Conditional | **No** | Partial update of specific fields of a resource. |
| `DELETE`| **Yes** | **No** | Delete target resource (subsequent calls return 404, but state remains deleted). |

### Pagination: Offset/Limit vs. Cursor-Based
```
 Offset Pagination: SELECT * FROM docs LIMIT 20 OFFSET 100000;
 ❌ Scans 100,020 rows in DB before returning 20! O(N) performance degradation.
 ❌ Susceptible to phantom skips if rows are inserted while user is paginating.

 Cursor (Keyset) Pagination: SELECT * FROM docs WHERE id > 'doc_100' ORDER BY id ASC LIMIT 20;
 ✅ Constant time O(1) seek using B-Tree index on cursor column.
 ✅ Immune to pagination drift.
```

---

## 2. Caching Strategies & Redis

### 1. Cache Patterns
- **Cache-Aside (Lazy Loading)**: Application checks Redis first. On cache miss, reads from DB, writes result to Redis with TTL, and returns. (Industry standard for web backends).
- **Write-Through**: Application writes data to the cache; cache synchronously writes to the DB. Low read latency, but higher write latency.
- **Write-Behind (Write-Back)**: Application writes to cache immediately; cache asynchronously flushes batch writes to DB. Fast, but risks data loss if Redis crashes before flush.

### 2. The Cache Stampede (Thundering Herd)
Occurs when a popular cached item with high traffic expires. Hundreds of concurrent requests experience a cache miss simultaneously and hammer the primary database, taking it down.  
**Fix: Distributed Mutex Lock / Probabilistic Early Expiration (XFetch)**:
```python
async def get_with_stampede_protection(key: str, ttl_seconds: int = 300):
    val = await redis.get(key)
    if val:
        return val
    
    # Acquire non-blocking distributed lock
    lock_acquired = await redis.set(f"lock:{key}", "1", nx=True, ex=10)
    if lock_acquired:
        try:
            val = await db_fetch_heavy_data(key)
            await redis.set(key, val, ex=ttl_seconds)
            return val
        finally:
            await redis.delete(f"lock:{key}")
    else:
        # Another worker is refreshing; sleep briefly and re-read cache
        await asyncio.sleep(0.05)
        return await redis.get(key)
```

### 3. Semantic Caching for GenAI (GPTCache / Redis Vector)
Traditional caching requires exact string matches (`key="What is RAG?"`). If a user asks *"Can you explain what RAG is?"*, traditional cache misses!  
**Semantic Cache Solution**:
1. Compute embedding of the incoming query.
2. Query Redis Vector store for existing cached query vectors with Cosine Similarity $\ge 0.95$.
3. If similar query exists, return the cached LLM response instantly in **$< 15\text{ms}$** for **$\$0.00$** LLM cost!

---

## 3. Asynchronous Task Queues: Celery / Redis Streams

For operations that exceed 500ms (PDF OCR, generating 100 embeddings, webhook dispatches), the HTTP request must acknowledge immediately with `202 Accepted` and offload work to a task queue.

```
 Client              FastAPI Gateway            Redis Broker             Celery Worker Fleet
   │                       │                         │                            │
   │ 1. POST /doc/upload   │                         │                            │
   ├──────────────────────►│                         │                            │
   │ 2. HTTP 202 {"task_id"}│ 3. Enqueue Task        │                            │
   │◄──────────────────────┼────────────────────────►│                            │
   │                       │                         │ 4. Pull Task from Queue    │
   │                       │                         ├───────────────────────────►│
   │                       │                         │                            │ 5. Parse, Chunk,
   │ 6. GET /tasks/{id}    │                         │                            │    Embed, Upsert
   ├──────────────────────►│ 7. Query State          │ 8. Write Result State      │    to Qdrant
   │ 8. {"status": "done"} │◄────────────────────────┼────────────────────────────┤
   │◄──────────────────────┤                         │                            │
```

### Key Queue Concepts for Interviews:
- **Prefetch Count**: Limits how many unacknowledged messages a worker pulls in advance. For long-running AI tasks, set `prefetch=1` so tasks are not hoarded by one busy worker while others sit idle.
- **Dead Letter Queue (DLQ)**: If a task fails repeatedly after max retries (e.g. malformed PDF crashes worker), it is routed to a DLQ for inspection rather than cyclically crashing the queue.
- **Idempotency Keys**: Ensure that retried jobs do not duplicate billing or database entries.

---

## 4. End-to-End System Design Interview: Enterprise RAG Platform

### Scenario:
> **"Design a real-time enterprise RAG search & conversational chatbot system serving 100,000 daily active users querying 5 million internal documents."**

```
                                  HIGH-LEVEL SYSTEM TOPOLOGY
                                  
                               ┌────────────────────────┐
                               │  Client Applications   │ (Web / Mobile / Slack)
                               └───────────┬────────────┘
                                           │ HTTPS / WSS / SSE
                                           ▼
                               ┌────────────────────────┐
                               │ Cloudflare / AWS ALB   │ (SSL, DDoS, Global CDN, Rate Limiting)
                               └───────────┬────────────┘
                                           │
             ┌─────────────────────────────┴─────────────────────────────┐
             │                                                           │
             ▼                                                           ▼
 ┌───────────────────────┐                                   ┌───────────────────────┐
 │ FastAPI Ingest API    │                                   │ FastAPI Query API     │
 └───────────┬───────────┘                                   └───────────┬───────────┘
             │                                                           │
             ▼                                                           ▼
 ┌───────────────────────┐                                   ┌───────────────────────┐
 │ AWS S3 (Raw Documents)│                                   │ Redis Semantic Cache  │
 └───────────┬───────────┘                                   └───────────┬───────────┘
             │                                                           │ (Cache Miss)
             ▼                                                           ▼
 ┌───────────────────────┐                                   ┌───────────────────────┐
 │ Celery Worker Fleet   │ (Parse, Chunk, Embed)             │ Fast Query Rewriter   │ (LLM gpt-4o-mini)
 └───────────┬───────────┘                                   └───────────┬───────────┘
             │                                                           │
             ├───────────────────────────┬───────────────────────────────┤
             │                           │                               │
             ▼                           ▼                               ▼
 ┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
 │ Qdrant Vector Cluster │   │ Elasticsearch / BM25  │   │ PostgreSQL (Metadata) │
 │ (HNSW Dense Embeds)   │   │ (Sparse Exact Match)  │   │ (Tenants, Users, RBAC)│
 └───────────────────────┘   └───────────┬───────────┘   └───────────────────────┘
                                         │
                                         ▼
                             ┌───────────────────────┐
                             │ Reciprocal Rank Fusion│ (Blends Sparse + Dense)
                             └───────────┬───────────┘
                                         │
                                         ▼
                             ┌───────────────────────┐
                             │ FlashRank / Cohere    │ (Cross-Encoder Re-Ranking Top-5)
                             └───────────┬───────────┘
                                         │
                                         ▼
                             ┌───────────────────────┐
                             │ LLM Inference Stream  │ (Claude 3.5 / GPT-4o via SSE)
                             └───────────────────────┘
```

### 1. Ingestion Pipeline Breakdown
1. User uploads document via Pre-signed S3 URL.
2. S3 ObjectCreated event fires a message into **RabbitMQ / Redis**.
3. **Celery Worker** picks up the task:
   - Downloads PDF and extracts structured text/tables using `PyMuPDF` / `unstructured`.
   - Chunks text using `RecursiveCharacterTextSplitter` (512 tokens, 64 overlap).
   - Generates embeddings in batches of 100 via `text-embedding-3-small`.
   - Upserts vectors and document chunks into **Qdrant** with tenant/RBAC payload.
   - Saves document metadata (title, page count, upload date, owner) in **PostgreSQL**.

### 2. Query Pipeline Breakdown
1. User submits query to `FastAPI Query Gateway`.
2. Auth dependency verifies JWT and extracts `user_id` and `tenant_id`.
3. **Semantic Cache**: Checks Redis vector cache. If query similarity $\ge 0.96$, streams cached response directly.
4. **Query Rewriter**: If follow-up in chat session, rewrites query into standalone question.
5. **Hybrid Retrieval (Fan-out)**:
   - In parallel (`asyncio.TaskGroup`), query Qdrant (dense HNSW) and Elasticsearch (BM25 sparse) with tenant filter masks.
6. **Blend & Rerank**:
   - Merge candidate lists using **Reciprocal Rank Fusion (RRF)**.
   - Run candidate Top-20 through local **FlashRank** re-ranker, extracting Top-5 highest-scoring passages.
7. **Synthesis**:
   - Construct prompt with context, system guardrails, and conversation history.
   - Stream response back to client via **FastAPI `StreamingResponse` (Server-Sent Events)**.
   - Post-response background task logs query, token usage, latency, and retrieved chunk IDs to ClickHouse/PostgreSQL for analytics and evaluation.

### 3. Back-of-the-Envelope Capacity Estimation
- **Users**: 100,000 DAU $\times$ 5 queries/day = 500,000 queries/day.
- **Average QPS**: $500,000 / 86,400 \approx 6 \text{ QPS}$ (Peak 5x: $\approx 30\text{ QPS}$).
- **Vector Storage**: 5,000,000 documents $\times$ 10 chunks/doc = 50,000,000 chunks.
- **Vector Memory**: $50,000,000 \times 1536 \text{ dims} \times 4 \text{ bytes (float32)} \approx 307 \text{ GB}$.
  - With **Scalar Quantization (SQ8)**: Compressed by $4\times \implies \approx 76 \text{ GB RAM}$.
  - Easily managed by a 3-node Qdrant cluster (each node with 32GB RAM).

---

## 5. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What happens when the LLM provider experiences an outage?"**
   - Implement circuit breakers using libraries like `pybreaker`. If OpenAI error rate exceeds 20%, trip circuit breaker and route requests to an alternative fallback provider (e.g. Anthropic Claude via Amazon Bedrock or self-hosted vLLM instance).
2. **"How do you prevent a slow embedding generation from blocking the entire API?"**
   - Decouple ingestion into asynchronous queues. Never generate embeddings synchronously in the HTTP request cycle.
3. **"How do you ensure multi-tenant security in hybrid search?"**
   - Ensure tenant filtering is enforced in *both* retrieval branches (in Elasticsearch via `term: {tenant_id: ...}` and in Qdrant via `FieldCondition: {tenant_id: ...}`).

---

## 6. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between horizontal and vertical scaling, and what are their limits?
**Answer:**
- **Vertical Scaling (Scale-Up)** adds more CPU, RAM, or faster NVMe disks to a single server. It requires zero application architecture changes, but hits hard physical hardware limits and introduces a single point of failure (SPOF).
- **Horizontal Scaling (Scale-Out)** adds more server instances behind a load balancer. It offers virtually limitless scaling and high availability, but requires the application layer to be strictly **stateless** (sessions and caches externalized to Redis; persistent state externalized to distributed databases).

### Q2: How does a Layer 4 (L4) load balancer differ from a Layer 7 (L7) load balancer?
**Answer:**
- **Layer 4 (Transport Layer, e.g. AWS NLB, HAProxy)** routes traffic based on IP address and TCP/UDP port without inspecting application packet content. It is extremely fast, uses minimal CPU, and operates at millions of packets per second.
- **Layer 7 (Application Layer, e.g. AWS ALB, NGINX)** parses and inspects the HTTP/HTTPS protocol headers, cookies, and URI paths. It allows intelligent routing (e.g. routing `/api/v1/stream` to specialized async instances and `/api/v1/auth` to others), SSL termination, and header-based rate limiting, at the cost of higher CPU overhead per connection.

### Q3: How do you implement database connection pooling in a horizontally scaled microservice?
**Answer:**
If 20 FastAPI container instances each run 4 workers with a pool size of 20 connections, that represents $20 \times 4 \times 20 = 1,600$ potential open connections to PostgreSQL, which can exhaust database memory.  
The production solution is a centralized proxy pooler like **PgBouncer** running in transaction pooling mode directly in front of PostgreSQL. Application instances maintain low connection counts, and PgBouncer dynamically maps thousands of short-lived application transactions onto a small, optimal pool of 30–50 real database connections.

### Q4: What is the difference between Write-Around, Write-Through, and Cache-Aside caching?
**Answer:**
- **Cache-Aside**: Application handles caching manually. Reads check cache first; on miss, read DB and populate cache. Writes go straight to DB; cache entry is invalidated.
- **Write-Through**: Application writes data directly to the cache, and the cache synchronously updates the database. Guarantees cache consistency, but increases write latency.
- **Write-Around**: Writes bypass the cache completely and go directly to the primary database. Data only enters the cache upon a subsequent read. Prevents cache pollution from write-heavy data that is rarely re-read.

### Q5: How do you design an API to handle sudden traffic spikes without crashing (Graceful Degradation)?
**Answer:**
1. **Rate Limiting & Throttling**: Reject excess traffic with HTTP 429 using Redis token bucket.
2. **Circuit Breakers**: Stop calling degraded downstream services (e.g. LLMs) and return graceful fallback responses.
3. **Queue Buffering**: Enqueue incoming jobs into Kafka/RabbitMQ so workers process at a steady, sustainable rate rather than crashing under concurrency spikes.
4. **Load Shedding**: Reject low-priority background requests (telemetry, analytics) to preserve CPU and connections for critical user-facing read/write flows.
