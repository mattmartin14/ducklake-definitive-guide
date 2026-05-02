.shell rm -f -- "encrypted.ducklake"
.shell rm -rf -- "./dwe"

ATTACH 'ducklake:encrypted.ducklake' as dle1 (DATA_PATH './dwe', ENCRYPTED);
INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=1); --250MB version
CREATE TABLE dle1.lineitem
AS
SELECT *
FROM lineitem;

FROM dle1.lineitem
LIMIT 5;

-- get file size
SELECT
    round(size / 1024.0 / 1024.0, 2) AS size_mb
FROM read_blob('./dwe/**/*.parquet')
;
