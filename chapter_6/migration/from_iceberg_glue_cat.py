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


def drop_glue_database_if_exists(database_name):
    client = boto3.client('glue')
    try:
        client.delete_database(Name=database_name)
        print(f"Database '{database_name}' dropped successfully.")
    except client.exceptions.EntityNotFoundException:
        print(f"Database '{database_name}' does not exist.")


def create_glue_database(database_name):
    client = boto3.client('glue')
    client.create_database(DatabaseInput={'Name': database_name})
    print(f"Database '{database_name}' created successfully.")


def _clean_s3_iceberg_data(table_names):
    s3 = boto3.client('s3')
    for table_name in table_names:
        prefix = f"{ICEBERG_S3_PREFIX}/{table_name}"
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=BUCKET_NAME, Prefix=prefix):
            objects = [{'Key': obj['Key']} for obj in page.get('Contents', [])]
            if objects:
                s3.delete_objects(Bucket=BUCKET_NAME, Delete={'Objects': objects})


def _setup_iceberg_connection(cn, load_ducklake=False):
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


def create_iceberg_tables(database_name):
    _clean_s3_iceberg_data(['orders', 'lineitem'])

    with duckdb.connect() as cn:
        _setup_iceberg_connection(cn)
        cn.execute("INSTALL tpch; LOAD tpch;")
        cn.execute("CALL dbgen(sf=.001);")
        cn.execute(f"""
            CREATE TABLE iceberg_datalake.{database_name}.orders
                WITH (location = 's3://{BUCKET_NAME}/{ICEBERG_S3_PREFIX}/orders')
                AS SELECT * FROM orders LIMIT 5;
        """)
        cn.execute(f"""
            CREATE TABLE iceberg_datalake.{database_name}.lineitem
                WITH (location = 's3://{BUCKET_NAME}/{ICEBERG_S3_PREFIX}/lineitem')
                AS SELECT * FROM lineitem LIMIT 5;
        """)


def migrate_iceberg_to_ducklake(iceberg_database, ducklake_database):
    with duckdb.connect() as cn:
        _setup_iceberg_connection(cn, load_ducklake=True)
        cn.execute(f"ATTACH 'ducklake:{DUCKLAKE_FILE}' AS dl1 (DATA_PATH '{DUCKLAKE_DATA_PATH}', DATA_INLINING_ROW_LIMIT 0);")
        cn.execute(f"CREATE SCHEMA IF NOT EXISTS dl1.{ducklake_database};")

        glue = boto3.client('glue')
        for table in glue.get_tables(DatabaseName=iceberg_database)['TableList']:
            table_name = table['Name']
            print(f"Migrating table: {table_name}")
            cn.execute(f"""
                CREATE TABLE dl1.{ducklake_database}.{table_name}
                AS SELECT * FROM iceberg_datalake.{iceberg_database}.{table_name};
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
    drop_glue_database_if_exists(GLUE_DATABASE)
    create_glue_database(GLUE_DATABASE)
    create_iceberg_tables(GLUE_DATABASE)
    migrate_iceberg_to_ducklake(GLUE_DATABASE, DUCKLAKE_DATABASE)
    validate_ducklake_tables(DUCKLAKE_DATABASE)


if __name__ == "__main__":
    main()
