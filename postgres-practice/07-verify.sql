-- Read-only fixture checks. Run before changing base data in experiments.
SET search_path = interview_lab, public;
DO $$
BEGIN
 IF (SELECT COUNT(*) FROM customers)<>8 THEN RAISE EXCEPTION 'customers expected 8'; END IF;
 IF (SELECT COUNT(*) FROM orders)<>12 THEN RAISE EXCEPTION 'orders expected 12'; END IF;
 IF (SELECT COUNT(*) FROM order_items)<>15 THEN RAISE EXCEPTION 'order_items expected 15'; END IF;
 IF (SELECT COUNT(*) FROM payments)<>10 THEN RAISE EXCEPTION 'payments expected 10'; END IF;
 IF (SELECT COUNT(*) FROM employees)<>8 THEN RAISE EXCEPTION 'employees expected 8'; END IF;
 IF (SELECT SUM(t.total) FROM orders o JOIN order_totals t ON t.order_id=o.id WHERE status='paid')<>18300 THEN RAISE EXCEPTION 'paid revenue expected 18300'; END IF;
 IF (SELECT COUNT(*) FROM customers c WHERE NOT EXISTS(SELECT 1 FROM orders o WHERE o.customer_id=c.id))<>2 THEN RAISE EXCEPTION 'no-order customers expected 2'; END IF;
 IF (SELECT COUNT(DISTINCT salary) FROM employees)<>6 THEN RAISE EXCEPTION 'distinct salaries expected 6'; END IF;
 RAISE NOTICE 'Fixture verified: 8 customers, 12 orders, paid revenue 18300.';
END $$;
