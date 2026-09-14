# Python / FastAPI + React Interview Prep

**Who this is for:** A developer with ~2.5 years of experience (strong React / Next.js, plus ~6 months of Python / FastAPI) preparing for **mid-size product companies in Bangalore, Noida, and Delhi**.

**What these interviews actually test at your level:**
- Solid fundamentals (Python, JavaScript, React, SQL) explained clearly
- Practical decisions ("why did you pick X over Y") backed by real project experience
- Clean, working code on a shared editor (CRUD, small features, easy-to-medium DSA)
- A simple system design you can reason about out loud
- Behavioral: how you work, communicate, and handle problems

**What they usually do NOT test at your level:** CPython bytecode internals, GPU/KV-cache math, wire-protocol byte disassembly, distributed consensus proofs. That material exists here in the **Advanced (Optional)** section, but treat it as stretch reading, not your main study path.

---

## 🚦 Start Here

If you only read one section, read this one. The [`00-start-here/`](./00-start-here/) folder has short, plain-English guides written for your level:

- [Python quick guide](./00-start-here/01-python-quick-guide.md)
- [FastAPI quick guide](./00-start-here/02-fastapi-quick-guide.md)
- [React & Next.js quick guide](./00-start-here/03-react-nextjs-quick-guide.md)
- [SQL & database quick guide](./00-start-here/04-database-quick-guide.md)
- [System design quick guide](./00-start-here/05-system-design-quick-guide.md)
- [RAG / GenAI quick guide](./00-start-here/06-rag-genai-quick-guide.md)
- [Practical must-knows](./00-start-here/07-practical-must-knows.md) — Git, REST, HTTP status codes, testing, debugging
- [Node → Python transition pitch](./00-start-here/08-node-to-python-pitch.md)
- [State management guide](./00-start-here/09-state-management-guide.md) — Context, useReducer, Zustand, Redux, TanStack Query
- [JavaScript fundamentals guide](./00-start-here/10-javascript-fundamentals-guide.md) — closures, promises, event loop, `this`
- [TypeScript guide](./00-start-here/11-typescript-guide.md) — types vs interfaces, generics, utility types
- [Scenarios & coding-round practice](./00-start-here/12-scenario-coding-round.md) — real prompts with solutions

Each guide follows the same simple format: **concept → plain explanation → the answer you say in an interview → what they'll follow up with.**

---

## 📅 A Realistic 4-Week Plan

You don't need to read everything. Here is a focused path.

| Week | Focus | Files |
|---|---|---|
| **Week 1** | Python + FastAPI core (your newest area) | `00-start-here/01`, `02`; then `01-python-core/01,02,03`; `02-fastapi-backend/04,05,06` |
| **Week 2** | React / Next.js (your strength) + JS/TS + state management | `00-start-here/03`, `09`, `10`, `11`; `06-frontend-react/14,15,18` |
| **Week 3** | SQL + System design + DSA + practical must-knows | `00-start-here/04`, `05`, `07`; `07-database-design/16`; `04-system-design-dsa/11,12` |
| **Week 4** | RAG/GenAI + behavioral + coding-round + mock questions | `00-start-here/06`, `08`, `12`; `05-behavioral/13`; whole `questions-bank/` |

Advanced files (21–30) are optional. Only open them if an interviewer specifically goes deep, or if you're targeting a company known for hard rounds.

---

## 🗂️ Full Contents

### Core material (study these)

```
01-python-core/
├── 01-python-fundamentals.md    # Data types, mutability, decorators, generators, GIL
├── 02-python-oop.md             # Classes, inheritance, dunder methods, dataclasses
└── 03-python-async.md           # async/await, event loop, when to use async

02-fastapi-backend/
├── 04-fastapi-core.md           # Routing, Pydantic, Depends(), async vs def
├── 05-fastapi-advanced.md       # Auth (JWT), WebSockets, streaming, testing, deploy
└── 06-databases-orm.md          # SQL, indexes, SQLAlchemy, the N+1 problem

03-rag-vector-genai/
├── 07-rag-fundamentals.md       # What RAG is, chunking, embeddings, retrieval
├── 08-vector-databases.md       # Vector search, HNSW, Chroma/Qdrant/Pinecone
├── 09-rag-advanced.md           # Re-ranking, query rewriting, evaluation
└── 10-llm-integration.md        # Prompts, function calling, LangChain basics

04-system-design-dsa/
├── 11-system-design-basics.md   # REST, caching, queues, designing a simple system
└── 12-dsa-essentials.md         # Arrays, hashmaps, two pointers, sliding window

05-behavioral/
└── 13-project-talking-points.md # STAR stories for your real projects

06-frontend-react/
├── 14-react-core-architecture.md   # How React works, hooks, state management
├── 15-nextjs-and-react-native.md   # RSC vs SSR, hydration, mobile basics
└── 18-react-ecosystem-libraries.md # Axios, TanStack Query, React Hook Form

07-database-design/
└── 16-database-design-principles.md # Normalization, keys, indexing, multi-tenancy

08-sdlc-engineering/
└── 17-sdlc-devops-practices.md   # Git workflow, CI/CD, testing pyramid, security

questions-bank/                   # Rapid-fire Q&A to self-test (read all)
```

### Advanced (Optional) — stretch material for hard rounds only

```
advanced-optional/  (files 19–30)
These cover Staff/FAANG-level internals: CPython VM, PyMalloc, ASGI internals,
PagedAttention/KV-cache math, GenAI security, Kafka/Saga consensus,
micro-frontends & RSC wire protocol, FAANG DSA patterns, deep JS/event-loop.

Skip these for a first pass. Come back only if you're specifically asked to
go deep, or you're interviewing at a company with a reputation for hard rounds.
```

---

## ✅ How to use this repo

1. Start with the `00-start-here/` guide for the topic you're weakest on (probably Python/FastAPI given your background).
2. When a quick guide references a deeper file, read it only if you want more detail.
3. Every few days, test yourself with the `questions-bank/`. Say answers out loud.
4. Keep the `advanced-optional/` material on the shelf until you need it.
