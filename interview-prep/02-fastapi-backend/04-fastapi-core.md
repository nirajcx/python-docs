# FastAPI Core: Architecture, Pydantic v2 & Dependencies

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [03-python-async.md](../01-python-core/03-python-async.md) | [05-fastapi-advanced.md](./05-fastapi-advanced.md) | [06-databases-orm.md](./06-databases-orm.md)

---

## 1. FastAPI Architecture & Mental Bridge: Express.js vs. FastAPI

Coming from an **Express.js (Node.js)** background:

| Feature | Express.js (Node.js) | FastAPI (Python) |
|---|---|---|
| **Underlying Engine** | Node HTTP module / libuv | Starlette (ASGI web framework) |
| **Validation Layer** | Manual (Zod / Joi / express-validator) | Automatic via Pydantic v2 (Rust-backed core) |
| **API Docs** | Manual swagger-ui-express setup | Automatic interactive Swagger UI (`/docs`) & ReDoc (`/redoc`) via OpenAPI 3.1 |
| **Dependency Management**| Middleware passing objects via `req.user` | First-class Dependency Injection engine (`Depends()`) |
| **Concurrency Model** | Single thread + event loop | Async event loop + AnyIO worker threadpool |

---

## 2. Request Parameters & Anatomy

FastAPI differentiates parameter sources automatically based on function signatures and type hints:

```python
from fastapi import FastAPI, Path, Query, Header, status
from pydantic import BaseModel, Field

app = FastAPI(title="RAG Service API", version="1.0.0")

class IngestRequest(BaseModel):
    document_text: str = Field(..., min_length=10, description="Raw text of the document")
    chunk_size: int = Field(default=512, ge=64, le=2048)

@app.post(
    "/api/v1/collections/{collection_id}/documents",
    status_code=status.HTTP_201_CREATED,
    tags=["Ingestion"]
)
async def ingest_document(
    # Path parameter (from URL path)
    collection_id: str = Path(..., regex="^[a-zA-Z0-9_-]+$", description="Collection slug"),
    # Query parameter (from ?dry_run=true)
    dry_run: bool = Query(default=False, description="Simulate without DB write"),
    # Header parameter
    x_client_id: str | None = Header(default=None, alias="X-Client-ID"),
    # Request Body (JSON payload parsed and validated by Pydantic)
    payload: IngestRequest = ...
):
    return {
        "status": "success",
        "collection": collection_id,
        "dry_run": dry_run,
        "client": x_client_id,
        "text_length": len(payload.document_text)
    }
```

---

## 3. Pydantic v2: Models, Field Validators & Custom Serialization

FastAPI uses **Pydantic v2** (`pydantic-core` written in Rust), giving a 5–15x performance increase over v1.

```python
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Literal

class LLMGenerationConfig(BaseModel):
    model_name: Literal["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet"]
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    top_p: float = Field(default=1.0, ge=0.0, le=1.0)
    max_tokens: int = Field(default=1024, gt=0)
    system_prompt: str | None = None

    # Field-level validator (Pydantic v2 syntax: @field_validator)
    @field_validator("temperature")
    @classmethod
    def validate_temperature_precision(cls, v: float) -> float:
        return round(v, 2)

    # Root / Model-level validator across multiple fields
    @model_validator(mode="after")
    def check_deterministic_settings(self) -> "LLMGenerationConfig":
        if self.temperature == 0.0 and self.top_p != 1.0:
            raise ValueError("top_p must be 1.0 when temperature is 0.0 (deterministic mode)")
        return self

    # Model configuration
    model_config = {
        "str_strip_whitespace": True,
        "json_schema_extra": {
            "example": {
                "model_name": "gpt-4o-mini",
                "temperature": 0.2,
                "top_p": 1.0,
                "max_tokens": 512
            }
        }
    }
```

### Pydantic v1 vs. v2 Gotcha for Interviews:
- In v1: `@validator('field')` and `@root_validator`.
- In v2: `@field_validator('field')` and `@model_validator(mode='before'|'after')`.
- In v1: `obj.dict()` and `obj.json()`.
- In v2: `obj.model_dump()` and `obj.model_dump_json()`.

---

## 4. Dependency Injection (`Depends`): Hierarchical & Cleanup (`yield`)

FastAPI's Dependency Injection system is its greatest architectural strength. It allows clean decoupling, authentication, database sessions, and mocking in unit tests.

