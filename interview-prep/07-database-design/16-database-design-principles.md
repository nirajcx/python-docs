# Database Design Principles: Normalization, Indexing & Multi-Tenancy

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [06-databases-orm.md](../02-fastapi-backend/06-databases-orm.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md)

---

## 1. Relational Data Modeling & Normalization

Database normalization is the process of structuring relational schemas to eliminate redundancy and prevent anomalies (insertion, update, and deletion).

```
                      The Normalization Progression
                      
 1NF (Atomicity)           2NF (No Partial Dep)      3NF (No Transitive Dep)
┌───────────────────────┐ ┌───────────────────────┐ ┌───────────────────────┐
│ • Atomic values only  │ │ • Satisfies 1NF       │ │ • Satisfies 2NF       │
│ • No comma-lists/arrays│ │ • Non-key columns     │ │ • Non-key columns     │
│ • Unique primary key  │ │   depend on WHOLE PK, │ │   depend ONLY on PK,  │
│                       │ │   not partial PK      │ │   not on other non-keys│
└───────────────────────┘ └───────────────────────┘ └───────────────────────┘
```

### Normalization Ladder:
- **1NF (First Normal Form)**: Every cell contains atomic (indivisible) values; no repeating groups or arrays stored as text; primary key uniquely identifies each row.
- **2NF (Second Normal Form)**: Must be in 1NF, and all non-key attributes must depend on the **entire candidate key** (eliminates partial key dependencies in tables with composite primary keys).
- **3NF (Third Normal Form)**: Must be in 2NF, and no non-key attribute can depend on another non-key attribute (**no transitive dependencies**: $X \to Y \to Z$).
- **BCNF (Boyce-Codd Normal Form)**: A stricter 3NF. For every functional dependency $X \to Y$, $X$ **must be a superkey**.

### Intentional Denormalization: When to Break the Rules
In read-heavy or high-throughput analytics systems, pure 3NF/BCNF schemas require 5–8 table joins per query, causing severe CPU and disk I/O bottlenecks.  
**Valid Reasons to Denormalize:**
1. **Pre-aggregating Metrics**: Storing `total_documents_count` directly on `organizations` table rather than executing `SELECT COUNT(*) FROM documents WHERE org_id = ...` on every request.
2. **Immutable Point-in-Time Snapshots**: Duplicating `customer_address` or `product_price` directly into the `orders` row so future changes to the customer profile never alter historical legal invoices.

---

## 2. Primary Key Architecture: UUID v4 vs. UUID v7 vs. BIGINT

Choosing the wrong primary key format can cripple database performance at scale.

```
                   Primary Key B-Tree Index Fragmentation
                   
 Sequential Keys (BIGINT / UUID v7 / ULID)     Random Keys (UUID v4)
┌────────────────────────────────────────┐    ┌────────────────────────────────────────┐
│ [1] ──► [2] ──► [3] ──► [4] ──► [5]    │    │ [c8] ──► [04] ──► [fa] ──► [1a] ──► [e2]│
│ Appends sequentially to rightmost leaf │    │ Inserts randomly anywhere in B-tree    │
│ Good locality; splits still occur         │    │ Constant B-Tree page splits & high I/O!│
└────────────────────────────────────────┘    └────────────────────────────────────────┘
```

| Key Strategy | Size | Distributed Unique? | B-Tree Locality | Security / Leakage Risk |
|---|---|---|---|---|
| **`BIGINT` (Auto-Increment)** | 8 Bytes | ❌ Requires central coordinator | **Optimal** (Sequential append) | **High**: Enumeration attack (`/api/users/1042`) reveals business volume. |
| **`UUID v4` (Random)** | 16 Bytes | ✅ Very low collision probability | Lower locality (random inserts)| Opaque; still requires authorization. |
| **`UUID v7` / `ULID` (Time-Sorted)**| 16 Bytes | ✅ Very low collision probability | Good time locality (not globally monotonic) | **Low**: High 48 bits encode UNIX timestamp; low bits random. |

> **Design choice:** Compare BIGINT and UUIDs against distribution, storage and ordering requirements. UUID v7 improves time locality relative to v4; verify generation support in the selected database/library version. Enforce uniqueness and authorization independently.

---

## 3. Advanced Indexing Strategies

An index is a separate data structure (most commonly a **B-Tree**) that trades write speed and disk space for $O(\log N)$ query speed.

