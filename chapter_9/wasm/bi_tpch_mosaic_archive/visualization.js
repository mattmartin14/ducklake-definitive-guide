// Query Visualization: renders a single Mosaic/vgplot chart driven by the
// most recent successful SQL Workbench query result, which workbench.js has
// already materialized as a local TEMP TABLE (see RESULT_TABLE there).
//
// Because the data lives in a DuckDB-WASM temp table, switching chart type,
// X/Y, or series here only re-issues Mosaic queries against that local
// table -- it never re-runs the original query over Quack/DuckLake.

import * as vg from "https://esm.sh/@uwdata/vgplot@0.14.1";

// Above this row count we refuse to plot raw points and ask the user to
// aggregate/filter instead, per the "don't visualize millions of rows" rule.
const MAX_VISUALIZE_ROWS = 50_000;
const CHART_WIDTH = 720;
const CHART_HEIGHT = 380;

const NUMERIC_TYPE_RE =
  /^(TINYINT|SMALLINT|INTEGER|INT|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT|FLOAT|DOUBLE|DECIMAL|REAL|NUMERIC)/i;
const TEMPORAL_TYPE_RE = /^(DATE|TIMESTAMP|TIME)/i;

/** Coarse column classification from a DuckDB SQL type string. */
export function classifyColumn(sqlType) {
  const type = (sqlType || "").toUpperCase();
  if (NUMERIC_TYPE_RE.test(type)) return "numeric";
  if (TEMPORAL_TYPE_RE.test(type)) return "temporal";
  return "categorical";
}

/**
 * Deterministic chart recommendation from `[{ name, category }]`:
 *   - temporal + numeric  -> line
 *   - categorical + numeric -> bar
 *   - numeric + numeric   -> scatter
 *   - otherwise           -> table
 * When multiple numeric columns exist, the first is used for Y (the user
 * can switch it via the Y-Axis dropdown).
 */
export function inferChart(columns) {
  const numeric = columns.filter((c) => c.category === "numeric");
  const temporal = columns.filter((c) => c.category === "temporal");
  const categorical = columns.filter((c) => c.category === "categorical");

  if (temporal.length >= 1 && numeric.length >= 1) {
    return { type: "line", x: temporal[0].name, y: numeric[0].name };
  }
  if (categorical.length >= 1 && numeric.length >= 1) {
    return { type: "bar", x: categorical[0].name, y: numeric[0].name };
  }
  if (numeric.length >= 2) {
    return { type: "scatter", x: numeric[0].name, y: numeric[1].name };
  }
  return { type: "table", x: null, y: null };
}

function populateSelect(selectEl, options, selectedValue) {
  selectEl.innerHTML = "";
  for (const option of options) {
    const opt = document.createElement("option");
    opt.value = option.value;
    opt.textContent = option.label;
    selectEl.appendChild(opt);
  }
  if (selectedValue && options.some((o) => o.value === selectedValue)) {
    selectEl.value = selectedValue;
  }
}

/**
 * Wires up the visualization toolbar + chart card.
 *
 * @param {object} options
 * @param {() => object} options.getConnection - returns the active AsyncDuckDBConnection.
 * @returns {{ handleQueryResult: (result: object | null) => void }}
 */
