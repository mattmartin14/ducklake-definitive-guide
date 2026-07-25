.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
install quack; load quack;
install ducklake;load ducklake;

-- migrate to ducklake
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

use dl1;
create schema sales;

create table dl1.sales.orders (
    order_id integer,
    customer_id integer,
    order_date date,
    status varchar
);

INSERT INTO dl1.sales.orders (order_id, customer_id, order_date, status) VALUES (1, 1, date '2024-06-01', 'pending');
INSERT INTO dl1.sales.orders (order_id, customer_id, order_date, status) VALUES (2, 1, date '2024-06-02', 'shipped');

call quack_serve(
    'quack:localhost:9494',
    token = '12345'
);