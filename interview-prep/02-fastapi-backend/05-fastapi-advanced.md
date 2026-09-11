# FastAPI Advanced: Security, Streaming, Testing & Production Ops

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [04-fastapi-core.md](./04-fastapi-core.md) | [06-databases-orm.md](./06-databases-orm.md) | [10-llm-integration.md](../03-rag-vector-genai/10-llm-integration.md)

---

## 1. Authentication: OAuth2 with Password Flow & Stateless JWTs

Production FastAPI backends typically authenticate users with signed, asymmetric or symmetric JSON Web Tokens (JWT) using `pyjwt` or `python-jose`, combined with `OAuth2PasswordBearer`.

### Full JWT Security Implementation
```python
from datetime import datetime, timedelta, timezone
from typing import Annotated
import jwt
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from passlib.context import CryptContext
from pydantic import BaseModel

SECRET_KEY = "your-production-high-entropy-secret-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: str | None = None
    role: str | None = None

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "iat": datetime.now(timezone.utc)})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)]) -> TokenData:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        role: str = payload.get("role")
        if user_id is None:
            raise credentials_exception
        return TokenData(user_id=user_id, role=role)
    except jwt.PyJWTError:
        raise credentials_exception
```

---

## 2. Real-Time Streaming: Server-Sent Events (SSE) vs. WebSockets

In AI applications (RAG chat, LLM responses), users expect **token streaming** as text is generated rather than waiting 15 seconds for a complete response.

### Pattern 1: Server-Sent Events (SSE) for LLM Token Streaming
SSE is simpler and strictly unidirectional (server -> client over standard HTTP/1.1 or HTTP/2). It is the industry standard for ChatGPT/Claude interfaces.

```python
from fastapi.responses import StreamingResponse
import asyncio

async def llm_token_generator(prompt: str):
    """Simulates token generation stream from an LLM API."""
    simulated_tokens = ["Retrieving", " relevant", " context", "...\n", "Found", " 3", " documents.", "\nAnswer: Hello!"]
    for token in simulated_tokens:
        await asyncio.sleep(0.08)
        # SSE format requires: "data: <content>\n\n"
        yield f"data: {token}\n\n"
    yield "data: [DONE]\n\n"

@app.get("/api/v1/chat/stream")
async def chat_stream_endpoint(query: str):
    return StreamingResponse(
        llm_token_generator(query),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"  # Prevents NGINX from buffering chunked responses!
        }
    )
```

### Pattern 2: WebSockets for Bi-Directional Chat
Use WebSockets when clients must send audio, user cancellations, or bidirectional message state over a single persistent connection.

```python
from fastapi import WebSocket, WebSocketDisconnect

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/chat/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Echo or process incoming message
            await websocket.send_text(f"Processing query: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
```

---

## 3. Rate Limiting in FastAPI

To protect LLM endpoints from budget-draining abuse, apply Redis-backed rate limiting using `slowapi` (built on `limits`).

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request

# Leaky / sliding window algorithm using client IP (or JWT user ID)
limiter = Limiter(key_func=get_remote_address, default_limits=["200/day", "50/hour"])
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@app.post("/api/v1/ai/generate")
@limiter.limit("5/minute")  # Strict rate limit for expensive LLM calls
async def generate_ai_response(request: Request):
    return {"status": "generated"}
```

---

## 4. Modern Testing with Pytest & Async TestClient

With **HTTPX** and **pytest-asyncio**, testing async FastAPI apps is robust and fast. Never make real external API calls in test suites.

```python
# tests/test_rag_routes.py
import pytest
from httpx import AsyncClient, ASGITransport
from main import app, get_current_user

# Mocking authenticated user dependency fixture
@pytest.fixture
def mock_auth():
    app.dependency_overrides[get_current_user] = lambda: {"user_id": "test_dev", "role": "admin"}
    yield
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_streaming_endpoint(mock_auth):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/api/v1/chat/stream?query=test")
        
        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]
        content = response.text
        assert "data: [DONE]" in content
