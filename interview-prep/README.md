# Python / FastAPI + AI & RAG Interview Preparation Master Hub

Target Role: **Mid / Senior Python, FastAPI, and GenAI/RAG Developer**  
Candidate Background: **3 Years Full-Stack Experience (React/Next.js/React Native + Node.js/Express, transitioning to Python/FastAPI/GenAI)**

---

## 🗺️ Master Study Roadmap & Architecture

```
interview-prep/
├── README.md                                  # You are here: Master Roadmap & Strategy
│
├── 01-python-core/
│   ├── 01-python-fundamentals.md              # Data types, mutability, decorators, generators, GIL, memory
│   ├── 02-python-oop.md                       # Classes, MRO, dunder methods, ABCs, dataclasses, composition
│   ├── 03-python-async.md                     # asyncio, event loop, coroutines, thread vs process vs async
│   └── 21-memory-optimization-and-leaks.md    # PyMalloc arenas, GC cycles, tracemalloc, cgroups OOMKilled, React leaks
│
├── 02-fastapi-backend/
│   ├── 04-fastapi-core.md                     # Params, Pydantic v2, DI, middleware, exceptions, async routes
│   ├── 05-fastapi-advanced.md                 # Auth (JWT/OAuth2), WebSockets, streaming, testing, deployment
│   └── 06-databases-orm.md                    # SQL joins/indexes, SQLAlchemy 2.0 (async), Alembic, PG vs NoSQL
│
├── 03-rag-vector-genai/
│   ├── 07-rag-fundamentals.md                 # Architecture, chunking, embeddings, similarity, end-to-end flow
│   ├── 08-vector-databases.md                 # ANN, HNSW, IVF, Chroma/Qdrant/Pinecone/FAISS, hybrid search
│   ├── 09-rag-advanced.md                     # Re-ranking, query rewrite, multi-query, Ragas eval, agentic RAG
│   └── 10-llm-integration.md                  # Prompts, function calling, LangChain vs LangGraph vs raw API, Ollama vs OpenAI
│
├── 04-system-design-dsa/
│   ├── 11-system-design-basics.md             # REST, Redis caching, queues (Celery/RabbitMQ), end-to-end RAG system design
│   ├── 12-dsa-essentials.md                   # Arrays, hashmaps, two pointers, sliding window, recursion
│   └── 19-high-scale-traffic-and-fintech.md   # 1K-100K QPS scaling, flash sales, fintech double-spending, 1M vector batch
│
├── 05-behavioral/
│   └── 13-project-talking-points.md           # STAR templates for Siraaj AI, Wishan, ERP & RAG setups
│
├── 06-frontend-react/
│   ├── 14-react-core-architecture.md          # Fiber Reconciler, Hooks deep dive, useRAGStream hook, Zustand vs Redux
│   ├── 15-nextjs-and-react-native.md          # RSC vs SSR, Hydration, React Native New Architecture (JSI/Fabric), Offline Sync
│   └── 18-react-ecosystem-libraries.md        # Axios interceptors/refresh queue, TanStack Query, React Hook Form, Edge Runtime
│
├── 07-database-design/
│   ├── 16-database-design-principles.md       # Normalization 1NF-BCNF, UUIDv7 vs BIGINT, Indexing, Multi-Tenancy & Partitioning
│   └── 20-advanced-database-engineering-and-migrations.md # B-Tree page splits, EXPLAIN BUFFERS, backfill scripts, zero-downtime Alembic
│
├── 08-sdlc-engineering/
│   └── 17-sdlc-devops-practices.md            # Trunk-Based Git, CI/CD, Testing Pyramid, Observability, OWASP Security
│
└── questions-bank/                            # 🎯 DEDICATED HIGH-YIELD QUESTIONS & MODEL ANSWERS
    ├── 01-python-fastapi-questions.md         # GIL, async def vs def, DI cleanup, Pydantic v2, SSE NGINX gotchas
    ├── 02-react-frontend-questions.md         # Fiber, hook rules, RSC vs SSR, hydration errors, Fabric/TurboModules
    ├── 03-rag-genai-questions.md              # Cosine vs Dot Product, single-stage HNSW, Bi vs Cross-encoders, Ragas
    ├── 04-database-system-design-questions.md # Leftmost prefix rule, isolation levels, UUIDv7, multi-tenancy, RAG latency budget
    ├── 05-sdlc-behavioral-questions.md        # Trunk-based vs GitFlow, blameless post-mortems, tech disagreements, zero-downtime
    ├── 06-scale-fintech-scenarios-questions.md # 1K-100K QPS scaling math, flash sales, double-spend prevention, 1M vector batch
    ├── 07-react-ecosystem-nextjs-questions.md # Axios token refresh queue, TanStack Query, React Hook Form, Edge runtime
    └── 08-mnc-tier1-deep-dive-questions.md    # Grammar-Constrained Decoding, EXPLAIN BUFFERS, PyMalloc arenas, KV cache VRAM sizing
```

