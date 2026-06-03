
-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. 
-- Author: D2I
-- Version: 0.3 Refactor RH
--          0.2 Fixed run order and ; use 
--          0.1: new RH
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]

-- Dependencies:
-- - PERSONVIEW
-- - PERSONDEMOGRAPHICSVIEW
-- - REFERENCENUMBERPERSONVIEW
-- - CLASSIFICATION, CLASSIFICATION_GROUP, CLASSIFICATION_ASSIGNMENT
-- - SUBJECT_CLASSIFICATION_ASSIGNM, PERSON_CLASSIFICATION_ASSIGNME
-- - PERSON_PER_RELATIONSHIP, RELATIONSHIP_TYPE
-- Notes: 030626 FAIL TEST RB|RH 
-- =============================================================================


/* META-ELEMENT: {"type": "drop_table"} */
IF OBJECT_ID('tempdb..#ssd_person', 'U') IS NOT NULL DROP TABLE #ssd_person;

IF OBJECT_ID('ssd_person', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_person])
        TRUNCATE TABLE [ssd_person];
END
ELSE
BEGIN
    /* META-ELEMENT: {"type": "create_table"} */
    CREATE TABLE [ssd_person] (
        pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A", "info": "Legacy systems identifier. Common to SystemC"}
        pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}
        pers_upn                NVARCHAR(13),               -- metadata={"item_ref":"PERS006A"}
        pers_forename           NVARCHAR(100),              -- metadata={"item_ref":"PERS015A"}
        pers_surname            NVARCHAR(255),              -- metadata={"item_ref":"PERS016A"}
        pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A", "info": "Eclipse: SEX==GENDER==SEX"}
        pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "info": "Eclipse: GENDER==SEX==GENDER"}
        pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"}
        pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"}
        pers_single_unique_id   NVARCHAR(48),               -- metadata={"item_ref":"PERS013A"}
        pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A"}
        pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A"}
        pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}
        pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"}
        pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
        pers_nationality        NVARCHAR(48)                -- metadata={"item_ref":"PERS012A"}
    );
END

/* META-ELEMENT: {"type": "insert_data"} */
;WITH PERSON_BASE AS (
    SELECT 
        P.*,
        CONVERT(NVARCHAR(48), P.PERSONID) AS PERSONID_STR
    FROM eclipseDelta.dbo.PERSONDEMOGRAPHICSVIEW P
),

CLASS_BASE AS (
    SELECT
        PCA.PERSON_FK AS PERSONID,
        CLA.ID,
        CLA.CODE,
        CG.ID AS GROUP_ID,
        CG.CODE AS GROUP_CODE,
        CLA_ASSIGN.START_DATE,
        CLA_ASSIGN.END_DATE
    FROM eclipseDelta.dbo.CLASSIFICATION CLA
    JOIN eclipseDelta.dbo.CLASSIFICATION_GROUP CG
        ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
    JOIN eclipseDelta.dbo.CLASSIFICATION_ASSIGNMENT CLA_ASSIGN
        ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
       AND ISNULL(CLA_ASSIGN.STATUS,'?') <> 'DELETED'
    JOIN eclipseDelta.dbo.SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ
        ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
    JOIN eclipseDelta.dbo.PERSON_CLASSIFICATION_ASSIGNME PCA
        ON PCA.ID = CLA_SUBJ.ID
),

UPN AS (
    SELECT
        CONVERT(NVARCHAR(48), PERSONID) AS PERSONID,
        REFERENCENUMBER AS UPN,
        ROW_NUMBER() OVER (
            PARTITION BY PERSONID
            ORDER BY
                CASE WHEN ENDDATE IS NULL THEN 0 ELSE 1 END,
                ENDDATE DESC,
                STARTDATE DESC
        ) AS RN
    FROM eclipseDelta.dbo.REFERENCENUMBERPERSONVIEW
    WHERE REFERENCETYPECODE = 'UPN'
),