### Yield Dependencies (Context Managers for Routes)
A dependency with `yield` executes its setup before the route runs, and its teardown **guaranteed** after the response is sent (even if an exception was raised!).

```python
from typing import AsyncGenerator
from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
# Assume get_session_factory returns async_sessionmaker

async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that injects an async DB session and guarantees cleanup."""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

# Sub-dependency: Authentication
async def get_current_user(token: str = Header(..., alias="Authorization")):
    if not token.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return {"user_id": "usr_123", "role": "admin"}

# Sub-dependency requiring another dependency: RBAC
def require_role(required_role: str):
    def role_checker(current_user: dict = Depends(get_current_user)):
        if current_user["role"] != required_role:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return current_user
    return role_checker

@app.delete("/api/v1/collections/{id}")
async def delete_collection(
    id: str,
    db: AsyncSession = Depends(get_db_session),
    admin_user: dict = Depends(require_role("admin"))
):
    # Route logic runs with active db session and verified admin user
    return {"message": f"Collection {id} deleted by {admin_user['user_id']}"}
```

---

## 5. Middleware vs. Dependencies

| Feature | Middleware | Dependency (`Depends`) |
|---|---|---|
| **Scope** | Global (runs on every single request / response) | Per-route or router-level (selective) |
| **Access to OpenAPI** | Invisible to OpenAPI documentation | Fully integrated into generated Swagger docs |
| **Response Modification**| Can modify headers or wrap responses directly | Cannot alter headers of the response easily |
| **Streaming Compatibility**| Can buffer or break Server-Sent Events / streaming | Safe with streaming responses |
| **Best Used For** | Request ID logging, CORS, timing metrics | Auth, DB sessions, input transformation, permissions |

```python
import time
from starlette.requests import Request

@app.middleware("http")
async def add_process_time_and_request_id(request: Request, call_next):
    start_time = time.perf_counter()
    
    # Process the request
    response = await call_next(request)
    
    # After response is computed
    process_time = time.perf_counter() - start_time
    response.headers["X-Process-Time-Ms"] = f"{process_time * 1000:.2f}"
    return response
```

---

## 6. Background Tasks: Native `BackgroundTasks` vs. Distributed Workers

FastAPI includes a lightweight `BackgroundTasks` runner executed after sending the HTTP response.

```python
from fastapi import BackgroundTasks

def log_vector_telemetry(query: str, latency_ms: float):
    # Simulated log write
    print(f"[TELEMETRY] Query: '{query}' resolved in {latency_ms}ms")

@app.post("/api/v1/search")
async def search_vectors(query: str, bg_tasks: BackgroundTasks):
    start = time.perf_counter()
    # Retrieval logic...
    elapsed = (time.perf_counter() - start) * 1000
    
    # Schedule non-blocking telemetry AFTER response is delivered to user
    bg_tasks.add_task(log_vector_telemetry, query, elapsed)
    return {"results": ["doc1", "doc2"]}
```

### 🧠 Junior vs. Senior Answer: "When do you use FastAPI BackgroundTasks vs. Celery?"
- **Junior Answer**: "`BackgroundTasks` is built-in and easy, so we can use it for all background work like sending emails and generating embeddings."
- **Senior Answer**: "`BackgroundTasks` runs inside the same process and memory space as the FastAPI web server. If the server crashes, restarts, or deploys a new container, all pending tasks in memory are lost forever. Additionally, heavy background tasks consume CPU/threadpool resources needed to serve HTTP traffic. Therefore, `BackgroundTasks` is only suitable for minor, fire-and-forget, non-critical operations (e.g. lightweight access audit logs). For business-critical, heavy, or retry-dependent operations (e.g. document embedding, OCR parsing, email dispatch, webhook retries), a distributed message queue like Celery, ARQ, or BullMQ with Redis/RabbitMQ is mandatory."

---

## 7. Global Exception Handling

Never expose raw Python tracebacks to clients in production.

```python
from fastapi import Request
from fastapi.responses import JSONResponse

class DocumentProcessingError(Exception):
    def __init__(self, doc_id: str, reason: str):
        self.doc_id = doc_id
        self.reason = reason

@app.exception_handler(DocumentProcessingError)
async def document_error_handler(request: Request, exc: DocumentProcessingError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error_type": "DOCUMENT_PROCESSING_FAILED",
            "document_id": exc.doc_id,
            "message": exc.reason
        }
    )
```

---

