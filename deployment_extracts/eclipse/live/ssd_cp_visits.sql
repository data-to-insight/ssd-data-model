
-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cp_visits;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cp_visits (
    cppv_cp_visit_id      VARCHAR(48) PRIMARY KEY, -- metadata={"item_ref":"CPPV007A"} 
    cppv_person_id        VARCHAR(48),             -- metadata={"item_ref":"CPPV008A"}
    cppv_cp_plan_id       VARCHAR(48),             -- metadata={"item_ref":"CPPV001A"}
    cppv_cp_visit_date    TIMESTAMP,               -- metadata={"item_ref":"CPPV003A"}
    cppv_cp_visit_seen    CHAR(1),                 -- metadata={"item_ref":"CPPV004A"}
    cppv_cp_visit_seen_alone CHAR(1),              -- metadata={"item_ref":"CPPV005A"}
    cppv_cp_visit_bedroom CHAR(1)                  -- metadata={"item_ref":"CPPV006A"}
);

TRUNCATE TABLE ssd_cp_visits;

INSERT INTO ssd_cp_visits (
    cppv_cp_visit_id,
    cppv_person_id,
    cppv_cp_plan_id,
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
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


FAPV AS (
    SELECT
        FAPV.INSTANCEID         AS INSTANCEID,
        FAPV.ANSWERFORSUBJECTID AS PERSONID,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
                    THEN FAPV.DATEANSWERVALUE
            END
        )                       AS VISIT_DATE,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
                    THEN CASE 
                             WHEN FAPV.ANSWERVALUE = 'Yes'
                                 THEN 'Y'
                             ELSE 'N'
                         END     
            END
        )                       AS CHILD_SEEN,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
                    THEN CASE 
                             WHEN FAPV.ANSWERVALUE = 'Child seen alone'
                                 THEN 'Y'
                             ELSE 'N'
                         END     
            END
        )                       AS CHILD_SEEN_ALONE
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child Protection '
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY 
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
)
SELECT
    FAPV.INSTANCEID                    AS "cppv_cp_visit_id",         --metadata={"item_ref:"CPPV007A"}
    FAPV.PERSONID                      AS "cppv_person_id",           --metadata={"item_ref:"CPPV008A"}
    CP_PLAN.CLASSIFICATIONASSIGNMENTID AS "cppv_cp_plan_id",          --metadata={"item_ref:"CPPV001A"}
    FAPV.VISIT_DATE                    AS "cppv_cp_visit_date",       --metadata={"item_ref:"CPPV003A"}
    FAPV.CHILD_SEEN                    AS "cppv_cp_visit_seen",       --metadata={"item_ref:"CPPV004A"}
    FAPV.CHILD_SEEN_ALONE              AS "cppv_cp_visit_seen_alone", --metadata={"item_ref:"CPPV005A"}
    NULL                               AS "cppv_cp_visit_bedroom"     --metadata={"item_ref:"CPPV006A"}
FROM FAPV
LEFT JOIN CLASSIFICATIONPERSONVIEW CP_PLAN
       ON CP_PLAN.PERSONID = FAPV.PERSONID
      AND FAPV.VISIT_DATE >= CP_PLAN.STARTDATE
      AND FAPV.VISIT_DATE <= COALESCE(CP_PLAN.ENDDATE, CURRENT_DATE)
      AND CP_PLAN.CLASSIFICATIONPATHID = 51;
