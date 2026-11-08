# DuckDB 2.0 Quack upgrade notes

The Regional Sales Portal is currently pinned to DuckDB 1.5.6 on both the EC2
server and DuckDB-WASM client. Use this file when retrying the DuckDB 2.0
upgrade after the browser Quack extension issue described in
[`DUCKDB_WASM_2_0_ISSUE.md`](./DUCKDB_WASM_2_0_ISSUE.md) is resolved.

## Current working versions

- Server: DuckDB CLI 1.5.6 GA.
- Browser: `@duckdb/duckdb-wasm@1.33.1-dev65.0`, whose DuckDB submodule is the
  1.5.6 GA commit `069cc9f9b5be802405797faecc284961b07c70ef`.
- Client SQL uses the legacy `remote.query('...')` interface.

## What blocked the DuckDB 2.0 attempt

- The DuckDB 2.0.0 server worked with native DuckDB clients: `CONNECT remote`,
  a query against `dl1.sales_data`, and `DISCONNECT` succeeded.
- The WASM build `@duckdb/duckdb-wasm@1.33.1-dev114.0` embeds DuckDB 2.0.0
  commit `d54cbbe3df17e8e5ce68312f483b4155836112aa`.
- In the browser's default WASM bundle, loading Quack succeeded, but attaching
  to the server failed with `thread constructor failed: Not supported`.
- In an explicitly cross-origin-isolated threads bundle, the published
  `wasm_threads/quack` extension returned HTTP 200 but failed to load into the
  shared-memory runtime.
- The browser therefore never reached a successful Quack attachment, so
  browser-side `CONNECT` / `DISCONNECT`, workbench queries, and CSV uploads
  were not verified.
- See the upstream report and workaround investigation at
  [duckdb/duckdb-wasm#2290](https://github.com/duckdb/duckdb-wasm/issues/2290).

## Reference examples

- `chapter_9/quack/server.sql`: DuckDB 2.0 server-side Quack setup.
- `chapter_9/quack/client.sql`: DuckDB 2.0 client-side `CONNECT` /
  `DISCONNECT` syntax.

## Retry checklist

1. Select a DuckDB-WASM release that embeds the DuckDB 2.0 GA version and has
   compatible Quack and httpfs WASM extensions for the selected runtime.
2. Verify browser startup and `ATTACH 'quack:...' AS remote` in both the
   supported default bundle and any required threaded configuration.
3. Only after attach succeeds, switch `workbench.js`, `csv_upload.js`, and
   `scripts/seed_sales_data.sh` from `remote.query(...)` to `CONNECT remote`,
   plain SQL, and `DISCONNECT`.
4. Pin the verified WASM version in both `app.js` and `csv_upload.js`.
5. Deploy the matching DuckDB server version and test browser query, chart, and
   CSV upload end to end.
