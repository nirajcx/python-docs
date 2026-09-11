# 12 Senior & Staff Cross-Domain System Design & Debugging Scenarios

> **Target Audience:** FAANG / Tier-1 MNC Staff & Senior Full-Stack, Backend & AI Engineers  
> **Evaluation Bar:** End-to-End System Architecture, Real-World Incidents, Quantitative Sizing, Trade-Off Justifications  
> **Cross-References:** [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md) | [19-high-scale-traffic-and-fintech.md](../04-system-design-dsa/19-high-scale-traffic-and-fintech.md) | [24-llm-serving-pagedattention.md](../03-rag-vector-genai/24-llm-serving-pagedattention.md) | [26-distributed-systems-kafka-saga.md](../04-system-design-dsa/26-distributed-systems-kafka-saga.md)

---

## Scenario 1: Multi-Tenant RAG Platform for 100k+ Users

### 1. Requirements & Assumptions
- **Functional**: Ingest enterprise PDFs, DOCX, and tables; support semantic search and multi-turn conversational chat with verifiable citations.
- **Scale**: 100,000 DAU, 5 queries/user/day $\approx$ 500,000 queries/day (~6 average QPS, 50 peak QPS).
- **Security**: Strict multi-tenancy; users can NEVER retrieve or synthesize answers from another tenant's documents.

### 2. Architecture & Component Flow
```
 Client (Next.js) ──(HTTPS/WSS)──► Cloudflare WAF ──► AWS ALB ──► FastAPI Gateway
                                                                       │
        ┌──────────────────────────────────────────────────────────────┤
        ▼                                                              ▼
 Redis Semantic Cache (Sim >= 0.96)                             Auth Dependency (JWT)
 (Instant Hit: Stream cached answer)                                   │
                                                                       ▼
                                                    Hybrid Fan-Out (asyncio.TaskGroup)
                                                     ├── Qdrant (Single-stage tenant HNSW)
                                                     └── Elasticsearch (BM25 sparse)
                                                                       │
                                                                       ▼
                                                           Reciprocal Rank Fusion (RRF)
                                                                       │
                                                                       ▼
                                                           FlashRank CPU Re-ranking
                                                                       │
                                                                       ▼
                                                           LLM Token Stream (SSE)
```

### 3. Bottlenecks, Failure Modes & Mitigations
- **Bottleneck**: Single-stage HNSW payload filtering performance when a single tenant has $> 1\text{M}$ chunks.
  - *Fix*: Shard Qdrant collections by tenant groups or use dedicated tenant namespaces.
- **Failure Mode**: Downstream LLM API outages (HTTP 503 / 429).
  - *Mitigation*: Circuit breaker tripping to secondary fallback model (Claude 3.5 on Bedrock $\to$ Azure OpenAI) with token-bucket throttlers.
- **Interviewer Follow-Up**: *"How do you handle a tenant deleting their account with 5 million vectors without causing an IO freeze?"*
  - *Staff Answer*: Never delete vectors row-by-row. Partition collections by tenant ID or partition key; dropping a tenant collection/partition in Qdrant is an instantaneous metadata unlinking ($O(1)$) with zero garbage collection overhead.

---

## Scenario 2: High-Throughput FastAPI Service at 100,000 QPS

### 1. Architecture Strategy
1. **Edge Tier (Cloudflare Anycast)**: Terminate TLS at the edge. Cache all static assets and semi-static GET responses.
2. **Compute Tier (Kubernetes HPA)**: 150–200 pods running FastAPI + Uvicorn with `uvloop`. Pods scale based on custom Prometheus metrics (HTTP requests/second).
3. **Database Decoupling**: Mutating writes are **never** written synchronously to PostgreSQL. The API verifies the payload schema, writes an event to **Apache Kafka**, and responds with `HTTP 202 Accepted`.
4. **Read Layer**: Redis Cluster with consistent hashing handles read lookups in $< 1.5\text{ms}$. Cache misses query a pool of **PostgreSQL Read Replicas** fronted by **PgBouncer**.

---

## Scenario 3: Auditable Payment System Preventing Double-Spending

### 1. The Core Invariants
- No race condition can ever deduct more money than an account holds.
- No network retry can ever charge an account twice.
- All balance modifications must be auditable via an immutable general ledger.

