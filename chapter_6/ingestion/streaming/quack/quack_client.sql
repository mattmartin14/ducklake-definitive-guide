install quack; load quack;

CALL enable_peg_parser();

ATTACH 'quack:localhost:9494' as remote_db (
    type quack,
    token '12345'
);



from remote_db.query('select * from dl1.sales.orders');

create table if not exists remote_db.inv (inv_id int);
insert into remote_db.inv (inv_id) values (1);
insert into remote_db.inv (inv_id) values (2);

select * from remote_db.inv;

create table if not exists remote_db.dl1.inv2 (id int);
insert into remote_db.dl1.inv2 (id) values (1);
select * from remote_db.dl1.inv2;

--call remote_db.query('insert into remote_db.sales.orders (order_id, customer_id, order_date, status) values (3, 2, date ''2024-06-03'', ''pending'')');

-- insert into remote_db.sales.orders (order_id, customer_id, order_date, status)
-- values (3, 2, date '2024-06-03', 'pending');

-- does not work
--select * from remote_db.dl1.sales.orders;