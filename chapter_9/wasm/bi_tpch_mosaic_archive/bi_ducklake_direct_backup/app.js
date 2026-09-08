import * as duckdb from "https://esm.sh/@duckdb/duckdb-wasm@1.32.0";
import * as vg from "https://esm.sh/@uwdata/vgplot@0.14.1";

const statusEl = document.getElementById("status");

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

function renderMessage(containerId, message) {
  const el = document.getElementById(containerId);
  el.innerHTML = "";
  const p = document.createElement("p");
  p.className = "message";
  p.textContent = message;
  el.appendChild(p);
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
  const catalogUrl = new URL("./data/tpch_catalog.ducklake", window.location.href).href;
  const catalogResp = await fetch(catalogUrl);
  if (!catalogResp.ok) {
    throw new Error(`Failed to fetch DuckLake catalog: HTTP ${catalogResp.status}`);
  }
  const catalogBytes = new Uint8Array(await catalogResp.arrayBuffer());
  await db.registerFileBuffer("tpch_catalog.ducklake", catalogBytes);

  await conn.query("INSTALL ducklake; LOAD ducklake;");
  await conn.query("INSTALL httpfs; LOAD httpfs;");

  const dataPath = new URL("./data/tpch_data/", window.location.href).href;
  await conn.query(
    `ATTACH 'ducklake:tpch_catalog.ducklake' AS tpch_lake (DATA_PATH '${dataPath}', OVERRIDE_DATA_PATH true);`,
  );
  await conn.query("USE tpch_lake;");
}

async function createAnalyticalViews(conn) {
  await conn.query(`
    CREATE OR REPLACE VIEW monthly_revenue AS
    SELECT date_trunc('month', o_orderdate) AS order_month,
           sum(o_totalprice) AS revenue
    FROM orders
    GROUP BY 1
    ORDER BY 1;
  `);

  await conn.query(`
    CREATE OR REPLACE VIEW nation_revenue AS
    SELECT n.n_name AS nation,
           sum(l.l_extendedprice * (1 - l.l_discount)) AS revenue
    FROM lineitem l
    JOIN orders o ON l.l_orderkey = o.o_orderkey
    JOIN customer c ON o.o_custkey = c.c_custkey
    JOIN nation n ON c.c_nationkey = n.n_nationkey
    GROUP BY 1
    ORDER BY revenue DESC;
  `);
}

function buildCharts() {
  const revenueChart = vg.plot(
    vg.lineY(vg.from("monthly_revenue"), { x: "order_month", y: "revenue", stroke: "#2f6d53" }),
    vg.dot(vg.from("monthly_revenue"), { x: "order_month", y: "revenue", fill: "#2f6d53" }),
    vg.xLabel("Order Month"),
    vg.yLabel("Revenue (USD)"),
    vg.width(500),
    vg.height(300),
  );
  document.getElementById("chart-revenue").replaceChildren(revenueChart);

  const nationChart = vg.plot(
    vg.barX(vg.from("nation_revenue"), { x: "revenue", y: "nation", fill: "#2f6d53" }),
    vg.xLabel("Revenue (USD)"),
    vg.yLabel(null),
    vg.width(500),
    vg.height(300),
  );
  document.getElementById("chart-nation").replaceChildren(nationChart);

  const priorityChart = vg.plot(
    vg.barY(vg.from("orders"), { x: "o_orderpriority", y: vg.count(), fill: "#c98a2c" }),
    vg.xLabel("Order Priority"),
    vg.yLabel("Order Count"),
    vg.width(500),
    vg.height(300),
  );
  document.getElementById("chart-priority").replaceChildren(priorityChart);

  const quantityChart = vg.plot(
    vg.rectY(vg.from("lineitem"), { x: vg.bin("l_quantity"), y: vg.count(), fill: "#5a7fa6" }),
    vg.xLabel("Line Item Quantity"),
    vg.yLabel("Count"),
    vg.width(500),
    vg.height(300),
  );
  document.getElementById("chart-quantity").replaceChildren(quantityChart);
}

async function initialize() {
  try {
    setStatus("Booting DuckDB-WASM...");
    const db = await instantiateDuckDB();
    const conn = await db.connect();

    setStatus("Fetching DuckLake catalog and attaching...");
    await attachDuckLake(db, conn);

    setStatus("Building analytical views...");
    await createAnalyticalViews(conn);

    setStatus("Rendering Mosaic charts...");
    vg.coordinator().databaseConnector(vg.wasmConnector({ duckdb: db, connection: conn }));
    buildCharts();

    setStatus("Connected: DuckDB-WASM \u2192 DuckLake (tpch_lake) \u2192 Mosaic vgplot");
  } catch (error) {
    console.error(error);
    setStatus(`Initialization failed: ${error.message}`, true);
    for (const id of ["chart-revenue", "chart-nation", "chart-priority", "chart-quantity"]) {
      renderMessage(id, error.message);
    }
  }
}

initialize();
