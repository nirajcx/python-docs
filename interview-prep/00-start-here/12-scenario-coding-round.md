# Coding rounds + mock interview workbook (Hinglish)

[Roadmap](../README.md) · [DB solutions](04-database-quick-guide.md) · [React race solution](03-react-nextjs-quick-guide.md)

Yeh practice prompts hain, kisi employer ke confirmed/recent question list ka claim nahi. Pehle timer lagao, answer baad mein dekho.

## Round A — FastAPI task API (60 min)

**Prompt:** authenticated user project tasks create/list/update kar sake. PostgreSQL persistence, Pydantic input, ownership check aur tests explain/implement karo.

**Acceptance criteria:**

- Title whitespace-only reject; reasonable length cap; status allowlist.
- Create 201, absent resource 404, invalid input 422, unauthorized access policy consistent.
- Membership authenticated identity se verify, body user_id trust nahi.
- List stable sort + limit cap; parameterized query/ORM expressions.
- PATCH only allowed fields; version conflict 409; failed write rollback.
- Duplicate/concurrent requests ka behavior define.

**Solution approach:** route → validation/dependencies → permission check → service transaction → ORM → output schema. Schema/session code [backend guide](02-fastapi-quick-guide.md) aur race strategy [DB guide](04-database-quick-guide.md) mein hai.

**Tests interviewer ko bolo:** happy path, whitespace title, wrong tenant ID, no membership, missing record, stale version, DB commit failure. In-memory dict prototype ko multi-worker persistent solution mat present karo.

## Round B — React task search (45 min)

**Prompt:** search/filter, loading/error/empty states, debounced API, select task, edit title.

**Acceptance criteria:**

- Old response latest search ko overwrite na kare.
- Unmount/query change par timer/request cleanup.
- Fetch non-2xx handled; user ko retry available.
- Stable keys, labelled input, keyboard usable controls.
- Save pending/failed/conflict states; rapid duplicate submission handled.

**Solution:** [useSearch example](03-react-nextjs-quick-guide.md) likho; API adapter ko separate rakho; query cache available ho toh equivalent key/cancellation explain karo.

**Manual scenarios:** “rea” slow, “react” fast → latest results only; query clear → empty state; 500 → error; screen leave → no obsolete state update. Network tab aur test delayed promises se race verify karo.

## Round C — SQL (30 min)

[Practice schema](04-database-quick-guide.md) use karo. Bina solution dekhe:

1. Har user ka paid count including zero (8 min).
2. Latest order per user with deterministic tie-breaker (8 min).
3. Users without orders (5 min).
4. Feed index and cursor query explain karo (9 min).

**Expected results:** paid counts Asha=2/Ravi=0/Neha=0; latest IDs 102/103; no-order user 3; before cursor `(Sep 2, 102)` for user 1 gives 101. Missing row, tied timestamps aur NULL follow-ups discuss karo.

## Round D — DSA (30 min)

**Prompt:** longest substring without repeated characters ka length. Start brute force, then optimize.

```python
def longest_unique(text: str) -> int:
    last_seen = {}
    left = best = 0
    for right, char in enumerate(text):
        if char in last_seen:
            left = max(left, last_seen[char] + 1)
        last_seen[char] = right
        best = max(best, right - left + 1)
    return best

assert longest_unique('') == 0
assert longest_unique('abba') == 2
assert longest_unique('abcabcbb') == 3
assert longest_unique('bbbb') == 1
```

**Explanation:** window unique rakho; old duplicate agar current window ke bahar hai toh left backward nahi move hona chahiye, isliye `max`. Average O(n) time, O(min(n, alphabet)) space. Python string code points count karta hai, grapheme clusters nahi.

Next patterns: hashmap/two sum, stack/balanced brackets, intervals/merge, binary search, BFS/DFS basics. [DSA reference](../04-system-design-dsa/12-dsa-essentials.md).

## Round E — full-stack debugging (20 min)

**“Save successful, refresh par old data.”** API response vs persisted row → transaction commit → replica lag → cache invalidation → stale response → environment mismatch. Har hypothesis ke liye evidence name karo.

**“Load badhne par latency shoots up.”** Trace DB duration/pool wait, query counts, external API time, CPU/event loop, queue depth. More workers blindly add karne se DB worse ho sakta hai.

**“Do users ek dusre ke tasks dekh rahe.”** Resource authorization, tenant context, shared cache keys, stale login cache. Reproduce with two identities; API negative integration test add karo.

## 45-minute oral mock + answer checkpoints

| Minutes | Prompt | Strong answer includes |
|---|---|---|
| 0–5 | Intro + one real feature | ownership, constraints, outcome |
| 5–10 | async vs threads? | blocking calls, I/O vs CPU, bounded concurrency |
| 10–15 | DB transaction vs session? | atomic unit vs ORM lifecycle, commit/rollback |
| 15–20 | Last stock race? | conditional update/lock, affected rows |
| 20–25 | React stale result? | closures, response ordering, cleanup |
| 25–30 | JWT enough for access? | token verification + resource permissions |
| 30–40 | Task manager design | contracts, DB, failures, measured scale |
| 40–45 | Incident/story | real evidence, trade-off, learning |

## 20 rapid questions: pehle answer bolo, phir checkpoint dekho

| Question | Minimum checkpoint |
|---|---|
| Python mutable default? | definition-time object shared |
| Shallow copy? | nested references shared |
| Generator benefit? | lazy production; consumer may materialize |
| `await` CPU parallelism? | no; cooperative suspension |
| FastAPI sync helper offload? | only framework-called sync route/dependency automatic |
| Pydantic vs TS? | runtime validation vs compile-time typing |
| DI vs middleware? | route resource/requirements vs cross-cutting request concern |
| 401 vs 403? | authentication vs permission |
| Idempotent retry? | repeated intended effect; durable dedup scope |
| N+1? | parent query plus per-parent relation fetch |
| LEFT JOIN WHERE trap? | null-rejecting predicate removes unmatched rows |
| Index always faster? | no, selectivity/cost/write overhead |
| Serializable retries? | abort then entire transaction retry |
| State setter immediate? | current render snapshot unchanged |
| Why stable key? | preserve intended component identity |
| Effect cleanup? | before re-setup and unmount |
| `useMemo` guarantee? | performance optimization, not semantic storage |
| Server state? | remote data/cache lifecycle distinct from UI state |
| RSC vs SSR? | component execution model vs HTML rendering |
| Outbox solves duplicates? | closes DB/publication gap; duplicates still possible |

## Scorecard + repair loop

Har dimension 0–4: correctness, reasoning/trade-offs, implementation, edge cases/tests, communication. 0=no answer; 1=memorized; 2=happy path; 3=correct with follow-ups; 4=independent implementation + limits.

Practice target: 15/20 with no zero in correctness or implementation. Yeh self-assessment threshold hai, hiring prediction nahi. Mistake log: date | question | wrong assumption | corrected answer | exercise | retry date. Missed topic next day, 3 days later, 7 days later repeat karo.

Behavioral answers mein real project, actual role aur measured outcome hi use karo. [STAR templates](../05-behavioral/13-project-talking-points.md).
