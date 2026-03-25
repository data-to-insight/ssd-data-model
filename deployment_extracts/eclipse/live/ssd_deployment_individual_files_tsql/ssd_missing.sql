-- META-CONTAINER: {"type": "table", "name": "ssd_missing"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - FORMANSWERPERSONVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

IF OBJECT_ID('ssd_missing', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_missing)
        TRUNCATE TABLE ssd_missing;
END
ELSE
BEGIN
    CREATE TABLE ssd_missing (
        miss_table_id                   NVARCHAR(48)  NOT NULL PRIMARY KEY,
        miss_person_id                  NVARCHAR(48)  NULL,
        miss_missing_episode_start_date DATETIME      NULL,
        miss_missing_episode_type       NVARCHAR(100) NULL,
        miss_missing_episode_end_date   DATETIME      NULL,
        miss_missing_rhi_offered        NVARCHAR(2)   NULL,
        miss_missing_rhi_accepted       NVARCHAR(2)   NULL
    );
END

;WITH MISSING_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID) AS miss_table_id,
        CONVERT(NVARCHAR(48), FAPV.SUBJECTID)  AS miss_person_id,
        MAX(CASE WHEN UPPER(FAPV.CONTROLNAME) LIKE 'DATECHILDLASTSEEN%'
                 THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS miss_missing_episode_start_date,
        MAX(CASE WHEN UPPER(FAPV.CONTROLNAME) LIKE 'ABSENCETYPE%'
                 THEN FAPV.ANSWERVALUE END) AS miss_missing_episode_type,
        MAX(CASE WHEN UPPER(FAPV.CONTROLNAME) LIKE 'FOUNDREPORTDATE%'
                 THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS miss_missing_episode_end_date,
        MAX(CASE WHEN UPPER(FAPV.CONTROLNAME) LIKE 'HASARETURNHOMEINTERVIEWBEENOFFERED%'
                 THEN FAPV.ANSWERVALUE END) AS miss_missing_rhi_offered,
        MAX(CASE WHEN UPPER(FAPV.CONTROLNAME) LIKE 'HASTHERETURNHOMEINTERVIEWBEENACCEPTED%'
                 THEN FAPV.ANSWERVALUE END) AS miss_missing_rhi_accepted
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e112bee8-4f50-4904-8ebc-842e2fd33994')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
      )
    GROUP BY
        FAPV.INSTANCEID,
        FAPV.SUBJECTID,
        FAPV.PAGETITLE
)
INSERT INTO ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,
    miss_missing_rhi_accepted
)
SELECT
    miss_table_id,
    miss_person_id,
    CAST(miss_missing_episode_start_date AS DATETIME),
    miss_missing_episode_type,
    CAST(miss_missing_episode_end_date AS DATETIME),
    miss_missing_rhi_offered,
    miss_missing_rhi_accepted
FROM MISSING_BASE;