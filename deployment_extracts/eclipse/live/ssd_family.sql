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
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
    WHERE PV.PERSONID IN (
            1,2,3,4,5,6,99046,100824,100825,100826,100827,100828,100829,100830,100832,100856,100857,100861,100864,9999040,102790,
            100831,100833,100834,100838,100839,100859,100860,99524,99543,99555,99559,99613,99661,99662,99993,100276,100290,100372,109032,100924,
            100941,35698,43088,68635,74902,77731,97447,9999000,9999010,9999025,9999026,9999029,9999050,72306,109032,117746,
            97951  -- not flagged as duplicate
        )
        OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)

SELECT
    -- table row id is concat of group and person
    CAST(RFAMILY.GROUPID AS TEXT) || CAST(RFAMILY.PERSONID AS TEXT) AS fami_table_id,  -- metadata={"item_ref":"FAMI003A"}
    RFAMILY.GROUPID                                                 AS fami_family_id,  -- metadata={"item_ref":"FAMI001A"}
    RFAMILY.PERSONID                                                AS fami_person_id   -- metadata={"item_ref":"FAMI002A"}
FROM GROUPPERSONVIEW RFAMILY
LEFT JOIN GROUPVIEW ON GROUPVIEW.GROUPID = RFAMILY.GROUPID
WHERE GROUPVIEW.GROUPTYPE = 'Family'
  AND RFAMILY.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;
