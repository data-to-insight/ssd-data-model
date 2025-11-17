-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_legal_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_legal_status (
    lega_legal_status_id         VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LEGA001A"}
    lega_person_id               VARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
    lega_legal_status            VARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
    lega_legal_status_start_date TIMESTAMP,                 -- metadata={"item_ref":"LEGA004A"}
    lega_legal_status_end_date   TIMESTAMP                  -- metadata={"item_ref":"LEGA005A"}
);

TRUNCATE TABLE ssd_legal_status;

INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
)
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
    WHERE PV.PERSONID IN (
            1,2,3,4,5,6,99046,100824,100825,100826,100827,100828,100829,100830,100832,100856,100857,100861,100864,9999040,102790,
            100831,100833,100834,100838,100839,100859,100860,99524,99543,99555,99559,99613,99661,99662,99993,100276,100290,100372,109032,100924,
            100941,35698,43088,68635,74902,77731,97447,9999000,9999010,9999025,9999026,9999029,9999050,72306,109032,117746,
            97951 --not flagged as duplicate
        )
        OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
),

EPISODES AS (
    SELECT
        EPIS.EPISODEOFCAREID, 
        EPIS.PERSONID,
        EPIS.LEGALSTATUS,
        EPIS.EOCSTARTDATE,
        EPIS.EOCENDDATE
    FROM CLAEPISODEOFCAREVIEW EPIS	
    WHERE EPIS.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
)    

SELECT
    LS_START.EPISODEOFCAREID AS lega_legal_status_id,         --metadata={"item_ref:"LEGA001A"}
    EPIS.PERSONID           AS lega_person_id,                --metadata={"item_ref:"LEGA002A"}
    EPIS.LEGALSTATUS        AS lega_legal_status,             --metadata={"item_ref:"LEGA003A"}
    EPIS.EOCSTARTDATE       AS lega_legal_status_start_date,  --metadata={"item_ref:"LEGA004A"}
    EPIS.EOCENDDATE         AS lega_legal_status_end_date     --metadata={"item_ref:"LEGA005A"}

FROM (
    SELECT
        PERSONID,
        LEGALSTATUS,
        MIN(EPIS.EOCSTARTDATE) AS EOCSTARTDATE,
        CASE
            WHEN BOOL_AND(EPIS.EOCENDDATE IS NOT NULL) IS FALSE
                THEN NULL
            ELSE MAX(EPIS.EOCENDDATE)
        END AS EOCENDDATE
    FROM (		
        SELECT
            *,
            SUM(START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, EOCSTARTDATE) AS GRP 
        FROM (   
            SELECT 
                *,
                CASE
                    WHEN EOCSTARTDATE BETWEEN
                        LAG(EOCSTARTDATE) OVER (
                            PARTITION BY PERSONID, LEGALSTATUS 
                            ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
                        )
                        AND COALESCE(
                            LAG(EOCENDDATE) OVER (
                                PARTITION BY PERSONID, LEGALSTATUS 
                                ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
                            ),
                            CURRENT_DATE
                        ) + INTERVAL '1 day'
                    THEN 0
                    ELSE 1
                END AS START_FLAG
            FROM EPISODES EPIS
        ) EPIS
    ) EPIS
    GROUP BY EPIS.PERSONID, EPIS.LEGALSTATUS --,LS_START.EPISODEOFCAREID
) EPIS

LEFT JOIN LATERAL (
    SELECT
        *
    FROM EPISODES
    WHERE EPISODES.PERSONID = EPIS.PERSONID
      AND EPISODES.LEGALSTATUS = EPIS.LEGALSTATUS
      AND EPISODES.EOCSTARTDATE = EPIS.EOCSTARTDATE
    ORDER BY EPISODES.EOCSTARTDATE  
    FETCH FIRST 1 ROW ONLY
) LS_START ON TRUE;

