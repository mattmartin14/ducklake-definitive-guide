// SQL Workbench: runs ad-hoc queries against the same DuckDB-WASM instance
// the dashboard uses (attached over Quack to the DuckLake catalog).
//
// Each successful query is materialized into a table inside DuckDB-WASM's
// local "memory" database -- not converted into JS objects -- so that
// visualization.js can point Mosaic directly at it without a second
// Quack/DuckLake round trip, and without pulling the full result into
// JavaScript just to plot it. Only a capped slice is pulled into JS, for the
// on-page results table.

export const RESULT_TABLE = "workbench_result";
const MAX_DISPLAY_ROWS = 100;

// Each run gets its own uniquely-named table (workbench_result_1,
// workbench_result_2, ...) instead of reusing/replacing one name, since
// Mosaic may still be reading the previous run's table when the next query
// starts. Tables are created in DuckDB-WASM's local "memory" database
// (fully qualified below) rather than as TEMP tables: TEMP tables are scoped
// to the connection that created them, and Mosaic renders through a
// *separate* dedicated connection (see app.js) so it never contends with
// the workbench's own CREATE/DESCRIBE/SELECT calls on the same connection --
// sharing one connection between the two was found to permanently wedge
// DuckDB-WASM's query pipeline after the first chart. Old result tables are
// simply left in place; harmless at this demo's data sizes.
let resultTableSequence = 0;

/**
 * Runs a single SQL statement against the given connection:
 *   1. Materializes it as `CREATE TABLE memory.workbench_result_N AS ...`
 *   2. Reads back column name/type via DESCRIBE (for chart inference).
 *   3. Reads the total row count.
 *   4. Pulls only up to `maxDisplayRows` rows into JS for the results table.
 *
 * Returns { tableName, columns, rows, rowCount, displayedRowCount, truncated, elapsedMs }.
 * `columns` is `[{ name, sqlType }]`. `tableName` is fully qualified
 * (`memory.workbench_result_N`) so callers (e.g. Mosaic) don't need to know
 * which catalog it lives in.
 */
export async function runQuery(conn, sql, { maxDisplayRows = MAX_DISPLAY_ROWS } = {}) {
  const trimmed = sql.trim().replace(/;\s*$/, "");
  if (!trimmed) {
    throw new Error("Enter a SQL query first.");
  }

  const tableName = `memory.${RESULT_TABLE}_${++resultTableSequence}`;

  const started = performance.now();
  await conn.query(`CREATE TABLE ${tableName} AS ${trimmed}`);
  const elapsedMs = performance.now() - started;

  const schemaResult = await conn.query(`DESCRIBE ${tableName}`);
  const columns = schemaResult.toArray().map((row) => {
    const record = row.toJSON();
    return { name: record.column_name, sqlType: record.column_type };
  });

  const countResult = await conn.query(`SELECT count(*)::BIGINT AS n FROM ${tableName}`);
  const rowCount = Number(countResult.toArray()[0].toJSON().n);

  const displayResult = await conn.query(`SELECT * FROM ${tableName} LIMIT ${maxDisplayRows}`);
  const rows = displayResult.toArray().map((row) => row.toJSON());

  return {
    tableName,
    columns,
    rows,
    rowCount,
    displayedRowCount: rows.length,
    truncated: rowCount > rows.length,
    elapsedMs,
  };
}

function renderResultsTable(container, columns, rows) {
  container.innerHTML = "";

  if (columns.length === 0) {
    const p = document.createElement("p");
    p.className = "message";
    p.textContent = "Query returned no columns.";
    container.appendChild(p);
    return;
  }

  const table = document.createElement("table");
  const thead = document.createElement("thead");
  const headRow = document.createElement("tr");
  for (const column of columns) {
    const th = document.createElement("th");
    th.textContent = column.name;
    headRow.appendChild(th);
  }
  thead.appendChild(headRow);
  table.appendChild(thead);

  const tbody = document.createElement("tbody");
  for (const row of rows) {
    const tr = document.createElement("tr");
    for (const column of columns) {
      const td = document.createElement("td");
      const value = row[column.name];
      td.textContent = value === null || value === undefined ? "NULL" : String(value);
      tr.appendChild(td);
    }
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);

  container.appendChild(table);
}

/**
 * Wires up the workbench DOM (textarea + buttons + status + results table).
 *
 * @param {object} options
 * @param {() => object} options.getConnection - returns the active AsyncDuckDBConnection.
 * @param {string} [options.defaultQuery]
 * @param {(result: object | null) => void} [options.onResult] - called with
 *   `null` right before a query runs (and on failure) so the caller can clear
 *   a dependent visualization, then with the result object on success.
 */
export function initWorkbench({ getConnection, defaultQuery = "", onResult = () => {} }) {
  const editorEl = document.getElementById("workbench-editor");
  const runButtonEl = document.getElementById("workbench-run");
  const clearButtonEl = document.getElementById("workbench-clear");
  const statusEl = document.getElementById("workbench-status");
  const resultsEl = document.getElementById("workbench-results");

  if (!editorEl || !runButtonEl || !clearButtonEl || !statusEl || !resultsEl) {
    console.warn(
      "SQL Workbench markup not found in the page (stale cached index.html?). " +
        "Hard-refresh (Cmd/Ctrl+Shift+R) and try again. Skipping workbench init.",
    );
    return;
  }

  editorEl.value = defaultQuery;

  function setStatus(text, isError = false) {
    statusEl.textContent = text;
    statusEl.classList.toggle("error", isError);
  }

  async function handleRunClick() {
    const conn = getConnection();
    if (!conn) {
      setStatus("Not connected to DuckDB-WASM yet.", true);
      return;
    }

    runButtonEl.disabled = true;
    runButtonEl.textContent = "Running...";
    setStatus("Running query...");
    onResult(null);

    try {
      const result = await runQuery(conn, editorEl.value, { maxDisplayRows: MAX_DISPLAY_ROWS });

      renderResultsTable(resultsEl, result.columns, result.rows);

      const parts = [
        `${result.elapsedMs.toFixed(1)} ms`,
        `${result.displayedRowCount} row${result.displayedRowCount === 1 ? "" : "s"} displayed`,
      ];
      if (result.truncated) {
        parts.push(`limited to ${MAX_DISPLAY_ROWS} of ${result.rowCount} rows`);
      }
      setStatus(parts.join(" \u00b7 "));

      onResult(result);
    } catch (error) {
      resultsEl.innerHTML = "";
      const p = document.createElement("p");
      p.className = "message error-message";
      p.textContent = error.message;
      resultsEl.appendChild(p);
      setStatus(`Query failed: ${error.message}`, true);
      onResult(null);
    } finally {
      runButtonEl.disabled = false;
      runButtonEl.textContent = "Run Query";
    }
  }

  function clearWorkbench() {
    editorEl.value = "";
    resultsEl.innerHTML = "";
    setStatus("");
    onResult(null);
  }

  runButtonEl.addEventListener("click", handleRunClick);
  clearButtonEl.addEventListener("click", clearWorkbench);
  editorEl.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      handleRunClick();
    }
  });
}

