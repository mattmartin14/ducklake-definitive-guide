import boto3
import duckdb
import os
import shutil

def delete_ducklake():
    if os.path.exists("./local_inst.ducklake"):
        os.remove("./local_inst.ducklake")
    if os.path.exists("./dw"):
        shutil.rmtree("./dw")

def drop_glue_database_if_exists(database_name):
    """Drop a Glue database if it exists."""
    client = boto3.client('glue')
    try:
        client.delete_database(Name=database_name)
        print(f"Database '{database_name}' dropped successfully.")
    except client.exceptions.EntityNotFoundException:
        print(f"Database '{database_name}' does not exist.")
    except Exception as e:
        print(f"Error dropping database: {e}")

def create_glue_database(database_name):
    """Create a Glue database."""
    client = boto3.client('glue')
    try:
        client.create_database(DatabaseInput={'Name': database_name})
        print(f"Database '{database_name}' created successfully.")
    except Exception as e:
        print(f"Error creating database: {e}")

def create_iceberg_tables(database_name):
    """Create an Iceberg table in the specified Glue database."""

    # Clean up S3 locations before recreating
    s3 = boto3.client('s3')
    for prefix in ['ice1/orders', 'ice1/lineitem']:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket='ducklake-definitive-guide', Prefix=prefix):
            objects = [{'Key': obj['Key']} for obj in page.get('Contents', [])]
            if objects:
                s3.delete_objects(Bucket='ducklake-definitive-guide', Delete={'Objects': objects})

    cn = duckdb.connect()
    cn.execute("INSTALL iceberg; LOAD iceberg;")
    cn.execute("INSTALL aws; LOAD aws;")
    cn.execute("INSTALL httpfs; LOAD httpfs;")
    cn.execute("CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);")
    cn.execute(f"""
        ATTACH '{os.getenv("aws_acct_nbr")}' AS iceberg_datalake (
            TYPE iceberg,
            ENDPOINT_TYPE 'GLUE'
        );
    """)
    cn.execute("INSTALL tpch; LOAD tpch;")
    cn.execute("CALL dbgen(sf=.001);")

    # create 2 glue tables from tpch
    sql = f"""
    CREATE TABLE iceberg_datalake.{database_name}.orders 
        WITH (
            location = 's3://ducklake-definitive-guide/ice1/orders'
        )
        AS SELECT * FROM orders LIMIT 5;
    """
    cn.execute(sql)

    sql = f"""
    CREATE TABLE iceberg_datalake.{database_name}.lineitem
        WITH (
            location = 's3://ducklake-definitive-guide/ice1/lineitem'
        )
        AS SELECT * FROM lineitem LIMIT 5;
    """
    cn.execute(sql)


def migrate_iceberg_to_ducklake(iceberg_database_name, ducklake_database_name):

    cn = duckdb.connect()   

    cn.execute("INSTALL iceberg; LOAD iceberg;")
    cn.execute("INSTALL aws; LOAD aws;")
    cn.execute("INSTALL httpfs; LOAD httpfs;")
    cn.execute("INSTALL ducklake; LOAD ducklake;")
    cn.execute("CREATE SECRET aws_data (TYPE S3, PROVIDER credential_chain);")

    cn.execute(f"""
        ATTACH '{os.getenv("aws_acct_nbr")}' as iceberg_datalake (
            TYPE iceberg,
            ENDPOINT_TYPE 'GLUE'
        );           
    """)

    cn.execute("ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);")
    cn.execute(f"CREATE SCHEMA IF NOT EXISTS dl1.{ducklake_database_name};")

    glue = boto3.client('glue')
    for table in glue.get_tables(DatabaseName=iceberg_database_name)['TableList']:
        table_name = table['Name']
        print(f"Migrating table: {table_name}")

        # Create a corresponding DuckLake table
        cn.execute(f"""
            CREATE TABLE dl1.{ducklake_database_name}.{table_name} 
            AS SELECT * FROM iceberg_datalake.{iceberg_database_name}.{table_name};
        """)
        print(f"Table '{table_name}' migrated successfully.")

def main():

    delete_ducklake()
    iceberg_database_name = "iceberg_db"
    drop_glue_database_if_exists(iceberg_database_name)
    create_glue_database(iceberg_database_name)
    create_iceberg_tables(iceberg_database_name)
    ducklake_database_name = "ducklake_cat"
    migrate_iceberg_to_ducklake(iceberg_database_name, ducklake_database_name)

if __name__ == "__main__":
    main()