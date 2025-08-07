/*
=============================================================================
Object Name: ssd_sdq_scores
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
    INSTANCEID               AS "csdq_table_id",           --metadata={"item_ref:"CSDQ001A"}
    PERSONID                 AS "csdq_person_id",          --metadata={"item_ref:"CSDQ002A"}
    completed_date           AS "csdq_sdq_completed_date", --metadata={"item_ref:"CSDQ003A"}
    CASE WHEN REASON = 'No form returned as child was aged under 4 or over 17 at date of latest assessment'   THEN 'SDQ1'
         WHEN REASON = 'Carer(s) refused to complete and return questionnaire'                                THEN 'SDQ2'
         WHEN REASON = 'Not possible to complete the questionnaire due to severity of the child’s disability' THEN 'SDQ3'
         WHEN REASON = 'Other'                                                                                THEN 'SDQ4'
         WHEN REASON = 'Child or young person refuses to allow an SDQ to be completed'                        THEN 'SDQ5'
    END                      AS "csdq_sdq_reason",         --metadata={"item_ref:"CSDQ004A"}
    SCORE                    AS "csdq_sdq_score"           --metadata={"item_ref:"CSDQ005A"}
FROM (
    SELECT 
	    FAPV.INSTANCEID                AS INSTANCEID, 
	    FAPV.ANSWERFORSUBJECTID        AS PERSONID,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = '903Return_dateOfLatestSDQRecord'
		          THEN FAPV.ANSWERVALUE
	    END)::DATE                      AS completed_date ,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = '903Return_reasonForNotSubmittingStrengthsAndDifficultiesQuestionnaireInPeriod'
		          THEN FAPV.ANSWERVALUE
	    END)                            AS REASON,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'youngPersonsStrengthsAndDifficultiesQuestionnaireScore'
		          THEN FAPV.ANSWERVALUE
	   END)                             AS SCORE 

	FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fb7f6ffc-e8a1-4b45-8eaa-356a5be33895') --Child in Care: Strengths and difficulties questionnaire scores
       AND FAPV.INSTANCESTATE = 'COMPLETE'
       AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY  FAPV.INSTANCEID,
              FAPV.ANSWERFORSUBJECTID) FAPV

