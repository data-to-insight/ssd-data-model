
-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_s47_enquiry;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_s47_enquiry (
    s47e_s47_enquiry_id             VARCHAR(48) PRIMARY KEY, -- metadata={"item_ref":"S47E001A"}
    s47e_referral_id                VARCHAR(48),             -- metadata={"item_ref":"S47E010A"}
    s47e_person_id                  VARCHAR(48),             -- metadata={"item_ref":"S47E002A"}
    s47e_s47_start_date             TIMESTAMP,               -- metadata={"item_ref":"S47E004A"}
    s47e_s47_end_date               TIMESTAMP,               -- metadata={"item_ref":"S47E005A"}
    s47e_s47_nfa                    CHAR(1),                 -- metadata={"item_ref":"S47E006A"}
    s47e_s47_outcome_json           VARCHAR(1000),           -- metadata={"item_ref":"S47E007A"}
    s47e_s47_completed_by_team      VARCHAR(48),             -- metadata={"item_ref":"S47E009A"}
    s47e_s47_completed_by_worker_id VARCHAR(100)             -- metadata={"item_ref":"S47E008A"}
);

TRUNCATE TABLE ssd_s47_enquiry;

INSERT INTO ssd_s47_enquiry (
    s47e_s47_enquiry_id,
    s47e_referral_id,
    s47e_person_id,
    s47e_s47_start_date,
    s47e_s47_end_date,
    s47e_s47_nfa,
    s47e_s47_outcome_json,
    s47e_s47_completed_by_team,
    s47e_s47_completed_by_worker_id
)
EXCLUSIONS AS (
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


WORKER AS (    -------Responsible social worker AND team 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS id,
        PPR.PERSONID                         AS personid,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS allocated_worker,
        PPR.STARTDATE                        AS worker_start_date,
        PPR.CLOSEDATE                        AS worker_end_date,
        PPR.PROFESSIONALTEAMID               AS professional_team_fk
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW' 
),

TEAM AS (    -------Responsible team 
    SELECT 
        PPR.RELATIONSHIPID   AS id,
        PPR.PERSONID         AS personid,
        PPR.ORGANISATIONID   AS allocated_team,
        PPR.DATESTARTED      AS team_start_date,
        PPR.DATEENDED        AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
),

CIN_EPISODE AS (  ----------CIN Episodes
    SELECT 
        cine_person_id,
        cine_referral_date,
        cine_close_date,
        MAX(cine_close_reason)  AS cine_close_reason,
        MIN(cine_referral_id)   AS cine_referral_id
    FROM (    
        SELECT 
            CLA.PERSONID        AS cine_person_id,
            MIN(CLA.primary_code_startdate) AS cine_referral_date,
            CASE
                WHEN BOOL_AND(primary_code_enddate IS NOT NULL) IS FALSE
                    THEN NULL
                ELSE MAX(primary_code_enddate)
            END                 AS cine_close_date,
            MAX(endreason)      AS cine_close_reason,
            MAX(episode_id)     AS cine_referral_id
        FROM (
            SELECT  
                *,
                SUM(next_start_flag) OVER (
                    PARTITION BY personid 
                    ORDER BY personid, primary_code_startdate
                ) AS episode,
                CASE WHEN next_start_flag = 1
                     THEN episodeid
                END              AS episode_id     
            FROM (
                SELECT 
                    CLA.PERSONID                         AS personid, 
                    CLA.CLASSIFICATIONASSIGNMENTID       AS episodeid,
                    CLA.STARTDATE::DATE                  AS primary_code_startdate,
                    CLA.ENDDATE::DATE                    AS primary_code_enddate,
                    CLA.ENDREASON                        AS endreason,
                    CASE 
                        WHEN CLA.STARTDATE >= LAG(CLA.STARTDATE) OVER (
                                 PARTITION BY CLA.PERSONID 
                                 ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                             )
                         AND CLA.STARTDATE <= COALESCE(
                                 LAG(CLA.ENDDATE) OVER (
                                     PARTITION BY CLA.PERSONID 
                                     ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                                 ),
                                 CURRENT_DATE
                             ) + INTERVAL '1 day' 
                            THEN 0
                        ELSE 1
                    END          AS next_start_flag     
                FROM CLASSIFICATIONPERSONVIEW CLA
                WHERE CLA.STATUS NOT IN ('DELETED')
                  AND CLA.CLASSIFICATIONPATHID IN (23, 10)
                ORDER BY CLA.PERSONID,
                         CLA.ENDDATE::DATE DESC NULLS FIRST,
                         CLA.STARTDATE::DATE DESC 
            ) CLA
        ) CLA
        GROUP BY personid, episode 
    ) CLA
    GROUP BY  cine_person_id,
              cine_referral_date,
              cine_close_date 
),

FAPV AS (
    SELECT
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID,
        MAX(CASE 
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
                THEN FAPV.DATEANSWERVALUE
            END)                 AS startdate,
        FAPV.DATECOMPLETED::DATE AS completiondate,
        MAX(CASE 
                WHEN FAPV.CONTROLNAME IN ('CINCensus_unsubWhatNeedsToHappenNext',
                                          'CINCensus_whatNeedsToHappenNext')
                THEN FAPV.ANSWERVALUE
            END)                 AS outcome,
        MAX(CASE 
                WHEN FAPV.CONTROLNAME IN ('CINCensus_outcomeOfSection47Enquiry')
                THEN FAPV.ANSWERVALUE
            END)                 AS summary_utcome
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)	
    GROUP BY 
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID,
        FAPV.DATECOMPLETED
)

