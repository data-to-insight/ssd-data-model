-- META-CONTAINER: {"type": "table", "name": "ssd_family"}
-- =============================================================================
-- Description: 
-- Author: 
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - GROUPPERSONVIEW
-- - GROUPVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_family', 'U') IS NOT NULL DROP TABLE #ssd_family;

IF OBJECT_ID('ssd_family', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_family)
        TRUNCATE TABLE ssd_family;
END
ELSE
BEGIN
    CREATE TABLE ssd_family (
        fami_table_id   NVARCHAR(48) NOT NULL PRIMARY KEY,  -- metadata={"item_ref":"FAMI003A"}
        fami_family_id  NVARCHAR(48) NULL,                  -- metadata={"item_ref":"FAMI001A"}
        fami_person_id  NVARCHAR(48) NULL                   -- metadata={"item_ref":"FAMI002A"}
    );
END;

INSERT INTO ssd_family (
    fami_table_id,
    fami_family_id,
    fami_person_id
)
SELECT
    CONVERT(NVARCHAR(48), CONCAT(CONVERT(NVARCHAR(48), rf.GROUPID), CONVERT(NVARCHAR(48), rf.PERSONID))) AS fami_table_id, -- metadata={"item_ref":"FAMI003A"}
    CONVERT(NVARCHAR(48), rf.GROUPID)  AS fami_family_id,  -- metadata={"item_ref":"FAMI001A"}
    CONVERT(NVARCHAR(48), rf.PERSONID) AS fami_person_id   -- metadata={"item_ref":"FAMI002A"}
FROM GROUPPERSONVIEW rf
LEFT JOIN GROUPVIEW gv
       ON gv.GROUPID = rf.GROUPID
WHERE gv.GROUPTYPE = 'Family'
  AND EXISTS (
        SELECT 1
        FROM ssd_person sp
        WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), rf.PERSONID)
      );