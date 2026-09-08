# Regional Sales Portal — DuckDB-WASM + Quack + DuckLake (EC2)

A browser-only SQL workbench + chart + CSV-upload portal. The **only** thing the
WASM client knows about the backend is a [Quack](https://duckdb.org/docs/current/quack/overview.html)
endpoint and a token — it never installs, loads, or attaches DuckLake, and never
touches S3/httpfs. All DuckLake logic lives on an EC2 instance; the browser just
sends SQL text over Quack's `remote.query('...')` and gets Arrow results back.

## Architecture

```
Browser (DuckDB-WASM)              Laptop                      EC2 (Terraform-managed)
+----------------------+  same-    +------------------+  SSH   +---------------------------+
| INSTALL quack;       |  origin   | serve.py         | tunnel | quack.service (systemd)    |
| ATTACH 'quack:host'  |---------->| proxies POST      |------->| duckdb CLI, holds catalog  |
|   AS remote (TOKEN)  |  /quack   | /quack ->         |  :9494 | ATTACH ducklake AS dl1     |
|                      |           | 127.0.0.1:9494    |        | DATA_PATH -> S3            |
| remote.query('SELECT |           +------------------+        +---------------------------+
|  * FROM dl1.sales_data')                                                |
+----------------------+                                                  v
                                                                  s3://ducklake-definitive-guide/
                                                                    chapter_9/wasm/data/
```

Quack is plain HTTP with no public domain/TLS in front of it, so the security
group only allows your own IP, and the browser never talks to EC2 directly —
an SSH tunnel forwards `127.0.0.1:9494` locally, and `serve.py` proxies the
browser's same-origin `POST /quack` to that tunnel (avoiding CORS entirely,
same trick used elsewhere in this book).

## One table: `sales_data`

```sql
CREATE TABLE dl1.sales_data (
  region_name    VARCHAR,
  sls_order_id   VARCHAR,
  sls_dt         DATE,
  item_name      VARCHAR,
  item_quantity  INTEGER,
  item_total_amt DECIMAL(10, 2)
);
```

Created by the EC2 bootstrap script on first boot. Think of it as a sales entry
template distributed to regional managers, who fill it in and upload it back
through the portal for everyone else to see.

## Deploy

1. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and
   fill in your VPC/subnet, your current public IP (`curl https://checkip.amazonaws.com`),
   an **existing** S3 bucket you control, and a real token.
2. `make deploy` (runs `terraform apply`). Note the printed `quack_public_ip`.
3. Wait ~1-2 minutes for cloud-init, then confirm: `ssh -i ~/.ssh/<key> ubuntu@<ip> 'systemctl is-active quack.service'`.
4. `make generate-data` — writes `sample_data/` (template, seed data + INSERT SQL, two sample upload CSVs).
5. `make tunnel-start` then `make seed-data` — pre-populates `dl1.sales_data` with ~40 dummy rows across 4 regions.
6. `make start` — starts the tunnel (if not already) + static server, opens the browser.

## Try it

- Run the default query (`SELECT * FROM dl1.sales_data LIMIT 100;`), then pick
  X/Y columns and Bar or Line under **Plot Results**.
- Upload `sample_data/sample_upload_pacific_northwest.csv` or
  `sample_upload_gulf_coast.csv` through **Upload Regional Sales CSV** — these
  use region names that aren't in the seed data, so you can immediately query
  `dl1.sales_data` again and see the new rows alongside the originals.

## How the pieces fit together

- **`workbench.js`** — wraps the user's SQL in `SELECT * FROM remote.query('...')`
  (escaping embedded quotes), applies the same 100-row LIMIT-wrapping safety net
  used elsewhere in this book, and fixes up DuckDB-WASM's raw epoch-number
  DATE/DECIMAL display quirks.
- **`chart.js`** — X-Axis/Y-Axis/Bar-or-Line controls rendering directly from the
  already-fetched JS row array via [Observable Plot](https://observablehq.com/plot/).
  Deliberately not Mosaic/vgplot: no reactive coordinator, no extra DB queries,
  no second connection — just a synchronous `Plot.plot({...})` call.
- **`csv_upload.js`** — registers the selected `File` as a DuckDB-WASM virtual
  file, runs `read_csv_auto(...)` **locally** (no Quack round trip for parsing),
  validates the header against the required columns, builds a single
  `INSERT INTO dl1.sales_data VALUES (...), (...);` statement from the typed
  rows, and executes it via `remote.query(...)`.
- **`scripts/generate_sales_data.py`** — produces the template, seed data +
  matching `INSERT` SQL, and sample upload CSVs (with region names *not* in the
  seed set, so uploads are easy to spot).

## Makefile targets

```
make deploy / destroy        terraform apply / destroy (bucket itself untouched)
make generate-data           regenerate sample_data/
make tunnel-start/stop       SSH tunnel to EC2's Quack port
make seed-data               pre-populate dl1.sales_data (tunnel must be up)
make start / stop / status   tunnel + static server, opens the browser
make logs                    tail tunnel + server logs
```

## Notes

- The S3 bucket (`ducklake-definitive-guide`) is **shared** with other chapters
  in this book. Terraform only reads it via a data source and scopes IAM
  permissions to the `chapter_9/wasm/*` key prefix — it is never created or
  destroyed by this module.
- `@duckdb/duckdb-wasm@1.33.1-dev57.0` is pinned because the stable 1.32.0
  release predates the `quack` extension's WASM build (Quack shipped in
  DuckDB v1.5.3).
- The demo token (`replace-with-secure-pwd`) lives in both `terraform.tfvars`
  and `app.js` — keep them in sync if you change it, and treat it as a
  low-security shared secret suitable for a book demo, not production.
- The previous TPC-H/Mosaic dashboard (a different architecture: DuckLake
  attached client-side, browser fetches Parquet directly) is preserved at
  `../bi_tpch_mosaic_archive/` for reference.
