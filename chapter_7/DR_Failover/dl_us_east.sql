install tpch; load tpch;
call dbgen(sf=.001);

.shell rm -f -- "local_inst.ducklake"
-- AWS CLI commands to clear all files from buckets:
.shell aws s3 rm s3://ducklake-definitive-guide-us-east-1 --recursive
.shell aws s3 rm s3://ducklake-definitive-guide-us-west-2 --recursive

.print 'buckets wiped'


INSTALL AWS; LOAD AWS;
CREATE SECRET (TYPE s3, PROVIDER credential_chain, region 'us-east-1');
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide-us-east-1/', DATA_INLINING_ROW_LIMIT 0);

create schema dl1.tpch;

create table dl1.tpch.orders as select * from orders;
create table dl1.tpch.lineitem as select * from lineitem;
.print 'tables created'

-- AWS CLI command to copy tpch folder from us-east-1 to us-west-2:
.shell aws s3 cp s3://ducklake-definitive-guide-us-east-1/tpch s3://ducklake-definitive-guide-us-west-2/tpch --recursive

.print 'cross region replication complete'




