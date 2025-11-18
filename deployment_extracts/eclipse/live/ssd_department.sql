/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_department;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_department (
    dept_team_id           VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
    dept_team_name         VARCHAR(255),              -- metadata={"item_ref":"DEPT1002A"}
    dept_team_parent_id    VARCHAR(48),               -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
    dept_team_parent_name  VARCHAR(255)               -- metadata={"item_ref":"DEPT1004A"}
);

TRUNCATE TABLE ssd_department;

INSERT INTO ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)
SELECT
    ORGANISATIONID AS dept_team_id,           -- metadata={"item_ref":"DEPT1001A"}
    DESCRIPTION    AS dept_team_name,         -- metadata={"item_ref":"DEPT1002A"}
    NULL           AS dept_team_parent_id,    -- metadata={"item_ref":"DEPT1003A"}
    NULL           AS dept_team_parent_name   -- metadata={"item_ref":"DEPT1004A"}
FROM ORGANISATIONVIEW
WHERE ORGANISATIONCLASS = 'TEAM'
  AND COALESCE(SECTOR, '') NOT IN ('CHARITY', 'PRIVATE')
  AND COALESCE(SECTORSUBTYPE, '') NOT IN ('ADULT_SOCIAL_SERVICES', 'EDUCATION');
