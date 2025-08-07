

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

IRO_MEETING AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                       AS PERSONID,
        FAPV.INSTANCEID                                               AS ASSESSMENTID,
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
			    THEN FAPV.DATEANSWERVALUE
		    END)                                                      AS DATE_OF_MEETING    
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('2d9d174f-77ed-40bd-ac2b-cae8015ad799') --Child: IRO Review Record
        AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID
)             

SELECT
	CLA_EPISODE.EPISODEOFCAREID                                         AS "clae_cla_episode_id",                  -- metadata={"item_ref":"CLAE001A"}
	CLA_EPISODE.PERSONID                                                AS "clae_person_id",                       -- metadata={"item_ref":"CLAE002A"}
	CLA_EPISODE.EOCSTARTDATE                                            AS "clae_cla_episode_start_date",          -- metadata={"item_ref":"CLAE003A"}
	CLA_EPISODE.EOCSTARTREASONCODE                                      AS "clae_cla_episode_start_reason",        -- metadata={"item_ref":"CLAE004A"}
	CASE WHEN CLA_EPISODE.CATEGORYOFNEED = 'Abuse or neglect'                THEN 'N1'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Child''s disability'             THEN 'N2'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Parental illness/disability'     THEN 'N3'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family in acute stress'          THEN 'N4'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family dysfunction'              THEN 'N5'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Socially unacceptable behaviour' THEN 'N6'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Low income'                      THEN 'N7'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Absent parenting'                THEN 'N8'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Cases other than child in need'  THEN 'N9'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Not stated'                      THEN 'N0'
    END                                                                AS "clae_cla_primary_need",                 -- metadata={"item_ref":"CLAE009A"}
	CLA_EPISODE.EOCENDDATE                                             AS "clae_cla_episode_ceased_date",               -- metadata={"item_ref":"CLAE005A"}
	CLA_EPISODE.EOCENDREASONCODE                                       AS "clae_cla_episode_ceased_reason",        -- metadata={"item_ref":"CLAE006A"}
	CLA_EPISODE.PERIODOFCAREID                                         AS "clae_cla_id",                           -- metadata={"item_ref":"CLAE010A"}
	REFR.ASSESSMENTID                                                  AS "clae_referral_id",                      -- metadata={"item_ref":"CLAE011A"}
	CLA_EPISODE.PLACEMENTADDRESSID                                     AS "clae_cla_placement_id",                 -- metadata={"item_ref":"CLAE013A"}    
	CLA.ADMISSIONDATE                                                  AS "clae_entered_care_date",                -- metadata={"item_ref":"CLAE014A"} 
	IRO_MEETING.DATE_OF_MEETING                                        AS "clae_cla_last_iro_contact_date"         -- metadata={"item_ref":"CLAE012A"}
	
FROM CLAEPISODEOFCAREVIEW CLA_EPISODE	
LEFT JOIN LATERAL (  
        SELECT *  
        FROM REFERRAL REFR
        WHERE CLA_EPISODE.PERSONID = REFR.PERSONID
           AND CLA_EPISODE.EOCSTARTDATE >= REFR.DATE_OF_REFERRAL
        ORDER BY REFR.DATE_OF_REFERRAL DESC
        FETCH FIRST 1 ROW ONLY
           ) REFR  ON TRUE 
           
LEFT JOIN CLAPERIODOFCAREVIEW CLA ON CLA.PERSONID = CLA_EPISODE.PERSONID AND CLA.PERIODOFCAREID = CLA_EPISODE.PERIODOFCAREID  
LEFT JOIN LATERAL (
        SELECT 
            *
        FROM IRO_MEETING    
        WHERE CLA_EPISODE.PERSONID = IRO_MEETING.PERSONID
          AND IRO_MEETING.DATE_OF_MEETING >= CLA.ADMISSIONDATE 
          AND IRO_MEETING.DATE_OF_MEETING <= COALESCE(CLA.DISCHARGEDATE,CURRENT_DATE)
        ORDER BY  IRO_MEETING.DATE_OF_MEETING DESC 
        FETCH FIRST 1 ROW ONLY) IRO_MEETING ON TRUE
WHERE CLA_EPISODE.PERSONID  NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)        

