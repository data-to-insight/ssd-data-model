-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- =============================================================================
CREATE TABLE IF NOT EXISTS ssd_cla_health (
    clah_health_check_id     VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAH001A"}
    clah_person_id           VARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
    clah_health_check_type   VARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
    clah_health_check_date   TIMESTAMP,                 -- metadata={"item_ref":"CLAH004A"}
    clah_health_check_status VARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
);

TRUNCATE TABLE ssd_cla_health;

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
)

INSERT INTO ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
)
-- main 903 Return health check forms
SELECT 
    clah_health_check_id     AS "clah_health_check_id",   --metadata={"item_ref:"CLAH001A"}
    clah_person_id           AS "clah_person_id",         --metadata={"item_ref:"CLAH002A"}
    CASE 
        WHEN clah_health_check_type = 'Dental check '   THEN 'Dental Check'
        WHEN clah_health_check_type = 'Health check '   THEN 'Health check'
        WHEN clah_health_check_type = 'Optician check ' THEN 'Optician check'
    END                        AS "clah_health_check_type",  --metadata={"item_ref:"CLAH003A"}
    CASE 
        WHEN clah_health_check_date IS NULL
        THEN reporting_date
        ELSE clah_health_check_date
    END::timestamp            AS "clah_health_check_date",   --metadata={"item_ref:"CLAH004A"}
    CASE 
        WHEN taken_place = 'No'
        THEN 'Refused'
        ELSE clah_health_check_status
    END                        AS "clah_health_check_status" --metadata={"item_ref:"CLAH005A"}
FROM (
    SELECT
        fapv.instanceid              AS clah_health_check_id,
        fapv.answerforsubjectid      AS clah_person_id,
        fapv.designsubname           AS clah_health_check_type,
        MAX(CASE 
                WHEN fapv.controlname IN ('903Return_reportingDate') 
                THEN fapv.answervalue 
            END)::date               AS reporting_date,
        MAX(CASE 
                WHEN fapv.controlname IN ('903Return_dateOfCheck8','903Return_dateOfCheck2') 
                THEN fapv.answervalue 
            END)::date               AS clah_health_check_date, 
        MAX(CASE 
                WHEN fapv.controlname IN (
                        '903Return_DentalCheck',
                        '903Return_HealthAssessmentTakenPlace',
                        'hasAnOpticianCheckTakenPlace'
                    ) 
                THEN fapv.answervalue 
            END)                     AS taken_place,
        fapv.instancestate           AS clah_health_check_status
    FROM formanswerpersonview fapv
    WHERE fapv.designguid = '0438ab4f-0d93-40d3-ab73-f97455646041'
      AND fapv.instancestate IN ('COMPLETE')
      AND fapv.designsubname IN ('Health check ', 'Dental check ','Optician check ')
    GROUP BY 
        fapv.instanceid,
        fapv.answerforsubjectid,
        fapv.designsubname,
        fapv.instancestate
) fapv
WHERE fapv.clah_person_id NOT IN (SELECT e.personid FROM exclusions e)

UNION ALL

-- future loading of health checks: health assessment
SELECT DISTINCT
    fapv.instanceid                                      AS "clah_health_check_id",     -- id
    fapv.answerforsubjectid                              AS "clah_person_id",
    'Health check'                                       AS "clah_health_check_type",
    MAX(CASE 
            WHEN fapv.controlname = 'dateLastHealthCheckCompleted' 
            THEN fapv.dateanswervalue 
        END)::timestamp                                  AS "clah_health_check_date",
    fapv.instancestate                                   AS "clah_health_check_status"
FROM formanswerpersonview fapv 
WHERE fapv.designguid = '36c62558-e07b-41bb-b3d1-1dd850d55472'
  AND fapv.controlname IN ('dateLastHealthCheckCompleted')
  AND fapv.instancestate IN ('COMPLETE')
  AND fapv.answerforsubjectid NOT IN (SELECT e.personid FROM exclusions e)
GROUP BY 
    fapv.answerforsubjectid,
    fapv.instanceid,
    fapv.instancestate

UNION ALL 

-- future loading: dental check
SELECT DISTINCT
    fapv.instanceid                                      AS "clah_health_check_id",
    fapv.answerforsubjectid                              AS "clah_person_id",
    'Dental Check'                                       AS "clah_health_check_type",
    MAX(CASE 
            WHEN fapv.controlname = 'dateLastDentalCheckCompleted' 
            THEN fapv.dateanswervalue 
        END)::timestamp                                  AS "clah_health_check_date",
    fapv.instancestate                                   AS "clah_health_check_status"
FROM formanswerpersonview fapv 
WHERE fapv.designguid = '36c62558-e07b-41bb-b3d1-1dd850d55472'
  AND fapv.controlname IN ('dateLastDentalCheckCompleted')
  AND fapv.instancestate IN ('COMPLETE')
  AND fapv.answerforsubjectid NOT IN (SELECT e.personid FROM exclusions e)
GROUP BY 
    fapv.answerforsubjectid,
    fapv.instanceid,
    fapv.instancestate 

UNION ALL 

-- future loading: optician check
SELECT DISTINCT
    fapv.instanceid                                      AS "clah_health_check_id",
    fapv.answerforsubjectid                              AS "clah_person_id",
    'Optician check'                                     AS "clah_health_check_type",
    MAX(CASE 
            WHEN fapv.controlname = 'dateLastOpticianCheckCompleted' 
            THEN fapv.dateanswervalue 
        END)::timestamp                                  AS "clah_health_check_date",
    fapv.instancestate                                   AS "clah_health_check_status"
FROM formanswerpersonview fapv 
WHERE fapv.designguid = '36c62558-e07b-41bb-b3d1-1dd850d55472'
  AND fapv.controlname IN ('dateLastOpticianCheckCompleted')
  AND fapv.instancestate IN ('COMPLETE')
  AND fapv.answerforsubjectid NOT IN (SELECT e.personid FROM exclusions e)
GROUP BY 
    fapv.answerforsubjectid,
    fapv.instanceid,
    fapv.instancestate;