---

## 📌 Complete Curriculum Quick Reference

| Module | File Link | Primary Focus |
|---|---|---|
| **Python Core** | [01-python-fundamentals.md](./01-python-core/01-python-fundamentals.md) | Mutability, closures, decorators, generators, GIL, memory |
| **Python Core** | [02-python-oop.md](./01-python-core/02-python-oop.md) | Dunders, MRO C3 Linearization, ABCs, dataclasses, composition |
| **Python Core** | [03-python-async.md](./01-python-core/03-python-async.md) | `asyncio`, Event loop, Task cancellation, concurrency models |
| **Memory Systems**| [21-memory-optimization-and-leaks.md](./01-python-core/21-memory-optimization-and-leaks.md) | PyMalloc arenas/pools, reference cycles, tracemalloc, cgroups OOMKilled, React leaks |
| **FastAPI** | [04-fastapi-core.md](./02-fastapi-backend/04-fastapi-core.md) | Routing, Pydantic v2 validation, `Depends()`, middleware |
| **FastAPI** | [05-fastapi-advanced.md](./02-fastapi-backend/05-fastapi-advanced.md) | JWT, WebSockets, streaming, Pytest + TestClient, Docker |
| **Databases** | [06-databases-orm.md](./02-fastapi-backend/06-databases-orm.md) | Indexing, SQLAlchemy 2.0 Async, Alembic migrations |
| **RAG & GenAI** | [07-rag-fundamentals.md](./03-rag-vector-genai/07-rag-fundamentals.md) | Chunking strategies, dense embeddings, cosine similarity |
| **RAG & GenAI** | [08-vector-databases.md](./03-rag-vector-genai/08-vector-databases.md) | HNSW, IVF, Qdrant/Chroma/Pinecone, BM25 hybrid search |
| **RAG & GenAI** | [09-rag-advanced.md](./03-rag-vector-genai/09-rag-advanced.md) | Flashrank/Cohere reranking, query decomposition, Ragas |
| **RAG & GenAI** | [10-llm-integration.md](./03-rag-vector-genai/10-llm-integration.md) | Tool calling, LangGraph vs raw HTTP, token optimization |
| **System Design**| [11-system-design-basics.md](./04-system-design-dsa/11-system-design-basics.md) | Redis caching, Celery/Redis queues, Full RAG System Design |
| **DSA** | [12-dsa-essentials.md](./04-system-design-dsa/12-dsa-essentials.md) | High-frequency patterns for backend & AI coding rounds |
| **Scale & FinTech**| [19-high-scale-traffic-and-fintech.md](./04-system-design-dsa/19-high-scale-traffic-and-fintech.md) | 1K-100K QPS scaling, flash sales, double-spend prevention, 1M vector batch |
| **Behavioral** | [13-project-talking-points.md](./05-behavioral/13-project-talking-points.md) | STAR framework for Siraaj, Wishan, ERP & GenAI work |
| **Frontend** | [14-react-core-architecture.md](./06-frontend-react/14-react-core-architecture.md) | Fiber reconciler, Hooks under the hood, RAG stream hook, Zustand |
| **Frontend** | [15-nextjs-and-react-native.md](./06-frontend-react/15-nextjs-and-react-native.md) | RSC vs SSR, hydration errors, JSI/Fabric/TurboModules, offline sync |
| **Frontend** | [18-react-ecosystem-libraries.md](./06-frontend-react/18-react-ecosystem-libraries.md) | Axios interceptor refresh queue, TanStack Query, React Hook Form + Zod, Edge Runtime |
| **Database Design**| [16-database-design-principles.md](./07-database-design/16-database-design-principles.md) | Normalization 1NF-BCNF, UUIDv7 vs BIGINT, indexing, multi-tenancy |
| **DB Engineering**| [20-advanced-database-engineering-and-migrations.md](./07-database-design/20-advanced-database-engineering-and-migrations.md) | B-Tree page splits, EXPLAIN BUFFERS, backfill scripts, zero-downtime Alembic |
| **SDLC & DevOps**| [17-sdlc-devops-practices.md](./08-sdlc-engineering/17-sdlc-devops-practices.md) | Trunk-based Git, CI/CD, testing pyramid, observability, OWASP |

