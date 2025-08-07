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
	INSTANCEID                      AS "miss_table_id",                   --metadata={"item_ref:"MISS001A"}
	SUBJECTID                       AS "miss_person_id",                  --metadata={"item_ref:"MISS002A"}
	MISS_MISSING_EPISODE_START_DATE AS "miss_missing_episode_start_date", --metadata={"item_ref:"MISS003A"}
	MISS_MISSING_EPISODE_TYPE       AS "miss_missing_episode_type",       --metadata={"item_ref:"MISS004A"}
	MISS_MISSING_EPISODE_END_DATE   AS "miss_missing_episode_end_date",   --metadata={"item_ref:"MISS005A"}
	MISS_MISSING_RHI_OFFERED        AS "miss_missing_rhi_offered",        --metadata={"item_ref:"MISS006A"}
	MISS_MISSING_RHI_ACCEPTED       AS "miss_missing_rhi_accepted"        --metadata={"item_ref:"MISS007A"}

FROM (
    SELECT 
        FAPV.INSTANCEID,
        FAPV.SUBJECTID,
        FAPV.PAGETITLE,
        MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('DATECHILDLASTSEEN%')
			    THEN FAPV.DATEANSWERVALUE
		    END) AS MISS_MISSING_EPISODE_START_DATE,
	    MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('ABSENCETYPE%')
		    	THEN FAPV.ANSWERVALUE
	    	END)	AS MISS_MISSING_EPISODE_TYPE,
	   MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('FOUNDREPORTDATE%')
			    THEN FAPV.DATEANSWERVALUE
		   END) AS	MISS_MISSING_EPISODE_END_DATE,
	   MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('HASARETURNHOMEINTERVIEWBEENOFFERED%')
			    THEN FAPV.ANSWERVALUE
		   END)	AS MISS_MISSING_RHI_OFFERED,
	   MAX(CASE
			    WHEN UPPER(FAPV.CONTROLNAME) LIKE ('HASTHERETURNHOMEINTERVIEWBEENACCEPTED%')
			    THEN FAPV.ANSWERVALUE
		   END)	AS MISS_MISSING_RHI_ACCEPTED		
    

    FROM FORMANSWERPERSONVIEW FAPV

    WHERE FAPV.DESIGNGUID IN ('e112bee8-4f50-4904-8ebc-842e2fd33994') --Missing: Child reported missing
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.INSTANCEID,
             FAPV.SUBJECTID,
             FAPV.PAGETITLE) AS FAPV