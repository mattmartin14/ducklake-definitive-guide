INSTALL QUACK; LOAD QUACK;

ATTACH 'quack:localhost:9494' AS qk (TOKEN 'test');

CONNECT qk;

SELECT * FROM dl1.tpch.orders limit 5;

CREATE OR REPLACE TABLE dl1.tpch.orders_filtered AS
SELECT * 
FROM dl1.tpch.orders
WHERE o_orderdate >= CURRENT_DATE - INTERVAL '10 DAY';

DISCONNECT;
