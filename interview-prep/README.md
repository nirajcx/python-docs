# Python / FastAPI + AI & RAG Interview Preparation Master Hub

Target Role: **Staff / Senior Python, FastAPI, Distributed Systems and GenAI/RAG Engineer**  
Candidate Background: **3 Years Full-Stack Experience (React/Next.js/React Native + Node.js/Express, transitioning to Python/FastAPI/GenAI/Distributed Systems)**  
Standard: **FAANG / Tier-1 MNC Systems & AI Architecture**

---

## 🗺️ Master Study Roadmap & Architecture

```
interview-prep/
├── README.md                                  # You are here: Master Roadmap & FAANG Matrix
│
├── 01-python-core/                            # 🐍 PYTHON INTERNALS & RUNTIME
│   ├── 01-python-fundamentals.md              # Data types, mutability, decorators, generators, GIL, memory
│   ├── 02-python-oop.md                       # Classes, MRO, dunder methods, ABCs, dataclasses, composition
│   ├── 03-python-async.md                     # asyncio, event loop, coroutines, thread vs process vs async
│   ├── 21-memory-optimization-and-leaks.md    # PyMalloc arenas, GC cycles, tracemalloc, cgroups OOMKilled, React leaks
│   └── 22-cpython-interpreter-and-descriptors.md # CPython 3.11+ PEP 659, descriptors, metaclasses, typing, packaging
│
├── 02-fastapi-backend/                        # ⚡ FASTAPI & BACKEND SYSTEMS
│   ├── 04-fastapi-core.md                     # Params, Pydantic v2, DI, middleware, exceptions, async routes
│   ├── 05-fastapi-advanced.md                 # Auth (JWT/OAuth2), WebSockets, streaming, testing, deployment
│   ├── 06-databases-orm.md                    # SQL joins/indexes, SQLAlchemy 2.0 (async), Alembic, PG vs NoSQL
│   └── 23-asgi-internals-and-redis-ratelimit.md # ASGI specification, scope/receive/send, Pydantic Rust core, Lua rate limiter
│
├── 03-rag-vector-genai/                       # 🧠 RAG, VECTOR SEARCH & LLM SERVING
│   ├── 07-rag-fundamentals.md                 # Architecture, chunking, embeddings, similarity, end-to-end flow
│   ├── 08-vector-databases.md                 # ANN, HNSW, IVF, Chroma/Qdrant/Pinecone/FAISS, hybrid search
│   ├── 09-rag-advanced.md                     # Re-ranking, query rewrite, multi-query, Ragas eval, agentic RAG
│   ├── 10-llm-integration.md                  # Prompts, function calling, LangChain vs LangGraph, Ollama vs OpenAI
│   ├── 24-llm-serving-pagedattention.md       # Prefill vs decode, KV cache sizing math, PagedAttention, vLLM, LoRA/DPO
│   └── 25-genai-security-and-guardrails.md    # Context engineering, Lost-in-the-Middle, LangGraph, prompt injection, ACLs
│
├── 04-system-design-dsa/                      # 🏗️ SYSTEM DESIGN, DISTRIBUTED SYSTEMS & DSA
│   ├── 11-system-design-basics.md             # REST, Redis caching, queues (Celery/RabbitMQ), end-to-end RAG design
│   ├── 12-dsa-essentials.md                   # Arrays, hashmaps, two pointers, sliding window, recursion
│   ├── 19-high-scale-traffic-and-fintech.md   # 1K-100K QPS scaling, flash sales, fintech double-spending, 1M vector batch
│   ├── 26-distributed-systems-kafka-saga.md   # Redlock critique, Fencing Tokens, Saga vs 2PC, Outbox pattern, Kafka vs RabbitMQ
│   └── 28-advanced-dsa-faang-patterns.md      # Binary search on answer, Monotonic stack, Trie, Union-Find, Topological sort
│
├── 05-behavioral/                             # 🎯 BEHAVIORAL & INTEGRATED SCENARIOS
│   ├── 13-project-talking-points.md           # STAR templates for Siraaj AI, Wishan, ERP & RAG setups
│   └── 29-faang-cross-domain-interview-scenarios.md # 12 Comprehensive Staff scenarios across RAG, 100k QPS, FinTech & Leaks
│
├── 06-frontend-react/                         # ⚛️ REACT, NEXT.JS & REACT NATIVE
│   ├── 14-react-core-architecture.md          # Fiber Reconciler, Hooks deep dive, useRAGStream hook, Zustand vs Redux
│   ├── 15-nextjs-and-react-native.md          # RSC vs SSR, Hydration, React Native New Architecture (JSI/Fabric), Offline Sync
│   ├── 18-react-ecosystem-libraries.md        # Axios interceptors/refresh queue, TanStack Query, React Hook Form, Edge Runtime
│   └── 27-microfrontends-and-rsc-internals.md # Module Federation, RSC Flight wire protocol, Hermes bytecode, Reanimated worklets
│
├── 07-database-design/                        # 🗄️ DATABASE DESIGN & ENGINEERING
│   ├── 16-database-design-principles.md       # Normalization 1NF-BCNF, UUIDv7 vs BIGINT, Indexing, Multi-Tenancy & Partitioning
│   └── 20-advanced-database-engineering-and-migrations.md # B-Tree page splits, EXPLAIN BUFFERS, backfill scripts, zero-downtime Alembic
│
├── 08-sdlc-engineering/                       # 🚀 SDLC, DEVOPS & OBSERVABILITY
│   └── 17-sdlc-devops-practices.md            # Trunk-Based Git, CI/CD, Testing Pyramid, Observability, OWASP Security
│
└── questions-bank/                            # 💡 9 DEDICATED HIGH-YIELD QUESTION BANKS
    ├── 01-python-fastapi-questions.md         # GIL, async def vs def, DI cleanup, Pydantic v2, SSE NGINX gotchas
    ├── 02-react-frontend-questions.md         # Fiber, hook rules, RSC vs SSR, hydration errors, Fabric/TurboModules
    ├── 03-rag-genai-questions.md              # Cosine vs Dot Product, single-stage HNSW, Bi vs Cross-encoders, Ragas
    ├── 04-database-system-design-questions.md # Leftmost prefix rule, isolation levels, UUIDv7, multi-tenancy, RAG latency budget
    ├── 05-sdlc-behavioral-questions.md        # Trunk-based vs GitFlow, blameless post-mortems, tech disagreements, zero-downtime
    ├── 06-scale-fintech-scenarios-questions.md # 1K-100K QPS scaling math, flash sales, double-spend prevention, 1M vector batch
    ├── 07-react-ecosystem-nextjs-questions.md # Axios token refresh queue, TanStack Query, React Hook Form, Edge runtime
    ├── 08-mnc-tier1-deep-dive-questions.md    # Grammar-Constrained Decoding, EXPLAIN BUFFERS, PyMalloc arenas, KV Cache math
    └── 09-faang-staff-systems-and-ai-questions.md # PEP 659, Redlock critique, Continuous Batching, ASGI scope/send, RSC Flight, Kafka EOS
```

