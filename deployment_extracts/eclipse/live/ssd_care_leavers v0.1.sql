/*
=============================================================================
Object Name: ssd_care_leavers
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
=============================================================================
*/

WITH CARELEAVER_REVIEW AS(
   SELECT 
   *,
     RANK () OVER (PARTITION BY PERSONID ORDER BY REIEW_DATE DESC) AS LATEST_REVIEW
   FROM (
    SELECT 
        FAPV.ANSWERFORSUBJECTID     AS PERSONID, 
        FAPV.INSTANCEID,
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'dateOfPathwayPlan'
			    THEN FAPV.DATEANSWERVALUE
		END) AS REIEW_DATE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('c17d1557-513d-443f-8013-a31eb541455b') --Care leavers: Pathway Needs assessment and plan 
        AND FAPV.INSTANCESTATE = 'COMPLETE'
     --   AND FAPV.ANSWERFORSUBJECTID = 75975
     --  AND FAPV.INSTANCEID = 2081278
GROUP BY FAPV.ANSWERFORSUBJECTID , 
    FAPV.INSTANCEID
    ) FAPV
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
    --AND PPR.PERSONID = 26647
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
)

SELECT
	CARELEAVER.CARELEAVERID               AS "clea_table_id",                         --metadata={"item_ref:"CLEA001A"}
	CARELEAVER.PERSONID                   AS "clea_person_id",                        --metadata={"item_ref:"CLEA002A"}
	CARELEAVER.ELIGIBILITY                AS "clea_care_leaver_eligibility",         --metadata={"item_ref:"CLEA003A"}
	CARELEAVER.INTOUCHCODE                AS "clea_care_leaver_in_touch",             --metadata={"item_ref:"CLEA004A"}
	CARELEAVER.CONTACTDATE::DATE          AS "clea_care_leaver_latest_contact",       --metadata={"item_ref:"CLEA005A"}
	CARELEAVER.ACCOMODATIONCODE           AS  "clea_care_leaver_accommodation",       --metadata={"item_ref:"CLEA006A"}
	CARELEAVER.ACCOMSUITABLE              AS "clea_care_leaver_accom_suitable",       --metadata={"item_ref:"CLEA007A"}
	CARELEAVER.MAINACTIVITYCODE           AS "clea_care_leaver_activity",             --metadata={"item_ref:"CLEA008A"}
	CARELEAVER_REVIEW.REIEW_DATE          AS "clea_pathway_plan_review_date",         --metadata={"item_ref:"CLEA009A"}
	WORKER.ALLOCATED_WORKER               AS "clea_care_leaver_personal_advisor",     --metadata={"item_ref:"CLEA010A"}
	TEAM.ALLOCATED_TEAM                   AS  "clea_care_leaver_allocated_team", --metadata={"item_ref:"CLEA011A"}
	WORKER.ALLOCATED_WORKER               AS "clea_care_leaver_worker_id"           --metadata={"item_ref:"CLEA012A"}
	
FROM (
	SELECT
	    CARELEAVER.CARELEAVERID,
	    CARELEAVER.PERSONID,
	    CARELEAVER.ELIGIBILITY,
	    CARELEAVER.INTOUCHCODE,
	    CARELEAVER.CONTACTDATE,
	    CARELEAVER.ACCOMODATIONCODE,
	    CASE WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered suitable'   THEN 1
	         WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered unsuitable' THEN 2
	    END    AS ACCOMSUITABLE,
	    CARELEAVER.MAINACTIVITYCODE,
	    RANK () OVER (PARTITION BY CARELEAVER.PERSONID ORDER BY CARELEAVER.CONTACTDATE DESC) AS LATEST_RECORD
	    FROM CLACARELEAVERDETAILSVIEW CARELEAVER
	    WHERE CARELEAVER.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
     	) CARELEAVER
LEFT JOIN CARELEAVER_REVIEW ON CARELEAVER_REVIEW.PERSONID = CARELEAVER.PERSONID	 AND CARELEAVER_REVIEW.LATEST_REVIEW = 1
LEFT JOIN WORKER ON WORKER.PERSONID = CARELEAVER.PERSONID 
                         AND CARELEAVER.CONTACTDATE >= WORKER.WORKER_START_DATE
                         AND CARELEAVER.CONTACTDATE <= COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = CARELEAVER.PERSONID 
                         AND CARELEAVER.CONTACTDATE >= TEAM.TEAM_START_DATE
                         AND CARELEAVER.CONTACTDATE <= COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         

WHERE LATEST_RECORD = 1
--AND CARELEAVER.PERSONID IN( 75975	, 41791)