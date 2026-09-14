# Distributed Systems: Kafka, Saga Pattern, Distributed Locks & Consensus

> **Target Audience:** FAANG / Tier-1 MNC Staff & Principal Systems Engineers  
> **Evaluation Focus:** Consensus (Raft/etcd), Redlock vs Fencing Tokens, 2PC vs Saga, Kafka Event Architecture, CAP/PACELC  
> **Cross-References:** [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md) | [19-high-scale-traffic-and-fintech.md](19-high-scale-traffic-and-fintech.md) | [20-advanced-database-engineering-and-migrations.md](20-advanced-database-engineering-and-migrations.md)

---

## 1. Distributed Consensus & Distributed Locking: Redlock vs. Fencing Tokens

Building distributed systems requires coordinating state across nodes that can fail, pause, or experience network partitions.

```
                      The Redlock GC Pause Flaw (Kleppmann's Critique)
                      
 Client 1 (Worker A)            Redis Cluster                  Client 2 (Worker B)            Storage / DB
        │                             │                                 │                          │
        │ 1. Acquire Lock (TTL = 10s) │                                 │                          │
        ├────────────────────────────►│                                 │                          │
        │◄── (Lock Granted) ──────────┤                                 │                          │
        │                             │                                 │                          │
        │ [STOP-THE-WORLD GC PAUSE]   │                                 │                          │
        │ (Freezes for 15 seconds!)   │                                 │                          │
        │                             │ 2. Lock TTL EXPIRES (10s)       │                          │
        │                             │                                 │                          │
        │                             │ 3. Acquire Lock (TTL = 10s)     │                          │
        │                             │◄────────────────────────────────┤                          │
        │                             ├──── (Lock Granted) ────────────►│                          │
        │                             │                                 │ 4. Write data to DB      │
        │                             │                                 ├─────────────────────────►│
        │                             │                                 │                          │
        │ [GC PAUSE ENDS]             │                                 │                          │
        │ 5. Writes stale data to DB! │                                 │                          │
        ├─────────────────────────────┼─────────────────────────────────┼─────────────────────────►│
        │   (DATA CORRUPTION: Both clients wrote concurrently!)         │                          │
```

### Why Distributed Locks Without Fencing Tokens are Unsafe
As computer scientist Martin Kleppmann proved: **a distributed lock cannot guarantee mutual exclusion in an asynchronous network** because clients can experience unbounded network delays, OS thread scheduling pauses, or Garbage Collection pauses after acquiring the lock.

### The Production Solution: Fencing Tokens
A fencing token is a **monotonically increasing integer** issued by the lock service (etcd, ZooKeeper) every time a lock is granted. The underlying storage layer validates the token on every write:

```sql
-- Storage Layer Rejection of Stale Fencing Tokens
-- Worker B has fencing token 42; Worker A resumes with stale token 41:
UPDATE enterprise_ledger 
SET balance = balance - 100, last_fencing_token = 42 
WHERE account_id = 'acc_123' AND last_fencing_token < 42;
-- Worker A's stale write affects 0 rows and is rejected!
```

---

## 2. Distributed Transactions: Two-Phase Commit (2PC) vs. The Saga Pattern

When a business process spans multiple independent microservices (e.g. Order Service $\to$ Payment Service $\to$ Inventory Service), a single ACID database transaction cannot span across network boundaries.

```
       Two-Phase Commit (2PC: Strongly Consistent, Blocking)
 Coordinator               Service A (Payment)            Service B (Inventory)
     │                             │                              │
     │ 1. PREPARE TO COMMIT        │                              │
     ├────────────────────────────►├─────────────────────────────►│
     │◄── (AGREED / LOCKED) ───────┴────── (AGREED / LOCKED) ─────┤ (Locks held!)
     │                             │                              │
     │ 2. COMMIT                   │                              │
     ├────────────────────────────►├─────────────────────────────►│
     
       The Saga Pattern (Eventual Consistency, Non-Blocking)
 [Create Order] ──► [Charge Payment] ──► [Reserve Inventory] ──► (Success!)
                           │
                           ▼ (Payment Fails!)
               [Compensating Tx: Cancel Order] ──► (Rolled Back Gracefully)
```

