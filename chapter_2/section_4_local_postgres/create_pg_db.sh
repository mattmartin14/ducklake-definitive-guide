# use psql from the PATH (e.g. Homebrew), otherwise psql inside a Docker container named ducklake-pg:
#   docker run -d --name ducklake-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
if command -v psql >/dev/null 2>&1; then
    PSQL="psql -d postgres"
else
    PSQL="docker exec ducklake-pg psql -U postgres -d postgres"
fi

$PSQL -c "DROP DATABASE IF EXISTS ducklake_v1;"
$PSQL -c "CREATE DATABASE ducklake_v1;"
