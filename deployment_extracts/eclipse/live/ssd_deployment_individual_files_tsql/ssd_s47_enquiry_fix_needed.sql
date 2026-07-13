
-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_s47_enquiry;
/* ===========================================
   CREATE TABLE
   =========================================== */

IF OBJECT_ID('ssd_s47_enquiry', 'U') IS NULL
BEGIN
    CREATE TABLE ssd_s47_enquiry (
        s47e_s47_enquiry_id             NVARCHAR(48) PRIMARY KEY,
        s47e_referral_id                NVARCHAR(48),
        s47e_person_id                  NVARCHAR(48),
        s47e_s47_start_date             DATETIME,
        s47e_s47_end_date               DATETIME,
        s47e_s47_nfa                    CHAR(1),
        s47e_s47_outcome_json           NVARCHAR(1000),
        s47e_s47_completed_by_team      NVARCHAR(48),
        s47e_s47_completed_by_worker_id NVARCHAR(100)
    );
END;

TRUNCATE TABLE ssd_s47_enquiry;

-- ============================================================
-- MAIN QUERY
-- ============================================================

;WITH EXCLUSIONS AS (
    SELECT PERSONID
    FROM PERSONVIEW
    WHERE PERSONID IN (1,2,3,4,5,6)
       OR ISNULL(DUPLICATED,'?') = 'DUPLICATE'
       OR UPPER(FORENAME) LIKE '%DUPLICATE%'
       OR UPPER(SURNAME)  LIKE '%DUPLICATE%'
),

WORKER AS (
    SELECT 
        PERSONRELATIONSHIPRECORDID AS id,
        PERSONID,
        PROFESSIONALRELATIONSHIPPERSONID AS allocated_worker,
        STARTDATE AS worker_start_date,
        CLOSEDATE AS worker_end_date,
        PROFESSIONALTEAMID
    FROM RELATIONSHIPPROFESSIONALVIEW
    WHERE ALLOCATEDWORKERCODE = 'AW'
),

TEAM AS (
    SELECT 
        RELATIONSHIPID AS id,
        PERSONID,
        ORGANISATIONID AS allocated_team,
        DATESTARTED AS team_start_date,
        DATEENDED   AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW
    WHERE ALLOCATEDTEAMCODE = 'AT'
),

-- ===========================================
-- CIN EPISODE (simplified but equivalent)
-- ===========================================

CIN_EPISODE AS (
    SELECT 
        PERSONID AS cine_person_id,
        MIN(CAST(STARTDATE AS DATE)) AS cine_referral_date,
        MAX(CAST(ENDDATE AS DATE))   AS cine_close_date,
        MAX(ENDREASON)               AS cine_close_reason,
        MAX(CLASSIFICATIONASSIGNMENTID) AS cine_referral_id
    FROM CLASSIFICATIONPERSONVIEW
    WHERE STATUS <> 'DELETED'
      AND CLASSIFICATIONPATHID IN (23,10)
    GROUP BY PERSONID
),

-- ===========================================
-- FORM DATA
-- ===========================================

FAPV AS (
    SELECT
        F.INSTANCEID,
        F.ANSWERFORSUBJECTID,
        MAX(CASE 
                WHEN F.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
                THEN F.DATEANSWERVALUE
            END) AS startdate,

        CAST(F.DATECOMPLETED AS DATE) AS completiondate,

        MAX(CASE 
                WHEN F.CONTROLNAME IN (
                    'CINCensus_unsubWhatNeedsToHappenNext',
                    'CINCensus_whatNeedsToHappenNext'
                )
                THEN F.ANSWERVALUE
            END) AS outcome,

        MAX(CASE 
                WHEN F.CONTROLNAME = 'CINCensus_outcomeOfSection47Enquiry'
                THEN F.ANSWERVALUE
            END) AS summary_outcome

    FROM FORMANSWERPERSONVIEW F
    WHERE F.DESIGNGUID = 'fdca0a95-8578-43ca-97ff-ad3a8adf57de'
      AND F.INSTANCESTATE = 'COMPLETE'
      AND F.ANSWERFORSUBJECTID NOT IN (SELECT PERSONID FROM EXCLUSIONS)
    GROUP BY 
        F.INSTANCEID,
        F.ANSWERFORSUBJECTID,
        F.DATECOMPLETED
)

-- ============================================================
-- INSERT
-- ============================================================

INSERT INTO ssd_s47_enquiry
SELECT
    F.INSTANCEID,
    C.cine_referral_id,
    F.ANSWERFORSUBJECTID,
    F.startdate,
    F.completiondate,

    CASE WHEN F.outcome = 'No further action' THEN 'Y' ELSE 'N' END,

    -- JSON converted to string
    '{'
    + '"OUTCOME_NFA_FLAG":"' + CASE WHEN F.outcome='No further action' THEN 'Y' ELSE 'N' END + '",'
    + '"OUTCOME_LEGAL_ACTION_FLAG":"N",'
    + '"OUTCOME_PROV_OF_SERVICES_FLAG":"N",'
    + '"OUTCOME_CP_CONFERENCE_FLAG":"' + CASE WHEN F.outcome='Convene initial child protection conference' THEN 'Y' ELSE 'N' END + '",'
    + '"OUTCOME_NFA_CONTINUE_SINGLE_FLAG":"' + CASE WHEN F.outcome IN (
            'Continue discussion and plan',
            'Continue assessment / plan',
            'Continue assessment and plan'
        ) THEN 'Y' ELSE 'N' END + '",'
    + '"OUTCOME_MONITOR_FLAG":"N",'
    + '"OTHER_OUTCOMES_EXIST_FLAG":"' + CASE WHEN F.outcome='Further strategy meeting' THEN 'Y' ELSE 'N' END + '",'
    + '"TOTAL_NO_OF_OUTCOMES":" ",'
    + '"OUTCOME_COMMENTS":"' + ISNULL(F.summary_outcome,'') + '"'
    + '}',

    T.allocated_team,
    W.allocated_worker

FROM FAPV F

LEFT JOIN WORKER W
    ON W.PERSONID = F.ANSWERFORSUBJECTID
   AND F.startdate >= W.worker_start_date
   AND F.startdate < ISNULL(W.worker_end_date, GETDATE())

LEFT JOIN TEAM T
    ON T.PERSONID = F.ANSWERFORSUBJECTID
   AND F.startdate >= T.team_start_date
   AND F.startdate < ISNULL(T.team_end_date, GETDATE())

LEFT JOIN CIN_EPISODE C
    ON F.ANSWERFORSUBJECTID = C.cine_person_id
   AND F.startdate >= C.cine_referral_date
   AND F.startdate < ISNULL(C.cine_close_date, GETDATE());