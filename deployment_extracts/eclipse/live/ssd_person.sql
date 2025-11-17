-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: 
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_person;  -- uncomment only if dropping to apply new structural update(s)

-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- Description: Create ssd_person if not exists
-- =============================================================================

CREATE TABLE IF NOT EXISTS ssd_person (
    pers_legacy_id          VARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"} 
    pers_upn                VARCHAR(13),               -- metadata={"item_ref":"PERS006A"} 
    pers_forename           VARCHAR(100),              -- metadata={"item_ref":"PERS015A"}  
    pers_surname            VARCHAR(255),              -- metadata={"item_ref":"PERS016A"}  
    pers_sex                VARCHAR(20),               -- metadata={"item_ref":"PERS002A", "item_status":"P", "info":"If additional status to Gender is held, otherwise duplicate pers_gender"}    
    pers_gender             VARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"R", "expected_data":["unknown",NULL,"F","U","M","I"]}       
    pers_ethnicity          VARCHAR(48),               -- metadata={"item_ref":"PERS004A", "expected_data":[NULL, "tbc"]} 
    pers_dob                TIMESTAMP,                 -- metadata={"item_ref":"PERS005A"} 
    pers_single_unique_id   VARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
    pers_upn_unknown        VARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
    pers_send_flag          CHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
    pers_expected_dob       TIMESTAMP,                 -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         TIMESTAMP,                 -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          CHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        VARCHAR(48)                -- metadata={"item_ref":"PERS012A", "expected_data":[NULL, "tbc"]}   
);

-- =============================================================================
-- Truncate before reload
-- Safe if there no foreign keys referencing ssd_person
-- =============================================================================
TRUNCATE TABLE ssd_person;

-- =============================================================================
-- Load data into ssd_person
-- =============================================================================

INSERT INTO ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_upn,
    pers_forename,
    pers_surname,
    pers_sex,
    pers_gender,
    pers_ethnicity,
    pers_dob,
    pers_single_unique_id,
    pers_upn_unknown,
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality
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

