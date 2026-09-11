# High-Scale Traffic (1K to 100K QPS), FinTech Transactions & Real-World System Scenarios

Target Role: Mid / Senior Python & FastAPI Backend Engineer  
Cross-References: [03-python-async.md](../01-python-core/03-python-async.md) | [06-databases-orm.md](../02-fastapi-backend/06-databases-orm.md) | [11-system-design-basics.md](./11-system-design-basics.md) | [16-database-design-principles.md](../07-database-design/16-database-design-principles.md)

---

## 1. The Scaling Spectrum: 1M Requests/Day vs. 1K QPS vs. 100K QPS

Interviewers love asking: *"How would you architect our Python/FastAPI service to handle 1,000 requests per second? What about 100,000 requests per second?"*  
Before jumping to Kubernetes or Kafka, do the **back-of-the-envelope math**:

```
                       The Traffic Scaling Matrix
                       
 Tier 1: 1M Req/Day          Tier 2: 1,000 QPS             Tier 3: 100,000 QPS
 (~12-50 QPS)                (~86M Req/Day)                (~8.6B Req/Day)
┌──────────────────────┐    ┌────────────────────────┐    ┌────────────────────────┐
│ • 1-2 FastAPI nodes  │    │ • 10-20 FastAPI nodes  │    │ • Hundreds of Pods (K8s)│
│ • Single Postgres DB │──► │ • Redis Cache Layer    │──► │ • Global CDN / Anycast │
│ • Celery Background  │    │ • PgBouncer Pooling    │    │ • Kafka Event Streams  │
│   Worker             │    │ • DB Read Replicas     │    │ • Sharded DBs / Dynamo │
└──────────────────────┘    └────────────────────────┘    └────────────────────────┘
```

### Back-of-the-Envelope Math Breakdown
| Scale | Daily Requests | Average QPS | Peak QPS (3-5x) | Infrastructure Reality |
|---|---|---|---|---|
| **Moderate** | 1 Million / day | $\approx 12\text{ QPS}$ | $\approx 50\text{ QPS}$ | **Single modest server** ($2\text{ CPU}, 4\text{GB RAM}$) running FastAPI + Uvicorn handles this with ease. |
| **High** | ~86 Million / day | $\mathbf{1,000\text{ QPS}}$ | $\mathbf{3,000\text{--}5,000\text{ QPS}}$ | Multiple container instances behind an ALB, **Redis caching**, **PgBouncer connection pooling**, single primary Postgres with Read Replicas. |
| **Massive (Hyperscale)** | ~8.6 Billion / day | $\mathbf{100,000\text{ QPS}}$ | $\mathbf{300,000\text{ QPS}}$ | Edge CDN termination, distributed Redis clusters, **Kafka event streaming**, sharded databases, strict rate limiting, async write-behind buffers. |

---

## 2. Layer-by-Layer Architecture for 1,000 to 10,000 QPS in Python

At 1,000+ QPS, the bottleneck is almost **never** Python execution speed—it is **database connection exhaustion, network I/O, or un-cached redundant queries**.

```
                             1,000 - 10,000 QPS ARCHITECTURE
                             
                               ┌────────────────────────┐
                               │ Cloudflare / Edge CDN  │ (Static assets, edge rate limit, SSL)
                               └───────────┬────────────┘
                                           │
                               ┌───────────▼────────────┐
                               │ AWS ALB (Layer 7)      │ (Health checks, round-robin)
                               └───────────┬────────────┘
                                           │
                 ┌─────────────────────────┴─────────────────────────┐
                 │                                                   │
                 ▼                                                   ▼
       ┌──────────────────┐                                ┌──────────────────┐
       │ FastAPI Pod 1    │ (4 Uvicorn workers)            │ FastAPI Pod N    │
       │ (uvloop enabled) │                                │ (uvloop enabled) │
       └─────────┬────────┘                                └─────────┬────────┘
                 │                                                   │
                 ├─────────────────────────┬─────────────────────────┤
                 │                         │                         │
                 ▼                         ▼                         ▼
       ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
       │ Redis Cluster    │      │ PgBouncer Pooler │      │ Kafka / RabbitMQ │
       │ (Cache-Aside,    │      │ (Transaction     │      │ (Async write     │
       │  Rate Limiting)  │      │  Pooling mode)   │      │  offloading)     │
       └──────────────────┘      └─────────┬────────┘      └──────────────────┘
                                           │
                           ┌───────────────┴───────────────┐
                           │                               │
                           ▼ (Writes)                      ▼ (Reads)
                 ┌──────────────────┐            ┌──────────────────┐
                 │ PostgreSQL Master│───────────►│ Read Replica 1,2│
                 └──────────────────┘ Replication└──────────────────┘
```

