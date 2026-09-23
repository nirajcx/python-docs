-- PostgreSQL 15+ solutions. Read exercises first. Read-only queries.
SET search_path = interview_lab, public;
SET TIME ZONE 'UTC';

-- Q01: Products with price >= 500, descending price; ties by ID.
-- Why: Comparison + ORDER BY. Without ORDER BY output order guaranteed nahi.
SELECT id, name, price FROM products WHERE price >= 500 ORDER BY price DESC, id;

-- Q02: Customers whose city is missing.
-- Why: NULL check IS NULL, = NULL nahi.
SELECT id, name FROM customers WHERE city IS NULL ORDER BY id;

-- Q03: Distinct known cities in alphabetical order.
-- Why: DISTINCT duplicates remove karta hai; NULL policy explicit.
SELECT DISTINCT city FROM customers WHERE city IS NOT NULL ORDER BY city;

-- Q04: Order count by status.
-- Why: GROUP BY rows collapse karke aggregate banata hai.
SELECT status, COUNT(*) AS orders FROM orders GROUP BY status ORDER BY status;

-- Q05: Every customer and total order count, including zero.
-- Why: COUNT(o.id), not COUNT(*): unmatched customer zero.
SELECT c.id, COUNT(o.id) AS orders FROM customers c LEFT JOIN orders o ON o.customer_id=c.id GROUP BY c.id ORDER BY c.id;

-- Q06: Every customer and paid order count, including zero.
-- Why: Right-side filter ON mein unmatched customers preserve karta hai.
SELECT c.id, COUNT(o.id) AS paid_orders FROM customers c LEFT JOIN orders o ON o.customer_id=c.id AND o.status='paid' GROUP BY c.id ORDER BY c.id;

-- Q07: Customers who have never ordered.
-- Why: NOT EXISTS avoids NULL-sensitive NOT IN trap.
SELECT c.id FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id=c.id) ORDER BY c.id;

-- Q08: Compute total for every order using quantity and purchase unit_price.
-- Why: Historical unit_price, not current products.price.
SELECT order_id, SUM(quantity*unit_price) AS total FROM order_items GROUP BY order_id ORDER BY order_id;

-- Q09: Total paid revenue across all tenants; refunded/pending/cancelled exclude.
-- Why: Revenue definition explicit; accounting settlement/refunds separate model ho sakta hai.
SELECT SUM(t.total) AS revenue FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE o.status='paid';

-- Q10: Paid spend per customer, including zero, ordered by customer ID.
-- Why: Aggregate NULL ko COALESCE; join paid filter safe.
SELECT c.id, COALESCE(SUM(t.total),0) AS paid_spend FROM customers c LEFT JOIN orders o ON o.customer_id=c.id AND o.status='paid' LEFT JOIN order_totals t ON t.order_id=o.id GROUP BY c.id ORDER BY c.id;

-- Q11: Customers with at least two paid orders.
-- Why: WHERE rows first, HAVING groups later.
SELECT customer_id, COUNT(*) AS paid_orders FROM orders WHERE status='paid' GROUP BY customer_id HAVING COUNT(*)>=2 ORDER BY customer_id;

-- Q12: Paid monthly revenue, using UTC month, Jan–Mar 2026.
-- Why: Timezone explicit, so local midnight does not shift grouping.
SELECT to_char(date_trunc('month',o.created_at AT TIME ZONE 'UTC'),'YYYY-MM') AS month, SUM(t.total) AS revenue FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE o.status='paid' GROUP BY 1 ORDER BY 1;

-- Q13: Daily paid revenue Jan 1–5 UTC, including days with no orders.
-- Why: Date spine + LEFT JOIN fills missing days.
WITH days AS (SELECT d::date AS day FROM generate_series('2026-01-01'::timestamp,'2026-01-05'::timestamp,interval '1 day') d), daily AS (SELECT (o.created_at AT TIME ZONE 'UTC')::date AS day, SUM(t.total) AS revenue FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE o.status='paid' GROUP BY 1) SELECT days.day::text, COALESCE(daily.revenue,0) AS revenue FROM days LEFT JOIN daily USING(day) ORDER BY days.day;

-- Q14: Latest order per customer; timestamp ties resolved by higher order ID.
-- Why: ROW_NUMBER gives exactly one deterministic winner.
WITH ranked AS (SELECT id,customer_id,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY created_at DESC,id DESC) AS rn FROM orders) SELECT customer_id,id FROM ranked WHERE rn=1 ORDER BY customer_id;

