/*
=============================================================================
Object Name: ssd_cla_substance_misuse
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
=============================================================================
*/

SELECT
	/*Row identifier for the ssd_substance_misuse table */
	NULL "clas_substance_misuse_id", --metadata={"item_ref:"CLAS001A"}
	/*Person's ID generated in CMS Database */
	NULL "clas_person_id", --metadata={"item_ref:"CLAS002A"}
	/*Date of substance misuse */
	NULL "clas_substance_misuse_date", --metadata={"item_ref:"CLAS003A"}
	/*Substance that was being misused */
	NULL "clas_substance_misused", --metadata={"item_ref:"CLAS004A"}
	/*Did child receive intervention for substance misuse problem? */
	NULL "clas_intervention_received" --metadata={"item_ref:"CLAS005A"}
	
 FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
	    AND FAPV.INSTANCESTATE IN ('COMPLETE')
	    AND FAPV.DESIGNSUBNAME IN ('Substance misuse check ')	
	
	
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
	    AND FAPV.DESIGNSUBNAME IN ('Substance misuse check ')
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DESIGNSUBNAME,
             FAPV.INSTANCESTATE

             
SELECT 
   FAPV.INSTANCEID                         AS CLAH_HEALTH_CHECK_ID,  
	    FAPV.ANSWERFORSUBJECTID                 AS CLAH_PERSON_ID        
 FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
	    AND FAPV.INSTANCESTATE IN ('COMPLETE')  
	    AND FAPV.DESIGNSUBNAME IN ('Substance misuse check ')
	    
	    
	    
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
			'dateLastSubstanceMisuseCheckCompleted' 	--Date last substance misuse check completed
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE 	    
	    