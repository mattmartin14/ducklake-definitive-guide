.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

CREATE TABLE IF NOT EXISTS dl1.order_hdr (order_id int, cust_name varchar(250), order_amount numeric(10,2));
INSERT INTO dl1.order_hdr (order_id, cust_name, order_amount) VALUES
    (1001, 'Alice', 250.00),
    (1002, 'Bob', 150.50),
    (1003, 'Charlie', 300.75),
    (1004, 'Diana', 120.00),
    (1005, 'Eve', 450.25);

INSTALL postgres; LOAD postgres;

SET VARIABLE pg_conn_str = 'dbname=' || getenv('PG_DB_NM') 
    || ' user=' || getenv('PG_DB_USER') 
    || ' password=' || getenv('PG_DB_PASSWORD') 
    || ' host=' || getenv('PG_HOST')
;

ATTACH $pg_conn_str AS pg (TYPE postgres);

SELECT
    o.order_id,
    o.cust_name,
    o.order_amount,
    l.id AS log_id,
    l.message AS log_message,
    l.log_ts AS log_timestamp
FROM dl1.order_hdr o
JOIN pg.order_logs l
    ON o.order_id = l.order_id;

