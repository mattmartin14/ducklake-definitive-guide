// Run: npm install && npm run append

import {
  DuckDBDataChunk,
  DuckDBInstance,
} from '@duckdb/node-api';

const instance = await DuckDBInstance.create(':memory:');
const conn = await instance.connect();

// Attach DuckLake and create a small target table.
await conn.run(`
  ATTACH 'ducklake:metadata.ducklake' AS lake (
    DATA_PATH 'lake_data/'
  )
`);

await conn.run(`
  CREATE OR REPLACE TABLE lake.trips (
    id INTEGER,
    city VARCHAR,
    fare DOUBLE
  )
`);

// Imagine these records came from an application stream.
const records = [
  { id: 1, city: 'city_0', fare: 1.5 },
  { id: 2, city: 'city_1', fare: 3.0 },
  { id: 3, city: 'city_2', fare: 4.5 },
];

// Append the complete record batch using the DuckDB appender API.
const appender = await conn.createAppender('trips', 'main', 'lake');

const schemaReader = await conn.runAndReadAll(
  'SELECT * FROM lake.trips LIMIT 0',
);
const chunk = DuckDBDataChunk.create(schemaReader.columnTypes());
chunk.setRows(records.map(({ id, city, fare }) => [id, city, fare]));
appender.appendDataChunk(chunk);

appender.closeSync();

const reader = await conn.runAndReadAll(`
  SELECT *
  FROM lake.trips
  ORDER BY id
`);

console.table(reader.getRowObjects());

conn.closeSync();