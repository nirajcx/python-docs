# Advanced / Optional 🧗

> **Skip this folder on your first pass.**

These files are deep, Staff/FAANG-level internals. They were written for a much more senior target than a 2.5-YOE developer interviewing at mid-size companies. Reading them now would eat your time and shake your confidence for little interview payoff.

**Come back here only if:**
- An interviewer specifically drills into low-level internals, OR
- You're interviewing somewhere known for very hard rounds, OR
- You've already mastered everything in [`../00-start-here/`](../00-start-here/) and the core files and want to go further.

**Your actual study path lives in [`../00-start-here/`](../00-start-here/).**

---

## What's in here (for reference)

| File | Topic | Why it's advanced |
|---|---|---|
| `19-high-scale-traffic-and-fintech.md` | 1K–100K QPS, flash sales, double-spend prevention | Extreme scale most mid-size roles won't test |
| `20-advanced-database-engineering-and-migrations.md` | B-Tree page splits, `EXPLAIN BUFFERS`, zero-downtime migrations | DBA/Staff-level depth |
| `21-memory-optimization-and-leaks.md` | PyMalloc arenas, GC generations, tracemalloc | Interpreter internals |
| `22-cpython-interpreter-and-descriptors.md` | CPython VM, PEP 659, descriptors, metaclasses | Compiler/VM internals |
| `23-asgi-internals-and-redis-ratelimit.md` | ASGI scope/receive/send, Lua rate limiters | Protocol-level detail |
| `24-llm-serving-pagedattention.md` | KV-cache math, PagedAttention, vLLM | ML infra / GPU math |
| `25-genai-security-and-guardrails.md` | Prompt injection, ACL vector filtering | Specialized AI security |
| `26-distributed-systems-kafka-saga.md` | Redlock critique, Saga vs 2PC, Kafka EOS | Distributed systems theory |
| `27-microfrontends-and-rsc-internals.md` | Module Federation, RSC Flight wire protocol | Frontend architecture internals |
| `28-advanced-dsa-faang-patterns.md` | Monotonic stack, Trie, Union-Find, topo sort | Hard DSA (FAANG-tier) |
| `29-faang-cross-domain-interview-scenarios.md` | 12 integrated Staff scenarios | Staff-level breadth |
| `30-javascript-core-and-event-loop-deep-dive.md` | V8 heap/stack, dual event-loop deep dive | Engine internals |

Good reference material to grow into over time — just not your priority right now.
