.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"
install quack; load quack;
load ducklake;

-- migrate to ducklake
ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

create table dl1.orders (
    order_id integer,
    customer_id integer,
    order_date date,
    status varchar
);

call quack_serve(
    'quack:localhost:9494',
    token = '12345',
    allow_other_hostname = true
);