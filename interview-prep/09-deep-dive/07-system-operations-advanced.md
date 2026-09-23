# System design, DevOps aur role-specific advanced concepts

[Roadmap](../README.md) · [Worked system design](../00-start-here/05-system-design-quick-guide.md)

## 1. Sizing: users, requests, concurrency alag hain

1M requests/day ≈ 11.6 average requests/sec; 1M requests/sec radically different system. Peak multiplier, request mix, payload and latency assumptions bolo. Little's Law steady-state approximation: in-flight work ≈ arrival rate × average time. 100 req/sec × 0.2 sec ≈ 20 in-flight; 50k idle sockets ka same CPU load assume mat karo.

Capacity benchmark actual mix/connection limits/DB work se aata hai, framework name se nahi. Rate limit inbound demand, concurrency limit in-flight operations, backpressure upstream producer ko slow/reject karna. Queue unbounded backlog solve nahi karti; arrival sustained service capacity se high ho toh delay grows.

## 2. Caches and Redis

Cache-aside, read-through, write-through, write-behind different consistency/write-failure trade-offs. Cache key tenant/user/version/filter include where needed. TTL staleness bound ki policy hai; updates invalidate/version, TTL jitter avoids synchronized expiry. Cache stampede single-flight/lease + stale-while-revalidate where acceptable. Hot-key capacity and sensitive-data leakage test karo.

Redis strings/counters, hashes, sets, sorted sets and streams useful hain. Atomic increment + expiry must be coordinated for limiter; two separate commands crash gap create kar sakti hain. Sliding window precise but memory cost; token bucket bursts allow karta hai. Multi-instance limiter shared state use kare; local dict per instance global rate limit nahi.

Redis Pub/Sub missed messages replay nahi karta. Streams/log durability config and consumer acknowledgment matter. Redis “in-memory” ka matlab persistence impossible nahi; RDB/AOF/failover settings data-loss window decide karti hain.

## 3. Queue vs Kafka, ordering and exactly-once

Task queue work distribution ke liye; log stream independent consumers/replay ke liye. Kafka topic partitions parallelism + per-partition order dete hain. Stable key/partitioning policy needed; partition count change mappings affect kar sakta hai. Processing concurrency can reorder completion even when log records ordered. Consumer lag offset distance hai, business delay measure bhi useful.

Producer idempotence/transactions bounded Kafka guarantees de sakte hain; external email/payment/DB side effects automatically exactly-once nahi. Event ID dedup + transaction/outbox + reconciliation explain karo. Saga multi-service steps + compensating actions; compensation business recovery hai, DB rollback jaisa perfect inverse necessary nahi.

## 4. Real-time: polling, SSE, WebSocket

| Method | Use | Nuance |
|---|---|---|
| Polling | low-frequency updates | persistent HTTP connections may reuse; not every poll fresh TLS |
| SSE | server → client text events | EventSource reconnect; fetch-stream clients own reconnect/parser |
| WebSocket | bidirectional low-latency messages | auth, origin, heartbeat, bounded buffers |
| WebRTC | real-time media/peer communications | signaling, NAT traversal, relay may be needed |

Native browser EventSource/WebSocket APIs don't offer arbitrary header configuration like fetch. Choose suitable cookie/session or short-lived ticket; avoid long-lived tokens in logged URLs. Verify Origin + room/resource permission. One connection belongs to one process; pub/sub fanout can notify remote instance, but delivery durability needs storage and replay cursor.

Slow client send must not indefinitely block entire room broadcast: bounded per-client queue/drop/disconnect policy. Track listener tasks, close subscriptions when room empty, cancel on shutdown. Heartbeat interval under configured proxy idle limits, bounded reconnection backoff+jitter. Browser JS doesn't expose protocol ping-frame API; server/library heartbeat or application-level messages choose karo.

## 5. Docker, Kubernetes, cloud

Container process isolation uses kernel facilities; VM has guest kernel. Docker Desktop Linux containers macOS par Linux VM ke through run karte hain. Image immutable template; container running instance, writable layer ephemeral; durable data volumes/external store mein.

Dockerfile: dependency files before source for cache, multi-stage build final image minimal, non-root where practical, secrets runtime/BuildKit secret mounts. Secret mount ka content manually file/log mein copy kiya toh leak still possible. Healthcheck command image mein installed hona chahiye; old examples mein `curl` missing ho sakta tha. Pin/review dependencies and base image, don't blindly choose Alpine if binary compatibility hurts.

K8s: Pod execution unit; Deployment rollout/replicas; Service stable service discovery; Ingress controller HTTP routing; ConfigMap configuration; Secret secret material (base64 alone encryption nahi). Liveness restart decision, readiness traffic eligibility, startup initialization gate. Thresholds configurable, “3 failures always” nahi.

Dependency outage par every liveness fail karna restart storm bana sakta hai. Readiness critical paths reflect kare, noncritical optional Redis fail par all pods remove karna sensible nahi always. Graceful shutdown: stop new traffic, drain in-flight, bound shutdown deadline, close resources. Existing WebSockets and long jobs need explicit behavior.

