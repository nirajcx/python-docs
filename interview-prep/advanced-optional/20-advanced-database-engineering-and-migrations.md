# Advanced Database Engineering: Indexing, Query Optimization & Zero-Downtime Migrations

> **Target Audience:** MNC / Tier-1 Tech Interviews (Staff / Senior Backend & AI Systems Engineer)  
> **Perspective:** Systems Architecture, Engine Internals, PostgreSQL 16+, Production Python Scripts  
> **Cross-References:** [06-databases-orm.md](../02-fastapi-backend/06-databases-orm.md) | [16-database-design-principles.md](../07-database-design/16-database-design-principles.md) | [19-high-scale-traffic-and-fintech.md](19-high-scale-traffic-and-fintech.md)

---

## 1. Deep Indexing Internals (B-Tree, GIN, BRIN & Hash)

In top-tier MNC interviews, simply stating "indexes speed up queries" will disqualify a candidate. You must articulate **data structure layouts, storage footprints, write amplification, and page management**.

```
                           B-Tree Page Architecture (PostgreSQL 8KB Page)
                           
                ┌──────────────────────────────────────────────────────────┐
                │                       Root Page                          │
                │        [Key: 100 | Pointer]     [Key: 500 | Pointer]     │
                └────────────────────┬───────────────────────┬─────────────┘
                                     │                       │
                ┌────────────────────▼─────┐   ┌─────────────▼─────────────┐
                │   Internal Page (Branch) │   │   Internal Page (Branch)  │
                │   [Key: 25]   [Key: 75]  │   │   [Key: 250]   [Key: 400] │
                └─────────┬────────────────┘   └───────────────────────────┘
                          │
     ┌────────────────────┴─────────────────────────────────────────┐
     │                                                              │
┌────▼─────────────────────────┐                               ┌────▼─────────────────────────┐
│       Leaf Page (Node)       │                               │       Leaf Page (Node)       │
│ [Key: 10 -> TID: (Block, Off)]│◄═════════════════════════════►│ [Key: 30 -> TID: (Block, Off)]│
│ [Key: 20 -> TID: (Block, Off)]│   Doubly-Linked Sibling Pointers [Key: 50 -> TID: (Block, Off)]│
└──────────────────────────────┘   (Enables O(1) Range Traversal)└──────────────────────────────┘
```

### Pointwise Index Architecture Comparison
1. **B-Tree (Balanced Multi-Way Search Tree)**:
   - **Page Size**: Stored in 8KB disk pages in PostgreSQL.
   - **Leaf Nodes**: Hold the sorted key and a 6-byte **TID (Tuple Identifier)** pointing to `(BlockNumber, OffsetNumber)` in the table heap.
   - **Doubly-Linked Leaves**: Leaf nodes are linked bidirectionally, allowing $O(1)$ sequential range scans (`WHERE created_at BETWEEN x AND y ORDER BY created_at ASC/DESC`).
   - **Write Amplification & Page Splits**: If an insert hits a full 8KB leaf page (exceeding `fillfactor`, default 90%), the engine splits the page into two 4KB pages, triggering expensive random disk I/O and WAL logging.
2. **GIN (Generalized Inverted Index)**:
   - **Mechanism**: Splits composite items (arrays, full-text documents, JSONB) into individual elements (keys), mapping each element to a sorted posting list/tree of TIDs.
   - **Write Profile**: Extremely expensive on `INSERT`/`UPDATE` due to posting tree re-balancing. Managed via `fastupdate = on` (buffers inserts into a pending list flushed asynchronously).
   - **Ideal For**: PostgreSQL `JSONB` containment (`@>`), full-text search (`tsvector`), and tag arrays.
3. **BRIN (Block Range Index)**:
   - **Mechanism**: Stores only the minimum and maximum values of a column for physical ranges of table pages (default: 128 pages = 1MB block).
   - **Footprint**: Up to **$99\%$ smaller** than a B-Tree index. A 100GB table might require a 15GB B-Tree index, but only a 50MB BRIN index.
   - **Prerequisite**: Data **must be physically correlated with insertion order** on disk (e.g., auto-incrementing timestamps, immutable append-only logs).
4. **Hash Index**:
   - Stores a 32-bit hash code mapped to bucket pages. Crash-safe in PostgreSQL 10+. Offers strictly $O(1)$ equality lookups (`=`), but cannot support range queries or sorting.

---

## 2. Advanced Query Optimization & `EXPLAIN (ANALYZE, BUFFERS)`

When answering performance questions at MNCs, explain queries through the lens of the **Cost-Based Optimizer (CBO)**, physical disk page buffers, and join algorithms.

