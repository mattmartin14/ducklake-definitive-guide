ATTACH 'tpch.duckdb' as tpch;

INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=.001);

CREATE TABLE tpch.customer AS
SELECT * FROM customer;

CREATE TABLE tpch.orders AS
SELECT * FROM orders;