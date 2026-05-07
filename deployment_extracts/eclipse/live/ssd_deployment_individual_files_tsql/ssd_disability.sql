-- META-CONTAINER: {"type": "table", "name": "ssd_disability"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
--
-- =============================================================================
IF OBJECT_ID('tempdb..#ssd_disability', 'U') IS NOT NULL
    DROP TABLE #ssd_disability;

IF OBJECT_ID('[eclipseDelta].[dbo].[ssd_disability]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [eclipseDelta].[dbo].[ssd_disability]
    )
        TRUNCATE TABLE [eclipseDelta].[dbo].[ssd_disability];
END
ELSE
BEGIN
    CREATE TABLE [eclipseDelta].[dbo].[ssd_disability] (
        disa_table_id        NVARCHAR(48) NOT NULL PRIMARY KEY,
        disa_person_id       NVARCHAR(48) NOT NULL,
        disa_disability_code NVARCHAR(48) NOT NULL
    );
END;

INSERT INTO [eclipseDelta].[dbo].[ssd_disability] (
    disa_table_id,
    disa_person_id,
    disa_disability_code
)
SELECT
    CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS disa_table_id,
    CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS disa_person_id,
    CASE
         WHEN C.NAME = 'No disability'                     THEN 'NONE'
         WHEN C.NAME = 'Mobility'                          THEN 'MOB'
         WHEN C.NAME = 'Hand function'                     THEN 'HAND'
         WHEN C.NAME = 'Personal care'                     THEN 'PC'
         WHEN C.NAME = 'Incontinence'                      THEN 'INC'
         WHEN C.NAME = 'Communication'                     THEN 'COMM'
         WHEN C.NAME = 'Learning Disability'
              OR CLA.NAME = 'Learning'                     THEN 'LD'
         WHEN C.NAME = 'Hearing'                           THEN 'HEAR'
         WHEN C.NAME = 'Vision'                            THEN 'VIS'
         WHEN C.NAME = 'Behaviour'                         THEN 'BEH'
         WHEN C.NAME = 'Consciousness'                     THEN 'CON'
         WHEN C.NAME IN (
                'Diagnosed autism/aspergers',
                'Autistic Spectrum Disorder',
                'Autism spectrum condition'
              )                                            THEN 'AUT'
         ELSE 'DDA'
    END AS disa_disability_code
FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
LEFT JOIN [eclipseDelta].[dbo].[CLASSIFICATION] C
    ON C.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.STATUS <> 'DELETED'
  AND CLA.CLASSIFICATIONPATHID IN (55, 58, 79, 172, 186)
  AND EXISTS (
      SELECT 1
      FROM [eclipseDelta].[dbo].[ssd_person] sp
      WHERE sp.pers_person_id =
            CONVERT(VARCHAR(48), CLA.PERSONID)
  );