ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

UPDATE my_ducklake.orders SET amount = 50.25 WHERE ORDER_ID = 1;

SELECT data_file_id, begin_snapshot, end_snapshot, path
FROM __ducklake_metadata_my_ducklake.ducklake_data_file
ORDER BY data_file_id;