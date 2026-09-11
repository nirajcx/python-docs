# Interview Questions Bank: High-Scale Traffic, FinTech & Real-World Scenarios

Target Role: Mid / Senior Python & AI Backend Engineer  
Cross-References: [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md) | [19-high-scale-traffic-and-fintech.md](../04-system-design-dsa/19-high-scale-traffic-and-fintech.md) | [06-databases-orm.md](../02-fastapi-backend/06-databases-orm.md)

---

### Q1: How would you architect a Python/FastAPI service to scale from 1,000 requests/sec to 100,000 requests/sec?
#### Junior Answer:
"Put the FastAPI app in Docker, deploy it to Kubernetes, and turn on autoscaling."
#### Senior In-Depth Answer:
"Scaling requires addressing architectural bottlenecks tier-by-tier:
1. **At 1,000 QPS**:
   - Python code is rarely the bottleneck; the database is.
   - Run 10–15 FastAPI container instances with `uvloop` behind an AWS Application Load Balancer.
   - Place **PgBouncer** in front of PostgreSQL in transaction-pooling mode to cap database connections to 30–50.
   - Implement **Redis Cache-Aside** for hot read queries and route read traffic to **Postgres Read Replicas**.
2. **At 100,000 QPS**:
   - No relational database can handle 100k writes per second directly.
   - **Edge Termination**: Terminate SSL and cache static/semi-static content at the CDN edge (Cloudflare).
   - **Decoupled Asynchronous Writes**: Ingestion and mutating requests write to a high-throughput **Kafka / Redis Streams cluster**; FastAPI acknowledges immediately with HTTP 202.
   - **Distributed Sharding**: Use horizontal database sharding or distributed NoSQL (DynamoDB / Cassandra) for primary data.
   - **Backpressure & Load Shedding**: Implement token bucket rate limiting at the API gateway and drop non-essential traffic (telemetry, background sync) to preserve core transactional paths."

---

### Q2: How do you prevent race conditions and double-spending when two users transfer money simultaneously?
#### Junior Answer:
"Use a database transaction with `BEGIN` and `COMMIT`."
#### Senior In-Depth Answer:
"Standard database transactions alone do **not** prevent race conditions under `Read Committed` isolation because both transactions read the original balance before either commits their update (the Lost Update phenomenon).  
*Production Solutions:*
1. **Pessimistic Row Locking (`SELECT ... FOR UPDATE`)**:
   Exclusively locks the rows in the database. Crucially, **prevent deadlocks by sorting account IDs**:
   ```python
   # Always lock in consistent alphabetical order
   id1, id2 = sorted([sender_id, recipient_id])
   await session.execute(select(Account).where(Account.id.in_([id1, id2])).with_for_update())
   ```
2. **Double-Entry Bookkeeping**:
   Never update a `balance` float column directly. Instead, write immutable debit and credit ledger rows (`id, txn_id, account_id, amount, entry_type`). The account balance is the mathematical sum of all historic ledger rows.
3. **Optimistic Locking**:
   Track an integer `version` column: `UPDATE accounts SET balance = balance - 100, version = version + 1 WHERE id = :id AND version = :current_version`. If affected rows is 0, another concurrent transaction updated first; catch and retry."

---

### Q3: A flash sale creates 50,000 purchase requests in 10 seconds. How do you prevent your backend from collapsing?
#### Junior Answer:
"Use a more powerful server with more RAM and CPU."
#### Senior In-Depth Answer:
"1. **Decouple the Write Path**:
   Never allow 5,000 QPS to hit PostgreSQL directly. The checkout API endpoint validates the payload, checks inventory in Redis in 1ms, and enqueues an order intent message into **RabbitMQ / Redis Streams**, immediately returning `HTTP 202 Accepted {"order_id": "...", "status": "QUEUED"}` to the user.
2. **Controlled Worker Fleet**:
   A dedicated worker fleet pulls messages from the queue at a steady, sustainable rate of 400 orders/sec, processing DB updates without exceeding connection pools.
3. **Redis Atomic Inventory Decrement**:
   Maintain inventory counts in Redis: `DECR stock:item_123`. Because Redis is single-threaded, `DECR` is atomic. If the return value is $< 0$, the item is sold out; reject subsequent requests immediately at the memory layer without touching the database.
4. **Token Bucket Rate Limiting**:
   Drop bot spikes at the edge using Redis sliding window rate limiters."

---

### Q4: How do you implement API Idempotency Keys for payment processing?
#### Junior Answer:
"Check if the payment was already made by querying the database for the user's name."
#### Senior In-Depth Answer:
"Network timeouts between the client and server often cause clients to retry payment requests, risking double billing.
1. The client generates a unique UUID `Idempotency-Key` header with every payment attempt.
2. In FastAPI middleware, attempt an atomic write to Redis:
   `SET idempotency:{key} "PROCESSING" NX EX 120`.
3. If the key already exists:
   - If value is `"PROCESSING"`, return `HTTP 409 Conflict` (request currently in-flight).
   - If value contains a cached response, return the cached HTTP 200 payload directly without re-executing the payment.
4. If key was newly set: execute the payment with Stripe/payment processor, store the final JSON response in Redis under `idempotency:{key}` with a 24-hour TTL, and return HTTP 200 to the client."

---

### Q5: How would you architect a pipeline to ingest and embed 1 million PDF documents into vector embeddings?
#### Junior Answer:
"Write a Python script that loops over the files, calls OpenAI's embedding API, and saves them to Pinecone."
#### Senior In-Depth Answer:
"A sequential loop will take over a month and crash on the first network timeout.
1. **Batching**: OpenAI's embedding endpoint accepts up to 2,048 texts per API request. Never embed single chunks; batch into groups of 100–250 chunks per HTTP payload to minimize network overhead.
2. **Distributed Celery / ARQ Queue**:
   A producer parses PDFs into chunks and enqueues batch jobs into RabbitMQ. A fleet of 20 worker containers process batches concurrently.
3. **Centralized Rate Limiting**:
   Coordinate worker requests through a Redis token bucket to throttle total outbound requests to stay just below OpenAI's Tier limits (e.g. 5M Tokens Per Minute), avoiding HTTP 429 backoff storms.
4. **Resumable State Machine**:
   Store document progress in PostgreSQL with state transitions: `UPLOADED -> CHUNKED -> EMBEDDING -> INDEXED -> COMPLETED`. If a worker pod is evicted mid-batch, the unacknowledged task is returned to the queue and reprocessed."

---

### Q6: What is PgBouncer and why does PostgreSQL fail under high concurrency without it?
#### Junior Answer:
"PgBouncer is a database cache that speeds up queries."
#### Senior In-Depth Answer:
"PgBouncer is a **connection pool proxy**, not a cache.  
PostgreSQL uses a process-based architecture (forking an OS process per client connection), consuming 5–10MB of RAM per connection. When 200+ concurrent connections open, CPU context switching between OS processes degrades query latency, and connection limits (`max_connections`) are quickly exhausted.  
**PgBouncer in Transaction Pooling Mode**:
- Thousands of client coroutines maintain persistent, lightweight connections to PgBouncer.
- PgBouncer maintains a tiny, optimal pool of 30–50 real connections to PostgreSQL.
- A physical database connection is assigned to a client *only* for the duration of a single transaction and returned to the pool immediately upon `COMMIT` or `ROLLBACK`. This allows thousands of concurrent FastAPI requests to share a fraction of physical DB connections."