### Anatomy of an `EXPLAIN (ANALYZE, BUFFERS)` Execution Plan
```sql
EXPLAIN (ANALYZE, BUFFERS, COSTS, VERBOSE, TIMING)
SELECT u.id, u.email, COUNT(d.id) AS doc_count
FROM users u
JOIN documents d ON d.user_id = u.id
WHERE u.organization_id = '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'
  AND d.status = 'PUBLISHED'
GROUP BY u.id, u.email;
```

```
                                                 QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=1254.20..1268.50 rows=1430 width=48) (actual time=14.210..15.120 rows=1200 loops=1)
   Group Key: u.id, u.email
   Batches: 1  Memory Usage: 241kB
   Buffers: shared hit=842 read=12
   ->  Hash Join  (cost=42.15..1232.75 rows=2860 width=40) (actual time=0.820..11.450 rows=3100 loops=1)
         Hash Cond: (d.user_id = u.id)
         Buffers: shared hit=842 read=12
         ->  Bitmap Heap Scan on documents d  (cost=18.40..1180.20 rows=5200 width=16) (actual time=0.410..7.200 rows=5120 loops=1)
               Recheck Cond: (status = 'PUBLISHED'::text)
               Buffers: shared hit=420 read=12
               ->  Bitmap Index Scan on idx_documents_status  (cost=0.00..17.10 rows=5200 width=0) (actual time=0.350..0.350 rows=5120 loops=1)
                     Index Cond: (status = 'PUBLISHED'::text)
                     Buffers: shared hit=8
         ->  Hash  (cost=21.20..21.20 rows=204 width=36) (actual time=0.380..0.380 rows=200 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 21kB
               Buffers: shared hit=422
               ->  Index Scan using idx_users_org_id on users u  (cost=0.29..21.20 rows=204 width=36) (actual time=0.030..0.290 rows=200 loops=1)
                     Index Cond: (organization_id = '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'::uuid)
                     Buffers: shared hit=422
 Planning Time: 0.420 ms
 Execution Time: 15.450 ms
```

### Pointwise Execution Plan Evaluation
- **`shared hit=842 read=12`**: 842 pages were read directly from RAM (`shared_buffers`), while 12 pages required physical NVMe disk I/O. A healthy cache-hit ratio is $> 99\%$.
- **Scan Types (Ordered from Best to Worst)**:
  1. **Index-Only Scan**: Reads data directly from B-Tree leaf pages without touching the heap table. Requires all selected columns to be indexed or included via `INCLUDE`, and the heap page must be clean according to the **Visibility Map**.
  2. **Index Scan**: Traverses B-Tree, fetches TIDs, and retrieves corresponding tuple pages from table heap.
  3. **Bitmap Index Scan + Bitmap Heap Scan**: Used when many matching rows exist. Gathers TIDs in a memory bitmap, sorts them by physical disk block order, and visits each table page only once, converting random I/O into sequential I/O.
  4. **Sequential Scan (`Seq Scan`)**: Reads every page in the table from disk. Catastrophic for OLTP on tables $> 100\text{k}$ rows.
- **Physical Join Algorithms (How the CBO joins tables)**:
  - **Nested Loop Join**: Outer loop scans table A; inner loop executes index lookup on table B for every row. Fast for tiny datasets or indexed single-row lookups ($O(N \log M)$).
  - **Hash Join**: Hashes smaller table into memory; scans larger table and probes the hash table. Best for unindexed medium-to-large datasets ($O(N + M)$).
  - **Merge Join**: Both datasets are sorted by join key, then merged linearly. Best when both datasets are already pre-sorted by an index ($O(N + M)$).

---

## 3. Handling Massive Datasets: Vacuuming, Bloat & Partition Pruning

At high scale (100M+ rows, 5,000+ QPS), standard PostgreSQL maintenance defaults will cause performance degradation.

### PostgreSQL MVCC & Dead Tuple Bloat
- PostgreSQL's **Multi-Version Concurrency Control (MVCC)** dictates that an `UPDATE` does not modify data in place; it inserts a new row version and sets `t_xmax` on the old version. A `DELETE` simply flags the row as dead.
- Dead rows cannot be reclaimed until no active transaction needs to see them.
- **Table Bloat**: If `AUTOVACUUM` is not tuned, dead tuples accumulate, bloating disk space, degrading cache efficiency, and forcing index scans to read millions of dead pointers.

