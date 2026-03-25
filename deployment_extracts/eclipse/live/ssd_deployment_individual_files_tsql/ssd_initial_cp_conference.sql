-- META-CONTAINER: {"type": "table", "name": "ssd_initial_cp_conference"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - FORMANSWERPERSONVIEW
-- - PERSONVIEW
-- - CLASSIFICATIONPERSONVIEW
-- - RELATIONSHIPPROFESSIONALVIEW
-- - PERSONORGRELATIONSHIPVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_initial_cp_conference', 'U') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;

IF OBJECT_ID('ssd_initial_cp_conference', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_initial_cp_conference)
        TRUNCATE TABLE ssd_initial_cp_conference;
END
ELSE
BEGIN
    CREATE TABLE ssd_initial_cp_conference (
        icpc_icpc_id              NVARCHAR(48)  NOT NULL PRIMARY KEY,
        icpc_icpc_meeting_id      NVARCHAR(48)  NULL,
        icpc_s47_enquiry_id       NVARCHAR(48)  NULL,
        icpc_person_id            NVARCHAR(48)  NULL,
        icpc_cp_plan_id           NVARCHAR(48)  NULL,
        icpc_referral_id          NVARCHAR(48)  NULL,
        icpc_icpc_transfer_in     NCHAR(1)      NULL,
        icpc_icpc_target_date     DATETIME      NULL,
        icpc_icpc_date            DATETIME      NULL,
        icpc_icpc_outcome_cp_flag NCHAR(1)      NULL,
        icpc_icpc_outcome_json    NVARCHAR(1000) NULL,
        icpc_icpc_team            NVARCHAR(48)  NULL,
        icpc_icpc_worker_id       NVARCHAR(100) NULL
    );
END

;WITH BANK_HOLIDAYS AS (
    SELECT CAST(v.d AS DATE) AS bh_date
    FROM (VALUES
        ('2016-01-01'),('2016-03-25'),('2016-03-28'),('2016-05-02'),('2016-05-30'),('2016-08-29'),('2016-12-26'),('2016-12-27'),
        ('2017-01-02'),('2017-04-14'),('2017-04-17'),('2017-05-01'),('2017-05-29'),('2017-08-28'),('2017-12-25'),('2017-12-26'),
        ('2018-01-01'),('2018-03-30'),('2018-04-02'),('2018-05-07'),('2018-05-28'),('2018-08-27'),('2018-12-25'),('2018-12-26'),
        ('2019-01-01'),('2019-04-19'),('2019-04-22'),('2019-05-06'),('2019-05-27'),('2019-08-26'),('2019-12-25'),('2019-12-26'),
        ('2020-01-01'),('2020-04-10'),('2020-04-13'),('2020-05-04'),('2020-05-25'),('2020-08-31'),('2020-12-25'),('2020-12-28'),
        ('2020-12-29'),('2020-12-30'),('2020-12-31'),
        ('2021-01-01'),('2021-04-02'),('2021-04-05'),('2021-05-03'),('2021-05-31'),('2021-08-30'),('2021-12-27'),('2021-12-28'),
        ('2021-12-29'),('2021-12-30'),('2021-12-31'),
        ('2022-01-03'),('2022-04-15'),('2022-04-18'),('2022-05-02'),('2022-06-02'),('2022-06-03'),('2022-08-29'),('2022-12-26'),
        ('2022-12-27'),('2022-12-28'),('2022-12-29'),('2022-12-30'),
        ('2023-01-02'),('2023-04-07'),('2023-04-10'),('2023-05-01'),('2023-05-08'),('2023-05-29'),('2023-08-28'),('2023-12-25'),
        ('2023-12-26'),('2023-12-27'),('2023-12-28'),('2023-12-29'),
        ('2024-01-01'),('2024-03-29'),('2024-04-01'),('2024-05-06'),('2024-05-27'),('2024-08-26'),('2024-12-25'),('2024-12-26'),
        ('2024-12-27'),('2024-12-30'),('2024-12-31'),
        ('2025-01-01'),('2025-04-18'),('2025-04-21'),('2025-05-05'),('2025-05-26'),('2025-08-25'),('2025-12-25'),('2025-12-26')
    ) v(d)
),
NUMS AS (
    SELECT TOP (DATEDIFF(DAY, CAST('2016-01-01' AS DATE), CAST(GETDATE() AS DATE)) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
CALENDAR AS (
    SELECT
        DATEADD(DAY, n, CAST('2016-01-01' AS DATE)) AS [date],
        CASE
            WHEN (DATEDIFF(DAY, CAST('19000101' AS DATE), DATEADD(DAY, n, CAST('2016-01-01' AS DATE))) % 7) IN (5,6) THEN 0
            WHEN EXISTS (SELECT 1 FROM BANK_HOLIDAYS bh WHERE bh.bh_date = DATEADD(DAY, n, CAST('2016-01-01' AS DATE))) THEN 0
            ELSE 1
        END AS is_working_day
    FROM NUMS
),
WORKING_DAY_RANKS AS (
    SELECT
        c.[date],
        SUM(c.is_working_day) OVER (ORDER BY c.[date] ROWS UNBOUNDED PRECEDING) AS [rank]
    FROM CALENDAR c
),
INITIAL_ASSESSMENT AS (
    SELECT *
    FROM (
        SELECT DISTINCT
            CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS instanceid,
            CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS personid,
            CAST(FAPV.DATECOMPLETED AS DATE)              AS completiondate,
            MAX(CASE WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                     THEN TRY_CONVERT(DATE, FAPV.ANSWERVALUE) END) AS date_of_meeting,
            MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_typeOfMeeting'
                     THEN FAPV.ANSWERVALUE END) AS meeting_type,
            MAX(CASE WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
                     THEN FAPV.ANSWERVALUE END) AS next_step
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
    ) x
    WHERE x.meeting_type IN (
        'Child Protection (Initial child protection conference)',
        'Child Protection (Transfer in conference)'
    )
),
ASSESSMENT47 AS (
    SELECT *
    FROM (
        SELECT
            CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS instanceid,
            CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS personid,
            MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
                     THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS startdate,
            CAST(FAPV.DATECOMPLETED AS DATE)              AS completiondate,
            MAX(CASE WHEN FAPV.CONTROLNAME IN ('CINCensus_unsubWhatNeedsToHappenNext','CINCensus_whatNeedsToHappenNext')
                     THEN FAPV.ANSWERVALUE END) AS outcome
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de')
          AND FAPV.INSTANCESTATE = 'COMPLETE'
          AND EXISTS (
                SELECT 1
                FROM ssd_person sp
                WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
          )
        GROUP BY
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID,
            FAPV.DATECOMPLETED
    ) y
    WHERE y.outcome = 'Convene initial child protection conference'
),
STRATEGY_DISC AS (
    SELECT
        sd.instanceid,
        sd.personid,
        sd.meeting_date,
        tarr.[date] AS target_date
    FROM (
        SELECT
            CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS instanceid,
            CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS personid,
            MAX(CASE WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
                     THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS meeting_date
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('f9a86a19-ea09-41f0-9403-a88e2b0e738a')
          AND FAPV.INSTANCESTATE = 'COMPLETE'
          AND EXISTS (
                SELECT 1
                FROM ssd_person sp
                WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
          )
        GROUP BY
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID
    ) sd
    LEFT JOIN WORKING_DAY_RANKS sdr
        ON sdr.[date] = sd.meeting_date
    LEFT JOIN WORKING_DAY_RANKS tarr
        ON tarr.[rank] = ISNULL(sdr.[rank], 0) + 15
),
CIN_EPISODE_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID)                   AS personid,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS episodeid,
        CAST(CLA.STARTDATE AS DATE)                           AS startdate,
        CAST(CLA.ENDDATE   AS DATE)                           AS enddate,
        CLA.ENDREASON                                          AS endreason
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND CLA.CLASSIFICATIONPATHID IN (23, 10)
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA.PERSONID)
      )
),
CIN_EPISODE_ORDERED AS (
    SELECT
        b.*,
        CASE
            WHEN b.startdate >= LAG(b.startdate) OVER (PARTITION BY b.personid ORDER BY b.startdate, CASE WHEN b.enddate IS NULL THEN 1 ELSE 0 END, b.enddate)
             AND b.startdate <= DATEADD(DAY, 1, ISNULL(LAG(b.enddate) OVER (PARTITION BY b.personid ORDER BY b.startdate, CASE WHEN b.enddate IS NULL THEN 1 ELSE 0 END, b.enddate), CAST(GETDATE() AS DATE)))
                THEN 0
            ELSE 1
        END AS next_start_flag
    FROM CIN_EPISODE_BASE b
),
CIN_EPISODE_GROUPED AS (
    SELECT
        o.*,
        SUM(o.next_start_flag) OVER (PARTITION BY o.personid ORDER BY o.startdate, o.episodeid ROWS UNBOUNDED PRECEDING) AS grp,
        CASE WHEN o.next_start_flag = 1 THEN o.episodeid END AS episode_id
    FROM CIN_EPISODE_ORDERED o
),
CIN_EPISODE AS (
    SELECT
        personid AS cine_person_id,
        MIN(startdate) AS cine_referral_date,
        CASE WHEN MAX(CASE WHEN enddate IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL ELSE MAX(enddate) END AS cine_close_date,
        MAX(endreason) AS cine_close_reason,
        MIN(episode_id) AS cine_referral_id
    FROM CIN_EPISODE_GROUPED
    GROUP BY personid, grp
),
CP_PLAN AS (
    SELECT
        CONVERT(NVARCHAR(48), cp_plan.CLASSIFICATIONASSIGNMENTID) AS planid,
        CONVERT(NVARCHAR(48), cp_plan.PERSONID)                   AS personid,
        CAST(cp_plan.STARTDATE AS DATE)                           AS plan_start_date,
        CAST(cp_plan.ENDDATE   AS DATE)                           AS plan_end_date,
        ce.cine_referral_id
    FROM CLASSIFICATIONPERSONVIEW cp_plan
    OUTER APPLY (
        SELECT TOP (1)
            cine_referral_id
        FROM CIN_EPISODE
        WHERE CIN_EPISODE.cine_person_id = CONVERT(NVARCHAR(48), cp_plan.PERSONID)
          AND CIN_EPISODE.cine_referral_date <= CAST(cp_plan.STARTDATE AS DATE)
        ORDER BY CIN_EPISODE.cine_referral_date DESC
    ) ce
    WHERE cp_plan.CLASSIFICATIONPATHID = 51
      AND cp_plan.STATUS NOT IN ('DELETED')
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), cp_plan.PERSONID)
      )
),
WORKER AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.PERSONRELATIONSHIPRECORDID)        AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)                          AS personid,
        CONVERT(NVARCHAR(100), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS allocated_worker,
        CAST(PPR.STARTDATE AS DATE)                                  AS worker_start_date,
        CAST(PPR.CLOSEDATE AS DATE)                                  AS worker_end_date
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW'
),
TEAM AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.RELATIONSHIPID)   AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)         AS personid,
        CONVERT(NVARCHAR(48), PPR.ORGANISATIONID)   AS allocated_team,
        CAST(PPR.DATESTARTED AS DATE)               AS team_start_date,
        CAST(PPR.DATEENDED   AS DATE)               AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
)
INSERT INTO ssd_initial_cp_conference (
    icpc_icpc_id,
    icpc_icpc_meeting_id,
    icpc_s47_enquiry_id,
    icpc_person_id,
    icpc_cp_plan_id,
    icpc_referral_id,
    icpc_icpc_transfer_in,
    icpc_icpc_target_date,
    icpc_icpc_date,
    icpc_icpc_outcome_cp_flag,
    icpc_icpc_outcome_json,
    icpc_icpc_team,
    icpc_icpc_worker_id
)
SELECT
    CONVERT(NVARCHAR(48), CONCAT(ia.instanceid, ia.personid)) AS icpc_icpc_id,
    ia.instanceid AS icpc_icpc_meeting_id,
    a47.instanceid AS icpc_s47_enquiry_id,
    ia.personid AS icpc_person_id,
    cpp.planid AS icpc_cp_plan_id,
    cpp.cine_referral_id AS icpc_referral_id,
    CASE WHEN ia.meeting_type = 'Child Protection (Transfer in conference)' THEN 'Y' ELSE 'N' END AS icpc_icpc_transfer_in,
    CAST(sd.target_date AS DATETIME) AS icpc_icpc_target_date,
    CAST(ia.date_of_meeting AS DATETIME) AS icpc_icpc_date,
    CASE WHEN ia.next_step = 'Set next review' THEN 'Y' ELSE 'N' END AS icpc_icpc_outcome_cp_flag,
    CONVERT(NVARCHAR(1000),
        '{'
        + '"OUTCOME_NFA_FLAG":"' + CASE WHEN ia.next_step = 'Case closure' OR ia.next_step IS NULL THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG":"",'
        + '"OUTCOME_SINGLE_ASSESSMENT_FLAG":"",'
        + '"OUTCOME_PROV_OF_SERVICES_FLAG":"",'
        + '"OUTCOME_CP_FLAG":"' + CASE WHEN ia.next_step = 'Set next review' THEN 'Y' ELSE 'N' END + '",'
        + '"OTHER_OUTCOMES_EXIST_FLAG":"' + CASE WHEN ia.next_step = 'CIN' THEN 'Y' ELSE 'N' END + '",'
        + '"TOTAL_NO_OF_OUTCOMES":"",'
        + '"OUTCOME_COMMENTS":""'
        + '}'
    ) AS icpc_icpc_outcome_json,
    ta.allocated_team AS icpc_icpc_team,
    wa.allocated_worker AS icpc_icpc_worker_id
