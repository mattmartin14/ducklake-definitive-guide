.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE TABLE dl1.orders (order_id integer, customer_id integer, order_date date);
INSERT INTO dl1.orders (order_id, customer_id, order_date)
VALUES (1, 100, '2024-01-01'), (2, 101, '2024-01-02'), (3, 102, '2024-01-03');

UPDATE dl1.orders SET order_date = '2024-01-10' WHERE order_id = 2;

DELETE FROM dl1.orders WHERE order_id = 3;
DELETE FROM dl1.orders WHERE order_id = 1; 

INSERT INTO dl1.orders (order_id, customer_id, order_date)
VALUES (4, 103, '2024-01-04'), (5, 104, '2024-01-05');

CREATE TABLE dl1.order_lineitem (lineitem_id integer, order_id integer, product_id integer, quantity integer);
INSERT INTO dl1.order_lineitem (lineitem_id, order_id, product_id, quantity)
VALUES (1, 1, 1000, 2), (2, 1, 1001, 1), (3, 2, 1000, 3), (4, 2, 1002, 5), (5, 3, 1001, 2);

UPDATE dl1.order_lineitem SET quantity = 4 WHERE lineitem_id = 2;

DELETE FROM dl1.order_lineitem WHERE lineitem_id = 3;
DELETE FROM dl1.order_lineitem WHERE lineitem_id = 1;

INSERT INTO dl1.order_lineitem (lineitem_id, order_id, product_id, quantity)
VALUES (6, 4, 1003, 1), (7, 5, 1004, 2);

CREATE SCHEMA dl1.order_summary;
create table dl1.order_summary.summary as
select o.order_id, o.customer_id, o.order_date, sum(l.quantity) as total_quantity
from dl1.orders o
join dl1.order_lineitem l on o.order_id = l.order_id
group by o.order_id, o.customer_id, o.order_date;

-- Disable compaction on the order_summary schema
CALL ducklake_set_option('dl1', 'auto_compact', false, schema => 'order_summary');

-- <1MB files into 5MB files
CALL ducklake_set_option('dl1', 'target_file_size', '5MB');
CALL ducklake_merge_adjacent_files('dl1', 'orders', schema => 'main', max_file_size => 1048576);

-- 1MB - 10MB files collapsed into 32MB files
CALL ducklake_set_option('dl1', 'target_file_size', '32MB');
CALL ducklake_merge_adjacent_files('dl1', 'order_lineitem', schema => 'main', min_file_size => 1048576, max_file_size => 10485760);

-- compact all tables in the order_summary schema into 10MB files
CALL ducklake_set_option('dl1', 'auto_compact', false, schema => 'main');
CALL ducklake_set_option('dl1', 'auto_compact', true, schema => 'order_summary');
CALL ducklake_set_option('dl1', 'target_file_size', '10MB');
CALL ducklake_merge_adjacent_files('dl1');