-- Q15: Latest paid order per customer using PostgreSQL DISTINCT ON.
-- Why: DISTINCT ON prefix ORDER BY matches grouping, deterministic tie-breaker.
SELECT DISTINCT ON(customer_id) customer_id,id FROM orders WHERE status='paid' ORDER BY customer_id,created_at DESC,id DESC;

-- Q16: All employees at the second-highest distinct salary company-wide.
-- Why: DENSE_RANK distinct salary, not second physical employee.
WITH ranked AS (SELECT id,name,salary,DENSE_RANK() OVER(ORDER BY salary DESC) AS r FROM employees) SELECT id,name,salary FROM ranked WHERE r=2 ORDER BY id;

-- Q17: Employees in top two distinct salary levels of each department, include ties.
-- Why: Ties included, can return >2 employees per department.
WITH ranked AS (SELECT id,department_id,salary,DENSE_RANK() OVER(PARTITION BY department_id ORDER BY salary DESC) AS r FROM employees) SELECT department_id,id,salary,r FROM ranked WHERE r<=2 ORDER BY department_id,r,id;

-- Q18: Employees earning strictly above their department average.
-- Why: Correlated subquery; compare window alternative.
SELECT e.id,e.name FROM employees e WHERE e.salary>(SELECT AVG(x.salary) FROM employees x WHERE x.department_id=e.department_id) ORDER BY e.id;

-- Q19: Every employee and manager name, including top-level employees.
-- Why: Self LEFT JOIN preserves NULL manager.
SELECT e.id,e.name,m.name AS manager FROM employees e LEFT JOIN employees m ON m.id=e.manager_id ORDER BY e.id;

-- Q20: All direct/indirect reports of employee 1 with depth (direct=1).
-- Why: Seed hierarchy acyclic hai; uncontrolled real graphs need cycle detection.
WITH RECURSIVE reports AS (SELECT id,name,1 AS depth FROM employees WHERE manager_id=1 UNION ALL SELECT e.id,e.name,r.depth+1 FROM employees e JOIN reports r ON e.manager_id=r.id) SELECT * FROM reports ORDER BY depth,id;

-- Q21: Employee count per department, including empty Legal.
-- Why: Empty dimension retained.
SELECT d.id,d.name,COUNT(e.id) AS employees FROM departments d LEFT JOIN employees e ON e.department_id=d.id GROUP BY d.id,d.name ORDER BY d.id;

-- Q22: Orders with both a failed and a successful payment attempt.
-- Why: Multiple attempts allowed; existence condition not raw total.
SELECT order_id FROM payments GROUP BY order_id HAVING BOOL_OR(status='failed') AND BOOL_OR(status='succeeded') ORDER BY order_id;

-- Q23: Paid orders with no successful payment row (reconciliation check).
-- Why: Expected empty on clean fixture; introduce missing payment in transaction to test failure.
SELECT o.id FROM orders o WHERE o.status='paid' AND NOT EXISTS(SELECT 1 FROM payments p WHERE p.order_id=o.id AND p.status='succeeded') ORDER BY o.id;

-- Q24: Compare per-order item total and successful payment total without join fanout.
-- Why: Aggregate child tables separately; raw items × payments join overcounts.
WITH paid AS (SELECT order_id,SUM(amount) AS paid_amount FROM payments WHERE status='succeeded' GROUP BY order_id) SELECT o.id,t.total,COALESCE(p.paid_amount,0) AS paid_amount FROM orders o JOIN order_totals t ON t.order_id=o.id LEFT JOIN paid p ON p.order_id=o.id ORDER BY o.id;

-- Q25: Customer 1 orders with previous order ID and elapsed days.
-- Why: LAG first row NULL; filter before window limits to customer.
SELECT id,LAG(id) OVER w AS previous_id,EXTRACT(EPOCH FROM(created_at-LAG(created_at) OVER w))/86400 AS days_since FROM orders WHERE customer_id=1 WINDOW w AS(ORDER BY created_at,id) ORDER BY created_at,id;

