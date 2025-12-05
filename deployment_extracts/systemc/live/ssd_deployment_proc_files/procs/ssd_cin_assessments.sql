IF OBJECT_ID(N'proc_ssd_cin_assessments', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cin_assessments AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cin_assessments
    @src_db sysname = NULL,
    @src_schema sysname = NULL,
    @ssd_timeframe_years int = NULL,
    @ssd_sub1_range_years int = NULL,
    @today_date date = NULL,
    @today_dt datetime = NULL,
    @ssd_window_start date = NULL,
    @ssd_window_end date = NULL,
    @CaseloadLastSept30th date = NULL,
    @CaseloadTimeframeStartDate date = NULL

AS
BEGIN
    SET NOCOUNT ON;
    -- normalise defaults if not provided
    IF @src_db IS NULL SET @src_db = DB_NAME();
    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();
    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;
    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;
    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());
    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);
    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;
    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);
    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE
        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;
    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--          Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cin_assessments', 'U') IS NOT NULL DROP TABLE #ssd_cin_assessments;

IF OBJECT_ID('ssd_cin_assessments','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_assessments)
        TRUNCATE TABLE ssd_cin_assessments;
END

ELSE
BEGIN
    CREATE TABLE ssd_cin_assessments
    (
        cina_assessment_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINA001A"}
        cina_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
        cina_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
        cina_assessment_start_date      DATETIME,                   -- metadata={"item_ref":"CINA003A"}
        cina_assessment_child_seen      NCHAR(1),                   -- metadata={"item_ref":"CINA004A"}
        cina_assessment_auth_date       DATETIME,                   -- metadata={"item_ref":"CINA005A"}             
        cina_assessment_outcome_json    NVARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
        cina_assessment_outcome_nfa     NCHAR(1),                   -- metadata={"item_ref":"CINA009A"}
        cina_assessment_team            NVARCHAR(48),               -- metadata={"item_ref":"CINA007A"}
        cina_assessment_worker_id       NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
    );
END


-- CTE for the EXISTS
;WITH RelevantPersons AS (
    SELECT p.pers_person_id
    FROM ssd_person p
),
 
-- CTE for the JOIN
FormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER,
        ffa.DIM_ASSESSMENT_TEMPLATE_QUESTION_ID_DESC
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE ffa.ANSWER_NO IN ('seenYN', 'FormEndDate')
),
 
-- CTE for aggregating form answers
AggregatedFormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'seenYN' THEN ffa.ANSWER ELSE NULL END, ''))                                       AS seenYN, -- [REVIEW] 310524 RH
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'FormEndDate' THEN TRY_CAST(ffa.ANSWER AS DATETIME) ELSE NULL END, '1900-01-01'))  AS AssessmentAuthorisedDate -- [REVIEW] 310524 RH
    FROM FormAnswers ffa
    GROUP BY ffa.FACT_FORM_ID
) 

INSERT INTO ssd_cin_assessments
(
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

-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fa.FACT_SINGLE_ASSESSMENT_ID,
    fa.DIM_PERSON_ID,
    fa.FACT_REFERRAL_ID,
    fa.START_DTTM,
    CASE
        WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
        WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
        ELSE NULL
    END AS seenYN,
    afa.AssessmentAuthorisedDate,
    (
        -- Manual JSON-like concatenation for cina_assessment_outcome_json
        '{' +
        '"NFA_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NFA_S47_END_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_NFA_S47_END_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"STRATEGY_DISCUSSION_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CLA_REQUEST_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_CLA_REQUEST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PRIVATE_FOSTERING_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"LEGAL_ACTION_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_LEGAL_ACTION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SERVICES_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SB_CARE_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PROV_OF_SB_CARE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"SPECIALIST_ASSESSMENT_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"REFERRAL_TO_OTHER_AGENCY_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_ACTIONS_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_OTHER_ACTIONS_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(fa.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"TOTAL_NO_OF_OUTCOMES": ' + ISNULL(TRY_CAST(fa.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(3)), 'null') + ', ' +
        '"COMMENTS": "' + ISNULL(TRY_CAST(fa.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
        '}'
    ) AS cina_assessment_outcome_json,
    fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
    NULLIF(fa.COMPLETED_BY_DEPT_ID, -1)                         AS cina_assessment_team,             -- replace -1 values with NULL _team_id
    NULLIF(fa.COMPLETED_BY_USER_ID, -1)                         AS cina_assessment_worker_id         -- replace -1 values with NULL for _worker_id
 
FROM
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
 
LEFT JOIN
    -- access pre-processed data in CTE
    AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
 
WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excludes draft and cancelled assessments
 
AND 
    (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR afa.AssessmentAuthorisedDate IS NULL)

AND EXISTS (
    -- access pre-processed data in CTE
    SELECT 1
    FROM RelevantPersons p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID -- #DtoI-1799
);


-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
-- SELECT
--     fa.FACT_SINGLE_ASSESSMENT_ID,
--     fa.DIM_PERSON_ID,
--     fa.FACT_REFERRAL_ID,
--     fa.START_DTTM,
--     CASE
--         WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
--         WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
--         ELSE NULL
--     END AS seenYN,
--     afa.AssessmentAuthorisedDate,
--     (
--         SELECT
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             ISNULL(fa.OUTCOME_NFA_FLAG, '')                     AS NFA_FLAG,
--             ISNULL(fa.OUTCOME_NFA_S47_END_FLAG, '')             AS NFA_S47_END_FLAG,
--             ISNULL(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '')     AS STRATEGY_DISCUSSION_FLAG,
--             ISNULL(fa.OUTCOME_CLA_REQUEST_FLAG, '')             AS CLA_REQUEST_FLAG,
--             ISNULL(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')       AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fa.OUTCOME_LEGAL_ACTION_FLAG, '')            AS LEGAL_ACTION_FLAG,
--             ISNULL(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')        AS PROV_OF_SERVICES_FLAG,
--             ISNULL(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')         AS PROV_OF_SB_CARE_FLAG,
--             ISNULL(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '')   AS SPECIALIST_ASSESSMENT_FLAG,
--             ISNULL(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS REFERRAL_TO_OTHER_AGENCY_FLAG,
--             ISNULL(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')           AS OTHER_ACTIONS_FLAG,
--             ISNULL(fa.OTHER_OUTCOMES_EXIST_FLAG, '')            AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(fa.TOTAL_NO_OF_OUTCOMES, '')                 AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(fa.OUTCOME_COMMENTS, '')                     AS COMMENTS -- dictates a larger _json size
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         ) AS cina_assessment_outcome_json,
--     fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
--     NULLIF(fa.COMPLETED_BY_DEPT_ID, -1)                         AS cina_assessment_team,             -- replace -1 values with NULL _team_id
--     NULLIF(fa.COMPLETED_BY_USER_ID, -1)                         AS cina_assessment_worker_id         -- replace -1 values with NULL for _worker_id
 
-- FROM
--     HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
 
-- LEFT JOIN
--     -- access pre-processed data in CTE
--     AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
 
-- WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excludes draft and cancelled assessments
 
-- AND 
--     (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR afa.AssessmentAuthorisedDate IS NULL)

-- AND EXISTS (
--     -- access pre-processed data in CTE
--     SELECT 1
--     FROM RelevantPersons p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID -- #DtoI-1799
-- );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
-- FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_assessments_person_id     ON ssd_cin_assessments(cina_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_assessment_start_date    ON ssd_cin_assessments(cina_assessment_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_assessment_auth_date     ON ssd_cin_assessments(cina_assessment_auth_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_referral_id              ON ssd_cin_assessments(cina_referral_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