SELECT
    FAPV.INSTANCEID              AS s47e_s47_enquiry_id,           -- metadata={"item_ref:"S47E001A"}
    CIN_EPISODE.cine_referral_id AS s47e_referral_id,              -- metadata={"item_ref:"S47E010A"}
    FAPV.ANSWERFORSUBJECTID      AS s47e_person_id,                -- metadata={"item_ref:"S47E002A"}
    FAPV.startdate               AS s47e_s47_start_date,           -- metadata={"item_ref:"S47E004A"}
    FAPV.completiondate          AS s47e_s47_end_date,             -- metadata={"item_ref:"S47E005A"}
    CASE 
        WHEN FAPV.outcome = 'No further action' 
            THEN 'Y'
        ELSE 'N' 
    END                         AS s47e_s47_nfa,                   -- metadata={"item_ref:"S47E006A"}
    JSON_BUILD_OBJECT( 
        'OUTCOME_NFA_FLAG',
            CASE 
                WHEN FAPV.outcome = 'No further action' 
                    THEN 'Y'
                ELSE 'N' 
            END,
        'OUTCOME_LEGAL_ACTION_FLAG',        'N', 
        'OUTCOME_PROV_OF_SERVICES_FLAG',    'N',
        'OUTCOME_CP_CONFERENCE_FLAG',
            CASE 
                WHEN FAPV.outcome = 'Convene initial child protection conference' 
                    THEN 'Y'
                ELSE 'N' 
            END, 
        'OUTCOME_NFA_CONTINUE_SINGLE_FLAG',
            CASE 
                WHEN FAPV.outcome IN ('Continue discussion and plan',
                                      'Continue assessment / plan',
                                      'Continue assessment and plan') 
                    THEN 'Y'
                ELSE 'N' 
            END, 
        'OUTCOME_MONITOR_FLAG',             'N', 
        'OTHER_OUTCOMES_EXIST_FLAG',
            CASE 
                WHEN FAPV.outcome = 'Further strategy meeting' 
                    THEN 'Y'
                ELSE 'N' 
            END,
        'TOTAL_NO_OF_OUTCOMES',             ' ',
        'OUTCOME_COMMENTS',                 FAPV.summary_utcome
    )                          AS s47e_s47_outcome_json,           -- metadata={"item_ref:"S47E007A"}
    TEAM.allocated_team         AS s47e_s47_completed_by_team,     -- metadata={"item_ref":"S47E009A"}
    WORKER.allocated_worker     AS s47e_s47_completed_by_worker_id -- metadata={"item_ref:"S47E008A"}
FROM FAPV
LEFT JOIN WORKER 
       ON WORKER.personid = FAPV.ANSWERFORSUBJECTID 
      AND FAPV.startdate >= WORKER.worker_start_date
      AND FAPV.startdate < COALESCE(WORKER.worker_end_date, CURRENT_DATE)
LEFT JOIN TEAM 
       ON TEAM.personid = FAPV.ANSWERFORSUBJECTID 
      AND FAPV.startdate >= TEAM.team_start_date
      AND FAPV.startdate < COALESCE(TEAM.team_end_date, CURRENT_DATE)                         
LEFT JOIN CIN_EPISODE 
       ON FAPV.ANSWERFORSUBJECTID = CIN_EPISODE.cine_person_id 
      AND FAPV.startdate >= CIN_EPISODE.cine_referral_date
      AND FAPV.startdate < COALESCE(CIN_EPISODE.cine_close_date, CURRENT_DATE);
