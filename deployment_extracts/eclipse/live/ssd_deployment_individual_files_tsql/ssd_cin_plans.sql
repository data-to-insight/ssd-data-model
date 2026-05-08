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

IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL
    DROP TABLE #ssd_cin_plans;

IF OBJECT_ID('[SSD].[ssd_cin_plans]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [SSD].[ssd_cin_plans])
        TRUNCATE TABLE [SSD].[ssd_cin_plans];
END
ELSE
BEGIN
    CREATE TABLE [SSD].[ssd_cin_plans] (
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
        CONVERT(NVARCHAR(48), PPR.PERSONRELATIONSHIPRECORDID) AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)                   AS personid,
        CONVERT(NVARCHAR(100), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS allocated_worker,
        CAST(PPR.STARTDATE AS DATE) AS worker_start_date,
        CAST(PPR.CLOSEDATE AS DATE) AS worker_end_date
    FROM [eclipseDelta].[dbo].[RELATIONSHIPPROFESSIONALVIEW] PPR
    WHERE PPR.ALLOCATEDWORKERCODE = 'AW'
),
TEAM AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.RELATIONSHIPID) AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)       AS personid,
        CONVERT(NVARCHAR(48), PPR.ORGANISATIONID) AS allocated_team,
        CAST(PPR.DATESTARTED AS DATE) AS team_start_date,
        CAST(PPR.DATEENDED   AS DATE) AS team_end_date
    FROM [eclipseDelta].[dbo].[PERSONORGRELATIONSHIPVIEW] PPR
    WHERE PPR.ALLOCATEDTEAMCODE = 'AT'
),
ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS personid,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS episodeid,
        CAST(CLA.STARTDATE AS DATE) AS startdate,
        CAST(CLA.ENDDATE   AS DATE) AS enddate
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
    WHERE CLA.STATUS <> 'DELETED'
      AND (CLA.CLASSIFICATIONPATHID IN (4,51) OR CLA.CLASSIFICATIONCODEID = 1270)
),
CIN_PLAN_ROWS AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS claid,
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS personid,
        CAST(CLA.STARTDATE AS DATE) AS startdate,
        CAST(CLA.ENDDATE   AS DATE) AS enddate,
        CASE
            WHEN CAST(CLA.STARTDATE AS DATE)
                 > LAG(CAST(CLA.STARTDATE AS DATE))
                     OVER (PARTITION BY CLA.PERSONID ORDER BY CAST(CLA.STARTDATE AS DATE))
            THEN 1 ELSE 0
        END AS new_grp
    FROM [eclipseDelta].[dbo].[CLASSIFICATIONPERSONVIEW] CLA
    WHERE CLA.STATUS <> 'DELETED'
      AND (CLA.CLASSIFICATIONPATHID = 4 OR CLA.CLASSIFICATIONCODEID = 1270)
      AND EXISTS (
          SELECT 1
          FROM [SSD].[ssd_person] sp
          WHERE sp.pers_person_id = CONVERT(VARCHAR(48), CLA.PERSONID)
      )
),
CIN_PLAN_TAGGED AS (
    SELECT *,
           SUM(new_grp) OVER (PARTITION BY personid ORDER BY startdate) AS grp
    FROM CIN_PLAN_ROWS
),
CIN_PLAN AS (
    SELECT
        MIN(claid) AS cin_plan_id,
        personid,
        MIN(startdate) AS startdate,
        MAX(enddate)   AS enddate
    FROM CIN_PLAN_TAGGED
    GROUP BY personid, grp
)
INSERT INTO [SSD].[ssd_cin_plans] (
    cinp_cin_plan_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT
    CP.cin_plan_id,
    CP.personid,
    CAST(CP.startdate AS DATETIME),
    CAST(CP.enddate AS DATETIME),
    TA.allocated_team,
    WA.allocated_worker
FROM CIN_PLAN CP
OUTER APPLY (
    SELECT TOP (1) allocated_worker
    FROM WORKER W
    WHERE W.personid = CP.personid
      AND ISNULL(CP.enddate, GETDATE()) >= W.worker_start_date
      AND CP.startdate <= ISNULL(W.worker_end_date, GETDATE())
    ORDER BY W.worker_start_date DESC
) WA
OUTER APPLY (
    SELECT TOP (1) allocated_team
    FROM TEAM T
    WHERE T.personid = CP.personid
      AND ISNULL(CP.enddate, GETDATE()) >= T.team_start_date
      AND CP.startdate <= ISNULL(T.team_end_date, GETDATE())
    ORDER BY T.team_start_date DESC
) TA;