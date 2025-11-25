-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_immigration_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_immigration_status (
    immi_immigration_status_id          VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
    immi_person_id                      VARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
    immi_immigration_status_start_date  TIMESTAMP,                 -- metadata={"item_ref":"IMMI003A"}
    immi_immigration_status_end_date    TIMESTAMP,                 -- metadata={"item_ref":"IMMI004A"}
    immi_immigration_status             VARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
);

TRUNCATE TABLE ssd_immigration_status;

INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
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
    CLA.CLASSIFICATIONASSIGNMENTID AS immi_immigration_status_id,         --metadata={"item_ref:"IMMI005A"}
    CLA.PERSONID                   AS immi_person_id,                     --metadata={"item_ref:"IMMI001A"}
    CLA.STARTDATE                  AS immi_immigration_status_start_date, --metadata={"item_ref:"IMMI003A"}
    CLA.ENDDATE                    AS immi_immigration_status_end_date,   --metadata={"item_ref:"IMMI004A"}
    CLASSIFICATION.NAME            AS immi_immigration_status             --metadata={"item_ref:"IMMI002A"}
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.CLASSIFICATIONPATHID IN (1, 83)
    AND CLA.STATUS NOT IN ('DELETED')
    AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;
