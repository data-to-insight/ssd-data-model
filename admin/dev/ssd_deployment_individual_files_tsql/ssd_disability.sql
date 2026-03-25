-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_disability;

-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- =============================================================================
IF OBJECT_ID('tempdb..#ssd_disability', 'U') IS NOT NULL DROP TABLE #ssd_disability;

IF OBJECT_ID('ssd_disability', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_disability)
        TRUNCATE TABLE ssd_disability;
END
ELSE
BEGIN
    CREATE TABLE ssd_disability
    (
        disa_table_id           VARCHAR(48) PRIMARY KEY,
        disa_person_id          VARCHAR(48) NOT NULL,
        disa_disability_code    VARCHAR(48) 
    );
END

-- =============================================================================
-- Truncate before reload
-- =============================================================================
TRUNCATE TABLE ssd_disability;

-- =============================================================================
-- Load data into ssd_disability
-- =============================================================================

;WITH EXCLUSIONS AS (
    SELECT PV.PERSONID
    FROM [eclipseDelta].[dbo].[PERSONVIEW] PV
    WHERE PV.PERSONID IN (1,2,3,4,5,6)
       OR ISNULL(PV.DUPLICATED,'?') = 'DUPLICATE'
       OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
       OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)
INSERT INTO ssd_disability (
    disa_table_id,
    disa_person_id,
    disa_disability_code
)
SELECT
    CLA.CLASSIFICATIONASSIGNMENTID AS disa_table_id,
    CLA.PERSONID                   AS disa_person_id,
    -- CASE 
    --      WHEN CLASSIFICATION.NAME = 'No disability' THEN 'NONE'
    --      WHEN CLASSIFICATION.NAME = 'Mobility' THEN 'MOB'
    --      WHEN CLASSIFICATION.NAME = 'Hand function' THEN 'HAND'
    --      WHEN CLASSIFICATION.NAME = 'Personal care' THEN 'PC'
    --      WHEN CLASSIFICATION.NAME = 'Incontinence' THEN 'INC'
    --      WHEN CLASSIFICATION.NAME = 'Communication' THEN 'COMM'
    --      WHEN CLASSIFICATION.NAME = 'Learning Disability'
    --           OR CLA.NAME = 'Learning' THEN 'LD'
    --      WHEN CLASSIFICATION.NAME = 'Hearing' THEN 'HEAR'
    --      WHEN CLASSIFICATION.NAME = 'Vision' THEN 'VIS'
    --      WHEN CLASSIFICATION.NAME = 'Behaviour' THEN 'BEH'
    --      WHEN CLASSIFICATION.NAME = 'Consciousness' THEN 'CON'
    --      WHEN CLASSIFICATION.NAME = 'Diagnosed autism/aspergers'
    --           OR CLASSIFICATION.NAME = 'Autistic Spectrum Disorder'
    --           OR CLASSIFICATION.NAME = 'Autism spectrum condition'
    --          THEN 'AUT'
    --      ELSE 'DDA'
    -- END 
    NULL AS disa_disability_code
FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
-- LEFT JOIN [eclipseDelta].[dbo].[CLASSIFICATION] CLASSIFICATION
--     ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
-- WHERE CLA.STATUS NOT IN ('DELETED')
--   AND CLA.CLASSIFICATIONPATHID IN (55, 58, 79, 172, 186)
--   AND 
  WHERE 
  NOT EXISTS (
      SELECT 1
      FROM EXCLUSIONS E
      WHERE E.PERSONID = CLA.PERSONID
  );