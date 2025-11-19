/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_missing;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_missing (
    miss_table_id                   VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"MISS001A"}
    miss_person_id                  VARCHAR(48),              -- metadata={"item_ref":"MISS002A"}
    miss_missing_episode_start_date TIMESTAMP,                -- metadata={"item_ref":"MISS003A"}
    miss_missing_episode_type       VARCHAR(100),             -- metadata={"item_ref":"MISS004A"}
    miss_missing_episode_end_date   TIMESTAMP,                -- metadata={"item_ref":"MISS005A"}
    miss_missing_rhi_offered        VARCHAR(2),               -- metadata={"item_ref":"MISS006A", "expected_data":["N","Y","NA", NULL]}
    miss_missing_rhi_accepted       VARCHAR(2)                -- metadata={"item_ref":"MISS007A"}
);

TRUNCATE TABLE ssd_missing;

INSERT INTO ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,
    miss_missing_rhi_accepted
)
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
        OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
),
MISSING_BASE AS (
    SELECT 
        FAPV.INSTANCEID                             AS miss_table_id,
        FAPV.SUBJECTID                              AS miss_person_id,
        MAX(
            CASE
                WHEN UPPER(FAPV.CONTROLNAME) LIKE 'DATECHILDLASTSEEN%'
                    THEN FAPV.DATEANSWERVALUE
            END
        )::DATE                                     AS miss_missing_episode_start_date,
        MAX(
            CASE
                WHEN UPPER(FAPV.CONTROLNAME) LIKE 'ABSENCETYPE%'
                    THEN FAPV.ANSWERVALUE
            END
        )                                           AS miss_missing_episode_type,
        MAX(
            CASE
                WHEN UPPER(FAPV.CONTROLNAME) LIKE 'FOUNDREPORTDATE%'
                    THEN FAPV.DATEANSWERVALUE
            END
        )::DATE                                     AS miss_missing_episode_end_date,
        MAX(
            CASE
                WHEN UPPER(FAPV.CONTROLNAME) LIKE 'HASARETURNHOMEINTERVIEWBEENOFFERED%'
                    THEN FAPV.ANSWERVALUE
            END
        )                                           AS miss_missing_rhi_offered,
        MAX(
            CASE
                WHEN UPPER(FAPV.CONTROLNAME) LIKE 'HASTHERETURNHOMEINTERVIEWBEENACCEPTED%'
                    THEN FAPV.ANSWERVALUE
            END
        )                                           AS miss_missing_rhi_accepted
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e112bee8-4f50-4904-8ebc-842e2fd33994')  -- Missing, child reported missing
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY
        FAPV.INSTANCEID,
        FAPV.SUBJECTID,
        FAPV.PAGETITLE
)
SELECT
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,
    miss_missing_rhi_accepted
FROM MISSING_BASE;
