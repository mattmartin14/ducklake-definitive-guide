
import duckdb

def connect_and_run():
    cn = duckdb.connect()

    cn.execute("""
        ATTACH 'ducklake:local_inst.ducklake' AS dl1 (
            DATA_PATH './dw'
        )
    """)

    cn.execute("""
        CREATE OR REPLACE TABLE dl1.orders AS
        SELECT i AS order_id
        FROM range(0, 5) AS r(i)
    """)

    reader = cn.execute("""
        SELECT *
        FROM dl1.orders
        ORDER BY order_id
    """).to_arrow_reader(batch_size=2)

    for batch in reader:
        print(batch)

    cn.close()

if __name__ == "__main__":
    connect_and_run()

