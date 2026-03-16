ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as d1 (DATA_PATH '${HOME}/dw2');

CREATE TABLE d1.test
as
select * from range(3);

select * 
from d1.test;
