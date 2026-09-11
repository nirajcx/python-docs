# Python Asynchronous Programming: AsyncIO & Concurrency

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [01-python-fundamentals.md](./01-python-fundamentals.md) | [04-fastapi-core.md](../02-fastapi-backend/04-fastapi-core.md) | [10-llm-integration.md](../03-rag-vector-genai/10-llm-integration.md)

---

## 1. AsyncIO Mental Bridge: Node.js vs. Python

Coming from a **Node.js/Express** background, the event loop concept will feel familiar, but Python has crucial architectural differences:

| Concept | Node.js (V8 + libuv) | Python (`asyncio` + CPython) |
|---|---|---|
| **Event Loop Activation** | Starts automatically with the process | Must be explicitly started (`asyncio.run()`) |
| **Execution Paradigm** | Asynchronous by default (callbacks / Promises) | Synchronous by default; async is opt-in |
| **Function Invocations** | Calling `async fn()` starts executing immediately | Calling `async def fn()` returns a **cold coroutine object**; it does nothing until `await`ed or scheduled as a `Task` |
| **Blocking the Loop** | `fs.readFileSync` blocks libuv thread | Any standard sync call (`time.sleep`, `requests.get`, sync DB) freezes the **entire** event loop |
| **Loop Replacement** | Fixed libuv implementation | Pluggable (e.g., `uvloop`, a drop-in C-based libuv replacement for 2-4x speedup) |

---

## 2. Core Building Blocks: Coroutines, Tasks, and Futures

```python
import asyncio

# 1. Coroutine Function: async def
async def fetch_embedding(doc_id: str) -> list[float]:
    await asyncio.sleep(0.5)  # Yields control back to the event loop
    return [0.01 * len(doc_id)]

# 2. Cold Coroutine: Calling it does NOT run it yet
coro = fetch_embedding("doc_42")
print(type(coro))  # <class 'coroutine'>

async def main():
    # 3. Running sequentially:
    result = await coro  # Execution starts here
    
    # 4. Task: Wraps a coroutine and schedules it on the event loop IMMEDIATELY
    task = asyncio.create_task(fetch_embedding("doc_99"))
    # task is now running concurrently in the background!
    
    val = await task
    print(val)

asyncio.run(main())
```

### Future vs. Task vs. Coroutine
- **Coroutine**: A generator-like object returned by an `async def` function. Suspends execution using `await`.
- **Future**: A low-level object representing an eventual result of an asynchronous operation (similar to a JS Promise in pending state).
- **Task**: A subclass of `Future` that wraps a coroutine and schedules its execution on the event loop.

---

## 3. The Cardinal Sin: Blocking the Event Loop & How to Fix It

If you run a synchronous, blocking library (such as `requests`, `time.sleep`, or standard `psycopg2`) inside an `async def` endpoint in FastAPI, **the entire server stops handling all other concurrent client requests**.

### Anti-Pattern vs. Production Fix
```python
import time
import requests
import asyncio

# BAD: Freezes the event loop for all users!
async def bad_rag_endpoint():
    time.sleep(2)  # FREEZES ALL REQUESTS
    res = requests.get("https://api.openai.com/v1/models")  # FREEZES ALL REQUESTS
    return res.json()

# SENIOR FIX 1: Use native async libraries
import httpx

async def good_rag_endpoint():
    await asyncio.sleep(2)  # Cooperatively yields control
    async with httpx.AsyncClient() as client:
        res = await client.get("https://api.openai.com/v1/models")
        return res.json()

# SENIOR FIX 2: Offload unavoidable sync / CPU-bound work to a thread pool
def legacy_sync_calc(data: str) -> str:
    time.sleep(1)  # Simulating heavy legacy SDK or CPU sync logic
    return data.upper()

async def safe_offloaded_endpoint():
    # Python 3.9+ built-in helper for ThreadPoolExecutor
    result = await asyncio.to_thread(legacy_sync_calc, "document_text")
    return {"result": result}
```

---

## 4. Concurrent Execution: `gather`, `TaskGroup`, and Timeouts

When building RAG, you frequently need to fan out queries (e.g., retrieving from dense index, BM25 index, and metadata store concurrently).

### Python 3.11+ Modern Standard: `asyncio.TaskGroup`
`asyncio.TaskGroup` provides structured concurrency. If any task inside the group fails, all remaining tasks are cancelled immediately, preventing orphaned tasks and leaked resources.

```python
async def fetch_vector_matches(query: str):
    await asyncio.sleep(0.2)
    return ["chunk_1", "chunk_2"]

async def fetch_bm25_matches(query: str):
    await asyncio.sleep(0.15)
    return ["chunk_2", "chunk_3"]

# MODERN STRUCTURAL CONCURRENCY (Python 3.11+)
async def hybrid_retrieve(query: str):
    async with asyncio.TaskGroup() as tg:
        t1 = tg.create_task(fetch_vector_matches(query))
        t2 = tg.create_task(fetch_bm25_matches(query))
        
    # Both tasks guaranteed completed here; if one raised an error,
    # ExceptionGroup is raised and unhandled tasks are cleanly cancelled.
    return {"dense": t1.result(), "sparse": t2.result()}

# LEGACY / CLASSIC: asyncio.gather
async def legacy_retrieve(query: str):
    # return_exceptions=True prevents one error from failing the whole batch
    results = await asyncio.gather(
        fetch_vector_matches(query),
        fetch_bm25_matches(query),
        return_exceptions=False
    )
    return results
```

### Strict Timeouts with `asyncio.timeout` (Python 3.11+)
```python
async def query_llm_with_deadline():
    try:
        async with asyncio.timeout(3.0):  # Hard deadline: 3 seconds
            async with httpx.AsyncClient() as client:
                resp = await client.post("https://api.openai.com/v1/chat/completions", timeout=5.0)
                return resp.json()
    except TimeoutError:
        print("LLM took too long! Fallback to cached answer or smaller model.")
        return {"fallback": True}
```