Cloud selection: region, team expertise, service constraints, recovery goals, cost incl egress, observability and lock-in. AWS/GCP/PaaS mein universal winner nahi; vendor choice automatic compliance/zero-downtime guarantee nahi. Managed DB backup + failover + replicas different capabilities. RPO allowed data loss; RTO restore time; restore drill verify karo.

## 6. CI/CD and safe migrations

Pipeline: reproducible dependencies → lint/types → relevant tests → build → staging smoke → controlled rollout → monitor. Schema-compatible old/new deployments, versioned contracts, feature flags and rollback plan. Blue/green/canary extra capacity/operational complexity trade-off.

Expand/contract: add compatible field, dual-write strategy, ensure old writers migrated, batched resumable backfill, validate consistency, switch reads, retire old writers/readers, later drop. Fixed 48 hours wait correctness proof nahi. Backfill existing non-null new field overwrite na kare; old writers racing backfill handled explicitly. DDL metadata-only ho toh bhi locks needed ho sakte hain. Concurrent index creation less blocking, not zero impact. [PostgreSQL CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html).

Monorepo shared changes/codegen easy kar sakti hai; separate deployed versions still drift kar sakti hain. Remote cache inputs/environment/secrets correctly scope; cache artifact trusted boundary. OpenAPI codegen runtime validation and compatibility checks replace nahi karta.

## 7. Git and team judgment

Merge can fast-forward or create merge commit; rebase replay commits and change IDs. Shared history rewrite team coordination without mat karo. Revert inverse commit shared history mein useful; reset moves local ref and mode affects index/worktree. Reflog local ref movements recover karne mein useful until expiry/pruning, remote permanent backup nahi.

Conflict solve intended behavior understand karke; tests run. Review explain why, small coherent PR, rollback risk. ADR: context/options/decision/consequences. Package choice need, compatibility, maintenance, security, actual bundle/runtime cost and organization license process se evaluate—download-count threshold security proof nahi.

## 8. MongoDB vs PostgreSQL (role-specific)

Document store embedded bounded aggregate access simplify kar sakta hai; unbounded collections references. PostgreSQL relationships/constraints/transactions strong; JSONB flexible attributes support. NoSQL “no schema/no transactions” false; MongoDB validation/transactions exist. Join/query plans and index selectivity there too; collection scan not automatically wrong for tiny/full-scan workload.

Driver/version verify: Motor is deprecated in favor of PyMongo Async; old Motor setup ko new-project default mat memorize karo. [MongoDB driver notice](https://www.mongodb.com/docs/drivers/motor/). Arbitrary writes/sec/vector-count thresholds architecture laws nahi; measured workload and operations decide.

## 9. RAG / LLM systems (only relevant role)

Ingest file → validate/parse → chunks + metadata/ACL → embeddings → search index. Query → permission-filtered retrieval → optional keyword/vector fusion → rerank → bounded context → answer with source links. Retrieval quality and generation faithfulness separate evaluate: representative labeled queries, recall@k, relevance, groundedness, latency/cost.

Chunk size/overlap and top-k dataset-dependent. Hybrid retrieval exact terms and semantics combine kar sakti hai; native PostgreSQL `ts_rank` is not BM25. HNSW approximate retrieval memory/build/recall trade-off; no fixed O(log n), 99% recall or 5ms guarantee for every workload.

History storage external shared DB/Redis when needed; token budget/summary preserve user intent without elevating untrusted data to instructions. Long-context positional effects model/task dependent. Streaming perceived responsiveness improves, total latency not necessarily. Retry only safe calls, cost budgets, disconnect cancellation and provider limits.

Prompt injection ko delimiters alone stop nahi karte. Tool allowlists, least privilege, tenant filtering, sandboxed execution, validated output, scoped credentials and confirmations for dangerous side effects are real enforcement boundaries. “SQL starts with SELECT” arbitrary query sandbox nahi: functions, stacked statements, expensive reads, tenant spoofing. Prefer fixed parameterized tool operations plus DB roles/RLS/timeouts.

MCP tools/resources/prompts interoperable interface deta hai, authorization magic nahi. Modern transport includes stdio and Streamable HTTP; old HTTP+SSE transport legacy hai. [MCP transports](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports). This guide deliberately excludes old untested “secure SQL runner” code.

## 10. DSA and behavioral depth for 3-year prep

DSA: array/string, hash map, stack/queue, two pointers, sliding window, binary search, intervals, linked list basics, BFS/DFS/tree traversal, heap/top-k, simple DP. For each: input constraints, brute force, invariant, complexity, empty/duplicate/extreme case. [Timed DSA solution](../00-start-here/12-scenario-coding-round.md).

Behavioral: one end-to-end feature, one difficult bug, one performance/quality improvement, one disagreement. Project names in older notes are prompts, not proof of your role or metrics. Actual contribution, constraints, measurement and learning explain karo. “I have 2.5 years, preparing at 3-year depth” honest positioning hai; title inflate karna necessary nahi.

Project worksheet: business goal → users → your scope → diagram → API/data model → auth → failure → tests/deployment → real outcome → what you'd improve. Three-year expectation independent delivery/debugging and defensible choices ho sakti hai; Staff-level internals every role ke liye required nahi.
