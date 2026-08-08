SET TimeZone = 'UTC';                      
SET VARIABLE catalog       = 'my_ducklake';
SET VARIABLE max_age_weeks = 26; -- expire older than N weeks before now()

SET VARIABLE versions_to_expire = (
  WITH snaps AS (
    SELECT snapshot_id, snapshot_time,
           snapshot_time::DATE            AS d,
           date_trunc('week', snapshot_time) AS wk
    FROM ducklake_snapshots(getvariable('catalog'))
  ),
  ref AS (
    SELECT now()                                             AS anchor_ts,
           date_trunc('week', now())                         AS ref_week,
           now() - to_weeks(getvariable('max_age_weeks')::BIGINT) AS cutoff_ts
  ),
  keep AS (
    -- 1. latest snapshot overall
    SELECT s.snapshot_id FROM snaps s
    QUALIFY row_number() OVER (ORDER BY s.snapshot_time DESC) = 1
    UNION
    -- 2. ALL snapshots within the last day (24h before the anchor)
    SELECT s.snapshot_id FROM snaps s, ref
    WHERE s.snapshot_time >= ref.anchor_ts - INTERVAL 1 DAY
    UNION
    -- 3. last snapshot of each day within the current (last) week
    SELECT s.snapshot_id FROM snaps s, ref WHERE s.wk = ref.ref_week
    QUALIFY row_number() OVER (PARTITION BY s.d ORDER BY s.snapshot_time DESC) = 1
    UNION
    -- 4. last snapshot of each prior week
    SELECT s.snapshot_id FROM snaps s, ref WHERE s.wk < ref.ref_week
    QUALIFY row_number() OVER (PARTITION BY s.wk ORDER BY s.snapshot_time DESC) = 1
  ),
  keep_after_age AS (      -- age floor overrides keep
    SELECT k.snapshot_id
    FROM keep k JOIN snaps s USING (snapshot_id), ref
    WHERE s.snapshot_time >= ref.cutoff_ts
  )
  SELECT list(snapshot_id ORDER BY snapshot_id)
  FROM snaps
  WHERE snapshot_id NOT IN (SELECT snapshot_id FROM keep_after_age)
);


CALL ducklake_expire_snapshots('my_ducklake', versions => getvariable('versions_to_expire'));