### 2. Implementation Blueprint
1. **API Gateway Level**: Require an `Idempotency-Key` UUID. Store execution state in Redis using `SETNX`.
2. **Database Transaction Layer**:
   ```sql
   BEGIN;
   -- 1. Sort account IDs to prevent deadlocks:
   SELECT * FROM accounts WHERE id IN ('acc_A', 'acc_B') ORDER BY id FOR UPDATE;
   
   -- 2. Verify sender balance >= amount
   -- 3. Write immutable general ledger entries (Double-Entry Bookkeeping):
   INSERT INTO ledger (transaction_id, account_id, entry_type, amount) 
   VALUES ('txn_1', 'acc_A', 'DEBIT', 100.00), ('txn_1', 'acc_B', 'CREDIT', 100.00);
   
   -- 4. Update cached balance counters:
   UPDATE accounts SET balance = balance - 100.00 WHERE id = 'acc_A';
   UPDATE accounts SET balance = balance + 100.00 WHERE id = 'acc_B';
   COMMIT;
   ```
- **Interviewer Follow-Up**: *"What if the payment processor (Stripe) charges the user, but your database crashes before committing the ledger?"*
  - *Staff Answer*: Use the **Two-Phase Commit (2PC) or Saga pattern with an Outbox table**. Record the transaction as `PENDING` before invoking Stripe. Stripe webhooks asynchronously update the database state to `CONFIRMED`. If the webhook never arrives, a reconciliation worker queries Stripe's charge API using the idempotency key to resolve the transaction.

---

## Scenario 4: Kafka-Based Document Ingestion & Embedding Pipeline

```
 S3 Upload Event ──► Kafka Topic: 'raw-docs' ──► Parsing Worker (PyMuPDF/OCR)
                                                        │
                                                        ▼
                                             Kafka Topic: 'chunked-docs'
                                                        │
                                                        ▼
                                             Batch Embedding Worker Fleet
                                             (Batches 100 chunks -> OpenAI / vLLM)
                                                        │
                                                        ▼
                                             Upsert to Qdrant Vector Cluster
```
- **Backpressure**: If OpenAI rate limits are approached, embedding workers throttle consumption from Kafka by pausing consumer partitions (`consumer.pause()`) without losing messages.
- **Dead Letter Queue (DLQ)**: Corrupted or password-protected PDFs that fail parsing after 3 retries are routed to `raw-docs-dlq` with stack trace metadata for human review.

---

## Scenario 5: Debugging a Production Python Memory Leak in Kubernetes

### Step-by-Step Production Incident Protocol:
1. **Triage**: Pod exhibits a steady upward memory saw-tooth pattern in Datadog until Linux cgroup issues `SIGKILL` (`Exit Code 137: OOMKilled`).
2. **Non-Invasive Diagnostic**: Attach to a live running pod using **`py-spy`** or **`memray`**:
   ```bash
   memray attach <fastapi_pid> --output /tmp/leak.bin
   ```
3. **Analyze Allocations**: Inspect top memory consumers using `tracemalloc` snapshots:
   - Identify whether leak is in **PyMalloc heap** (Python objects) or **C-extensions** (PyTorch tensors, NumPy, libpq).
4. **Common Culprit Resolution**:
   - Culprit: Global cache or `@lru_cache` on class methods holding `self`.
   - Fix: Replace with function-level caches, sever closure scopes, or configure Gunicorn `--max-requests 5000` worker recycling.

---

## Scenario 6: Debugging PostgreSQL Latency Caused by Locks & Query Plans

### The Scenario: API P99 latency spikes from 35ms to 12,000ms.
1. **Identify Blocked Locks**:
   ```sql
   SELECT blocked_locks.pid AS blocked_pid, blocking_locks.pid AS blocking_pid,
          blocked_activity.query AS blocked_statement, blocking_activity.query AS current_statement_in_blocking_process
   FROM pg_catalog.pg_locks blocked_locks
   JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
   JOIN pg_catalog.pg_locks blocking_locks 
       ON blocking_locks.locktype = blocked_locks.locktype
       AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
       AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
       AND blocking_locks.pid != blocked_locks.pid
   JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
   WHERE NOT blocked_locks.granted;
   ```
2. **Root Cause Analysis**: A long-running analytics query or unindexed foreign key deletion is holding an `ExclusiveLock` on the table, blocking all incoming `SELECT ... FOR UPDATE` rows.
3. **Resolution**: Kill blocking query (`pg_cancel_backend(pid)`), set strict `statement_timeout = '5s'` and `lock_timeout = '2s'` on web sessions, and add missing composite indexes.

---

## Scenario 7: Resilient AI Agent Platform with Tool Failures & Guardrails