export function initVisualization({ getConnection }) {
  const chartTypeEl = document.getElementById("viz-chart-type");
  const xEl = document.getElementById("viz-x");
  const yEl = document.getElementById("viz-y");
  const seriesEl = document.getElementById("viz-series");
  const renderButtonEl = document.getElementById("viz-render");
  const messageEl = document.getElementById("viz-message");
  const chartSlotEl = document.getElementById("viz-chart");

  if (!chartTypeEl || !xEl || !yEl || !seriesEl || !renderButtonEl || !messageEl || !chartSlotEl) {
    console.warn("Query Visualization markup not found in the page. Skipping visualization init.");
    return { handleQueryResult() {} };
  }

  // The full column list (with inferred category) and row count for the
  // *current* workbench_result table; null until a query has succeeded.
  let currentResult = null;
  const controlEls = [chartTypeEl, xEl, yEl, seriesEl, renderButtonEl];

  function setControlsEnabled(enabled) {
    for (const el of controlEls) el.disabled = !enabled;
  }

  function setMessage(text, isError = false) {
    messageEl.textContent = text;
    messageEl.classList.toggle("error", isError);
  }

  function resolveChartType() {
    if (chartTypeEl.value !== "auto") return chartTypeEl.value;
    return currentResult?.recommendation.type ?? "table";
  }

  function updateAutoOptionLabel() {
    const autoOption = chartTypeEl.querySelector('option[value="auto"]');
    if (!autoOption) return;
    const rec = currentResult?.recommendation.type;
    autoOption.textContent = rec ? `Auto (${rec.charAt(0).toUpperCase()}${rec.slice(1)})` : "Auto";
  }

  function clear() {
    currentResult = null;
    setControlsEnabled(false);
    chartSlotEl.replaceChildren();
    setMessage("");
    chartTypeEl.value = "auto";
    updateAutoOptionLabel();
  }

  function renderChart() {
    if (!currentResult) return;

    const chartType = resolveChartType();
    const x = xEl.value;
    const y = yEl.value;
    const series = seriesEl.value || null;
    const { tableName, columnsByName, rowCount } = currentResult;

    chartSlotEl.replaceChildren();
    setMessage("");

    if (rowCount > MAX_VISUALIZE_ROWS) {
      setMessage(
        `Result has ${rowCount.toLocaleString()} rows, above the ${MAX_VISUALIZE_ROWS.toLocaleString()}-row ` +
          "visualization limit. Aggregate or filter your SQL query first.",
        true,
      );
      return;
    }

    if (chartType === "table") {
      setMessage("Table view selected \u2014 see the results grid above for row-level data.");
      return;
    }

    if (!x || !y || !columnsByName[x] || !columnsByName[y]) {
      setMessage("Choose an X-Axis and Y-Axis column to render a chart.", true);
      return;
    }

    if (chartType === "scatter" && (columnsByName[x].category !== "numeric" || columnsByName[y].category !== "numeric")) {
      setMessage("Scatter charts need numeric X and Y columns. Pick two numeric columns, or choose Bar/Line.", true);
      return;
    }

    if ((chartType === "bar" || chartType === "line") && columnsByName[y].category !== "numeric") {
      setMessage(`${chartType.charAt(0).toUpperCase()}${chartType.slice(1)} charts need a numeric Y-Axis column.`, true);
      return;
    }

    try {
      const plot = buildPlot(chartType, tableName, x, y, series);
      chartSlotEl.replaceChildren(plot);
    } catch (error) {
      console.error(error);
      setMessage(`Chart failed to render: ${error.message}`, true);
    }
  }

  function buildPlot(chartType, tableName, x, y, series) {
    const common = [vg.xLabel(x), vg.yLabel(y), vg.width(CHART_WIDTH), vg.height(CHART_HEIGHT)];

    if (chartType === "bar") {
      return vg.plot(vg.barY(vg.from(tableName), { x, y, fill: series || "#2f6d53" }), ...common);
    }
    if (chartType === "line") {
      return vg.plot(
        vg.lineY(vg.from(tableName), { x, y, stroke: series || "#2f6d53" }),
        vg.dot(vg.from(tableName), { x, y, fill: series || "#2f6d53" }),
        ...common,
      );
    }
    if (chartType === "scatter") {
      return vg.plot(vg.dot(vg.from(tableName), { x, y, fill: series || "#2f6d53" }), ...common);
    }
    throw new Error(`Unknown chart type "${chartType}"`);
  }

  function handleQueryResult(result) {
    if (!result) {
      clear();
      return;
    }

    const columns = result.columns.map((c) => ({ ...c, category: classifyColumn(c.sqlType) }));
    const recommendation = inferChart(columns);
    currentResult = {
      tableName: result.tableName,
      rowCount: result.rowCount,
      recommendation,
      columnsByName: Object.fromEntries(columns.map((c) => [c.name, c])),
    };

    const columnOptions = columns.map((c) => ({ value: c.name, label: `${c.name} (${c.sqlType})` }));
    populateSelect(xEl, columnOptions, recommendation.x ?? columns[0]?.name);
    populateSelect(yEl, columnOptions, recommendation.y ?? columns[0]?.name);
    populateSelect(seriesEl, [{ value: "", label: "(none)" }, ...columnOptions], "");

    chartTypeEl.value = "auto";
    updateAutoOptionLabel();
    setControlsEnabled(true);
    renderChart();
  }

  renderButtonEl.addEventListener("click", renderChart);
  chartTypeEl.addEventListener("change", renderChart);
  xEl.addEventListener("change", renderChart);
  yEl.addEventListener("change", renderChart);
  seriesEl.addEventListener("change", renderChart);

  clear();

  return { handleQueryResult };
}
