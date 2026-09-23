# PostgreSQL query practice — 40 exercises

[Setup](README.md) · [Solutions](04-solutions.sql) · [Expected output](EXPECTED-RESULTS.md)

Run `SET search_path = interview_lab, public; SET TIME ZONE 'UTC';` in your query tab. Har query deterministic ORDER BY use kare. Paid revenue means orders.status = paid, calculated from purchase line items; refunded orders excluded.

## Q01. Products with price >= 500, descending price; ties by ID.

Apni query likho; result and edge cases explain karo.

## Q02. Customers whose city is missing.

Apni query likho; result and edge cases explain karo.

## Q03. Distinct known cities in alphabetical order.

Apni query likho; result and edge cases explain karo.

## Q04. Order count by status.

Apni query likho; result and edge cases explain karo.

## Q05. Every customer and total order count, including zero.

Apni query likho; result and edge cases explain karo.

## Q06. Every customer and paid order count, including zero.

Apni query likho; result and edge cases explain karo.

## Q07. Customers who have never ordered.

Apni query likho; result and edge cases explain karo.

## Q08. Compute total for every order using quantity and purchase unit_price.

Apni query likho; result and edge cases explain karo.

## Q09. Total paid revenue across all tenants; refunded/pending/cancelled exclude.

Apni query likho; result and edge cases explain karo.

## Q10. Paid spend per customer, including zero, ordered by customer ID.

Apni query likho; result and edge cases explain karo.

## Q11. Customers with at least two paid orders.

Apni query likho; result and edge cases explain karo.

## Q12. Paid monthly revenue, using UTC month, Jan–Mar 2026.

Apni query likho; result and edge cases explain karo.

## Q13. Daily paid revenue Jan 1–5 UTC, including days with no orders.

Apni query likho; result and edge cases explain karo.

## Q14. Latest order per customer; timestamp ties resolved by higher order ID.

Apni query likho; result and edge cases explain karo.

## Q15. Latest paid order per customer using PostgreSQL DISTINCT ON.

Apni query likho; result and edge cases explain karo.

## Q16. All employees at the second-highest distinct salary company-wide.

Apni query likho; result and edge cases explain karo.

## Q17. Employees in top two distinct salary levels of each department, include ties.

Apni query likho; result and edge cases explain karo.

## Q18. Employees earning strictly above their department average.

Apni query likho; result and edge cases explain karo.

## Q19. Every employee and manager name, including top-level employees.

Apni query likho; result and edge cases explain karo.

## Q20. All direct/indirect reports of employee 1 with depth (direct=1).

Apni query likho; result and edge cases explain karo.

## Q21. Employee count per department, including empty Legal.

Apni query likho; result and edge cases explain karo.

## Q22. Orders with both a failed and a successful payment attempt.

Apni query likho; result and edge cases explain karo.

## Q23. Paid orders with no successful payment row (reconciliation check).

Apni query likho; result and edge cases explain karo.

## Q24. Compare per-order item total and successful payment total without join fanout.

Apni query likho; result and edge cases explain karo.

## Q25. Customer 1 orders with previous order ID and elapsed days.

Apni query likho; result and edge cases explain karo.

## Q26. Running paid revenue over time, tie-break by order ID.

Apni query likho; result and edge cases explain karo.

## Q27. Rank every customer by paid spend within tenant, including zero.

Apni query likho; result and edge cases explain karo.

## Q28. Paid revenue by product category.

Apni query likho; result and edge cases explain karo.

## Q29. Products never present in any order, regardless of order status.

Apni query likho; result and edge cases explain karo.

## Q30. Paid revenue by tenant.

Apni query likho; result and edge cases explain karo.

## Q31. Order IDs placed through mobile using JSONB text extraction.

Apni query likho; result and edge cases explain karo.

## Q32. Paid/mobile orders using JSONB containment.

Apni query likho; result and edge cases explain karo.

## Q33. Duplicate customer display names and their counts (not duplicate accounts).

Apni query likho; result and edge cases explain karo.

## Q34. Tenant 1 feed: next 3 rows before cursor Feb 2 10:00 UTC / ID 107, newest first.

Apni query likho; result and edge cases explain karo.

## Q35. Orders >= 2026-02-01 and < 2026-03-01 UTC.

Apni query likho; result and edge cases explain karo.

## Q36. Daily distinct active customers from login events (UTC).

Apni query likho; result and edge cases explain karo.

## Q37. Each customer’s longest streak of consecutive UTC login dates.

Apni query likho; result and edge cases explain karo.

## Q38. Each department’s salary share of total company salary, rounded 2 decimals.

Apni query likho; result and edge cases explain karo.

## Q39. Customer IDs with any order but no paid orders.

Apni query likho; result and edge cases explain karo.

## Q40. Compare COUNT(*) vs COUNT(city) and demonstrate NOT IN with NULL.

Apni query likho; result and edge cases explain karo.

## Extra mutation drills (transaction + rollback)

M1: product 4 reserve using atomic conditional update; second reservation fails. M2: employee update then rollback. M3: duplicate webhook event insert with ON CONFLICT, side effect only first time. M4: savepoint rollback after bad constraint. M5: optimistic version conflict. Full steps [concurrency labs](06-concurrency-labs.md) mein hain.
