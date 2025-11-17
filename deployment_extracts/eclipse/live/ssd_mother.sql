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
	WHERE PV.PERSONID IN (
			1,2,3,4,5,6,99046,100824,100825,100826,100827,100828,100829,100830,100832,100856,100857,100861,100864,9999040,102790,
			100831,100833,100834,100838,100839,100859,100860,99524,99543,99555,99559,99613,99661,99662,99993,100276,100290,100372,109032,100924,
			100941,35698,43088,68635,74902,77731,97447,9999000,9999010,9999025,9999026,9999029,9999050,72306,109032,117746,
			97951 --not flagged as duplicate
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
