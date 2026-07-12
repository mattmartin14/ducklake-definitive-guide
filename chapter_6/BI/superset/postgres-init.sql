-- Runs once when the postgres container first initialises.
-- Creates a dedicated database for the DuckLake catalog (metadata only;
-- parquet data lives on disk at /data/parquet/ inside the superset container).
CREATE DATABASE ducklake;
GRANT ALL PRIVILEGES ON DATABASE ducklake TO superset;
