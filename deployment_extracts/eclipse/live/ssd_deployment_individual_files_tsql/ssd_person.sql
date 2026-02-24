-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. 
-- Author: D2I
-- Version:
--             0.1: new RH
-- Status: [R]elease
-- Remarks: [EA_API_PRIORITY_TABLE]

-- Dependencies:
-- - PERSONVIEW
-- - PERSONDEMOGRAPHICSVIEW
-- - REFERENCENUMBERPERSONVIEW
-- - CLASSIFICATION, CLASSIFICATION_GROUP, CLASSIFICATION_ASSIGNMENT
-- - SUBJECT_CLASSIFICATION_ASSIGNM, PERSON_CLASSIFICATION_ASSIGNME
-- - PERSON_PER_RELATIONSHIP, RELATIONSHIP_TYPE
-- =============================================================================


/* META-ELEMENT: {"type": "drop_table"} */
IF OBJECT_ID('tempdb..#ssd_person', 'U') IS NOT NULL DROP TABLE #ssd_person;

IF OBJECT_ID('ssd_development.ssd_person', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_person)
        TRUNCATE TABLE ssd_development.ssd_person;
END
ELSE
BEGIN
    /* META-ELEMENT: {"type": "create_table"} */
    CREATE TABLE ssd_development.ssd_person (
        pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A", "info": "Legacy systems identifier. Common to SystemC"}
        pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}
        pers_upn                NVARCHAR(13),               -- metadata={"item_ref":"PERS006A"}
        pers_forename           NVARCHAR(100),              -- metadata={"item_ref":"PERS015A"}
        pers_surname            NVARCHAR(255),              -- metadata={"item_ref":"PERS016A"}
        pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A"}
        pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A"}
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


/* Cohort filter list, optional
   Replace placeholders with real IDs, adjust type if PERSONID is numeric on your system
*/
DECLARE @allowed_persons TABLE (personid NVARCHAR(48) NOT NULL PRIMARY KEY);
INSERT INTO @allowed_persons (personid)
VALUES
    (N'EG111111'), (N'EG222222'), (N'EG333333');  -- swap to live record IDs, or delete these rows to disable filtering


