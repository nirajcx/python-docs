# FastAPI Quick Guide (Start Here)

Written for someone coming from Express.js. FastAPI is the Python equivalent of Express + Zod + auto-Swagger, with async built in.

Format: **concept → plain explanation → what you say in an interview → likely follow-up.**

---

## 1. The mental model: Express vs FastAPI

| Express.js | FastAPI |
|---|---|
| Manual validation (Joi/Zod) | Automatic validation via Pydantic |
| Manual Swagger setup | Auto docs at `/docs` |
| `req.user` via middleware | Dependency Injection via `Depends()` |
| Runs itself | Needs a server (Uvicorn) to run |

**Interview answer:** "FastAPI is built on Starlette (async web framework) and Pydantic (validation). You define request/response shapes with Python type hints, and it gives you validation, serialization, and interactive docs for free."

---

## 2. A basic endpoint

```python
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class CreateUser(BaseModel):
    name: str
    age: int

@app.post("/users")
async def create_user(user: CreateUser):
    return {"message": f"Created {user.name}"}
```

Pydantic validates the body automatically. Send bad data and you get a clean 422 error — no manual checks.

**Follow-up:** *"Why 422 not 400?"* → 400 means the JSON itself is broken/unparseable. 422 means the JSON parsed fine but failed your schema rules (e.g. `age` was a string).

---

## 3. Path, query, and body params

FastAPI figures out where each value comes from by its type hint and position:

```python
@app.get("/items/{item_id}")
async def get_item(item_id: int, q: str | None = None):
    # item_id comes from the URL path
    # q comes from the query string (?q=...)
    return {"item_id": item_id, "q": q}
```

---

## 4. Pydantic (the star of the show)

**Plain explanation:** Pydantic models are like Zod schemas or TypeScript types that actually run at runtime. They validate and convert data.

```python
from pydantic import BaseModel, Field

class Product(BaseModel):
    name: str = Field(min_length=1)
    price: float = Field(gt=0)          # must be > 0
    tags: list[str] = []
```

**Interview answer:** "Pydantic validates and parses input based on type hints. It's like Zod, but it's the core of how FastAPI validates every request and serializes every response."

**Note (v1 vs v2):** In Pydantic v2 use `model_dump()` (not `.dict()`) and `@field_validator` (not `@validator`). Knowing this shows you're current.

---

## 5. Dependency Injection with `Depends()`

**Plain explanation:** `Depends()` is how you share reusable logic — DB sessions, the current user, auth checks — across routes. It's cleaner than Express middleware because it shows up in the docs and is easy to mock in tests.

```python
from fastapi import Depends, HTTPException

async def get_db():
    db = SessionLocal()
    try:
        yield db          # give it to the route
    finally:
        db.close()        # always cleaned up, even on error

async def get_current_user(token: str):
    if not token:
        raise HTTPException(401, "Not authenticated")
    return {"id": 1}

@app.get("/me")
async def me(user=Depends(get_current_user), db=Depends(get_db)):
    return user
```

**Interview answer:** "Dependencies are reusable functions injected into routes. A dependency with `yield` sets up a resource, hands it over, and guarantees cleanup afterward — I use that pattern for DB sessions so they always close."

---

## 6. `async def` vs `def` (top interview question)

**Plain explanation:**
- `async def` runs on the main event loop. Only put non-blocking `await` calls here (async DB, `httpx`). If you put blocking code here, you freeze the whole server.
- `def` (plain) is auto-run in a background thread pool, so blocking code is safe but has thread overhead.

**Rule of thumb:** Using an async library? Use `async def`. Stuck with a blocking/sync library? Use plain `def`, or offload with `await asyncio.to_thread(...)`.

**Interview answer:** "If I'm calling async libraries I use `async def` so it runs on the event loop. If I only have a blocking library, I use a normal `def` so FastAPI runs it in a worker thread and doesn't block the loop. The mistake to avoid is blocking code inside `async def`."

---

## 7. Background tasks vs a real queue

**Plain explanation:** `BackgroundTasks` runs *after* the response, but inside the same process — if the server restarts, the work is lost. Fine for fire-and-forget logging. For important work (emails, embeddings, retries), use a real queue like Celery/ARQ with Redis.

**Interview answer:** "BackgroundTasks is fine for small non-critical work. For anything important or retryable, I'd use a proper task queue so work survives restarts and can be retried."

---

## 8. Startup/shutdown (lifespan)

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup: open DB pool, load models
    yield
    # shutdown: close connections

app = FastAPI(lifespan=lifespan)
```

Use this to open a DB pool on startup and close it on shutdown.

---

## 9. Running it

FastAPI doesn't run itself — you need an ASGI server:

```bash
uvicorn main:app --reload
```

---

## Quick self-test
1. Difference between `async def` and `def` in a route, and when to use each?
2. Why does FastAPI return 422 instead of 400 on bad input?
3. What does a `yield` dependency give you over plain setup code?
4. When would you NOT use BackgroundTasks?

More detail: [`../02-fastapi-backend/04-fastapi-core.md`](../02-fastapi-backend/04-fastapi-core.md) and [`05-fastapi-advanced.md`](../02-fastapi-backend/05-fastapi-advanced.md).
