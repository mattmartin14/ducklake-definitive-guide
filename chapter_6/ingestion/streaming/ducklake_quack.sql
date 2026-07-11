create secret(type quack, token '12345', scope 'quack:localhost:9494');

attach 'quack:localhost:9494' as q1 (type quack);

insert into q1.orders (order_id, customer_id, order_date, status) values (1, 1, date '2024-06-01', 'pending');
insert into q1.orders (order_id, customer_id, order_date, status) values (2, 1, date '2024-06-02', 'shipped');