# Interview Questions Bank: Databases & System Design

Target Role: Backend / Full-Stack & AI Systems Engineer  
Cross-References: [06-databases-orm.md](../02-fastapi-backend/06-databases-orm.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md) | [16-database-design-principles.md](../07-database-design/16-database-design-principles.md)

---

### Q1: How does a composite B-Tree index work, and what is the "Leftmost Prefix Rule"?
#### Junior Answer:
"A composite index is an index on multiple columns, like `(user_id, created_at)`. You should put all the columns in your WHERE clause into the index."
#### Senior In-Depth Answer:
"A composite B-Tree index sorts rows hierarchically: first by Column 1, then by Column 2 within identical Column 1 values, and so on.  
Under the **Leftmost Prefix Rule**, the query planner can only use the index if the query filters include the leading leftmost column:
- Index on `(org_id, status, created_at)`:
  - `WHERE org_id = 'A'` ➔ **Index Used**
  - `WHERE org_id = 'A' AND status = 'ACTIVE'` ➔ **Index Used**
  - `WHERE status = 'ACTIVE' AND created_at > ...` ➔ **Index CANNOT be used!** (Triggers full table scan because Column 1 was omitted).  
*Ordering Rule:* Always place **exact equality columns first**, followed by **range/inequality columns**, and **sort columns last**."

---

### Q2: What are database isolation levels, and what specific anomalies does each prevent?
#### Junior Answer:
"Isolation levels control how transactions see each other's changes, ranging from Read Uncommitted to Serializable."
#### Senior In-Depth Answer:
"SQL isolation levels prevent specific concurrency read phenomena:
1. **Read Uncommitted**: Allows **Dirty Reads** (reading uncommitted data from a transaction that might rollback).
2. **Read Committed** (Default in Postgres): Prevents Dirty Reads. However, it allows **Non-Repeatable Reads** (re-reading the same row within the same transaction returns different values if another transaction committed an update in between).
3. **Repeatable Read**: Prevents Dirty Reads and Non-Repeatable Reads. In PostgreSQL, it uses MVCC transaction snapshots to also prevent **Phantom Reads** (new rows appearing in range queries).
4. **Serializable**: Strictly simulates serial, non-concurrent execution using Serializable Snapshot Isolation (SSI). It prevents all anomalies (including write skew), but throws serialization failure errors on conflicts, requiring application-level retries."

---

### Q3: Why does using UUID v4 as a Primary Key hurt database performance at scale, and what is the modern solution?
#### Junior Answer:
"UUIDs take 16 bytes instead of 8 bytes like integers, so they use more disk space."
#### Senior In-Depth Answer:
"The main issue is **B-Tree index cache fragmentation**, not just byte size.  
- **UUID v4** is completely random. Successive inserts land randomly across the entire leaf page space of the B-Tree index. Once the table outgrows the database buffer pool RAM, almost every `INSERT` triggers an expensive random disk read to fetch a leaf page into memory, followed by frequent **B-Tree page splits** and index fragmentation.  
- **Modern Solution:** Use **UUID v7** (or ULID). UUID v7 encodes a 48-bit UNIX millisecond timestamp in the high bits and random entropy in the low bits. It is **monotonically increasing** (time-sorted), meaning new inserts append sequentially to the rightmost leaf page of the B-Tree, preserving cache locality and eliminating page splits while retaining global collision-free uniqueness."

---

### Q4: How do you choose between Shared Schema, Schema-per-Tenant, and Database-per-Tenant in a Multi-Tenant SaaS?
#### Junior Answer:
"Shared database is the easiest, but separate database is the most secure."
#### Senior In-Depth Answer:
"It is a strict trade-off between infrastructure cost, operational complexity, and regulatory compliance:
1. **Shared Database, Shared Schema** (with `tenant_id` on every table + PostgreSQL Row-Level Security):
   - *Pros:* Lowest cost, maximum server density, instant cross-tenant analytics, run migrations once.
   - *Cons:* Noisy neighbor problem; strict software-level isolation required.
2. **Shared Database, Schema-per-Tenant** (PostgreSQL Schemas):
   - *Pros:* Logical isolation, easy per-tenant data backup.
   - *Cons:* Schema migration nightmare (running migrations across 5,000 schemas in a loop can take hours and exhaust connection limits).
3. **Database-per-Tenant**:
   - *Pros:* Hard physical isolation (crucial for FinTech/HIPAA), independent scaling and regional data residency.
   - *Cons:* Highest cost, massive idle resource waste for small tenants, complex connection pool routing."

---

### Q5: What is the Cache Stampede (Thundering Herd) problem, and how do you protect against it in production?
#### Junior Answer:
"When the cache expires, all users hit the database at once and crash it. You fix it by increasing the TTL."
#### Senior In-Depth Answer:
"When a high-traffic cached key expires, dozens or hundreds of concurrent requests experience a cache miss at the exact same millisecond. All of them fall back to query the primary database simultaneously, saturating connection pools and CPU.  
*Solutions:*
1. **Distributed Mutex Lock**: The first worker to experience a cache miss acquires a non-blocking Redis lock (`SET lock:key 1 NX EX 5`). Only this worker queries the DB and repopulates the cache; all other workers sleep for 50ms and re-read the cache.
2. **Probabilistic Early Expiration (XFetch algorithm)**: Computes a probabilistic recompute trigger: `now - (beta * delta * ln(random())) > ttl`. As the TTL approaches expiration, the probability that a read worker background-refreshes the cache before it officially expires increases, guaranteeing the cache never goes stale for users."

---

### Q6: How do you design an end-to-end RAG architecture with a 99th percentile latency budget under 600ms?
#### Junior Answer:
"Use FastAPI, a fast vector DB like Qdrant, and stream the LLM answer."
#### Senior In-Depth Answer:
"Break down the end-to-end P99 latency budget across the query path:
1. **FastAPI Gateway & Auth Verification**: $\le 15\text{ms}$ (Stateless JWT verification in memory).
2. **Semantic Cache Check**: $\le 10\text{ms}$ (Redis Vector Search cosine similarity $\ge 0.96$. On hit, stream immediately $\implies$ Total TTFT $< 30\text{ms}$!).
3. **Query Embedding**: $\le 40\text{ms}$ (via local quantized ONNX embedding model or fast API endpoint).
4. **Hybrid Search Fan-Out**: $\le 30\text{ms}$ (Run Qdrant HNSW dense search and BM25 sparse search concurrently via `asyncio.TaskGroup`).
5. **Reciprocal Rank Fusion (RRF) & Re-Ranking**: $\le 25\text{ms}$ (In-process CPU cross-encoder like FlashRank, avoiding external HTTP network hops).
6. **Time-To-First-Token (TTFT) from LLM**: $\le 350\text{ms}$ (Using frontier streaming APIs with `max_tokens` constraints or fast models like Claude 3.5 Haiku / GPT-4o-mini).
7. **FastAPI StreamingResponse (SSE)**: Streams tokens incrementally over HTTP to the frontend with zero response buffering (`X-Accel-Buffering: no`).  
*Total Time to First Token:* $\approx 470\text{ms}$ (well within the 600ms budget!)."
