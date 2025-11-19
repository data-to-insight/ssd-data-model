-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_disability;

-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- =============================================================================

CREATE TABLE IF NOT EXISTS ssd_disability
(
    disa_table_id           VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          VARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    VARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);

-- =============================================================================
-- Truncate before reload
-- =============================================================================
TRUNCATE TABLE ssd_disability;

-- =============================================================================
-- Load data into ssd_disability
-- =============================================================================

INSERT INTO ssd_disability (
    disa_table_id,
    disa_person_id,
    disa_disability_code
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
    CLA.CLASSIFICATIONASSIGNMENTID  AS disa_table_id,   -- metadata={"item_ref":"DISA003A"}
    CLA.PERSONID                    AS disa_person_id,  -- metadata={"item_ref":"DISA001A"}
    CASE 
         WHEN CLASSIFICATION.NAME = 'No disability' 
             THEN 'NONE'
         WHEN CLASSIFICATION.NAME = 'Mobility' 
             THEN 'MOB'
         WHEN CLASSIFICATION.NAME = 'Hand function' 
             THEN 'HAND'
         WHEN CLASSIFICATION.NAME = 'Personal care' 
             THEN 'PC'
         WHEN CLASSIFICATION.NAME = 'Incontinence' 
             THEN 'INC'
         WHEN CLASSIFICATION.NAME = 'Communication' 
             THEN 'COMM'
         WHEN CLASSIFICATION.NAME = 'Learning Disability'
              OR  CLA.NAME = 'Learning'
             THEN 'LD'
         WHEN CLASSIFICATION.NAME = 'Hearing' 
             THEN 'HEAR'    
         WHEN CLASSIFICATION.NAME = 'Vision' 
             THEN 'VIS' 
         WHEN CLASSIFICATION.NAME = 'Behaviour' 
             THEN 'BEH' 
         WHEN CLASSIFICATION.NAME = 'Consciousness' 
             THEN 'CON' 
         WHEN CLASSIFICATION.NAME = 'Diagnosed autism/aspergers' 
                 OR CLASSIFICATION.NAME = 'Autistic Spectrum Disorder'
                 OR CLASSIFICATION.NAME = 'Autism spectrum condition'
             THEN 'AUT' 
         ELSE 'DDA'   
    END                             AS disa_disability_code  -- metadata={"item_ref":"DISA002A"}
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION 
    ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.STATUS NOT IN ('DELETED')
  AND CLA.CLASSIFICATIONPATHID IN (55, 58, 79, 172, 186)
  AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;
