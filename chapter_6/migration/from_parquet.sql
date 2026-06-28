.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
.shell rm -rf -- "./tpch"

install tpch; load tpch;
call dbgen(sf=1);

.shell mkdir -p -- "./tpch"
copy (from orders limit 5) to './tpch/orders.parquet';
copy (from lineitem limit 5) to './tpch/lineitem.parquet';

-- migrate to ducklake
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

create schema dl1.tpch;

-- Method 1: just a straight copy
create table dl1.tpch.orders as select * from './tpch/orders.parquet';
create table dl1.tpch.lineitem as select * from './tpch/lineitem.parquet';

-- Method 2: add data files to existing tables
drop table if exists dl1.tpch.orders;
drop table if exists dl1.tpch.lineitem;

create table dl1.tpch.orders as select * from './tpch/orders.parquet' where 1=0;
create table dl1.tpch.lineitem as select * from './tpch/lineitem.parquet' where 1=0;

CALL ducklake_add_data_files('dl1', 'orders', './tpch/orders.parquet', schema => 'tpch');
CALL ducklake_add_data_files('dl1', 'lineitem', './tpch/lineitem.parquet', schema => 'tpch');

select * from dl1.tpch.orders limit 5;
select * from dl1.tpch.lineitem limit 5;




