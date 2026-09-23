# Backend production patterns — FastAPI, ORM, HTTP, jobs

[Roadmap](../README.md) · [Core FastAPI](../00-start-here/02-fastapi-quick-guide.md)

## 1. HTTP aur REST fundamentals

Resource-oriented URLs (`/projects/{id}/tasks`), consistent contracts, pagination/filtering, auth and documented errors REST API design mein useful hain. REST sirf JSON transport ka synonym nahi. GET safe/read semantics rakho; mutation GET se mat karo. PUT intended replacement idempotent; PATCH partial change necessarily idempotent nahi (`increment` differs from `set`). DELETE repeated intended effect same ho sakta hai while second response 404 ho.

`Cache-Control: no-store` storage avoid karne ka directive; `no-cache` store allowed but reuse se pehle validation. ETag + If-None-Match conditional GET bandwidth reduce karta hai; If-Match precondition concurrent edit protect kar sakti hai, failed precondition typically 412. API versioning mein old clients, fields/defaults and deprecation window consider karo.

CORS security boundaries [auth chapter](02-auth-jwt-sessions.md) mein hain. HTTPS transit protect karta hai, authorization aur input validation replace nahi.

## 2. ASGI, concurrency aur worker resources

ASGI request/response events, WebSocket aur lifespan support karta hai. WSGI sync interface hai; deployment can use different worker models. Django bhi async support rakhta hai—“FastAPI only async framework” wrong.

A worker event loop cooperative tasks schedule karta hai. `await` already-ready result par necessarily yield nahi karta; actual awaitable semantics matter. Async I/O library driver needed; sync function simply `async def` label se nonblocking nahi banti. Thread pools finite hain; library limiter tokens OS thread count ka universal guarantee nahi.

Lifespan per process init/cleanup: shared HTTP client/pool reuse, shutdown close. Multi-worker app mein resources each process create karta hai. Timeout = connect/read/write/pool budgets plus overall deadline; per-read timeout full stream wall-time deadline same nahi.

## 3. ORM session, transaction aur connection

- Engine connections manage karta hai; pool usually lazily create/reuse karta hai, `pool_size` immediate prewarm guarantee nahi.
- Session ORM identity map + unit-of-work transaction state; constructing session immediately DB connection checkout imply nahi.
- Transaction atomic business operation. A request can have read-only/no DB work; request and transaction scopes related but not identical.
- `flush`: pending SQL DB ko send, constraints/generated IDs resolve; not durable commit.
- `commit`: transaction complete; `rollback`: failed transaction clear/undo transactional work.
- `refresh`: DB state explicitly reload; `expire_on_commit=False` expired-attribute refresh avoid, relationship preload nahi.

Session per concurrent task; open session ORM objects background worker ko pass mat karo. Async ORM attribute access implicit I/O trigger kar sakta hai (`MissingGreenlet`); eager load/explicit await/refresh choose. Lazy I/O bug ko “different OS thread error” assume mat karo. [SQLAlchemy async patterns](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html).

## 4. Concrete service transaction: stock reserve

Illustrative SQLAlchemy 2-style function; schema in [practice folder](../../postgres-practice/01-schema.sql). `session` caller provides fresh AsyncSession with no transaction already begun.

```python
from sqlalchemy import text

class OutOfStock(Exception):
    pass

async def reserve_stock(session, product_id: int, quantity: int):
    if quantity <= 0:
        raise ValueError('quantity must be positive')
    async with session.begin():
        result = await session.execute(text('''
            UPDATE interview_lab.inventory
            SET stock = stock - :quantity, version = version + 1
            WHERE product_id = :product_id AND stock >= :quantity
            RETURNING stock
        '''), {'product_id': product_id, 'quantity': quantity})
        stock = result.scalar_one_or_none()
        if stock is None:
            raise OutOfStock()
        # Related order/reservation insert belongs in THIS transaction.
    return stock  # commit has succeeded before success returned
```

Already-started session transaction ke upar blindly `.begin()` error de sakta hai; ownership boundary clear rakho. Dependency post-yield commit response sent ke baad defer mat karo. No-stock vs not-found business contract decide karo; boolean `if not stock` zero successful stock ko incorrectly reject karega.

## 5. Connection pooling and PgBouncer

Maximum app-side connections ≈ instances × processes × (pool_size + max_overflow), plus workers/admin tools. DB `max_connections` cap crossing refusals cause kar sakta hai, automatic “server crash” inevitable nahi.