SELECT DISTINCT
    P.CAREFIRSTID              AS pers_legacy_id,          -- metadata={"item_ref":"PERS014A"}               
    P.PERSONID                 AS pers_person_id,          -- metadata={"item_ref":"PERS001A"}
    UPN.UPN                    AS pers_upn,                -- metadata={"item_ref":"PERS006A"}
    P.FORENAME                 AS pers_forename,           -- metadata={"item_ref":"PERS015A"}  
    P.SURNAME                  AS pers_surname,            -- metadata={"item_ref":"PERS016A"}  
    CASE
        WHEN P.SEX = 'Male'
            THEN 'M'
        WHEN P.SEX = 'Female'
            THEN 'F'
        ELSE 'U'
    END                        AS pers_sex,                -- metadata={"item_ref":"PERS002A"}
    CASE
        WHEN P.GENDER = 'Man'
            THEN '01'
        WHEN P.GENDER = 'Woman'
            THEN '02'
        WHEN P.GENDER IS NULL
            THEN '00'
        ELSE '09'
    END                        AS pers_gender,             -- metadata={"item_ref":"PERS003A"}
    CASE
        WHEN P.ETHNICITYCODE = 'ARAB' THEN '??'
        WHEN P.ETHNICITYCODE = 'BANGLADESHI' THEN 'ABAN'
        WHEN P.ETHNICITYCODE = 'INDIAN' THEN 'AIND'
        WHEN P.ETHNICITYCODE = 'OTHER_ASIAN' THEN 'AOTH'
        WHEN P.ETHNICITYCODE = 'ENG_SCOT_TRAVELLER' THEN 'AOTH'
        WHEN P.ETHNICITYCODE = 'PAKISTANI' THEN 'APKN'
        WHEN P.ETHNICITYCODE = 'AFRICAN' THEN 'BAFR'
        WHEN P.ETHNICITYCODE = 'BLACK_AFRICAN' THEN 'BAFR'
        WHEN P.ETHNICITYCODE = 'BLACK_CARIBBEAN' THEN 'BCRB'
        WHEN P.ETHNICITYCODE = 'CARIBBEAN' THEN 'BCRB'
        WHEN P.ETHNICITYCODE = 'OTHER_BLACK' THEN 'BOTH'
        WHEN P.ETHNICITYCODE = 'OTHER_AFRICAN' THEN 'BOTH'
        WHEN P.ETHNICITYCODE = 'CHINESE' THEN 'CNHE'
        WHEN P.ETHNICITYCODE = 'OTHER_MIXED' THEN 'MOTH'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_ASIAN' THEN 'MWAS'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_AFRICAN' THEN 'MWBa'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_CARIBBEAN' THEN 'MWBC'
        WHEN P.ETHNICITYCODE = 'NOT_KNOWN' THEN 'NOBT'
        WHEN P.ETHNICITYCODE = 'OTHER_ETHNIC' THEN 'OOTH'
        WHEN P.ETHNICITYCODE = 'REFUSED' THEN 'REFU'
        WHEN P.ETHNICITYCODE = 'WHITE_BRITISH' THEN 'WBRI'
        WHEN P.ETHNICITYCODE = 'WHITE_NORTHERNIRISH' THEN 'WBRI'
        WHEN P.ETHNICITYCODE = 'WHITE_SCOTTISH' THEN 'WBRI'
        WHEN P.ETHNICITYCODE = 'WHITE_WELSH' THEN 'WBRI'
        WHEN P.ETHNICITYCODE = 'WHITE_IRISH' THEN 'WIRI'
        WHEN P.ETHNICITYCODE = 'IRISHTRAVELLER' THEN 'WIRT'
        WHEN P.ETHNICITYCODE = 'OTHER_WHITE_ORIGIN' THEN 'WOTH'
        WHEN P.ETHNICITYCODE = 'WHITE_POLISH' THEN 'WOTH'
        WHEN P.ETHNICITYCODE = 'GYPSY' THEN 'WROM'
        WHEN P.ETHNICITYCODE = 'TRAVELLER' THEN 'WROM'
        WHEN P.ETHNICITYCODE = 'ROMA' THEN 'WROM'
        WHEN P.ETHNICITYCODE IS NULL THEN 'NOBT'
        ELSE '??'
    END                        AS pers_ethnicity,          -- metadata={"item_ref":"PERS004A"}
    COALESCE(
        P.DATEOFBIRTH,
        CASE
            WHEN P.DATEOFBIRTH IS NULL AND P.DUEDATE >= CURRENT_TIMESTAMP
                THEN P.DUEDATE
        END
    )                          AS pers_dob,                -- metadata={"item_ref":"PERS005A"}
    P.NHSNUMBER                AS pers_single_unique_id,   -- metadata={"item_ref":"PERS013A"}
    COALESCE(
        UPN.UPN,
        UN_UPN.UN_UPN,
        -- factor in those under 5
        CASE
            WHEN EXTRACT(YEAR FROM AGE(COALESCE(P.DIEDDATE,CURRENT_TIMESTAMP),P.DATEOFBIRTH)) < 5
                THEN 'UN1'
            -- new in care (1 week prior to collection period end)
            -- NEEDS BUILDING IN
            -- WHEN EOC.POCSTARTDATE + interval '1 week' >= C.SUBMISSION_TO
            --     THEN 'UN4'
            -- when UASC
            WHEN UASC.PERSONID IS NOT NULL
                THEN 'UN2'
        END
    )                          AS pers_upn_unknown,        -- metadata={"item_ref":"PERS007A"}
    /* Flag showing if a person has an EHC plan recorded on the system. 
       Code set 
       Y - Has an EHC Plan 
       N - Does not have an EHC Plan  */
    NULL                       AS pers_send_flag,          -- metadata={"item_ref":"PERS008A"}
    CASE
        WHEN P.DUEDATE >= CURRENT_TIMESTAMP
            THEN P.DUEDATE
    END                        AS pers_expected_dob,       -- metadata={"item_ref":"PERS009A"}
    P.DIEDDATE                 AS pers_death_date,         -- metadata={"item_ref":"PERS010A"}
    CASE
        WHEN MOTHER.PERSONID IS NOT NULL
            THEN 'Y'
        ELSE 'N'
    END                        AS pers_is_mother,          -- metadata={"item_ref":"PERS011A"}
    /* Required for UASC, reported in the ADCS Safeguarding Pressures research. */
    P.COUNTRYOFBIRTHCODE       AS pers_nationality         -- metadata={"item_ref":"PERS012A"}
FROM PERSONDEMOGRAPHICSVIEW P
LEFT JOIN (
    SELECT DISTINCT
        RNPV.PERSONID,
        RNPV.REFERENCENUMBER AS UPN,
        -- open on the system first, then followed by the most recent
        ROW_NUMBER() OVER (
            PARTITION BY PERSONID
            ORDER BY COALESCE(RNPV.ENDDATE,CURRENT_TIMESTAMP) DESC, STARTDATE DESC
        ) AS RN
    FROM REFERENCENUMBERPERSONVIEW RNPV
    WHERE RNPV.REFERENCETYPECODE = 'UPN'
) UPN ON P.PERSONID = UPN.PERSONID
   AND UPN.RN = 1