### 2PC vs. Saga Architectural Comparison
| Dimension | Two-Phase Commit (2PC) | Saga Pattern |
|---|---|---|
| **Consistency** | **Strong Consistency** (ACID) | **Eventual Consistency** (BASE) |
| **Locking Behavior** | **Blocking**: Database locks held across all nodes during phase 1 | **Non-Blocking**: Each service commits locally in independent transactions |
| **Availability** | Poor: If coordinator or 1 node hangs, system stalls | **High**: Failures trigger local compensating transactions |
| **Best Used For** | Financial core banking ledgers, distributed DBs (Spanner)| Modern microservice e-commerce, travel booking |

### Choreography vs. Orchestration in Sagas
- **Choreography (Event-Driven)**: Services listen to Kafka events and trigger local transactions independently. Best for simple 2–3 step workflows, but becomes hard to trace as systems grow ("spaghetti events").
- **Orchestration (Centralized Coordinator)**: A dedicated state machine (e.g. Temporal, Camunda, AWS Step Functions) invokes services explicitly and manages compensating rollbacks. Highly recommended for enterprise workflows.

---

## 3. Messaging Architecture: Apache Kafka vs. RabbitMQ Deep Dive

Choosing between Kafka and RabbitMQ is a premier MNC system design test.

```
 Apache Kafka (Distributed Append-Only Commit Log)
 Topic: 'order-events' (Retained on NVMe disk for 7 days)
 ┌───────────────┬───────────────┬───────────────┬───────────────┐
 │ Partition 0:  │ Offset 0      │ Offset 1      │ Offset 2 ...  │ ◄── Consumer Group A (Offset 2)
 ├───────────────┼───────────────┼───────────────┼───────────────┤
 │ Partition 1:  │ Offset 0      │ Offset 1      │ Offset 2 ...  │ ◄── Consumer Group B (Offset 1)
 └───────────────┴───────────────┴───────────────┴───────────────┘
 
 RabbitMQ (Smart Broker / Transient Queue)
 Messages deleted immediately upon Consumer ACK
 [Producer] ──► [Exchange] ──► [Queue] ──(Pushes)──► [Consumer ACK] ──► (Deleted!)
```

### Architectural Comparison Matrix
| Dimension | Apache Kafka | RabbitMQ |
|---|---|---|
| **Underlying Model** | **Append-Only Distributed Commit Log** | **Message Queue (AMQP 0-9-1)** |
| **Message Consumption**| **Pull-based**: Consumers read offsets at their own pace | **Push-based**: Broker pushes messages to connected workers |
| **Message Retention** | Persistent on disk for days/months; **Replayable** | Ephemeral: Deleted immediately upon consumer acknowledgement |
| **Ordering Guarantees**| **Strictly guaranteed within a single partition** | Guaranteed in single queue without priorities |
| **Throughput Capacity**| **Millions of events/sec** (Zero-Copy OS disk reads) | ~50,000–100,000 messages/sec |
| **Best Used For** | Event sourcing, clickstreams, AI ingestion, CDC | Complex task routing, RPC patterns, immediate task jobs |

### Kafka Consumer Group Rebalancing: Eager vs. Cooperative Sticky
When a consumer instance crashes or a new container scales up:
- **Eager Rebalancing (Legacy)**: All consumers in the group stop processing, drop all partition assignments, and wait for the coordinator to reassign partitions (**Stop-the-World pause**).
- **Cooperative Sticky Rebalancing (Modern Default)**: Only reassigns partitions that actually need to move, allowing unaffected consumers to continue streaming without downtime.

---

## 4. The Outbox Pattern & Change Data Capture (CDC)

**The Dual-Write Problem:** If your code saves an order to PostgreSQL and then publishes an event to Kafka:
```python
# THE DUAL-WRITE DISASTER:
await db.save_order(order)
# What if the server crashes or Kafka times out RIGHT HERE?
# The DB has the order, but Kafka NEVER receives the event!
await kafka_producer.send("order_created", order)
```

