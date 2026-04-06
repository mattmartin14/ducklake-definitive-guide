-- Note: Requires AWS credentials in the environment (as environment variables), 
-- plus environment variables set for AWS_REGION (ex: "us-east-1") 
-- and AWS_BUCKET for the bucket path (with a trailing slash, like "s3://bucket-name/")
-- In the final command, the DATA_PATH must be a string literal.

CREATE OR REPLACE SECRET my_secret IN MOTHERDUCK (
    type s3,
    region getenv('AWS_REGION'),
    key_id getenv('AWS_ACCESS_KEY_ID'),
    secret getenv('AWS_SECRET_ACCESS_KEY'),
    scope getenv('AWS_BUCKET')
);

CREATE DATABASE my_ducklake (
    TYPE DUCKLAKE, 
    DATA_PATH 's3://bucket-name/'
);
