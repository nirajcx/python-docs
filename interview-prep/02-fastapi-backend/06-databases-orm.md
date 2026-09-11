# Databases, SQL & Modern SQLAlchemy 2.0 (Async)

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [04-fastapi-core.md](./04-fastapi-core.md) | [08-vector-databases.md](../03-rag-vector-genai/08-vector-databases.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md)

---

## 1. Relational Database Essentials: SQL & Indexing

### Index Types & Performance
| Index Type | Internal Data Structure | Best Used For | Complexity |
|---|---|---|---|
| **B-Tree** (Default) | Balanced tree with sorted leaf nodes | Range queries (`<`, `>`), equality (`=`), sorting (`ORDER BY`) | $O(\log N)$ |
| **Hash Index** | Hash table lookup | Exact equality matches only (`=`), no ranges or sorting | $O(1)$ |
| **GIN** (Generalized Inverted) | Inverted index mapping elements to rows | PostgreSQL `JSONB`, full-text search, array containment (`@>`) | Fast read, slower write |
| **HNSW / IVFFlat** | Graph / Inverted file (`pgvector`) | Vector similarity search (Cosine, L2, Inner Product) | $O(\log N)$ approximate |

### The Composite Index Leftmost Prefix Rule
If you create an index on `(organization_id, created_at, status)`:
- `WHERE organization_id = 5` ➔ **USES INDEX** (prefix matches)
- `WHERE organization_id = 5 AND created_at > '2026-01-01'` ➔ **USES INDEX**
- `WHERE created_at > '2026-01-01'` ➔ **INDEX CANNOT BE USED** (Leftmost column omitted, triggers full table scan!)

---

## 2. Transactions & ACID Isolation Levels

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Notes |
|---|---|---|---|---|
| **Read Uncommitted** | Possible | Possible | Possible | Reads dirty uncommitted rows |
| **Read Committed** (Postgres default) | **Prevented** | Possible | Possible | Only reads committed data; subsequent reads inside same TX can see changed values |
| **Repeatable Read** | **Prevented** | **Prevented** | Prevented in Postgres (MVCC snapshot) | Snapshot taken at first query; sees same data across entire transaction |
| **Serializable** | **Prevented** | **Prevented** | **Prevented** | Strict serial execution simulation; throws concurrency errors on conflicts |

---

## 3. Modern SQLAlchemy 2.0 (Async Style)

SQLAlchemy 2.0 completely overhauled the ORM. Legacy `session.query(User).filter(...)` is deprecated in favor of explicit `select()` statements and type-safe `Mapped[]` declarations.

### Declarative Model Definition
```python
from datetime import datetime, timezone
import uuid
from sqlalchemy import String, DateTime, ForeignKey, Index
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID, JSONB

class Base(DeclarativeBase):
    pass

class Organization(Base):
    __tablename__ = "organizations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    # One-to-Many relationship
    documents: Mapped[list["Document"]] = relationship(back_populates="organization", cascade="all, delete-orphan")

class Document(Base):
    __tablename__ = "documents"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    org_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), index=True)
    metadata_json: Mapped[dict] = mapped_column(JSONB, default=dict)

    organization: Mapped["Organization"] = relationship(back_populates="documents")

    __table_args__ = (
        Index("ix_documents_org_id_title", "org_id", "title"),
    )
```

### Production Async Engine, Session & CRUD
```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select

DATABASE_URL = "postgresql+asyncpg://postgres:password@localhost:5432/production_db"

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=20,          # Persistent connections in pool
    max_overflow=10,       # Connections allowed beyond pool_size during traffic spikes
    pool_recycle=3600,     # Recycle connections hourly to prevent stale timeouts
    pool_pre_ping=True     # Test connection health before leasing to request
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False  # CRUCIAL: Prevents lazy-loading attributes after commit!
)
```

---

## 4. The N+1 Query Problem & ORM Eager Loading

The N+1 problem occurs when an application executes 1 query to fetch $N$ parent records, and then executes $N$ additional queries to fetch child relationships.

```python
# THE BUG (N+1 Queries):
stmt = select(Organization)
orgs = (await session.scalars(stmt)).all()
for org in orgs:
    print(len(org.documents))  # In async SQLAlchemy, this raises MissingGreenlet exception!
```

### Eager Loading Strategies in SQLAlchemy 2.0
```python
from sqlalchemy.orm import selectinload, joinedload

# STRATEGY 1: selectinload (BEST FOR ONE-TO-MANY & MANY-TO-MANY)
# Executes 2 queries: 
# 1. SELECT * FROM organizations;
# 2. SELECT * FROM documents WHERE org_id IN (id1, id2, id3...);
stmt = select(Organization).options(selectinload(Organization.documents))
result = await session.scalars(stmt)
orgs = result.all()

# STRATEGY 2: joinedload (BEST FOR MANY-TO-ONE & ONE-TO-ONE)
# Executes 1 query with an SQL LEFT OUTER JOIN
stmt = select(Document).options(joinedload(Document.organization))
docs = (await session.scalars(stmt)).all()
```

---

## 5. Alembic Database Migrations & Zero-Downtime Releases

Alembic manages schema evolution versioning.

```bash
# Initialize alembic in project
alembic init -t async migrations

# Generate new migration script by inspecting SQLAlchemy models vs DB schema
alembic revision --autogenerate -m "add_documents_table"

# Apply pending migrations
alembic upgrade head

# Rollback last migration
alembic downgrade -1
```

