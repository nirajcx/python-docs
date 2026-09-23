# PostgreSQL concurrency labs — do query tabs mein dekho

[Setup](README.md). PostgreSQL server par **two independent connections** A/B kholo. Same tab mein all commands paste mat karo. PGlite single-session verification concurrent scheduling prove nahi karti.

Dono tabs mein run:

```sql
SET search_path = interview_lab, public;
SET TIME ZONE 'UTC';
SET lock_timeout = '15s';
SET statement_timeout = '30s';
```

Only training DB. Autocommit normal rakho; explicit BEGIN/COMMIT steps below follow karo. Error ke baad failed transaction mein `ROLLBACK` needed. Timing miss karke timeout aaye toh rollback and lab retry.

## Lab 1 — last monitor, two buyers

Before starting, A only (no other transactions):

```sql
UPDATE inventory SET stock=1,version=1 WHERE product_id=4;
BEGIN;
UPDATE inventory SET stock=stock-1,version=version+1
WHERE product_id=4 AND stock>0 RETURNING stock;
-- A sees 0; don't commit yet.
```

B:

```sql
BEGIN;
UPDATE inventory SET stock=stock-1,version=version+1
WHERE product_id=4 AND stock>0 RETURNING stock;
-- Waits for A. Switch to A promptly.
```

A: `COMMIT;`. B unblocks; default Read Committed rechecks updated row condition, **zero rows** returns. B: `COMMIT;`. Final stock 0, not -1. Restore outside transaction: `UPDATE inventory SET stock=1,version=1 WHERE product_id=4;`.

**Follow-up:** A rollback karta toh B stock decrement succeed kar sakta tha. Related order insert same successful reservation transaction mein chahiye.

## Lab 2 — normal SELECT vs locking SELECT

A:

```sql
BEGIN;
SELECT * FROM inventory WHERE product_id=4 FOR UPDATE;
```

B:

```sql
SELECT stock FROM inventory WHERE product_id=4;
-- Normal MVCC SELECT ordinarily returns; it doesn't wait for row lock.
BEGIN;
SELECT stock FROM inventory WHERE product_id=4 FOR UPDATE NOWAIT;
-- Expected SQLSTATE 55P03 lock_not_available; transaction failed.
ROLLBACK;
```

A: `ROLLBACK;`. Explains “row lock means nobody can read” misconception.

## Lab 3 — Read Committed vs Repeatable Read

Initialize A outside transaction: `UPDATE inventory SET stock=1 WHERE product_id=4;`.

A: `BEGIN ISOLATION LEVEL READ COMMITTED; SELECT stock FROM inventory WHERE product_id=4;` → 1.

B: `UPDATE inventory SET stock=2 WHERE product_id=4;` → autocommitted.

A: `SELECT stock FROM inventory WHERE product_id=4;` → 2, then `COMMIT;`.

Repeat with initialization stock=1, A `BEGIN ISOLATION LEVEL REPEATABLE READ;` and first SELECT, B writes 2. A second SELECT still **1**. A `COMMIT;`. Restore stock=1. Snapshot established at first relevant statement, not merely wall-clock BEGIN.

## Lab 4 — optimistic edit version

A outside transaction:

```sql
UPDATE inventory SET stock=10,version=1 WHERE product_id=1;
SELECT version FROM inventory WHERE product_id=1; -- 1
```

B separately `SELECT version FROM inventory WHERE product_id=1;` → 1. A:

```sql
UPDATE inventory SET stock=9,version=version+1
WHERE product_id=1 AND version=1 RETURNING version; -- 2
```

B same expected version:

```sql
UPDATE inventory SET stock=8,version=version+1
WHERE product_id=1 AND version=1 RETURNING version; -- zero rows
```

Conflict means reread/reconcile, don't silently retry overwrite user's edit. UPDATE still acquires DB locks during write. Restore `UPDATE inventory SET stock=10,version=1 WHERE product_id=1;`.

## Lab 5 — deadlock

A: `BEGIN; UPDATE inventory SET stock=stock+1 WHERE product_id=1;`

B: `BEGIN; UPDATE inventory SET stock=stock+1 WHERE product_id=2;`

A: `UPDATE inventory SET stock=stock+1 WHERE product_id=2;` → waits.

B: `UPDATE inventory SET stock=stock+1 WHERE product_id=1;` → cycle. PostgreSQL aborts one transaction with deadlock detected (40P01); victim not predetermined. Run `ROLLBACK;` on victim promptly so survivor proceeds, then `ROLLBACK;` on survivor. Both changes discarded. If lock timeout wins because steps too slow, repeat promptly. Consistent lock order + short transactions + bounded retry policy reduces impact.

## Lab 6 — savepoint after error (run statements one by one)

```sql
BEGIN;
UPDATE inventory SET stock=11 WHERE product_id=1;
SAVEPOINT optional_step;
UPDATE inventory SET stock=-1 WHERE product_id=2;
-- Expected CHECK violation 23514. Next command recovers failed subtransaction.
ROLLBACK TO SAVEPOINT optional_step;
SELECT stock FROM inventory WHERE product_id=1; -- 11
ROLLBACK;
SELECT stock FROM inventory WHERE product_id=1; -- 10, if prior labs restored
```

A psql script with ON_ERROR_STOP halts at intended error. This lab is interactive intentionally.

## Lab 7 — idempotent event insert

```sql
BEGIN;
INSERT INTO webhook_events(event_id,payload)
VALUES('event-demo','{"action":"grant-credit"}')
ON CONFLICT(event_id) DO NOTHING RETURNING event_id; -- one row
INSERT INTO webhook_events(event_id,payload)
VALUES('event-demo','{"action":"grant-credit"}')
ON CONFLICT(event_id) DO NOTHING RETURNING event_id; -- zero rows
ROLLBACK;
```

Only successful first insertion should trigger same-transaction DB effect. External payment/email still needs provider idempotency/reconciliation. Atomic insert avoids “SELECT exists then INSERT” race.

## Lab 8 — serializable write skew (optional advanced)

Training table create once: `CREATE TABLE interview_lab.on_call (doctor text PRIMARY KEY, active boolean NOT NULL); INSERT INTO interview_lab.on_call VALUES ('A',true),('B',true);`.

A and B: `BEGIN ISOLATION LEVEL SERIALIZABLE; SELECT COUNT(*) FROM interview_lab.on_call WHERE active;` → both 2 before writes.

A: `UPDATE interview_lab.on_call SET active=false WHERE doctor='A';`.

B: `UPDATE interview_lab.on_call SET active=false WHERE doctor='B';`.

Try A `COMMIT;`, then B `COMMIT;`. Serialization failure (40001) can occur on a statement or commit; one transaction must abort. In failed tab ROLLBACK, start new transaction and **rerun count/business decision**, don't just retry last UPDATE. Restore `UPDATE interview_lab.on_call SET active=true;` outside transactions. Real invariant: at least one doctor remains active; snapshot isolation alone can allow both to go off call.
