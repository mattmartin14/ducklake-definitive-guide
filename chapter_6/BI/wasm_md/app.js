import { MDConnection } from "https://esm.sh/@motherduck/wasm-client/with-arrow";

const DATABASE_NAME = "md_dl1";
const statusEl = document.getElementById("status");
const sqlInputEl = document.getElementById("sqlInput");
const runButtonEl = document.getElementById("runQuery");
const clearButtonEl = document.getElementById("clearResults");
const resultsEl = document.getElementById("results");
const rowMetaEl = document.getElementById("rowMeta");

let connection;

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

function clearResults() {
  resultsEl.innerHTML = "";
  rowMetaEl.textContent = "";
}

function renderMessage(message) {
  clearResults();
  const p = document.createElement("p");
  p.className = "message";
  p.textContent = message;
  resultsEl.appendChild(p);
}

function renderRows(rows) {
  clearResults();

  if (!Array.isArray(rows) || rows.length === 0) {
    rowMetaEl.textContent = "0 rows";
    renderMessage("No rows returned.");
    return;
  }

  const columns = Object.keys(rows[0]);
  rowMetaEl.textContent = `${rows.length} rows`;

  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");

  for (const name of columns) {
    const th = document.createElement("th");
    th.textContent = name;
    headRow.appendChild(th);
  }

  thead.appendChild(headRow);
  table.appendChild(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const name of columns) {
      const td = document.createElement("td");
      const value = row[name];
      td.textContent = value === null || value === undefined ? "NULL" : String(value);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }

  table.appendChild(tbody);
  resultsEl.appendChild(table);
}

function getToken() {
  const token = window.APP_CONFIG?.mdToken?.trim();
  if (token) {
    return token;
  }

  const manualToken = window.prompt("MD_TOKEN was not found in /config.js. Paste token now:", "");
  return manualToken ? manualToken.trim() : "";
}

async function executeQuery() {
  const sql = sqlInputEl.value.trim();
  if (!sql) {
    setStatus("Enter SQL before running.", true);
    return;
  }

  setStatus("Running query...");

  try {
    if (!connection) {
      throw new Error("Connection is not ready yet.");
    }

    const started = performance.now();
    const result = await connection.evaluateQuery(sql);

    if (result.type !== "materialized") {
      throw new Error(`Unsupported result type: ${result.type}`);
    }

    const rows = result.data.toRows();

    const elapsed = ((performance.now() - started) / 1000).toFixed(2);
    renderRows(rows);
    setStatus(`Query completed in ${elapsed}s (MotherDuck WASM client)`);
  } catch (error) {
    setStatus(`Query failed: ${error.message}`, true);
    renderMessage(error.message);
  }
}

async function initialize() {
  setStatus("Booting MotherDuck WASM client...");

  const token = getToken();
  if (!token) {
    setStatus("No MotherDuck token provided.", true);
    renderMessage("Set MD_TOKEN before running the local server, or provide token in prompt.");
    return;
  }

  try {
    connection = MDConnection.create({
      mdToken: token,
    });
    await connection.isInitialized();

    await connection.evaluateQuery(`USE ${DATABASE_NAME};`);

    setStatus(`Connected to MotherDuck database ${DATABASE_NAME}`);

    sqlInputEl.value = [
      "-- Example queries",
      "SHOW TABLES;",
      "SELECT * FROM duckdb_tables() LIMIT 25;",
    ].join("\n");

    renderMessage("Connected. Run a query to view results.");
  } catch (error) {
    setStatus(`Initialization failed: ${error.message}`, true);
    renderMessage(error.message);
  }
}

runButtonEl.addEventListener("click", executeQuery);
clearButtonEl.addEventListener("click", () => {
  clearResults();
  renderMessage("Results cleared.");
});

sqlInputEl.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
    event.preventDefault();
    executeQuery();
  }
});

initialize();
