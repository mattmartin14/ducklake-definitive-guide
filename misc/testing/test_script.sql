ATTACH OR REPLACE 'ducklake:local_inst.ducklake' AS d1 (DATA_PATH '${HOME}/dw2');


CREATE OR REPLACE TABLE d1.test AS
SELECT * FROM range(3);


SELECT * FROM d1.test;
