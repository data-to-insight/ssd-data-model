
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
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
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