PgBouncer transaction mode DB connection transaction lifetime tak multiplex karta hai, every statement ke immediately baad when transaction still open nahi. Session state features/prepared-statement support depend on versions/configuration. Transaction-local `set_config(..., true)` tenant context within explicit transaction use karo; verify RLS under real application role. Pooling throughput ceiling remove nahi karta; waiting/backpressure ab bhi needed.

## 6. Pagination, filters, validation

List cap, deterministic ordering, consistent cursor key and filters, authorization before results. Input sorting column names parameterized value placeholders se bind nahi hote; allowlist mapping use karo. SQLAlchemy expression building safe patterns use kar sakta hai; raw SQL f-string still vulnerable. Pydantic validation SQL injection defense by itself nahi.

PATCH `model_dump(exclude_unset=True)` omitted field vs explicit null distinguish karta hai. `str | None` without default Pydantic v2 mein required-but-nullable ho sakta hai. Empty patch, whitespace title, enum transitions validate karo. Input/output models separate; password hash output mein nahi.

## 7. Job queues, delivery and idempotency

Producer → broker → worker → optional result store. Reliability configuration se aati hai: broker persistence, publisher acknowledgment, consumer acknowledgment timing, visibility lease, retry/dead-letter policy. Queue use karna alone delivery guarantee nahi.

```text
Operation key scoped by (tenant, endpoint/action, client key)
  + request fingerprint
  + in-progress/completed status
  + saved result / outcome
  + expiry policy
```

Unique DB constraint concurrent same key serialize/dedup kare. Same key different payload reject. External call DB transaction ke andar long wait na rakho; persist intent + provider idempotency + reconciliation. Crash after provider success before local commit possible, so local unique row alone end-to-end exactly-once proof nahi.

Task retry transient exceptions only. Poison payload quarantine/DLQ, capped retries, jitter. Worker task apna DB session banaye. Cancellation thread/external service operation ko automatically stop nahi karti.

## 8. Webhook / payment / workflow integrations

Server calculates expected amount/currency/order, provider-hosted flow collects payment details, signed webhook/reconciliation confirms final status. Client success redirect ko fulfillment proof mat banao. Provider signature algorithm exact docs se use karo; raw request bytes verify; replay/timestamp policy provider-specific. Stripe/Razorpay header formats identical assume mat karo.

Durably record verified event before acknowledgment; unique provider event ID + payment state machine handle duplicates/out-of-order events. Amount/currency/merchant identity/order mapping verify against stored intent. Later failure event se succeeded order blindly downgrade mat karo; valid transitions define karo. Workflow tools such as n8n integration simplify kar sakte hain, but credentials, retries, audit and ownership still required.

## 9. Uploads / downloads / SSRF

Large uploads scoped short-lived presigned URL se object storage ja sakte hain; finalize ownership, actual size/type/hash and scanning policy verify karo. Declared MIME/client filename trustworthy nahi. Download authorization enforce, guessed path se access mat do. Stream/batch processing memory cap preserve karta hai.

User-supplied URL fetch can cause SSRF: restrict scheme/destination, resolve/validate network targets, redirects revalidate, egress policy, time/size limits. Private metadata endpoints expose mat karo. File paths normalize and confine allowed directory; arbitrary extraction path avoid.

## 10. Testing that finds real bugs

Unit: rules and pure transforms. API: validation, status, identity. Integration: real DB constraints, locks/transactions/migrations. E2E: user journey. Test distribution project risk pe choose, fixed 70/20/10 rule nahi.

HTTPX ASGITransport lifecycle startup automatically run assume mat karo; lifespan fixture/tool or context-managed TestClient configure karo. Test transaction isolation tab work karti hai jab app correct test-bound connection/session use kare; independently committed jobs/other connections automatically rollback nahi honge. Parallel tests separate DB/schema or controlled fixtures use karein.

Mock external service deterministic timeouts, malformed response, retry, partial stream. Mock ORM alone PostgreSQL correctness validate nahi karta. Contract code generation drift reduce karti hai; deployment mismatch/runtime malformed data impossible nahi banati.

## 11. Architecture for 3 years experience

```text
app/
  api/          routes, HTTP errors, input/output contracts
  services/     business operations, transaction ownership
  models/       ORM tables
  schemas/      Pydantic models
  core/         config, auth, DB, logging
  workers/      durable background operations
migrations/     reviewed schema changes
tests/          unit, API, DB integration
```

Small application mein unnecessary repository/interfaces layers mat force karo. Domain boundary useful ho toh modular monolith. Design judgment = constraint + alternative + cost + evidence, directory naming contest nahi.
