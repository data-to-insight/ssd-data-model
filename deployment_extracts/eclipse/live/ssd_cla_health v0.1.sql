/*
=============================================================================
Object Name: ssd_cla_health
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
=============================================================================
*/

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


SELECT 
    CLAH_HEALTH_CHECK_ID                              AS CLAH_HEALTH_CHECK_ID,     --metadata={"item_ref:"CLAH001A"}
    CLAH_PERSON_ID                                    AS CLAH_PERSON_ID,           --metadata={"item_ref:"CLAH002A"}
    CASE WHEN CLAH_HEALTH_CHECK_TYPE = 'Dental check '
         THEN 'Dental Check'
         WHEN CLAH_HEALTH_CHECK_TYPE = 'Health check '
         THEN 'Health check'
         WHEN CLAH_HEALTH_CHECK_TYPE = 'Optician check '
         THEN 'Optician check'
    END                                               AS   CLAH_HEALTH_CHECK_TYPE,  --metadata={"item_ref:"CLAH003A"}
    CASE WHEN CLAH_HEALTH_CHECK_DATE IS NULL
         THEN REPORTING_DATE
         ELSE CLAH_HEALTH_CHECK_DATE
    END                                               AS CLAH_HEALTH_CHECK_DATE,   --metadata={"item_ref:"CLAH004A"}    
    CASE WHEN TAKEN_PLACE = 'No'
         THEN 'Refused'
         ELSE CLAH_HEALTH_CHECK_STATUS                         
    END                                               AS CLAH_HEALTH_CHECK_STATUS  --metadata={"item_ref:"CLAH005A"}
    
FROM (
    SELECT
	    FAPV.INSTANCEID                         AS CLAH_HEALTH_CHECK_ID,  
	    FAPV.ANSWERFORSUBJECTID                 AS CLAH_PERSON_ID, 
	    FAPV.DESIGNSUBNAME                      AS CLAH_HEALTH_CHECK_TYPE,
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_reportingDate') 
		        THEN FAPV.ANSWERVALUE 
	    END) ::DATE                             AS REPORTING_DATE,
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_dateOfCheck8','903Return_dateOfCheck2') 
		    THEN FAPV.ANSWERVALUE 
	    END) ::DATE                             AS CLAH_HEALTH_CHECK_DATE, 
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_DentalCheck','903Return_HealthAssessmentTakenPlace', 'hasAnOpticianCheckTakenPlace') 
		        THEN FAPV.ANSWERVALUE 
	    END)                                    AS TAKEN_PLACE,
	    FAPV.INSTANCESTATE                      AS CLAH_HEALTH_CHECK_STATUS
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
	    AND FAPV.INSTANCESTATE IN ('COMPLETE')
	    AND FAPV.DESIGNSUBNAME IN ('Health check ', 'Dental check ','Optician check ')
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DESIGNSUBNAME,
             FAPV.INSTANCESTATE ) FAPV
WHERE FAPV.CLAH_PERSON_ID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)             

UNION ALL

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Health check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastHealthCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastHealthCheckCompleted' 			--Date last health check completed
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE 

UNION ALL 

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Dental Check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastDentalCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastDentalCheckCompleted' 			--Date last dental check completed 
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE 
         
         
UNION ALL 

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Optician check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastOpticianCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastOpticianCheckCompleted' 			--Date last optician check completed
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE