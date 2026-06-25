.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"


ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

USE dl1;

create schema test;

create table test.sales_hdr as
select 1 as sls_id, date '2025-01-01' as sls_dt, 200.05 as sls_amt, cast('North' as varchar(30)) as region_name
union all
select 2, date '2025-03-04', 153.75, cast('South' as varchar(30));

create table test.sales_dtl as
select 1 as sls_id, 101 as item_id, 2 as qty, 3.86 as price
union all
select 1, 102, 1, 2.99
union all
select 2, 101, 1, 3.86
union all
select 2, 103, 3, 1.99;

create table test.sales_nested as
select sls_id
    ,array_agg({'item_id': item_id, 'qty': qty, 'price': price}) as items
    -- , array_agg(struct_pack(item_id := item_id, qty := qty, price := price)) as items
    --, array_agg(row(item_id, qty, price)::STRUCT(item_id INTEGER, qty INTEGER, price DOUBLE)) as items
from test.sales_dtl
group by sls_id;


select * from test.sales_nested;

select
    sls_id,
    item.item_id,
    item.qty,
    item.price
from test.sales_nested,
     unnest(items) as t(item)
order by sls_id, item.item_id;

select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'test'
  and table_name = 'sales_nested';
.last