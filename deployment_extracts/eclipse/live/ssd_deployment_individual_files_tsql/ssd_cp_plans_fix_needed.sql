-- META-CONTAINER: {"type": "table", "name": "ssd_cp_plans"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - FORMANSWERPERSONVIEW
-- - CLASSIFICATIONPERSONVIEW
-- - CLAEPISODEOFCAREVIEW
-- - ssd_person
-- Notes: 030626 FAIL TEST RB|RH 
-- =============================================================================
IF OBJECT_ID('tempdb..#ssd_cp_plans', 'U') IS NOT NULL
    DROP TABLE #ssd_cp_plans;

IF OBJECT_ID('ssd_cp_plans', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_cp_plans])
        TRUNCATE TABLE [ssd_cp_plans];
END
ELSE
BEGIN
    CREATE TABLE [ssd_cp_plans] (
        cppl_cp_plan_id               NVARCHAR(48)  NOT NULL PRIMARY KEY, -- metadata={"item_ref":"CPPL001A"}
        cppl_referral_id              NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL007A"}
        cppl_icpc_id                  NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL008A"}
        cppl_person_id                NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL002A"}
        cppl_cp_plan_start_date       DATETIME      NULL,                 -- metadata={"item_ref":"CPPL003A"}
        cppl_cp_plan_end_date         DATETIME      NULL,                 -- metadata={"item_ref":"CPPL004A"}
        cppl_cp_plan_ola              NCHAR(1)      NULL,                 -- metadata={"item_ref":"CPPL011A"}
        cppl_cp_plan_initial_category NVARCHAR(100) NULL,                 -- metadata={"item_ref":"CPPL009A"}
        cppl_cp_plan_latest_category  NVARCHAR(100) NULL                  -- metadata={"item_ref":"CPPL010A"}
    );
END;

