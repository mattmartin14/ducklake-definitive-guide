# DuckDB-WASM + MotherDuck (md_dl1)

Simple browser query console that uses the MotherDuck Wasm Client and connects to MotherDuck database `md_dl1`.

## Run locally

1. Export your MotherDuck token:

   ```bash
   export MD_TOKEN="<your_token_here>"
   ```

2. Start the local server:

   ```bash
   python3 serve.py
   ```

3. Open:

   ```
   http://127.0.0.1:8000
   ```

## Notes

- Token is read from environment variable `MD_TOKEN` at request time and served from `/config.js`.
- This demo is intended for local development; the token is visible in browser devtools.
- The browser app imports `@motherduck/wasm-client/with-arrow` from a CDN (`esm.sh`).
- Use Cmd/Ctrl+Enter in the SQL text area to run a query quickly.
