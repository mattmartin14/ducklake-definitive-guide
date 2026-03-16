script=$(envsubst < ./test_script.sql)
duckdb -s "$script"