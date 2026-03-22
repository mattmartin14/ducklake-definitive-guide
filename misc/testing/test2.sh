# brew install duckdb
# duckdb -c "copy 'data.csv' to 'data.parquet'"

script=$(cat <<SQL
SELECT * FROM 'data.parquet';

select 1 as test;
SQL
)
duckdb -c "$script"