# Interview Questions Bank: FAANG & Tier-1 Staff Systems, AI & Architecture

> **Target Audience:** FAANG / Tier-1 MNC Staff & Principal Engineering Rounds  
> **Style:** Rigorous Technical Depth, Mathematical Proofs, Systemic Failure Modes, Verbatim Staff-Level Responses  
> **Cross-References:** [22-cpython-interpreter-and-descriptors.md](../01-python-core/22-cpython-interpreter-and-descriptors.md) | [23-asgi-internals-and-redis-ratelimit.md](../02-fastapi-backend/23-asgi-internals-and-redis-ratelimit.md) | [24-llm-serving-pagedattention.md](../03-rag-vector-genai/24-llm-serving-pagedattention.md) | [26-distributed-systems-kafka-saga.md](../04-system-design-dsa/26-distributed-systems-kafka-saga.md)

---

### Q1: How does Python 3.11's Adaptive Specializing Interpreter (PEP 659) operate at the bytecode level, and how does it handle polymorphic call sites?
#### Staff Model Answer:
"Prior to Python 3.11, bytecode instructions executed static, generic evaluation routines. PEP 659 introduced an adaptive bytecode engine:
1. **Warmup & Profiling**: Instructions start with an adaptive counter. When an instruction executes 8 times on uniform types, it transitions to the 'hot' state.
2. **Specialization**: The VM rewrites the opcode in-memory into a specialized variant:
   - `LOAD_ATTR` becomes `LOAD_ATTR_INSTANCE_VALUE` or `LOAD_ATTR_SLOT`.
   - `BINARY_OP` becomes `BINARY_OP_ADD_FLOAT` or `BINARY_OP_ADD_INT`.
   - An **inline cache** entry is written into the bytecode stream holding the type version and exact memory offset.
3. **Polymorphic De-optimization**: If a call site is polymorphic (e.g. alternating between integers and strings), the type check fails. The interpreter de-specializes the instruction back to the generic opcode, avoiding thrashing. If polymorphism is low (e.g. bimorphic), it can specialize to a quickened multi-type handler."

---

### Q2: Why is the Redlock algorithm considered flawed for strict mutual exclusion, and how do Fencing Tokens resolve it?
#### Staff Model Answer:
"Martin Kleppmann proved that Redlock relies on an **asynchronous network model with dangerous synchrony assumptions (bounded clock drift and bounded execution pauses)**.  
If Client 1 acquires a Redlock across a quorum of Redis nodes with a 10-second TTL, but then experiences a **Stop-the-World Garbage Collection pause, OS process preemption, or network delay lasting 12 seconds**, the lock lease expires in Redis.  
Redis grants the lock to Client 2. When Client 1's GC pause ends, it believes it still holds the lock and proceeds to write to the storage layer, corrupting state.  
**Fencing Tokens Resolution:**
A reliable lock service must return a **monotonically increasing integer token** (e.g. 101, 102). When writing to the database, the transaction enforces:
```sql
UPDATE balance_ledger SET amount = amount + 50, last_token = 102 
WHERE account_id = 'A' AND last_token < 102;
```
When Client 1 resumes with stale token 101, the database rejects the write because $101 < 102$, ensuring safety regardless of how long the client paused."

---

### Q3: What is the exact difference between continuous batching and naive static batching in LLM serving?
#### Staff Model Answer:
"- **Static Batching**: Requests $R_1 \dots R_N$ are grouped together and run through the model simultaneously. The forward pass must wait until the *longest sequence* in the batch finishes generating. If $R_1$ finishes in 50 tokens and $R_2$ requires 1,000 tokens, $R_1$'s allocated GPU memory and compute sit completely idle for 950 generation steps.  
- **Continuous Batching (Iteration-Level Scheduling - Orca / vLLM)**: Operates at the single-token iteration step. At every decode iteration:
  1. Requests that emit an end-of-sequence (`<|endoftext|>`) token are evicted immediately, freeing their KV cache blocks.
  2. Newly arrived requests from the queue are injected into the batch dynamically for their prefill phase alongside the active decode requests.  
  This increases GPU compute saturation and multiplies serving throughput by **$2\text{--}4\times$**."

---

### Q4: In an ASGI application, what are `scope`, `receive`, and `send`, and how does Starlette's middleware stack execute them?
#### Staff Model Answer:
"Under ASGI 3.0, the application interface is `async def app(scope, receive, send)`:
- **`scope`**: Connection metadata dictionary initialized by Uvicorn (contains protocol type `'http'` or `'websocket'`, HTTP method, path, headers, client IP). It persists for the entire connection.
- **`receive`**: An async callable yielding incoming events (e.g. `{'type': 'http.request', 'body': b'...', 'more_body': False}`).
- **`send`**: An async callable that streams response events back to Uvicorn (`http.response.start` with status code and headers, followed by `http.response.body`).  
**Middleware Pipeline**: Middleware wraps `app` like an onion. A middleware receives `(scope, receive, send)`, can inspect or mutate `scope`, wraps `receive` (to inspect incoming body streams), and wraps `send` (to inject headers like `X-Process-Time` or compress output bytes) before forwarding to the downstream application."

---

### Q5: Disassemble the React Server Components (RSC) Flight Protocol wire format. What does the browser actually receive?
#### Staff Model Answer:
"RSC does not send HTML or raw JavaScript. It streams an optimized JSON-based Abstract Syntax Tree (AST) known as the **Flight payload**:
- `1:I["./Button.tsx", ["default"], "Button"]`: **Module Reference**. Tells the client that component `Button` is a Client Component located at that bundle chunk.
- `0:["$","div",null,{"className":"hero","children":["Hello",["$","$1",null,{"variant":"primary"}]]}]`: Represents virtual DOM elements. Tags rendered by Server Components are emitted as plain JSON data requiring 0 KB of client JS bundle. The placeholder `"$1"` points to the module reference defined in line 1.
- `S...`: Suspense boundaries streamed asynchronously over HTTP chunked transfer encoding as server-side Promises resolve."

---

### Q6: How does Kafka guarantee Exactly-Once Semantics (EOS) in a stream processing pipeline?
#### Staff Model Answer:
"Kafka guarantees EOS using two coordinated mechanisms:
1. **Idempotent Producer**:
   - The broker assigns each producer a unique 64-bit **Producer ID (PID)**.
   - Each message sent by the producer carries a monotonically increasing **Sequence Number**.
   - The broker tracks sequence numbers per partition and silently deduplicates any message arriving with a sequence number $\le$ the last acknowledged number.
2. **Transactional Coordinator**:
   - In a consume-transform-produce loop, messages are produced to output topics and consumer offsets are committed to `__consumer_offsets` within a **single atomic Kafka transaction**.
   - The transaction coordinator writes a commit marker to the partition log.
   - Downstream consumers configured with `isolation.level = read_committed` will never see aborted messages or uncommitted writes."
