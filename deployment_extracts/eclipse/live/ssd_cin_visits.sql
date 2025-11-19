

-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cin_visits;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cin_visits
(
    cinv_cin_visit_id         VARCHAR(48) PRIMARY KEY, -- metadata={"item_ref":"CINV001A"}      
    cinv_person_id            VARCHAR(48),             -- metadata={"item_ref":"CINV007A"}
    cinv_cin_visit_date       TIMESTAMP,               -- metadata={"item_ref":"CINV003A"}
    cinv_cin_visit_seen       CHAR(1),                 -- metadata={"item_ref":"CINV004A"}
    cinv_cin_visit_seen_alone CHAR(1),                 -- metadata={"item_ref":"CINV005A"}
    cinv_cin_visit_bedroom    CHAR(1)                  -- metadata={"item_ref":"CINV006A"}
);

TRUNCATE TABLE ssd_cin_visits;

INSERT INTO ssd_cin_visits (
    cinv_cin_visit_id,
    cinv_person_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
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


CIN_PLAN AS (
    SELECT 
        MIN(CLA.claid)     AS claid,
        CLA.personid,
        MIN(CLA.startdate) AS startdate,
        CASE
            WHEN BOOL_AND(enddate IS NOT NULL) IS FALSE
                THEN NULL
            ELSE MAX(enddate)
        END AS enddate
    FROM (	
        SELECT  
            *,
            SUM(next_start_flag) OVER (
                PARTITION BY personid 
                ORDER BY personid, startdate ROWS UNBOUNDED PRECEDING
            ) AS episode 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID AS claid, 
                CLA.PERSONID                   AS personid, 
                CLA.STARTDATE::DATE            AS startdate,
                CLA.ENDDATE::DATE              AS enddate,
                CASE 
                    WHEN CLA.STARTDATE > LAG(CLA.STARTDATE) OVER (
                             PARTITION BY CLA.PERSONID 
                             ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                         )
                     AND CLA.STARTDATE <= COALESCE(
                             LAG(CLA.ENDDATE) OVER (
                                 PARTITION BY CLA.PERSONID 
                                 ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                             ),
                             CURRENT_DATE
                         )
                    THEN 0
                    ELSE 1
                END AS next_start_flag     
            FROM CLASSIFICATIONPERSONVIEW CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
              AND (CLA.CLASSIFICATIONPATHID IN (4)  -- CIN classification
                   OR CLA.CLASSIFICATIONCODEID IN (1270)) -- FAMILY Help CIN classification
              AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
            ORDER BY CLA.PERSONID,
                     CLA.ENDDATE DESC NULLS FIRST,
                     CLA.STARTDATE DESC 
        ) CLA
    ) CLA
    GROUP BY CLA.personid, CLA.episode
)  

SELECT 
    FAPV.formid          AS cinv_cin_visit_id,       -- metadata={"item_ref:"CINV001A"}
    FAPV.personid        AS cinv_person_id,          -- metadata={"item_ref:"CINV007A"}
    FAPV.visit_date      AS cinv_cin_visit_date,     -- metadata={"item_ref:"CINV003A"}
    FAPV.child_seen      AS cinv_cin_visit_seen,     -- metadata={"item_ref:"CINV004A"}
    FAPV.seen_alone      AS cinv_cin_visit_seen_alone, -- metadata={"item_ref:"CINV005A"}
    NULL::CHAR(1)        AS cinv_cin_visit_bedroom   -- metadata={"item_ref:"CINV006A"}
FROM CIN_PLAN
JOIN (
    SELECT
        FAPV.INSTANCEID         AS formid,
        FAPV.ANSWERFORSUBJECTID AS personid,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
                THEN FAPV.DATEANSWERVALUE
            END)                AS visit_date,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
                THEN CASE 
                         WHEN FAPV.ANSWERVALUE = 'Yes'
                             THEN 'Y'
                         ELSE 'N'
                     END     
            END)                AS child_seen,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
                THEN CASE 
                         WHEN FAPV.ANSWERVALUE = 'Child seen alone'
                             THEN 'Y'
                         ELSE 'N'
                     END     
            END)                AS seen_alone
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.designsubname IN ('Child in need', 'Family Help')
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY 
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID	
) FAPV 
    ON FAPV.personid = CIN_PLAN.personid
   AND FAPV.visit_date >= CIN_PLAN.startdate
   AND FAPV.visit_date <= CIN_PLAN.enddate;
