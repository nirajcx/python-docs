# System Design Quick Guide (Start Here)

At 2.5 YOE for mid-size companies, system design rounds are usually **light**. They want to see that you can break a problem down, name the main pieces, and reason about tradeoffs out loud. You do NOT need to design Netflix.

Format: **concept → plain explanation → what you say → follow-up.**

---

## 1. A framework you can use for any design question

When asked "design X" (URL shortener, chat app, feed), walk through these steps out loud:

1. **Clarify requirements** — what does it need to do? How many users? Read-heavy or write-heavy?
2. **Define the API** — a few endpoints (`POST /shorten`, `GET /{code}`).
3. **Design the data** — what tables/collections? Key fields?
4. **Draw the flow** — client → API → database/cache.
5. **Scale it** — add caching, replicas, a queue where needed.
6. **Mention tradeoffs** — you don't need the perfect answer, just show you see the options.

**Interview tip:** Talking through this structure calmly matters more than the final diagram.

---

## 2. The building blocks you should be able to name

- **Load balancer** — spreads traffic across multiple servers.
- **App servers** — your FastAPI/Node instances (stateless, so you can run many).
- **Database** — source of truth (usually PostgreSQL).
- **Cache (Redis)** — stores hot data in memory so you don't hit the DB every time.
- **Queue (Celery/RabbitMQ/Kafka)** — for background/async work.
- **CDN** — serves static assets close to users.
- **Object storage (S3)** — for files and images.

**Interview answer:** "I keep app servers stateless so I can scale them horizontally behind a load balancer. Session/hot data goes in Redis, files go in object storage, and heavy background work goes to a queue."

---

## 3. Caching (the most common scaling tool)

**Plain explanation:** Reading from memory (Redis) is much faster than reading from disk (database). Cache data that's read often and changes rarely.

**Cache-aside pattern (most common):**
1. Check the cache.
2. Miss? Read from DB, then store in cache.
3. Return the data.

**Key challenge — invalidation:** when the underlying data changes, you must update or delete the cached copy, or set a TTL (expiry) so it refreshes.

**Interview answer:** "I use cache-aside with Redis: check cache, fall back to DB on a miss, and store the result. I set a TTL and invalidate on writes so I don't serve stale data."

---

## 4. Scaling: vertical vs horizontal

- **Vertical:** bigger machine (more CPU/RAM). Simple but has a ceiling.
- **Horizontal:** more machines. Needs stateless servers and a load balancer, but scales much further.

**Interview answer:** "I scale vertically first because it's simple, then horizontally by adding stateless instances behind a load balancer once I hit limits."

---

## 5. Database scaling basics

- **Read replicas** — copies that serve read queries, taking load off the primary. Writes go to the primary.
- **Indexing** — often the cheapest fix for a slow app.
- **Sharding** — splitting data across databases by some key. Powerful but complex; mention it, only go deep if pushed.

---

## 6. Sync vs async work (queues)

**Plain explanation:** If a task is slow (sending email, generating a report, processing a document), don't make the user wait. Return quickly and do the work in the background via a queue.

**Interview answer:** "For slow or unreliable operations I return immediately and push the job to a queue so a worker handles it. That keeps the API responsive and lets the work retry if it fails."

---

## 7. Statelessness & sessions

**Plain explanation:** If each server remembers who's logged in, you can't freely add servers. Keep servers stateless — store sessions in Redis or use JWTs — so any server can handle any request.

---

## 8. A worked mini-example: "Design a URL shortener"

- **Requirements:** shorten a long URL, redirect on visit, handle lots of reads.
- **API:** `POST /shorten` → returns short code; `GET /{code}` → redirect.
- **Data:** table `(id, short_code, long_url, created_at)`, index on `short_code`.
- **Flow:** generate a unique short code, store the mapping, redirect on lookup.
- **Scale:** it's read-heavy, so cache `short_code → long_url` in Redis; add read replicas.
- **Tradeoff:** random code vs encoding the id — mention both.

Practice narrating this in ~5 minutes.

---

## Quick self-test
1. Walk through your steps for any "design X" question.
2. Explain cache-aside and why invalidation is hard.
3. Vertical vs horizontal scaling — pros and cons?
4. Why keep app servers stateless?
5. When do you push work to a queue?

More detail: [`../04-system-design-dsa/11-system-design-basics.md`](../04-system-design-dsa/11-system-design-basics.md).
