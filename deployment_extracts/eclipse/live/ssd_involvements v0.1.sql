/*
=============================================================================
Object Name: ssd_involvements
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_professionals
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
              
)

SELECT
	PPR.PERSONRELATIONSHIPRECORDID       AS "invo_involvements_id",        --metadata={"item_ref:"INVO005A"}
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "invo_professional_id",        --metadata={"item_ref:"INVO006A"}
	PPR.RELATIONSHIPCLASSCODE            AS "invo_professional_role_id",   --metadata={"item_ref:"INVO007A"}
	TEAM.ALLOCATED_TEAM                  AS "invo_professional_team",      --metadata={"item_ref:"INVO009A"}
	PPR.STARTDATE                        AS "invo_involvement_start_date", --metadata={"item_ref:"INVO002A"}
	PPR.CLOSEDATE                        AS "invo_involvement_end_date",  --metadata={"item_ref:"INVO003A"}
	PPR.STARTREASONCODE                  AS "invo_worker_change_reason",   --metadata={"item_ref:"INVO004A"}
	PPR.PERSONID                         AS "invo_person_id",              --metadata={"item_ref:"INVO011A"}
	CIN_EPISODE.CINE_REFERRAL_ID         AS "invo_referral_id"             --metadata={"item_ref:"INVO010A"}

FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN CIN_EPISODE ON PPR.PERSONID =  CIN_EPISODE.CINE_PERSON_ID 
                      AND PPR.STARTDATE >= CIN_EPISODE.CINE_REFERRAL_DATE
                      AND PPR.STARTDATE < COALESCE(CIN_EPISODE.CINE_CLOSE_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = PPR.PERSONID 
                         AND COALESCE(PPR.CLOSEDATE,CURRENT_DATE) >= TEAM.TEAM_START_DATE
                         AND PPR.STARTDATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                      
WHERE PPR.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)


