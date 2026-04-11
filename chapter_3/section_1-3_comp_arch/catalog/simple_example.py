import duckdb
import time
import os

def main():

    cn = duckdb.connect()

    sql = f"""
        ATTACH OR REPLACE 'ducklake:local_inst.ducklake' as my_ducklake (DATA_PATH '{os.getenv("HOME")}/dw1');
    """
    cn.execute(sql)

    sql = f"""
        CREATE OR REPLACE TABLE my_ducklake.cust_orders (order_id int, order_date date);

        INSERT INTO my_ducklake.cust_orders VALUES (1, date '2025-01-01');
    """

    cn.execute(sql)

    # mimic time delay between transactions
    time.sleep(5)

    sql = """
        INSERT INTO my_ducklake.cust_orders VALUES 
             (2, date '2025-02-01')
            ,(3, date '2025-03-01')
            ,(4, date '2025-04-01')
            ,(5, date '2025-05-01')
    
    """

    cn.execute(sql)

    cn.sql("FROM my_ducklake.cust_orders").show()

    # time travel
    sql = """SELECT * FROM my_ducklake.cust_orders AT (TIMESTAMP => NOW() - INTERVAL '3 second');"""

    cn.sql(sql).show()

    sql = f"""
        CREATE OR REPLACE VIEW my_ducklake.v_cust_orders
        AS
        SELECT *
        FROM my_ducklake.cust_orders
        WHERE order_id <= 3
    """

    cn.execute(sql)

    cn.sql("from my_ducklake.v_cust_orders").show()

    #creating a macro
    sql = f"""
        CREATE OR REPLACE MACRO my_ducklake.is_even_order(order_id) 
            AS 
            CASE WHEN order_id % 2 == 0 THEN true ELSE false END;
    """
    cn.execute(sql)

    sql = f"""
        SELECT order_id
            ,my_ducklake.is_even_order(order_id) as is_even_ord 
        FROM my_ducklake.cust_orders
    """

    cn.sql(sql).show()

if __name__ == "__main__":
    main()

# to run: uv run simple_example.py