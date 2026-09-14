# ASGI Architecture Internals, Advanced Pydantic v2 & Distributed Rate Limiting

> **Target Audience:** FAANG / Tier-1 MNC Staff & Senior Backend Engineers  
> **Evaluation Focus:** ASGI Request Lifecycle, Starlette vs Uvicorn, Pydantic-Core Rust, Redis Lua Rate Limiters  
> **Cross-References:** [04-fastapi-core.md](../02-fastapi-backend/04-fastapi-core.md) | [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md) | [19-high-scale-traffic-and-fintech.md](19-high-scale-traffic-and-fintech.md)

---

## 1. ASGI Architecture Internals: The Complete Request Lifecycle

While WSGI (Flask, Django) was synchronous and single-request-per-worker, **ASGI (Asynchronous Server Gateway Interface)** provides a standard interface for async-capable Python web servers, frameworks, and applications.

```
                              THE COMPLETE ASGI REQUEST FLOW
                              
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 1. ASGI Web Server (Uvicorn / Hypercorn)                                        │
 │    • Binds to TCP Socket; parses HTTP/1.1 or HTTP/2 via httptools (C library)   │
 │    • Constructs the `scope` dictionary from connection metadata                 │
 └────────────────────────────────────────┬────────────────────────────────────────┘
                                          │ Calls: app(scope, receive, send)
                                          ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 2. Middleware Stack (Starlette Outer Pipeline)                                  │
 │    • Request ID Injection ──► CORS Headers ──► GZip Compression                 │
 └────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 3. Starlette Routing Engine                                                     │
 │    • Matches URL path against registered Route regexes                          │
 │    • Dispatches to endpoint handler callable                                    │
 └────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 4. FastAPI Dependency & Validation Engine                                       │
 │    • Executes `Depends()` graph (Auth, DB session setup)                        │
 │    • Passes request body to `pydantic-core` for Rust-based JSON validation      │
 └────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 5. User Endpoint Logic: async def endpoint(...)                                 │
 │    • Executes business logic / queries DB / calls AI models                     │
 └────────────────────────────────────────┬────────────────────────────────────────┘
                                          │ Returns response data
                                          ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │ 6. Response Pipeline (Starlette & Uvicorn)                                      │
 │    • Serializes output to JSON (Pydantic `model_dump_json()`)                  │
 │    • Calls `await send({"type": "http.response.start", "status": 200, ...})`    │
 │    • Calls `await send({"type": "http.response.body", "body": b"...", ...})`    │
 │    • Executes dependency `yield` teardown (commits/closes DB session)           │
 └─────────────────────────────────────────────────────────────────────────────────┘
```

### The ASGI Application Callable Specification
At its core, an ASGI 3.0 application is a single asynchronous callable:
```python
async def app(scope: dict, receive: callable, send: callable) -> None:
    pass
```

- **`scope`**: A dictionary containing connection metadata. It exists for the entire connection duration:
  - `scope['type']`: `'http'`, `'websocket'`, or `'lifespan'`.
  - `scope['method']`: `'GET'`, `'POST'`, etc.
  - `scope['path']`: Request path (e.g. `'/api/v1/documents'`).
  - `scope['headers']`: Raw iterable of `(name, value)` 2-item tuples in bytes.
- **`receive`**: An async callable returning an event dictionary:
  - For HTTP: `await receive()` yields `{"type": "http.request", "body": b"...", "more_body": False}`.
- **`send`**: An async callable invoked to send messages back to the client:
  - Step 1: `await send({"type": "http.response.start", "status": 200, "headers": [...]})`.
  - Step 2: `await send({"type": "http.response.body", "body": b"payload", "more_body": False})`.

### The Lifespan Protocol
Replaces legacy `@app.on_event("startup")` with structured concurrency:
```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: scope['type'] == 'lifespan', receive() -> 'lifespan.startup'
    print("Initializing Qdrant client connection pool...")
    yield
    # SHUTDOWN: receive() -> 'lifespan.shutdown', send() -> 'lifespan.shutdown.complete'
    print("Flushing caches and draining database pools...")

app = FastAPI(lifespan=lifespan)
```

---

