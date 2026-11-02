# Task 5 -- Query Index Tuning, Execution Plans & ACID Transactions

## 1. Objective

This task demonstrates PostgreSQL query-plan inspection, index creation,
statistics collection, and transaction control using an `inventory`
table.

## 2. Indexes

The following indexes were used:

  ------------------------------------------------------------------------------------
  Index                               Definition               Purpose
  ----------------------------------- ------------------------ -----------------------
  `inventory_pkey`                    Primary-key index on     Enforces unique product
                                      `product_id`             IDs and supports
                                                               lookups by product ID

  `idx_inventory_warehouse`           B-tree on `warehouse_id` Supports
                                                               warehouse-based
                                                               filtering

  `idx_inventory_category_quantity`   Composite index on       Supports filtering by
                                      `(category, quantity)`   category and quantity

  `idx_inventory_low_stock`           Partial index on         Supports low-stock
                                      `updated_at` where       queries ordered by
                                      `status = 'LOW'`         update time
  ------------------------------------------------------------------------------------

The `idx_inventory_category` index was also visible in the database
index listing.

### SQL used

``` sql
CREATE INDEX IF NOT EXISTS idx_inventory_warehouse
ON inventory USING BTREE (warehouse_id);

CREATE INDEX IF NOT EXISTS idx_inventory_category_quantity
ON inventory (category, quantity);

CREATE INDEX IF NOT EXISTS idx_inventory_low_stock
ON inventory (updated_at)
WHERE status = 'LOW';

ANALYZE inventory;
```

`ANALYZE` updates table statistics used by PostgreSQL's query planner.

## 3. Query execution plans

The following queries were tested with `EXPLAIN ANALYZE`:

### Warehouse filter

``` sql
EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE warehouse_id = 777;
```

The execution-plan screenshot showed an index-based access path for the
warehouse filter.

### Composite-index filter

``` sql
EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE category = 'Books'
  AND quantity < 20;
```

The execution-plan screenshot showed a bitmap index access path for this
filter.

### Partial-index query

``` sql
EXPLAIN ANALYZE
SELECT *
FROM inventory
WHERE status = 'LOW'
ORDER BY updated_at DESC
LIMIT 20;
```

The captured plan showed `Index Scan Backward` using
`idx_inventory_low_stock`. The screenshot reported an execution time of
**0.131 ms** for that run.

### Before-and-after comparison note

The indexes had already been created before the captured query-plan
tests. Therefore, the screenshots establish the post-index query plans,
but they do not provide a reliable measured before-and-after timing
comparison.

For a valid comparison, capture a baseline before creating indexes (or
use a controlled test copy of the table), then capture the indexed plan
under the same conditions. Do not treat `SET enable_indexscan = OFF` and
`SET enable_bitmapscan = OFF` as a perfect historical before-index
measurement: those settings only discourage those plan types for the
current session and do not remove indexes.

PostgreSQL may still choose a sequential scan when its cost estimate
indicates that it is cheaper. This is expected and does not necessarily
indicate a problem.

## 4. ACID transaction demonstrations

### COMMIT

A transaction updated product 2 by reducing its quantity by one and
committed the change.

``` sql
BEGIN;

UPDATE inventory
SET quantity = quantity - 1
WHERE product_id = 2;

SELECT product_id, quantity
FROM inventory
WHERE product_id = 2;

COMMIT;
```

### ROLLBACK

A temporary update to product 3 was cancelled.

``` sql
BEGIN;

UPDATE inventory
SET quantity = quantity + 50
WHERE product_id = 3;

SELECT product_id, quantity
FROM inventory
WHERE product_id = 3;

ROLLBACK;
```

### SAVEPOINT

The update to product 3 was retained, while the later update to product
4 was rolled back to the savepoint.

``` sql
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
```

### SERIALIZABLE isolation

A read-only transaction was run using the SERIALIZABLE isolation level.

``` sql
BEGIN TRANSACTION;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT *
FROM inventory
WHERE warehouse_id = 777;

COMMIT;
```

## 5. ACID properties demonstrated

  -----------------------------------------------------------------------
  Property                            Demonstration
  ----------------------------------- -----------------------------------
  Atomicity                           `ROLLBACK` cancels the
                                      transaction's uncommitted update

  Consistency                         Updates are subject to the table's
                                      constraints; valid committed states
                                      are preserved

  Isolation                           `SERIALIZABLE` isolation level was
                                      selected

  Durability                          `COMMIT` saves the transaction's
                                      changes
  -----------------------------------------------------------------------

## 6. Evidence and remaining verification

Attach the pgAdmin screenshots showing: - The index listing and
partial-index definition. - `ANALYZE inventory` execution. - The three
`EXPLAIN ANALYZE` outputs. - The committed update and its
verification. - The rolled-back update and its verification. - The
savepoint result. - The SERIALIZABLE transaction.

Before final submission, verify the row count with:

``` sql
SELECT COUNT(*) AS total_records
FROM inventory;
```

Record the actual result in the report. The screenshots available in
this work do not establish the final row count, so no total is claimed
here.

Also verify the partial index exists:

``` sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'inventory'
ORDER BY indexname;
```

## 7. Conclusion

The task demonstrates PostgreSQL indexing, query-plan inspection,
statistics collection, and transaction operations including `COMMIT`,
`ROLLBACK`, `SAVEPOINT`, and `SERIALIZABLE` isolation. The recorded
query plans show index-based access for the tested warehouse,
category/quantity, and low-stock queries. A measured before-and-after
performance comparison and final row count should only be reported after
collecting those values under controlled conditions.
