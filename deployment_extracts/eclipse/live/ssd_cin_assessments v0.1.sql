/*
=============================================================================
Object Name: ssd_cin_assessments
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
                   AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
               ORDER BY CLA.PERSONID,
	                    CLA.ENDDATE:: DATE DESC NULLS FIRST,
	                    CLA.STARTDATE:: DATE DESC 
	             ) CLA
	       
	          )CLA
    	--WHERE  PERSONID = 69     
        GROUP BY PERSONID, EPISODE 
        ) CLA
        
    GROUP BY  CINE_PERSON_ID,
              CINE_REFERRAL_DATE,
              CINE_CLOSE_DATE 
),

WORKER AS (    -------Responcible social worker 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
        PPR.STARTDATE                        AS WORKER_START_DATE,
        PPR.CLOSEDATE                        AS WORKER_END_DATE
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

ASSESSMENT AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                                AS CINA_PERSON_ID,
        FAPV.INSTANCEID                                                        AS CINA_ASSESSMENT_ID,
        FAPV.DATECOMPLETED ::DATE                                              AS CINA_ASSESSMENT_AUTH_DATE,
        CASE WHEN MAX(CASE
		    	          WHEN FAPV.CONTROLNAME = 'SeenAlone'
			              THEN FAPV.ANSWERVALUE
		              END) IN ('Child seen alone', 'Child seen with others')  
		     THEN 'Y'
		     ELSE 'N'
	    END	                                                                   AS CINA_ASSESSMENT_CHILD_SEEN, 
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'CINCensus_startDateOfForm'
		    	THEN FAPV.ANSWERVALUE
	        END) ::DATE                                                        AS CINA_ASSESSMENT_START_DATE,
	    MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'WorkerOutcome'
		    	THEN FAPV.ANSWERVALUE
	        END)	                                                           AS OUTCOME  
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('94b3f530-a918-4f33-85c2-0ae355c9c2fd') --Child: Assessment
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.CONTROLNAME IN ('SeenAlone', 'CINCensus_startDateOfForm','WorkerOutcome')
        AND COALESCE(FAPV.DESIGNSUBNAME,'?') NOT IN (
				--Trailing spaces, just to be safe.
				'CLA report for review 20 days ','CLA report for review 20 days',
				'CLA report for review 3 Months',
				'CLA report for review 6 months ','CLA report for review 6 months'
			)
    GROUP BY   FAPV.ANSWERFORSUBJECTID,
               FAPV.INSTANCEID,
               FAPV.DATECOMPLETED 
 )

 
SELECT 
 	ASSESSMENT.CINA_ASSESSMENT_ID                              AS "cina_assessment_id",                -- metadata={"item_ref":"CINA001A"}
	CIN_EPISODE.CINE_PERSON_ID                                 AS "cina_person_id",                    -- metadata={"item_ref":"CINA002A"}
	CIN_EPISODE.CINE_REFERRAL_ID                               AS "cina_referral_id",                  -- metadata={"item_ref":"CINA010A"}
	ASSESSMENT.CINA_ASSESSMENT_START_DATE                      AS "cina_assessment_start_date",        -- metadata={"item_ref":"CINA003A"}
	ASSESSMENT.CINA_ASSESSMENT_CHILD_SEEN                      AS "cina_assessment_child_seen",        -- metadata={"item_ref":"CINA004A"}
	ASSESSMENT.CINA_ASSESSMENT_AUTH_DATE                       AS "cina_assessment_auth_date",         -- metadata={"item_ref":"CINA005A"}
	JSON_BUILD_OBJECT(
	 'OUTCOME_NFA_FLAG',                      CASE WHEN ASSESSMENT.OUTCOME IN ('Case Closure','Step down to Universal Services/Signposting')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_NFA_S47_END_FLAG',              'N',
	 'OUTCOME_STRATEGY_DISCUSSION_FLAG',      CASE WHEN ASSESSMENT.OUTCOME IN ('Progress to Child Protection')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,     
	 'OUTCOME_CLA_REQUEST_FLAG',              CASE WHEN ASSESSMENT.OUTCOME IN ('Recommend Child looked after planning')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_PRIVATE_FOSTERING_FLAG',        CASE WHEN ASSESSMENT.OUTCOME IN ('Privately fostered child not deemed to be child in need')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_LEGAL_ACTION_FLAG',             'N',
	 'OUTCOME_PROV_OF_SERVICES_FLAG',         CASE WHEN ASSESSMENT.OUTCOME IN ('Recommend Child in Need planning', 'Continue with existing plan')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_PROV_OF_SB_CARE_FLAG',          CASE WHEN ASSESSMENT.OUTCOME IN ('Short Break (Child in need)')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,     
	 'OUTCOME_SPECIALIST_ASSESSMENT_FLAG',    'N',
	 'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', 'N',
	 'OUTCOME_OTHER_ACTIONS_FLAG',            'N',
	 'OTHER_OUTCOMES_EXIST_FLAG',             CASE WHEN ASSESSMENT.OUTCOME IN ('Refer to Early Intervention','Transfer (CIN / CP / CLA)')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'TOTAL_NO_OF_OUTCOMES',                  ''   )           AS "cina_assessment_outcome_json", --metadata={"item_ref:"CINA006A"}
	CASE WHEN ASSESSMENT.OUTCOME IN ('Case Closure','Step down to Universal Services/Signposting')
	     THEN 'Y'
	     ELSE 'N'
	END                                                        AS "cina_assessment_outcome_nfa", --metadata={"item_ref:"CINA009A"}
	TEAM.ALLOCATED_TEAM                                        AS "cina_assessment_team",        -- metadata={"item_ref":"CINA007A"}
	WORKER.ALLOCATED_WORKER                                    AS "cina_assessment_worker_id"    -- metadata={"item_ref":"CINA008A"}
FROM CIN_EPISODE
JOIN ASSESSMENT ON ASSESSMENT.CINA_PERSON_ID = CIN_EPISODE.CINE_PERSON_ID 
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE > CIN_EPISODE.CINE_REFERRAL_DATE
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < CIN_EPISODE.CINE_CLOSE_DATE
LEFT JOIN WORKER ON WORKER.PERSONID = ASSESSMENT.CINA_PERSON_ID 
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= WORKER.WORKER_START_DATE
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < WORKER.WORKER_END_DATE
LEFT JOIN TEAM ON TEAM.PERSONID = ASSESSMENT.CINA_PERSON_ID 
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= TEAM.TEAM_START_DATE
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < TEAM.TEAM_END_DATE
                         