### 1. Composite Indexes & Column Ordering
If your query is:
```sql
SELECT * FROM audit_logs 
WHERE organization_id = 'org_123' 
  AND status = 'FAILED' 
  AND created_at >= '2026-01-01'
ORDER BY created_at DESC;
```
**Optimal Index Definition:**
```sql
CREATE INDEX idx_audit_org_status_created 
ON audit_logs (organization_id, status, created_at DESC);
```
**Golden Rule of Composite Index Ordering:**
1. **Equality columns first** (`organization_id`, `status`).
2. **Range / Inequality columns next** (`created_at`).
3. **Sort columns last** (if not already handled by range).

### 2. Partial Indexes (Savings Depend on Selected Rows)
Only index rows that are actually queried:
```sql
-- Index ONLY active documents, ignoring 10 million soft-deleted rows!
CREATE INDEX idx_active_documents ON documents (org_id, title)
WHERE deleted_at IS NULL;
```

### 3. Covering Indexes (`INCLUDE` Clause)
Enables PostgreSQL to satisfy the entire query from the index leaf pages without reading the physical table heap (**Index-Only Scan**):
```sql
CREATE INDEX idx_users_email_covering ON users (email) 
INCLUDE (id, first_name, role);
```

---

## 4. Multi-Tenant Database Architecture (SaaS & Enterprise ERP)

```
                            Multi-Tenant Design Patterns
                            
   Pattern 1: Shared DB, Shared Schema      Pattern 2: Schema-per-Tenant     Pattern 3: DB-per-Tenant
  ┌─────────────────────────────────┐      ┌─────────────────────────┐      ┌───────────┐ ┌───────────┐
  │ Table: documents                │      │ Schema: tenant_a        │      │ Tenant A  │ │ Tenant B  │
  │ id | tenant_id | title          │      │ Schema: tenant_b        │      │ Database  │ │ Database  │
  │ 1  | org_A     | Report.pdf     │      │ (Separate tables in     │      │ (Physical │ │ (Physical │
  │ 2  | org_B     | Contract.pdf   │      │  same Postgres DB)      │      │  Instance)│ │  Instance)│
  └─────────────────────────────────┘      └─────────────────────────┘      └───────────┘ └───────────┘
```

| Criterion | 1. Shared DB, Shared Schema | 2. Schema-per-Tenant | 3. Database-per-Tenant |
|---|---|---|---|
| **Infrastructure Cost** | **Lowest** (Maximum density) | Low-Medium | **Highest** (Many idle DBs) |
| **Data Isolation** | Logical (`WHERE tenant_id = ...`) | Schema boundary | **Physical / Hard isolation** |
| **Schema Migrations** | Fastest (Run Alembic once) | Slow (Loop over 1,000 schemas)| Slowest (1,000 DB migrations) |
| **Noisy Neighbor Risk**| High (Shared buffer cache) | Medium | **Zero** |
| **Enterprise Compliance**| Requires Row-Level Security (RLS) | Moderate | **Gold Standard** (HIPAA / FinTech) |

### Enforcing Multi-Tenancy with PostgreSQL Row-Level Security (RLS)
Prevents accidental data leakage even if a developer forgets `WHERE tenant_id = ...` in Python:
```sql
-- Enable RLS on table
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Create policy bound to session variable
CREATE POLICY tenant_isolation_policy ON documents
FOR ALL
USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- In FastAPI connection hook:
-- SET LOCAL app.current_tenant_id = 'uuid-of-tenant';
```

---

## 5. Table Partitioning (PostgreSQL Declarative Partitioning)

When a table grows past 50–100 million rows (e.g. audit logs, telemetry events, chat messages), B-Tree indexes exceed available RAM.

```sql
-- Range Partitioning by Month
CREATE TABLE telemetry_events (
    id UUID NOT NULL,
    organization_id UUID NOT NULL,
    event_type VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE telemetry_2026_01 PARTITION OF telemetry_events
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE telemetry_2026_02 PARTITION OF telemetry_events
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```
- **Partition Pruning**: Queries with `WHERE created_at >= '2026-02-15'` automatically skip scanning `telemetry_2026_01` entirely.
- **Instant Data Retention Deletion**: Dropping old logs is instantaneous (`DROP TABLE telemetry_2025_01;`) without incurring expensive row-by-row `DELETE` dead tuples and vacuuming.

---

## 6. OLTP vs. OLAP: Row-Oriented vs. Column-Oriented Storage

