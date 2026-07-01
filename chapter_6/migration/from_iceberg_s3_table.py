import boto3
from botocore.exceptions import ClientError
import duckdb
import os
import shutil

S3_TABLE_ARN = f"arn:aws:s3tables:us-east-1:{os.getenv('aws_acct_nbr')}:bucket/icehouse-tbl-bucket1"
S3_TABLE_NAMESPACE = "ns1"
DUCKLAKE_FILE = "local_inst.ducklake"
DUCKLAKE_DATA_PATH = "./dw"
DUCKLAKE_DATABASE = "ducklake_cat"


def delete_ducklake():
    if os.path.exists(DUCKLAKE_FILE):
        os.remove(DUCKLAKE_FILE)
    if os.path.exists(DUCKLAKE_DATA_PATH):
        shutil.rmtree(DUCKLAKE_DATA_PATH)


def drop_s3_table_if_exists(s3_tables_arn, namespace, table_name):
    s3_tables = boto3.client('s3tables')
    try:
        s3_tables.delete_table(tableBucketARN=s3_tables_arn, namespace=namespace, name=table_name)
        print(f"Table '{table_name}' dropped successfully.")
    except ClientError as e:
        if e.response['Error']['Code'] == 'NotFoundException':
            print(f"Table '{table_name}' does not exist.")
        else:
            raise


def _setup_iceberg_connection(cn, s3_tables_arn, load_ducklake=False):
    cn.execute("INSTALL iceberg; LOAD iceberg;")
    cn.execute("INSTALL aws; LOAD aws;")
    cn.execute("INSTALL httpfs; LOAD httpfs;")
    if load_ducklake:
        cn.execute("INSTALL ducklake; LOAD ducklake;")
    cn.execute("CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);")
    cn.execute(f"""
        ATTACH '{s3_tables_arn}' AS iceberg_datalake (
            TYPE iceberg,
            ENDPOINT_TYPE s3_tables
        );
    """)


def create_iceberg_s3_tables(s3_tables_arn, namespace):
    with duckdb.connect() as cn:
        _setup_iceberg_connection(cn, s3_tables_arn)
        cn.execute("INSTALL tpch; LOAD tpch;")
        cn.execute("CALL dbgen(sf=.001);")
        cn.execute(f"""
            CREATE TABLE iceberg_datalake.{namespace}.orders
                AS SELECT * FROM orders LIMIT 5;
        """)
        cn.execute(f"""
            CREATE TABLE iceberg_datalake.{namespace}.lineitem
                AS SELECT * FROM lineitem LIMIT 5;
        """)


def migrate_iceberg_to_ducklake(s3_tables_arn, namespace, ducklake_database):
    with duckdb.connect() as cn:
        _setup_iceberg_connection(cn, s3_tables_arn, load_ducklake=True)
        cn.execute(f"ATTACH 'ducklake:{DUCKLAKE_FILE}' AS dl1 (DATA_PATH '{DUCKLAKE_DATA_PATH}', DATA_INLINING_ROW_LIMIT 0);")
        cn.execute(f"CREATE SCHEMA IF NOT EXISTS dl1.{ducklake_database};")

        s3_tables = boto3.client('s3tables')
        for table in s3_tables.list_tables(tableBucketARN=s3_tables_arn, namespace=namespace)['tables']:
            table_name = table['name']
            print(f"Migrating table: {table_name}")
            cn.execute(f"""
                CREATE TABLE dl1.{ducklake_database}.{table_name}
                AS SELECT * FROM iceberg_datalake.{namespace}.{table_name};
            """)
            print(f"Table '{table_name}' migrated successfully.")

def validate_ducklake_tables(ducklake_database):
    with duckdb.connect() as cn:
        cn.execute(f"ATTACH 'ducklake:{DUCKLAKE_FILE}' AS dl1 (DATA_PATH '{DUCKLAKE_DATA_PATH}', DATA_INLINING_ROW_LIMIT 0);")
        for table_name in ["orders", "lineitem"]:
            result = cn.execute(f"SELECT COUNT(*) FROM dl1.{ducklake_database}.{table_name};").fetchone()
            print(f"Table '{table_name}' has {result[0]} rows in DuckLake.")


def main():
    delete_ducklake()
    drop_s3_table_if_exists(S3_TABLE_ARN, S3_TABLE_NAMESPACE, "orders")
    drop_s3_table_if_exists(S3_TABLE_ARN, S3_TABLE_NAMESPACE, "lineitem")
    create_iceberg_s3_tables(S3_TABLE_ARN, S3_TABLE_NAMESPACE)
    migrate_iceberg_to_ducklake(S3_TABLE_ARN, S3_TABLE_NAMESPACE, DUCKLAKE_DATABASE)
    validate_ducklake_tables(DUCKLAKE_DATABASE)

if __name__ == "__main__":
    main()