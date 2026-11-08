import * as duckdb from "https://esm.sh/@duckdb/duckdb-wasm@1.33.1-dev65.0";
import { initWorkbench } from "./workbench.js";
import { initChart } from "./chart.js";
import { initCsvUpload } from "./csv_upload.js";

const QUACK_TOKEN = "replace-with-secure-pwd";
const statusEl = document.getElementById("status");

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

async function instantiateDuckDB() {
  const bundle = await duckdb.selectBundle(duckdb.getJsDelivrBundles());

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

// The WASM client only ever installs/loads the `quack` extension. It never
// installs, loads, or ATTACHes DuckLake, and never touches S3/httpfs --
// every SQL statement runs server-side on EC2 via `remote.query('...')`,
// which is where DuckLake (alias `dl1`) actually lives.
async function attachQuack(conn) {
  await conn.query("INSTALL quack; LOAD quack;");

  // Same-origin proxy trick: serve.py forwards POST /quack to the local
  // SSH tunnel (scripts/start_ssh_tunnel.sh), which forwards to the
  // EC2-hosted Quack server. The browser only ever talks to its own origin.
  const quackHostPort = window.location.host;
  await conn.query(`CREATE OR REPLACE SECRET quack_demo (TYPE quack, TOKEN '${QUACK_TOKEN}');`);
  await conn.query(`ATTACH 'quack:${quackHostPort}' AS remote (TOKEN '${QUACK_TOKEN}');`);
}

async function initialize() {
  try {
    setStatus("Booting DuckDB-WASM...");
    const db = await instantiateDuckDB();
    const conn = await db.connect();

    setStatus("Attaching to Quack...");
    await attachQuack(conn);

    const chart = initChart();
    initWorkbench({
      getConnection: () => conn,
      defaultQuery: "SELECT *\nFROM dl1.sales_data\nLIMIT 100;",
      onResult: chart.handleQueryResult,
    });
    initCsvUpload({ getDb: () => db, getConnection: () => conn });

    setStatus("Connected: DuckDB-WASM \u2192 Quack \u2192 DuckLake (dl1) on EC2");
  } catch (error) {
    console.error(error);
    setStatus(`Initialization failed: ${error.message}`, true);
  }
}

initialize();
