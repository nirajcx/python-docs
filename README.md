# Python, FastAPI, GenAI & Full-Stack Engineering Knowledge Base

> **Target Roles:** Mid / Senior Python & FastAPI Backend Developer, AI/RAG Engineer, Full-Stack Engineer  
> **Candidate Profile:** 3 Years Professional Experience (React / Next.js / React Native + Node.js / Express, transitioning to Python, FastAPI, Vector DBs, and GenAI / RAG)

---

## 📌 Repository Overview

This repository contains an end-to-end, interview-ready engineering study curriculum located inside [`/interview-prep/`](./interview-prep/README.md).

Every module is written with senior engineering rigor:
- **Under-the-Hood Mechanics**: Memory layouts, CPython bytecode, Fiber reconcilers, and HNSW graph traversal.
- **Junior vs. Senior Perspectives**: Distinguishing standard textbook answers from senior, production-tested answers.
- **Production Gotchas**: Real-world traps (e.g. mutable default arguments, event loop blocking, hydration mismatches, vector $k$-shortage bugs).
- **Practical Code & Diagrams**: Type-safe Python 3.11+, Pydantic v2, modern SQLAlchemy 2.0 Async, and custom React hooks.
- **Questions & Answers**: 5–8 high-yield interview questions per topic plus a dedicated **Interview Questions Bank**.

---

## 🗺️ Curriculum Structure

```
python-docs/
├── README.md                                  # You are here: Repository Overview
└── interview-prep/
    ├── README.md                              # Master Study Roadmap & Quick Matrix
    │
    ├── 01-python-core/                        # 🐍 PYTHON INTERNALS & CORE
    │   ├── 01-python-fundamentals.md          # Mutability, comprehensions, decorators, generators, GIL & memory
    │   ├── 02-python-oop.md                   # Classes, MRO (C3 Linearization), dunders, ABCs, dataclasses
    │   └── 03-python-async.md                 # Event loop, Node vs Python async, TaskGroup, thread offloading
    │
    ├── 02-fastapi-backend/                    # ⚡ FASTAPI & BACKEND
    │   ├── 04-fastapi-core.md                 # Routing, Pydantic v2 validation, Depends() DI, async vs def
    │   ├── 05-fastapi-advanced.md             # JWT/OAuth2, SSE token streaming, WebSockets, testing, Docker
    │   └── 06-databases-orm.md                # SQL indexing, SQLAlchemy 2.0 Async, N+1 problem, Alembic
    │
    ├── 03-rag-vector-genai/                   # 🧠 RAG & GENERATIVE AI
    │   ├── 07-rag-fundamentals.md             # RAG architecture, chunking, embeddings, similarity math
    │   ├── 08-vector-databases.md             # ANN, HNSW, IVF, Qdrant/Chroma/Pinecone/FAISS, hybrid search
    │   ├── 09-rag-advanced.md                 # Cross-Encoder re-ranking, query expansion, Ragas eval, Agentic RAG
    │   └── 10-llm-integration.md              # Tool calling, LangGraph vs raw SDK, KV cache, open-source vs API
    │
    ├── 04-system-design-dsa/                  # 🏗️ SYSTEM DESIGN & DSA
    │   ├── 11-system-design-basics.md         # REST, Redis semantic cache, queues (Celery), 100k DAU RAG design
    │   └── 12-dsa-essentials.md               # Arrays, hashmaps, two-pointers, sliding window, heaps (heapq)
    │
    ├── 05-behavioral/                         # 🎯 BEHAVIORAL & EXPERIENCE
    │   └── 13-project-talking-points.md       # STAR templates for Siraaj AI, Wishan, ERP, and Node-to-Python pitch
    │
    ├── 06-frontend-react/                     # ⚛️ REACT, NEXT.JS & REACT NATIVE
    │   ├── 14-react-core-architecture.md      # Fiber reconciler, Hooks memory model, useRAGStream, Zustand
    │   └── 15-nextjs-and-react-native.md      # RSC vs SSR, Hydration errors, React Native JSI/Fabric, Offline sync
    │
    ├── 07-database-design/                    # 🗄️ DATABASE DESIGN PRINCIPLES
    │   └── 16-database-design-principles.md   # Normalization 1NF-BCNF, UUIDv7 vs BIGINT, Indexing, Multi-tenancy
    │
    ├── 08-sdlc-engineering/                   # 🚀 SDLC, DEVOPS & SECURITY
    │   └── 17-sdlc-devops-practices.md        # Trunk-Based Git, CI/CD, testing pyramid, observability, OWASP Top 10
    │
    └── questions-bank/                        # 💡 DEDICATED INTERVIEW QUESTIONS BANK
        ├── 01-python-fastapi-questions.md     # High-yield Python & FastAPI interview Q&As
        ├── 02-react-frontend-questions.md     # High-yield React, Next.js & React Native interview Q&As
        ├── 03-rag-genai-questions.md          # High-yield RAG, Vector DB & GenAI interview Q&As
        ├── 04-database-system-design-questions.md # High-yield DB design & System Design interview Q&As
        └── 05-sdlc-behavioral-questions.md    # High-yield SDLC, DevOps & Behavioral interview Q&As
```

---

## 📚 Study Modules Index

### 1. Python Internals & OOP
- [01-python-fundamentals.md](./interview-prep/01-python-core/01-python-fundamentals.md): Pass-by-object-reference, mutable default argument trap, closures, decorators, generators, CPython reference counting, generational GC, and the GIL.
- [02-python-oop.md](./interview-prep/01-python-core/02-python-oop.md): Class vs instance attributes, C3 Linearization MRO, `super()`, dunder methods (`__repr__`, `__eq__`, `__hash__`), ABCs, dataclasses (`slots=True`), and composition over inheritance.
- [03-python-async.md](./interview-prep/01-python-core/03-python-async.md): Event loop internals, Node.js libuv vs Python `asyncio`, coroutines, Tasks, Futures, `asyncio.TaskGroup`, and preventing event loop starvation.

