# Review record, corrections and official sources

**Review date:** 23 September 2026. **Target:** 2.5 years actual experience, 3-year FastAPI + React interview preparation. Interview prompts editorial practice hain, employer-confirmed frequency claims nahi.

## What is the primary source now?

Eight revised quick guides and nine [deep-dive chapters](09-deep-dive/README.md) form the primary path. Root [Fullstack-Master-Interview-Guide.md](../Fullstack-Master-Interview-Guide.md) is built from them; `python3 scripts/build_master_guide.py --check` verifies no drift. Root guide was substantively rebuilt, not just given a disclaimer.

Old master topic inventory, concept sections, code patterns, question/coding/design headings and experience narratives were reviewed for coverage and misleading claims. Repeated question banks were consolidated into answer checkpoints; old first-person achievements/metrics were not treated as verified user history. Every newly authored primary chapter was read back and checked for internal consistency; this is not a claim that every old supplementary chapter in the repository has been fully revalidated.

## Important corrected misconceptions

| Older statement/pattern | Corrected treatment |
|---|---|
| JWT stateless means no server state anywhere | offline access verification vs sessions/refresh/revocation explained independently |
| HttpOnly means protected from XSS | prevents JS cookie reading; malicious authenticated actions remain possible |
| Subdomains always require SameSite=None | cross-origin and cross-site distinguished |
| Keycloak JWT example claimed issuer validation without issuer parameter | replaced with explicit trusted issuer/audience/key/rotation policy |
| Optimistic update takes no locks | UPDATE takes write locks; version detects stale application state |
| FOR UPDATE prevents anybody reading row | ordinary MVCC SELECT generally still reads visible version |
| Missing leading index column means index cannot be used | planner cost, scan/skip-scan nuance |
| INCLUDE guarantees zero heap reads | visibility map / Heap Fetches explained |
| Seq Scan always bad, Index Only always best | plan selected by actual query cost/selectivity |
| shared read means physical disk read | OS cache can satisfy buffer reads |
| pg_stat_statements automatically logs every slow query | aggregate statistics vs separate slow-query logging |
| Session construction acquires connection immediately | lazy connection checkout explained |
| Commit after dependency yield always safe | commit ownership before successful response |
| More workers automatically fixes slow API | pool multiplication, CPU/memory/DB saturation |
| Generator always holds one item/constant memory | retained generator state and consuming materialization |
| GIL universal across every Python build | GIL-enabled CPython vs free-threaded/native exceptions |
| Tuple lookup O(n) without operation distinction | indexing O(1), membership O(n) |
| useEffect always after paint/nonblocking | commit timing, interaction caveats, long JS blocks |
| React 19 automatically enables compiler | configured build optimization separate from runtime version |
| All hooks never conditional | ordinary hooks rule + React use exception |
| React Hook Form guarantees zero renders | subscriptions/controlled fields/validation can rerender |
| Node timers always before setImmediate | context/platform/version-dependent ordering |
| Motor mandatory for async MongoDB | deprecation noted, PyMongo Async migration reference |
| “SELECT startswith” safe SQL sandbox | rejected; fixed operations, DB privileges, RLS and limits |
| MCP only stdio and old HTTP+SSE | Streamable HTTP transport included |
| Guaranteed cache hit %, latency, no downtime, fixed cloud winner | explicit workload assumptions and measurable trade-offs |
| Invented first-person incident metrics | real-project worksheet and defensible ownership |

## Coverage mapping from older master themes

| Earlier themes | Reviewed destination |
|---|---|
| Python core, VM, memory, concurrency | quick Python + Python deeper concepts |
| JS/TS, V8, browser/Node event loops | JS quick + JS language depth + TS |
| FastAPI/ASGI/Pydantic/DI/lifespan | FastAPI quick + backend patterns |
| Pooling/ORM/transactions/normalization | DB quick + backend patterns + indexing depth |
| Auth/JWT/cookies/SSO/Keycloak/RLS/security | dedicated auth chapter + backend + indexing |
| React/hooks/state/forms/compiler/Next.js | React quick + React/browser depth |
| Accessibility/CSS/performance/cross-browser | React/browser depth |
| Internet/networking/DNS/TLS | React/browser + backend HTTP + debugging |
| Debugging/latency/single-user/prod incidents/tracing | dedicated API/production debugging |
| Redis/Celery/Kafka/high scale/webhooks/payments | backend production + system operations |
| Docker/Kubernetes/cloud/CI/CD/migrations/monorepo | system operations |
| Real-time/SSE/WebSockets | system operations + debugging |
| RAG/vector/context/MCP/MongoDB | advanced electives (role-specific, not universal core) |
| Team communication/package selection/leadership | system operations + project worksheet |
| System design scenarios | worked task manager, URL shortener/upload drills, operations |
| Coding/traps/behavioral/rapid-fire questions | workbook + coverage checkpoints + SQL practice |