LEFT JOIN (
    SELECT DISTINCT
        A.PERSONID,
        STRING_AGG(A.CLASSIFICATION_CODE, ', ') AS UN_UPN
    FROM (
        SELECT DISTINCT
            PCA.PERSON_FK                AS PERSONID,
            CLA.CODE                     AS CLASSIFICATION_CODE,
            CAST(CLA_ASSIGN.START_DATE AS DATE) AS START_DATE,
            CAST(CLA_ASSIGN.END_DATE   AS DATE) AS END_DATE,
            -- open on the system first, then followed by the most recent, use dense rank here because concerns over DQ
            DENSE_RANK() OVER (
                PARTITION BY PCA.PERSON_FK
                ORDER BY COALESCE(CLA_ASSIGN.END_DATE,CURRENT_TIMESTAMP) DESC,
                         CLA_ASSIGN.START_DATE DESC
            ) AS RN
        FROM CLASSIFICATION CLA
        INNER JOIN CLASSIFICATION_GROUP CG
            ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
        INNER JOIN CLASSIFICATION_ASSIGNMENT CLA_ASSIGN
            ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
           AND COALESCE(CLA_ASSIGN.STATUS,'?') NOT IN ('DELETED')
        INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ
            ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
        INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA
            ON PCA.ID = CLA_SUBJ.ID
        WHERE CG.ID = 2
          AND CLA.CODE IN ('UN1','UN2','UN3','UN4','UN5')
    ) A
    WHERE A.RN = 1
    GROUP BY A.PERSONID
) UN_UPN ON P.PERSONID = UN_UPN.PERSONID
LEFT JOIN (
    SELECT DISTINCT
        PCA.PERSON_FK                AS PERSONID,
        CONCAT(CG.NAME,'/',CLA.NAME) AS CLASSIFICATION,
        CAST(CLA_ASSIGN.START_DATE AS DATE) AS START_DATE,
        CAST(CLA_ASSIGN.END_DATE   AS DATE) AS END_DATE,
        ROW_NUMBER() OVER (
            PARTITION BY PCA.PERSON_FK
            ORDER BY CAST(CLA_ASSIGN.START_DATE AS DATE) DESC
        ) AS RN
    FROM CLASSIFICATION CLA
    INNER JOIN CLASSIFICATION_GROUP CG
        ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
    INNER JOIN CLASSIFICATION_ASSIGNMENT CLA_ASSIGN
        ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
       AND COALESCE(CLA_ASSIGN.STATUS,'?') NOT IN ('DELETED')
    INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ
        ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
    INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA
        ON PCA.ID = CLA_SUBJ.ID
    WHERE UPPER(CG.CODE) = 'ASY_STAT'
      AND CLA.ID = 423                         -- unaccompanied only
) UASC ON P.PERSONID = UASC.PERSONID
   AND UASC.RN = 1
   AND COALESCE(UASC.END_DATE,CURRENT_TIMESTAMP) >= CURRENT_TIMESTAMP
   AND UASC.START_DATE <= CURRENT_TIMESTAMP
LEFT JOIN (
    SELECT DISTINCT
        PV2.PERSONID,
        PV2.CAREFIRSTID,
        PV2.DATEOFBIRTH,
        EXTRACT(YEAR FROM AGE(CURRENT_DATE,PV2.DATEOFBIRTH)) AS AGE_ON_SNAPSHOT,
        EXTRACT(YEAR FROM AGE(PV.DATEOFBIRTH,PV2.DATEOFBIRTH)) AS AGE_AT_CHILD_BIRTH,
        PV2.FORENAME,
        PV2.SURNAME,
        PV.PERSONID               AS CHILD_PERSONID,
        CONCAT(PV.FORENAME,' ',PV.SURNAME) AS CHILD_NAME,
        PV.DATEOFBIRTH            AS CHILD_DOB,
        PPR.START_DATE            AS RELATIONSHIP_START_DATE,
        PPR.CLOSE_DATE            AS RELATIONSHIP_END_DATE,
        CASE
            WHEN CURRENT_DATE BETWEEN PPR.START_DATE AND COALESCE(PPR.CLOSE_DATE,CURRENT_DATE)
                THEN 'Y'
            ELSE 'N'
        END                       AS ACTIVE_RELATIONSHIP,
        RT.ID                     AS RELATIONSHIP_TYPE_ID,
        RT.RELATIONSHIP_CLASS,
        RT.RELATIONSHIP_CLASS_NAME
    FROM PERSONDEMOGRAPHICSVIEW PV
    INNER JOIN PERSON_PER_RELATIONSHIP PPR
        ON (PV.PERSONID = PPR.ROLE_A_PERSON_FK OR PV.PERSONID = PPR.ROLE_B_PERSON_FK)
    INNER JOIN PERSONVIEW PV2
        ON (PPR.ROLE_B_PERSON_FK = PV2.PERSONID OR PPR.ROLE_A_PERSON_FK = PV2.PERSONID)
    INNER JOIN RELATIONSHIP_TYPE RT
        ON PPR.PERSON_PER_REL_TYPE_FK  = RT.ID
       AND RT.ID IN (17)
    WHERE PV.PERSONID <> COALESCE(PV2.PERSONID,0)
      AND COALESCE(PV.DATEOFBIRTH,CURRENT_DATE) >= PV2.DATEOFBIRTH
      AND PV2.GENDER = 'Female'
) MOTHER ON P.PERSONID = MOTHER.PERSONID
WHERE P.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
-- Limit this down to the SSD Cohort if required
/*
WHERE EXISTS (
    -- CIN

)
*/
;
