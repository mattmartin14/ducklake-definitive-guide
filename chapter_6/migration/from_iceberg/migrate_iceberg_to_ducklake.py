import boto3
import duckdb
import os
import shutil

AWS_ACCOUNT_NBR = os.getenv('aws_acct_nbr')
GLUE_DATABASE = "iceberg_db"
BUCKET_NAME = "ducklake-definitive-guide"
ICEBERG_S3_PREFIX = "ice1"
DUCKLAKE_FILE = "local_inst.ducklake"
DUCKLAKE_DATA_PATH = "./dw"
DUCKLAKE_DATABASE = "ducklake_cat"


def delete_ducklake():
    if os.path.exists(DUCKLAKE_FILE):
        os.remove(DUCKLAKE_FILE)
    if os.path.exists(DUCKLAKE_DATA_PATH):
        shutil.rmtree(DUCKLAKE_DATA_PATH)

def _setup_iceberg_connection(cn, load_ducklake=False):
    cn.execute("UPDATE EXTENSIONS")
    cn.execute("INSTALL iceberg; LOAD iceberg;")
    cn.execute("INSTALL aws; LOAD aws;")
    cn.execute("INSTALL httpfs; LOAD httpfs;")
    if load_ducklake:
        cn.execute("INSTALL ducklake; LOAD ducklake;")
    cn.execute("CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);")
    cn.execute(f"""
        ATTACH '{AWS_ACCOUNT_NBR}' AS iceberg_datalake (
            TYPE iceberg,
            ENDPOINT_TYPE 'GLUE'
        );
    """)

def migrate_iceberg_to_ducklake(iceberg_database, ducklake_database, migration_type):
    with duckdb.connect() as cn:
        _setup_iceberg_connection(cn, load_ducklake=True)
        cn.execute(f"ATTACH 'ducklake:{DUCKLAKE_FILE}' AS dl1 (DATA_PATH '{DUCKLAKE_DATA_PATH}', DATA_INLINING_ROW_LIMIT 0);")
        cn.execute(f"CREATE SCHEMA IF NOT EXISTS dl1.{ducklake_database};")

        glue = boto3.client('glue')
        for table in glue.get_tables(DatabaseName=iceberg_database)['TableList']:
            table_name = table['Name']
            print(f"sampling table: {table_name}")
            cn.sql(f"FROM iceberg_datalake.{iceberg_database}.{table_name} limit 1;").show()
            print(f"Table '{table_name}' metadata sampled")

        #execute the shallow migration
        if migration_type == "shallow":
            # currently a bug on shallow copy here: https://github.com/duckdb/ducklake/issues/1278
            cn.execute("CALL iceberg_to_ducklake('iceberg_datalake','dl1')")
        elif migration_type == "full":
            cn.execute("COPY FROM DATABASE iceberg_datalake TO dl1;")

def validate_ducklake_tables(ducklake_schema):
    with duckdb.connect() as cn:
        cn.execute(f"ATTACH 'ducklake:{DUCKLAKE_FILE}' AS dl1 (DATA_PATH '{DUCKLAKE_DATA_PATH}', DATA_INLINING_ROW_LIMIT 0);")
        for table_name in ["orders", "lineitem"]:
            result = cn.execute(f"SELECT COUNT(*) FROM dl1.{ducklake_schema}.{table_name};").fetchone()
            print(f"Table '{table_name}' has {result[0]} rows in DuckLake.")

def main():
    delete_ducklake()
    migrate_iceberg_to_ducklake(GLUE_DATABASE, DUCKLAKE_DATABASE, migration_type="shallow")
    # Note: after a migration, the original iceberg db connection becomes the schema that gets migrated to ducklake
    validate_ducklake_tables(GLUE_DATABASE)


if __name__ == "__main__":
    main()
