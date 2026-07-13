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
-- Notes: 030626 FAIL TEST RB|RH 
-- =============================================================================
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference', 'U') IS NOT NULL
    DROP TABLE #ssd_initial_cp_conference;

IF OBJECT_ID('[ssd_initial_cp_conference]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [ssd_initial_cp_conference]
    )
        TRUNCATE TABLE [ssd_initial_cp_conference];
END
ELSE
BEGIN
    CREATE TABLE [ssd_initial_cp_conference] (
        icpc_icpc_id              NVARCHAR(48)   NOT NULL PRIMARY KEY,
        icpc_icpc_meeting_id      NVARCHAR(48)   NULL,
        icpc_s47_enquiry_id       NVARCHAR(48)   NULL,
        icpc_person_id            NVARCHAR(48)   NULL,
        icpc_cp_plan_id           NVARCHAR(48)   NULL,
        icpc_referral_id          NVARCHAR(48)   NULL,
        icpc_icpc_transfer_in     NCHAR(1)       NULL,
        icpc_icpc_target_date     DATETIME       NULL,
        icpc_icpc_date            DATETIME       NULL,
        icpc_icpc_outcome_cp_flag NCHAR(1)       NULL,
        icpc_icpc_outcome_json    NVARCHAR(1000) NULL,
        icpc_icpc_team            NVARCHAR(48)   NULL,
        icpc_icpc_worker_id       NVARCHAR(100)  NULL
    );
END;

