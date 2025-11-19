-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_mother;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_mother (
    moth_table_id           VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          VARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   VARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         TIMESTAMP                  -- metadata={"item_ref":"MOTH003A"}
);

TRUNCATE TABLE ssd_mother;

INSERT INTO ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)
WITH EXCLUSIONS AS (
	SELECT
		PV.PERSONID
	FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
		OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
		OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
		OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)

SELECT
	PPR.PERSONRELATIONSHIPRECORDID  AS moth_table_id,           --metadata={"item_ref:"MOTH004A"}
	PPR.ROLEAPERSONID               AS moth_person_id,          --metadata={"item_ref:"MOTH002A"}
	PPR.ROLEBPERSONID               AS moth_childs_person_id,   --metadata={"item_ref:"MOTH001A"}
	PDV.DATEOFBIRTH                 AS moth_childs_dob          --metadata={"item_ref:"MOTH003A"}
FROM RELATIONSHIPPERSONVIEW PPR
LEFT JOIN PERSONDEMOGRAPHICSVIEW PDV 
       ON PDV.PERSONID = PPR.ROLEBPERSONID
WHERE PPR.RELATIONSHIP = 'Mother'
    AND PPR.ROLEAPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    AND PPR.ROLEBPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;