UN_UPN_BASE AS (
    SELECT
        PERSONID,
        CODE,
        DENSE_RANK() OVER (
            PARTITION BY PERSONID
            ORDER BY COALESCE(END_DATE, SYSDATETIME()) DESC,
                     START_DATE DESC
        ) AS RN
    FROM CLASS_BASE
    WHERE GROUP_ID = 2
      AND CODE IN ('UN1','UN2','UN3','UN4','UN5')
),

/* =================================================================
   UN_UPN aggregation (uncomment legacy opt 2 if on pre-'17 version)
   ================================================================= */

-- =============================================
-- OPT 1: STRING_AGG (SQL Server 2017+)
-- =============================================
UN_UPN AS (
    SELECT
        PERSONID,
        STRING_AGG(CODE, ', ') WITHIN GROUP (ORDER BY CODE) AS UN_UPN
    FROM UN_UPN_BASE
    WHERE RN = 1
    GROUP BY PERSONID
),

/*
-- =============================================
-- OPT 2: LEGACY (pre-2017 fallback)
-- =============================================
UN_UPN AS (
    SELECT
        B.PERSONID,
        STUFF((
            SELECT ', ' + B2.CODE
            FROM UN_UPN_BASE B2
            WHERE B2.PERSONID = B.PERSONID
              AND B2.RN = 1
            ORDER BY B2.CODE
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS UN_UPN
    FROM UN_UPN_BASE B
    WHERE B.RN = 1
    GROUP BY B.PERSONID
),
*/

UASC AS (
    SELECT
        PERSONID,
        START_DATE,
        END_DATE,
        ROW_NUMBER() OVER (
            PARTITION BY PERSONID
            ORDER BY START_DATE DESC
        ) AS RN
    FROM CLASS_BASE
    WHERE GROUP_CODE = 'ASY_STAT'
      AND ID = 423
),

MOTHER AS (
    SELECT
        CONVERT(NVARCHAR(48), PV2.PERSONID) AS PERSONID
    FROM eclipseDelta.dbo.PERSONDEMOGRAPHICSVIEW PV
    JOIN eclipseDelta.dbo.PERSON_PER_RELATIONSHIP PPR
        ON PV.PERSONID = PPR.ROLE_A_PERSON_FK
    JOIN eclipseDelta.dbo.PERSONVIEW PV2
        ON PPR.ROLE_B_PERSON_FK = PV2.PERSONID
    JOIN eclipseDelta.dbo.RELATIONSHIP_TYPE RT
        ON PPR.PERSON_PER_REL_TYPE_FK = RT.ID
       AND RT.ID = 17
    WHERE PV.PERSONID <> PV2.PERSONID
      AND ISNULL(PV.DATEOFBIRTH, CAST(GETDATE() AS DATE)) >= PV2.DATEOFBIRTH
      AND PV2.GENDER = 'Female'
),

CLASS_FILTER AS (
    SELECT PERSONID
    FROM CLASS_BASE
    WHERE GROUP_ID IN (17,21,43,50)
      AND END_DATE IS NULL
    GROUP BY PERSONID
)

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