### The Transactional Outbox Solution
```
                          The Transactional Outbox Pattern
                          
 Application (FastAPI)               PostgreSQL Database                 Kafka Cluster
        │                                     │                                │
        │ 1. BEGIN TRANSACTION                │                                │
        │    INSERT INTO orders (...);        │                                │
        │    INSERT INTO outbox_events (...); │                                │
        │    COMMIT;                          │                                │
        ├────────────────────────────────────►│                                │
        │   (Atomic Single DB Transaction!)   │                                │
        │                                     │                                │
        │                                     │ 2. Reads WAL Log (CDC)         │
        │                           ┌─────────┴─────────┐                      │
        │                           │ Debezium / Kafka  │                      │
        │                           │ Connect Worker    ├─────────────────────►│
        │                           └───────────────────┘ 3. Emits event       │
```
1. Write business data and the event payload into an `outbox_events` table inside the **exact same ACID transaction**.
2. A Change Data Capture (CDC) tool like **Debezium** tail-reads PostgreSQL's Write-Ahead Log (WAL) and streams outbox rows into Kafka with **at-least-once delivery guarantees**, eliminating dual-write inconsistencies forever.

---

## 5. System Design Core: Consistent Hashing & PACELC

### Consistent Hashing with Virtual Nodes
In traditional modulo hashing (`node = hash(key) % N`), adding or removing 1 server rehashes **almost 100% of all keys**, causing massive cache stampedes and database collapse.  
**Consistent Hashing**:
1. Maps keys and server nodes onto a circular **Hash Ring ($0\text{ to }2^{32}-1$)**.
2. A key is assigned to the first node encountered moving clockwise.
3. Adding a node only redistributes $K/N$ keys.
4. **Virtual Nodes (vnodes)**: Each physical machine is mapped to 100–250 virtual positions on the ring, ensuring uniform hash distribution and preventing "hot spots".

### The PACELC Theorem (Beyond CAP)
The CAP theorem only considers behavior during network partitions ($P$). The **PACELC theorem** provides the complete picture:
$$\text{If } \mathbf{P} \text{ (Partition): Choose } \mathbf{A} \text{ (Availability) or } \mathbf{C} \text{ (Consistency);}$$
$$\text{ELSE: Choose } \mathbf{L} \text{ (Latency) or } \text{C} \text{ (Consistency).}$$
- **MongoDB / DynamoDB**: If partition $\implies$ Availability ($PA$); Else $\implies$ Latency ($EL$).
- **PostgreSQL / Spanner**: If partition $\implies$ Consistency ($PC$); Else $\implies$ Consistency ($EC$).

---

## 6. Pointwise MNC Interview Questions & Answers

### Q1: How does Kafka achieve high write throughput without CPU bottlenecking?
**Answer:**
1. **Sequential Disk Append**: Writes messages to the end of partition segment files on disk sequentially. Sequential disk I/O on modern NVMe drives matches RAM speeds (~600MB/s).
2. **Page Cache Centric**: Relies heavily on the Linux OS Page Cache rather than keeping objects in JVM heap, avoiding GC pauses.
3. **Zero-Copy Optimization (`sendfile` system call)**: Moves data directly from the Linux OS page cache to the Network Socket buffer, bypassing user-space CPU memory copying entirely.
4. **Batching & Compression**: Batches multiple messages together and compresses them (snappy, zstd) before network transmission.

### Q2: What is the difference between At-Least-Once, At-Most-Once, and Exactly-Once Semantics in Kafka?
**Answer:**
- **At-Most-Once**: Offsets are committed *before* processing. If the consumer crashes during processing, the message is lost. (No duplicates, but data loss).
- **At-Least-Once**: Offsets are committed *after* processing. If consumer crashes before commit, the message is reprocessed upon restart. (No data loss, but duplicate processing possible; requires **idempotent consumers**).
- **Exactly-Once Processing (EOS)**: Combines **Idempotent Producers** (producer assigns sequence numbers to messages; broker deduplicates) with **Kafka Transactional API** (`sendOffsetsToTransaction`), ensuring read-process-write loops across Kafka topics commit atomically.