-- Q26: Running paid revenue over time, tie-break by order ID.
-- Why: Explicit ROWS frame avoids peer surprises.
SELECT o.id,SUM(t.total) OVER(ORDER BY o.created_at,o.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE o.status='paid' ORDER BY o.created_at,o.id;

-- Q27: Rank every customer by paid spend within tenant, including zero.
-- Why: Aggregate first, rank second; zero spend preserved.
WITH spend AS(SELECT c.tenant_id,c.id,COALESCE(SUM(t.total),0) AS total FROM customers c LEFT JOIN orders o ON o.customer_id=c.id AND o.status='paid' LEFT JOIN order_totals t ON t.order_id=o.id GROUP BY c.tenant_id,c.id) SELECT *,DENSE_RANK() OVER(PARTITION BY tenant_id ORDER BY total DESC) AS rank FROM spend ORDER BY tenant_id,rank,id;

-- Q28: Paid revenue by product category.
-- Why: Revenue from purchase prices and quantities.
SELECT p.category,SUM(i.quantity*i.unit_price) AS revenue FROM order_items i JOIN products p ON p.id=i.product_id JOIN orders o ON o.id=i.order_id WHERE o.status='paid' GROUP BY p.category ORDER BY p.category;

-- Q29: Products never present in any order, regardless of order status.
-- Why: Different from never sold in paid orders; question scope matters.
SELECT p.id,p.name FROM products p WHERE NOT EXISTS(SELECT 1 FROM order_items i WHERE i.product_id=p.id) ORDER BY p.id;

-- Q30: Paid revenue by tenant.
-- Why: Do not group merely by display name; tenant ID boundary.
SELECT o.tenant_id,SUM(t.total) AS revenue FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE o.status='paid' GROUP BY o.tenant_id ORDER BY o.tenant_id;

-- Q31: Order IDs placed through mobile using JSONB text extraction.
-- Why: -> returns JSONB; ->> text. Match index expression.
SELECT id FROM orders WHERE metadata->>'channel'='mobile' ORDER BY id;

-- Q32: Paid/mobile orders using JSONB containment.
-- Why: Containment can use suitable GIN operator class; tiny table may scan.
SELECT id FROM orders WHERE status='paid' AND metadata @> '{"channel":"mobile"}'::jsonb ORDER BY id;

-- Q33: Duplicate customer display names and their counts (not duplicate accounts).
-- Why: Names are not unique identifiers.
SELECT name,COUNT(*) AS count FROM customers GROUP BY name HAVING COUNT(*)>1 ORDER BY name;

-- Q34: Tenant 1 feed: next 3 rows before cursor Feb 2 10:00 UTC / ID 107, newest first.
-- Why: Composite comparison handles same timestamp 106 correctly.
SELECT id FROM orders WHERE tenant_id=1 AND(created_at,id)<('2026-02-02T10:00:00Z'::timestamptz,107) ORDER BY created_at DESC,id DESC LIMIT 3;

-- Q35: Orders >= 2026-02-01 and < 2026-03-01 UTC.
-- Why: Half-open interval includes fractional end-day times without cast on column.
SELECT id FROM orders WHERE created_at>='2026-02-01T00:00:00Z' AND created_at<'2026-03-01T00:00:00Z' ORDER BY id;

-- Q36: Daily distinct active customers from login events (UTC).
-- Why: Repeated login same day counts once.
SELECT(logged_at AT TIME ZONE 'UTC')::date::text AS day,COUNT(DISTINCT customer_id) AS active FROM login_events GROUP BY 1 ORDER BY 1;

-- Q37: Each customer’s longest streak of consecutive UTC login dates.
-- Why: Deduplicate dates before gaps-and-islands grouping.
WITH days AS(SELECT DISTINCT customer_id,(logged_at AT TIME ZONE 'UTC')::date AS day FROM login_events), grouped AS(SELECT customer_id,day,day-(ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY day))::int AS island FROM days), streaks AS(SELECT customer_id,COUNT(*) AS length FROM grouped GROUP BY customer_id,island) SELECT customer_id,MAX(length) AS longest FROM streaks GROUP BY customer_id ORDER BY customer_id;

-- Q38: Each department’s salary share of total company salary, rounded 2 decimals.
-- Why: Aggregate across groups using window; rounding may not sum exactly 100.
SELECT department_id,ROUND(100.0*SUM(salary)/SUM(SUM(salary)) OVER(),2) AS percent FROM employees GROUP BY department_id ORDER BY department_id;

-- Q39: Customer IDs with any order but no paid orders.
-- Why: Expected empty here; pending-only customer is a useful extra fixture challenge.
SELECT DISTINCT customer_id FROM orders EXCEPT SELECT customer_id FROM orders WHERE status='paid' ORDER BY customer_id;

-- Q40: Compare COUNT(*) vs COUNT(city) and demonstrate NOT IN with NULL.
-- Why: NOT IN(NULL) produces UNKNOWN, so WHERE keeps no rows.
SELECT COUNT(*) AS all_customers,COUNT(city) AS known_city, (SELECT COUNT(*) FROM customers WHERE id NOT IN(SELECT NULL::integer)) AS null_trap_count FROM customers;