SELECT
    CONVERT(NVARCHAR(48), P.CAREFIRSTID),
    P.PERSONID_STR,
    CONVERT(NVARCHAR(13), U.UPN),
    CONVERT(NVARCHAR(100), P.FORENAME),
    CONVERT(NVARCHAR(255), P.SURNAME),

    CASE
        WHEN P.SEX = 'Male'   THEN 'M'
        WHEN P.SEX = 'Female' THEN 'F'
        ELSE 'U'
    END,

    CASE
        WHEN P.GENDER = 'Man'   THEN '01'
        WHEN P.GENDER = 'Woman' THEN '02'
        WHEN P.GENDER IS NULL   THEN '00'
        ELSE '09'
    END,

    CASE
        WHEN P.ETHNICITYCODE = 'ARAB' THEN 'ORAB'
        WHEN P.ETHNICITYCODE = 'BANGLADESHI' THEN 'ABAN'
        WHEN P.ETHNICITYCODE = 'INDIAN' THEN 'AIND'
        WHEN P.ETHNICITYCODE = 'OTHER_ASIAN' THEN 'AOTH'
        WHEN P.ETHNICITYCODE = 'ENG_SCOT_TRAVELLER' THEN 'AOTH'
        WHEN P.ETHNICITYCODE = 'PAKISTANI' THEN 'APKN'
        WHEN P.ETHNICITYCODE IN ('AFRICAN','BLACK_AFRICAN') THEN 'BAFR'
        WHEN P.ETHNICITYCODE IN ('BLACK_CARIBBEAN','CARIBBEAN') THEN 'BCRB'
        WHEN P.ETHNICITYCODE IN ('OTHER_BLACK','OTHER_AFRICAN') THEN 'BOTH'
        WHEN P.ETHNICITYCODE = 'CHINESE' THEN 'CNHE'
        WHEN P.ETHNICITYCODE = 'OTHER_MIXED' THEN 'MOTH'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_ASIAN' THEN 'MWAS'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_AFRICAN' THEN 'MWBa'
        WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_CARIBBEAN' THEN 'MWBC'
        WHEN P.ETHNICITYCODE = 'NOT_KNOWN' THEN 'NOBT'
        WHEN P.ETHNICITYCODE = 'OTHER_ETHNIC' THEN 'OOTH'
        WHEN P.ETHNICITYCODE = 'REFUSED' THEN 'REFU'
        WHEN P.ETHNICITYCODE IN ('WHITE_BRITISH','WHITE_NORTHERNIRISH','WHITE_SCOTTISH','WHITE_WELSH') THEN 'WBRI'
        WHEN P.ETHNICITYCODE = 'WHITE_IRISH' THEN 'WIRI'
        WHEN P.ETHNICITYCODE = 'IRISHTRAVELLER' THEN 'WIRT'
        WHEN P.ETHNICITYCODE IN ('OTHER_WHITE_ORIGIN','WHITE_POLISH') THEN 'WOTH'
        WHEN P.ETHNICITYCODE IN ('GYPSY','TRAVELLER','ROMA') THEN 'WROM'
        WHEN P.ETHNICITYCODE IS NULL THEN 'NOBT'
        ELSE '??'
    END,

    COALESCE(P.DATEOFBIRTH, P.DUEDATE),
    CONVERT(NVARCHAR(48), P.NHSNUMBER),
    CASE
        WHEN LEN(COALESCE(U.UPN, UU.UN_UPN)) > 6 
            THEN LEFT(COALESCE(U.UPN, UU.UN_UPN), 6) + '*' -- visible note on truncations for LA ref
        ELSE COALESCE(U.UPN, UU.UN_UPN)
    END
    NULL,
    CASE WHEN P.DUEDATE >= SYSDATETIME() THEN P.DUEDATE END,
    P.DIEDDATE,
    CASE WHEN M.PERSONID IS NOT NULL THEN 'Y' ELSE 'N' END,
    CONVERT(NVARCHAR(48), P.COUNTRYOFBIRTHCODE)

FROM PERSON_BASE P

INNER JOIN CLASS_FILTER CF
    ON CF.PERSONID = P.PERSONID

LEFT JOIN UPN U
    ON P.PERSONID_STR = U.PERSONID
   AND U.RN = 1

LEFT JOIN UN_UPN UU
    ON P.PERSONID = UU.PERSONID

LEFT JOIN (
    SELECT PERSONID
    FROM UASC
    WHERE RN = 1
      AND COALESCE(END_DATE, CAST(GETDATE() AS DATE)) >= CAST(GETDATE() AS DATE)
      AND START_DATE <= CAST(GETDATE() AS DATE)
) UASCPERSON
    ON UASCPERSON.PERSONID = P.PERSONID

LEFT JOIN MOTHER M
    ON M.PERSONID = P.PERSONID_STR
-- WHERE
--     (
--         NOT EXISTS (SELECT 1 FROM @allowed_persons)
--         OR P.PERSONID_STR IN (SELECT personid FROM @allowed_persons)
--     )

;