---

## 5. Task Cancellation & Graceful Shutdown

When a client disconnects in FastAPI or a deadline expires, tasks may be cancelled. Unhandled cancellations can cause database connection leaks or incomplete audit trails.

```python
async def process_document_indexing(doc_id: str):
    try:
        print(f"Indexing started for {doc_id}")
        await asyncio.sleep(5)
        print(f"Indexing completed for {doc_id}")
    except asyncio.CancelledError:
        print(f"Task for {doc_id} was cancelled! Cleaning up temporary chunks...")
        # Clean up temporary scratch tables or vector drafts
        raise  # MUST re-raise CancelledError to acknowledge cancellation!
```

---

## 6. Concurrency Decision Matrix

| Workload Type | Example | Recommended Solution | Why |
|---|---|---|---|
| **High I/O Network Calls** | Calling OpenAI APIs, fetching web pages, FastAPI routing | **AsyncIO (`async/await`)** | Minimal memory overhead per connection, single-threaded, thousands of concurrent sockets. |
| **Blocking Sync I/O** | Legacy DB SDK (`psycopg2`), reading files from disk, third-party sync libraries | **`asyncio.to_thread()` / ThreadPool** | Frees up main event loop while thread waits on disk or OS socket. |
| **Heavy CPU / Compute** | Calculating tokenizers, matrix operations, local PyTorch inference | **`ProcessPoolExecutor` / Multiprocessing** | Bypasses Python's GIL by spinning separate OS processes with dedicated memory. |
| **Long-Running Background Tasks** | Document parsing (100MB PDF OCR), model retraining, bulk ingest | **Celery / ARQ / Redis Queue** | Offloads execution outside of the web server lifecycle into distributed worker fleets. |

---

## 7. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What happens if you define `def` instead of `async def` in a FastAPI route?"**
   - FastAPI inspects the signature. If it is a regular `def`, FastAPI runs the endpoint inside an external **threadpool** (`anyio.to_thread.run_sync`), not the main event loop! This protects against blocking, but incurs thread context-switching overhead.
2. **"Can you run an event loop inside a thread that already has an event loop?"**
   - By default, each OS thread has at most one active event loop. Calling `asyncio.get_event_loop()` in a new thread will raise an error unless `asyncio.new_event_loop()` and `asyncio.set_event_loop()` are called first.
3. **"What is the difference between `asyncio.gather(*tasks)` and `asyncio.as_completed(tasks)`?"**
   - `gather` waits for *all* tasks to finish (or the first exception, unless `return_exceptions=True`) and preserves the original input order.
   - `as_completed` returns an iterator that yields results **as soon as each individual task finishes**, allowing you to stream or render results in real-time.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: How does the Python Event Loop work internally?
**Answer:**
The event loop is a single-threaded infinite loop that monitors OS I/O events using OS-level polling primitives (`epoll` on Linux, `kqueue` on macOS, `IOCP` on Windows) via Python's `selectors` module.  
When an `await` expression is evaluated, the current coroutine yields execution back to the event loop along with a file descriptor / timer to watch. The event loop switches to execute other ready tasks. Once the OS signals that the I/O event is ready (or the sleep timer triggers), the event loop places the paused coroutine back into the ready queue to resume execution from the exact point it suspended.

### Q2: Why does Python 3.11 prefer `asyncio.TaskGroup` over `asyncio.gather`?
**Answer:**
`asyncio.TaskGroup` implements **structured concurrency**. In `asyncio.gather`, if one coroutine crashes with an exception, the other coroutines continue running in the background unmanaged (known as task leakage or orphan tasks).  
With `asyncio.TaskGroup`, an exception in one child task immediately cancels all other sibling tasks within the group, and packages any raised exceptions cleanly into an `ExceptionGroup`, guaranteeing no lingering background tasks consume compute or keep connections open.

### Q3: How do you safely call an async coroutine from synchronous code?
**Answer:**
- If **no event loop is running** in the current thread: Use `asyncio.run(coroutine())`. This initializes a fresh loop, runs the coroutine to completion, closes the loop, and shuts down asynchronous generators.
- If **an event loop is already running** (e.g., inside Celery or a sync callback in a running framework), calling `asyncio.run()` will raise `RuntimeError: This event loop is already running`. In that case, you must run it in a separate thread via `concurrent.futures` or schedule it with `asyncio.run_coroutine_threadsafe(coro, loop)`.

### Q4: What is `uvloop`, and why is it used with FastAPI in production?
**Answer:**
`uvloop` is a fast, drop-in replacement for the default `asyncio` event loop implemented in Cython on top of `libuv` (the same C-based I/O library that powers Node.js). It optimizes memory allocation and polling loops, making Python async I/O roughly **2 to 4 times faster**, reaching speeds competitive with Node.js and Go network runtimes. Uvicorn uses `uvloop` automatically when installed in production environments.

### Q5: How do you prevent race conditions in async Python without the GIL?
**Answer:**
Even though single-threaded async code does not have OS-level preemption across threads, race conditions still occur at **interleaving points** (any place where code `await`s). If two coroutines read shared state, `await` an I/O operation, and then write back to the shared state, one will overwrite the other.  
To prevent this, use `asyncio.Lock()`, `asyncio.Semaphore()`, or atomic in-memory structures:
```python
lock = asyncio.Lock()

async def safe_increment():
    async with lock:
        # Critical section: No other coroutine can enter while this yields at an await
        val = await db.get_counter()
        await db.set_counter(val + 1)
```
