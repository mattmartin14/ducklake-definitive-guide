ATTACH 'ducklake:non_encrypted.ducklake' as dlne1;
ATTACH 'ducklake:encrypted.ducklake' as dle1;

.timer on

.print '--- Non-Encrypted Table Query ---'
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dlne1.lineitem;
.print '--- Encrypted Table Query ---'
SELECT COUNT(DISTINCT l_suppkey) AS suppkey_count, SUM(l_quantity) AS total_quantity FROM dle1.lineitem;