/* META-ELEMENT: {"type": "insert_data"} */
INSERT INTO ssd_development.ssd_person (
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
;WITH EXCLUSIONS AS (
    SELECT PV.PERSONID
    FROM PERSONVIEW PV
    WHERE
        PV.PERSONID IN (1,2,3,4,5,6)
        OR ISNULL(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME)  LIKE '%DUPLICATE%'
),
UPN AS (
    SELECT
        RNPV.PERSONID,
        RNPV.REFERENCENUMBER AS UPN,
        ROW_NUMBER() OVER (
            PARTITION BY RNPV.PERSONID
            ORDER BY
                CASE WHEN RNPV.ENDDATE IS NULL THEN 0 ELSE 1 END,
                RNPV.ENDDATE DESC,
                RNPV.STARTDATE DESC
        ) AS RN
    FROM REFERENCENUMBERPERSONVIEW RNPV
    WHERE RNPV.REFERENCETYPECODE = 'UPN'
),
UN_UPN_BASE AS (
    SELECT DISTINCT
        PCA.PERSON_FK AS PERSONID,
        CLA.CODE      AS CLASSIFICATION_CODE,
        CAST(CLA_ASSIGN.START_DATE AS DATE) AS START_DATE,
        CAST(CLA_ASSIGN.END_DATE   AS DATE) AS END_DATE,
        DENSE_RANK() OVER (
            PARTITION BY PCA.PERSON_FK
            ORDER BY COALESCE(CLA_ASSIGN.END_DATE, SYSDATETIME()) DESC,
                     CLA_ASSIGN.START_DATE DESC
        ) AS RN
    FROM CLASSIFICATION CLA
    INNER JOIN CLASSIFICATION_GROUP CG
        ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
    INNER JOIN CLASSIFICATION_ASSIGNMENT CLA_ASSIGN
        ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
       AND ISNULL(CLA_ASSIGN.STATUS, '?') NOT IN ('DELETED')
    INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ
        ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
    INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA
        ON PCA.ID = CLA_SUBJ.ID
    WHERE CG.ID = 2
      AND CLA.CODE IN ('UN1','UN2','UN3','UN4','UN5')
),
UN_UPN AS (
    SELECT
        B.PERSONID,
        STUFF((
            SELECT ', ' + B2.CLASSIFICATION_CODE
            FROM UN_UPN_BASE B2
            WHERE B2.PERSONID = B.PERSONID
              AND B2.RN = 1
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS UN_UPN
    FROM UN_UPN_BASE B
    WHERE B.RN = 1
    GROUP BY B.PERSONID
),
UASC AS (
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
       AND ISNULL(CLA_ASSIGN.STATUS, '?') NOT IN ('DELETED')
    INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ
        ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
    INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA
        ON PCA.ID = CLA_SUBJ.ID
    WHERE UPPER(CG.CODE) = 'ASY_STAT'
      AND CLA.ID = 423
),
MOTHER AS (
    SELECT DISTINCT
        PV2.PERSONID
    FROM PERSONDEMOGRAPHICSVIEW PV
    INNER JOIN PERSON_PER_RELATIONSHIP PPR
        ON (PV.PERSONID = PPR.ROLE_A_PERSON_FK OR PV.PERSONID = PPR.ROLE_B_PERSON_FK)
    INNER JOIN PERSONVIEW PV2
        ON (PPR.ROLE_B_PERSON_FK = PV2.PERSONID OR PPR.ROLE_A_PERSON_FK = PV2.PERSONID)
    INNER JOIN RELATIONSHIP_TYPE RT
        ON PPR.PERSON_PER_REL_TYPE_FK = RT.ID
       AND RT.ID IN (17)
    WHERE PV.PERSONID <> ISNULL(PV2.PERSONID, 0)
      AND ISNULL(PV.DATEOFBIRTH, CAST(GETDATE() AS DATE)) >= PV2.DATEOFBIRTH
      AND PV2.GENDER = 'Female'
)
SELECT DISTINCT
    CONVERT(NVARCHAR(48), P.CAREFIRSTID)  AS pers_legacy_id,        -- PERS014A
    CONVERT(NVARCHAR(48), P.PERSONID)     AS pers_person_id,        -- PERS001A
    CONVERT(NVARCHAR(13), U.UPN)          AS pers_upn,              -- PERS006A
    CONVERT(NVARCHAR(100), P.FORENAME)    AS pers_forename,         -- PERS015A
    CONVERT(NVARCHAR(255), P.SURNAME)     AS pers_surname,          -- PERS016A

    CASE
        WHEN P.SEX = 'Male'   THEN 'M'
        WHEN P.SEX = 'Female' THEN 'F'
        ELSE 'U'
    END                                   AS pers_sex,             -- PERS002A

    CASE
        WHEN P.GENDER = 'Man'   THEN '01'
        WHEN P.GENDER = 'Woman' THEN '02'
        WHEN P.GENDER IS NULL   THEN '00'
        ELSE '09'
    END                                   AS pers_gender,          -- PERS003A

    CASE
        WHEN P.ETHNICITYCODE = 'ARAB' THEN 'ORAB'
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
    END                                   AS pers_ethnicity,       -- PERS004A

    COALESCE(
        P.DATEOFBIRTH,
        CASE
            WHEN P.DATEOFBIRTH IS NULL AND P.DUEDATE >= SYSDATETIME()
                THEN P.DUEDATE
        END
    )                                     AS pers_dob,             -- PERS005A

    CONVERT(NVARCHAR(48), P.NHSNUMBER)    AS pers_single_unique_id, -- PERS013A

    COALESCE(
        U.UPN,
        UU.UN_UPN,
        CASE
            WHEN P.DATEOFBIRTH IS NOT NULL
                 AND (
                     DATEDIFF(YEAR, P.DATEOFBIRTH, COALESCE(P.DIEDDATE, SYSDATETIME()))
                     - CASE
                           WHEN DATEADD(YEAR, DATEDIFF(YEAR, P.DATEOFBIRTH, COALESCE(P.DIEDDATE, SYSDATETIME())), P.DATEOFBIRTH)
                                > COALESCE(P.DIEDDATE, SYSDATETIME())
                               THEN 1
                           ELSE 0
                       END
                 ) < 5
                THEN 'UN1'
            WHEN UASCPERSON.PERSONID IS NOT NULL
                THEN 'UN2'
        END
    )                                     AS pers_upn_unknown,     -- PERS007A

    NULL                                  AS pers_send_flag,       -- PERS008A

    CASE
        WHEN P.DUEDATE >= SYSDATETIME()
            THEN P.DUEDATE
    END                                   AS pers_expected_dob,    -- PERS009A

    P.DIEDDATE                            AS pers_death_date,      -- PERS010A

    CASE
        WHEN M.PERSONID IS NOT NULL THEN 'Y'
        ELSE 'N'
    END                                   AS pers_is_mother,       -- PERS011A

    CONVERT(NVARCHAR(48), P.COUNTRYOFBIRTHCODE) AS pers_nationality -- PERS012A

FROM PERSONDEMOGRAPHICSVIEW P
LEFT JOIN UPN U
    ON P.PERSONID = U.PERSONID
   AND U.RN = 1
LEFT JOIN UN_UPN UU
    ON P.PERSONID = UU.PERSONID
LEFT JOIN (
    SELECT *
    FROM UASC
    WHERE RN = 1
      AND COALESCE(END_DATE, CAST(GETDATE() AS DATE)) >= CAST(GETDATE() AS DATE)
      AND START_DATE <= CAST(GETDATE() AS DATE)
) UASCPERSON
    ON P.PERSONID = UASCPERSON.PERSONID
LEFT JOIN MOTHER M
    ON P.PERSONID = M.PERSONID
WHERE
    NOT EXISTS (SELECT 1 FROM EXCLUSIONS E WHERE E.PERSONID = P.PERSONID)
    AND (
        NOT EXISTS (SELECT 1 FROM @allowed_persons)
        OR CONVERT(NVARCHAR(48), P.PERSONID) IN (SELECT personid FROM @allowed_persons)
    );
