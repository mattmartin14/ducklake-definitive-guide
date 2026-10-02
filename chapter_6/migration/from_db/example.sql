.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

/*
    Note: 
    This script assumes you have a local postgres instance with the table order_logs already created.
    It also assumes you have environment variables PG_DEV_DB, PG_DEV_USER, and PG_DEV_PASSWORD set so it can log in.

    If you don't have a local postgres instance, you can install it from the web for free.
*/

INSTALL postgres; LOAD postgres;

SET VARIABLE pg_conn = concat(
    'dbname=',getenv('PG_DEV_DB'),
    ' user=',getenv('PG_DEV_USER'),
    ' password=',getenv('PG_DEV_PASSWORD'),
    ' host=127.0.0.1'
);

ATTACH getvariable('pg_conn') AS pg (TYPE postgres);

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw');

CREATE TABLE dl1.order_logs AS SELECT * FROM pg.public.order_logs;

SELECT * FROM dl1.order_logs limit 5;