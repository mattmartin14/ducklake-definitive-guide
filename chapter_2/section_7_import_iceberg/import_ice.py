import duckdb
import os

def main():
    
    cn = duckdb.connect()

    sql = f"""
        select version();
    """
    cn.sql(sql).show()

    sql = f"""
        ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH concat('{os.getenv('HOME')}', '/dw2'));

        CREATE OR REPLACE SECRET aws_creds (TYPE S3, provider credential_chain);

        INSTALL ICEBERG;
        LOAD ICEBERG;

        ATTACH '{os.getenv('AWS_ACCT_ID')}' AS iceberg_catalog (
                  TYPE ICEBERG
                , ENDPOINT_TYPE 'GLUE'
        );
    """
    cn.execute(sql)

    sql = f"""
        select *
        from iceberg_catalog.db3.orders;
    """
    cn.sql(sql).show()

    sql = f"""
        DESCRIBE iceberg_catalog.db3.order_lines;
    """
    cn.sql(sql).show()
    cn.sql("DESCRIBE iceberg_catalog.db3.orders;").show()

    sql = f"""
        COPY FROM DATABASE iceberg_catalog TO my_ducklake;
    """

    #cn.sql(sql).show()
    cn.execute(sql)

if __name__ == "__main__":
    main()