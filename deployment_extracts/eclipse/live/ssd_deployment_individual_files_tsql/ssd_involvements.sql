-- META-CONTAINER: {"type": "table", "name": "ssd_involvements"}
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
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;

IF OBJECT_ID('ssd_involvements', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_involvements)
        TRUNCATE TABLE ssd_involvements;
END
ELSE
BEGIN
    CREATE TABLE ssd_involvements (
        invo_involvements_id        NVARCHAR(48)  NOT NULL PRIMARY KEY,
        invo_professional_id        NVARCHAR(48)  NULL,
        invo_professional_role_id   NVARCHAR(200) NULL,
        invo_professional_team      NVARCHAR(255) NULL,
        invo_person_id              NVARCHAR(48)  NULL,
        invo_involvement_start_date DATETIME      NULL,
        invo_involvement_end_date   DATETIME      NULL,
        invo_worker_change_reason   NVARCHAR(200) NULL,
        invo_referral_id            NVARCHAR(48)  NULL
    );
END

;WITH TEAM AS (
    SELECT
        CONVERT(NVARCHAR(48), PPR.RELATIONSHIPID) AS id,
        CONVERT(NVARCHAR(48), PPR.PERSONID)       AS personid,
        CONVERT(NVARCHAR(48), PPR.ORGANISATIONID) AS allocated_team,
        CAST(PPR.DATESTARTED AS DATE)             AS team_start_date,
        CAST(PPR.DATEENDED   AS DATE)             AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
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
)
INSERT INTO ssd_involvements (
    invo_involvements_id,
    invo_professional_id,
    invo_professional_role_id,
    invo_professional_team,
    invo_person_id,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)
SELECT
    CONVERT(NVARCHAR(48), PPR.PERSONRELATIONSHIPRECORDID)       AS invo_involvements_id,
    CONVERT(NVARCHAR(48), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS invo_professional_id,
    CONVERT(NVARCHAR(200), PPR.RELATIONSHIPCLASSCODE)           AS invo_professional_role_id,
    T.allocated_team                                            AS invo_professional_team,
    CONVERT(NVARCHAR(48), PPR.PERSONID)                         AS invo_person_id,
    CAST(PPR.STARTDATE AS DATETIME)                             AS invo_involvement_start_date,
    CAST(PPR.CLOSEDATE AS DATETIME)                             AS invo_involvement_end_date,
    CONVERT(NVARCHAR(200), PPR.STARTREASONCODE)                 AS invo_worker_change_reason,
    CE.cine_referral_id                                         AS invo_referral_id
FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN CIN_EPISODE CE
       ON CONVERT(NVARCHAR(48), PPR.PERSONID) = CE.cine_person_id
      AND CAST(PPR.STARTDATE AS DATE) >= CE.cine_referral_date
      AND CAST(PPR.STARTDATE AS DATE) < ISNULL(CE.cine_close_date, CAST(GETDATE() AS DATE))
LEFT JOIN TEAM T
       ON T.personid = CONVERT(NVARCHAR(48), PPR.PERSONID)
      AND ISNULL(CAST(PPR.CLOSEDATE AS DATE), CAST(GETDATE() AS DATE)) >= T.team_start_date
      AND CAST(PPR.STARTDATE AS DATE) < ISNULL(T.team_end_date, CAST(GETDATE() AS DATE))
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), PPR.PERSONID)
);