FROM INITIAL_ASSESSMENT ia
OUTER APPLY (
    SELECT TOP (1) *
    FROM ASSESSMENT47
    WHERE ASSESSMENT47.personid = ia.personid
      AND ASSESSMENT47.startdate <= ia.date_of_meeting
    ORDER BY ASSESSMENT47.startdate DESC
) a47
OUTER APPLY (
    SELECT TOP (1) *
    FROM STRATEGY_DISC
    WHERE STRATEGY_DISC.personid = ia.personid
      AND STRATEGY_DISC.meeting_date <= ia.date_of_meeting
    ORDER BY STRATEGY_DISC.meeting_date DESC
) sd
OUTER APPLY (
    SELECT TOP (1) *
    FROM CP_PLAN
    WHERE CP_PLAN.personid = ia.personid
      AND ia.date_of_meeting <= CP_PLAN.plan_start_date
    ORDER BY CP_PLAN.plan_start_date
) cpp
OUTER APPLY (
    SELECT TOP (1) W.allocated_worker
    FROM WORKER W
    WHERE W.personid = ia.personid
      AND ia.date_of_meeting >= W.worker_start_date
      AND ia.date_of_meeting < ISNULL(W.worker_end_date, CAST(GETDATE() AS DATE))
    ORDER BY W.worker_start_date DESC
) wa
OUTER APPLY (
    SELECT TOP (1) T.allocated_team
    FROM TEAM T
    WHERE T.personid = ia.personid
      AND ia.date_of_meeting >= T.team_start_date
      AND ia.date_of_meeting < ISNULL(T.team_end_date, CAST(GETDATE() AS DATE))
    ORDER BY T.team_start_date DESC
) ta
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = ia.personid
);