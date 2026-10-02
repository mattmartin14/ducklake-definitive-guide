# Prompt: upgrade `chapter_9/wasm/bi` to DuckDB 2.0 (alpha) Quack syntax

Paste or reference this file when a DuckDB-WASM build matching DuckDB 2.0 is published.

## Goal

Move the Regional Sales Portal in `chapter_9/wasm/bi` from DuckDB 1.5.5 and legacy
`remote.query('...')` to DuckDB 2.0 alpha, using `CONNECT` / `DISCONNECT` so SQL is no
longer wrapped in `remote.query()`.

## Why it was reverted

- Server on 2.0 alpha plus browser on `@duckdb/duckdb-wasm@1.33.1-dev57.0` failed at
  init: `Serialization Error: Failed to deserialize: expected end of object, but found field id: 2`.
- `@duckdb/duckdb-wasm@1.33.1-dev65.0` (newest on npm at the time, dist-tag `next`) was
  tried and still did not match, so the WASM Quack client was older than the server.
- Precondition to retry: check `npm view @duckdb/duckdb-wasm dist-tags versions` for a
  build based on DuckDB 2.0, and pin it in `app.js`, `csv_upload.js` and the README Notes.

## Reference examples (modern syntax, already working)

- `chapter_6/quack/server.sql`: server side. Installs `ducklake`, `quack`, `AWS`;
  attaches DuckLake; ends with `CALL quack_serve(token => '...')`.
- `chapter_6/quack/client.sql`: client side. `ATTACH 'quack:host:port' AS qk (TOKEN '...');`
  then `CONNECT qk;` ... plain SQL against `dl1.*` ... `DISCONNECT;`.

## Install DuckDB 2.0 alpha

```
curl https://install.duckdb.org | DUCKDB_VERSION=alpha bash
```

The installer writes to `$HOME/.duckdb/cli/latest/duckdb`. On EC2 cloud-init set
`export HOME=/root` first, and symlink the binary to `/usr/local/bin/duckdb`.
The local CLI used for seeding must also be 2.0 alpha (a 1.5.6 CLI works fine with a
1.5.5 server, but not with 2.0 syntax).

## Files to change

| File | Change |
| --- | --- |
| `terraform/templates/bootstrap.sh.tftpl` | Replace the 1.5.5 zip download (`duckdb_version`/`architecture` block) with the alpha install above; keep `quack_serve(..., token => ..., allow_other_hostname => true)` unless the alpha rejects it. |
| `workbench.js` | Remove `escapeForRemoteQuery` and the `remote.query('...')` wrapper. Run `CONNECT remote;`, then the SQL, then `DISCONNECT;` (in a `finally`). |
| `csv_upload.js` | Parse CSV locally first (while NOT connected, since `CONNECT` routes all statements to the server), then `CONNECT remote;` / INSERT / `DISCONNECT;`. Remove `escapeForRemoteQuery`. |
| `app.js` | Keep `ATTACH 'quack:<host>' AS remote (TOKEN ...)`; update the pinned WASM version and comments. |
| `scripts/seed_sales_data.sh` | Inside the heredoc: `CONNECT remote;`, the raw `seed_insert.sql` content, the summary query, `DISCONNECT;`. No quote escaping needed. |
| `index.html`, `README.md` | Replace `remote.query(...)` mentions (architecture diagram, workbench/csv_upload descriptions, WASM pin note). |

## Deploy notes

- `user_data_replace_on_change = false` in `terraform/main.tf`: editing the bootstrap
  template does NOT affect the running instance. Recreate it
  (`terraform apply -replace=<aws_instance resource>` or `make destroy && make deploy`).
- Recreating the instance wipes the DuckLake catalog (`/opt/quack-server/ducklake_metadata.ducklake`),
  so rerun, in order: `make tunnel-start`, `make seed-data`, `make start`.
- Hard-refresh the browser (Cmd+Shift+R) after changing the pinned WASM version.

## Verify

1. Table is populated: with the tunnel up, `ATTACH 'quack:localhost:9494' AS remote (TOKEN '<token>'); CONNECT remote; SELECT count(*) FROM dl1.sales_data; DISCONNECT;`
2. Page loads with no "Initialization failed" banner.
3. Default workbench query returns rows; chart renders; sample CSV upload adds rows.

## Rollback

Revert to DuckDB 1.5.5 zip download in the bootstrap, `remote.query('...')` wrappers
with `escapeForRemoteQuery`, and `duckdb-wasm@1.33.1-dev57.0`.