---

## 🎯 Dedicated High-Yield Interview Questions Bank

| Topic | File Link | Focus Questions |
|---|---|---|
| **Python & FastAPI** | [01-python-fastapi-questions.md](./questions-bank/01-python-fastapi-questions.md) | GIL, `def` vs `async def`, dependency cleanup with `yield`, Pydantic v2, SSE NGINX gotchas, memory leak debugging. |
| **React, Next.js & Mobile** | [02-react-frontend-questions.md](./questions-bank/02-react-frontend-questions.md) | Fiber reconciliation, Hook linked lists, RSC vs SSR, hydration fixes, React Native JSI vs Bridge, offline sync outbox. |
| **RAG, Vectors & GenAI** | [03-rag-genai-questions.md](./questions-bank/03-rag-genai-questions.md) | Cosine vs Dot Product math, single-stage filtered HNSW, Bi vs Cross-encoders, RRF hybrid formula, Ragas evaluation, prompt injection. |
| **Databases & System Design**| [04-database-system-design-questions.md](./questions-bank/04-database-system-design-questions.md) | Composite index leftmost prefix, isolation levels (ACID), UUIDv7 B-Tree locality, multi-tenancy SaaS models, cache stampede locks. |
| **SDLC & Behavioral** | [05-sdlc-behavioral-questions.md](./questions-bank/05-sdlc-behavioral-questions.md) | Trunk-based vs GitFlow, blameless post-mortem framework, technical disagreement STAR story, zero-downtime migrations, AI non-determinism. |
| **Scale & FinTech Scenarios** | [06-scale-fintech-scenarios-questions.md](./questions-bank/06-scale-fintech-scenarios-questions.md) | 1K-100K QPS scaling math, double-spend prevention, flash sales (50k reqs in 10s), idempotency keys, bulk 1M vector ingestion. |
| **React Ecosystem & Next.js**| [07-react-ecosystem-nextjs-questions.md](./questions-bank/07-react-ecosystem-nextjs-questions.md) | Axios concurrent 401 refresh queue, TanStack Query staleTime vs gcTime, React Hook Form, Edge vs Node runtime, Core Web Vitals. |
| **MNC Tier-1 Deep Dive** | [08-mnc-tier1-deep-dive-questions.md](./questions-bank/08-mnc-tier1-deep-dive-questions.md) | Grammar-Constrained Decoding, reading EXPLAIN (ANALYZE, BUFFERS), CPython PyMalloc Arenas, KV Cache VRAM sizing formula, Lost Update fixes. |
