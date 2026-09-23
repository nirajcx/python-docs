# 3-year interview coverage — checklist, follow-ups aur answer checkpoints

[Roadmap](../README.md) · [Mock workbook](../00-start-here/12-scenario-coding-round.md) · [PostgreSQL practice](../../postgres-practice/README.md)

## Readiness ka meaning

Topic done tab: 60-second definition, working example, one failure case, one alternative/trade-off. Basic questions ko skip karke only internals padhna balanced preparation nahi. Yeh broad preparation map hai, every possible interview question ki guarantee nahi.

## Python — P0/P1

| Question | Answer checkpoint |
|---|---|
| List vs tuple? | mutability, hashability elements, indexing vs membership complexity |
| Dict key list kyun nahi? | hash/equality stability; list unhashable |
| Mutable default? | definition-time shared object; None sentinel |
| Shallow/deep copy? | nested references vs recursive copy; copy cost |
| is vs ==? | identity vs value; custom __eq__ |
| Closure late binding? | variable lookup timing; default capture |
| args/kwargs? | positional tuple/keyword dict; forwarding |
| Decorator with arguments? | factory → decorator → wrapper; wraps; async-aware |
| Generator vs iterator? | yield state machine; lazy, exhaustion, retained state |
| Context manager? | setup/cleanup; exception handling and suppression |
| Class vs instance attribute? | shared class state vs per instance |
| classmethod vs staticmethod? | cls supplied vs no implicit receiver |
| Inheritance vs composition? | substitutability vs injected collaborators |
| MRO and super? | next method in resolution order |
| Protocol vs ABC? | structural typing vs explicit abstraction |
| GIL means race-free? | no; build/native code/compound operations caveat |
| async vs thread vs process? | I/O vs CPU, overhead, bounded resources |
| gather vs TaskGroup? | sibling cancellation/error lifecycle differ |
| Memory leak? | retained references/caches/tasks/native memory; measure |
| venv vs Docker? | dependencies vs process/runtime environment isolation |

## Backend / HTTP / security — P0/P1

| Question | Answer checkpoint |
|---|---|
| Framework vs ASGI server? | FastAPI vs Uvicorn, app interface vs serving |
| async route calls sync helper? | blocks worker loop unless explicitly offloaded |
| Why Pydantic when type hints? | runtime boundary validation, coercion/strictness |
| Optional field vs nullable field? | omission default separate from None allowed |
| Depends vs middleware? | route requirements vs broad request concern |
| Resource cleanup timing? | yield scope/version; own background task resources |
| Session vs transaction? | ORM lifecycle vs atomic unit; connection acquired as needed |
| flush vs commit? | SQL synchronization vs transaction completion |
| 400/401/403/409/422? | error meaning + FastAPI defaults + producing layer |
| GET/PUT/PATCH/POST? | safe/idempotent semantics, partial update contract |
| Idempotency key? | operation/user scope, payload fingerprint, atomic persistence |
| REST pagination? | limit/order/cursor, offset cost, concurrent changes |
| JWT stateless but sessions? | access verification vs lifecycle/revocation state |
| Logout stolen JWT? | expiry window or denylist/status lookup |
| JWT decode enough? | signature + algorithms + claims + authorization |
| Access token vs refresh vs ID token? | API credential vs renewal vs identity assertion |
| Cookie vs token? | transport/storage vs credential format |
| HttpOnly stops XSS? | token reading reduced; authenticated actions still possible |
| CORS vs CSRF? | browser cross-origin reading vs unwanted authenticated actions |
| Cross-origin vs cross-site? | scheme/host/port origin vs site boundary |
| RBAC vs ABAC? | role permissions vs contextual attributes |
| SQL injection with ORM? | raw interpolated SQL remains dangerous |
| SSRF? | server fetches attacker destination; network/redirect controls |
| Rate limit multiple instances? | shared atomic state, key policy, backpressure |
| Durable job? | persist intent, delivery/ack/retry/dedup semantics |
| Webhook duplicated/out of order? | verified event, unique ID, state machine, reconciliation |
| Upload validation? | actual file size/type, ownership, scoped URL and scan policy |
| Retry every failure? | only transient + capped backoff, avoid duplicate effects |

## PostgreSQL — P0/P1

| Question | Answer checkpoint |
|---|---|
| PK/UNIQUE/FK/CHECK? | identity, uniqueness, relationship, domain; null semantics |
| Normalization 1NF→BCNF? | repeating groups, partial/transitive FD, determinants |
| Denormalize when? | measured read need/historical snapshot + consistency cost |
| WHERE vs HAVING? | row filter vs group filter |
| LEFT JOIN right predicate? | ON preserves unmatched, WHERE may reject NULL |
| COUNT(*) vs COUNT(col)? | rows vs non-null values |
| NOT IN with NULL? | UNKNOWN; NOT EXISTS alternative |
| Window vs GROUP BY? | per-row context vs collapsed groups |
| row_number/rank/dense_rank? | unique numbering / ties gaps / ties no gaps |
| Index internally? | balanced multiway pages → tuple reference → visibility |
| Why index unused? | selectivity/stats/expression/order/heap cost |
| Composite index order? | lexicographic, equality/range/order workload |
| INCLUDE vs key column? | payload vs searchable ordering, visibility caveat |
| GIN vs BRIN? | inverted entries vs block-range summaries |
| EXPLAIN cost milliseconds? | no; actual timing separate; loops/statistics |
| ACID consistency vs CAP consistency? | integrity vs distributed observed behavior; context differs |
| Isolation levels? | PG snapshots/anomalies, serializable retries |
| SELECT FOR UPDATE blocks SELECT? | ordinary MVCC read generally not blocked by row lock |
| Optimistic locking no locks? | update still locks; version detects stale decision |
| Deadlock fix? | consistent lock order, shorter TX, retry whole operation |
| Savepoint? | partial rollback, not independently committed nested TX |
| VACUUM vs ANALYZE? | reclaim reusable dead-space vs planner stats |
| Connection pool exhaustion? | waiting/leak/long TX + multiplicative worker capacity |
| Replication vs backup? | lag/failover vs restore history; accidental delete replicates |
| Partition vs shard? | partitions vs independent database distribution |
| RLS sufficient alone? | roles/bypass/context/app auth and operational tests |

