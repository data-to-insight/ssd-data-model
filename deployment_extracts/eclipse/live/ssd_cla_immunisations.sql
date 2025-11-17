
/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_immunisations;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_immunisations (
    clai_person_id                 VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAI002A"}
    clai_immunisations_status      CHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
    clai_immunisations_status_date TIMESTAMP                  -- metadata={"item_ref":"CLAI005A"}
);

TRUNCATE TABLE ssd_cla_immunisations;


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


INSERT INTO ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)
SELECT
    FAPV.ANSWERFORSUBJECTID            AS "clai_person_id",              --metadata={"item_ref:"CLAI002A"}
    MAX(
        CASE 
            WHEN FAPV.CONTROLNAME IN ('903Return_ImmunisationsComplete') 
            THEN SUBSTRING(FAPV.ANSWERVALUE FROM 1 FOR 1) 
        END
    )                                 AS "clai_immunisations_status",    --metadata={"item_ref:"CLAI004A"}
    MAX(
        CASE 
            WHEN FAPV.CONTROLNAME IN ('903Return_dateOfCheckImm') 
            THEN FAPV.ANSWERVALUE 
        END
    )::DATE                           AS "clai_immunisations_status_date" --metadata={"item_ref:"CLAI005A"}
FROM FORMANSWERPERSONVIEW FAPV
WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
  AND FAPV.INSTANCESTATE IN ('COMPLETE')	
  AND FAPV.DESIGNSUBNAME IN ('Immunisation check ')
  AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY
    FAPV.INSTANCEID,
    FAPV.ANSWERFORSUBJECTID;
