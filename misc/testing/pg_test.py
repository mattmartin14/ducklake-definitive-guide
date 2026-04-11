import os
import ssl
import pg8000


def run_sql(sql_statement: str) -> None:

    ssl_context = ssl.create_default_context(cafile=os.getenv("PGSSLROOTCERT"))
    ssl_context.check_hostname = True
    ssl_context.verify_mode = ssl.CERT_REQUIRED

    cn = pg8000.dbapi.connect(
        host="pg.us-east-1-aws.motherduck.com",
        port=5432,
        database="md:",
        user="postgres",
        password=os.getenv("MD_TOKEN"),
        timeout=10,
        ssl_context=ssl_context,
    )

    cursor = cn.cursor()

    cursor.execute(sql_statement)
    rows = cursor.fetchall()
    for row in rows:
        print(row)
    cn.close()

if __name__ == "__main__":
    sql = "select * from dw1.sales.transactions limit 5;"
    run_sql(sql)