## JS / TS / React — P0/P1

| Question | Answer checkpoint |
|---|---|
| let/const/var? | block/function scope, TDZ, reassign/redeclare, const object mutation |
| var loop callbacks? | shared binding vs per-iteration let |
| Closure vs copy? | lexical environment, not frozen value by default |
| this and arrow? | call-site receiver vs lexical capture |
| call/apply/bind? | immediate invocation args/list vs bound function |
| prototype vs class? | lookup chain, shared methods, class syntax |
| ==/===/Object.is? | coercion vs strict equality vs NaN/signed zero |
| ?? vs ||? | nullish vs all falsy |
| Promise combinators? | all/any/race/allSettled; losing work cancellation separate |
| Event loop output? | specify browser/Node + module context; microtask/task order |
| debounce vs throttle? | pause-based vs rate-limited; cleanup |
| sort/map/filter/reduce? | mutation/return/complexity and intent |
| any vs unknown vs never? | checks off vs narrowing required vs no possible value |
| Type assertion validate? | no; runtime schema required for external data |
| Generics? | preserve relationships among types |
| Discriminated union? | narrow state, exhaustive handling |
| React render vs commit? | calculate vs DOM mutations; render purity |
| setState two calls? | render snapshot vs functional updater queue |
| State mutation? | identity/snapshot violation; changed path copies |
| Key index bug? | reorder/delete changes identity/state association |
| Effect vs event? | external synchronization vs user action |
| Dependency stale closure? | reads must match dependencies/updater design |
| useRef vs state? | mutable persistent storage vs UI updates |
| useMemo/useCallback/memo? | cached value/function/component optimization |
| Context vs reducer/store/query? | ownership, transition logic, shared client vs remote state |
| Custom hook shares state? | no, each invocation separate unless external shared store |
| Strict Mode double setup? | development checks; cleanup symmetry |
| use vs ordinary hook rules? | use conditional exception, allowed context constraints |
| React Compiler automatic with version? | configured build tooling, not version-only magic |
| Controlled/uncontrolled? | source of input state and form behavior |
| Search race? | abort/ignore old result; cleanup and cache key |
| Optimistic rollback race? | version/order-aware reconcile, not stale snapshot overwrite |
| Suspense arbitrary fetch? | requires supported resource, Effect fetch not automatic |
| transition vs debounce? | render priority vs delay/rate control |
| RSC vs SSR? | execution model vs HTML generation |
| Hydration mismatch? | deterministic initial tree + inspect data/time/browser |
| Error boundary async? | normal async/event handlers need explicit handling |
| Accessibility? | semantics, labels, keyboard/focus, feedback |
| Slow typing? | measure JS/layout/render, state locality, expensive computations |
| WebSocket reconnect? | auth/origin, jitter, bounded buffer, resume/dedup |

## Production/system design — P1, deeper parts P2

| Question | Answer checkpoint |
|---|---|
| Slow API with fast SQL? | pool checkout, network, external spans, serialization |
| Single user issue? | permissions/data/flags/build/browser compare |
| 502 vs 504? | upstream response/reset vs gateway timeout evidence |
| Memory growing? | RSS vs traced allocations, references/native/pool limits |
| Debug after deployment? | release correlation, rollback compatibility, mitigation then RCA |
| Logs vs metrics vs traces? | event details vs aggregate trends vs request path |
| p95 vs average? | tail latency, sampling interval, route/error mix |
| Cache invalidation race? | stale reader refill after write; TTL/version/coordination |
| CAP? | partition-time consistency/availability trade-off, not unconditional choose-two |
| Outbox? | same DB transaction persists business change + event, duplicates remain |
| Saga? | compensating multi-service workflow, not ACID magic |
| Kafka ordering? | partition order, key mapping, completion ordering caveat |
| Liveness vs readiness? | restart vs traffic; dependency failure design |
| Expand/contract? | mixed-version compatibility + backfill race + retire old clients |
| RTO/RPO? | recovery time and data-loss objectives, restore drill |
| API codegen guarantees? | catches type drift, not all runtime/deploy mismatches |
| Monolith vs microservices? | team ownership/scale boundaries vs operational cost |

## Practice gates

1. **Backend:** 60-minute CRUD with permission failure and transaction rollback explained.
2. **DB:** Q1–10 in 30 minutes; window/ranking problems in another session; actual EXPLAIN explain aloud.
3. **Frontend:** 45-minute search/form with obsolete response, loading/error/empty and accessibility.
4. **Design:** 35-minute task manager, including auth, conflict, queue failure and sizing.
5. **Behavioral:** two real 3-minute stories with specific ownership and one trade-off.

Do not memorize all tables as one-line scripts. Har weak checkpoint ka linked full chapter read + reproduce code. [Workbook](../00-start-here/12-scenario-coding-round.md) has scoring and repair loop.