```
 User Prompt ──► Input Guardrail (Presidio PII Masking)
                       │
                       ▼
               LangGraph Router Node (Model Selection)
                       │
                       ▼
               Tool Execution Node
                       │
       ┌───────────────┴───────────────┐
       ▼ (Tool Success)                ▼ (Tool Failure / Timeout)
 Output Guardrail               Self-Correction Node
 (Hallucination check)          (Rewrites arguments / selects fallback tool)
       │                               │
       ▼                               └────────► Retry Loop (Max 3)
 Final User Answer
```
- **Tool Failure Handling**: Tools return structured error payloads (`{"error": "DatabaseTimeout", "retryable": true}`) rather than raising unhandled Python exceptions, allowing the agent to reason about alternative approaches.
- **State Checkpointing**: LangGraph stores state in PostgreSQL using `PostgresSaver`. If a container reboots mid-workflow, the user conversation resumes from the exact node state.

---

## Scenario 8: Enterprise RAG with Strict Document-Level Access Control (ACL)

1. **Ingestion**: Documents extracted from Google Drive / SharePoint carry security metadata:
   `metadata: {"allowed_users": ["u123"], "allowed_roles": ["finance_lead", "vp"]}`.
2. **Query Filtering**: JWT token decrypted at gateway; user roles extracted: `user_roles = ["finance_lead"]`.
3. **Single-Stage Filtered Vector Query**:
   ```python
   qdrant_client.search(
       collection_name="docs",
       query_vector=query_emb,
       query_filter=Filter(
           should=[
               FieldCondition(key="allowed_users", match=MatchValue(value=user_id)),
               FieldCondition(key="allowed_roles", match=MatchAny(values=user_roles)),
           ]
       )
   )
   ```
   Ensures unauthorized documents are excluded *before* similarity scoring, making leakage mathematically impossible.

---

## Scenario 9: Next.js + FastAPI Real-Time Streaming AI Application

1. **Frontend**: Next.js Client Component invokes custom hook `useRAGStream`.
2. **Network Protocol**: HTTP GET/POST with `Accept: text/event-stream`.
3. **Backend Pipeline**: FastAPI `StreamingResponse` wrapping an asynchronous generator yielding `data: {"text": "token"}\n\n`.
4. **Infrastructure Guardrail**: NGINX reverse proxy configured with `X-Accel-Buffering: no` to prevent response buffering.
5. **Cancellation Handling**: If the user clicks "Stop Generating", the browser triggers `abortController.abort()`. FastAPI catches `asyncio.CancelledError` and terminates the upstream OpenAI connection immediately, saving GPU tokens.

---

## Scenario 10: Multi-Region Cloud Deployment with Disaster Recovery (RPO=0, RTO<1min)

- **Topology**: **Active-Active** for stateless compute; **Active-Passive with Read Replicas** for databases.
- **DNS Routing**: AWS Route 53 latency-based routing with automated health check failover.
- **Data Persistence**:
  - Primary Region (us-east-1): Read/Write Master PostgreSQL + Redis Primary.
  - Secondary Region (us-west-2): Streaming Async Read Replicas + Redis Replica.
- **RTO / RPO Target**:
  - RPO (Data Loss): $< 1\text{ second}$ (PostgreSQL cross-region streaming replication).
  - RTO (Downtime): $< 60\text{ seconds}$ (Automated promotion of replica to primary via Patroni/Raft).

---

## Scenario 11: Diagnosing an LLM Serving Cluster with KV Cache Memory Pressure

### The Scenario: vLLM cluster returns HTTP 503 / engine queue stalls.
1. **Root Cause**: High concurrency combined with long context lengths ($> 8,192$ tokens) exhaust pre-allocated PagedAttention GPU memory blocks.
2. **Diagnosis**: Inspect vLLM metrics: `vllm:num_requests_waiting` is high while `vllm:gpu_cache_usage_factor` sits at $1.0$.
3. **Mitigations**:
   - Enable **Chunked Prefill**: Breaks long prompts into smaller computational chunks so decode tokens are not starved.
   - Adjust `max_num_batched_tokens` and `max_num_seqs`.
   - Implement **Prefix Caching** (`enable_prefix_caching=True`): Reuses KV cache blocks for identical system prompts across multiple users.

---

## Scenario 12: Diagnosing React & React Native Performance Degradation

### Diagnosis Checklist:
1. **Profile with React DevTools**: Identify components re-rendering on every parent update; inspect "Why did this render?".
2. **Fix Keystroke Latency**: Convert controlled inputs to **React Hook Form (uncontrolled inputs with refs)**.
3. **Mobile FlatList Jitter**:
   - Provide explicit `getItemLayout` to bypass layout measurements.
   - Reduce `windowSize = 5`.
   - Move complex gesture animations to **Reanimated 3 UI-thread worklets**.
   - Enable **Hermes Engine** with ahead-of-time bytecode pre-compilation.
