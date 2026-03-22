.bail on
.print 'test'


select 1 as "blah";

.print 'ok'

-- select * from a;

create table z
as 
select 1 as x, 2 as y;

.print 'table created'

select * 
from z;

