.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE TABLE dl1.sales_dly (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_dly SET PARTITIONED BY (sls_dt);
INSERT INTO dl1.sales_dly VALUES
('2025-01-01', 'North', 200.05),
('2025-01-01', 'South', 150.75),
('2025-03-04', 'North', 153.75),
('2025-03-04', 'South', 120.50);


CREATE TABLE dl1.sales_yr_mth_day (sls_dt date, region_name varchar, sls_amt double);
ALTER TABLE dl1.sales_yr_mth_day SET PARTITIONED BY (year(sls_dt), month(sls_dt), day(sls_dt));
INSERT INTO dl1.sales_yr_mth_day VALUES
    ('2025-01-01', 'North', 200.05),
    ('2025-01-01', 'South', 150.75),
    ('2025-03-04', 'North', 153.75),
    ('2025-03-04', 'South', 120.50);