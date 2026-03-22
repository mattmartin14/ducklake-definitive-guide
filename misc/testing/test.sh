#script=$(envsubst < ./test_script.sql)
#duckdb -s "$script"
duckdb -s "$(envsubst < ./test_script.sql)" 
#duckdb -c ".read test_script.sql" 


