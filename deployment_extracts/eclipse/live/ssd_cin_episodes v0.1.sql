
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
)

    
SELECT
	CIN_EPISODE.REFERRALID                                                                             AS "cine_referral_id",             -- metadata={"item_ref":"CINE001A"}
	CIN_EPISODE.PERSONID                                                                               AS "cine_person_id",               -- metadata={"item_ref":"CINE002A"}
	CIN_EPISODE.DATE_OF_REFERRAL                                                                       AS "cine_referral_date",           -- metadata={"item_ref":"CINE003A"}
	CIN_EPISODE.PRIMARY_NEED_RANK                                                                      AS "cine_cin_primary_need_code",   -- metadata={"item_ref":"CINE010A"}
	CASE WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Acquaintance'                               THEN '1B'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'A & E'                                      THEN '3E'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Anonymous'                                  THEN '9'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Early help'                                 THEN '5D'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Education Services'                         THEN '2B'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'External e.g. from another local authority' THEN '5C'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Family Member/Relative/Carer'               THEN '1A'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'GP'                                         THEN '3A'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Health Visitor'                             THEN '3B'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Housing'                                    THEN '4'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other'                                      THEN '1D'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other Health Services'                      THEN '3F'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other - including children centres'         THEN '8'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other internal e,g, BC Council'             THEN '5B'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other Legal Agency'                         THEN '7'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Other Primary Health Services'              THEN '3D'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Police'                                     THEN '6'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'School'                                     THEN '2A'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'School Nurse'                               THEN '3C'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Self'                                       THEN '1C'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Social care e.g. adult social care'         THEN '5A'
	     WHEN CIN_EPISODE.REFERRAL_SOURCE = 'Unknown'                                    THEN '10'
	END                                                                                              AS "cine_referral_source_code",       -- metadata={"item_ref":"CINE004A"}  
	CIN_EPISODE.REFERRAL_SOURCE                                                                      AS "cine_referral_source_desc",       -- metadata={"item_ref":"CINE012A"}
	JSON_BUILD_OBJECT( 
	'OUTCOME_SINGLE_ASSESSMENT_FLAG',  CASE WHEN CIN_EPISODE.NEXT_STEP IN ('Assessment','Family Help Discussion (10 days)','Family Help Discussion (CAT) -10 days','Family Help Discussion (DCYP)- 10 days')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_NFA_FLAG',                CASE WHEN CIN_EPISODE.NEXT_STEP IN ('No further action','Signpost')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_STRATEGY_DISCUSSION_FLAG',CASE WHEN CIN_EPISODE.NEXT_STEP = 'Strategy Discussion/Meeting'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CLA_REQUEST_FLAG', 'N',
	'OUTCOME_NON_AGENCY_ADOPTION_FLAG',CASE WHEN CIN_EPISODE.NEXT_STEP = 'Adoption or Special Guardianship support'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_PRIVATE_FOSTERING_FLAG',  CASE WHEN CIN_EPISODE.NEXT_STEP = 'Private Fostering'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CP_TRANSFER_IN_FLAG',     CASE WHEN CIN_EPISODE.NEXT_STEP = 'Transfer in child protection conference'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CP_CONFERENCE_FLAG',      'N',
	'OUTCOME_CARE_LEAVER_FLAG',        'N',
	'OTHER_OUTCOMES_EXIST_FLAG',       CASE WHEN CIN_EPISODE.NEXT_STEP IN ('Asylum seeker','Court Report Request Section 7/Section 37','Disabled children service',
                                                                   'No recourse to public funds','Family Help Discussion(45 Day)','Family Help Discussion (45 days)',
                                                                   'Early Intervention','Universal Services')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END)                                                    	AS "cine_referral_outcome_json", --metadata={"item_ref:"CINE005A"}
	CASE WHEN CIN_EPISODE.NEXT_STEP = 'No further action'
	     THEN 'Y'
	     ELSE 'N'
	END                                                                                         AS "cine_referral_nfa",          -- metadata={"item_ref":"CINE011A"} 
	CASE WHEN CIN_EPISODE.CINE_REASON_END IN ('Adopted','Adopted - Consent dispensed with', 
	            'Adopted - Application unopposed', 'Adopted - PRE 2000', 'PRE-Adopted', 'Adopted consent dispensed with by court',
	            'ADOPTED/FREED FOR ADOPTION - PRE 2000','Adopted - application for an adoption order unopposed')                        THEN 'RC1' 
	     WHEN CIN_EPISODE.CINE_REASON_END IN ('Died', 'Child/young person has died', 'Child/young person has died')                     THEN 'RC2'
	     WHEN CIN_EPISODE.CINE_REASON_END IN ('Child Arrangements Order','Residence order or a child arrangements order')               THEN 'RC3'
         WHEN CIN_EPISODE.CINE_REASON_END IN ('Special Guardianship Order'  ,'Special guardianship made to former foster carers',
		         'Special guardianship made to other than former foster carers', 
		         'Special guardianship relative/friend not former foster carer(s)',
		         'Special guardianship other not relative/friend/former foster carer')                                                  THEN 'RC4'
		WHEN CIN_EPISODE.CINE_REASON_END = 'Child moved permanently from area'                                                          THEN 'RC5'
		WHEN CIN_EPISODE.CINE_REASON_END IN ('Transferred to Adult Services', 'Transferred to care of Adult Social Services',
		         'Transferred to residential care funded by Adult Social Services')                                                     THEN 'RC6'
		WHEN CIN_EPISODE.CINE_REASON_END = 'Case closed after assessment, no further action'                                            THEN 'RC8'
		WHEN CIN_EPISODE.CINE_REASON_END IN( 'Case closed after assessment, referred to early help',
		                                       'Case closed after assessment, referred to EH')                                          THEN 'RC9'
		WHEN CIN_EPISODE.CINE_CLOSE_DATE IS NULL                                                                                        THEN ''
		                                                                                                                                ELSE 'RC7'
	END                                                                                          AS "cine_close_reason",        -- metadata={"item_ref":"CINE006A"}
	--CIN_EPISODE.CINE_CLOSE_REASON, 
	CIN_EPISODE.CINE_CLOSE_DATE                                                                  AS "cine_close_date",          -- metadata={"item_ref":"CINE007A"}
	--TEAM.ORGANISATIONID                                                                          AS "cine_referral_team",
	NULL                                                                                         AS "cine_referral_team",       -- metadata={"item_ref":"CINE008A"}   
	CIN_EPISODE.SUBMITTERPERSONID                                                                   AS "cine_referral_worker_id"   -- metadata={"item_ref":"CINE009A"}
    
FROM CIN_EPISODE	
        