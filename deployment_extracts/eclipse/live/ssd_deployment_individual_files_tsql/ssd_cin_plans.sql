-- META-CONTAINER: {"type": "table", "name": "ssd_cin_plans"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - RELATIONSHIPPROFESSIONALVIEW
-- - PERSONORGRELATIONSHIPVIEW
-- - CLASSIFICATIONPERSONVIEW
-- - CLAEPISODEOFCAREVIEW
-- - FORMANSWERPERSONVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;

IF OBJECT_ID('ssd_cin_plans', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_plans)
        TRUNCATE TABLE ssd_cin_plans;
END
ELSE
BEGIN
    CREATE TABLE ssd_cin_plans (
        cinp_cin_plan_id         NVARCHAR(48)  NOT NULL PRIMARY KEY,
        cinp_referral_id         NVARCHAR(48)  NULL,
        cinp_person_id           NVARCHAR(48)  NULL,
        cinp_cin_plan_start_date DATETIME      NULL,
        cinp_cin_plan_end_date   DATETIME      NULL,
        cinp_cin_plan_team       NVARCHAR(48)  NULL,
        cinp_cin_plan_worker_id  NVARCHAR(100) NULL
    );
END;

;WITH WORKER AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.PERSONRELATIONSHIPRECORDID)       AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)                         AS personid,
        CONVERT(NVARCHAR(100), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS allocated_worker,
        CAST(PPR.STARTDATE AS DATE)                                 AS worker_start_date,
        CAST(PPR.CLOSEDATE AS DATE)                                 AS worker_end_date
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE PPR.ALLOCATEDWORKERCODE = 'AW'
),
TEAM AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.RELATIONSHIPID) AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)       AS personid,
        CONVERT(NVARCHAR(48), PPR.ORGANISATIONID) AS allocated_team,
        CAST(PPR.DATESTARTED AS DATE)             AS team_start_date,
        CAST(PPR.DATEENDED   AS DATE)             AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE PPR.ALLOCATEDTEAMCODE = 'AT'
),
ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS EPISODEID,
        CAST(CLA.STARTDATE AS DATE) AS EPISODE_STARTDATE,
        CAST(CLA.ENDDATE   AS DATE) AS EPISODE_ENDDATE,
        CLA.ENDREASON
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND (CLA.CLASSIFICATIONPATHID IN (4, 51) OR CLA.CLASSIFICATIONCODEID IN (1270))

    UNION ALL

    SELECT
        CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(48), CLA_EPISODE.EPISODEOFCAREID) AS EPISODEID,
        CAST(CLA_EPISODE.EOCSTARTDATE AS DATE) AS EPISODE_STARTDATE,
        CAST(CLA_EPISODE.EOCENDDATE   AS DATE) AS EPISODE_ENDDATE,
        CLA_EPISODE.EOCENDREASON AS ENDREASON
    FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
),
REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS personid,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS assessmentid,
        CONVERT(NVARCHAR(100), FAPV.SUBMITTERPERSONID) AS submitterpersonid,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource' THEN FAPV.ANSWERVALUE END) AS referral_source,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed' THEN FAPV.ANSWERVALUE END) AS next_step,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory' THEN FAPV.ANSWERVALUE END) AS primary_need_cat,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral' THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS date_of_referral
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE
            WHEN RB.primary_need_cat = 'Abuse or neglect'                THEN 'N1'
            WHEN RB.primary_need_cat = 'Child''s disability'             THEN 'N2'
            WHEN RB.primary_need_cat = 'Parental illness/disability'     THEN 'N3'
            WHEN RB.primary_need_cat = 'Family in acute stress'          THEN 'N4'
            WHEN RB.primary_need_cat = 'Family dysfunction'              THEN 'N5'
            WHEN RB.primary_need_cat = 'Socially unacceptable behaviour' THEN 'N6'
            WHEN RB.primary_need_cat = 'Low income'                      THEN 'N7'
            WHEN RB.primary_need_cat = 'Absent parenting'                THEN 'N8'
            WHEN RB.primary_need_cat = 'Cases other than child in need'  THEN 'N9'
            WHEN RB.primary_need_cat = 'Not stated'                      THEN 'N0'
        END AS primary_need_rank
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
        END AS CINE_CLOSE_DATE,
        MAX(EG.EPISODE_ID) AS LAST_CINE_ID
    FROM EPISODES_GROUPED EG
    GROUP BY EG.PERSONID, EG.EPISODE_GRP
),
CIN_EPISODE AS (
    SELECT
        CB.PERSONID,
        CB.CINE_START_DATE,
        CB.CINE_CLOSE_DATE,
        ACE.ENDREASON AS CINE_REASON_END,
        RA.assessmentid,
        CONVERT(NVARCHAR(48), CONCAT(CB.PERSONID, RA.assessmentid)) AS referralid,
        CAST(RA.date_of_referral AS DATE) AS date_of_referral,
        RA.primary_need_rank,
        RA.submitterpersonid,
        RA.referral_source,
        RA.next_step
    FROM CIN_BASE CB
    LEFT JOIN ALL_CIN_EPISODES ACE
           ON ACE.PERSONID = CB.PERSONID
          AND ACE.EPISODE_ENDDATE = CB.CINE_CLOSE_DATE
    OUTER APPLY (
        SELECT TOP (1)
            R.personid,
            R.assessmentid,
            R.submitterpersonid,
            R.referral_source,
            R.next_step,
            R.primary_need_rank,
            R.date_of_referral
        FROM REFERRAL R
        WHERE R.personid = CB.PERSONID
          AND R.date_of_referral <= CB.CINE_START_DATE
        ORDER BY R.date_of_referral DESC
    ) RA
),
CIN_PLAN_ROWS AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS claid,
        CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS personid,
        CAST(CLA.STARTDATE AS DATE)                           AS startdate,
        CAST(CLA.ENDDATE   AS DATE)                           AS enddate,
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
        END AS next_start_flag
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND (CLA.CLASSIFICATIONPATHID IN (4) OR CLA.CLASSIFICATIONCODEID IN (1270))
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
        )
),
CIN_PLAN_TAGGED AS (
    SELECT
        CPR.*,
        SUM(CPR.next_start_flag) OVER (
            PARTITION BY CPR.personid
            ORDER BY CPR.startdate ROWS UNBOUNDED PRECEDING
        ) AS episode_grp
    FROM CIN_PLAN_ROWS CPR
),
CIN_PLAN AS (
    SELECT
        MIN(CT.claid)     AS claid,
        CT.personid,
        MIN(CT.startdate) AS startdate,
        CASE
            WHEN MAX(CASE WHEN CT.enddate IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL
            ELSE MAX(CT.enddate)
        END AS enddate
    FROM CIN_PLAN_TAGGED CT
    GROUP BY CT.personid, CT.episode_grp
)
INSERT INTO ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT
    CP.claid AS cinp_cin_plan_id,
    CE.referralid AS cinp_referral_id,
    CP.personid AS cinp_person_id,
    CAST(CP.startdate AS DATETIME) AS cinp_cin_plan_start_date,
    CAST(CP.enddate   AS DATETIME) AS cinp_cin_plan_end_date,
    TA.allocated_team AS cinp_cin_plan_team,
    WA.allocated_worker AS cinp_cin_plan_worker_id
FROM CIN_PLAN CP
OUTER APPLY (
    SELECT TOP (1)
        W.allocated_worker
    FROM WORKER W
    WHERE W.personid = CP.personid
      AND ISNULL(CP.enddate, CAST(GETDATE() AS DATE)) > W.worker_start_date
      AND CP.startdate < ISNULL(W.worker_end_date, CAST(GETDATE() AS DATE))
    ORDER BY W.worker_start_date DESC
) WA
OUTER APPLY (
    SELECT TOP (1)
        T.allocated_team
    FROM TEAM T
    WHERE T.personid = CP.personid
      AND ISNULL(CP.enddate, CAST(GETDATE() AS DATE)) > T.team_start_date
      AND CP.startdate < ISNULL(T.team_end_date, CAST(GETDATE() AS DATE))
    ORDER BY T.team_start_date DESC
) TA
OUTER APPLY (
    SELECT TOP (1)
        E.referralid
    FROM CIN_EPISODE E
    WHERE E.personid = CP.personid
      AND CP.startdate >= E.date_of_referral
      AND CP.startdate <= ISNULL(E.cine_close_date, CAST(GETDATE() AS DATE))
    ORDER BY E.date_of_referral DESC
) CE;