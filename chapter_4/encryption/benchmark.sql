ATTACH 'ducklake:non_encrypted.ducklake' as dlne1;
ATTACH 'ducklake:encrypted.ducklake' as dle1;

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;

.print '--- Benchmark Results (seconds) ---'
SELECT 'non_encrypted' AS query_name, ROUND(latency::DOUBLE, 6) AS elapsed_seconds FROM read_json_auto('/tmp/duckdb_bench_non_encrypted.json')
UNION ALL
SELECT 'encrypted' AS query_name, ROUND(latency::DOUBLE, 6) AS elapsed_seconds FROM read_json_auto('/tmp/duckdb_bench_encrypted.json')
ORDER BY query_name;