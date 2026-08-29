.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

-- snapshot 1
CREATE SCHEMA dl1.sales;

-- snapshot 2
CREATE TABLE dl1.sales.orders (order_id int, order_dt date, sales_amt float, order_status varchar(1));

-- snapshot 3
INSERT INTO dl1.sales.orders
VALUES (1, '2024-06-01', 100.0, NULL),
       (2, '2024-06-02', 200.0, NULL),
       (3, '2024-06-03', 300.0, NULL)
;
-- snapshot 4
UPDATE dl1.sales.orders
SET order_status = 'F'
WHERE order_id = 2;

-- snapshot 5
DELETE FROM dl1.sales.orders
WHERE order_id = 3;

-- get latest snapshot
SET VARIABLE _current_snapshot_id = cast((SELECT id FROM dl1.current_snapshot()) as int); 

-- review changes
FROM dl1.sales.table_changes('orders', 4, getvariable('_current_snapshot_id'));