### 1. Single Node Tuning:
- Use **`uvloop`** (C-based libuv event loop) with Uvicorn.
- Worker sizing formula: $\text{Workers} = (2 \times \text{CPU Cores}) + 1$.
- Keep all I/O strictly non-blocking (`async def` with `asyncpg` and `httpx`).

### 2. The Database Connection Wall (PgBouncer):
If you run 20 FastAPI containers, each with 4 Uvicorn workers, and each worker allocates a pool of 20 database connections:
$$20 \times 4 \times 20 = 1,600\text{ concurrent connections to PostgreSQL!}$$
PostgreSQL allocates ~5–10MB of RAM per connection process; 1,600 connections will exhaust database memory and crash the server.  
**Solution:** Place **PgBouncer** in front of PostgreSQL in **Transaction Pooling Mode**. Thousands of FastAPI coroutines share a pool of just 30–50 real physical database connections.

### 3. Read/Write Splitting:
Route all `GET` queries to read replicas and all `POST/PUT/DELETE` queries to the primary master database using SQLAlchemy routing engines.

---

## 3. Real-World Scenario 1: Sudden Traffic Spikes / Flash Sales (50,000 Req in 10s)

**The Scenario:** A ticketing drop or flash sale causes traffic to spike from 100 QPS to 5,000 QPS within seconds. Traditional autoscaling (K8s HPA) takes 2–3 minutes to spin up new pods.

```
 Client Spikes (5,000 QPS)
            │
            ▼
 ┌──────────────────────┐
 │ 1. Token Bucket Rate │ (Redis sliding window: drop abusive bots with 429)
 │    Limiter           │
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 2. Load Shedding     │ (Reject non-critical telemetry/analytics requests)
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 3. Queue Buffering   │ Write order intent to Redis Queue / RabbitMQ.
 │    (Decoupled Write) │ Acknowledge client with HTTP 202 {"order_id": "...", "status": "QUEUED"}
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │ 4. Controlled Worker │ Workers pull orders at a steady, sustainable 500 QPS,
 │    Fleet             │ guaranteeing the database never crashes!
 └──────────────────────┘
```

---

## 4. Real-World Scenario 2: Financial Transactions & "Money" Systems (Zero Race Conditions)

In fintech, e-commerce, or enterprise ERP systems, financial operations must adhere to **strict ACID properties**. You can never have a **double-spend** or **lost update**.

### The Lost Update Bug (Classic Double Spend)
```python
# BUGGY CODE (Disaster in high concurrency):
async def withdraw_money(account_id: str, amount: float):
    account = await db.get_account(account_id)  # Thread A reads balance: $100
    # Thread B also reads balance: $100!
    if account.balance >= amount:
        new_balance = account.balance - amount   # Both subtract $100 -> $0
        await db.update_balance(account_id, new_balance) # Both write $0!
        # Result: User withdrew $200, but only $100 was deducted!
```

### Pattern 1: Pessimistic Row Locking (`SELECT ... FOR UPDATE`)
Locks the specific database row at the SQL engine level. Any other transaction attempting to read or modify this row must wait until the current transaction commits:

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

async def safe_transfer_pessimistic(
    session: AsyncSession,
    sender_id: str,
    recipient_id: str,
    amount: float
):
    async with session.begin():
        # DEADLOCK PREVENTION: Always lock rows in consistent alphabetical order!
        first_id, second_id = sorted([sender_id, recipient_id])

        # SELECT ... FOR UPDATE locks the rows exclusively
        stmt_first = select(Account).where(Account.id == first_id).with_for_update()
        stmt_second = select(Account).where(Account.id == second_id).with_for_update()

        acc1 = (await session.scalars(stmt_first)).one()
        acc2 = (await session.scalars(stmt_second)).one()

        sender = acc1 if acc1.id == sender_id else acc2
        recipient = acc2 if acc2.id == recipient_id else acc1

        if sender.balance < amount:
            raise InsufficientFundsError("Balance too low")

        sender.balance -= amount
        recipient.balance += amount
        # Commit automatically releases locks
