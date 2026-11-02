-- Task 5: Query Index Tuning, Execution Plans & ACID Transactions
-- Run in pgAdmin Query Tool against the database containing public.inventory.
-- Review the table/schema and existing data before executing UPDATE statements.

-- 1. Verify the data volume
SELECT COUNT(*) AS total_records
FROM inventory;

-- 2. Review existing indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'inventory'
ORDER BY indexname;

-- 3. Create required indexes (safe to rerun)
CREATE INDEX IF NOT EXISTS idx_inventory_warehouse
ON inventory USING BTREE (warehouse_id);

CREATE INDEX IF NOT EXISTS idx_inventory_category_quantity
ON inventory (category, quantity);

CREATE INDEX IF NOT EXISTS idx_inventory_low_stock
ON inventory (updated_at)
WHERE status = 'LOW';

-- Refresh planner statistics
ANALYZE inventory;

-- 4. Query execution plans
EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE warehouse_id = 777;

EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE category = 'Books'
  AND quantity < 20;

EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE status = 'LOW'
ORDER BY updated_at DESC
LIMIT 20;

-- 5. COMMIT demonstration
BEGIN;

UPDATE inventory
SET quantity = quantity - 1
WHERE product_id = 2;

SELECT product_id, quantity
FROM inventory
WHERE product_id = 2;

COMMIT;

-- 6. ROLLBACK demonstration
BEGIN;

UPDATE inventory
SET quantity = quantity + 50
WHERE product_id = 3;

SELECT product_id, quantity
FROM inventory
WHERE product_id = 3;

ROLLBACK;

-- Verify that product 3's quantity returned to its pre-transaction value
SELECT product_id, quantity
FROM inventory
WHERE product_id = 3;

-- 7. SAVEPOINT demonstration
BEGIN;

UPDATE inventory
SET quantity = quantity + 5
WHERE product_id = 3;

SAVEPOINT sp1;

UPDATE inventory
SET quantity = quantity + 20
WHERE product_id = 4;

ROLLBACK TO SAVEPOINT sp1;

COMMIT;

-- Verify savepoint outcome
SELECT product_id, quantity
FROM inventory
WHERE product_id IN (3, 4)
ORDER BY product_id;

-- 8. SERIALIZABLE isolation demonstration
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT *
FROM inventory
WHERE warehouse_id = 777;

COMMIT;
