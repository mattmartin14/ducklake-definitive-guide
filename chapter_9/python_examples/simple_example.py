import duckdb

def connect_and_run():
    cn = duckdb.connect()

    cn.execute("attach 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw')")

    cn.execute("""
        create or replace table dl1.orders as 
        select i as order_id 
        from range(0,5) as r(i)
    """)

    res = cn.execute("select * from dl1.orders limit 5").fetchall()

    for row in res:
        print(row)

if __name__ == "__main__":
    connect_and_run()

