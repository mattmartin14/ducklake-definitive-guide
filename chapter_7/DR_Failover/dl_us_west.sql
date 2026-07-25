
.print 'simulate us-east-1 outage'
.shell aws s3 rm s3://ducklake-definitive-guide-us-east-1 --recursive


INSTALL AWS; LOAD AWS;
CREATE SECRET (TYPE s3, PROVIDER credential_chain, region 'us-west-2');
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH 's3://ducklake-definitive-guide-us-west-2/', OVERRIDE_DATA_PATH True);

-- query data
SELECT * FROM dl1.tpch.orders
limit 5
;

.print 'created table in us-west-2'
create or replace table dl1.tpch.orders_2 as 
    select t
    from range(1,20) as t(i)
;

-- global settings (the defaulted us-east-1, ignored at instance time since we overrode it)
from dl1.options();

-- instance time (has us-west-2 in use)
from dl1.settings();

-- select * from __ducklake_metadata_dl1.ducklake_metadata;
