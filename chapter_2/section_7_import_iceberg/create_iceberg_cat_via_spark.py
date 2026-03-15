import os
import shutil
from pathlib import Path

from pyspark.sql import SparkSession

spark_version = "4.0"
scala_version = "2.13"
iceberg_version = "1.10.1"

warehouse_path = str(Path(__file__).resolve().parent / "icehouse")

def create_spark_session():

    catalog_name = "iceberg"
    spark = SparkSession.builder \
        .appName("local_iceberg_example") \
        .master("local[*]") \
        .config("spark.driver.host", "127.0.0.1") \
        .config("spark.driver.bindAddress", "127.0.0.1") \
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions") \
        .config(f"spark.sql.catalog.{catalog_name}", "org.apache.iceberg.spark.SparkCatalog") \
        .config(f"spark.sql.catalog.{catalog_name}.type", "hadoop") \
        .config(f"spark.sql.catalog.{catalog_name}.warehouse", warehouse_path) \
        .config("spark.jars.packages", f"org.apache.iceberg:iceberg-spark-runtime-{spark_version}_{scala_version}:{iceberg_version}") \
        .getOrCreate()
    
    return spark

def purge_iceberg_warehouse():
 
    if os.path.exists(warehouse_path):
        shutil.rmtree(warehouse_path)

def create_iceberg_table(spark):

    catalog_name = "iceberg"

    namespace = "purch_ord"
    spark.sql(f"create namespace if not exists {catalog_name}.{namespace}")


    sql = f"""
        CREATE OR REPLACE TABLE {catalog_name}.{namespace}.orders
        USING ICEBERG
        AS
        SELECT 1 AS order_id, current_date() AS order_date, floor(rand() * 1000) AS customer_id, rand() * 100 AS total_amount
        UNION ALL
        SELECT 2 AS order_id, current_date() AS order_date, floor(rand() * 1000) AS customer_id, rand() * 100 AS total_amount
    """

    spark.sql(sql)

    sql = f"""
        CREATE OR REPLACE TABLE {catalog_name}.{namespace}.order_lines
        USING ICEBERG
        AS
        SELECT 1 AS order_id, 1 AS line_id, 'Widget' AS product, 2 AS quantity, 19.99 AS price
        UNION ALL
        SELECT 1 AS order_id, 2 AS line_id, 'Gadget' AS product, 1 AS quantity, 29.99 AS price
        UNION ALL
        SELECT 2 AS order_id, 1 AS line_id, 'Thingamajig' AS product, 3 AS quantity, 9.99 AS price  
    """

    spark.sql(sql)

if __name__ == "__main__":
    purge_iceberg_warehouse()
    print('purged iceberg warehouse')
    spark = create_spark_session()
    print('created spark session')
    create_iceberg_table(spark)
    print('created iceberg tables')
    spark.stop()