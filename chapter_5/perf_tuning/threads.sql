.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"


ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

USE dl1;

CREATE TABLE sales_hdr (sls_id int, sls_dt date, region_name varchar, sls_amt double);

INSERT INTO sales_hdr VALUES 
    (1, '2025-01-01', 'North', 200.05),
    (2, '2025-01-02', 'North', 210);

SET threads TO 1;
SELECT * FROM sales_hdr;

SET threads TO 4;
SELECT * FROM sales_hdr;

SELECT approx_count_distinct(region_name) 
FROM sales_hdr;