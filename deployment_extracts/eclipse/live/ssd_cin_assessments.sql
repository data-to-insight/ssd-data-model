-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cin_assessments;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cin_assessments
(
    cina_assessment_id           VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINA001A"}
    cina_person_id               VARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
    cina_referral_id             VARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
    cina_assessment_start_date   TIMESTAMP,                 -- metadata={"item_ref":"CINA003A"}
    cina_assessment_child_seen   CHAR(1),                   -- metadata={"item_ref":"CINA004A"}
    cina_assessment_auth_date    TIMESTAMP,                 -- metadata={"item_ref":"CINA005A"}             
    cina_assessment_outcome_json VARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
    cina_assessment_outcome_nfa  CHAR(1),                   -- metadata={"item_ref":"CINA009A"}
    cina_assessment_team         VARCHAR(48),               -- metadata={"item_ref":"CINA007A"}
    cina_assessment_worker_id    VARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
);

TRUNCATE TABLE ssd_cin_assessments;

INSERT INTO ssd_cin_assessments (
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date,
    cina_assessment_outcome_json,
    cina_assessment_outcome_nfa,
    cina_assessment_team,
    cina_assessment_worker_id
)
-- WITH EXCLUSIONS AS (
--     SELECT
--         PV.PERSONID
--     FROM PERSONVIEW PV
--     WHERE PV.PERSONID IN (  -- hard filter admin/test/duplicate records on system
--             1,2,3,4,5,6
--         )
--         OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
--         OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
--         OR UPPER(PV.SURNAME)  LIKE '%DUPLICATE%'
-- ),
WITH ALL_CIN_EPISODES AS (
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
          AND (
                CLA.CLASSIFICATIONPATHID IN (4 , 51) -- CIN & CP classification
                OR CLA.CLASSIFICATIONCODEID IN (1270)  -- FAMILY Help CIN classification
              )
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
        WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f') -- Child: Referral
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
                END                                                                                      AS EPISODE_ID     
            FROM (
                SELECT 
                    PERSONID, 
                    EPISODEID,
                    EPISODE_STARTDATE,
                    EPISODE_ENDDATE,
                    ENDREASON,
                    CASE 
                        WHEN CLA.EPISODE_STARTDATE >= LAG(CLA.EPISODE_STARTDATE) OVER (
                                 PARTITION BY CLA.PERSONID
                                 ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST
                             )
                         AND CLA.EPISODE_STARTDATE <= COALESCE(
                                 LAG(CLA.EPISODE_ENDDATE) OVER (
                                     PARTITION BY CLA.PERSONID
                                     ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST
                                 ),
                                 CURRENT_DATE
                             ) + INTERVAL '1 day'
                            THEN 0
                        ELSE 1
                    END AS NEXT_START_FLAG     
                FROM ALL_CIN_EPISODES  CLA
                ORDER BY CLA.PERSONID,
                         CLA.EPISODE_ENDDATE::DATE DESC NULLS FIRST,
                         CLA.EPISODE_STARTDATE::DATE DESC 
            ) CLA
        ) CLA
        GROUP BY PERSONID, EPISODE 
    ) CLA
    LEFT JOIN ALL_CIN_EPISODES
           ON ALL_CIN_EPISODES.PERSONID = CLA.PERSONID
          AND ALL_CIN_EPISODES.EPISODE_ENDDATE = CLA.CINE_CLOSE_DATE
    LEFT JOIN LATERAL (
        SELECT
            *
        FROM REFERRAL 
        WHERE REFERRAL.PERSONID = CLA.PERSONID 
          AND REFERRAL.DATE_OF_REFERRAL <= CLA.CINE_START_DATE
        ORDER BY REFERRAL.DATE_OF_REFERRAL DESC 
        FETCH FIRST 1 ROW ONLY
    ) REFERRAL ON TRUE 
),

WORKER AS (    -- Responsible social worker 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
        PPR.STARTDATE                        AS WORKER_START_DATE,
        PPR.CLOSEDATE                        AS WORKER_END_DATE
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW' 
),

TEAM AS (      -- Responsible team
    SELECT 
        PPR.RELATIONSHIPID                   AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.ORGANISATIONID                   AS ALLOCATED_TEAM,
        PPR.DATESTARTED                      AS TEAM_START_DATE,
        PPR.DATEENDED                        AS TEAM_END_DATE
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT' 
),

ASSESSMENT AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                                AS PERSONID,
        FAPV.INSTANCEID                                                        AS CINA_ASSESSMENT_ID,
        FAPV.DATECOMPLETED::DATE                                               AS CINA_ASSESSMENT_AUTH_DATE,
        CASE WHEN MAX(CASE
                        WHEN FAPV.CONTROLNAME = 'SeenAlone'
                            THEN FAPV.ANSWERVALUE
                    END) IN ('Child seen alone', 'Child seen with others')  
             THEN 'Y'
             ELSE 'N'
        END	                                                                   AS CINA_ASSESSMENT_CHILD_SEEN, 
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'CINCensus_startDateOfForm'
                    THEN FAPV.ANSWERVALUE
            END)::DATE                                                         AS CINA_ASSESSMENT_START_DATE,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'WorkerOutcome'
                    THEN FAPV.ANSWERVALUE
            END)	                                                           AS OUTCOME  
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('94b3f530-a918-4f33-85c2-0ae355c9c2fd') -- Child: Assessment
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.CONTROLNAME IN ('SeenAlone', 'CINCensus_startDateOfForm','WorkerOutcome')
      AND COALESCE(FAPV.DESIGNSUBNAME,'?') IN (
            'Reassessment',
            'Single assessment'
        )
      -- back check person exists in ssd_person cohort, exclusions applied
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = FAPV.ANSWERFORSUBJECTID
        )
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID,
             FAPV.DATECOMPLETED 
               
    UNION ALL 
    
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                                AS PERSONID,
        FAPV.INSTANCEID                                                        AS CINA_ASSESSMENT_ID,
        FAPV.DATECOMPLETED::DATE                                               AS CINA_ASSESSMENT_AUTH_DATE,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'wasTheChildSeen'
                    THEN FAPV.ANSWERVALUE
            END)                                                               AS CINA_ASSESSMENT_CHILD_SEEN, 
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'dateOfDocument'
                    THEN FAPV.ANSWERVALUE
            END)::DATE                                                         AS CINA_ASSESSMENT_START_DATE,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'outcomes2'
                    THEN FAPV.ANSWERVALUE
            END)	                                                           AS OUTCOME  
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('6d3b942a-37ad-40ef-8cc6-b202d2cd1c0e') -- Family Help: Discussion
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.CONTROLNAME IN ('wasTheChildSeen', 'dateOfDocument','outcomes2')
      -- back check person exists in ssd_person cohort, exclusions applied
      AND EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = FAPV.ANSWERFORSUBJECTID
        )
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID,
             FAPV.DATECOMPLETED 
)