;WITH INITIAL_ASSESSMENT AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS INSTANCEID,
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CAST(FAPV.DATECOMPLETED AS DATE)               AS DATE_COMPLETED,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                    THEN TRY_CONVERT(DATE, FAPV.ANSWERVALUE)
            END
        ) AS DATE_OF_MEETING
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] FAPV
    WHERE FAPV.DESIGNGUID = '21e01e2e-fd65-439d-a8aa-a179106a3d45'
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child Protection - Initial Conference'
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
    GROUP BY
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID,
        FAPV.DATECOMPLETED
),
CP_CATEGORY AS (
    SELECT
        CONVERT(NVARCHAR(48), CPV.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(100), CPV.NAME)    AS NAME,
        CAST(CPV.STARTDATE AS DATE)         AS STARTDATE,
        CAST(CPV.ENDDATE   AS DATE)         AS ENDDATE
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CPV
    WHERE CPV.CLASSIFICATIONPATHID = 81
      AND CPV.STATUS <> 'DELETED'
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), CPV.PERSONID)
      )
),
ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS PERSONID,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS EPISODEID,
        CAST(CLA.STARTDATE AS DATE)                           AS EPISODE_STARTDATE,
        CAST(CLA.ENDDATE   AS DATE)                           AS EPISODE_ENDDATE,
        CLA.ENDREASON                                         AS ENDREASON
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
    WHERE CLA.STATUS <> 'DELETED'
      AND (CLA.CLASSIFICATIONPATHID IN (4, 51)
           OR CLA.CLASSIFICATIONCODEID = 1270)
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), CLA.PERSONID)
      )

    UNION ALL

    SELECT
        CONVERT(NVARCHAR(48), CE.PERSONID),
        CONVERT(NVARCHAR(48), CE.EPISODEOFCAREID),
        CAST(CE.EOCSTARTDATE AS DATE),
        CAST(CE.EOCENDDATE   AS DATE),
        CE.EOCENDREASON
    FROM [eclipseDelta].[dbo].[CLAEPISODEOFCAREVIEW] CE
    WHERE EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), CE.PERSONID)
      )
),
REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), FAPV.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'
                 THEN FAPV.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
                 THEN FAPV.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
                 THEN FAPV.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'
                 THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] FAPV
    WHERE FAPV.DESIGNGUID = 'e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f'
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.SUBMITTERPERSONID
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
        ACE.*,
        CASE
            WHEN ACE.EPISODE_STARTDATE >=
                 LAG(ACE.EPISODE_STARTDATE)
                    OVER (PARTITION BY ACE.PERSONID ORDER BY ACE.EPISODE_STARTDATE)
             AND ACE.EPISODE_STARTDATE <=
                 DATEADD(
                    DAY, 1,
                    ISNULL(
                        LAG(ACE.EPISODE_ENDDATE)
                            OVER (PARTITION BY ACE.PERSONID ORDER BY ACE.EPISODE_STARTDATE),
                        CAST(GETDATE() AS DATE)
                    )
                 )
                THEN 0
            ELSE 1
        END AS NEXT_START_FLAG
    FROM ALL_CIN_EPISODES ACE
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
        CASE
            WHEN MAX(CASE WHEN EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END) = 1
                THEN NULL
            ELSE MAX(EPISODE_ENDDATE)
        END AS CINE_CLOSE_DATE
    FROM EPISODES_GROUPED
    GROUP BY PERSONID, EPISODE_GRP
),
CIN_EPISODE AS (
    SELECT
        CB.PERSONID,
        CB.CINE_START_DATE,
        CB.CINE_CLOSE_DATE,
        CONVERT(NVARCHAR(48), CONCAT(CB.PERSONID, R.ASSESSMENTID)) AS REFERRALID,
        R.DATE_OF_REFERRAL
    FROM CIN_BASE CB
    OUTER APPLY (
        SELECT TOP (1)
            ASSESSMENTID,
            DATE_OF_REFERRAL
        FROM REFERRAL R
        WHERE R.PERSONID = CB.PERSONID
          AND R.DATE_OF_REFERRAL <= CB.CINE_START_DATE
        ORDER BY R.DATE_OF_REFERRAL DESC
    ) R
),
CP_PLAN_ROWS AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS CLAID,
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS PERSONID,
        CAST(CLA.STARTDATE AS DATE) AS STARTDATE,
        CAST(CLA.ENDDATE   AS DATE) AS ENDDATE,
        CASE
            WHEN LAG(CAST(CLA.STARTDATE AS DATE))
                 OVER (PARTITION BY CLA.PERSONID ORDER BY CAST(CLA.STARTDATE AS DATE))
                 IS NULL
                THEN 1
            ELSE 0
        END AS NEXT_START_FLAG
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
    WHERE CLA.STATUS <> 'DELETED'
      AND CLA.CLASSIFICATIONPATHID = 51
      AND EXISTS (
            SELECT 1
            FROM [ssd_person] sp
            WHERE sp.pers_person_id =
                  CONVERT(NVARCHAR(48), CLA.PERSONID)
      )
),
CP_PLAN_TAGGED AS (
    SELECT
        CPR.*,
        SUM(CPR.NEXT_START_FLAG)
            OVER (PARTITION BY CPR.PERSONID ORDER BY CPR.STARTDATE) AS GRP
    FROM CP_PLAN_ROWS CPR
),
CP_PLAN AS (
    SELECT
        MIN(CLAID)     AS CLAID,
        PERSONID,
        MIN(STARTDATE) AS STARTDATE,
        MAX(ENDDATE)   AS ENDDATE
    FROM CP_PLAN_TAGGED
    GROUP BY PERSONID, GRP
)
INSERT INTO [ssd_cp_plans] (
    cppl_cp_plan_id,
    cppl_referral_id,
    cppl_icpc_id,
    cppl_person_id,
    cppl_cp_plan_start_date,
    cppl_cp_plan_end_date,
    cppl_cp_plan_ola,
    cppl_cp_plan_initial_category,
    cppl_cp_plan_latest_category
)
SELECT
    CP.CLAID,
    CE.REFERRALID,
    IA.INSTANCEID,
    CP.PERSONID,
    CAST(CP.STARTDATE AS DATETIME),
    CAST(CP.ENDDATE   AS DATETIME),
    NULL,
    CFIRST.NAME,
    CLATEST.NAME
FROM CP_PLAN CP
OUTER APPLY (
    SELECT TOP (1)
        INSTANCEID,
        DATE_OF_MEETING
    FROM INITIAL_ASSESSMENT IA
    WHERE IA.PERSONID = CP.PERSONID
      AND IA.DATE_OF_MEETING <= CP.STARTDATE
    ORDER BY IA.DATE_OF_MEETING DESC
) IA
OUTER APPLY (
    SELECT TOP (1)
        REFERRALID,
        DATE_OF_REFERRAL,
        CINE_CLOSE_DATE
    FROM CIN_EPISODE CE
    WHERE CE.PERSONID = CP.PERSONID
      AND CE.DATE_OF_REFERRAL <= CP.STARTDATE
      AND CP.STARTDATE <= ISNULL(CE.CINE_CLOSE_DATE, CAST(GETDATE() AS DATE))
    ORDER BY CE.DATE_OF_REFERRAL DESC
) CE
OUTER APPLY (
    SELECT TOP (1) NAME
    FROM CP_CATEGORY
    WHERE PERSONID = CP.PERSONID
      AND STARTDATE <= CP.STARTDATE
    ORDER BY STARTDATE DESC
) CLATEST
OUTER APPLY (
    SELECT TOP (1) NAME
    FROM CP_CATEGORY
    WHERE PERSONID = CP.PERSONID
      AND STARTDATE <= CP.STARTDATE
    ORDER BY STARTDATE ASC
) CFIRST
WHERE EXISTS (
    SELECT 1
    FROM [ssd_person] sp
    WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CP.PERSONID)
);