| Dimension | OLTP (e.g. PostgreSQL, MySQL) | OLAP (e.g. ClickHouse, Snowflake, BigQuery) |
|---|---|---|
| **Data Organization** | **Row-oriented** (stores row data sequentially) | **Column-oriented** (stores all values of a column sequentially) |
| **Query Profile** | Simple CRUD lookups by ID; transactional writes | Aggregate queries: `AVG()`, `SUM()`, `GROUP BY` over millions of rows |
| **I/O Efficiency** | High for single-row reads; terrible for aggregations | Phenomenal for aggregations (reads only the requested column from disk)|
| **Compression** | Modest (mixed data types per block) | Extremely high ($5\text{--}10\times$ compression; uniform types per block) |
| **Best For** | User auth, billing, checkout, ERP transactions | RAG telemetry, clickstream analytics, BI reporting |

---

## 7. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What is database bloat and how does PostgreSQL MVCC cause it?"**
   - In PostgreSQL, an `UPDATE` does not overwrite the row on disk; it marks the old row as dead and inserts a new row version (Multi-Version Concurrency Control). Dead tuples consume disk space until cleaned up by `VACUUM` or `AUTOVACUUM`. Heavy updates on un-tuned databases cause severe table and index bloat.
2. **"Why should you never use `NOT IN (SELECT ...)` with nullable columns?"**
   - If the subquery returns even a single `NULL` value, the entire `NOT IN` condition evaluates to `UNKNOWN` (falsy) for all rows, returning zero results! Use `NOT EXISTS (SELECT 1 ...)` instead.
3. **"What is the difference between a Surrogate Key and a Natural Key?"**
   - A **Natural Key** is an attribute with real-world business meaning that uniquely identifies a record (e.g. Social Security Number, ISBN, email). A **Surrogate Key** is a synthetic, database-generated identifier (e.g. `BIGINT` ID, `UUID`) with zero domain meaning. Senior rule: Always prefer surrogate keys for primary keys to decouple internal relationships from volatile business changes.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: What is the Boyce-Codd Normal Form (BCNF), and when does 3NF fail to satisfy it?
**Answer:**
A table is in 3NF if for every functional dependency $X \to Y$, either $X$ is a superkey OR $Y$ is a prime attribute (part of a candidate key).  
BCNF removes that second leniency: for *every* non-trivial functional dependency $X \to Y$, $X$ **must strictly be a superkey**.  
3NF fails to satisfy BCNF when a table has multiple overlapping candidate keys and an attribute of one candidate key is functionally determined by a non-superkey. BCNF anomalies are resolved by decomposing the table into two separate relations.

### Q2: How do you migrate a 100-million row table without locking it in production?
**Answer:**
1. **Never run `ALTER TABLE ADD COLUMN default_val` with volatile defaults** in older Postgres versions (PostgreSQL 11+ handles constant defaults in metadata without rewrites).
2. **Creating Indexes**: Always use `CREATE INDEX CONCURRENTLY`. Standard `CREATE INDEX` locks the table for writes; `CONCURRENTLY` performs two table scans without blocking incoming `INSERT`, `UPDATE`, or `DELETE` statements.
3. **Column Backfills**: Never run `UPDATE table SET new_col = ...` across 100M rows in a single transaction (locks rows, causes table bloat, exhausts WAL logs). Chunk the backfill into batches of 5,000 rows executed in separate short transactions with pauses in between.

### Q3: What is the difference between Sharding and Partitioning?
**Answer:**
- **Partitioning** splits a large logical table into smaller physical partitions within the **same single database instance**. The database query planner manages routing transparently.
- **Sharding** distributes data partitions across **multiple independent physical database servers/nodes**. Requires a sharding key and routing middleware (or Citus/Vitess), introducing network latency and complex cross-shard transaction boundaries (2-Phase Commit).

### Q4: When should you use PostgreSQL's `JSONB` type vs. dedicated columns?
**Answer:**
- Use **dedicated relational columns** when the data is structured, queried frequently in `WHERE` / `JOIN` clauses, requires foreign key constraints, or needs strict data type enforcement.
- Use **`JSONB`** for polymorphic schemas, arbitrary third-party API payloads (e.g. Stripe webhook dumps), rapidly evolving user preferences, or dynamic custom fields where schema flexibility outweighs relational constraints. JSONB can be indexed using GIN indexes for fast key/value containment queries (`@>`).
