-- The frozen.ducklake catalog is stored in a private S3 bucket; use s3:// with credential chain
INSTALL AWS; LOAD AWS;
INSTALL DUCKLAKE; LOAD DUCKLAKE;
CREATE SECRET (TYPE s3, PROVIDER credential_chain, REGION 'us-east-1');
ATTACH 'ducklake:s3://ducklake-definitive-guide/frozen/frozen.ducklake' AS dl1;

SELECT * 
FROM dl1.orders
LIMIT 5;