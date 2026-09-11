# Interview Questions Bank: Python Core & FastAPI

Target Role: Mid / Senior Python & FastAPI Developer  
Cross-References: [01-python-fundamentals.md](../01-python-core/01-python-fundamentals.md) | [03-python-async.md](../01-python-core/03-python-async.md) | [04-fastapi-core.md](../02-fastapi-backend/04-fastapi-core.md) | [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md)

---

### Q1: What happens under the hood when a function is called in Python with default arguments?
#### Junior Answer:
"The default value is assigned to the parameter whenever the caller doesn't pass an argument."
#### Senior In-Depth Answer:
"Default parameter expressions are evaluated **once at function definition time** when the module is compiled into bytecode, not at runtime when the function is invoked. Python stores default values as a tuple on the function object (`func.__defaults__`). If a default value is a mutable object like a list or dictionary, modifications made to that argument inside the function persist across subsequent calls to that function. The idiomatic senior pattern is to use `None` as the default sentinel and initialize a fresh mutable instance inside the function body (`if arg is None: arg = []`)."

---

### Q2: How does Python's Global Interpreter Lock (GIL) impact multithreaded applications, and why can't we simply remove it?
#### Junior Answer:
"The GIL stops threads from running at the same time so Python can only use one CPU core."
#### Senior In-Depth Answer:
"The GIL is a mutual exclusion mutex in CPython that ensures only one native OS thread executes Python bytecode at any instant. It protects CPython's memory management system, which relies on non-thread-safe reference counting (`ob_refcnt`). Removing the GIL naively would require adding fine-grained locks to every pointer allocation and reference count modification, introducing massive single-threaded CPU overhead (up to 30% slowdown).  
In I/O-bound multithreading (e.g. socket reads, disk I/O), C extensions release the GIL while waiting on the operating system, allowing high concurrency. For CPU-bound parallelism, the solution is `multiprocessing` (separate processes each with their own memory space and GIL) or PEP 703 (free-threaded Python 3.13+)."

---

### Q3: What is the exact execution difference in FastAPI between defining an endpoint as `def endpoint()` vs `async def endpoint()`?
#### Junior Answer:
"`async def` is asynchronous and faster, while `def` is normal synchronous code."
#### Senior In-Depth Answer:
"FastAPI uses Starlette's execution planner:
- If an endpoint is declared as **`async def`**, FastAPI runs it directly on the **main event loop thread**. If you execute blocking code inside it (`time.sleep(5)`, `requests.get()`, or synchronous DB calls), you freeze the entire event loop, preventing all other concurrent requests from being processed.
- If an endpoint is declared as **`def`** (synchronous), FastAPI detects this and offloads the function to an external **worker threadpool** (`anyio.to_thread.run_sync`). The main event loop continues serving other requests while the thread waits.  
*Rule:* Only use `async def` when calling non-blocking asynchronous libraries (`await httpx.get()`, `await db.execute()`). If using legacy sync SDKs, either use standard `def` or explicitly offload via `await asyncio.to_thread(sync_fn)`."

---

### Q4: How does FastAPI's Dependency Injection system handle state cleanup and transaction rollbacks?
#### Junior Answer:
"You use `Depends()` in your route arguments and return the database session."
#### Senior In-Depth Answer:
"FastAPI leverages Python generator functions with `yield` to implement contextual dependency lifetimes:
```python
async def get_db_session():
    session = AsyncSessionLocal()
    try:
        yield session
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    finally:
        await session.close()
```
FastAPI runs the code prior to `yield` before the endpoint logic executes. After the HTTP response is generated and delivered to the client, FastAPI resumes the generator in the `finally` block, ensuring connections and locks are cleaned up even if the route raised an unhandled exception."

---

### Q5: What are the differences between Pydantic v1 and Pydantic v2, and why does it matter for high-throughput APIs?
#### Junior Answer:
"Pydantic v2 has updated syntax like `model_dump` instead of `dict`."
#### Senior In-Depth Answer:
"Pydantic v2 completely rewrote the core validation and serialization logic in **Rust** (`pydantic-core`), resulting in a **5x to 15x performance speedup** in serialization and parsing throughput.  
Architectural shifts include:
1. Deprecation of `@validator` and `@root_validator` in favor of `@field_validator` and `@model_validator(mode='before'|'after')`.
2. Replacement of `.dict()` and `.json()` with `.model_dump()` and `.model_dump_json()`.
3. Strict mode validation (`strict=True`), which stops coercive type conversions (e.g. converting string `'123'` to integer `123`), ensuring rigid API schema compliance."

---

### Q6: How do you implement Server-Sent Events (SSE) in FastAPI for streaming LLM tokens, and what infrastructure pitfalls exist?
#### Junior Answer:
"You use `StreamingResponse` and yield chunks of text in a loop."
#### Senior In-Depth Answer:
"You return a `StreamingResponse` wrapping an asynchronous generator that yields lines adhering to the SSE protocol: `f'data: {json.dumps(payload)}\n\n'`:
```python
@app.get("/stream")
async def stream():
    async def token_gen():
        async for chunk in llm_stream:
            yield f"data: {chunk}\n\n"
        yield "data: [DONE]\n\n"
    return StreamingResponse(token_gen(), media_type="text/event-stream")
```
*Critical Infrastructure Gotcha:* If your service sits behind an **NGINX** reverse proxy, NGINX buffers HTTP responses by default until a buffer threshold is reached, completely destroying real-time streaming for end users. You must disable proxy buffering by passing the response header `X-Accel-Buffering: no` or configuring `proxy_buffering off;` in NGINX."

---

### Q7: How would you debug a high-memory leak in a long-running FastAPI/Python service deployed in Docker?
#### Junior Answer:
"Look through the code for unclosed files and add more RAM to the Docker container."
#### Senior In-Depth Answer:
"1. **Analyze GC & Allocation**: Use Python's standard `tracemalloc` to capture memory snapshots before and after high-load endpoints (`snapshot.compare_to(previous, 'lineno')`) to see which lines allocate untracked memory.  
2. **Check for Unbounded Global State**: In-memory caches (e.g. Python dictionaries decorated with `@lru_cache` without a `maxsize`, or global arrays appending logs).  
3. **Circular References with Broken Finalizers**: Inspect `gc.garbage` and analyze reference cycles using the `objgraph` library to identify unreachable objects holding memory.  
4. **C-Level Extension Leaks**: In AI microservices, libraries like PyTorch or Tokenizers allocate memory outside Python's heap. Use `jemalloc` or `valgrind` to monitor external heap allocations."

---

### Q8: How does `asyncio.TaskGroup` in Python 3.11+ improve over `asyncio.gather`?
#### Junior Answer:
"It's a newer context manager syntax to run multiple tasks together."
#### Senior In-Depth Answer:
"`asyncio.TaskGroup` implements **Structured Concurrency**. With legacy `asyncio.gather(*tasks)`, if one task raises an exception, the other sibling tasks continue running in the background unmanaged (known as task leakage or orphaned coroutines).  
With `async with asyncio.TaskGroup() as tg:`, if any task raises an exception, the context manager automatically and immediately cancels all other running tasks inside the group and packages any raised exceptions cleanly into an `ExceptionGroup`. This guarantees no leaked network sockets or dangling compute tasks."
