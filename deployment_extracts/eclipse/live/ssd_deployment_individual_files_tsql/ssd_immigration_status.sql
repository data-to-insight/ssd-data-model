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
IF OBJECT_ID('tempdb..#ssd_immigration_status', 'U') IS NOT NULL
    DROP TABLE #ssd_immigration_status;

IF OBJECT_ID('[eclipseDelta].[dbo].[ssd_immigration_status]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [eclipseDelta].[dbo].[ssd_immigration_status]
    )
        TRUNCATE TABLE [eclipseDelta].[dbo].[ssd_immigration_status];
END
ELSE
BEGIN
    CREATE TABLE [eclipseDelta].[dbo].[ssd_immigration_status] (
        immi_immigration_status_id         NVARCHAR(48)  NOT NULL PRIMARY KEY,
        immi_person_id                     NVARCHAR(48)  NULL,
        immi_immigration_status_start_date DATETIME      NULL,
        immi_immigration_status_end_date   DATETIME      NULL,
        immi_immigration_status            NVARCHAR(100) NULL
    );
END;

INSERT INTO [eclipseDelta].[dbo].[ssd_immigration_status] (
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
    CONVERT(NVARCHAR(100), C.NAME)                        AS immi_immigration_status
FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
LEFT JOIN [eclipseDelta].[dbo].[CLASSIFICATION] C
    ON C.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.CLASSIFICATIONPATHID IN (1, 83)
  AND CLA.STATUS <> 'DELETED'
  AND EXISTS (
      SELECT 1
      FROM [eclipseDelta].[dbo].[ssd_person] sp
      WHERE sp.pers_person_id =
            CONVERT(VARCHAR(48), CLA.PERSONID)
  );
