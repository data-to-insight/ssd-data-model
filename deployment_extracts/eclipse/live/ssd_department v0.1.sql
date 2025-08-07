

SELECT
	ORGANISATIONID AS "dept_team_id",           --metadata={"item_ref:"DEPT1001A"}
	DESCRIPTION    AS "dept_team_name",         --metadata={"item_ref:"DEPT1002A"}
	NULL           AS "dept_team_parent_id",    --metadata={"item_ref:"DEPT1003A"}
	NULL           AS "dept_team_parent_name"  --metadata={"item_ref:"DEPT1004A"}
	
FROM ORGANISATIONVIEW	
WHERE ORGANISATIONCLASS = 'TEAM' AND 
      COALESCE(SECTOR,'') NOT IN  ('CHARITY', 'PRIVATE') AND 
      COALESCE(SECTORSUBTYPE,'') NOT IN ('ADULT_SOCIAL_SERVICES','EDUCATION')	
