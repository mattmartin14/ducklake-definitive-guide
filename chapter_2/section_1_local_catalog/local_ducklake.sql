.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw');

CREATE TABLE my_ducklake.orders
AS
SELECT 1 as order_id, DATE '2024-01-01' AS order_date, 100.0 AS amount
UNION ALL
SELECT 2, DATE '2024-03-04', 150
;

select * from my_ducklake.orders;