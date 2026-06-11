.shell rm -f -- "local_inst.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:local_inst.ducklake' as dl1 (DATA_PATH './dw', DATA_INLINING_ROW_LIMIT 0);

CREATE TABLE dl1.user_lookup (user_id int, user_name varchar);
ALTER TABLE dl1.user_lookup SET PARTITIONED BY (bucket(5, user_id));

INSERT INTO dl1.user_lookup VALUES
    (1, 'Alice'),(2, 'Bob'),(3, 'Charlie'),(4, 'David'),(5, 'Eve'),
    (6, 'Frank'),(7, 'Grace'),(8, 'Henry'),(9, 'Ivy'),(10, 'Jack');

INSERT INTO dl1.user_lookup VALUES
    (11, 'Kate'),(12, 'Leo'),(13, 'Mia'),(14, 'Nina'),(15, 'Oscar'),
    (16, 'Paul'),(17, 'Quinn'),(18, 'Rose'),(19, 'Sam'),(20, 'Tina');