```
                  PostgreSQL Autovacuum Tuning for High Write Volume
```
```ini
# postgresql.conf (Production High-Throughput Tuning)
autovacuum = on
autovacuum_max_workers = 5
autovacuum_naptime = 15s

# Reduce threshold scale factor from default 20% to 2%
# Default 20% means on a 100M row table, autovacuum won't trigger until 20M rows are dead!
autovacuum_vacuum_scale_factor = 0.02
autovacuum_vacuum_threshold = 1000

# Allocate enough memory for vacuum worker maintenance
maintenance_work_mem = 2GB
autovacuum_vacuum_cost_limit = 2000
autovacuum_vacuum_cost_delay = 2ms
```

---

## 4. Writing Production Scripts: Safe Batching & Checkpointing

**The MNC Interview Scenario:** *"You need to backfill a new encrypted column or recalculate foreign keys on a live 50-million-row production table while the application is actively serving 2,000 QPS. Write the migration script."*

### Why Naive Scripts Fail
- `UPDATE users SET encrypted_email = encrypt(email);` in a single transaction will:
  1. Hold an exclusive lock on all 50M rows.
  2. Generate 50GB of Write-Ahead Log (WAL) traffic, saturating replication lag to read replicas.
  3. Starve connection pools and crash the web application.

### The Production Python Script: Batched Keyset Pagination with Backoff
```python
"""
scripts/backfill_user_encryption.py
Production-grade, zero-lock batch data migration script with checkpointing.
"""

import sys
import time
import logging
import psycopg2
from psycopg2.extras import RealDictCursor

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("migration")

DB_DSN = "postgresql://postgres:secret@db-primary.internal:5432/production_db"
BATCH_SIZE = 2000
SLEEP_BETWEEN_BATCHES_SEC = 0.1  # Prevents saturating replica WAL buffers

def get_checkpoint(conn) -> str:
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS migration_checkpoints (
                migration_name VARCHAR(100) PRIMARY KEY,
                last_processed_id UUID,
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        """)
        cur.execute("SELECT last_processed_id FROM migration_checkpoints WHERE migration_name = 'user_encryption_v1';")
        row = cur.fetchone()
        return row[0] if row and row[0] else '00000000-0000-0000-0000-000000000000'

def save_checkpoint(conn, last_id: str):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO migration_checkpoints (migration_name, last_processed_id, updated_at)
            VALUES ('user_encryption_v1', %s, NOW())
            ON CONFLICT (migration_name) DO UPDATE 
            SET last_processed_id = EXCLUDED.last_processed_id, updated_at = NOW();
        """)
    conn.commit()

def run_migration():
    conn = psycopg2.connect(DB_DSN)
    conn.autocommit = False  # Explicit transaction management per batch

    last_id = get_checkpoint(conn)
    logger.info(f"Starting migration from checkpoint ID: {last_id}")

    total_migrated = 0

    try:
        while True:
            batch_start = time.perf_counter()
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # 1. Fetch batch using Keyset Pagination (O(1) seek using PK index)
                cur.execute("""
                    SELECT id, email 
                    FROM users 
                    WHERE id > %s 
                    ORDER BY id ASC 
                    LIMIT %s;
                """, (last_id, BATCH_SIZE))
                rows = cur.fetchall()

                if not rows:
                    logger.info("No more records to process. Migration complete!")
                    break

                # 2. Process / transform batch in memory
                update_params = []
                for row in rows:
                    encrypted = f"enc_{row['email']}"  # Replace with real crypto function
                    update_params.append((encrypted, row["id"]))

                # 3. Fast bulk update using execute_batch
                psycopg2.extras.execute_batch(cur, """
                    UPDATE users 
                    SET encrypted_email = %s 
                    WHERE id = %s;
                """, update_params)

                last_id = rows[-1]["id"]
                total_migrated += len(rows)

            # 4. Commit batch and update checkpoint
            conn.commit()
            save_checkpoint(conn, last_id)

            elapsed = time.perf_counter() - batch_start
            logger.info(f"Batch completed: {len(rows)} rows in {elapsed*1000:.1f}ms | Total: {total_migrated} | Last ID: {last_id}")

            # 5. Yield execution to avoid hogging database CPU/IO
            time.sleep(SLEEP_BETWEEN_BATCHES_SEC)

    except Exception as exc:
        conn.rollback()
        logger.error(f"Migration failed! State safely checkpointed at ID {last_id}. Error: {exc}")
        sys.exit(1)
    finally:
        conn.close()

if __name__ == "__main__":
    run_migration()
```

---

## 5. Zero-Downtime Alembic Migrations

In production, running `alembic upgrade head` while your API is serving live traffic will cause downtime if you drop, rename, or add columns naively.

### The Expand / Contract (Parallel Run) Lifecycle

