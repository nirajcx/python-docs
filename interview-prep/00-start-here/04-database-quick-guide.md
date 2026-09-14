# SQL & Database Quick Guide (Start Here)

You've used PostgreSQL, so this builds the mental model behind what you've done. Format: **concept → plain explanation → what you say in an interview → likely follow-up.**

Databases come up in almost every backend interview. You don't need to be a DBA — you need to reason clearly about tables, queries, indexes, and transactions.

---

## 1. SQL basics you must be fluent in

```sql
-- Read
SELECT name, email FROM users WHERE age > 18 ORDER BY name LIMIT 10;

-- Insert
INSERT INTO users (name, email) VALUES ('Asha', 'asha@x.com');

-- Update
UPDATE users SET age = 25 WHERE id = 1;

-- Delete
DELETE FROM users WHERE id = 1;
```

**Aggregation** (grouping):
```sql
SELECT country, COUNT(*) AS user_count
FROM users
GROUP BY country
HAVING COUNT(*) > 100;   -- HAVING filters groups; WHERE filters rows
```

**Interview answer for WHERE vs HAVING:** "`WHERE` filters individual rows before grouping. `HAVING` filters the groups after `GROUP BY`."

---

## 2. Joins (the #1 SQL interview topic)

**Plain explanation:** A join combines rows from two tables using a related column.

| Join | Returns |
|---|---|
| `INNER JOIN` | Only rows that match in both tables |
| `LEFT JOIN` | All rows from the left table + matches (NULL if none) |
| `RIGHT JOIN` | All rows from the right table + matches |
| `FULL OUTER JOIN` | All rows from both, matched where possible |

```sql
-- All users and their orders (users with no orders still show, order fields NULL)
SELECT u.name, o.total
FROM users u
LEFT JOIN orders o ON o.user_id = u.id;
```

**Interview answer:** "INNER JOIN keeps only matching rows. LEFT JOIN keeps every row from the left side even if there's no match. I reach for LEFT JOIN when I want all the primary records regardless of whether related data exists."

---

## 3. Indexes (why queries are fast or slow)

**Plain explanation:** An index is like the index at the back of a book. Without it, the database reads every row to find matches (a "full table scan"). With it, it jumps straight to the rows. Indexes make reads faster but writes slightly slower (the index must be updated too), and they use disk.

```sql
CREATE INDEX idx_users_email ON users(email);
```

**When to add one:** on columns you frequently filter (`WHERE`), join on, or sort by.

**Interview answer:** "An index speeds up lookups by avoiding a full table scan, at the cost of extra storage and slightly slower writes. I index columns used in WHERE, JOIN, and ORDER BY. I check a slow query with `EXPLAIN` to see if it's using the index."

**Follow-up:** *"Downside of too many indexes?"* → Every insert/update has to maintain them, so writes get slower and storage grows.

---

## 4. Primary keys, foreign keys, constraints

- **Primary key:** uniquely identifies a row (`id`). One per table.
- **Foreign key:** a column pointing to another table's primary key (`orders.user_id → users.id`). Enforces that the reference is valid.
- **Unique / NOT NULL / CHECK:** rules the database enforces so bad data can't get in.

**Interview answer:** "Foreign keys enforce referential integrity — you can't create an order for a user that doesn't exist. I let the database enforce constraints rather than relying only on app code."

---

## 5. Normalization (organizing tables)

**Plain explanation:** Normalization means splitting data so each fact lives in exactly one place, avoiding duplication. Instead of repeating a customer's address on every order, you store it once in a `customers` table and reference it.

- **1NF:** no repeating groups; each cell holds one value.
- **2NF/3NF:** every column depends on the key, the whole key, and nothing but the key.

**When to denormalize:** for read-heavy systems you sometimes duplicate data on purpose to avoid expensive joins.

**Interview answer:** "Normalization removes duplication so data stays consistent. I normalize by default, then denormalize selectively when read performance matters more than avoiding duplication."

---

## 6. Transactions & ACID

**Plain explanation:** A transaction groups several statements so they all succeed or all fail together. Classic example: transferring money — debit one account and credit another must both happen or neither.

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;   -- or ROLLBACK if something failed
```

**ACID** in one line each:
- **Atomicity:** all-or-nothing.
- **Consistency:** the DB moves from one valid state to another.
- **Isolation:** concurrent transactions don't corrupt each other.
- **Durability:** once committed, it survives a crash.

**Interview answer:** "A transaction makes several operations atomic — all succeed or all roll back. I use one whenever multiple writes must stay consistent, like updating an order and reducing inventory together."

---

## 7. SQL vs NoSQL

| SQL (PostgreSQL, MySQL) | NoSQL (MongoDB, DynamoDB) |
|---|---|
| Structured tables, fixed schema | Flexible documents |
| Strong relationships & joins | Denormalized, few joins |
| ACID transactions | Often eventual consistency |
| Great default for most apps | Great for huge scale / flexible shape |

**Interview answer:** "I default to PostgreSQL because most apps have relationships and benefit from transactions and constraints. I'd consider NoSQL for very large scale or genuinely schema-less data."

---

## 8. The N+1 query problem (very common in ORM interviews)

**Plain explanation:** You fetch a list (1 query), then loop and fetch related data for each item (N more queries). 100 users → 101 queries. Slow.

**Fix:** fetch related data in one go — a JOIN, or the ORM's eager loading (`selectinload` / `joinedload` in SQLAlchemy).

**Interview answer:** "N+1 is when I load a list and then query the database once per item for related data. I fix it with eager loading or a join so it's one or two queries instead of hundreds."

---

## Quick self-test
1. INNER JOIN vs LEFT JOIN?
2. What does an index do, and what's the tradeoff?
3. Explain a transaction with a real example.
4. What is the N+1 problem and how do you fix it?
5. When would you pick NoSQL over PostgreSQL?

More detail: [`../02-fastapi-backend/06-databases-orm.md`](../02-fastapi-backend/06-databases-orm.md) and [`../07-database-design/16-database-design-principles.md`](../07-database-design/16-database-design-principles.md).
