
ATTACH 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh
    (DATA_PATH concat(getenv('HOME'), '/dwpg1'));

create or replace table wh.orders
as
select 1 as order_id, date '2024-01-01' as order_date, 100.0 as amount
union all
select 2, date '2024-03-04', 150
;

select *
from wh.orders
;


-- if using s3:
CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

-- DATA_INLINING_ROW_LIMIT 0: small inserts are otherwise stored inline in the
--  postgres catalog and no parquet file is written to s3
ATTACH OR REPLACE 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh
    (DATA_PATH concat('s3://', getenv('AWS_BUCKET'), '/ducklake_pg'), OVERRIDE_DATA_PATH True, DATA_INLINING_ROW_LIMIT 0);

INSERT INTO wh.orders VALUES (3, date '2024-05-06', 200);

-- the new file is under s3://, the first one was written locally
SELECT data_file FROM ducklake_list_files('wh', 'orders');

SELECT * FROM wh.orders;