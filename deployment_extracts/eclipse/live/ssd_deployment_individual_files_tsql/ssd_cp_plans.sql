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
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cp_plans', 'U') IS NOT NULL DROP TABLE #ssd_cp_plans;

IF OBJECT_ID('ssd_cp_plans', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cp_plans)
        TRUNCATE TABLE ssd_cp_plans;
END
ELSE
BEGIN
    CREATE TABLE ssd_cp_plans (
        cppl_cp_plan_id               NVARCHAR(48)  NOT NULL PRIMARY KEY, -- metadata={"item_ref":"CPPL001A"}
        cppl_referral_id              NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL007A"}
        cppl_icpc_id                  NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL008A"}
        cppl_person_id                NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"CPPL002A"}
        cppl_cp_plan_start_date       DATETIME      NULL,                 -- metadata={"item_ref":"CPPL003A"}
        cppl_cp_plan_end_date         DATETIME      NULL,                 -- metadata={"item_ref":"CPPL004A"}
        cppl_cp_plan_ola              NCHAR(1)       NULL,                 -- metadata={"item_ref":"CPPL011A"}
        cppl_cp_plan_initial_category NVARCHAR(100)  NULL,                 -- metadata={"item_ref":"CPPL009A"}
        cppl_cp_plan_latest_category  NVARCHAR(100)  NULL                  -- metadata={"item_ref":"CPPL010A"}
    );
END;

