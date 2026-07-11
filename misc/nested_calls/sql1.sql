install tpch; load tpch;
call dbgen(sf=.001);

create schema dw;

create table dw.orders as 
select * from orders limit 5;

.print 'running sql2.sql'
.read "sql2.sql"