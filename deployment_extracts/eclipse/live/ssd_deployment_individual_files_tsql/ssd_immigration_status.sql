-- META-CONTAINER: {"type": "table", "name": "ssd_immigration_status"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_immigration_status', 'U') IS NOT NULL DROP TABLE #ssd_immigration_status;

IF OBJECT_ID('ssd_immigration_status', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_immigration_status)
        TRUNCATE TABLE ssd_immigration_status;
END
ELSE
BEGIN
    CREATE TABLE ssd_immigration_status (
        immi_immigration_status_id         NVARCHAR(48)  NOT NULL PRIMARY KEY,
        immi_person_id                     NVARCHAR(48)  NULL,
        immi_immigration_status_start_date DATETIME      NULL,
        immi_immigration_status_end_date   DATETIME      NULL,
        immi_immigration_status            NVARCHAR(100) NULL
    );
END;

INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)
SELECT
    CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS immi_immigration_status_id,
    CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS immi_person_id,
    CONVERT(DATETIME, CLA.STARTDATE)                      AS immi_immigration_status_start_date,
    CONVERT(DATETIME, CLA.ENDDATE)                        AS immi_immigration_status_end_date,
    CONVERT(NVARCHAR(100), CLASSIFICATION.NAME)           AS immi_immigration_status
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION
    ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.CLASSIFICATIONPATHID IN (1, 83)
  AND CLA.STATUS NOT IN ('DELETED')
  AND EXISTS (
      SELECT 1
      FROM ssd_person SP
      WHERE SP.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
  );