/*
=============================================================================
Object Name: ssd_s47_enquiry
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
=============================================================================
*/

WITH WORKER AS (    -------Responcible social worker AND team
SELECT 
     PPR.PERSONRELATIONSHIPRECORDID       AS ID,
     PPR.PERSONID                         AS PERSONID,
     PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
     PPR.STARTDATE                        AS WORKER_START_DATE,
     PPR.CLOSEDATE                        AS WORKER_END_DATE,
     PPR.PROFESSIONALTEAMID               AS PROFESSIONAL_TEAM_FK
FROM RELATIONSHIPPROFESSIONALVIEW PPR
WHERE ALLOCATEDWORKERCODE = 'AW' 
),

TEAM AS (    -------Responcible team
    SELECT 
        PPR.RELATIONSHIPID                   AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.ORGANISATIONID                   AS ALLOCATED_TEAM,
        PPR.DATESTARTED                      AS TEAM_START_DATE,
        PPR.DATEENDED                        AS TEAM_END_DATE
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
),

EXCLUSIONS AS (
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

CIN_EPISODE AS (  ----------CIN Episodes
    SELECT 
        CINE_PERSON_ID,
        CINE_REFERRAL_DATE,
        CINE_CLOSE_DATE,
        MAX(CINE_CLOSE_REASON)          AS CINE_CLOSE_REASON,
        MIN(CINE_REFERRAL_ID)           AS CINE_REFERRAL_ID
    FROM (    
        SELECT 
            CLA.PERSONID                                                  AS CINE_PERSON_ID,
            MIN(CLA.PRIMARY_CODE_STARTDATE)                               AS CINE_REFERRAL_DATE,
            CASE
	    	    WHEN BOOL_AND(PRIMARY_CODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(PRIMARY_CODE_ENDDATE)
	        END                                                           AS CINE_CLOSE_DATE,
	        MAX(ENDREASON)                                                AS CINE_CLOSE_REASON,
	        MAX(EPISODE_ID)                                               AS CINE_REFERRAL_ID
        FROM (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, PRIMARY_CODE_STARTDATE) AS EPISODE,
	            CASE WHEN NEXT_START_FLAG = 1
	                 THEN EPISODEID
	            END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   CLA.PERSONID, 
                   CLA.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
	               CLA.STARTDATE::DATE                                                 AS PRIMARY_CODE_STARTDATE,
                   CLA.ENDDATE::DATE                                                   AS PRIMARY_CODE_ENDDATE,
                   CLA.ENDREASON,
                   CASE WHEN CLA.STARTDATE >= LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                           AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM CLASSIFICATIONPERSONVIEW  CLA
               WHERE CLA.STATUS NOT IN ('DELETED')
                   AND CLA.CLASSIFICATIONPATHID IN (23,10)
               ORDER BY CLA.PERSONID,
	                    CLA.ENDDATE:: DATE DESC NULLS FIRST,
	                    CLA.STARTDATE:: DATE DESC 
	             ) CLA
	       
	          )CLA
    	     
        GROUP BY PERSONID, EPISODE 
        ) CLA
        
    GROUP BY  CINE_PERSON_ID,
              CINE_REFERRAL_DATE,
              CINE_CLOSE_DATE 
              
) 


SELECT
	FAPV.INSTANCEID                    AS "s47e_s47_enquiry_id",           --metadata={"item_ref:"S47E001A"}
	CIN_EPISODE.CINE_REFERRAL_ID       AS "s47e_referral_id",              --metadata={"item_ref:"S47E010A"}
	FAPV.ANSWERFORSUBJECTID            AS "s47e_person_id",                --metadata={"item_ref:"S47E002A"}
	FAPV.STARTDATE                     AS "s47e_s47_start_date",           --metadata={"item_ref:"S47E004A"}
	FAPV.COMPLETIONDATE                AS "s47e_s47_end_date",             --metadata={"item_ref:"S47E005A"}
	CASE WHEN FAPV.OUTCOME = 'No further action' 
	     THEN 'Y'
	     ELSE 'N' 
	END                                AS "s47e_s47_nfa",                 --metadata={"item_ref:"S47E006A"}
	JSON_BUILD_OBJECT( 
         'OUTCOME_NFA_FLAG',                 CASE WHEN FAPV.OUTCOME = 'No further action' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END,
         'OUTCOME_LEGAL_ACTION_FLAG',        'N', 
         'OUTCOME_PROV_OF_SERVICES_FLAG',    'N',
         'OUTCOME_CP_CONFERENCE_FLAG',       CASE WHEN FAPV.OUTCOME = 'Convene initial child protection conference' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END, 
         'OUTCOME_NFA_CONTINUE_SINGLE_FLAG', CASE WHEN FAPV.OUTCOME IN( 'Continue discussion and plan', 'Continue assessment / plan', 'Continue assessment and plan') 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END, 
         'OUTCOME_MONITOR_FLAG',             'N', 
         'OTHER_OUTCOMES_EXIST_FLAG'    ,    CASE WHEN FAPV.OUTCOME = 'Further strategy meeting' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END,
         'TOTAL_NO_OF_OUTCOMES',             ' ',
         'OUTCOME_COMMENTS' ,                SUMMARY_UTCOME

      )                              AS	"s47e_s47_outcome_json",             --metadata={"item_ref:"S47E007A"}
	WORKER.ALLOCATED_WORKER          AS "s47e_s47_completed_by_worker_id", --metadata={"item_ref:"S47E008A"}
	TEAM.ALLOCATED_TEAM              AS "s47e_s47_completed_by_team"    --metadata={"item_ref:"S47E009A"}
		    
FROM (
	SELECT
		FAPV.INSTANCEID ,
		FAPV.ANSWERFORSUBJECTID ,
		MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
				 THEN FAPV.DATEANSWERVALUE
		END)                       AS STARTDATE,
		FAPV.DATECOMPLETED::DATE   AS COMPLETIONDATE,
		MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_unsubWhatNeedsToHappenNext', 'CINCensus_whatNeedsToHappenNext')
				 THEN FAPV.ANSWERVALUE
	    END)                       AS OUTCOME,
		MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_outcomeOfSection47Enquiry')
				 THEN FAPV.ANSWERVALUE
	    END)                       AS SUMMARY_UTCOME	    
	FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)	
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DATECOMPLETED) FAPV
LEFT JOIN WORKER ON WORKER.PERSONID = FAPV.ANSWERFORSUBJECTID 
                         AND FAPV.STARTDATE >= WORKER.WORKER_START_DATE
                         AND FAPV.STARTDATE < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = FAPV.ANSWERFORSUBJECTID 
                         AND FAPV.STARTDATE >= TEAM.TEAM_START_DATE
                         AND FAPV.STARTDATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         
LEFT JOIN CIN_EPISODE ON FAPV.ANSWERFORSUBJECTID =  CIN_EPISODE.CINE_PERSON_ID 
                      AND FAPV.STARTDATE >= CIN_EPISODE.CINE_REFERRAL_DATE
                      AND FAPV.STARTDATE < COALESCE(CIN_EPISODE.CINE_CLOSE_DATE,CURRENT_DATE)                          
         
         