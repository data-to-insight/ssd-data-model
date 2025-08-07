
WITH INITIAL_ASESSMENT AS (
    SELECT DISTINCT  
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID  AS PERSONID,
        FAPV.DATECOMPLETED::DATE AS COTE_OF_COMPLETED,
        MAX(CASE
				WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
					THEN FAPV.ANSWERVALUE
		END)::DATE                     AS DATE_OF_MEETING
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         AND DESIGNSUBNAME = 'Child Protection - Initial Conference'
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DATECOMPLETED     
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

CP_CATEGORY AS (
    SELECT 
        CP_CATEGORY.PERSONID,
        CP_CATEGORY.NAME,
        CP_CATEGORY.STARTDATE:: DATE AS STARTDATE,
        CP_CATEGORY.ENDDATE:: DATE   AS ENDDATE
    FROM CLASSIFICATIONPERSONVIEW CP_CATEGORY
    WHERE CP_CATEGORY.CLASSIFICATIONPATHID = 81 
),    

ALL_CIN_EPISODES AS (
    SELECT 
        *
    FROM (    
	    SELECT 
	        CLA.PERSONID, 
	        CLA.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
		    CLA.STARTDATE::DATE                                                 AS EPISODE_STARTDATE,
	        CLA.ENDDATE::DATE                                                   AS EPISODE_ENDDATE,
	        CLA.ENDREASON
	    FROM CLASSIFICATIONPERSONVIEW  CLA
	    WHERE CLA.STATUS NOT IN ('DELETED')
	     AND (CLA.CLASSIFICATIONPATHID IN (4 , 51) -- CIN & CP classification
	      OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classificaion
	      
	    UNION ALL 
	    
	    SELECT
			CLA_EPISODE.PERSONID,
			CLA_EPISODE.EPISODEOFCAREID,
			CLA_EPISODE.EOCSTARTDATE,
			CLA_EPISODE.EOCENDDATE,
			CLA_EPISODE.EOCENDREASON
		FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
		) CIN
	ORDER BY PERSONID,
	         EPISODE_STARTDATE
	         
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


CIN_EPISODE AS (
    SELECT 
        CLA.*,
        ALL_CIN_EPISODES.ENDREASON  AS CINE_REASON_END,
        CONCAT(CLA.PERSONID, REFERRAL.ASSESSMENTID)      AS REFERRALID,
        REFERRAL.DATE_OF_REFERRAL,
	    REFERRAL.PRIMARY_NEED_RANK,
        REFERRAL.SUBMITTERPERSONID,
        REFERRAL.REFERRAL_SOURCE,
        REFERRAL.NEXT_STEP
    FROM (  
        SELECT 
            CLA.PERSONID,
            MIN(CLA.EPISODE_STARTDATE)                                    AS CINE_START_DATE,
            CASE
	    	    WHEN BOOL_AND(EPISODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(EPISODE_ENDDATE)
	        END                                                           AS CINE_CLOSE_DATE,
	        MAX(EPISODE_ID)                                               AS LAST_CINE_ID
        FROM (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, EPISODE_STARTDATE) AS EPISODE,
	            CASE WHEN NEXT_START_FLAG = 1
	                 THEN EPISODEID
	            END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   PERSONID, 
                   EPISODEID,
	               EPISODE_STARTDATE,
                   EPISODE_ENDDATE,
                   ENDREASON,
                   CASE WHEN CLA.EPISODE_STARTDATE >= LAG(CLA.EPISODE_STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST) 
                           AND CLA.EPISODE_STARTDATE <= COALESCE(LAG(CLA.EPISODE_ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM ALL_CIN_EPISODES  CLA
               ORDER BY CLA.PERSONID,
	                    CLA.EPISODE_ENDDATE:: DATE DESC NULLS FIRST,
	                    CLA.EPISODE_STARTDATE:: DATE DESC 
	             ) CLA
	       
	          )CLA
    	GROUP BY PERSONID, EPISODE 
        ) CLA
    LEFT JOIN  ALL_CIN_EPISODES ON ALL_CIN_EPISODES.PERSONID = CLA.PERSONID AND ALL_CIN_EPISODES.EPISODE_ENDDATE = CLA.CINE_CLOSE_DATE
    LEFT JOIN LATERAL (
            SELECT
                *
            FROM REFERRAL 
            WHERE REFERRAL.PERSONID = CLA.PERSONID 
                AND REFERRAL.DATE_OF_REFERRAL <= CLA.CINE_START_DATE
            ORDER BY  REFERRAL.DATE_OF_REFERRAL DESC 
            FETCH FIRST 1 ROW ONLY) REFERRAL ON TRUE 
),

CP_PLAN AS (
    SELECT 
        MIN(CLA.CLAID)     AS CLAID,
        CLA.PERSONID,
        MIN(CLA.STARTDATE) AS STARTDATE,
        CASE
	        WHEN BOOL_AND(ENDDATE IS NOT NULL) IS FALSE
	        THEN NULL
            ELSE MAX(ENDDATE)
       END                 AS ENDDATE
    FROM (	
        SELECT  
            *,
            SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, STARTDATE ROWS UNBOUNDED PRECEDING) AS EPISODE 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID    AS CLAID, 
                CLA.PERSONID, 
                CLA.STARTDATE::DATE               AS STARTDATE,
                CLA.ENDDATE::DATE                 AS ENDDATE,
                CASE WHEN CLA.STARTDATE > LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                            AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE) 
                     THEN 0
                     ELSE 1
                END                               AS NEXT_START_FLAG     
            FROM CLASSIFICATIONPERSONVIEW  CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
                  AND CLA.CLASSIFICATIONPATHID IN (51) -- CP classification
	              AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
                ORDER BY CLA.PERSONID,
	                     CLA.ENDDATE DESC NULLS FIRST,
	                     CLA.STARTDATE DESC 
	             ) CLA
	       
	          )CLA
        GROUP BY CLA.PERSONID, CLA.EPISODE
)  


SELECT
	CP_PLAN.CLAID                       AS "cppl_cp_plan_id", --metadata={"item_ref:"CPPL001A"}
	CIN_EPISODE.REFERRALID              AS "cppl_referral_id", --metadata={"item_ref:"CPPL007A"}
	INITIAL_ASESSMENT.INSTANCEID        AS "cppl_icpc_id", --metadata={"item_ref:"CPPL008A"}
	CP_PLAN.PERSONID                    AS "cppl_person_id", --metadata={"item_ref:"CPPL002A"}
	CP_PLAN.STARTDATE:: DATE            AS "cppl_cp_plan_start_date", --metadata={"item_ref:"CPPL003A"}
	CP_PLAN.ENDDATE:: DATE              AS "cppl_cp_plan_end_date", --metadata={"item_ref:"CPPL004A"}
	CP_CATEGORY_FIRST.NAME              AS "cppl_cp_plan_initial_category", --metadata={"item_ref:"CPPL009A"}
	NULL                                AS "cppl_cp_plan_ola",             --metadata={"item_ref:"CPPL0101A"}
	CP_CATEGORY_LATEST.NAME             AS "cppl_cp_plan_latest_category" --metadata={"item_ref:"CPPL010A"}
FROM CP_PLAN
LEFT JOIN LATERAL (
                SELECT
                    *
                FROM INITIAL_ASESSMENT
                WHERE INITIAL_ASESSMENT.PERSONID = CP_PLAN.PERSONID
                     AND INITIAL_ASESSMENT.DATE_OF_MEETING <= CP_PLAN.STARTDATE:: DATE
                ORDER BY INITIAL_ASESSMENT.DATE_OF_MEETING DESC
                FETCH FIRST 1 ROW ONLY
                ) INITIAL_ASESSMENT ON TRUE 
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CIN_EPISODE
                WHERE CIN_EPISODE.PERSONID = CP_PLAN.PERSONID
                    AND CIN_EPISODE.DATE_OF_REFERRAL <= CP_PLAN.STARTDATE:: DATE
                ORDER BY CIN_EPISODE.DATE_OF_REFERRAL DESC
                FETCH FIRST 1 ROW ONLY
                ) CIN_EPISODE ON TRUE  
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CP_CATEGORY
                WHERE CP_CATEGORY.PERSONID = CP_PLAN.PERSONID 
                    AND CP_CATEGORY.STARTDATE <= CP_PLAN.STARTDATE::DATE
                ORDER BY CP_CATEGORY.STARTDATE DESC    
                FETCH FIRST 1 ROW ONLY
                ) CP_CATEGORY_LATEST ON TRUE
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CP_CATEGORY
                WHERE CP_CATEGORY.PERSONID = CP_PLAN.PERSONID 
                    AND CP_CATEGORY.STARTDATE <= CP_PLAN.STARTDATE::DATE
                ORDER BY CP_CATEGORY.STARTDATE     
                FETCH FIRST 1 ROW ONLY
                ) CP_CATEGORY_FIRST ON TRUE                
 