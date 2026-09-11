# Python, FastAPI, GenAI, JavaScript & Full-Stack Systems Knowledge Base

> **Target Roles:** Staff / Senior Full-Stack & Python Backend Developer, AI/RAG Systems Engineer, Distributed Systems Engineer  
> **Candidate Profile:** 3 Years Professional Experience (React / Next.js / React Native + Node.js / Express, transitioning to Python, FastAPI, Vector DBs, and GenAI / RAG)  
> **Quality Standard:** FAANG & Tier-1 MNC Staff-Level Interview Depth (Engine Internals, Mathematical Proofs, Production Scripts, Wire Protocols)

---

## 📌 Repository Overview

This repository contains an end-to-end, interview-ready engineering study curriculum located inside [`/interview-prep/`](./interview-prep/README.md).

Every module is written with senior engineering rigor:
- **JavaScript Core & Dual-Language Event Loop**: V8 Heap/Stack memory, Closures, Prototypal inheritance, `this` 4 binding rules, and a deep comparative breakdown of the **JavaScript (V8/libuv) vs. Python (AsyncIO/uvloop) Event Loops**.
- **Under-the-Hood Mechanics**: CPython 3.11+ PEP 659 Adaptive Specializing Interpreter, PyMalloc Arenas/Pools, Fiber reconciler linked-list traversal, HNSW skip-graphs, and PostgreSQL 8KB B-Tree page splits.
- **LLM Infrastructure & Serving**: Prefill vs Decode hardware bottlenecks, KV Cache mathematical sizing formulas, PagedAttention (vLLM virtual paging), Continuous Batching, Speculative Decoding, and LoRA/DPO alignment.
- **GenAI Security & Guardrails**: Context window budgeting (Lost-in-the-Middle), Sentence Window retrieval, Indirect Prompt Injection, Markdown image data exfiltration, and document-level ACL vector filtering.
- **Distributed Systems & Consensus**: Redlock failure modes & Fencing Tokens, Two-Phase Commit (2PC) vs Saga Pattern, Outbox Pattern with Debezium CDC, and Kafka commit log vs RabbitMQ.
- **High-Scale & FinTech Scenarios**: Handling 1,000 to 100,000 QPS, flash sales (50k req/10s), preventing financial double-spending (pessimistic row locking with deadlock ordering, double-entry ledgers, idempotency keys), and bulk vector ingestion.
- **Modern Frontend & Wire Protocols**: Module Federation micro-frontends, React Server Components (RSC) Flight Protocol wire format disassembly (`0:HL...`, `1:I...`), Hermes AOT bytecode, Reanimated 3 worklets, and Axios concurrent 401 refresh queues.
- **12 Integrated Staff Scenarios & Questions Bank**: End-to-end multi-tenant RAG, 100k QPS systems, and a dedicated **10-part Interview Questions Bank**.

---

## 🗺️ Curriculum Structure