### Alembic Autogenerate Traps Interviewers Test:
- Alembic **cannot** detect table name changes (it interprets it as `DROP TABLE old` followed by `CREATE TABLE new` -> catastrophic data loss!).
- Alembic often fails to detect PostgreSQL `ENUM` type modifications or unnamed constraints.
- Always inspect the generated migration script in `migrations/versions/` before committing.

### Zero-Downtime Migration Pattern (Expand / Contract)
Never rename or drop a column in a single release while web servers are running.
1. **Expand**: Add new column `new_col` as nullable in DB migration. Deploy code that dual-writes to both `old_col` and `new_col`.
2. **Backfill**: Run an offline background script to copy historical data from `old_col` to `new_col`.
3. **Switch**: Update application code to read and write exclusively from `new_col`. Deploy.
4. **Contract**: Drop `old_col` in a subsequent migration after confirming stability.

---

## 6. PostgreSQL vs. NoSQL vs. Vector DB Decision Framework

| Criterion | PostgreSQL (RDBMS) | MongoDB (Document NoSQL) | Redis (In-Memory K/V) | Dedicated Vector DB (Qdrant/Pinecone) |
|---|---|---|---|---|
| **Data Structure** | Structured tables, foreign keys, constraints | Unstructured/polymorphic JSON documents | Key-value pairs, strings, hashes, sorted sets | High-dimensional embedding vectors + payload |
| **Consistency** | Strong ACID, strict transactions | Eventual consistency (tunable replica sets) | Single-threaded in-memory atomic ops | Eventual consistency |
| **Best For** | Users, billing, orders, ERP, core metadata | Dynamic schemas, fast product catalogs | Rate limiting, session stores, hot cache | Semantic search over 10M+ embeddings |
| **Vector Support** | Great up to ~1-2M vectors via `pgvector` extension | Limited | Fast vector search for small datasets | Purpose-built for 10M-1B+ vectors, HNSW |

---

## 7. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What happens if you forget `expire_on_commit=False` in an async SQLAlchemy session?"**
   - After `await session.commit()`, accessing any un-loaded attribute on an ORM instance triggers a synchronous lazy-load. In an async context, this throws `sqlalchemy.exc.MissingGreenlet: greenlet_spawn has not been called`.
2. **"Why is `SELECT *` considered an antipattern in production?"**
   - It fetches unnecessary data over the network, increases memory usage, prevents database index-only scans, and can break applications when new columns are added.
3. **"What is PgBouncer and why is it needed between FastAPI and PostgreSQL?"**
   - PostgreSQL creates an OS process for every open client connection (~2-10MB RAM each). Under high traffic, hundreds of FastAPI worker coroutines can exhaust PostgreSQL's max connection limit. **PgBouncer** sits in front of PostgreSQL providing lightweight transaction-level connection pooling, allowing thousands of application connections to share 20–50 actual database connections.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between an INNER JOIN, LEFT JOIN, and CROSS JOIN?
**Answer:**
- **INNER JOIN**: Returns only the rows where there is a match in both tables based on the join condition.
- **LEFT JOIN (LEFT OUTER JOIN)**: Returns all rows from the left table, and matching rows from the right table. If no match exists, NULL values are returned for the right table columns.
- **CROSS JOIN**: Produces a Cartesian product, pairing every row of the first table with every row of the second table ($N \times M$ rows).

### Q2: What is database normalization, and when would you intentionally denormalize?
**Answer:**
Normalization (1NF through 3NF/BCNF) organizes relational tables to eliminate data redundancy and insertion, update, and deletion anomalies.  
However, in high-throughput read-heavy systems (or analytical reporting), joining multiple normalized tables causes severe query latency. **Denormalization** (e.g., storing precomputed totals or duplicating user names directly into order rows) is used intentionally to optimize read performance and eliminate expensive joins, provided the application ensures data consistency.

### Q3: How does PostgreSQL's `pgvector` compare to dedicated vector stores?
**Answer:**
`pgvector` allows storing embeddings and querying nearest neighbors directly inside PostgreSQL using HNSW or IVFFlat indexes alongside relational data.
- **Pros:** Zero extra infrastructure to manage; ACID guarantees; single transaction joins between business data and vectors; metadata filtering uses standard SQL WHERE clauses.
- **Cons:** PostgreSQL is memory-heavy; indexing millions of vectors can saturate database RAM and disk I/O, impacting core transactional workloads. For datasets exceeding 5–10 million vectors, dedicated vector DBs (e.g., Qdrant, Milvus) offer superior sharding, compression, and recall throughput.

### Q4: How do you identify and fix slow database queries in production?
**Answer:**
1. Enable `pg_stat_statements` in PostgreSQL to view queries with highest cumulative execution times.
2. Run `EXPLAIN ANALYZE <query>` to inspect the execution plan (look for Sequential Scans on large tables, high disk reads, or slow Nested Loops).
3. Add appropriate indexes (e.g., composite B-Tree indexes matching filter/sort orders).
4. Optimize the query (avoid functions on indexed columns like `WHERE LOWER(email) = ...`, use covering indexes to enable index-only scans).

### Q5: What is the difference between optimistic and pessimistic locking?
**Answer:**
- **Pessimistic Locking** (`SELECT ... FOR UPDATE`): Locks the database row at read time, preventing any other transaction from reading with lock or modifying until the current transaction commits. Best when contention is high, but risks deadlocks and reduces throughput.
- **Optimistic Locking**: Does not lock rows on read. Instead, tracks a `version_id` or timestamp column. On update: `UPDATE item SET val = :val, version = version + 1 WHERE id = :id AND version = :current_version`. If no rows are updated, another transaction modified it concurrently, so the application catches the conflict and retries. Best for read-heavy systems with low collision rates.
