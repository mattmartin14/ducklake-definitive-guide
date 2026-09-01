-- Run with: psql -f load_table_to_pg.sql

CREATE TABLE IF NOT EXISTS order_logs (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    log_ts TIMESTAMPTZ NOT NULL,
    message TEXT NOT NULL
);

INSERT INTO order_logs (order_id, log_ts, message) VALUES
    (1001, '2026-08-28 09:12:03', 'Order received and payment authorized'),
    (1002, '2026-08-28 10:47:21', 'Order picked for fulfillment'),
    (1003, '2026-08-29 14:05:56', 'Order shipped via carrier UPS, tracking assigned'),
    (1004, '2026-08-30 08:30:11', 'Order delayed due to inventory shortage'),
    (1005, '2026-08-31 16:22:47', 'Order delivered and marked complete');

SELECT * FROM order_logs ORDER BY log_ts;
