/*
=============================================================================
Object Name: ssd_initial_cp_conference
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

CALENDAR AS (
	SELECT 
		GENERATE_SERIES::DATE "DATE",
		EXTRACT(DOW FROM GENERATE_SERIES) "DAY"
	FROM GENERATE_SERIES('2016-01-01',
						 CURRENT_TIMESTAMP::DATE,
						 interval '1 DAY')
),

WORKING_DAY_CALENDAR AS (
    SELECT DISTINCT
        C.*,
        ROW_NUMBER() OVER(ORDER BY C."DATE" ASC) RN
    FROM CALENDAR C
    --Take out bank holidays and weekends
    WHERE "DATE" NOT IN (
		'2016-01-01','2016-03-25','2016-03-28','2016-05-02','2016-05-30','2016-08-29','2016-12-26','2016-12-27',
		'2017-01-02','2017-04-14','2017-04-17','2017-05-01','2017-05-29','2017-08-28','2017-12-25','2017-12-26',
		'2018-01-01','2018-03-30','2018-04-02','2018-05-07','2018-05-28','2018-08-27','2018-12-25','2018-12-26',
		'2019-01-01','2019-04-19','2019-04-22','2019-05-06','2019-05-27','2019-08-26','2019-12-25','2019-12-26',
		'2020-01-01','2020-04-10','2020-04-13','2020-05-04','2020-05-25','2020-08-31','2020-12-25','2020-12-28','2020-12-29','2020-12-30','2020-12-31',
		'2021-01-01','2021-04-02','2021-04-05','2021-05-03','2021-05-31','2021-08-30','2021-12-27','2021-12-28','2021-12-29','2021-12-30','2021-12-31',
		'2022-01-03','2022-04-15','2022-04-18','2022-05-02','2022-06-02','2022-06-03','2022-08-29','2022-12-26','2022-12-27','2022-12-28','2022-12-29','2022-12-30',
		'2023-01-02','2023-04-07','2023-04-10','2023-05-01','2023-05-08','2023-05-29','2023-08-28','2023-12-25','2023-12-26','2023-12-27','2023-12-28','2023-12-29',
		'2024-01-01','2024-03-29','2024-04-01','2024-05-06','2024-05-27','2024-08-26','2024-12-25','2024-12-26','2024-12-27','2024-12-30','2024-12-31',
		'2025-01-01','2025-04-18','2025-04-21','2025-05-05','2025-05-26','2025-08-25','2025-12-25','2025-12-26'
	) 
        AND "DAY" NOT IN (6,0)
),

WORKING_DAY_RANKS AS (
	SELECT 
		GENERATE_SERIES::DATE "DATE",
		EXTRACT(DOW FROM GENERATE_SERIES) "DAY",
		COALESCE((SELECT MAX(WDC.RN) FROM WORKING_DAY_CALENDAR WDC WHERE WDC."DATE" <= GENERATE_SERIES),0) RANK
		
	FROM GENERATE_SERIES('2016-01-01',
						 CURRENT_TIMESTAMP::DATE,
						 interval '1 DAY')
),

INITIAL_ASESSMENT AS (
   SELECT 
       *
   FROM (
       SELECT DISTINCT  
           FAPV.INSTANCEID,
           FAPV.ANSWERFORSUBJECTID        AS PERSONID,
           FAPV.DATECOMPLETED::DATE       AS COMPLETIONDATE,
           MAX(CASE
				    WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
				    THEN FAPV.ANSWERVALUE
		   END)::DATE                     AS DATE_OF_MEETING,
		   MAX(CASE
		            WHEN FAPV.CONTROLNAME = 'AnnexAReturn_typeOfMeeting'
		            THEN FAPV.ANSWERVALUE
	       END)                           AS MEETING_TYPE,
	       MAX(CASE
		            WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
		            THEN FAPV.ANSWERVALUE
	       END)                           AS NEXT_STEP
       FROM  FORMANSWERPERSONVIEW FAPV
       WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         AND DESIGNSUBNAME = 'Child Protection - Initial Conference'
         AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
       GROUP BY FAPV.INSTANCEID,
                FAPV.ANSWERFORSUBJECTID,
                FAPV.DATECOMPLETED 
    )FAPV
    WHERE MEETING_TYPE IN ('Child Protection (Initial child protection conference)', 'Child Protection (Transfer in conference)')
),

ASESSMENT47 AS(
    SELECT
        *
    FROM (    
        SELECT
	    	FAPV.INSTANCEID ,
	    	FAPV.ANSWERFORSUBJECTID          AS PERSONID ,
		    MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
				     THEN FAPV.DATEANSWERVALUE
		    END) AS STARTDATE,
		    FAPV.DATECOMPLETED::DATE         AS COMPLETIONDATE,
	    	MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_unsubWhatNeedsToHappenNext', 'CINCensus_whatNeedsToHappenNext')
		    		 THEN FAPV.ANSWERVALUE
	        END)                             AS OUTCOME
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.INSTANCEID ,
		         FAPV.ANSWERFORSUBJECTID,
		         FAPV.DATECOMPLETED
    ) FAPV
    WHERE FAPV.OUTCOME = 'Convene initial child protection conference'
),  

STRATEGY_DISC AS (
    SELECT 
        *,
        TARR."DATE"                 AS TARGET_DATE
    FROM (    
        SELECT 
            FAPV.INSTANCEID ,
		    FAPV.ANSWERFORSUBJECTID AS PERSONID ,
		    MAX(CASE WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
			    	 THEN FAPV.DATEANSWERVALUE
	    	END)                    AS MEETING_DATE
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('f9a86a19-ea09-41f0-9403-a88e2b0e738a') --Child Protection: Strategy discussion
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.INSTANCEID ,
		         FAPV.ANSWERFORSUBJECTID,
		         FAPV.DATECOMPLETED
	    ) FAPV	
    LEFT JOIN WORKING_DAY_RANKS SDR ON SDR."DATE" = FAPV.MEETING_DATE 
    LEFT JOIN WORKING_DAY_RANKS TARR ON TARR.RANK = SDR.RANK + 15
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
    	--WHERE  PERSONID = 69     
        GROUP BY PERSONID, EPISODE 
        ) CLA
        
    GROUP BY  CINE_PERSON_ID,
              CINE_REFERRAL_DATE,
              CINE_CLOSE_DATE 
              
),
         
CP_PLAN AS (
    SELECT
	CP_PLAN.CLASSIFICATIONASSIGNMENTID  AS PLANID,
	CP_PLAN.PERSONID                    AS PERSONID,
	CP_PLAN.STARTDATE:: DATE            AS PLAN_START_DATE,
	CP_PLAN.ENDDATE:: DATE              AS PLAN_END_DATE,
	CIN_EPISODE.CINE_REFERRAL_ID
	FROM CLASSIFICATIONPERSONVIEW CP_PLAN
	LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CIN_EPISODE
                WHERE CIN_EPISODE.CINE_PERSON_ID = CP_PLAN.PERSONID
                    AND CIN_EPISODE.CINE_REFERRAL_DATE <= CP_PLAN.STARTDATE:: DATE
                ORDER BY CIN_EPISODE.CINE_REFERRAL_DATE DESC
                FETCH FIRST 1 ROW ONLY
                ) CIN_EPISODE ON TRUE 
WHERE CP_PLAN.CLASSIFICATIONPATHID = 51 
   AND CP_PLAN.STATUS NOT IN ('DELETED')
   AND CP_PLAN.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
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
	CONCAT(INITIAL_ASESSMENT.INSTANCEID,INITIAL_ASESSMENT.PERSONID) AS "icpc_icpc_id",          --metadata={"item_ref:"ICPC001A"}
	INITIAL_ASESSMENT.INSTANCEID                                    AS "icpc_icpc_meeting_id",  --metadata={"item_ref:"ICPC009A"}
	ASESSMENT47.INSTANCEID                                          AS "icpc_s47_enquiry_id",   --metadata={"item_ref:"ICPC002A"}
	INITIAL_ASESSMENT.PERSONID                                      AS "icpc_person_id",        --metadata={"item_ref:"ICPC010A"}
	CP_PLAN.PLANID                                                  AS "icpc_cp_plan_id",       --metadata={"item_ref:"ICPC011A"}
	CP_PLAN.CINE_REFERRAL_ID                                        AS "icpc_referral_id",      --metadata={"item_ref:"ICPC012A"}
	CASE WHEN INITIAL_ASESSMENT.MEETING_TYPE = 'Child Protection (Transfer in conference)'
	     THEN 'Y'
	     ELSE 'N'
	END                                                             AS "icpc_icpc_transfer_in", --metadata={"item_ref:"ICPC003A"}
	STRATEGY_DISC.TARGET_DATE                                       AS "icpc_icpc_target_date", --metadata={"item_ref:"ICPC004A"}
	INITIAL_ASESSMENT.DATE_OF_MEETING                               AS "icpc_icpc_date",        --metadata={"item_ref:"ICPC005A"}
	CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Set next review'
	     THEN 'Y'
	     ELSE 'N'
	END                                                             AS "icpc_icpc_outcome_cp_flag", --metadata={"item_ref:"ICPC013A"}
	JSON_BUILD_OBJECT( 
	    'OUTCOME_NFA_FLAG', CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Case closure' OR INITIAL_ASESSMENT.NEXT_STEP IS NULL
	                             THEN 'Y'
	                             ELSE 'N'
	                        END ,
	    'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', '',
	    'OUTCOME_SINGLE_ASSESSMENT_FLAG',        '',
	    'OUTCOME_PROV_OF_SERVICES_FLAG',         '', 
	    'OUTCOME_CP_FLAG',  CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Set next review'
	                             THEN 'Y'
	                             ELSE 'N'
	                        END ,
	    'OTHER_OUTCOMES_EXIST_FLAG', CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'CIN'
	                                      THEN 'Y'
	                                      ELSE 'N'
	                                 END ,
	    'TOTAL_NO_OF_OUTCOMES',     '',
	    'OUTCOME_COMMENTS'    ,      ''
	)                                                               AS  "icpc_icpc_outcome_json", --metadata={"item_ref:"ICPC006A"}
	TEAM.ALLOCATED_TEAM                                             AS "icpc_icpc_team", --metadata={"item_ref:"ICPC007A"}
	WORKER.ALLOCATED_WORKER                                         AS "icpc_icpc_worker_id" --metadata={"item_ref:"ICPC008A"}
FROM INITIAL_ASESSMENT	
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM ASESSMENT47
             WHERE ASESSMENT47.PERSONID = INITIAL_ASESSMENT.PERSONID
                   AND ASESSMENT47.STARTDATE <= INITIAL_ASESSMENT.DATE_OF_MEETING
             ORDER BY ASESSMENT47.STARTDATE DESC
             FETCH FIRST 1 ROW ONLY) ASESSMENT47 ON TRUE
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM STRATEGY_DISC
             WHERE STRATEGY_DISC.PERSONID = INITIAL_ASESSMENT.PERSONID
                   AND STRATEGY_DISC.MEETING_DATE <= INITIAL_ASESSMENT.DATE_OF_MEETING
             ORDER BY STRATEGY_DISC.MEETING_DATE DESC
             FETCH FIRST 1 ROW ONLY) STRATEGY_DISC ON TRUE             
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM CP_PLAN
             WHERE CP_PLAN.PERSONID = INITIAL_ASESSMENT.PERSONID
                 AND INITIAL_ASESSMENT.DATE_OF_MEETING <= CP_PLAN.PLAN_START_DATE
             ORDER BY CP_PLAN.PLAN_START_DATE
             FETCH FIRST 1 ROW ONLY) CP_PLAN ON TRUE  
 LEFT JOIN WORKER ON WORKER.PERSONID = INITIAL_ASESSMENT.PERSONID 
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING >= WORKER.WORKER_START_DATE
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)  
 LEFT JOIN TEAM ON TEAM.PERSONID = INITIAL_ASESSMENT.PERSONID  
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING >= TEAM.TEAM_START_DATE
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)  
LEFT JOIN WORKING_DAY_RANKS SDR ON SDR."DATE" = STRATEGY_DISC.MEETING_DATE                         
LEFT JOIN WORKING_DAY_RANKS IAR ON IAR."DATE" = INITIAL_ASESSMENT.DATE_OF_MEETING
                                      
--WHERE INITIAL_ASESSMENT.PERSONID = 101492