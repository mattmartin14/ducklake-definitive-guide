install tpch; load tpch;
call dbgen(sf=.001);

.shell rm -f -- "local_inst.ducklake"
-- AWS CLI commands to clear all files from buckets:
.shell aws s3 rm s3://ducklake-definitive-guide-us-east-1 --recursive
.shell aws s3 rm s3://ducklake-definitive-guide-us-west-2 --recursive

.print 'buckets wiped'


INSTALL AWS; LOAD AWS;
CREATE OR REPLACE SECRET (TYPE s3, PROVIDER credential_chain, region 'us-east-1');
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide-us-east-1/', DATA_INLINING_ROW_LIMIT 0);

create schema dl1.tpch;

create table dl1.tpch.orders as select * from orders;
create table dl1.tpch.lineitem as select * from lineitem;
.print 'tables created in us-east-1'

CREATE OR REPLACE SECRET (TYPE s3, PROVIDER credential_chain, region 'us-west-2');

DETACH dl1;

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide-us-west-2/', OVERRIDE_DATA_PATH True);

.print 'creating new schema in us-west-2'
create schema dl1.tpch2;

.print 'created table in us-west-2'
create or replace table dl1.tpch2.orders_2 as 
    select t
    from range(1,20) as t(i)
;

.print 'query table in us west 2'
SELECT * FROM dl1.tpch2.orders_2 limit 3;

DETACH dl1;

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide-us-east-1/');

CREATE OR REPLACE SECRET (TYPE s3, PROVIDER credential_chain, region 'us-east-1');

.print 'query table in us east 1'
SELECT * FROM dl1.tpch.orders limit 3;


