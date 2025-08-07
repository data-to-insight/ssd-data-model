
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

CIN_PLAN AS (
    SELECT 
        MIN(CLA.CLAID)     AS CLAID,
        CLA.PERSONID,
        MIN(CLA.STARTDATE) AS STARTDATE,
        CASE
	        WHEN BOOL_AND(ENDDATE IS NOT NULL) IS FALSE
	        THEN NULL
            ELSE MAX(ENDDATE)
       END                 AS ENDDATE
    FROM (	
        SELECT  
            *,
            SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, STARTDATE ROWS UNBOUNDED PRECEDING) AS EPISODE 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID    AS CLAID, 
                CLA.PERSONID, 
                CLA.STARTDATE::DATE               AS STARTDATE,
                CLA.ENDDATE::DATE                 AS ENDDATE,
                CASE WHEN CLA.STARTDATE > LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                            AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE) 
                     THEN 0
                     ELSE 1
                END                               AS NEXT_START_FLAG     
            FROM CLASSIFICATIONPERSONVIEW  CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
                  AND (CLA.CLASSIFICATIONPATHID IN (4) -- CIN classification
	                     OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classificaion
                  AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
                ORDER BY CLA.PERSONID,
	                     CLA.ENDDATE DESC NULLS FIRST,
	                     CLA.STARTDATE DESC 
	             ) CLA
	       
	          )CLA
        GROUP BY CLA.PERSONID, CLA.EPISODE
)  


SELECT 
    FAPV.FORMID            AS "cinv_cin_visit_id",       --metadata={"item_ref:"CINV001A"}
	FAPV.PERSONID          AS "cinv_person_id",          --metadata={"item_ref:"CINV007A"}
	FAPV.VISIT_DATE	       AS "cinv_cin_visit_date",     --metadata={"item_ref:"CINV003A"}
	FAPV.CHILD_SEEN        AS "cinv_cin_visit_seen",       --metadata={"item_ref:"CINV004A"}
	FAPV.SEEN_ALONE        AS "cinv_cin_visit_seen_alone", --metadata={"item_ref:"CINV005A"}
	NULL                   AS "cinv_cin_visit_bedroom"     --metadata={"item_ref:"CINV006A"}
FROM CIN_PLAN
JOIN (
		
		SELECT
			FAPV.INSTANCEID            AS FORMID,
			FAPV.ANSWERFORSUBJECTID    AS PERSONID,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
				   THEN FAPV.DATEANSWERVALUE
			    END)	               AS VISIT_DATE,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
				   THEN CASE WHEN FAPV.ANSWERVALUE = 'Yes'
				             THEN 'Y'
				             ELSE 'N'
				        END     
			    END)                  AS CHILD_SEEN,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
				   THEN CASE WHEN FAPV.ANSWERVALUE = 'Child seen alone'
				             THEN 'Y'
				             ELSE 'N'
				        END     
			    END)                  AS SEEN_ALONE
			
			
		FROM  FORMANSWERPERSONVIEW FAPV
		WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
		    AND FAPV.INSTANCESTATE = 'COMPLETE'
		    AND FAPV.designsubname IN ('Child in need', 'Family Help')
		    AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
		GROUP BY 
		    FAPV.ANSWERFORSUBJECTID,
		    FAPV.INSTANCEID	
  ) FAPV ON FAPV.PERSONID = CIN_PLAN.PERSONID
        AND FAPV.VISIT_DATE >= CIN_PLAN.STARTDATE
        AND FAPV.VISIT_DATE <= CIN_PLAN.ENDDATE