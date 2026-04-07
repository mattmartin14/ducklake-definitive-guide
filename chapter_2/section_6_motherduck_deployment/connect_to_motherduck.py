# /// script
# dependencies = ["duckdb",]
# ///

# As a pre-requisite, retrieve your MotherDuck token from http://app.motherduck.com/settings/tokens
# and store the token in the environment variable motherduck_token with:
# export motherduck_token="your token"
import duckdb 
from os import getenv

token = getenv('motherduck_token')
con = duckdb.connect(f'md:?motherduck_token={token}')