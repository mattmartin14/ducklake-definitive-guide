brew services start postgresql@16
psql -d postgres
CREATE DATABASE ducklake_v1;
\q
psql -d ducklake_v1 -P pager=off

brew services stop postgresql@16