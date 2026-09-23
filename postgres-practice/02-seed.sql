-- Fixed dates and amounts: outputs do not change with today's date.
-- Run after 01-schema.sql, once. Entire seed is atomic; repeated IDs fail safely.
BEGIN;
SET LOCAL search_path = interview_lab, public;
INSERT INTO tenants VALUES (1,'Alpha'), (2,'Beta');
INSERT INTO customers VALUES
 (1,1,'Asha','asha@example.test','Delhi','2025-12-01T00:00:00Z'),
 (2,1,'Ravi','ravi@example.test','Mumbai','2025-12-02T00:00:00Z'),
 (3,1,'Neha','neha@example.test','Delhi','2025-12-03T00:00:00Z'),
 (4,1,'Kabir','kabir@example.test',NULL,'2025-12-04T00:00:00Z'),
 (5,1,'Asha','asha2@example.test','Pune','2025-12-05T00:00:00Z'),
 (6,2,'Meera','meera@example.test','Bengaluru','2025-12-01T00:00:00Z'),
 (7,2,'Omar','omar@example.test','Delhi','2025-12-02T00:00:00Z'),
 (8,2,'Zoya','zoya@example.test',NULL,'2025-12-03T00:00:00Z');
INSERT INTO products VALUES
 (1,'Keyboard','Tech',1000),(2,'Mouse','Tech',500),
 (3,'Book','Books',300),(4,'Monitor','Tech',10000),
 (5,'Mug','Home',200),(6,'Notebook','Books',100);
INSERT INTO orders VALUES
 (101,1,1,'paid','2026-01-01T10:00:00Z','{"channel":"web"}'),
 (102,1,1,'paid','2026-01-03T10:00:00Z','{"channel":"mobile"}'),
 (103,1,2,'paid','2026-01-03T10:00:00Z','{"channel":"web"}'),
 (104,1,2,'cancelled','2026-01-05T10:00:00Z','{"channel":"web"}'),
 (105,1,3,'paid','2026-02-01T10:00:00Z','{"channel":"mobile"}'),
 (106,1,3,'pending','2026-02-02T10:00:00Z','{"channel":"web"}'),
 (107,1,4,'paid','2026-02-02T10:00:00Z','{"channel":"web"}'),
 (108,1,1,'refunded','2026-02-03T10:00:00Z','{"channel":"mobile"}'),
 (109,2,6,'paid','2026-02-01T10:00:00Z','{"channel":"web"}'),
 (110,2,6,'paid','2026-03-01T10:00:00Z','{"channel":"mobile"}'),
 (111,2,7,'pending','2026-03-01T10:00:00Z','{"channel":"web"}'),
 (112,2,7,'paid','2026-03-03T10:00:00Z','{"channel":"web"}');
INSERT INTO order_items VALUES
 (101,1,1,1000),(101,2,2,500),(102,3,2,300),(103,1,1,1000),
 (104,4,1,10000),(105,2,1,500),(105,5,1,200),(106,3,1,300),
 (107,5,3,200),(108,4,1,10000),(109,4,1,10000),(109,2,1,500),
 (110,1,2,1000),(111,3,1,300),(112,3,3,300);
INSERT INTO payments VALUES
 (1,101,'pay-101','succeeded',2000,'2026-01-01T10:01:00Z'),
 (2,102,'pay-102','succeeded',600,'2026-01-03T10:01:00Z'),
 (3,103,'pay-103-fail','failed',1000,'2026-01-03T10:01:00Z'),
 (4,103,'pay-103-ok','succeeded',1000,'2026-01-03T10:02:00Z'),
 (5,105,'pay-105','succeeded',700,'2026-02-01T10:01:00Z'),
 (6,107,'pay-107','succeeded',600,'2026-02-02T10:01:00Z'),
 (7,108,'pay-108','refunded',10000,'2026-02-04T10:01:00Z'),
 (8,109,'pay-109','succeeded',10500,'2026-02-01T10:01:00Z'),
 (9,110,'pay-110','succeeded',2000,'2026-03-01T10:01:00Z'),
 (10,112,'pay-112','succeeded',900,'2026-03-03T10:01:00Z');
INSERT INTO departments VALUES (1,'Engineering'),(2,'Sales'),(3,'Support'),(4,'Legal');
INSERT INTO employees VALUES
 (1,'Anita',1,NULL,150000,'2022-01-01'),
 (2,'Dev',1,1,100000,'2023-01-01'),
 (3,'Isha',1,1,100000,'2023-02-01'),
 (4,'Karan',1,2,70000,'2024-01-01'),
 (5,'Lata',2,NULL,120000,'2022-02-01'),
 (6,'Manav',2,5,80000,'2024-02-01'),
 (7,'Naina',3,NULL,60000,'2023-03-01'),
 (8,'Pawan',3,7,60000,'2024-03-01');
INSERT INTO login_events VALUES
 (1,1,'2026-03-01T08:00:00Z'),(2,1,'2026-03-01T09:00:00Z'),
 (3,1,'2026-03-02T08:00:00Z'),(4,1,'2026-03-03T08:00:00Z'),
 (5,1,'2026-03-05T08:00:00Z'),(6,2,'2026-03-01T08:00:00Z'),
 (7,2,'2026-03-03T08:00:00Z'),(8,2,'2026-03-04T08:00:00Z'),
 (9,6,'2026-03-02T08:00:00Z');
INSERT INTO inventory VALUES (1,10,1),(2,20,1),(3,30,1),(4,1,1),(5,5,1),(6,50,1);
COMMIT;
