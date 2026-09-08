// Simple chart: pick an X column, a Y column, Bar or Line, click Plot.
// Renders directly from the already-fetched result rows (a plain JS array)
// using Observable Plot -- no reactive coordinator, no extra DB queries.
// This is deliberately NOT Mosaic/vgplot: that reactive, live-querying layer
// isn't needed for a "plot what the workbench just returned" button, and
// pointing it at a `remote.query(...)`-backed relation caused hard-to-debug
// hangs. A static array keeps this simple and robust.

import * as Plot from "https://esm.sh/@observablehq/plot@0.6";

function populateSelect(selectEl, columns, selectedValue) {
  selectEl.innerHTML = "";
  for (const name of columns) {
    const opt = document.createElement("option");
    opt.value = name;
    opt.textContent = name;
    selectEl.appendChild(opt);
  }
  if (selectedValue && columns.includes(selectedValue)) {
    selectEl.value = selectedValue;
  }
}

/**
 * Wires up the X/Y/chart-type controls + chart card.
 * @returns {{ handleQueryResult: (result: object | null) => void }}
 */
export function initChart() {
  const xEl = document.getElementById("chart-x");
  const yEl = document.getElementById("chart-y");
  const typeEl = document.getElementById("chart-type");
  const plotButtonEl = document.getElementById("chart-plot");
  const messageEl = document.getElementById("chart-message");
  const chartSlotEl = document.getElementById("chart-slot");

  const controlEls = [xEl, yEl, typeEl, plotButtonEl];
  let currentRows = [];

  function setControlsEnabled(enabled) {
    for (const el of controlEls) el.disabled = !enabled;
  }

  function setMessage(text, isError = false) {
    messageEl.textContent = text;
    messageEl.classList.toggle("error", isError);
  }

  function clear() {
    currentRows = [];
    setControlsEnabled(false);
    chartSlotEl.replaceChildren();
    setMessage("");
  }

  function plot() {
    chartSlotEl.replaceChildren();
    setMessage("");

    if (currentRows.length === 0) {
      setMessage("Run a query with at least one row first.", true);
      return;
    }

    const x = xEl.value;
    const y = yEl.value;
    const type = typeEl.value;

    try {
      const mark =
        type === "line"
          ? Plot.lineY(currentRows, { x, y, marker: "circle" })
          : Plot.barY(currentRows, { x, y });

      const chart = Plot.plot({
        width: 720,
        height: 380,
        marginBottom: 50,
        x: { label: x, tickRotate: -30 },
        y: { label: y, grid: true },
        marks: [mark],
      });
      chartSlotEl.replaceChildren(chart);
    } catch (error) {
      console.error(error);
      setMessage(`Chart failed to render: ${error.message}`, true);
    }
  }

  function handleQueryResult(result) {
    if (!result || result.rows.length === 0) {
      clear();
      return;
    }

    currentRows = result.rows;
    populateSelect(xEl, result.columns, result.columns[0]);
    populateSelect(yEl, result.columns, result.columns[1] ?? result.columns[0]);
    setControlsEnabled(true);
    plot();
  }

  plotButtonEl.addEventListener("click", plot);

  clear();

  return { handleQueryResult };
}
