// Run: npm install && npm start

import { DuckDBInstance } from '@duckdb/node-api';
import { tableFromIPC } from 'apache-arrow';

const instance = await DuckDBInstance.create(':memory:');
const conn = await instance.connect();

// Attach DuckLake.
await conn.run(`
  ATTACH 'ducklake:metadata.ducklake' AS lake (
    DATA_PATH 'lake_data/'
  )
`);

await conn.run(`
  CREATE OR REPLACE TABLE lake.trips AS
  SELECT
    i AS id,
    'city_' || (i % 3) AS city,
    i * 1.5 AS fare
  FROM range(10) t(i)
`);

// Convert query results to Arrow IPC.
await conn.run(`
  INSTALL nanoarrow FROM community;
  LOAD nanoarrow;
`);

const reader = await conn.runAndReadAll(`
  SELECT *
  FROM to_arrow_ipc((
    SELECT
      city,
      count(*) AS trips,
      sum(fare)::DOUBLE AS total
    FROM lake.trips
    GROUP BY city
    ORDER BY city
  ))
`);

// Read the Arrow IPC messages with Apache Arrow for JavaScript.
const table = tableFromIPC(
  reader.getRows().map(([blob]) => blob.bytes),
);

console.log(
  table.schema.fields
    .map((field) => `${field.name}:${field.type}`)
    .join(', '),
);
console.table(table.toArray().map((row) => row.toJSON()));

conn.closeSync();