## 2. Advanced Pydantic v2 Internals & `pydantic-core` (Rust Engine)

Pydantic v2 achieved a **5–15x performance increase** by rewriting all data parsing, validation, and serialization in **Rust** (`pydantic-core`).

### Validation vs. Serialization Pipeline
```
               Pydantic v2 Parsing & Validation Architecture
               
 Input (JSON bytes / dict)
            │
            ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ pydantic-core (Rust Engine)                                 │
 │ 1. Validates schema types in compiled Rust code             │
 │ 2. mode='before' Validators execute (Raw Python/Rust objects)│
 │ 3. Rust coercion (e.g., parsing ISO strings into Timestamps)│
 │ 4. mode='after' Validators execute (Validated Python Model) │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                                ▼
                       Validated Python Model
```

### Modern `Annotated` Pattern with Custom Reusable Validators
```python
from typing import Annotated
from pydantic import BaseModel, Field, AfterValidator, PlainSerializer

def validate_uppercase_code(v: str) -> str:
    if not v.isupper():
        raise ValueError("Code must be all uppercase")
    return v

# Reusable typed field with validation and custom JSON serialization
TenantCode = Annotated[
    str,
    Field(min_length=3, max_length=10),
    AfterValidator(validate_uppercase_code),
    PlainSerializer(lambda v: v.strip(), return_type=str)
]

class EnterpriseTenantPayload(BaseModel):
    tenant_code: TenantCode
    max_storage_gb: int = Field(gt=0)
```

---

## 3. Distributed Rate Limiting: Redis Lua Scripts

### Rate Limiting Algorithms Comparison
| Algorithm | How it Works | Pros | Cons | Best Used For |
|---|---|---|---|---|
| **Fixed Window** | Counter reset every fixed minute/hour | Lowest memory | Burst at window boundary ($2\times$ limit)| Basic API protection |
| **Sliding Window Log**| Stores timestamps of every request in sorted set | 100% exact window | High memory footprint ($O(N)$ timestamps) | Low-volume, expensive endpoints |
| **Token Bucket** | Tokens refill at constant rate; burst capacity | Allows bursts up to bucket capacity | Slightly more complex state | General API rate limiting |
| **Leaky Bucket** | Requests leak at steady rate | Smooths out traffic spikes | Discards bursts; increases latency | E-commerce checkout queues |

### Production-Grade Atomic Redis Lua Token Bucket
Running rate limiting logic across multiple Redis calls from Python creates **race conditions**. A **Lua script** runs atomically inside Redis's single-threaded event loop, guaranteeing 100% thread safety at 100,000+ QPS.

```lua
-- rate_limiter.lua
-- KEYS[1]: Rate limit key (e.g. "rate:user_123")
-- ARGV[1]: Max tokens (bucket capacity)
-- ARGV[2]: Refill rate per second
-- ARGV[3]: Current timestamp (seconds float)
-- ARGV[4]: Requested tokens (usually 1)

local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local requested = tonumber(ARGV[4])

-- Retrieve current state: [tokens, last_updated]
local data = redis.call("HMGET", key, "tokens", "last_updated")
local tokens = tonumber(data[1])
local last_updated = tonumber(data[2])

if tokens == nil then
    tokens = capacity
    last_updated = now
else
    -- Calculate tokens accumulated since last request
    local elapsed = math.max(0, now - last_updated)
    tokens = math.min(capacity, tokens + (elapsed * refill_rate))
    last_updated = now
end

if tokens >= requested then
    tokens = tokens - requested
    redis.call("HMSET", key, "tokens", tokens, "last_updated", last_updated)
    redis.call("EXPIRE", key, math.ceil(capacity / refill_rate))
    return {1, math.floor(tokens)} -- Allowed: 1 = true
else
    return {0, math.floor(tokens)} -- Denied: 0 = false
end
```

