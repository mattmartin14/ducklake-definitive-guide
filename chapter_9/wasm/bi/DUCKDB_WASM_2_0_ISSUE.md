# DuckDB-WASM 2.0 Quack compatibility issue report

Filed as [duckdb/duckdb-wasm#2305](https://github.com/duckdb/duckdb-wasm/issues/2305).

## Summary

DuckDB-WASM 2.0.0 can load the published Quack extension in its default
single-threaded browser bundle, but attaching to a Quack server fails with
`thread constructor failed: Not supported`. Switching to the threaded
`wasm_threads` bundle avoids that error but the published Quack extension fails
to load into the shared-memory runtime. As a result, browser Quack clients
cannot attach to a DuckDB 2.0 Quack server with the tested official artifacts.

This report is based on a minimal DuckDB-WASM test page querying a Quack server
backed by a DuckLake table seeded with dummy data. It is related to
[duckdb/duckdb-wasm#2290](https://github.com/duckdb/duckdb-wasm/issues/2290),
which reports the DuckDB 2.0 version issue and subsequent threaded-extension
investigation.

## Environment

- DuckDB server: DuckDB CLI `v2.0.0 (Cyanoptera)`, commit
  `d54cbbe3df17e8e5ce68312f483b4155836112aa`.
- DuckDB-WASM npm package: `@duckdb/duckdb-wasm@1.33.1-dev114.0`.
- The package's DuckDB submodule is the same DuckDB 2.0.0 commit listed above.
- Quack extension URL for the threaded runtime:
  `https://extensions.duckdb.org/v2.0.0/wasm_threads/quack.duckdb_extension.wasm`.
- Browser used a same-origin local HTTP server and SSH tunnel to reach the
  Quack endpoint. The test page's COOP/COEP headers were also enabled for the
  threaded-runtime test.

## Reproduction

1. Start a DuckDB 2.0.0 server with DuckLake attached and Quack listening with
   token authentication.
2. In a browser, load `@duckdb/duckdb-wasm@1.33.1-dev114.0`, instantiate the
   default bundle from `getJsDelivrBundles()`, then run:

   ```sql
   INSTALL quack;
   LOAD quack;
   CREATE OR REPLACE SECRET quack_demo (TYPE quack, TOKEN '<token>');
   ATTACH 'quack:<host>:<port>' AS remote (TOKEN '<token>');
   ```

3. Alternatively, instantiate the package's `duckdb-threads.wasm` and
   `duckdb-browser-threads.*.worker.js` assets from a cross-origin-isolated
   page, then install and load Quack.

## Observed results

### Default bundle

- `INSTALL quack` and `LOAD quack` complete.
- `ATTACH` fails with:

  ```text
  Invalid Error: thread constructor failed: Not supported
  ```

- Setting `threads = 1` did not make the Quack `ATTACH` succeed.

### Threaded bundle

- The browser reports cross-origin isolation and WASM thread support.
- `INSTALL quack` completes, but `LOAD quack` fails with:

  ```text
  IO Error: Extension "https://extensions.duckdb.org/v2.0.0/wasm_threads/quack.duckdb_extension.wasm" could not be loaded:
  ```

- The extension URL returned HTTP 200 and the response compiled as a WebAssembly
  module. The follow-up investigation in issue #2290 reports that this
  extension build imports non-shared memory, which is incompatible with the
  shared memory expected by the threaded DuckDB-WASM runtime.

## Expected behavior

The official DuckDB 2.0 WASM bundle and matching published Quack/httpfs
extensions should support attaching to a DuckDB 2.0 Quack server in a supported
browser runtime. The client should then be able to issue a query (including
`CONNECT` / plain SQL / `DISCONNECT` where supported) and receive the result.

## Server-side control test

The same DuckDB 2.0.0 server accepted a native DuckDB 2.0.0 client using:

```sql
ATTACH 'quack:localhost:9494' AS remote (TOKEN '<token>');
CONNECT remote;
SELECT count(*) FROM dl1.sales_data;
DISCONNECT;
```

The query returned the seeded 40-row count. This confirms the server-side
Quack endpoint and 2.0 `CONNECT` syntax worked; the failing path was the
browser/WASM client before it could issue those routed queries.

## Related upstream investigation

Issue [duckdb/duckdb-wasm#2290](https://github.com/duckdb/duckdb-wasm/issues/2290)
documents the WASM engine version mismatch that was fixed by
[duckdb/duckdb-wasm#2299](https://github.com/duckdb/duckdb-wasm/pull/2299),
as well as the threaded Quack extension memory mismatch and a local extension
rebuild workaround. That workaround rebuilt both Quack and httpfs for
`wasm_threads` with shared-memory support and matching version metadata.

## Request

Please confirm the supported browser runtime for DuckDB 2.0 Quack and publish
Quack (and any required httpfs) WASM extensions that are compatible with that
runtime's memory model and DuckDB version metadata. A small end-to-end browser
test covering `INSTALL` / `LOAD`, `ATTACH`, and a query against a 2.0 Quack
server would help prevent this regression.