### 2. FastAPI & Backend Systems
- [04-fastapi-core.md](./interview-prep/02-fastapi-backend/04-fastapi-core.md): Path/Query/Body parameters, Pydantic v2 Rust engine, dependency injection with `yield` cleanup, middleware, and `def` vs `async def` threadpool execution.
- [05-fastapi-advanced.md](./interview-prep/02-fastapi-backend/05-fastapi-advanced.md): OAuth2 + JWT authentication, Server-Sent Events (SSE) token streaming, WebSockets, rate limiting, Pytest with `AsyncClient`, and production Docker/Gunicorn deployment.
- [06-databases-orm.md](./interview-prep/02-fastapi-backend/06-databases-orm.md): SQL joins, indexing, ACID isolation levels, SQLAlchemy 2.0 Async, solving the N+1 problem with `selectinload`, and zero-downtime Alembic migrations.

### 3. RAG, Vector Search & Generative AI
- [07-rag-fundamentals.md](./interview-prep/03-rag-vector-genai/07-rag-fundamentals.md): RAG vs fine-tuning, chunking strategies (recursive, semantic, markdown), dense embeddings, Cosine vs Dot Product math, and an end-to-end Python pipeline.
- [08-vector-databases.md](./interview-prep/03-rag-vector-genai/08-vector-databases.md): Exact kNN vs ANN, HNSW multi-layer graphs, IVF Voronoi clusters, Qdrant vs Pinecone vs Chroma vs FAISS, single-stage filtered HNSW, and Reciprocal Rank Fusion (RRF) hybrid search.
- [09-rag-advanced.md](./interview-prep/03-rag-vector-genai/09-rag-advanced.md): Bi-Encoders vs Cross-Encoders, in-process FlashRank re-ranking, query expansion, HyDE, the Ragas evaluation triad (Faithfulness, Relevance, Precision), and Agentic RAG state machines.
- [10-llm-integration.md](./interview-prep/03-rag-vector-genai/10-llm-integration.md): Tool calling protocols, Pydantic structured output, raw SDKs vs LangChain vs LangGraph, KV cache memory bottlenecks, token management, and self-hosted vLLM vs commercial APIs.

### 4. System Design & DSA Essentials
- [11-system-design-basics.md](./interview-prep/04-system-design-dsa/11-system-design-basics.md): REST API standards, Redis caching patterns, cache stampede protection, Celery background worker queues, and an end-to-end 100k DAU RAG platform system design.
- [12-dsa-essentials.md](./interview-prep/04-system-design-dsa/12-dsa-essentials.md): High-frequency backend coding patterns: hashmaps, LRU cache with `OrderedDict`, two-pointers, sliding window, Top-K elements with `heapq`, and tree traversals.

### 5. Frontend & Mobile (React, Next.js & React Native)
- [14-react-core-architecture.md](./interview-prep/06-frontend-react/14-react-core-architecture.md): Fiber reconciler cooperative scheduling, Hook linked list memory structures, production `useRAGStream` SSE hook, Zustand vs Redux, and React 18 `useTransition`.
- [15-nextjs-and-react-native.md](./interview-prep/06-frontend-react/15-nextjs-and-react-native.md): App Router Server Components (RSC) vs Client Components, hydration mismatch fixes, React Native New Architecture (JSI C++ pointers, Fabric, TurboModules), and offline-first data sync.

### 6. Database Design & SDLC / DevOps
- [16-database-design-principles.md](./interview-prep/07-database-design/16-database-design-principles.md): Normalization (1NF through BCNF), why random UUID v4 shatters B-Tree cache locality vs **UUID v7**, composite column ordering, PostgreSQL multi-tenancy (RLS), and table partitioning.
- [17-sdlc-devops-practices.md](./interview-prep/08-sdlc-engineering/17-sdlc-devops-practices.md): Trunk-Based Development vs GitFlow, CI/CD pipeline architecture, testing pyramid, the 3 observability pillars (metrics, logs, traces), OWASP Top 10 (BOLA, SSRF in AI), and blameless post-mortems.

### 7. Behavioral & Dedicated Questions Bank
- [13-project-talking-points.md](./interview-prep/05-behavioral/13-project-talking-points.md): STAR framework talking points for Siraaj AI, Wishan Mobile, Enterprise ERP feature flags, and the 3-year Node-to-Python transition pitch.
- [01-python-fastapi-questions.md](./interview-prep/questions-bank/01-python-fastapi-questions.md): Curated Python & FastAPI interview questions with Junior vs Senior answers.
- [02-react-frontend-questions.md](./interview-prep/questions-bank/02-react-frontend-questions.md): Curated React, Next.js & React Native interview questions with Junior vs Senior answers.
- [03-rag-genai-questions.md](./interview-prep/questions-bank/03-rag-genai-questions.md): Curated RAG, Vector Search & GenAI interview questions with Junior vs Senior answers.
- [04-database-system-design-questions.md](./interview-prep/questions-bank/04-database-system-design-questions.md): Curated Database Design & System Design interview questions with Junior vs Senior answers.
- [05-sdlc-behavioral-questions.md](./interview-prep/questions-bank/05-sdlc-behavioral-questions.md): Curated SDLC, DevOps & Behavioral leadership interview questions with model responses.

---

## 🎯 Quick Start
Navigate into [`/interview-prep/`](./interview-prep/README.md) to begin studying.