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

IF OBJECT_ID('tempdb..#ssd_disability', 'U') IS NOT NULL DROP TABLE #ssd_disability;

IF OBJECT_ID('ssd_disability', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_disability)
        TRUNCATE TABLE ssd_disability;
END
ELSE
BEGIN
    CREATE TABLE ssd_disability (
        disa_table_id        NVARCHAR(48) NOT NULL PRIMARY KEY,
        disa_person_id       NVARCHAR(48) NOT NULL,
        disa_disability_code NVARCHAR(48) NOT NULL
    );
END;

INSERT INTO ssd_disability (
    disa_table_id,
    disa_person_id,
    disa_disability_code
)
SELECT
    CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS disa_table_id,
    CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS disa_person_id,
    CASE
         WHEN CLASSIFICATION.NAME = 'No disability' THEN 'NONE'
         WHEN CLASSIFICATION.NAME = 'Mobility' THEN 'MOB'
         WHEN CLASSIFICATION.NAME = 'Hand function' THEN 'HAND'
         WHEN CLASSIFICATION.NAME = 'Personal care' THEN 'PC'
         WHEN CLASSIFICATION.NAME = 'Incontinence' THEN 'INC'
         WHEN CLASSIFICATION.NAME = 'Communication' THEN 'COMM'
         WHEN CLASSIFICATION.NAME = 'Learning Disability'
              OR CLA.NAME = 'Learning' THEN 'LD'
         WHEN CLASSIFICATION.NAME = 'Hearing' THEN 'HEAR'
         WHEN CLASSIFICATION.NAME = 'Vision' THEN 'VIS'
         WHEN CLASSIFICATION.NAME = 'Behaviour' THEN 'BEH'
         WHEN CLASSIFICATION.NAME = 'Consciousness' THEN 'CON'
         WHEN CLASSIFICATION.NAME = 'Diagnosed autism/aspergers'
              OR CLASSIFICATION.NAME = 'Autistic Spectrum Disorder'
              OR CLASSIFICATION.NAME = 'Autism spectrum condition'
             THEN 'AUT'
         ELSE 'DDA'
    END AS disa_disability_code
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION
    ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.STATUS NOT IN ('DELETED')
  AND CLA.CLASSIFICATIONPATHID IN (55, 58, 79, 172, 186)
  AND EXISTS (
      SELECT 1
      FROM ssd_person SP
      WHERE SP.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
  );