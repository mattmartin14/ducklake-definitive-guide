// CSV Upload: parses the file LOCALLY in DuckDB-WASM's own in-memory
// database (via read_csv_auto against a registered file handle -- no quack
// round trip for parsing), then builds a plain INSERT ... VALUES statement
// and executes it server-side via remote.query('...'), same as the
// SQL Workbench. This is the "open the CSV in temp space, construct an
// INSERT" approach: DuckDB-WASM IS the temp space.

import * as duckdb from "https://esm.sh/@duckdb/duckdb-wasm@1.33.1-dev57.0";

const REQUIRED_COLUMNS = [
  "region_name",
  "sls_order_id",
  "sls_dt",
  "item_name",
  "item_quantity",
  "item_total_amt",
];
const UPLOAD_FILE_NAME = "upload.csv";

function escapeForRemoteQuery(sql) {
  return sql.replace(/'/g, "''");
}

function quoteString(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function rowToValuesTuple(row) {
  const literals = [
    quoteString(row.region_name),
    quoteString(row.sls_order_id),
    `DATE ${quoteString(row.sls_dt)}`,
    quoteString(row.item_name),
    String(parseInt(row.item_quantity, 10)),
    String(row.item_total_amt),
  ];
  return `(${literals.join(", ")})`;
}

/**
 * @param {object} options
 * @param {() => object} options.getDb - returns the AsyncDuckDB instance.
 * @param {() => object} options.getConnection - returns the active AsyncDuckDBConnection.
 */
export function initCsvUpload({ getDb, getConnection }) {
  const fileInputEl = document.getElementById("upload-file");
  const submitButtonEl = document.getElementById("upload-submit");
  const statusEl = document.getElementById("upload-status");

  function setStatus(text, isError = false) {
    statusEl.textContent = text;
    statusEl.classList.toggle("error", isError);
  }

  fileInputEl.addEventListener("change", () => {
    submitButtonEl.disabled = !fileInputEl.files?.length;
    setStatus("");
  });

  async function handleUploadClick() {
    const file = fileInputEl.files?.[0];
    const db = getDb();
    const conn = getConnection();
    if (!file || !db || !conn) {
      setStatus("Choose a CSV file first.", true);
      return;
    }

    submitButtonEl.disabled = true;
    submitButtonEl.textContent = "Uploading...";
    setStatus("Reading CSV locally...");

    try {
      await db.registerFileHandle(
        UPLOAD_FILE_NAME,
        file,
        duckdb.DuckDBDataProtocol.BROWSER_FILEREADER,
        true,
      );

      // Validate the header before attempting to select typed columns, so a
      // mismatched template produces a clear message instead of a raw SQL error.
      const previewResult = await conn.query(
        `SELECT * FROM read_csv_auto('${UPLOAD_FILE_NAME}') LIMIT 0`,
      );
      const actualColumns = previewResult.schema.fields.map((f) => f.name.toLowerCase());
      const missing = REQUIRED_COLUMNS.filter((name) => !actualColumns.includes(name));
      if (missing.length > 0) {
        throw new Error(
          `CSV is missing required column(s): ${missing.join(", ")}. ` +
            `Expected: ${REQUIRED_COLUMNS.join(", ")}.`,
        );
      }

      const typedResult = await conn.query(`
        SELECT
          region_name,
          sls_order_id,
          CAST(sls_dt AS VARCHAR) AS sls_dt,
          item_name,
          CAST(item_quantity AS INTEGER) AS item_quantity,
          CAST(item_total_amt AS VARCHAR) AS item_total_amt
        FROM read_csv_auto('${UPLOAD_FILE_NAME}')
      `);
      const rows = typedResult.toArray().map((row) => row.toJSON());

      if (rows.length === 0) {
        throw new Error("CSV has a header but no data rows.");
      }

      setStatus(`Inserting ${rows.length} row(s) into dl1.sales_data...`);

      const valuesSql = rows.map(rowToValuesTuple).join(",\n  ");
      const insertSql = `INSERT INTO dl1.sales_data (${REQUIRED_COLUMNS.join(", ")}) VALUES\n  ${valuesSql};`;
      await conn.query(`SELECT * FROM remote.query('${escapeForRemoteQuery(insertSql)}')`);

      setStatus(`Uploaded ${rows.length} row(s) from "${file.name}" to dl1.sales_data.`);
      fileInputEl.value = "";
      submitButtonEl.disabled = true;
    } catch (error) {
      console.error(error);
      setStatus(`Upload failed: ${error.message}`, true);
    } finally {
      submitButtonEl.textContent = "Upload";
      if (fileInputEl.files?.length) {
        submitButtonEl.disabled = false;
      }
    }
  }

  submitButtonEl.addEventListener("click", handleUploadClick);
}
