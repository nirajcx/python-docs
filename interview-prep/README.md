# Interview roadmap — full-stack FastAPI + React

**Profile:** 2.5 years actual experience; preparation 3-year full-stack expectations ke liye. Concepts Hinglish mein samjho, code independently likho, aur trade-offs defend karo.

**All-in-one:** [root master guide](../Fullstack-Master-Interview-Guide.md), 17 reviewed chapters. **Hands-on:** [PostgreSQL lab](../postgres-practice/README.md): tables + INSERTs + 40 queries/solutions + 100k-row indexing + 8 concurrency labs.

## Topic map: exactly kahan padhna hai

| Priority | Track | Main study guide | Deeper reference |
|---|---|---|---|
| P0 | Python | [Python concepts](00-start-here/01-python-quick-guide.md) | [OOP/runtime/async depth](09-deep-dive/08-python-deeper-concepts.md) |
| P0 | Backend | [FastAPI + HTTP + auth](00-start-here/02-fastapi-quick-guide.md) | [production + ORM](09-deep-dive/05-backend-production-patterns.md) |
| P0 | Database | [SQL + transactions](00-start-here/04-database-quick-guide.md) | [index internals](09-deep-dive/03-postgres-indexing-internals.md) |
| P0 | JavaScript | [JS fundamentals](00-start-here/10-javascript-fundamentals-guide.md) | [language depth](09-deep-dive/01-javascript-language.md) |
| P0 | React | [React concepts](00-start-here/03-react-nextjs-quick-guide.md) | [React/browser depth](09-deep-dive/06-react-browser-engineering.md) |
| P0 | TypeScript | [TS contracts](00-start-here/11-typescript-guide.md) | [frontend contracts/forms](09-deep-dive/06-react-browser-engineering.md) |
| P0 | Coding/debugging | [Timed workbook + answer checkpoints](00-start-here/12-scenario-coding-round.md) | [DSA patterns](04-system-design-dsa/12-dsa-essentials.md) |
| P1 | System design | [Worked task manager + diagrams](00-start-here/05-system-design-quick-guide.md) | [distributed systems/operations](09-deep-dive/07-system-operations-advanced.md) |
| P1 | Engineering | [Production debugging](09-deep-dive/04-api-production-debugging.md) | [CI/CD + operations](09-deep-dive/07-system-operations-advanced.md) |
| P0 | Project/behavioral | [Real STAR stories](05-behavioral/13-project-talking-points.md) | [Node → Python pitch](00-start-here/08-node-to-python-pitch.md) |
| P2 | Next.js / mobile | [Rendering + mobile reference](06-frontend-react/15-nextjs-and-react-native.md) | only relevant JD topics |
| P2 | GenAI / RAG | [Quick guide](00-start-here/06-rag-genai-quick-guide.md) | [RAG basics](03-rag-vector-genai/07-rag-fundamentals.md) |
| P2 | Internals | [Advanced index](advanced-optional/README.md) | files 19–30; selected reading |

P0 = pehle ready karo. P1 = core ke baad practical depth. P2 = role-specific. Yeh editorial priorities hain, verified question-frequency statistics nahi. Interview mein exact kya aayega company aur round par depend karta hai.

## Daily routine (2 hours)

25 min concept → 45 min code/query → 20 min aloud Q&A → 20 min previous mistakes → 10 min notes. Reading complete checkbox se zyada useful hai: bina notes explanation + working example + one failure case.

## 4-week plan with deliverables

| Days | Focus | Done tab maanoge jab… |
|---|---|---|
| 1–3 | Python objects/OOP/async | output questions + generator/decorator + concurrency reasoning |
| 4–7 | HTTP/FastAPI/auth | CRUD contract, validation, permission, transaction and tests |
| 8–10 | SQL/schema/indexes | three SQL exercises + EXPLAIN reasoning |
| 11–12 | transactions/concurrency | stock race + optimistic edit conflict explain |
| 13–14 | backend/DB mock | timed Round A/C; mistakes corrected |
| 15–17 | JS/TS | event loop outputs, closure, debounce, typed API states |
| 18–21 | React | race-safe search, forms, cache, performance debugging |
| 22–24 | design + deployment | task manager diagram with one failure deep dive |
| 25–26 | DSA + project stories | two timed problems, two defensible stories |
| 27–28 | full mocks | scorecard, weakest topics repeat, concise revision |

## Agar interview 7 din mein hai

Day 1 Python + FastAPI, day 2 DB/SQL, day 3 JS/TS, day 4 React coding, day 5 auth/debugging/design, day 6 timed full mock + project stories, day 7 weak answers and light revision. Har din 30 min DSA/SQL alternate karo. P2 ko tabhi time do jab JD explicitly maange.

## Answer dene ka format

**Definition → mechanism → small example → trade-off → test/failure case.**

Example: “Index lookup/sort help karta hai; is feed mein user equality aur created_at ordering hai, toh matching composite index evaluate karunga. Writes/storage cost badhegi. EXPLAIN ANALYZE se actual plan aur latency check karunga.”

Nahi pata ho toh assumption clearly bolo aur reasoning dikhao. Project ke fictional metrics ya unowned work claim mat karo.

## Reference library ka use

Revised core + [deep-dive index](09-deep-dive/README.md) primary source hain, root master inse automatically build hota hai. Older English reference folders retained hain, but version-specific snippets ko reviewed chapters and official docs ke against check karo. Unreviewed old examples ko production-ready assume mat karo.

## Required deep-dive checkpoints

[Auth and JWT sessions](09-deep-dive/02-auth-jwt-sessions.md) · [API/production debugging](09-deep-dive/04-api-production-debugging.md) · [Coverage and answer checkpoints](09-deep-dive/09-interview-coverage.md). Inhe P1 optional reading nahi, core ke baad essential practical preparation samjho.

[Review scope and official sources](SOURCES-AND-REVIEW.md) · [Start-here index](00-start-here/README.md) · [Practice workbook](00-start-here/12-scenario-coding-round.md)
