.shell rm -f -- "non_encrypted.ducklake"
.shell rm -rf -- "./dwne"

ATTACH 'ducklake:non_encrypted.ducklake' as dlne1 (DATA_PATH './dwne');
INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=1); --250MB version
CREATE TABLE dlne1.lineitem
AS
SELECT *
FROM lineitem;

FROM dlne1.lineitem
LIMIT 5;

-- get file size
SELECT
    round(size / 1024.0 / 1024.0, 2) AS size_mb
FROM read_blob('./dwne/**/*.parquet')