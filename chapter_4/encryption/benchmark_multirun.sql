ATTACH 'ducklake:non_encrypted.ducklake' as dlne1;
ATTACH 'ducklake:encrypted.ducklake' as dle1;

.timer on

CREATE TEMP TABLE benchmark_results (
    query_name VARCHAR,
    run_number INTEGER,
    elapsed_seconds DOUBLE
);

-- Run 1
PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted_run1.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'non_encrypted', 1, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_non_encrypted_run1.json');

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted_run1.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'encrypted', 1, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_encrypted_run1.json');

-- Run 2
PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted_run2.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'non_encrypted', 2, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_non_encrypted_run2.json');

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted_run2.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'encrypted', 2, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_encrypted_run2.json');

-- Run 3
PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted_run3.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'non_encrypted', 3, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_non_encrypted_run3.json');

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted_run3.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'encrypted', 3, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_encrypted_run3.json');

-- Run 4
PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted_run4.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'non_encrypted', 4, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_non_encrypted_run4.json');

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted_run4.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'encrypted', 4, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_encrypted_run4.json');

-- Run 5
PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_non_encrypted_run5.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'non_encrypted', 5, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_non_encrypted_run5.json');

PRAGMA enable_profiling='json';
PRAGMA profiling_output='/tmp/duckdb_bench_encrypted_run5.json';
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;
PRAGMA disable_profiling;
INSERT INTO benchmark_results
SELECT 'encrypted', 5, latency::DOUBLE FROM read_json_auto('/tmp/duckdb_bench_encrypted_run5.json');

.print '--- Per-Run Timings (seconds) ---'
SELECT query_name, run_number, ROUND(elapsed_seconds, 6) AS elapsed_seconds
FROM benchmark_results
ORDER BY query_name, run_number;

.print '--- Average Runtime By Query (seconds) ---'
SELECT
    query_name,
    COUNT(*) AS runs,
    ROUND(AVG(elapsed_seconds), 6) AS avg_elapsed_seconds,
    ROUND(MIN(elapsed_seconds), 6) AS min_elapsed_seconds,
    ROUND(MAX(elapsed_seconds), 6) AS max_elapsed_seconds
FROM benchmark_results
GROUP BY query_name
ORDER BY query_name;
