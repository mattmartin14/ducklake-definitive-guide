# DuckDB-WASM + Quack + DuckLake + Mosaic TPC-H Dashboard

An in-browser BI demo: [DuckDB-WASM](https://duckdb.org/docs/stable/clients/wasm/overview) attaches
to a **DuckLake** catalog whose metadata is served by a local native DuckDB process over the
[Quack remote protocol](https://duckdb.org/docs/current/quack/overview.html), and
[Mosaic](https://idl.uw.edu/mosaic/) (`@uwdata/vgplot`) renders interactive charts by pushing SQL
queries directly to that in-browser DuckDB instance.

## Architecture

```
Browser (DuckDB-WASM)                    Local machine
+------------------------+                +------------------------------+
| ATTACH 'ducklake:      |  POST /quack   | Quack sidecar (native duckdb) |
|   quack:host:port'     |--------------->| opens data/tpch_catalog.      |
|   AS tpch_lake         |  (catalog      | ducklake directly, serves     |
|                        |   metadata)    | it raw over Quack             |
| SELECT ... FROM        |                +------------------------------+
|   tpch_lake.orders     |
|                        |  GET Range     +------------------------------+
|                        |--------------->| serve.py (static + proxy)     |
+------------------------+  (Parquet      | data/tpch_data/*.parquet      |
                             bytes)       +------------------------------+
```

Catalog metadata (schemas, tables, snapshots) travels over Quack; the actual Parquet bytes are
still fetched by the browser directly over HTTP via `httpfs`. `serve.py` also proxies
`POST /quack` requests through to the sidecar so the browser's Quack traffic stays same-origin,
sidestepping CORS entirely instead of requiring the Quack server to send CORS headers.

## How it works

1. `generate_data.py` uses native DuckDB (Python) to:
   - `CALL dbgen(sf=0.001)` to generate TPC-H data at scale factor 0.001.
   - `ATTACH 'ducklake:...'` a DuckLake catalog and copy 5 TPC-H tables
     (`customer`, `orders`, `lineitem`, `nation`, `region`) into it.
   - This writes `data/tpch_catalog.ducklake` (the catalog database) and
     `data/tpch_data/` (Parquet storage).
2. `start_quack_sidecar.sh` launches a native `duckdb` CLI process that opens
   `data/tpch_catalog.ducklake` directly as its primary database (not via the
   `ducklake:` ATTACH syntax — Quack serves whatever the current session can
   see) and calls `quack_serve('quack:127.0.0.1:9494', token => ...)`.
3. `serve.py` serves the app's static files with byte-range support (needed
   for DuckDB-WASM's `httpfs` Parquet reads) and proxies `POST /quack` to the
   sidecar on port 9494.
4. `app.js` boots DuckDB-WASM, `LOAD`s the `quack`, `ducklake`, and `httpfs`
   extensions, creates a `quack` secret, and runs:
   ```sql
   ATTACH 'ducklake:quack:127.0.0.1:8000' AS tpch_lake (
     DATA_PATH 'http://127.0.0.1:8000/data/tpch_data/',
     OVERRIDE_DATA_PATH true
   );
   USE tpch_lake;
   ```
   The host:port in the nested `quack:` URI is this page's own origin (proxied
   by serve.py to the real sidecar on 9494), so the request never leaves the
   browser's same-origin policy.
5. Mosaic's coordinator is pointed at the same DuckDB-WASM instance/connection
   via `vg.wasmConnector({ duckdb, connection })`, so chart queries run against
   the DuckLake tables with zero server-side compute (other than the Quack
   catalog round-trips).

## Charts

- **Monthly Order Revenue** — line/dot chart over a precomputed `monthly_revenue` view.
- **Revenue by Nation** — bar chart over a `nation_revenue` view (joins `lineitem` → `orders` → `customer` → `nation`).
- **Orders by Priority** — bar chart computed live by Mosaic (`vg.count()` grouped by `o_orderpriority`).
- **Line Item Quantity Distribution** — histogram computed live by Mosaic (`vg.bin("l_quantity")`).

## SQL Workbench

A small ad-hoc query panel (`workbench.js`) sits above the charts. It reuses the exact same
DuckDB-WASM connection the dashboard is already attached with (no second instance, no server-side
execution):

- Results render as an HTML table with dynamic column headers, capped at 100 displayed rows.
- If your query has no `LIMIT`, it's wrapped in a subquery with an outer `LIMIT 100` so DuckDB
  never materializes an unbounded result; if it already has a `LIMIT`, that's respected as-is
  (with a 100-row display cap still applied defensively).
- The status line shows execution time (ms), rows displayed, and whether results were truncated.
- Errors from DuckDB are caught and shown inline instead of crashing the page.

`executeQuery()` and `initWorkbench()` in `workbench.js` are intentionally generic (they just take
a connection + SQL string) so this is a reasonable base for later additions like local CSV/Parquet
uploads, additional local tables, or rendering charts from arbitrary query results.

## Run locally

The `Makefile` runs both background processes (as daemons, tracked with PID files under `data/`)
and is the easiest way to get started:

```bash
source .venv/bin/activate
make -C chapter_9/wasm/bi generate-data   # once, or whenever you want to regenerate the data
make -C chapter_9/wasm/bi start           # starts the Quack sidecar + static server
```

Then open `http://127.0.0.1:8000`. Other targets:

```bash
make -C chapter_9/wasm/bi status    # show PIDs / running state
make -C chapter_9/wasm/bi logs      # tail both logs
make -C chapter_9/wasm/bi stop      # stop both background processes
make -C chapter_9/wasm/bi restart
```

### Running the pieces by hand

If you'd rather not use `make`, the same start/stop scripts work standalone (each prints its PID
and writes a PID file under `data/` so you can release it later):

```bash
./chapter_9/wasm/bi/start_quack_sidecar.sh   # requires the duckdb CLI, e.g. brew install duckdb
./chapter_9/wasm/bi/start_server.sh
# ...
./chapter_9/wasm/bi/stop_server.sh
./chapter_9/wasm/bi/stop_quack_sidecar.sh
```

## Notes

- All extensions (`quack`, `ducklake`, `httpfs`) are fetched at runtime from
  `extensions.duckdb.org`'s WASM-specific builds; nothing is precompiled into
  this repo. Quack shipped in DuckDB v1.5.3 (May 2026), so this demo pins
  `@duckdb/duckdb-wasm@1.33.1-dev57.0` — the stable 1.32.0 release predates
  Quack's WASM build.
- The demo auth token (`ducklake-demo-token`) is hardcoded for local-only use;
  override it by exporting `QUACK_TOKEN` before running
  `start_quack_sidecar.sh` and updating the same value in `app.js`.
- `start_quack_sidecar.sh` / `start_server.sh` run as background daemons and
  refuse to start a second copy if their PID file (`data/*.pid`) points at a
  still-running process; use the matching `stop_*.sh` script (or `make stop`)
  to release them. Logs land in `data/quack_sidecar.log` and `data/server.log`.
- The custom `serve.py` implements HTTP Range (206 Partial Content) responses
  because Python's default `http.server` ignores the `Range` header, which
  breaks DuckDB-WASM's Parquet byte-range reads.
- `data/` is regenerated by `generate_data.py` and is git-ignored.
- A backup of the earlier (pre-Quack) version of this demo — where the
  browser fetched the whole `.ducklake` catalog file directly instead of
  going through a Quack sidecar — is kept at
  `../bi_ducklake_direct_backup/` for reference.

