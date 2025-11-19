
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
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
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
