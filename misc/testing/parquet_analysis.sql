COPY (
    FROM (VALUES 
        (1, '2024-01-01', 100.05),
        (2, '2024-01-02', 150.00),
        (3, '2024-01-03', 200.25)
    ) AS t(order_id, order_date, amount)
) to 'orders.parquet'
;

SELECT row_group_id, path_in_schema AS column_name, type
    , stats_min, stats_max, stats_null_count, num_values, compression, encodings 
FROM parquet_metadata('orders.parquet') 
ORDER BY row_group_id, path_in_schema;