;WITH INITIAL_ASSESSMENT AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS INSTANCEID,
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CAST(FAPV.DATECOMPLETED AS DATE)              AS DATE_COMPLETED,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                    THEN TRY_CONVERT(DATE, FAPV.ANSWERVALUE)
            END) AS DATE_OF_MEETING
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child Protection - Initial Conference'
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
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
    FROM CLASSIFICATIONPERSONVIEW CPV
    WHERE CPV.CLASSIFICATIONPATHID = 81
      AND CPV.STATUS NOT IN ('DELETED')
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CPV.PERSONID)
      )
),
ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS PERSONID,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS EPISODEID,
        CAST(CLA.STARTDATE AS DATE)                           AS EPISODE_STARTDATE,
        CAST(CLA.ENDDATE   AS DATE)                           AS EPISODE_ENDDATE,
        CLA.ENDREASON                                        AS ENDREASON
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND (
            CLA.CLASSIFICATIONPATHID IN (4, 51)
         OR CLA.CLASSIFICATIONCODEID IN (1270)
      )
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
      )

    UNION ALL

    SELECT
        CONVERT(NVARCHAR(48), CLA_EP.PERSONID)       AS PERSONID,
        CONVERT(NVARCHAR(48), CLA_EP.EPISODEOFCAREID) AS EPISODEID,
        CAST(CLA_EP.EOCSTARTDATE AS DATE)            AS EPISODE_STARTDATE,
        CAST(CLA_EP.EOCENDDATE   AS DATE)            AS EPISODE_ENDDATE,
        CLA_EP.EOCENDREASON                           AS ENDREASON
    FROM CLAEPISODEOFCAREVIEW CLA_EP
    WHERE EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA_EP.PERSONID)
      )
),
REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), FAPV.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'      THEN FAPV.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'  THEN FAPV.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'  THEN FAPV.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'       THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE
            WHEN RB.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
            WHEN RB.PRIMARY_NEED_CAT = 'Child''s disability'             THEN 'N2'
            WHEN RB.PRIMARY_NEED_CAT = 'Parental illness/disability'     THEN 'N3'
            WHEN RB.PRIMARY_NEED_CAT = 'Family in acute stress'          THEN 'N4'
            WHEN RB.PRIMARY_NEED_CAT = 'Family dysfunction'              THEN 'N5'
            WHEN RB.PRIMARY_NEED_CAT = 'Socially unacceptable behaviour' THEN 'N6'
            WHEN RB.PRIMARY_NEED_CAT = 'Low income'                      THEN 'N7'
            WHEN RB.PRIMARY_NEED_CAT = 'Absent parenting'                THEN 'N8'
            WHEN RB.PRIMARY_NEED_CAT = 'Cases other than child in need'  THEN 'N9'
            WHEN RB.PRIMARY_NEED_CAT = 'Not stated'                      THEN 'N0'
        END AS PRIMARY_NEED_RANK
    FROM REFERRAL_BASE RB
),
EPISODES_ORDERED AS (
    SELECT
        ACE.PERSONID,
        ACE.EPISODEID,
        ACE.EPISODE_STARTDATE,
        ACE.EPISODE_ENDDATE,
        ACE.ENDREASON,
        CASE
            WHEN ACE.EPISODE_STARTDATE >= LAG(ACE.EPISODE_STARTDATE) OVER (
                    PARTITION BY ACE.PERSONID
                    ORDER BY ACE.EPISODE_STARTDATE,
                             CASE WHEN ACE.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END,
                             ACE.EPISODE_ENDDATE
                 )
             AND ACE.EPISODE_STARTDATE <= DATEADD(
                    DAY, 1,
                    ISNULL(
                        LAG(ACE.EPISODE_ENDDATE) OVER (
                            PARTITION BY ACE.PERSONID
                            ORDER BY ACE.EPISODE_STARTDATE,
                                     CASE WHEN ACE.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END,
                                     ACE.EPISODE_ENDDATE
                        ),
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
        SUM(EO.NEXT_START_FLAG) OVER (
            PARTITION BY EO.PERSONID
            ORDER BY EO.EPISODE_STARTDATE, EO.EPISODEID
        ) AS EPISODE_GRP,
        CASE WHEN EO.NEXT_START_FLAG = 1 THEN EO.EPISODEID END AS EPISODE_ID
    FROM EPISODES_ORDERED EO
),
CIN_BASE AS (
    SELECT
        EG.PERSONID,
        EG.EPISODE_GRP,
        MIN(EG.EPISODE_STARTDATE) AS CINE_START_DATE,
        CASE
            WHEN MAX(CASE WHEN EG.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL
            ELSE MAX(EG.EPISODE_ENDDATE)
        END AS CINE_CLOSE_DATE
    FROM EPISODES_GROUPED EG
    GROUP BY EG.PERSONID, EG.EPISODE_GRP
),
CIN_EPISODE AS (
    SELECT
        CB.PERSONID,
        CB.CINE_START_DATE,
        CB.CINE_CLOSE_DATE,
        CONVERT(NVARCHAR(48), CONCAT(CB.PERSONID, RA.ASSESSMENTID)) AS REFERRALID,
        RA.DATE_OF_REFERRAL,
        RA.ASSESSMENTID
    FROM CIN_BASE CB
    OUTER APPLY (
        SELECT TOP (1)
            R.ASSESSMENTID,
            R.DATE_OF_REFERRAL
        FROM REFERRAL R
        WHERE R.PERSONID = CB.PERSONID
          AND R.DATE_OF_REFERRAL <= CB.CINE_START_DATE
        ORDER BY R.DATE_OF_REFERRAL DESC
    ) RA
),
CP_PLAN_ROWS AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS CLAID,
        CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS PERSONID,
        CAST(CLA.STARTDATE AS DATE)                           AS STARTDATE,
        CAST(CLA.ENDDATE   AS DATE)                           AS ENDDATE,
        CASE
            WHEN CAST(CLA.STARTDATE AS DATE) > LAG(CAST(CLA.STARTDATE AS DATE)) OVER (
                     PARTITION BY CLA.PERSONID
                     ORDER BY CAST(CLA.STARTDATE AS DATE),
                              CASE WHEN CLA.ENDDATE IS NULL THEN 1 ELSE 0 END,
                              CAST(CLA.ENDDATE AS DATE)
                 )
             AND CAST(CLA.STARTDATE AS DATE) <= ISNULL(
                     LAG(CAST(CLA.ENDDATE AS DATE)) OVER (
                         PARTITION BY CLA.PERSONID
                         ORDER BY CAST(CLA.STARTDATE AS DATE),
                                  CASE WHEN CLA.ENDDATE IS NULL THEN 1 ELSE 0 END,
                                  CAST(CLA.ENDDATE AS DATE)
                     ),
                     CAST(GETDATE() AS DATE)
                 )
                THEN 0
            ELSE 1
        END AS NEXT_START_FLAG
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND CLA.CLASSIFICATIONPATHID IN (51)
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
      )
),
CP_PLAN_TAGGED AS (
    SELECT
        CPR.*,
        SUM(CPR.NEXT_START_FLAG) OVER (
            PARTITION BY CPR.PERSONID
            ORDER BY CPR.STARTDATE ROWS UNBOUNDED PRECEDING
        ) AS EPISODE_GRP
    FROM CP_PLAN_ROWS CPR
),
CP_PLAN AS (
    SELECT
        MIN(CT.CLAID)     AS CLAID,
        CT.PERSONID,
        MIN(CT.STARTDATE) AS STARTDATE,
        CASE
            WHEN MAX(CASE WHEN CT.ENDDATE IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL
            ELSE MAX(CT.ENDDATE)
        END AS ENDDATE
    FROM CP_PLAN_TAGGED CT
    GROUP BY CT.PERSONID, CT.EPISODE_GRP
)
INSERT INTO ssd_cp_plans (
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
    CP.CLAID AS cppl_cp_plan_id,
    CE.REFERRALID AS cppl_referral_id,
    IA.INSTANCEID AS cppl_icpc_id,
    CP.PERSONID AS cppl_person_id,
    CAST(CP.STARTDATE AS DATETIME) AS cppl_cp_plan_start_date,
    CAST(CP.ENDDATE   AS DATETIME) AS cppl_cp_plan_end_date,
    NULL AS cppl_cp_plan_ola,
    CFIRST.NAME AS cppl_cp_plan_initial_category,
    CLATEST.NAME AS cppl_cp_plan_latest_category
FROM CP_PLAN CP
OUTER APPLY (
    SELECT TOP (1)
        I.INSTANCEID,
        I.DATE_OF_MEETING
    FROM INITIAL_ASSESSMENT I
    WHERE I.PERSONID = CP.PERSONID
      AND I.DATE_OF_MEETING <= CP.STARTDATE
    ORDER BY I.DATE_OF_MEETING DESC
) IA
OUTER APPLY (
    SELECT TOP (1)
        E.REFERRALID,
        E.DATE_OF_REFERRAL
    FROM CIN_EPISODE E
    WHERE E.PERSONID = CP.PERSONID
      AND E.DATE_OF_REFERRAL <= CP.STARTDATE
      AND CP.STARTDATE <= ISNULL(E.CINE_CLOSE_DATE, CAST(GETDATE() AS DATE))
    ORDER BY E.DATE_OF_REFERRAL DESC
) CE
OUTER APPLY (
    SELECT TOP (1)
        C.NAME
    FROM CP_CATEGORY C
    WHERE C.PERSONID = CP.PERSONID
      AND C.STARTDATE <= CP.STARTDATE
    ORDER BY C.STARTDATE DESC
) CLATEST
OUTER APPLY (
    SELECT TOP (1)
        C.NAME
    FROM CP_CATEGORY C
    WHERE C.PERSONID = CP.PERSONID
      AND C.STARTDATE <= CP.STARTDATE
    ORDER BY C.STARTDATE ASC
) CFIRST
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = CP.PERSONID
);