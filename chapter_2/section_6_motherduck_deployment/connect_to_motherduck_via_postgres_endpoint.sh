# As a pre-requisite, retrieve your MotherDuck token from http://app.motherduck.com/settings/tokens
# and store the token in the environment variable motherduck_token with:
# export motherduck_token="your token"

# Replace <region> with your MotherDuck region (for example us-east-1)
PGPASSWORD=$MOTHERDUCK_TOKEN psql \
  -h pg.<region>-aws.motherduck.com \
  -p 5432 \
  -U postgres \
  "dbname=sample_data sslmode=verify-full sslrootcert=system"