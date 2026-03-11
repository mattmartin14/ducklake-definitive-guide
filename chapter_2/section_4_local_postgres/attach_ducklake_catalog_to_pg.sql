

ATTACH OR REPLACE 'ducklake:postgres:dbname=ducklake_v1 host=localhost' AS wh
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

