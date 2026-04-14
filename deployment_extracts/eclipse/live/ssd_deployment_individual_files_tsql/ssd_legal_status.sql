-- META-CONTAINER: {"type": "table", "name": "ssd_legal_status"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - CLAEPISODEOFCAREVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_legal_status', 'U') IS NOT NULL DROP TABLE #ssd_legal_status;

IF OBJECT_ID('ssd_legal_status', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_legal_status)
        TRUNCATE TABLE ssd_legal_status;
END
ELSE
BEGIN
    CREATE TABLE ssd_legal_status (
        lega_legal_status_id         NVARCHAR(48)  NOT NULL PRIMARY KEY,
        lega_person_id               NVARCHAR(48)  NULL,
        lega_legal_status            NVARCHAR(100) NULL,
        lega_legal_status_start_date DATETIME      NULL,
        lega_legal_status_end_date   DATETIME      NULL
    );
END

;WITH EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), EPIS.EPISODEOFCAREID) AS episodeofcareid,
        CONVERT(NVARCHAR(48), EPIS.PERSONID)        AS personid,
        CONVERT(NVARCHAR(100), EPIS.LEGALSTATUS)    AS legalstatus,
        CAST(EPIS.EOCSTARTDATE AS DATE)             AS eocstartdate,
        CAST(EPIS.EOCENDDATE   AS DATE)             AS eocenddate
    FROM CLAEPISODEOFCAREVIEW EPIS
    WHERE EXISTS (
        SELECT 1
        FROM ssd_person sp
        WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), EPIS.PERSONID)
    )
),
FLAGGED AS (
    SELECT
        e.*,
        CASE
            WHEN e.eocstartdate BETWEEN
                 LAG(e.eocstartdate) OVER (PARTITION BY e.personid, e.legalstatus ORDER BY e.eocstartdate, CASE WHEN e.eocenddate IS NULL THEN 1 ELSE 0 END, e.eocenddate)
                 AND DATEADD(DAY, 1, ISNULL(
                        LAG(e.eocenddate) OVER (PARTITION BY e.personid, e.legalstatus ORDER BY e.eocstartdate, CASE WHEN e.eocenddate IS NULL THEN 1 ELSE 0 END, e.eocenddate),
                        CAST(GETDATE() AS DATE)
                 ))
                THEN 0
            ELSE 1
        END AS start_flag
    FROM EPISODES e
),
GROUPED AS (
    SELECT
        f.*,
        SUM(f.start_flag) OVER (PARTITION BY f.personid, f.legalstatus ORDER BY f.eocstartdate ROWS UNBOUNDED PRECEDING) AS grp
    FROM FLAGGED f
),
ROLLED AS (
    SELECT
        g.personid,
        g.legalstatus,
        MIN(g.eocstartdate) AS eocstartdate,
        CASE WHEN MAX(CASE WHEN g.eocenddate IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL ELSE MAX(g.eocenddate) END AS eocenddate
    FROM GROUPED g
    GROUP BY g.personid, g.legalstatus, g.grp
),
LS_START AS (
    SELECT
        r.personid,
        r.legalstatus,
        r.eocstartdate,
        x.episodeofcareid
    FROM ROLLED r
    OUTER APPLY (
        SELECT TOP (1)
            e.episodeofcareid
        FROM EPISODES e
        WHERE e.personid = r.personid
          AND e.legalstatus = r.legalstatus
          AND e.eocstartdate = r.eocstartdate
        ORDER BY e.eocstartdate
    ) x
)
INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
)
SELECT
    ls.episodeofcareid                   AS lega_legal_status_id,
    r.personid                           AS lega_person_id,
    r.legalstatus                        AS lega_legal_status,
    CAST(r.eocstartdate AS DATETIME)     AS lega_legal_status_start_date,
    CAST(r.eocenddate   AS DATETIME)     AS lega_legal_status_end_date
FROM ROLLED r
LEFT JOIN LS_START ls
    ON ls.personid = r.personid
   AND ls.legalstatus = r.legalstatus
   AND ls.eocstartdate = r.eocstartdate;