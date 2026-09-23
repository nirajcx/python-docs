-- PostgreSQL 15+; run in the training DB after schema/seed.
-- Uses a separate table: does not change the 40-exercise dataset.
-- Run sections individually to inspect each plan. One-time table creation.
SET search_path = interview_lab, public;
SET TIME ZONE 'UTC';
CREATE TABLE order_events (
    id bigint PRIMARY KEY,
    tenant_id integer NOT NULL,
    customer_id integer NOT NULL,
    status text NOT NULL,
    created_at timestamptz NOT NULL,
    amount numeric(12,2) NOT NULL,
    email text NOT NULL,
    metadata jsonb NOT NULL
);
INSERT INTO order_events
SELECT g, (g % 10)::integer + 1, (g % 1000)::integer + 1,
       CASE WHEN g % 100 = 0 THEN 'pending' ELSE 'paid' END,
       '2026-01-01T00:00:00Z'::timestamptz + g * interval '1 minute',
       ((g % 500) + 1)::numeric(12,2),
       'User' || g || '@example.test',
       jsonb_build_object('channel', CASE WHEN g % 5 = 0 THEN 'mobile' ELSE 'web' END)
FROM generate_series(1,100000) AS g;
ANALYZE order_events;

-- A. Baseline (only PK exists). Expected 20 returned, not a fixed duration.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id,created_at,amount FROM order_events
WHERE customer_id=42 ORDER BY created_at DESC,id DESC LIMIT 20;

-- B. Composite matching filter/order.
CREATE INDEX order_events_customer_feed_idx
ON order_events(customer_id,created_at DESC,id DESC);
ANALYZE order_events;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id,created_at,amount FROM order_events
WHERE customer_id=42 ORDER BY created_at DESC,id DESC LIMIT 20;

-- C. Covering index. Heap Fetches depend on visibility map, not just INCLUDE.
CREATE INDEX order_events_customer_cover_idx
ON order_events(customer_id,created_at DESC,id DESC) INCLUDE(amount);
-- Run VACUUM outside a transaction; some GUI tools wrap scripts automatically.
VACUUM (ANALYZE) order_events;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id,created_at,amount FROM order_events
WHERE customer_id=42 ORDER BY created_at DESC,id DESC LIMIT 20;
-- Two similar indexes here are for comparison, not a recommendation to keep both.

-- D. Partial index: 1,000 pending rows out of 100,000.
CREATE INDEX order_events_pending_idx ON order_events(created_at,id)
WHERE status='pending';
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM order_events WHERE status='pending'
ORDER BY created_at,id LIMIT 20;

-- E. Expression index.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM order_events WHERE lower(email)='user12345@example.test';
CREATE INDEX order_events_lower_email_idx ON order_events(lower(email));
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM order_events WHERE lower(email)='user12345@example.test';

-- F. GIN containment: matching index doesn't force planner to use it.
CREATE INDEX order_events_metadata_idx ON order_events USING gin(metadata);
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM order_events WHERE metadata @> '{"channel":"mobile"}';

-- G. BRIN: timestamps physically correlated with insert order.
CREATE INDEX order_events_created_brin_idx ON order_events USING brin(created_at);
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM order_events
WHERE created_at>='2026-03-10T00:00:00Z' AND created_at<'2026-03-11T00:00:00Z';

-- H. Low-selectivity query: sequential scan may be correct.
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(amount) FROM order_events WHERE status='paid';

-- I. Offset vs cursor: compare equivalent page from same stable dataset.
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM order_events ORDER BY id LIMIT 20 OFFSET 90000;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM order_events WHERE id>90000 ORDER BY id LIMIT 20;

-- J. Inspect storage, don't infer exact memory savings from row counts.
SELECT indexname,indexdef FROM pg_indexes
WHERE schemaname='interview_lab' AND tablename='order_events'
ORDER BY indexname;
SELECT pg_size_pretty(pg_relation_size('order_events')) AS heap_size,
       pg_size_pretty(pg_indexes_size('order_events')) AS index_size;
-- Record scan type, estimated/actual rows, buffers, sort, heap fetches, timing.
-- Warm-cache repeats are not the same experiment as cold-cache runs.
