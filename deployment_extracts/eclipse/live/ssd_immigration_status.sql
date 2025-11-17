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