## Official technical references

Links were opened/search-checked during this review; versioned behavior must still match an actual project's installed packages.

| Topic | Primary reference |
|---|---|
| FastAPI sync/async dispatch | [Concurrency](https://fastapi.tiangolo.com/async/) |
| Yield lifetimes | [Dependencies with yield](https://fastapi.tiangolo.com/tutorial/dependencies/dependencies-with-yield/) |
| BackgroundTasks | [Background tasks](https://fastapi.tiangolo.com/tutorial/background-tasks/) |
| Request vs server validation errors | [Error handling](https://fastapi.tiangolo.com/tutorial/handling-errors/) |
| Pydantic v2 | [Models](https://docs.pydantic.dev/latest/concepts/models/) |
| SQLAlchemy async sessions / implicit IO | [Asyncio](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html) |
| PostgreSQL isolation | [Transaction isolation](https://www.postgresql.org/docs/current/transaction-iso.html) |
| Multicolumn indexes | [Index predicates/order](https://www.postgresql.org/docs/current/indexes-multicolumn.html) |
| Heap visibility / INCLUDE | [Index-only scans](https://www.postgresql.org/docs/current/indexes-index-only-scans.html) |
| Plan interpretation | [Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html) |
| Concurrent index caveats | [CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html) |
| Database monitoring | [Statistics system](https://www.postgresql.org/docs/current/monitoring-stats.html) |
| Tenant defense in depth | [Row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) |
| JWT state/revocation | [OWASP JWT](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html) |
| Login/session lifecycle | [OWASP session management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) |
| JS let/const/var/TDZ | [MDN grammar/types](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Grammar_and_types) |
| Browser execution | [MDN execution model](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Execution_model) |
| Node scheduling | [Node event loop](https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick) |
| React state | [Snapshot](https://react.dev/learn/state-as-a-snapshot) |
| Effects | [Avoid unnecessary effects](https://react.dev/learn/you-might-not-need-an-effect), [useEffect](https://react.dev/reference/react/useEffect) |
| React use exception | [use](https://react.dev/reference/react/use) |
| Compiler separate from version | [Compiler introduction](https://react.dev/learn/react-compiler/introduction) |
| Next.js boundaries | [Server/client components](https://nextjs.org/docs/app/getting-started/server-and-client-components) |
| Python task lifecycle | [Asyncio tasks](https://docs.python.org/3/library/asyncio-task.html) |
| MongoDB async driver migration | [Motor notice](https://www.mongodb.com/docs/drivers/motor/) |
| MCP transport correction | [Transport specification](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports) |

## Validation and limits

- PostgreSQL practice schema/seed: executed in PGlite 0.5.8, PostgreSQL 18.3 WASM build.
- All 40 solution queries executed; independent expected values checked for ordinary and edge cases. Expected-result tables generated from execution.
- FK tenant mismatch, negative stock CHECK, duplicate key: expected SQLSTATE errors checked. Missing-payment reconciliation and sequential reservation outcomes checked.
- Entire 100k-row indexing lab executed statement-by-statement (VACUUM outside implicit transaction).
- 11 Mermaid source diagrams parsed successfully after fixing two sequence-diagram semicolon syntax issues. Parser validation is not full visual layout QA.
- Markdown local links/fences, Python snippet syntax, master build consistency, standalone TypeScript examples, selected Python/JavaScript behavior checked; final counts reported by validation tools.
- Real two-client PostgreSQL locks/deadlocks/serializable schedules provided as interactive labs; not executed here because Docker daemon wasn't running and no native PostgreSQL server was available.
- No full FastAPI service or React app integration run: this repository contains documentation and SQL labs, not a complete application. Illustrative code specifies dependencies/context where needed.
- Existing PDF, if present, remains an older export. Older supplementary folders retain historical material; primary reviewed path is the rebuilt master and its source chapters.
