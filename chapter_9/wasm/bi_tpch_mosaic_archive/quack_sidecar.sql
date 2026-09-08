-- Server-side script for the local Quack sidecar.
--
-- This is a native DuckDB process (run via the `duckdb` CLI) that opens the
-- DuckLake catalog file (data/tpch_catalog.ducklake) directly as its primary
-- database and exposes it over the Quack remote protocol. Quack serves
-- whatever the current session can see, so the browser (DuckDB-WASM) can
-- attach with `ATTACH 'ducklake:quack:host:port' AS tpch_lake (...)` and find
-- the existing TPC-H schema/tables already there. The actual Parquet bytes
-- are fetched by the browser directly over HTTP(S) (see DATA_PATH on the
-- client-side ATTACH), never routed through Quack.
--
-- Run once via ./start_quack_sidecar.sh, which keeps this process alive and
-- opens the catalog file as the positional database (not `:memory:`).

LOAD ducklake;
LOAD quack;

SET VARIABLE quack_demo_token = coalesce(nullif(getenv('QUACK_TOKEN'), ''), 'ducklake-demo-token');

CALL quack_serve('quack:127.0.0.1:9494', token => getvariable('quack_demo_token'));

SELECT 'Quack sidecar serving tpch_catalog.ducklake on quack:127.0.0.1:9494' AS status;
