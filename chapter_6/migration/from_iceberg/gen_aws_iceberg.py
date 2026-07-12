import boto3
import duckdb
import os

"""
Generate Iceberg tables on AWS using DuckDB.

This script performs the following steps:
1. Drops and creates the specified Glue database.
2. Cleans up existing Iceberg data in the specified S3 bucket.
3. Sets up an Iceberg connection in DuckDB.
4. Creates Iceberg tables (`orders` and `lineitem`) with sample data.

Environment variables:
- aws_acct_nbr: AWS account number for the Iceberg datalake.

Dependencies:
- boto3
- duckdb
"""

AWS_ACCOUNT_NBR = os.getenv('aws_acct_nbr')
GLUE_DATABASE = "iceberg_db"
BUCKET_NAME = "ducklake-definitive-guide"
ICEBERG_S3_PREFIX = "ice1"

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


def _setup_iceberg_connection(cn):
    cn.execute("INSTALL iceberg; LOAD iceberg;")
    cn.execute("INSTALL aws; LOAD aws;")
    cn.execute("INSTALL httpfs; LOAD httpfs;")
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



def main():
    drop_glue_database_if_exists(GLUE_DATABASE)
    create_glue_database(GLUE_DATABASE)
    create_iceberg_tables(GLUE_DATABASE)
   
if __name__ == "__main__":
    main()
