

-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cin_plans;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cin_plans (
    cinp_cin_plan_id          VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id          VARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id            VARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date  TIMESTAMP,                 -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date    TIMESTAMP,                 -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team        VARCHAR(48),               -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_id   VARCHAR(100)               -- metadata={"item_ref":"CINP006A"}
);

TRUNCATE TABLE ssd_cin_plans;

INSERT INTO ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)

WITH EXCLUSIONS AS (
	SELECT
		PV.PERSONID
	FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
		OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
		OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
		OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
),

WORKER AS (    -------Responsible social worker 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS id,
        PPR.PERSONID                         AS personid,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS allocated_worker,
        PPR.STARTDATE                        AS worker_start_date,
        PPR.CLOSEDATE                        AS worker_end_date
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW' 
),

TEAM AS (    -------Responsible team
    SELECT 
        PPR.RELATIONSHIPID                   AS id,
        PPR.PERSONID                         AS personid,
        PPR.ORGANISATIONID                   AS allocated_team,
        PPR.DATESTARTED                      AS team_start_date,
        PPR.DATEENDED                        AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT' 
),

ALL_CIN_EPISODES AS (
    SELECT 
        *
    FROM (    
        SELECT 
            CLA.PERSONID, 
            CLA.CLASSIFICATIONASSIGNMENTID AS episodeid,
            CLA.STARTDATE::DATE            AS episode_startdate,
            CLA.ENDDATE::DATE              AS episode_enddate,
            CLA.ENDREASON
        FROM CLASSIFICATIONPERSONVIEW CLA
        WHERE CLA.STATUS NOT IN ('DELETED')
          AND (CLA.CLASSIFICATIONPATHID IN (4, 51) -- CIN & CP classification
               OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classification
        UNION ALL 
        SELECT
            CLA_EPISODE.PERSONID,
            CLA_EPISODE.EPISODEOFCAREID,
            CLA_EPISODE.EOCSTARTDATE,
            CLA_EPISODE.EOCENDDATE,
            CLA_EPISODE.EOCENDREASON
        FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
    ) CIN
    ORDER BY personid,
             episode_startdate
),

REFERRAL AS (
    SELECT 
        *,
        CASE WHEN CLA.primary_need_cat = 'Abuse or neglect'                THEN 'N1'
             WHEN CLA.primary_need_cat = 'Child''s disability'             THEN 'N2'
             WHEN CLA.primary_need_cat = 'Parental illness/disability'     THEN 'N3'
             WHEN CLA.primary_need_cat = 'Family in acute stress'          THEN 'N4'
             WHEN CLA.primary_need_cat = 'Family dysfunction'              THEN 'N5'
             WHEN CLA.primary_need_cat = 'Socially unacceptable behaviour' THEN 'N6'
             WHEN CLA.primary_need_cat = 'Low income'                      THEN 'N7'
             WHEN CLA.primary_need_cat = 'Absent parenting'                THEN 'N8'
             WHEN CLA.primary_need_cat = 'Cases other than child in need'  THEN 'N9'
             WHEN CLA.primary_need_cat = 'Not stated'                      THEN 'N0'
        END  AS primary_need_rank
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID AS personid,
            FAPV.INSTANCEID         AS assessmentid,
            FAPV.SUBMITTERPERSONID  AS submitterpersonid,
            MAX(CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'
                    THEN FAPV.ANSWERVALUE
                END)                AS referral_source,
            MAX(CASE
                    WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
                    THEN FAPV.ANSWERVALUE
                END)                AS next_step,  
            MAX(CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
                    THEN FAPV.ANSWERVALUE
                END)                AS primary_need_cat,
            MAX(CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'
                    THEN FAPV.DATEANSWERVALUE
                END)                AS date_of_referral    
        FROM FORMANSWERPERSONVIEW FAPV
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
        ALL_CIN_EPISODES.endreason  AS cine_reason_end,
        CONCAT(CLA.personid, REFERRAL.assessmentid) AS referralid,
        REFERRAL.date_of_referral,
        REFERRAL.primary_need_rank,
        REFERRAL.submitterpersonid,
        REFERRAL.referral_source,
        REFERRAL.next_step
    FROM (  
        SELECT 
            CLA.personid,
            MIN(CLA.episode_startdate) AS cine_start_date,
            CASE
                WHEN BOOL_AND(episode_enddate IS NOT NULL) IS FALSE
                    THEN NULL
                ELSE MAX(episode_enddate)
            END                       AS cine_close_date,
            MAX(episode_id)           AS last_cine_id
        FROM (
            SELECT  
                *,
                SUM(next_start_flag) OVER (PARTITION BY personid ORDER BY personid, episode_startdate) AS episode,
                CASE WHEN next_start_flag = 1
                     THEN episodeid
                END AS episode_id     
            FROM (
                SELECT 
                    personid, 
                    episodeid,
                    episode_startdate,
                    episode_enddate,
                    endreason,
                    CASE 
                        WHEN CLA.episode_startdate >= LAG(CLA.episode_startdate) OVER (
                                 PARTITION BY CLA.personid 
                                 ORDER BY CLA.episode_startdate, CLA.episode_enddate NULLS LAST
                             )
                         AND CLA.episode_startdate <= COALESCE(
                                 LAG(CLA.episode_enddate) OVER (
                                     PARTITION BY CLA.personid 
                                     ORDER BY CLA.episode_startdate, CLA.episode_enddate NULLS LAST
                                 ),
                                 CURRENT_DATE
                             ) + INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                    END AS next_start_flag     
                FROM ALL_CIN_EPISODES CLA
                ORDER BY CLA.personid,
                         CLA.episode_enddate::DATE DESC NULLS FIRST,
                         CLA.episode_startdate::DATE DESC 
            ) CLA
        ) CLA
        GROUP BY personid, episode 
    ) CLA
    LEFT JOIN ALL_CIN_EPISODES 
           ON ALL_CIN_EPISODES.personid = CLA.personid 
          AND ALL_CIN_EPISODES.episode_enddate = CLA.cine_close_date
    LEFT JOIN LATERAL (
            SELECT
                *
            FROM REFERRAL 
            WHERE REFERRAL.personid = CLA.personid 
              AND REFERRAL.date_of_referral <= CLA.cine_start_date
            ORDER BY REFERRAL.date_of_referral DESC 
            FETCH FIRST 1 ROW ONLY
        ) REFERRAL ON TRUE 
),

CIN_PLAN AS (
    SELECT 
        MIN(CLA.claid)     AS claid,
        CLA.personid,
        MIN(CLA.startdate) AS startdate,
        CASE
            WHEN BOOL_AND(enddate IS NOT NULL) IS FALSE
                THEN NULL
            ELSE MAX(enddate)
        END               AS enddate
    FROM (	
        SELECT  
            *,
            SUM(next_start_flag) OVER (
                PARTITION BY personid 
                ORDER BY personid, startdate ROWS UNBOUNDED PRECEDING
            ) AS episode 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID AS claid, 
                CLA.PERSONID                   AS personid, 
                CLA.STARTDATE::DATE            AS startdate,
                CLA.ENDDATE::DATE              AS enddate,
                CASE 
                    WHEN CLA.STARTDATE > LAG(CLA.STARTDATE) OVER (
                             PARTITION BY CLA.PERSONID 
                             ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                         )
                     AND CLA.STARTDATE <= COALESCE(
                             LAG(CLA.ENDDATE) OVER (
                                 PARTITION BY CLA.PERSONID 
                                 ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                             ),
                             CURRENT_DATE
                         )
                        THEN 0
                        ELSE 1
                END AS next_start_flag     
            FROM CLASSIFICATIONPERSONVIEW CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
              AND (CLA.CLASSIFICATIONPATHID IN (4) -- CIN classification
                   OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classification
              AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
            ORDER BY CLA.PERSONID,
                     CLA.ENDDATE DESC NULLS FIRST,
                     CLA.STARTDATE DESC 
        ) CLA
    ) CLA
    GROUP BY CLA.personid, CLA.episode
)  

SELECT
    CIN_PLAN.claid           AS cinp_cin_plan_id,         -- metadata={"item_ref":"CINP001A"}
    CIN_EPISODE.referralid   AS cinp_referral_id,         -- metadata={"item_ref:"CINP007A"}
    CIN_PLAN.personid        AS cinp_person_id,           -- metadata={"item_ref:"CINP002A"}
    CIN_PLAN.startdate       AS cinp_cin_plan_start_date, -- metadata={"item_ref:"CINP003A"}
    CIN_PLAN.enddate         AS cinp_cin_plan_end_date,   -- metadata={"item_ref:"CINP004A"}
    TEAM.allocated_team      AS cinp_cin_plan_team,       -- metadata={"item_ref:"CINP005A"}
    WORKER.allocated_worker  AS cinp_cin_plan_worker_id   -- metadata={"item_ref:"CINP006A"}
FROM CIN_PLAN 
LEFT JOIN LATERAL (
    SELECT
        *
    FROM WORKER 
    WHERE WORKER.personid = CIN_PLAN.personid
      AND COALESCE(CIN_PLAN.enddate, CURRENT_DATE) > WORKER.worker_start_date
      AND CIN_PLAN.startdate < COALESCE(WORKER.worker_end_date, CURRENT_DATE)
    ORDER BY WORKER.worker_start_date DESC        
    FETCH FIRST 1 ROW ONLY        
) WORKER ON TRUE        
LEFT JOIN LATERAL (
    SELECT 
        * 
    FROM TEAM
    WHERE TEAM.personid = CIN_PLAN.personid 
      AND COALESCE(CIN_PLAN.enddate, CURRENT_DATE) > TEAM.team_start_date
      AND CIN_PLAN.startdate < COALESCE(TEAM.team_end_date, CURRENT_DATE)  
    ORDER BY TEAM.team_start_date DESC 
    FETCH FIRST 1 ROW ONLY 
) TEAM ON TRUE
LEFT JOIN LATERAL (
    SELECT
        *
    FROM CIN_EPISODE
    WHERE CIN_PLAN.personid = CIN_EPISODE.personid 
      AND CIN_PLAN.startdate >= CIN_EPISODE.date_of_referral
      AND CIN_PLAN.startdate <= COALESCE(CIN_EPISODE.cine_close_date, CURRENT_DATE)
    ORDER BY CIN_EPISODE.date_of_referral DESC 
    FETCH FIRST 1 ROW ONLY 
) CIN_EPISODE ON TRUE;
