-- clean up from previous runs
.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

CREATE OR REPLACE TABLE dl1.orders (order_id INTEGER, order_date DATE, amount decimal(10, 2));

INSERT INTO dl1.orders (order_id, order_date, amount)
VALUES 
    (1, '2024-01-01', 100.05),
    (2, '2024-01-02', 150.00),
    (3, '2024-01-03', 200.25)
;

FROM dl1.snapshots();

USE __ducklake_metadata_dl1;

SELECT *
FROM ducklake_snapshot as s