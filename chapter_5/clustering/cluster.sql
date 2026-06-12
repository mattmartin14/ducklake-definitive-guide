.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE TABLE dl1.sales_dly (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_dly SET SORTED BY (sls_dt ASC);

INSERT INTO dl1.sales_dly VALUES
('2025-01-01', 'North', 200.05),
('2025-01-01', 'South', 150.75),
('2025-03-04', 'North', 153.75),
('2025-03-04', 'South', 120.50);

CREATE TABLE dl1.sales_dly_region_name (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_dly_region_name SET SORTED BY (sls_dt ASC, region_name ASC);
INSERT INTO dl1.sales_dly_region_name VALUES
('2025-01-01', 'North', 200.05),
('2025-01-01', 'South', 150.75),
('2025-03-04', 'North', 153.75),
('2025-03-04', 'South', 120.50);


CREATE TABLE dl1.sales_dly_cust_sort (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_dly_cust_sort SET SORTED BY (substring(region_name,1,4) DESC);

CREATE TABLE dl1.sales_hourly (sls_ts timestamp, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_hourly SET SORTED BY (date(sls_ts) ASC);
INSERT INTO dl1.sales_hourly VALUES
('2025-01-01 08:00:00', 'North', 200.05),
('2025-01-01 08:00:00', 'South', 150.75),
('2025-03-04 14:30:00', 'North', 153.75),
('2025-03-04 14:30:00', 'South', 120.50);

-- partition and cluster
CREATE TABLE dl1.sales_dly_region_name_cluster (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_dly_region_name_cluster SET PARTITIONED BY (sls_dt);
ALTER TABLE dl1.sales_dly_region_name_cluster SET SORTED BY (region_name ASC);
INSERT INTO dl1.sales_dly_region_name_cluster VALUES
('2025-01-01', 'North', 200.05),
('2025-01-01', 'South', 150.75),
('2025-03-04', 'North', 153.75),
('2025-03-04', 'South', 120.50);

SELECT *
FROM dl1.sales_dly_region_name_cluster
WHERE sls_dt = '2025-01-01'
    AND region_name = 'North';

USE __ducklake_metadata_dl1;

SELECT *
FROM ducklake_sort_expression;