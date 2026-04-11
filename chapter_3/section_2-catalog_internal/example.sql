-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "$HOME/dw3"

ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH '~/dw3');

CREATE OR REPLACE TABLE my_ducklake.orders
AS
SELECT 1 as order_id, '2024-01-01' as order_date, 100.0 as amount
;