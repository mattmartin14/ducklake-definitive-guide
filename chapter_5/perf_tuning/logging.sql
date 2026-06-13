.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
.shell rm -rf -- "./query_logs"
.shell mkdir -p "./query_logs"

-- Enable query profiling in JSON mode (output file is set per-query below)
PRAGMA enable_profiling = 'json';

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

USE dl1;

CREATE TABLE sales_hdr (sls_id int, sls_dt date, region_name varchar, sls_amt double);

INSERT INTO sales_hdr VALUES (1, '2025-01-01', 'North', 200.05);
INSERT INTO sales_hdr VALUES (2, '2025-01-02', 'North', 210);

CREATE TABLE sales_dtl (sls_id int, item_id int, qty int);
INSERT INTO sales_dtl VALUES (1, 101, 2);
INSERT INTO sales_dtl VALUES (1, 102, 1);
INSERT INTO sales_dtl VALUES (2, 101, 1);
INSERT INTO sales_dtl VALUES (2, 103, 3);


-- Query 1: full scan
PRAGMA profiling_output = './query_logs/q1_full_scan.json';
SELECT * FROM sales_hdr;

-- Query 2: filtered scan
PRAGMA profiling_output = './query_logs/q2_filtered_join_scan.json';
SELECT hdr.sls_dt, sum(dtl.qty) as total_qty
FROM sales_hdr as hdr
    INNER JOIN sales_dtl as dtl
        ON hdr.sls_id = dtl.sls_id
WHERE hdr.sls_amt > 205
GROUP BY hdr.sls_dt;