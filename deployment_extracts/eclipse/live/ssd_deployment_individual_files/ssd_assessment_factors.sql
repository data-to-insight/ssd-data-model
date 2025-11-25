-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_assessment_factors;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_assessment_factors (
    cinf_table_id                VARCHAR(48)  NOT NULL,
    cinf_assessment_id           VARCHAR(48)  NOT NULL,
    cinf_assessment_factors_json TEXT         NULL,
    CONSTRAINT pk_ssd_assessment_factors PRIMARY KEY (cinf_table_id, cinf_assessment_id)
);

TRUNCATE TABLE ssd_assessment_factors;

INSERT INTO ssd_assessment_factors (
    cinf_table_id,
    cinf_assessment_id,
    cinf_assessment_factors_json
)
-- WITH EXCLUSIONS AS (
--     SELECT
--         PV.PERSONID
--     FROM PERSONVIEW PV
--     WHERE PV.PERSONID IN (  -- hard filter admin or test or duplicate records on system
--             1,2,3,4,5,6
--         )
--         OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
--         OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
--         OR UPPER(PV.SURNAME)  LIKE '%DUPLICATE%'
-- )
SELECT
    CONCAT(NEF.PERSONID, NEF.INSTANCEID) AS cinf_table_id,        -- metadata={"item_ref":"CINF003A"}
    NEF.INSTANCEID                       AS cinf_assessment_id,   -- metadata={"item_ref":"CINF001A"}
    JSON_BUILD_ARRAY(
        CASE WHEN NEF.ALCOHOL_CHILD IS NOT NULL                    THEN '1A' END,
        CASE WHEN NEF.ALCOHOL_PARENT IS NOT NULL                   THEN '1B' END,
        CASE WHEN NEF.ALCOHOL_OTHER_PERSON_HOUSEHOLD IS NOT NULL   THEN '1C' END,
        CASE WHEN NEF.DRUG_CHILD IS NOT NULL                       THEN '2A' END,
        CASE WHEN NEF.DRUG_PARENT IS NOT NULL                      THEN '2B' END,
        CASE WHEN NEF.DRUG_OTHER_PERSON_HOUSEHOLD IS NOT NULL      THEN '2C' END,
        CASE WHEN NEF.DOMESTIC_CHILD IS NOT NULL                   THEN '3A' END,
        CASE WHEN NEF.DOMESTIC_PARENT IS NOT NULL                  THEN '3B' END,
        CASE WHEN NEF.DOMESTIC_OTHER_PERSON_HOUSEHOLD IS NOT NULL  THEN '3C' END,
        CASE WHEN NEF.MENTAL_HEALTH_CHILD IS NOT NULL              THEN '4A' END,
        CASE WHEN NEF.MENTAL_HEALTH_PARENT IS NOT NULL             THEN '4B' END,
        CASE WHEN NEF.MENTAL_HEALTH_OTHER_PERSON IS NOT NULL       THEN '4C' END,
        CASE WHEN NEF.LEARN_DIS_CHILD IS NOT NULL                  THEN '5A' END,
        CASE WHEN NEF.LEARN_DIS_PARENT IS NOT NULL                 THEN '5B' END,
        CASE WHEN NEF.LEARN_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '5C' END,
        CASE WHEN NEF.PHYS_DIS_CHILD IS NOT NULL                   THEN '6A' END,
        CASE WHEN NEF.PHYS_DIS_PARENT IS NOT NULL                  THEN '6B' END,
        CASE WHEN NEF.PHYS_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL  THEN '6C' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%YCarer%'  THEN '7A' END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOther%'
             AND NEF.CHILD_SPECIFIC_FACTOR LIKE '%Privately fostered - Other%'
                THEN '8F' 
        END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFUKFamily%'         THEN '8E' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFUKEducation%'      THEN '8D' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOCIntendtostay%'   THEN '8C' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOCIntendtoreturn%' THEN '8B' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%UASC%'               THEN '9A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Miss%'               THEN '10A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexExploit%'         THEN '11A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Traffic%'            THEN '12A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Gang%'               THEN '13A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Behave%'             THEN '14A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SHarm%'              THEN '15A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%AbuseNeglect%'       THEN '16A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%EmotAbuse%'          THEN '17A' END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PhysAbuse%' 
             AND NEF.ALLEGED_PERP_PHYS_ABUSE LIKE '%18B%' 
                THEN '18B' 
        END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PhysAbuse%' 
             AND NEF.ALLEGED_PERP_PHYS_ABUSE LIKE '%18C%' 
                THEN '18C' 
        END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexAbuse%' 
             AND NEF.ALLEGED_PERP_SEXUAL_ABUSE LIKE '%19B%' 
                THEN '19B' 
        END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexAbuse%' 
             AND NEF.ALLEGED_PERP_SEXUAL_ABUSE LIKE '%19C%' 
                THEN '19C' 
        END,
        CASE 
            WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Other%'
             AND NEF.CHILD_SPECIFIC_FACTOR NOT LIKE '%Privately fostered - Other%'
                THEN '20' 
        END,
        CASE
            WHEN NEF.ALCOHOL_CHILD IS NULL
             AND NEF.ALCOHOL_OTHER_PERSON_HOUSEHOLD IS NULL
             AND NEF.ALCOHOL_PARENT IS NULL
             AND NEF.CHILD_SPECIFIC_FACTOR IS NULL
             AND NEF.DOMESTIC_CHILD IS NULL
             AND NEF.DOMESTIC_OTHER_PERSON_HOUSEHOLD IS NULL
             AND NEF.DOMESTIC_PARENT IS NULL
             AND NEF.DRUG_CHILD IS NULL
             AND NEF.DRUG_OTHER_PERSON_HOUSEHOLD IS NULL
             AND NEF.DRUG_PARENT IS NULL
             AND NEF.LEARN_DIS_CHILD IS NULL
             AND NEF.LEARN_DIS_OTHER_PERSON_HOUSEHOLD IS NULL
             AND NEF.LEARN_DIS_PARENT IS NULL
             AND NEF.MENTAL_HEALTH_CHILD IS NULL
             AND NEF.MENTAL_HEALTH_OTHER_PERSON IS NULL
             AND NEF.MENTAL_HEALTH_PARENT IS NULL
             AND NEF.PHYS_DIS_CHILD IS NULL
             AND NEF.PHYS_DIS_OTHER_PERSON_HOUSEHOLD IS NULL
             AND NEF.PHYS_DIS_PARENT IS NULL
                THEN '21'
        END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%FGM%'   THEN '22A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Faith%' THEN '23A' END,
        CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%RAD%'   THEN '24A' END
    )::TEXT AS cinf_assessment_factors_json                   -- metadata={"item_ref":"CINF002A"}