;WITH BANK_HOLIDAYS AS (
    SELECT CAST(v.d AS DATE) AS bh_date
    FROM (VALUES
        ('2016-01-01'),('2016-03-25'),('2016-03-28'),('2016-05-02'),
        ('2016-05-30'),('2016-08-29'),('2016-12-26'),('2016-12-27'),
        ('2017-01-02'),('2017-04-14'),('2017-04-17'),('2017-05-01'),
        ('2017-05-29'),('2017-08-28'),('2017-12-25'),('2017-12-26'),
        ('2018-01-01'),('2018-03-30'),('2018-04-02'),('2018-05-07'),
        ('2018-05-28'),('2018-08-27'),('2018-12-25'),('2018-12-26'),
        ('2019-01-01'),('2019-04-19'),('2019-04-22'),('2019-05-06'),
        ('2019-05-27'),('2019-08-26'),('2019-12-25'),('2019-12-26'),
        ('2020-01-01'),('2020-04-10'),('2020-04-13'),('2020-05-04'),
        ('2020-05-25'),('2020-08-31'),('2020-12-25'),('2020-12-28'),
        ('2021-01-01'),('2021-04-02'),('2021-04-05'),('2021-05-03'),
        ('2021-05-31'),('2021-08-30'),('2021-12-27'),('2021-12-28'),
        ('2022-01-03'),('2022-04-15'),('2022-04-18'),('2022-05-02'),
        ('2022-06-02'),('2022-06-03'),('2022-08-29'),('2022-12-26'),
        ('2023-01-02'),('2023-04-07'),('2023-04-10'),('2023-05-01'),
        ('2023-05-08'),('2023-05-29'),('2023-08-28'),('2023-12-25'),
        ('2024-01-01'),('2024-03-29'),('2024-04-01'),('2024-05-06'),
        ('2024-05-27'),('2024-08-26'),('2024-12-25'),('2024-12-26'),
        ('2025-01-01'),('2025-04-18'),('2025-04-21'),('2025-05-05'),
        ('2025-05-26'),('2025-08-25'),('2025-12-25'),('2025-12-26')
    ) v(d)
),
NUMS AS (
    SELECT TOP (DATEDIFF(DAY, '2016-01-01', CAST(GETDATE() AS DATE)) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
CALENDAR AS (
    SELECT
        DATEADD(DAY, n, CAST('2016-01-01' AS DATE)) AS [date],
        CASE
            WHEN DATEPART(WEEKDAY, DATEADD(DAY, n, '2016-01-01')) IN (1,7) THEN 0
            WHEN EXISTS (
                SELECT 1
                FROM BANK_HOLIDAYS bh
                WHERE bh.bh_date = DATEADD(DAY, n, '2016-01-01')
            ) THEN 0
            ELSE 1
        END AS is_working_day
    FROM NUMS
),
WORKING_DAY_RANKS AS (
    SELECT
        [date],
        SUM(is_working_day)
            OVER (ORDER BY [date] ROWS UNBOUNDED PRECEDING) AS [rank]
    FROM CALENDAR
),
INITIAL_ASSESSMENT AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS instanceid,
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS personid,
        CAST(FAPV.DATECOMPLETED AS DATE)               AS completiondate,
        MAX(CASE WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                 THEN TRY_CONVERT(DATE, FAPV.ANSWERVALUE) END) AS date_of_meeting,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_typeOfMeeting'
                 THEN FAPV.ANSWERVALUE END) AS meeting_type,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
                 THEN FAPV.ANSWERVALUE END) AS next_step
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
WORKER AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.PERSONID) AS personid,
        CONVERT(NVARCHAR(100), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS allocated_worker,
        CAST(PPR.STARTDATE AS DATE) AS startdate,
        CAST(PPR.CLOSEDATE AS DATE) AS enddate
    FROM [eclipseDelta].[dbo].[RELATIONSHIPPROFESSIONALVIEW] PPR
    WHERE PPR.ALLOCATEDWORKERCODE = 'AW'
),
TEAM AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.PERSONID) AS personid,
        CONVERT(NVARCHAR(48), PPR.ORGANISATIONID) AS allocated_team,
        CAST(PPR.DATESTARTED AS DATE) AS startdate,
        CAST(PPR.DATEENDED AS DATE) AS enddate
    FROM [eclipseDelta].[dbo].[PERSONORGRELATIONSHIPVIEW] PPR
    WHERE PPR.ALLOCATEDTEAMCODE = 'AT'
)
INSERT INTO [ssd_initial_cp_conference] (
    icpc_icpc_id,
    icpc_icpc_meeting_id,
    icpc_person_id,
    icpc_icpc_target_date,
    icpc_icpc_date,
    icpc_icpc_transfer_in,
    icpc_icpc_outcome_cp_flag,
    icpc_icpc_outcome_json,
    icpc_icpc_team,
    icpc_icpc_worker_id
)
SELECT
    CONVERT(NVARCHAR(48), CONCAT(ia.instanceid, ia.personid)),
    ia.instanceid,
    ia.personid,
    CAST(wdr.[date] AS DATETIME),
    CAST(ia.date_of_meeting AS DATETIME),
    CASE WHEN ia.meeting_type LIKE '%Transfer%' THEN 'Y' ELSE 'N' END,
    CASE WHEN ia.next_step = 'Set next review' THEN 'Y' ELSE 'N' END,
    CONVERT(NVARCHAR(1000),
        '{'
        + '"OUTCOME_CP_FLAG":"' + CASE WHEN ia.next_step = 'Set next review' THEN 'Y' ELSE 'N' END + '"'
        + '}'
    ),
    t.allocated_team,
    w.allocated_worker
FROM INITIAL_ASSESSMENT ia
LEFT JOIN WORKING_DAY_RANKS wdr
    ON wdr.[rank] = (
        SELECT TOP (1) r.[rank] + 15
        FROM WORKING_DAY_RANKS r
        WHERE r.[date] = ia.date_of_meeting
    )
OUTER APPLY (
    SELECT TOP (1) allocated_worker
    FROM WORKER w
    WHERE w.personid = ia.personid
      AND ia.date_of_meeting >= w.startdate
      AND ia.date_of_meeting < ISNULL(w.enddate, GETDATE())
    ORDER BY w.startdate DESC
) w
OUTER APPLY (
    SELECT TOP (1) allocated_team
    FROM TEAM t
    WHERE t.personid = ia.personid
      AND ia.date_of_meeting >= t.startdate
      AND ia.date_of_meeting < ISNULL(t.enddate, GETDATE())
    ORDER BY t.startdate DESC
) t
WHERE EXISTS (
    SELECT 1
    FROM [ssd_person] sp
    WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), ia.personid)
);