## 8. Synchronous `def` vs. Asynchronous `async def` in Routes

This is one of the top 3 most frequently asked FastAPI interview questions:

- If you declare an endpoint with **`async def`**: FastAPI runs it directly on the **main event loop thread**. If you run blocking code (e.g. `requests.get`, `time.sleep`), you choke the server.
- If you declare an endpoint with **`def`**: FastAPI recognizes it as synchronous and automatically runs it inside a separate worker **threadpool** (managed by `anyio`). It will not block the main event loop, but incurs thread overhead.

```python
# Rule of thumb:
# If calling async libraries (httpx, asyncpg, motor): ALWAYS use `async def`
# If using legacy synchronous libraries: EITHER use standard `def` OR use `await asyncio.to_thread(...)`
```

---

## 9. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why does Pydantic return a 422 instead of a 400 when validation fails?"**
   - HTTP 400 means Malformed Syntax (e.g. invalid JSON syntax that cannot be parsed). HTTP 422 (`Unprocessable Content`) means the syntax was valid JSON, but failed domain schema/semantic validations (e.g. an integer field received a string, or a number was outside `ge=0, le=100`).
2. **"Does `Depends()` re-run if used multiple times in the same request?"**
   - By default, `Depends(fn, use_cache=True)`. FastAPI caches the result of the dependency for the duration of that single request. If multiple sub-dependencies or routes request `get_db_session`, it executes once and shares the instance. Set `use_cache=False` if you need fresh state per invocation.
3. **"Can FastAPI be run directly with `python main.py`?"**
   - FastAPI is purely an ASGI application definition; it has no built-in web server. It requires an ASGI server like **Uvicorn** or **Hypercorn** to bind to sockets and parse HTTP protocols.

---

## 10. High-Probability Interview Questions & Model Answers

### Q1: How does FastAPI achieve such high performance compared to Flask or Django?
**Answer:**
FastAPI is built on top of **Starlette** (one of the fastest ASGI frameworks in Python) and **Pydantic v2** (validation written in Rust). It leverages Python's native asynchronous event loop (`asyncio`) running on `uvloop`, allowing a single process to handle thousands of concurrent I/O-bound requests without thread-switching overhead. Traditional Flask and Django (WSGI) use synchronous blocking architectures requiring one OS worker thread or process per concurrent request.

### Q2: How does Dependency Injection in FastAPI differ from Spring or NestJS?
**Answer:**
Unlike Java Spring or NestJS, which rely heavily on object-oriented class reflection, decorators, and centralized containers, FastAPI's DI is function-driven and declarative. Dependencies are Python callables (functions or classes) composed via the `Depends()` marker in route signatures. This allows simple scoping, seamless composition of nested sub-dependencies, automatic resolution of parameters in the OpenAPI schema, and straightforward mocking during unit tests via `app.dependency_overrides`.

### Q3: What is the lifespan context in FastAPI, and why did it replace `@app.on_event("startup")`?
**Answer:**
The older `@app.on_event("startup")` and `"shutdown"` handlers were deprecated because they split setup and teardown logic into separate decoupled functions. FastAPI now uses ASGI **Lifespan** context managers (`lifespan=...` in `FastAPI()`):
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # STARTUP: Initialize DB pool, load AI embedding models into memory
    print("Initializing vector index...")
    yield
    # SHUTDOWN: Close connection pools, flush caches
    print("Closing connections...")

app = FastAPI(lifespan=lifespan)
```
This guarantees structured concurrency and resource cleanup using Python's standard `try...finally` mechanics.

### Q4: How do you handle file uploads in FastAPI without running out of RAM on large files?
**Answer:**
FastAPI provides `UploadFile` (backed by Starlette's `SpooledTemporaryFile`). Unlike `bytes` (which loads the entire file into RAM), `UploadFile` keeps small files in memory (up to 1MB) and automatically rolls over large files to a temporary disk buffer. It provides async file-like methods (`await file.read(chunk_size)`) allowing chunked streaming straight to object storage (like AWS S3) without consuming web server memory.

### Q5: How do you mock a database dependency during automated integration tests?
**Answer:**
FastAPI provides a built-in dictionary `app.dependency_overrides`. In test fixtures, you map the real dependency function to a mock function:
```python
async def override_get_db():
    yield mock_test_session

app.dependency_overrides[get_db_session] = override_get_db
```
When tests complete, clear the dictionary (`app.dependency_overrides.clear()`).
