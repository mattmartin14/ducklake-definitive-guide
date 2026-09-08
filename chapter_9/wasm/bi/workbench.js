// SQL Workbench: runs ad-hoc queries against the DuckDB-WASM connection,
// which is attached ONLY via the `quack` extension (see app.js) -- no
// DuckLake/httpfs extension is ever installed or loaded client-side. Every
// query is executed server-side on EC2 via `remote.query('<sql text>')`;
// DuckDB-WASM here is just the transport + result renderer.

const MAX_DISPLAY_ROWS = 100;
const LIMIT_RE = /\blimit\s+\d+/i;

function escapeForRemoteQuery(sql) {
  return sql.replace(/'/g, "''");
}

/**
 * Runs `sql` against the remote DuckLake catalog via `remote.query(...)`,
 * capping the result at `maxRows` (wraps in a subquery + LIMIT if the query
 * doesn't already have one; otherwise trusts the user's own LIMIT and still
 * truncates client-side as a defensive cap).
 *
 * Returns { columns, rows, rowCount, displayedRowCount, truncated, elapsedMs }.
 */
export async function runQuery(conn, sql, { maxRows = MAX_DISPLAY_ROWS } = {}) {
  const trimmed = sql.trim().replace(/;\s*$/, "");
  if (!trimmed) {
    throw new Error("Enter a SQL query first.");
  }

  const hasLimit = LIMIT_RE.test(trimmed);
  const innerSql = hasLimit ? trimmed : `SELECT * FROM (${trimmed}) AS _workbench_subquery LIMIT ${maxRows}`;
  const remoteSql = `SELECT * FROM remote.query('${escapeForRemoteQuery(innerSql)}')`;

  const started = performance.now();
  const result = await conn.query(remoteSql);
  const elapsedMs = performance.now() - started;

  const columns = result.schema.fields.map((field) => field.name);
  // Arrow returns DATE/TIMESTAMP columns as raw epoch numbers, and DECIMAL
  // columns as unscaled integers, via toJSON(); reformat both so the results
  // table and chart axes show real dates/amounts instead of raw integers.
  const temporalColumns = new Set(
    result.schema.fields.filter((field) => /date|timestamp/i.test(field.type.toString())).map((field) => field.name),
  );
  const decimalScaleByColumn = new Map(
    result.schema.fields
      .filter((field) => /decimal/i.test(field.type.toString()))
      .map((field) => [field.name, field.type.scale]),
  );
  const allRows = result.toArray().map((row) => {
    const record = row.toJSON();
    for (const name of temporalColumns) {
      if (typeof record[name] === "number" || typeof record[name] === "bigint") {
        record[name] = new Date(Number(record[name])).toISOString().slice(0, 10);
      }
    }
    for (const [name, scale] of decimalScaleByColumn) {
      if (record[name] !== null && record[name] !== undefined) {
        record[name] = (Number(record[name]) / 10 ** scale).toFixed(scale);
      }
    }
    return record;
  });
  const truncated = allRows.length > maxRows;
  const rows = truncated ? allRows.slice(0, maxRows) : allRows;

  return {
    columns,
    rows,
    rowCount: allRows.length,
    displayedRowCount: rows.length,
    truncated,
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

  container.appendChild(table);
}

/**
 * Wires up the workbench DOM (textarea + buttons + status + results table).
 *
 * @param {object} options
 * @param {() => object} options.getConnection - returns the active AsyncDuckDBConnection.
 * @param {string} [options.defaultQuery]
 * @param {(result: object | null) => void} [options.onResult] - called with
 *   `null` right before a query runs (and on failure), then the result on success.
 */
export function initWorkbench({ getConnection, defaultQuery = "", onResult = () => {} }) {
  const editorEl = document.getElementById("workbench-editor");
  const runButtonEl = document.getElementById("workbench-run");
  const clearButtonEl = document.getElementById("workbench-clear");
  const statusEl = document.getElementById("workbench-status");
  const resultsEl = document.getElementById("workbench-results");

  editorEl.value = defaultQuery;

  function setStatus(text, isError = false) {
    statusEl.textContent = text;
    statusEl.classList.toggle("error", isError);
  }

  async function handleRunClick() {
    const conn = getConnection();
    if (!conn) {
      setStatus("Not connected yet.", true);
      return;
    }

    runButtonEl.disabled = true;
    runButtonEl.textContent = "Running...";
    setStatus("Running query...");
    onResult(null);

    try {
      const result = await runQuery(conn, editorEl.value);
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
