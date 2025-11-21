-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_family;

-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- Description: Create ssd_family if not exists
-- =============================================================================

CREATE TABLE IF NOT EXISTS ssd_family (
    fami_table_id   VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  VARCHAR(48),              -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  VARCHAR(48)               -- metadata={"item_ref":"FAMI002A"}
);

-- =============================================================================
-- Truncate before reload
-- =============================================================================
TRUNCATE TABLE ssd_family;

-- =============================================================================
-- Load data into ssd_family
-- =============================================================================

INSERT INTO ssd_family (
    fami_table_id,
    fami_family_id,
    fami_person_id
)
-- WITH EXCLUSIONS AS (
--     SELECT
--         PV.PERSONID
--     FROM PERSONVIEW PV
-- 	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
-- 			1,2,3,4,5,6
-- 		)
--         OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
--         OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
--         OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
-- )

SELECT
    -- table row id is concat of group and person
    CAST(rf.GROUPID AS TEXT) || CAST(rf.PERSONID AS TEXT) AS fami_table_id,  -- metadata={"item_ref":"FAMI003A"}
    rf.GROUPID                                            AS fami_family_id,  -- metadata={"item_ref":"FAMI001A"}
    rf.PERSONID                                           AS fami_person_id   -- metadata={"item_ref":"FAMI002A"}
FROM GROUPPERSONVIEW rf
LEFT JOIN GROUPVIEW gv
       ON gv.GROUPID = rf.GROUPID
WHERE gv.GROUPTYPE = 'Family'
  -- person exists in ssd_person cohort, exclusions applied
  AND EXISTS (
        SELECT 1
        FROM ssd_person sp
        WHERE sp.pers_person_id = rf.PERSONID
      );