### FastAPI Middleware Integration
```python
import time
from fastapi import FastAPI, Request, HTTPException, status
import redis.asyncio as aioredis

redis_pool = aioredis.from_url("redis://localhost:6379", decode_responses=True)

with open("rate_limiter.lua", "r") as f:
    lua_rate_limiter = f.read()

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host
    rate_key = f"ratelimit:{client_ip}"

    # Atomic Lua execution: Capacity=60, Refill=1 token/sec, Current time, Cost=1
    allowed, remaining = await redis_pool.eval(
        lua_rate_limiter,
        1,
        rate_key,
        60,
        1.0,
        time.time(),
        1
    )

    if allowed == 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Please throttle your requests."
        )

    response = await call_next(request)
    response.headers["X-RateLimit-Remaining"] = str(remaining)
    return response
```

---

## 4. Enterprise Backend Patterns: REST vs. gRPC, Circuit Breakers & Resilience

### REST vs. gRPC Architectural Comparison
| Feature | REST (JSON over HTTP/1.1 or HTTP/2) | gRPC (Protobuf over HTTP/2) |
|---|---|---|
| **Protocol Format** | Human-readable JSON text | Highly compressed binary Protocol Buffers |
| **Transport** | Unidirectional HTTP/1.1 or HTTP/2 | Strict HTTP/2 (Bidirectional streaming, multiplexing) |
| **Contract** | OpenAPI / JSON Schema (Informal) | Strict `.proto` contract file with code generation |
| **Performance** | Slower serialization, larger bandwidth | **5–10x faster serialization**, minimal CPU/bandwidth |
| **Best Used For** | Public-facing client APIs, Web frontends | Internal microservice-to-microservice communication |

### Circuit Breaker Pattern (Preventing Cascading Failures)
When calling external AI APIs (OpenAI, Anthropic) or legacy services:

```
            Closed (Normal) ──(Failure Rate > 50%)──► Open (Fail Fast)
                  ▲                                        │
                  │ (Success Threshold Met)                │ (Sleep Window Expires: 30s)
                  │                                        ▼
                  └────────────────────────────── Half-Open (Test Probe)
```

```python
import pybreaker

db_breaker = pybreaker.CircuitBreaker(
    fail_max=5,           # Trip after 5 consecutive failures
    reset_timeout=30      # Wait 30 seconds before testing service health
)

@db_breaker
async def call_external_llm_api(prompt: str):
    # If breaker is OPEN, instantly raises pybreaker.CircuitBreakerError
    # without making the network call, preventing threadpool starvation!
    return await httpx_client.post("https://api.openai.com/v1/chat/completions", ...)
```

---

## 5. Pointwise MNC Interview Questions & Answers

### Q1: What is the exact difference between WSGI and ASGI?
**Answer:**
- **WSGI (Web Server Gateway Interface, PEP 3333)** is a synchronous, blocking standard (`application(environ, start_response)`). Each incoming request binds a physical worker thread or OS process until the response is sent, making it incapable of handling persistent long-lived connections (WebSockets, SSE) without high memory overhead.
- **ASGI (Asynchronous Server Gateway Interface)** is an asynchronous standard (`app(scope, receive, send)`). It runs on Python's event loop (`asyncio`), allowing a single OS process to maintain tens of thousands of concurrent I/O-bound connections (HTTP/2 multiplexing, WebSockets, background token streams) with minimal RAM overhead.

### Q2: How does Pydantic v2 achieve high performance without violating Python's dynamic typing?
**Answer:**
Pydantic v2 offloads parsing, recursive type traversal, and validation to **Rust** via `pydantic-core`. When a model is defined in Python, its schema is compiled into a C-level Rust validator structure. When incoming JSON arrives, `pydantic-core` parses the JSON bytes directly in Rust and constructs Python objects only after validating types. This bypasses Python's interpreter overhead, avoiding thousands of intermediate PyObject allocations and dynamic attribute lookups.

### Q3: How do you prevent Redis rate limiters from failing when keys are distributed across a Redis Cluster?
**Answer:**
In Redis Cluster, multi-key commands or Lua scripts require all involved keys to map to the exact same hash slot (one of the 16,384 cluster slots). If you pass keys located on different cluster shards, Redis raises a `CROSSSLOT Keys in request don't hash to the same slot` error.  
*Solution:* Use **Redis Hash Tags**. By wrapping the routing key in curly braces: `{user_123}:ratelimit` and `{user_123}:history`, Redis hashes strictly the string inside `{...}`, guaranteeing all keys belonging to that user hash to the exact same cluster node.