```

---

## 5. Production Deployment Architecture: Uvicorn + Gunicorn + Docker

In production, never run `uvicorn main:app --reload`. Instead, use **Gunicorn** as the process manager to supervise multiple **Uvicorn worker** processes.

```
                  ┌──────────────────────────────┐
                  │   Reverse Proxy / Load Balancer │ (NGINX / Cloudflare / AWS ALB)
                  └──────────────┬───────────────┘
                                 │ HTTP Requests
                  ┌──────────────▼───────────────┐
                  │ Gunicorn Master Process       │ (Heartbeat, worker lifecycle, signals)
                  ├──────────────┬───────────────┤
                  │              │               │
            ┌─────▼─────┐  ┌─────▼─────┐   ┌─────▼─────┐
            │  Uvicorn   │  │  Uvicorn   │   │  Uvicorn   │ (Asyncio Event Loops via uvloop)
            │  Worker 1 │  │  Worker 2 │   │  Worker 3 │
            └───────────┘  └───────────┘   └───────────┘
```

### Production Command
```bash
# Recommended worker formula: (2 x CPU cores) + 1
gunicorn main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000 \
  --timeout 120 \
  --graceful-timeout 30 \
  --access-logfile - \
  --error-logfile -
```

### Multi-Stage Production Dockerfile
```dockerfile
# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Final Minimal Runtime
FROM python:3.11-slim

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 curl && rm -rf /var/lib/apt/lists/*

# Copy only installed python packages from builder
COPY --from=builder /root/.local /root/.local
COPY . /app

# Ensure python finds installed user packages
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Production Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/healthz || exit 1

CMD ["gunicorn", "main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]
```

---

## 6. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why does token streaming break behind an NGINX reverse proxy?"**
   - By default, NGINX buffers HTTP responses until it has collected enough bytes before flushing to the client. For SSE streaming, you must disable response buffering by sending the header `X-Accel-Buffering: no` or setting `proxy_buffering off;` in your NGINX location block.
2. **"What is the difference between OAuth2 Scopes and Role-Based Access Control (RBAC)?"**
   - OAuth2 scopes restrict what a *third-party application* is allowed to do on behalf of a user (e.g. `read:profile`, `write:documents`), even if the user has full permissions. RBAC determines what the *user themselves* is authorized to perform (e.g. `Admin`, `Editor`, `Viewer`).
3. **"Why should you never store JWTs in local storage on the frontend?"**
   - Local storage is completely accessible to JavaScript, making tokens vulnerable to Cross-Site Scripting (XSS) attacks. Senior practice: store access tokens in memory (React state) and refresh tokens in secure, `HttpOnly`, `SameSite=Strict` cookies.

---

## 7. High-Probability Interview Questions & Model Answers

### Q1: How do you gracefully shut down a FastAPI application without dropping in-flight requests?
**Answer:**
Gunicorn sends a `SIGTERM` signal to its worker processes. Using `--graceful-timeout 30`, Gunicorn stops routing new connections to the worker and gives it up to 30 seconds to finish currently active requests. In FastAPI, the ASGI `lifespan` teardown block executes upon receiving the shutdown event, allowing the application to drain database pools, flush Redis caches, and complete in-flight tasks before the process terminates.

### Q2: How does `pytest.mark.asyncio` work with FastAPI's `AsyncClient`?
**Answer:**
FastAPI routes that are asynchronous cannot be tested with traditional synchronous test clients without blocking the event loop. `pytest-asyncio` spins up an event loop for test execution, and `httpx.AsyncClient(transport=ASGITransport(app=app))` communicates directly with the FastAPI ASGI interface in-memory without binding to a physical network port. This eliminates network latency and socket conflicts during automated CI/CD runs.

### Q3: How do you handle file uploads directly to AWS S3 without overloading the server?
**Answer:**
Direct server proxying of large files consumes server bandwidth and memory. The senior pattern is **Pre-signed S3 URLs**:
1. The client requests an upload link: `GET /api/v1/documents/upload-url?filename=report.pdf`.
2. FastAPI generates a temporary pre-signed S3 PUT URL using `boto3` with strict constraints (file type, max size) and returns it.
3. The client uploads the file directly to S3 via PUT.
4. S3 fires an event notification (or the client calls a `/documents/confirm` endpoint) to trigger the background indexing pipeline.

### Q4: What is the risk of using symmetric keys (HS256) vs. asymmetric keys (RS256/ES256) in JWT authentication?
**Answer:**
- **HS256 (Symmetric)** uses the exact same secret key to both sign and verify tokens. If multiple microservices need to verify user identity, the secret key must be shared with all of them; if any service is compromised, attackers can forge valid tokens for the entire system.
- **RS256/ES256 (Asymmetric)** uses a private key (held exclusively by the auth service) to sign tokens, and a public key (distributed freely to all microservices or published via JWKS) to verify tokens. Services can verify tokens without having the ability to forge them.
