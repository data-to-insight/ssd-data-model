-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: 
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]    
-- Dependencies: 
-- - CLASSIFICATIONPERSONVIEW
-- - CLAEPISODEOFCAREVIEW
-- - FORMANSWERPERSONVIEW
-- - ssd_person
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cin_episodes', 'U') IS NOT NULL
    DROP TABLE #ssd_cin_episodes;

IF OBJECT_ID('[ssd_cin_episodes]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_cin_episodes])
        TRUNCATE TABLE [ssd_cin_episodes];
END
ELSE
BEGIN
    CREATE TABLE [ssd_cin_episodes]
    (
        cine_referral_id           NVARCHAR(48)   NOT NULL PRIMARY KEY,
        cine_person_id             NVARCHAR(48)   NULL,
        cine_referral_date         DATETIME       NULL,
        cine_cin_primary_need_code NVARCHAR(3)    NULL,
        cine_referral_source_code  NVARCHAR(48)   NULL,
        cine_referral_source_desc  NVARCHAR(255)  NULL,
        cine_referral_outcome_json NVARCHAR(4000) NULL,
        cine_referral_nfa          NCHAR(1)        NULL,
        cine_close_reason          NVARCHAR(100)  NULL,
        cine_close_date            DATETIME       NULL,
        cine_referral_team         NVARCHAR(48)   NULL,
        cine_referral_worker_id    NVARCHAR(100)  NULL
    );
END;

;WITH ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS EPISODEID,
        CAST(CLA.STARTDATE AS DATE) AS EPISODE_STARTDATE,
        CAST(CLA.ENDDATE   AS DATE) AS EPISODE_ENDDATE,
        CLA.ENDREASON
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
    WHERE CLA.STATUS <> 'DELETED'
      AND (CLA.CLASSIFICATIONPATHID IN (4,51) OR CLA.CLASSIFICATIONCODEID = 1270)

    UNION ALL

    SELECT
        CONVERT(NVARCHAR(48), CE.PERSONID),
        CONVERT(NVARCHAR(48), CE.EPISODEOFCAREID),
        CAST(CE.EOCSTARTDATE AS DATE),
        CAST(CE.EOCENDDATE   AS DATE),
        CE.EOCENDREASON
    FROM [eclipseDelta].[dbo].[CLAEPISODEOFCAREVIEW] CE
),
REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), F.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), F.INSTANCEID)        AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), F.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN F.CONTROLNAME = 'CINCensus_ReferralSource' THEN F.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN F.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed' THEN F.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN F.CONTROLNAME = 'CINCensus_primaryNeedCategory' THEN F.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN F.CONTROLNAME = 'CINCensus_DateOfReferral'
                 THEN CAST(F.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] F
    WHERE F.DESIGNGUID = 'e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f'
      AND F.INSTANCESTATE = 'COMPLETE'
    GROUP BY F.ANSWERFORSUBJECTID, F.INSTANCEID, F.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE RB.PRIMARY_NEED_CAT
            WHEN 'Abuse or neglect'                THEN 'N1'
            WHEN 'Child''s disability'             THEN 'N2'
            WHEN 'Parental illness/disability'     THEN 'N3'
            WHEN 'Family in acute stress'          THEN 'N4'
            WHEN 'Family dysfunction'              THEN 'N5'
            WHEN 'Socially unacceptable behaviour' THEN 'N6'
            WHEN 'Low income'                      THEN 'N7'
            WHEN 'Absent parenting'                THEN 'N8'
            WHEN 'Cases other than child in need'  THEN 'N9'
            WHEN 'Not stated'                      THEN 'N0'
        END AS PRIMARY_NEED_RANK
    FROM REFERRAL_BASE RB
),
EPISODES_ORDERED AS (
    SELECT
        A.*,
        CASE
            WHEN A.EPISODE_STARTDATE >= LAG(A.EPISODE_STARTDATE)
                 OVER (PARTITION BY A.PERSONID ORDER BY A.EPISODE_STARTDATE)
             AND A.EPISODE_STARTDATE <= DATEADD(DAY, 1,
                     ISNULL(LAG(A.EPISODE_ENDDATE)
                     OVER (PARTITION BY A.PERSONID ORDER BY A.EPISODE_STARTDATE),
                     CAST(GETDATE() AS DATE)))
                THEN 0
            ELSE 1
        END AS NEXT_START_FLAG
    FROM ALL_CIN_EPISODES A
),
EPISODES_GROUPED AS (
    SELECT
        EO.*,
        SUM(EO.NEXT_START_FLAG)
            OVER (PARTITION BY EO.PERSONID ORDER BY EO.EPISODE_STARTDATE) AS EPISODE_GRP
    FROM EPISODES_ORDERED EO
),
CIN_BASE AS (
    SELECT
        PERSONID,
        EPISODE_GRP,
        MIN(EPISODE_STARTDATE) AS CINE_START_DATE,
        CASE WHEN MAX(CASE WHEN EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END) = 1
             THEN NULL ELSE MAX(EPISODE_ENDDATE) END AS CINE_CLOSE_DATE
    FROM EPISODES_GROUPED
    GROUP BY PERSONID, EPISODE_GRP
),
CIN_EPISODE AS (
    SELECT
        CB.PERSONID,
        CB.CINE_START_DATE,
        CB.CINE_CLOSE_DATE,
        R.ASSESSMENTID,
        CONVERT(NVARCHAR(48), CONCAT(CB.PERSONID, R.ASSESSMENTID)) AS REFERRALID,
        R.DATE_OF_REFERRAL,
        R.PRIMARY_NEED_RANK,
        R.SUBMITTERPERSONID,
        R.REFERRAL_SOURCE,
        R.NEXT_STEP
    FROM CIN_BASE CB
    OUTER APPLY (
        SELECT TOP (1) *
        FROM REFERRAL R
        WHERE R.PERSONID = CB.PERSONID
          AND R.DATE_OF_REFERRAL <= CB.CINE_START_DATE
        ORDER BY R.DATE_OF_REFERRAL DESC
    ) R
)
INSERT INTO [ssd_cin_episodes]
SELECT *
FROM CIN_EPISODE CE
WHERE EXISTS (
    SELECT 1
    FROM [ssd_person] sp
    WHERE sp.pers_person_id = CONVERT(VARCHAR(48), CE.PERSONID)
);