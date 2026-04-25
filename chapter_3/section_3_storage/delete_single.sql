ATTACH 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

DELETE FROM my_ducklake.orders WHERE order_id = 1;

USE __ducklake_metadata_my_ducklake;


SELECT data_file_id, begin_snapshot, end_snapshot, path
FROM ducklake_data_file
ORDER BY data_file_id;