FROM (
    SELECT DISTINCT
        FAPV.ANSWERFORSUBJECTID PERSONID,
        FAPV.INSTANCEID,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholChild') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS ALCOHOL_CHILD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholOtherPersonHousehold') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS ALCOHOL_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholParent') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS ALCOHOL_PARENT,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticChild') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DOMESTIC_CHILD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticOtherPersonHousehold') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DOMESTIC_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticParent') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DOMESTIC_PARENT,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_drugChild') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DRUG_CHILD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_drugOtherPersonHousehold') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DRUG_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_drugParent')
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS DRUG_PARENT,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisChild') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS LEARN_DIS_CHILD,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisOtherPersonHousehold') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS LEARN_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisParent') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS LEARN_DIS_PARENT,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthChild')
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS MENTAL_HEALTH_CHILD,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthOtherPerson') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS MENTAL_HEALTH_OTHER_PERSON,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthParent') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS MENTAL_HEALTH_PARENT,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisChild') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS PHYS_DIS_CHILD,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisOtherPersonHousehold') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS PHYS_DIS_OTHER_PERSON_HOUSEHOLD,
        MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisParent') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS PHYS_DIS_PARENT,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_childSpecificFactor') 
                THEN FAPV.ANSWERVALUE 
            ELSE NULL 
        END) AS CHILD_SPECIFIC_FACTOR,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_childSpecificFactor') 
                THEN FAPV.SHORTANSWERVALUE 
            ELSE NULL 
        END) AS CHILD_SPECIFIC_FACTOR_SHORT,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_allegedPerpetratorOfSexualAbuse') 
                THEN FAPV.SHORTANSWERVALUE 
            ELSE NULL 
        END) AS ALLEGED_PERP_SEXUAL_ABUSE,
        MAX(CASE 
            WHEN FAPV.CONTROLNAME IN ('CINCensus_allegedPerpetratorOfPhysicalAbuse') 
                THEN FAPV.SHORTANSWERVALUE 
            ELSE NULL 
        END) AS ALLEGED_PERP_PHYS_ABUSE
    FROM FORMANSWERPERSONVIEW FAPV -- [REVIEW] GUID must match (LA to review/update)
    -- Child: Assessment
    WHERE FAPV.DESIGNGUID = '94b3f530-a918-4f33-85c2-0ae355c9c2fd'   -- Child: Assessment
      AND FAPV.INSTANCESTATE IN ('COMPLETE')
      AND FAPV.CONTROLNAME IN (
            'advocacyOffered','WorkerOutcome','AnnexAReturn_typeOfAssessment','WorkerOutcome',
            'CINCensus_startDateOfForm',
            'CINCensus_alcoholChild','CINCensus_alcoholOtherPersonHousehold','CINCensus_alcoholParent',
            'CINCensus_childSpecificFactor',
            'CINCensus_domesticChild','CINCensus_domesticOtherPersonHousehold','CINCensus_domesticParent',
            'CINCensus_drugChild','CINCensus_drugOtherPersonHousehold','CINCensus_drugParent',
            'CINCensus_learnDisChild','CINCensus_learnDisOtherPersonHousehold','CINCensus_learnDisParent',
            'CINCensus_mentalHealthChild','CINCensus_mentalHealthOtherPerson','CINCensus_mentalHealthParent',
            'CINCensus_physDisChild','CINCensus_physDisOtherPersonHousehold','CINCensus_physDisParent',
            'advocacyAccepted',
            'CINCensus_allegedPerpetratorOfSexualAbuse','CINCensus_allegedPerpetratorOfPhysicalAbuse'
        )
      AND COALESCE(FAPV.DESIGNSUBNAME,'?') IN (
            'Reassessment',
            'Single assessment'
        )
    -- back check person exists in ssd_person cohort, exclusions applied
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = FAPV.ANSWERFORSUBJECTID
        )
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.DATESTARTED,
        FAPV.DATECOMPLETED
) NEF;