SELECT 
    CONCAT(ASSESSMENT.PERSONID, ASSESSMENT.CINA_ASSESSMENT_ID) AS cina_assessment_id,                -- metadata={"item_ref":"CINA001A"}
    ASSESSMENT.PERSONID                                        AS cina_person_id,                    -- metadata={"item_ref":"CINA002A"}
    CIN_EPISODE.REFERRALID                                     AS cina_referral_id,                  -- metadata={"item_ref":"CINA010A"}
    ASSESSMENT.CINA_ASSESSMENT_START_DATE                      AS cina_assessment_start_date,        -- metadata={"item_ref":"CINA003A"}
    ASSESSMENT.CINA_ASSESSMENT_CHILD_SEEN                      AS cina_assessment_child_seen,        -- metadata={"item_ref":"CINA004A"}
    ASSESSMENT.CINA_ASSESSMENT_AUTH_DATE                       AS cina_assessment_auth_date,         -- metadata={"item_ref":"CINA005A"}
    JSON_BUILD_OBJECT(
        'OUTCOME_NFA_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Case Closure',
                        'Step down to Universal Services/Signposting',
                        'Advice, Guidance and signposting',
                        'Case Closure',
                        'Transfer to Early Support Plan'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,
        'OUTCOME_NFA_S47_END_FLAG',              'N',
        'OUTCOME_STRATEGY_DISCUSSION_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Progress to Child Protection',
                        'Recommend/Progress to Strategy discussion'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,     
        'OUTCOME_CLA_REQUEST_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Recommend Child looked after planning',
                        'Privately fostered child',
                        'Recommend Children and Young People in Care planning'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,
        'OUTCOME_PRIVATE_FOSTERING_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Privately fostered child not deemed to be child in need'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,
        'OUTCOME_LEGAL_ACTION_FLAG',             'N',
        'OUTCOME_PROV_OF_SERVICES_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Recommend Child in Need planning',
                        'Continue with existing plan',
                        'Recommend Disabled Children and Young People',
                        'Recommend Family Help SEND Service',
                        'Recommend/Progress to Family Help Discussion'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,
        'OUTCOME_PROV_OF_SB_CARE_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Short Break (Child in need)'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,     
        'OUTCOME_SPECIALIST_ASSESSMENT_FLAG',    'N',
        'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', 'N',
        'OUTCOME_OTHER_ACTIONS_FLAG',            'N',
        'OTHER_OUTCOMES_EXIST_FLAG',
            CASE WHEN ASSESSMENT.OUTCOME IN (
                        'Refer to Early Intervention',
                        'Transfer (CIN / CP / CLA)'
                    )
                 THEN 'Y'
                 ELSE 'N'
            END,
        'TOTAL_NO_OF_OUTCOMES',                  ''
    )::TEXT                                                     AS cina_assessment_outcome_json, -- metadata={"item_ref":"CINA006A"}
    CASE WHEN ASSESSMENT.OUTCOME IN (
             'Case Closure',
             'Step down to Universal Services/Signposting',
             'Advice, Guidance and signposting',
             'Case Closure',
             'Transfer to Early Support Plan'
         )
         THEN 'Y'
         ELSE 'N'
    END                                                         AS cina_assessment_outcome_nfa,  -- metadata={"item_ref":"CINA009A"}
    TEAM.ALLOCATED_TEAM                                         AS cina_assessment_team,         -- metadata={"item_ref":"CINA007A"}
    WORKER.ALLOCATED_WORKER                                     AS cina_assessment_worker_id     -- metadata={"item_ref":"CINA008A"}
FROM ASSESSMENT 
LEFT JOIN LATERAL (
    SELECT
        *
    FROM CIN_EPISODE 
    WHERE ASSESSMENT.PERSONID = CIN_EPISODE.PERSONID
      AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= CIN_EPISODE.DATE_OF_REFERRAL
    ORDER BY CIN_EPISODE.DATE_OF_REFERRAL DESC 
    FETCH FIRST 1 ROW ONLY
) CIN_EPISODE ON TRUE 
LEFT JOIN WORKER
       ON WORKER.PERSONID = ASSESSMENT.PERSONID 
      AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= WORKER.WORKER_START_DATE
      AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < WORKER.WORKER_END_DATE
LEFT JOIN TEAM
       ON TEAM.PERSONID = ASSESSMENT.PERSONID 
      AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= TEAM.TEAM_START_DATE
      AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < TEAM.TEAM_END_DATE;
