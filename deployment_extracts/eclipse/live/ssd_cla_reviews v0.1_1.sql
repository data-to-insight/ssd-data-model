/*
=============================================================================
Object Name: ssd_cla_reviews
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_cla_episodes
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

CLA_REVIEW AS(
    SELECT 
        CLA_REVIEW.*,
        CLA.PERIODOFCAREID 
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID    AS PERSONID,
	        FAPV.INSTANCEID 		   AS FORMID,
	        MAX(CASE
		        WHEN FAPV.CONTROLNAME = 'dateOfNextReview'
		        THEN FAPV.ANSWERVALUE
	        END) :: DATE               AS NEXT_REVIEW,
	        MAX(CASE
		        WHEN FAPV.CONTROLNAME = 'dateOfReview'
		        THEN FAPV.ANSWERVALUE
	        END)::DATE                 AS DATE_OF_REVIEW   
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('b5c5c8d8-5ba7-4919-a3cd-9722e8e90aaf') --Child in Care:  IRO decisions
            AND FAPV.INSTANCESTATE = 'COMPLETE'
            AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
        GROUP BY FAPV.ANSWERFORSUBJECTID ,
	             FAPV.INSTANCEID      
         ) CLA_REVIEW
    LEFT JOIN CLAPERIODOFCAREVIEW CLA ON CLA.PERSONID = CLA_REVIEW.PERSONID
          AND CLA_REVIEW.DATE_OF_REVIEW >= CLA.ADMISSIONDATE AND CLA_REVIEW.DATE_OF_REVIEW <= COALESCE(CLA.DISCHARGEDATE,CURRENT_DATE)  
   
)


SELECT
    IRO_REVIEW.FORMID         AS "clar_cla_review_id",           --metadata={"item_ref:"CLAR001A"}
	CLA_REVIEW.PERIODOFCAREID AS "clar_cla_id",                  --metadata={"item_ref:"CLAR011A"}
	PREVIOUSR.NEXT_REVIEW     AS "clar_cla_review_due_date",     --metadata={"item_ref:"CLAR003A"}
	CLA_REVIEW.DATE_OF_REVIEW AS "clar_cla_review_date",         --metadata={"item_ref:"CLAR004A"}
	'N'                       AS "clar_cla_review_cancelled",    --metadata={"item_ref:"CLAR012A"}
	IRO_REVIEW.PARTICIPATION  AS "clar_cla_review_participation" --metadata={"item_ref:"CLAR007A"}
FROM CLA_REVIEW
LEFT JOIN LATERAL (
           SELECT
               *
           FROM  CLA_REVIEW PREVIOUSR
           WHERE PREVIOUSR.PERSONID = CLA_REVIEW.PERSONID
                 AND PREVIOUSR.PERIODOFCAREID = CLA_REVIEW.PERIODOFCAREID
                 AND PREVIOUSR.DATE_OF_REVIEW < CLA_REVIEW.DATE_OF_REVIEW
           ORDER BY PREVIOUSR.DATE_OF_REVIEW DESC
           FETCH FIRST 1 ROW ONLY) PREVIOUSR ON TRUE 
LEFT JOIN (
 	      SELECT
	     	  FAPV.ANSWERFORSUBJECTID 	AS PERSONID,
	          FAPV.INSTANCEID 			AS FORMID,
	          MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'howWasTheChildAbleToContributeTheirViewsToTheReview'
		          THEN FAPV.SHORTANSWERVALUE
	          END)                      AS PARTICIPATION,
	          MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
		          THEN FAPV.ANSWERVALUE
	          END)::DATE                AS DATE_OF_MEETING       
	     FROM FORMANSWERPERSONVIEW FAPV
         WHERE FAPV.DESIGNGUID IN ('79f3495c-134f-4e69-b00f-7621925419f7') --Independent Reviewing Officer: Quality assurance
            AND FAPV.INSTANCESTATE = 'COMPLETE'
            AND FAPV.designsubname = 'Child/young person in care review' 
            AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
         GROUP BY FAPV.ANSWERFORSUBJECTID,
	              FAPV.INSTANCEID ) IRO_REVIEW ON IRO_REVIEW.PERSONID = CLA_REVIEW.PERSONID
	                                    AND IRO_REVIEW.DATE_OF_MEETING = CLA_REVIEW.DATE_OF_REVIEW