---

## 📊 FAANG / Tier-1 MNC Coverage Matrix

| Area | Existing Coverage | New / Upgraded Coverage | Interview Depth |
|---|---|---|---|
| **Python Core** | Mutability, OOP, AsyncIO, Memory Leaks | CPython 3.11+ PEP 659 Adaptive Specializing Interpreter, Bytecode disasm, Descriptors, Metaclasses vs `__init_subclass__`, Generics, Covariance/Contravariance, `pyproject.toml`, Hypothesis testing | **Staff Level**: VM evaluation loop, C structs, and typing invariants |
| **FastAPI** | Params, Pydantic v2, DI, Auth, Testing | ASGI 3.0 specification (`scope`, `receive`, `send`), Starlette vs Uvicorn lifecycle, `pydantic-core` Rust engine, Atomic Redis Lua token bucket rate limiter, gRPC vs REST, Circuit Breakers | **Staff Level**: Network protocol frames, concurrency safety |
| **PostgreSQL** | Basic joins, B-Tree, SQLAlchemy 2.0 | B-Tree 8KB page splits, GIN/BRIN/Hash tradeoffs, `EXPLAIN (ANALYZE, BUFFERS)` execution plans, Autovacuum dead tuple bloat tuning, keyset pagination backfills, zero-downtime Alembic migrations | **Staff Level**: Storage engines, physical page buffers, CBO optimizer |
| **Redis** | Basic cache-aside, semantic cache | Atomic Lua scripts, distributed locks & Kleppmann's Redlock critique, Fencing Tokens, sliding window logs, Redis Cluster hash tags `{user_id}` | **Staff Level**: Mutual exclusion, cluster slot routing |
| **Kafka** | Celery / RabbitMQ overview | Append-only commit log, Partitioning, Consumer Group Cooperative Sticky rebalancing, Exactly-Once Semantics (EOS) via Transactional API, Outbox Pattern with Debezium CDC | **Staff Level**: Distributed logs, delivery semantics |
| **RAG Systems** | Basic chunking, embeddings, similarity | Context Window budgeting (Lost-in-the-Middle), Sentence Window retrieval, LLMLingua token pruning, Multimodal RAG (table extraction), ACL-aware vector filtering | **Staff Level**: Attention distribution, token economics |
| **LLM Inference** | Basic API calls, LangChain vs LangGraph | Prefill vs Decode phases (Compute vs Memory-Bandwidth bound), KV Cache mathematical sizing, PagedAttention (vLLM virtual paging), Continuous Batching, Speculative Decoding, LoRA math, DPO alignment | **Staff Level**: GPU hardware architecture, tensor memory math |
| **System Design**| 100k DAU RAG, Caching, Queues | 1K to 100K QPS scaling math, Flash Sales (50k req/10s), Double-spending prevention (pessimistic row locking with deadlock ordering, double-entry ledgers), Consistent Hashing with vnodes, PACELC theorem, Active-Active DR | **Staff Level**: Extreme scale, distributed consensus |
| **React / Next.js**| Fiber reconciler, Hooks, SSR/RSC | Module Federation micro-frontends, RSC Flight Wire Protocol disassembly (`0:HL...`, `1:I...`), Server Actions CSRF protection, Axios concurrent 401 refresh queues, TanStack Query optimistic updates, React Hook Form $O(1)$ renders | **Staff Level**: Wire protocols, browser main-thread scheduling |
| **React Native** | Legacy bridge vs New Architecture | Hermes AOT bytecode compilation (`.hbc`), FlatList virtualization (`getItemLayout`, `windowSize`), Reanimated 3 UI-thread worklets, native-module memory leak prevention | **Staff Level**: C++ JSI bindings, mobile OS thread scheduling |
| **DevOps & Cloud**| Docker multi-stage, Git branching | Kubernetes liveness vs readiness probes, HPA custom metrics, Zero-downtime expand/contract releases, OpenTelemetry distributed tracing, blameless post-mortems | **Staff Level**: SRE practices, high availability |
| **Security** | JWT auth, rate limiting | OWASP Top 10 for LLMs, Indirect Prompt Injection, Markdown image data exfiltration, BOLA/IDOR tenant isolation, Presidio PII redaction | **Staff Level**: Defense in depth, adversarial AI |
| **DSA** | Light two-pointer, sliding window, heaps | Binary search on answer space, Monotonic stack, Trie, Union-Find (DSU with path compression & rank), Topological Sort (Kahn's), Dynamic Programming, Intervals | **Staff Level**: Optimal time/space proofs |

---

## 🎯 Quick Navigation Links

- **CPython VM & Descriptors**: [22-cpython-interpreter-and-descriptors.md](./01-python-core/22-cpython-interpreter-and-descriptors.md)
- **ASGI & Redis Lua Rate Limiting**: [23-asgi-internals-and-redis-ratelimit.md](./02-fastapi-backend/23-asgi-internals-and-redis-ratelimit.md)
- **LLM Serving & PagedAttention**: [24-llm-serving-pagedattention.md](./03-rag-vector-genai/24-llm-serving-pagedattention.md)
- **GenAI Security & Guardrails**: [25-genai-security-and-guardrails.md](./03-rag-vector-genai/25-genai-security-and-guardrails.md)
- **Kafka, Saga & Consensus**: [26-distributed-systems-kafka-saga.md](./04-system-design-dsa/26-distributed-systems-kafka-saga.md)
- **Micro-Frontends & RSC Flight**: [27-microfrontends-and-rsc-internals.md](./06-frontend-react/27-microfrontends-and-rsc-internals.md)
- **Advanced FAANG DSA**: [28-advanced-dsa-faang-patterns.md](./04-system-design-dsa/28-advanced-dsa-faang-patterns.md)
- **12 Integrated Staff Scenarios**: [29-faang-cross-domain-interview-scenarios.md](./05-behavioral/29-faang-cross-domain-interview-scenarios.md)
- **Staff Systems & AI Question Bank**: [09-faang-staff-systems-and-ai-questions.md](./questions-bank/09-faang-staff-systems-and-ai-questions.md)