```
python-docs/
├── README.md                                  # You are here: Repository Overview
└── interview-prep/
    ├── README.md                              # Master Study Roadmap & FAANG Matrix
    │
    ├── 01-python-core/                        # 🐍 PYTHON INTERNALS & RUNTIME
    │   ├── 01-python-fundamentals.md          # Data types, mutability, decorators, generators, GIL, memory
    │   ├── 02-python-oop.md                   # Classes, MRO (C3 Linearization), dunders, ABCs, dataclasses
    │   ├── 03-python-async.md                 # Event loop, Node vs Python async, TaskGroup, thread offloading
    │   ├── 21-memory-optimization-and-leaks.md # PyMalloc arenas, GC cycles, tracemalloc, cgroups OOMKilled, React leaks
    │   └── 22-cpython-interpreter-and-descriptors.md # CPython 3.11+ PEP 659, descriptors, metaclasses, typing, packaging
    │
    ├── 02-fastapi-backend/                    # ⚡ FASTAPI & BACKEND SYSTEMS
    │   ├── 04-fastapi-core.md                 # Routing, Pydantic v2 validation, Depends() DI, async vs def
    │   ├── 05-fastapi-advanced.md             # JWT/OAuth2, SSE token streaming, WebSockets, testing, Docker
    │   ├── 06-databases-orm.md                # SQL indexing, SQLAlchemy 2.0 Async, N+1 problem, Alembic
    │   └── 23-asgi-internals-and-redis-ratelimit.md # ASGI specification, scope/receive/send, Pydantic Rust core, Lua rate limiter
    │
    ├── 03-rag-vector-genai/                   # 🧠 RAG, VECTOR SEARCH & LLM SERVING
    │   ├── 07-rag-fundamentals.md             # RAG architecture, chunking, embeddings, similarity math
    │   ├── 08-vector-databases.md             # ANN, HNSW, IVF, Chroma/Qdrant/Pinecone/FAISS, hybrid search
    │   ├── 09-rag-advanced.md                 # Cross-Encoder re-ranking, query expansion, Ragas eval, Agentic RAG
    │   ├── 10-llm-integration.md              # Tool calling, LangGraph vs raw SDK, KV cache, open-source vs API
    │   ├── 24-llm-serving-pagedattention.md   # Prefill vs decode, KV cache sizing math, PagedAttention, vLLM, LoRA/DPO
    │   └── 25-genai-security-and-guardrails.md # Context engineering, Lost-in-the-Middle, LangGraph, prompt injection, ACLs
    │
    ├── 04-system-design-dsa/                  # 🏗️ SYSTEM DESIGN, DISTRIBUTED SYSTEMS & DSA
    │   ├── 11-system-design-basics.md         # REST, Redis caching, queues (Celery), 100k DAU RAG design
    │   ├── 12-dsa-essentials.md               # Arrays, hashmaps, two-pointers, sliding window, heaps (heapq)
    │   ├── 19-high-scale-traffic-and-fintech.md # 1K-100K QPS scaling, flash sales, fintech double-spending, 1M vector batch
    │   ├── 26-distributed-systems-kafka-saga.md # Redlock critique, Fencing Tokens, Saga vs 2PC, Outbox pattern, Kafka vs RabbitMQ
    │   └── 28-advanced-dsa-faang-patterns.md  # Binary search on answer, Monotonic stack, Trie, Union-Find, Topological sort
    │
    ├── 05-behavioral/                         # 🎯 BEHAVIORAL & INTEGRATED SCENARIOS
    │   ├── 13-project-talking-points.md       # STAR templates for Siraaj AI, Wishan, ERP, and Node-to-Python pitch
    │   └── 29-faang-cross-domain-interview-scenarios.md # 12 Comprehensive Staff scenarios across RAG, 100k QPS, FinTech & Leaks
    │
    ├── 06-frontend-react/                     # ⚛️ JAVASCRIPT, REACT, NEXT.JS & MOBILE
    │   ├── 14-react-core-architecture.md      # Fiber reconciler, Hooks memory model, useRAGStream, Zustand
    │   ├── 15-nextjs-and-react-native.md      # RSC vs SSR, Hydration errors, React Native JSI/Fabric, Offline sync
    │   ├── 18-react-ecosystem-libraries.md    # Axios interceptors/refresh queue, TanStack Query, React Hook Form, Edge Runtime
    │   ├── 27-microfrontends-and-rsc-internals.md # Module Federation, RSC Flight wire protocol, Hermes bytecode, Reanimated worklets
    │   └── 30-javascript-core-and-event-loop-deep-dive.md # V8 memory, React JS fundamentals (immutability, debounce, events), and JS vs Python Event Loop
    │
    ├── 07-database-design/                    # 🗄️ DATABASE DESIGN & ENGINEERING
    │   ├── 16-database-design-principles.md   # Normalization 1NF-BCNF, UUIDv7 vs BIGINT, Indexing, Multi-tenancy
    │   └── 20-advanced-database-engineering-and-migrations.md # B-Tree page splits, EXPLAIN BUFFERS, backfill scripts, zero-downtime Alembic
    │
    ├── 08-sdlc-engineering/                   # 🚀 SDLC, DEVOPS & OBSERVABILITY
    │   └── 17-sdlc-devops-practices.md        # Trunk-Based Git, CI/CD, testing pyramid, observability, OWASP Top 10
    │
    └── questions-bank/                        # 💡 10 DEDICATED HIGH-YIELD QUESTION BANKS
        ├── 01-python-fastapi-questions.md     # High-yield Python & FastAPI interview Q&As
        ├── 02-react-frontend-questions.md     # High-yield React, Next.js & React Native interview Q&As
        ├── 03-rag-genai-questions.md          # High-yield RAG, Vector DB & GenAI interview Q&As
        ├── 04-database-system-design-questions.md # High-yield DB design & System Design interview Q&As
        ├── 05-sdlc-behavioral-questions.md    # High-yield SDLC, DevOps & Behavioral interview Q&As
        ├── 06-scale-fintech-scenarios-questions.md # 1K-100K QPS, flash sales, money transactions, idempotency Q&As
        ├── 07-react-ecosystem-nextjs-questions.md # Axios refresh queue, TanStack Query, Edge runtime, INP Q&As
        ├── 08-mnc-tier1-deep-dive-questions.md # Grammar-Constrained Decoding, EXPLAIN BUFFERS, PyMalloc, KV Cache math
        ├── 09-faang-staff-systems-and-ai-questions.md # PEP 659, Redlock critique, Continuous Batching, ASGI scope/send, RSC Flight, Kafka EOS
        └── 10-javascript-and-event-loop-questions.md # Microtask draining, React state immutability, debounce cleanup, JS vs Python Event Loop
```

---

## 🎯 Quick Start
Navigate into [`/interview-prep/`](./interview-prep/README.md) to begin studying.