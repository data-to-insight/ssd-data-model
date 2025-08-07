/*
=============================================================================
Object Name: ssd_early_help_episodes
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

EH_EPISODE AS (  ----------CIN Episodes
    SELECT 
        PERSONID,
        EH_REFERRAL_DATE,
        EH_CLOSE_DATE,
        MAX(EH_CLOSE_REASON)          AS EH_CLOSE_REASON,
        MIN(EH_REFERRAL_ID)           AS EH_REFERRAL_ID
    FROM (    
        SELECT 
            EH.PERSONID                                                  AS PERSONID,
            MIN(EH.PRIMARY_CODE_STARTDATE)                               AS EH_REFERRAL_DATE,
            CASE
	    	    WHEN BOOL_AND(PRIMARY_CODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(PRIMARY_CODE_ENDDATE)
	        END                                                           AS EH_CLOSE_DATE,
	        MAX(ENDREASON)                                                AS EH_CLOSE_REASON,
	        MAX(EPISODE_ID)                                               AS EH_REFERRAL_ID
        FROM (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, PRIMARY_CODE_STARTDATE) AS EPISODE,
	            CASE WHEN NEXT_START_FLAG = 1
	                 THEN EPISODEID
	            END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   EH.PERSONID, 
                   EH.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
	               EH.STARTDATE::DATE                                                 AS PRIMARY_CODE_STARTDATE,
                   EH.ENDDATE::DATE                                                   AS PRIMARY_CODE_ENDDATE,
                   EH.ENDREASON,
                   CASE WHEN EH.STARTDATE >= LAG(EH.STARTDATE ) OVER (PARTITION BY EH.PERSONID ORDER BY EH.STARTDATE, EH.ENDDATE NULLS LAST) 
                           AND EH.STARTDATE <= COALESCE(LAG(EH.ENDDATE) OVER (PARTITION BY EH.PERSONID ORDER BY EH.STARTDATE, EH.ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM CLASSIFICATIONPERSONVIEW  EH
               WHERE EH.STATUS NOT IN ('DELETED')
                   AND EH.CLASSIFICATIONCODEID IN (699,1271)
                   AND EH.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
               ORDER BY EH.PERSONID,
	                    EH.ENDDATE:: DATE DESC NULLS FIRST,
	                    EH.STARTDATE:: DATE DESC 
	             ) EH
	       
	          )EH
    	--WHERE  PERSONID = 266     
        GROUP BY PERSONID, EPISODE 
        ) EH
        
    GROUP BY  PERSONID,
              EH_REFERRAL_DATE,
              EH_CLOSE_DATE 
),

CLOSURE AS (
    SELECT DISTINCT  
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID  AS PERSONID,
        FAPV.DATECOMPLETED::DATE AS COMPLETED_DATE,
        MAX(CASE
			WHEN FAPV.CONTROLNAME = 'AnnexA_reasonForClosure1'
			  OR FAPV.CONTROLNAME = 'reasonForClosure1' 
			  OR FAPV.CONTROLNAME = 'reasonForCaseClosure'
			THEN FAPV.ANSWERVALUE
		END)                     AS REASON,
		MAX(CASE
			WHEN FAPV.CONTROLNAME = 'dateOfClosure'
			  OR FAPV.CONTROLNAME = 'dateCaseClosed' 
			 -- OR FAPV.CONTROLNAME = 'reasonForCaseClosure'
			THEN FAPV.ANSWERVALUE
		END)::DATE                     AS CLOSURE_DATE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE (FAPV.DESIGNGUID IN ('12bb8ca2-e585-4a09-a6dd-d5b6e910a3f0') --Early Help: Closure
           OR FAPV.DESIGNGUID IN ('57eef045-0dbb-4df4-8dbd-bb07acf99e99')) --Family Help: Closure
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         --AND INSTANCEID = 1830828
    GROUP BY  FAPV.INSTANCEID,
              FAPV.ANSWERFORSUBJECTID,
              FAPV.DATECOMPLETED 
),

REFERRAL AS (
    SELECT 
        *,
        CASE WHEN CLA.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
             WHEN CLA.PRIMARY_NEED_CAT = 'Child''s disability'             THEN 'N2'
             WHEN CLA.PRIMARY_NEED_CAT = 'Parental illness/disability'     THEN 'N3'
             WHEN CLA.PRIMARY_NEED_CAT = 'Family in acute stress'          THEN 'N4'
             WHEN CLA.PRIMARY_NEED_CAT = 'Family dysfunction'              THEN 'N5'
             WHEN CLA.PRIMARY_NEED_CAT = 'Socially unacceptable behaviour' THEN 'N6'
             WHEN CLA.PRIMARY_NEED_CAT = 'Low income'                      THEN 'N7'
             WHEN CLA.PRIMARY_NEED_CAT = 'Absent parenting'                THEN 'N8'
             WHEN CLA.PRIMARY_NEED_CAT = 'Cases other than child in need'  THEN 'N9'
             WHEN CLA.PRIMARY_NEED_CAT = 'Not stated'                      THEN 'N0'
        END  AS PRIMARY_NEED_RANK
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID                                       AS PERSONID,
            FAPV.INSTANCEID                                               AS ASSESSMENTID,
            FAPV.SUBMITTERPERSONID                                        AS SUBMITTERPERSONID,
            MAX(CASE
		        	WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'
		    	    THEN FAPV.ANSWERVALUE
		        END)                                                      AS REFERRAL_SOURCE,
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
	    		    THEN FAPV.ANSWERVALUE
	    	    END)                                                      AS NEXT_STEP,  
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
	    		    THEN FAPV.ANSWERVALUE
		        END)                                                      AS PRIMARY_NEED_CAT,
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'
	    		    THEN FAPV.DATEANSWERVALUE
	    	    END)                                                      AS DATE_OF_REFERRAL    
        FROM  FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f') --Child: Referral
            AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.ANSWERFORSUBJECTID,
                 FAPV.INSTANCEID,
                 FAPV.SUBMITTERPERSONID
           ) CLA      
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
)

SELECT
	EH_EPISODE.EH_REFERRAL_ID   AS "earl_episode_id",           --metadata={"item_ref:"EARL001A"}
	EH_EPISODE.PERSONID         AS "earl_person_id",            --metadata={"item_ref:"EARL002A"}
	EH_EPISODE.EH_REFERRAL_DATE AS "earl_episode_start_date",   --metadata={"item_ref:"EARL003A"}
	EH_EPISODE.EH_CLOSE_DATE    AS "earl_episode_end_date",     --metadata={"item_ref:"EARL004A"}
	REFERRAL.PRIMARY_NEED_CAT   AS "earl_episode_reason",       --metadata={"item_ref:"EARL005A"}
	CLOSURE.REASON              AS "earl_episode_end_reason",   --metadata={"item_ref:"EARL006A"}
	TEAM.ALLOCATED_TEAM         AS "earl_episode_organisation", --metadata={"item_ref:"EARL007A"}
	WORKER.ALLOCATED_WORKER     AS "earl_episode_worker_id"   --metadata={"item_ref:"EARL008A"}

FROM EH_EPISODE
LEFT JOIN CLOSURE ON CLOSURE.PERSONID = EH_EPISODE.PERSONID AND
                     (CLOSURE.COMPLETED_DATE = EH_EPISODE.EH_CLOSE_DATE OR CLOSURE.CLOSURE_DATE = EH_EPISODE.EH_CLOSE_DATE) 
LEFT JOIN LATERAL (
               SELECT
                   *
               FROM REFERRAL
               WHERE REFERRAL.PERSONID = EH_EPISODE.PERSONID
                 AND REFERRAL.DATE_OF_REFERRAL <= EH_EPISODE.EH_REFERRAL_DATE
               ORDER BY REFERRAL.DATE_OF_REFERRAL DESC 
               FETCH FIRST 1 ROW ONLY) REFERRAL ON TRUE
LEFT JOIN WORKER ON WORKER.PERSONID = EH_EPISODE.PERSONID
                         AND EH_EPISODE.EH_CLOSE_DATE > WORKER.WORKER_START_DATE
                         AND EH_EPISODE.EH_REFERRAL_DATE < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = EH_EPISODE.PERSONID 
                         AND EH_EPISODE.EH_CLOSE_DATE >= TEAM.TEAM_START_DATE
                         AND EH_EPISODE.EH_REFERRAL_DATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         