```
Phase 1 (Expand)            Phase 2 (Backfill)          Phase 3 (Switch)            Phase 4 (Contract)
┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
│ • Add nullable column │   │ • Background script   │   │ • App reads/writes    │   │ • Drop old column     │
│ • App dual-writes to  │──►│   backfills historical│──►│   exclusively from    │──►│ • Drop dual-write     │
│   both old & new cols │   │   data in batches     │   │   new column          │   │   compatibility logic │
└───────────────────────┘   └───────────────────────┘   └───────────────────────┘   └───────────────────────┘
```

### Production Alembic Migration Script Example
```python
"""
migrations/versions/20260911_add_index_concurrently_and_new_column.py
Alembic migration demonstrating zero-lock principles.
"""

from alembic import op
import sqlalchemy as sa

revision = '20260911_zero_downtime'
down_revision = '20260910_previous_rev'
branch_labels = None
depends_on = None

def upgrade():
    # RULE 1: Never add non-nullable columns without defaults on large tables.
    # Add column as NULLABLE first.
    op.add_column('users', sa.Column('phone_number_v2', sa.String(length=32), nullable=True))

    # RULE 2: NEVER create indexes inside a standard transaction block!
    # Commit existing transaction, set autocommit, and use CONCURRENTLY.
    op.execute("COMMIT")
    op.execute("""
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_phone_v2 
        ON users (phone_number_v2) 
        WHERE phone_number_v2 IS NOT NULL;
    """)

def downgrade():
    op.execute("COMMIT")
    op.execute("DROP INDEX CONCURRENTLY IF EXISTS idx_users_phone_v2")
    op.drop_column('users', 'phone_number_v2')
```

---

## 6. Pointwise MNC Interview Questions & Answers (Database Engineering)

### Q1: What is the difference between an Index Scan, an Index-Only Scan, and a Bitmap Heap Scan?
- **Index Scan**: Traverses the B-Tree index to locate matching pointers (`TIDs`), then reads the physical table heap page for each matching tuple. Best for low-cardinality lookups returning $< 1\text{--}5\%$ of the table.
- **Index-Only Scan**: Reads all required column values directly from the index leaf pages without accessing the table heap at all. Possible only when all queried columns exist in the index (or `INCLUDE` clause) AND the heap pages are flagged clean in the **Visibility Map**.
- **Bitmap Heap Scan**: Used when an index scan would return many rows scattered across many heap pages. It evaluates the B-Tree, constructs an in-memory bitmap of matching physical block IDs, sorts the blocks sequentially, and fetches each heap page once, converting expensive random disk I/O into sequential disk I/O.

### Q2: How does column ordering in a composite index affect query performance, and what is write amplification?
- **Column Ordering**: Multi-column B-Trees are ordered strictly by the **leftmost prefix rule**. Columns evaluated for exact equality (`=`) must come first, followed by range/inequality filters (`<`, `>`, `BETWEEN`), and finally sort columns (`ORDER BY`). Omitting the leading column forces the planner to abandon the index or perform a costly full index scan.
- **Write Amplification**: Every additional index on a table requires every `INSERT`, `UPDATE`, and `DELETE` to update both the heap table and all corresponding index B-Tree pages. A table with 10 indexes incurs 11 physical disk writes per insert.

### Q3: What is the difference between `DELETE`, `TRUNCATE`, and dropping a partition?
- **`DELETE`**: Scans the table, logs every individual row deletion to the Write-Ahead Log (WAL), generates dead tuples, and requires subsequent vacuuming. Very slow for large tables ($O(N)$).
- **`TRUNCATE`**: Deallocates table storage pages at the OS filesystem level in a single transaction, bypassing row-by-row logging. Resets identity sequences if specified. Fast ($O(1)$), but locks the table exclusively.
- **Dropping a Partition (`DROP TABLE partition_2025_01`)**: Deletes the underlying OS disk file directly via metadata unlinking. Zero WAL traffic, instantaneous ($O(1)$), and releases disk space immediately back to the operating system without vacuuming.

### Q4: How do you resolve a database deadlock, and how do you write code to prevent them?
- **Resolution**: PostgreSQL automatically detects deadlocks using a background timer (`deadlock_timeout`, default 1s). If a cyclic dependency exists in the wait-for graph, the engine aborts the transaction that entered the wait condition last with SQLSTATE `40P01`.
- **Prevention (Deterministic Lock Ordering)**: Deadlocks happen when Transaction A locks row 1 and waits for row 2, while Transaction B locks row 2 and waits for row 1. Application code must enforce **strict lock ordering** (e.g., sorting all target IDs alphabetically or numerically before issuing `SELECT ... FOR UPDATE`):
  ```python
  locked_ids = sorted([user_a_id, user_b_id])
  ```
  Because both transactions acquire locks in identical sequential order, cyclical wait states are mathematically impossible.
