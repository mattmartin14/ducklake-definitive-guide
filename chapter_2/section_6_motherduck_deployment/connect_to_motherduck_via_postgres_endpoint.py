# /// script
# dependencies = ["psycopg",]
# ///

# As a pre-requisite, retrieve your MotherDuck token from http://app.motherduck.com/settings/tokens
# and store the token in the environment variable motherduck_token with:
# export motherduck_token="your token"

import os
import psycopg

token = os.environ["motherduck_token"]
region = "us-east-1-aws.motherduck.com"
conn_str = f"postgresql://postgres:{token}@pg.{region}:5432/md:?"
conn_str += "sslmode=verify-full&sslrootcert=system"

with psycopg.connect(conn_str) as conn:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT title, score
            FROM sample_data.hn.hacker_news
            WHERE type = 'story'
            ORDER BY score DESC
            LIMIT 5
        """)
        print(cur.fetchall())
