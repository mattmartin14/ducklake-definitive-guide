.shell rm -f -- "dw.ducklake"
.shell rm -rf -- "./dw"

ATTACH 'ducklake:dw.ducklake' as dw (DATA_PATH './dw');

INSTALL TPCH; LOAD TPCH;
CALL dbgen(sf=1); --250MB version

CREATE TABLE dw.lineitem
AS
SELECT *
FROM lineitem;

-- macro
.print 'creating scalar macro'
CREATE MACRO dw.cat_comment (comment varchar(250))
AS
CASE
    WHEN comment LIKE '%special%requests%' THEN 'special requests'
    WHEN comment LIKE '%delayed%shipment%' THEN 'delayed shipment'
    ELSE 'other'
END
;

.print 'creating table macro'
CREATE MACRO dw.recent_lineitems (anchor_date date) AS TABLE
SELECT *
FROM dw.lineitem
WHERE l_shipdate >= anchor_date
;

.print 'invoking table macro'
SELECT *
FROM dw.recent_lineitems(date '1998-01-01')
LIMIT 5
;

.print 'creating the view'
CREATE VIEW dw.lineitem_shipmode_agg
AS
SELECT l_shipmode
    , dw.cat_comment(l_comment) AS comment_category
    , sum(l_quantity) AS total_quantity
FROM dw.lineitem
GROUP BY ALL
;

.print adding comments to the tables, views, and columns
COMMENT ON TABLE dw.lineitem IS 'This is the lineitem table from TPCH';
COMMENT ON VIEW dw.lineitem_shipmode_agg IS 'This is an aggregate of lineitems by shipmode and comment category';
COMMENT ON COLUMN dw.lineitem.l_shipdate IS 'This is the date the line item shipped';

FROM dw.lineitem
LIMIT 5;

FROM dw.lineitem_shipmode_agg
LIMIT 5;

USE __ducklake_metadata_dw;

FROM ducklake_tag;
FROM ducklake_column_tag;

.shell rm -rf -- "./dw"