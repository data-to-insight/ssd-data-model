-- META-CONTAINER: {"type": "table", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: 
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]    
-- Dependencies: 
-- - FORMANSWERPERSONVIEW
-- - ssd_person
-- Notes: 030626 FAIL TEST RB|RH (max?)
-- =============================================================================


IF OBJECT_ID('tempdb..#ssd_assessment_factors', 'U') IS NOT NULL
    DROP TABLE #ssd_assessment_factors;

IF OBJECT_ID('ssd_assessment_factors', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_assessment_factors])
        TRUNCATE TABLE [ssd_assessment_factors];
END
ELSE
BEGIN
    CREATE TABLE [ssd_assessment_factors] (
        cinf_table_id                NVARCHAR(48)  NOT NULL,
        cinf_assessment_id           NVARCHAR(48)  NOT NULL,
        cinf_assessment_factors_json NVARCHAR(MAX) NULL,
        CONSTRAINT pk_ssd_assessment_factors
            PRIMARY KEY (cinf_table_id, cinf_assessment_id)
    );
END;

;WITH FAPV_BASE AS (
    -- convert ids
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS INSTANCEID,
        FAPV.CONTROLNAME,
        FAPV.ANSWERVALUE,
        FAPV.SHORTANSWERVALUE
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] FAPV
    WHERE FAPV.DESIGNGUID = '94b3f530-a918-4f33-85c2-0ae355c9c2fd'
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND ISNULL(FAPV.DESIGNSUBNAME, '?') IN ('Reassessment', 'Single assessment')
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
),

NEF AS (
    SELECT
        PERSONID,
        INSTANCEID,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_alcoholChild'
                 THEN ANSWERVALUE END) AS ALCOHOL_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_alcoholOtherPersonHousehold'
                 THEN ANSWERVALUE END) AS ALCOHOL_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_alcoholParent'
                 THEN ANSWERVALUE END) AS ALCOHOL_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_domesticChild'
                 THEN ANSWERVALUE END) AS DOMESTIC_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_domesticOtherPersonHousehold'
                 THEN ANSWERVALUE END) AS DOMESTIC_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_domesticParent'
                 THEN ANSWERVALUE END) AS DOMESTIC_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_drugChild'
                 THEN ANSWERVALUE END) AS DRUG_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_drugOtherPersonHousehold'
                 THEN ANSWERVALUE END) AS DRUG_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_drugParent'
                 THEN ANSWERVALUE END) AS DRUG_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_learnDisChild'
                 THEN ANSWERVALUE END) AS LEARN_DIS_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_learnDisOtherPersonHousehold'
                 THEN ANSWERVALUE END) AS LEARN_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_learnDisParent'
                 THEN ANSWERVALUE END) AS LEARN_DIS_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_mentalHealthChild'
                 THEN ANSWERVALUE END) AS MENTAL_HEALTH_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_mentalHealthOtherPerson'
                 THEN ANSWERVALUE END) AS MENTAL_HEALTH_OTHER_PERSON,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_mentalHealthParent'
                 THEN ANSWERVALUE END) AS MENTAL_HEALTH_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_physDisChild'
                 THEN ANSWERVALUE END) AS PHYS_DIS_CHILD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_physDisOtherPersonHousehold'
                 THEN ANSWERVALUE END) AS PHYS_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_physDisParent'
                 THEN ANSWERVALUE END) AS PHYS_DIS_PARENT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_childSpecificFactor'
                 THEN ANSWERVALUE END) AS CHILD_SPECIFIC_FACTOR,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_childSpecificFactor'
                 THEN SHORTANSWERVALUE END) AS CHILD_SPECIFIC_FACTOR_SHORT,

        MAX(CASE WHEN CONTROLNAME = 'CINCensus_allegedPerpetratorOfSexualAbuse'
                 THEN SHORTANSWERVALUE END) AS ALLEGED_PERP_SEXUAL_ABUSE,
        MAX(CASE WHEN CONTROLNAME = 'CINCensus_allegedPerpetratorOfPhysicalAbuse'
                 THEN SHORTANSWERVALUE END) AS ALLEGED_PERP_PHYS_ABUSE

    FROM FAPV_BASE
    GROUP BY
        PERSONID,
        INSTANCEID
)

INSERT INTO [ssd_assessment_factors] (
    cinf_table_id,
    cinf_assessment_id,
    cinf_assessment_factors_json
)
SELECT
    -- 
    CONCAT(NEF.PERSONID, '-', NEF.INSTANCEID) AS cinf_table_id,
    NEF.INSTANCEID,

    CONVERT(NVARCHAR(MAX),
        '['
        + ISNULL(
            STUFF((
                SELECT ',"' + V.code + '"'
                FROM (VALUES
                    (CASE WHEN NEF.ALCOHOL_CHILD IS NOT NULL                    THEN '1A' END),
                    (CASE WHEN NEF.ALCOHOL_PARENT IS NOT NULL                   THEN '1B' END),
                    (CASE WHEN NEF.ALCOHOL_OTHER_PERSON_HOUSEHOLD IS NOT NULL   THEN '1C' END),
                    (CASE WHEN NEF.DRUG_CHILD IS NOT NULL                       THEN '2A' END),
                    (CASE WHEN NEF.DRUG_PARENT IS NOT NULL                      THEN '2B' END),
                    (CASE WHEN NEF.DRUG_OTHER_PERSON_HOUSEHOLD IS NOT NULL      THEN '2C' END),
                    (CASE WHEN NEF.DOMESTIC_CHILD IS NOT NULL                   THEN '3A' END),
                    (CASE WHEN NEF.DOMESTIC_PARENT IS NOT NULL                  THEN '3B' END),
                    (CASE WHEN NEF.DOMESTIC_OTHER_PERSON_HOUSEHOLD IS NOT NULL  THEN '3C' END),
                    (CASE WHEN NEF.MENTAL_HEALTH_CHILD IS NOT NULL              THEN '4A' END),
                    (CASE WHEN NEF.MENTAL_HEALTH_PARENT IS NOT NULL             THEN '4B' END),
                    (CASE WHEN NEF.MENTAL_HEALTH_OTHER_PERSON IS NOT NULL       THEN '4C' END),
                    (CASE WHEN NEF.LEARN_DIS_CHILD IS NOT NULL                  THEN '5A' END),
                    (CASE WHEN NEF.LEARN_DIS_PARENT IS NOT NULL                 THEN '5B' END),
                    (CASE WHEN NEF.LEARN_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '5C' END),
                    (CASE WHEN NEF.PHYS_DIS_CHILD IS NOT NULL                   THEN '6A' END),
                    (CASE WHEN NEF.PHYS_DIS_PARENT IS NOT NULL                  THEN '6B' END),
                    (CASE WHEN NEF.PHYS_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL  THEN '6C' END),
                    (CASE WHEN CAST(NEF.CHILD_SPECIFIC_FACTOR_SHORT AS NVARCHAR(100)) LIKE '%RAD%' THEN '24A' END)
                ) V(code)
                WHERE V.code IS NOT NULL
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
        '')
        + ']'
    )
FROM NEF;