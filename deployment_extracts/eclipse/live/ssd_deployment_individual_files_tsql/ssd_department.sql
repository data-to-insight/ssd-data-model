-- META-CONTAINER: {"type": "table", "name": "ssd_department"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - ORGANISATIONVIEW
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_department', 'U') IS NOT NULL DROP TABLE #ssd_department;

IF OBJECT_ID('ssd_department', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_department)
        TRUNCATE TABLE ssd_department;
END
ELSE
BEGIN
    CREATE TABLE ssd_department (
        dept_team_id          NVARCHAR(48)  NOT NULL PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
        dept_team_name        NVARCHAR(255) NULL,                  -- metadata={"item_ref":"DEPT1002A"}
        dept_team_parent_id   NVARCHAR(48)  NULL,                  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
        dept_team_parent_name NVARCHAR(255) NULL                   -- metadata={"item_ref":"DEPT1004A"}
    );
END;

INSERT INTO ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)
SELECT
    CONVERT(NVARCHAR(48), ORGANISATIONID) AS dept_team_id,
    CONVERT(NVARCHAR(255), DESCRIPTION)   AS dept_team_name,
    NULL                                  AS dept_team_parent_id,
    NULL                                  AS dept_team_parent_name
FROM ORGANISATIONVIEW
WHERE ORGANISATIONCLASS = 'TEAM'
  AND ISNULL(SECTOR, '') NOT IN ('CHARITY', 'PRIVATE')
  AND ISNULL(SECTORSUBTYPE, '') NOT IN ('ADULT_SOCIAL_SERVICES', 'EDUCATION');