```

### Pattern 2: Optimistic Locking (Version Columns)
Best for read-heavy balances with occasional updates:
```sql
UPDATE accounts 
SET balance = balance - 100, version = version + 1 
WHERE id = 'acc_123' AND version = 4;
```
If another transaction updated the account first, `version` is already 5; the update returns 0 affected rows, and the application catches the conflict and retries.

### Pattern 3: Double-Entry Bookkeeping (The Holy Grail of FinTech)
**Senior Rule:** In financial systems, you **never mutate a balance column**. Balances are calculated by summing immutable transaction ledger entries.

```
                      Double-Entry General Ledger Table
                      
 id | transaction_id | account_id | entry_type | amount  | created_at
----+----------------+------------+------------+---------+---------------------
  1 | txn_98765      | acc_user_A | DEBIT      | $100.00 | 2026-09-11 10:00:00
  2 | txn_98765      | acc_user_B | CREDIT     | $100.00 | 2026-09-11 10:00:00
```
- Total sum of Debits **must always equal** total sum of Credits across the system.
- Audit trail is 100% tamper-evident and immune to race condition state overwrite.

### Pattern 4: API Idempotency Keys
Prevents double-charging if the user's internet drops while submitting a payment:
```
 Client                                  FastAPI Payment Gateway               Redis
   │                                                │                            │
   │ 1. POST /payments                              │                            │
   │    Header: "Idempotency-Key: 9b1deb4d-..."     │                            │
   ├───────────────────────────────────────────────►│ 2. SETNX idemp:9b1deb4d    │
   │                                                ├───────────────────────────►│
   │                                                │◄─── (OK: Key Acquired) ────┤
   │                                                │                            │
   │                                                │ 3. Execute Stripe Charge   │
   │                                                │ 4. Store Result in Redis   │
   │                                                ├───────────────────────────►│
   │ 5. HTTP 200 {"status": "SUCCESS"}              │                            │
   │◄───────────────────────────────────────────────┤                            │
   │                                                │                            │
   │ [NETWORK RETRY by Client with SAME KEY]:       │                            │
   │ 6. POST /payments (Same Idempotency-Key)       │ 7. GET idemp:9b1deb4d      │
   ├───────────────────────────────────────────────►├───────────────────────────►│
   │ 8. Returns CACHED 200 SUCCESS (No double bill!)│◄─── Returns Result ────────┤
   │◄───────────────────────────────────────────────┤                            │
```

---

## 5. Real-World Scenario 3: Bulk Processing 1 Million Documents into Vector Embeddings

**The Scenario:** You must ingest 1,000,000 PDF documents (averaging 10 pages each = 10,000,000 chunks) into Qdrant/Pinecone.  
- A naive script calling `openai.embeddings.create(input=chunk)` synchronously in a loop will take **38 days** and fail on the first network timeout!

### Production Batch Pipeline Architecture:
1. **Batching**: Never send single strings. OpenAI's embedding endpoint accepts up to **2,048 texts per API request**. Batch into groups of 100–250 chunks per HTTP payload.
2. **Distributed Celery / ARQ Workers**:
   - Master producer partitions 1M documents into chunks and pushes chunk manifests to a message queue (RabbitMQ / Redis).
   - 20 worker processes consume tasks concurrently.
3. **Token Bucket Rate Throttling**:
   - Use a centralized Redis token bucket to ensure all 20 workers combined never exceed OpenAI's Tier quota (e.g. 5,000,000 Tokens Per Minute).
4. **Resumable Checkpoints**:
   - Store processing state in PostgreSQL (`status: 'PENDING' | 'EMBEDDED' | 'FAILED'`).
   - If a worker node crashes mid-job, remaining unindexed chunks are picked up without re-processing already embedded files.

---

## 6. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What is the difference between Deadlock Prevention and Deadlock Detection?"**
   - **Detection**: The database background engine periodically inspects the wait-for graph. If a cycle is found (Tx A waits for Tx B; Tx B waits for Tx A), it aborts one transaction with a deadlock error.
   - **Prevention**: Enforcing an **ordered locking hierarchy** in application code (e.g. always acquiring locks in ascending alphabetical order of Primary Keys: `sorted([acc_A, acc_B])`). This mathematically makes cyclical wait graphs impossible.
2. **"Why is a Distributed Lock (Redlock) risky for financial operations?"**
   - If a Python worker acquires a Redis lock with a 5-second TTL, but suffers a long Garbage Collection pause or slow disk I/O lasting 6 seconds, the lock expires. Another worker acquires the lock, and both workers now execute simultaneously!  
   *Senior Fix:* Use **Fencing Tokens** (monotonically increasing version numbers verified by the database on write) or native database row-level locking (`FOR UPDATE`).
