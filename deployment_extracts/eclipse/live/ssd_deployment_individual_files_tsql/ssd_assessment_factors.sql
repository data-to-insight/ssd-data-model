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
-- =============================================================================


IF OBJECT_ID('tempdb..#ssd_assessment_factors', 'U') IS NOT NULL
    DROP TABLE #ssd_assessment_factors;

IF OBJECT_ID('[SSD].[ssd_assessment_factors]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [SSD].[ssd_assessment_factors]
    )
        TRUNCATE TABLE [SSD].[ssd_assessment_factors];
END
ELSE
BEGIN
    CREATE TABLE [SSD].[ssd_assessment_factors] (
        cinf_table_id                NVARCHAR(48)  NOT NULL,
        cinf_assessment_id           NVARCHAR(48)  NOT NULL,
        cinf_assessment_factors_json NVARCHAR(MAX) NULL,
        CONSTRAINT pk_ssd_assessment_factors
            PRIMARY KEY (cinf_table_id, cinf_assessment_id)
    );
END;

;WITH NEF AS (
    SELECT DISTINCT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS INSTANCEID,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_alcoholChild'
                 THEN FAPV.ANSWERVALUE END) AS ALCOHOL_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_alcoholOtherPersonHousehold'
                 THEN FAPV.ANSWERVALUE END) AS ALCOHOL_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_alcoholParent'
                 THEN FAPV.ANSWERVALUE END) AS ALCOHOL_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_domesticChild'
                 THEN FAPV.ANSWERVALUE END) AS DOMESTIC_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_domesticOtherPersonHousehold'
                 THEN FAPV.ANSWERVALUE END) AS DOMESTIC_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_domesticParent'
                 THEN FAPV.ANSWERVALUE END) AS DOMESTIC_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_drugChild'
                 THEN FAPV.ANSWERVALUE END) AS DRUG_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_drugOtherPersonHousehold'
                 THEN FAPV.ANSWERVALUE END) AS DRUG_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_drugParent'
                 THEN FAPV.ANSWERVALUE END) AS DRUG_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_learnDisChild'
                 THEN FAPV.ANSWERVALUE END) AS LEARN_DIS_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_learnDisOtherPersonHousehold'
                 THEN FAPV.ANSWERVALUE END) AS LEARN_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_learnDisParent'
                 THEN FAPV.ANSWERVALUE END) AS LEARN_DIS_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_mentalHealthChild'
                 THEN FAPV.ANSWERVALUE END) AS MENTAL_HEALTH_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_mentalHealthOtherPerson'
                 THEN FAPV.ANSWERVALUE END) AS MENTAL_HEALTH_OTHER_PERSON,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_mentalHealthParent'
                 THEN FAPV.ANSWERVALUE END) AS MENTAL_HEALTH_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_physDisChild'
                 THEN FAPV.ANSWERVALUE END) AS PHYS_DIS_CHILD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_physDisOtherPersonHousehold'
                 THEN FAPV.ANSWERVALUE END) AS PHYS_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_physDisParent'
                 THEN FAPV.ANSWERVALUE END) AS PHYS_DIS_PARENT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_childSpecificFactor'
                 THEN FAPV.ANSWERVALUE END) AS CHILD_SPECIFIC_FACTOR,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_childSpecificFactor'
                 THEN FAPV.SHORTANSWERVALUE END) AS CHILD_SPECIFIC_FACTOR_SHORT,

        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_allegedPerpetratorOfSexualAbuse'
                 THEN FAPV.SHORTANSWERVALUE END) AS ALLEGED_PERP_SEXUAL_ABUSE,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_allegedPerpetratorOfPhysicalAbuse'
                 THEN FAPV.SHORTANSWERVALUE END) AS ALLEGED_PERP_PHYS_ABUSE

    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] FAPV
    WHERE FAPV.DESIGNGUID = '94b3f530-a918-4f33-85c2-0ae355c9c2fd'
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND ISNULL(FAPV.DESIGNSUBNAME, '?') IN ('Reassessment', 'Single assessment')
      AND EXISTS (
            SELECT 1
            FROM [SSD].[ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(VARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.DATESTARTED,
        FAPV.DATECOMPLETED
)
INSERT INTO [SSD].[ssd_assessment_factors] (
    cinf_table_id,
    cinf_assessment_id,
    cinf_assessment_factors_json
)
SELECT
    CONVERT(NVARCHAR(48), CONCAT(NEF.PERSONID, NEF.INSTANCEID)) AS cinf_table_id,
    NEF.INSTANCEID                                             AS cinf_assessment_id,
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
                    (CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%RAD%'     THEN '24A' END)
                ) V(code)
                WHERE V.code IS NOT NULL
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
        '')
        + ']'
    ) AS cinf_assessment_factors_json
FROM NEF;