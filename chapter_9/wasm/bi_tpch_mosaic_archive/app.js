import * as duckdb from "https://esm.sh/@duckdb/duckdb-wasm@1.33.1-dev57.0";
import * as vg from "https://esm.sh/@uwdata/vgplot@0.14.1";
import { initWorkbench } from "./workbench.js";
import { initVisualization } from "./visualization.js";

const QUACK_TOKEN = "ducklake-demo-token";
const statusEl = document.getElementById("status");

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

async function instantiateDuckDB() {
  const bundles = duckdb.getJsDelivrBundles();
  const bundle = await duckdb.selectBundle(bundles);

  const workerUrl = URL.createObjectURL(
    new Blob([`importScripts("${bundle.mainWorker}");`], {
      type: "text/javascript",
    }),
  );

  const worker = new Worker(workerUrl);
  const logger = new duckdb.ConsoleLogger();
  const db = new duckdb.AsyncDuckDB(logger, worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  URL.revokeObjectURL(workerUrl);
  return db;
}

async function attachDuckLake(db, conn) {
  await conn.query("INSTALL quack; LOAD quack;");
  await conn.query("INSTALL ducklake; LOAD ducklake;");
  await conn.query("INSTALL httpfs; LOAD httpfs;");

  // The Quack request goes to this page's own origin; serve.py proxies
  // POST /quack through to the local sidecar (start_quack_sidecar.sh),
  // which keeps everything same-origin and avoids CORS entirely.
  const quackHostPort = window.location.host;
  await conn.query(
    `CREATE OR REPLACE SECRET quack_demo (TYPE quack, TOKEN '${QUACK_TOKEN}');`,
  );

  // Catalog metadata (schemas, tables, snapshots) is served by the Quack
  // sidecar; Parquet bytes are still fetched directly by the browser over
  // HTTP via httpfs, so DATA_PATH points at this server's static files.
  const dataPath = new URL("./data/tpch_data/", window.location.href).href;
  await conn.query(
    `ATTACH 'ducklake:quack:${quackHostPort}' AS tpch_lake (DATA_PATH '${dataPath}', OVERRIDE_DATA_PATH true);`,
  );
  await conn.query("USE tpch_lake;");
}

async function initialize() {
  try {
    setStatus("Booting DuckDB-WASM...");
    const db = await instantiateDuckDB();
    const conn = await db.connect();

    setStatus("Fetching DuckLake catalog and attaching...");
    await attachDuckLake(db, conn);

    // Mosaic gets its own connection, separate from the one the workbench
    // uses for CREATE/DESCRIBE/SELECT. Both connections share the same
    // underlying DuckDB-WASM database (so Mosaic can see tables the
    // workbench materializes into the local "memory" database), but issuing
    // ad-hoc queries and Mosaic's chart queries concurrently on a *single*
    // connection was found to permanently wedge DuckDB-WASM after the first
    // chart render.
    const mosaicConn = await db.connect();
    vg.coordinator().databaseConnector(vg.wasmConnector({ duckdb: db, connection: mosaicConn }));

    // Isolated from the outer try/catch: a workbench/visualization-only
    // failure (e.g. the page markup is stale from a cached load) must not
    // blank out an otherwise-successful connection.
    try {
      const visualization = initVisualization({ getConnection: () => mosaicConn });
      initWorkbench({
        getConnection: () => conn,
        defaultQuery: "SELECT *\nFROM tpch_lake.orders\nLIMIT 100;",
        onResult: visualization.handleQueryResult,
      });
    } catch (workbenchError) {
      console.error("SQL Workbench/Visualization failed to initialize:", workbenchError);
    }

    setStatus("Connected: DuckDB-WASM \u2192 Quack \u2192 DuckLake (tpch_lake) \u2192 Mosaic vgplot");
  } catch (error) {
    console.error(error);
    setStatus(`Initialization failed: ${error.message}`, true);
  }
}

initialize();
