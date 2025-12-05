IF OBJECT_ID(N'proc_ssd_sdq_scores', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_sdq_scores AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_sdq_scores
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
--          ASSESSMENT_TEMPLATE_ID_CODEs ranges validated at 12/12/23
--         Removed csdq _form_ id as the form id is also being used as csdq_table_id
--         Added placeholder for csdq_sdq_reason
--         Removed PRIMARY KEY stipulation for csdq_table_id
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 
IF OBJECT_ID('ssd_sdq_scores','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_sdq_scores)
        TRUNCATE TABLE ssd_sdq_scores;
END

ELSE
BEGIN
    CREATE TABLE ssd_sdq_scores (
        csdq_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CSDQ001A"} --  PRIMARY KEY switched off for ESCC
        csdq_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CSDQ002A"}
        csdq_sdq_completed_date     DATETIME,                   -- metadata={"item_ref":"CSDQ003A"}
        csdq_sdq_score              INT,                        -- metadata={"item_ref":"CSDQ005A"}
        csdq_sdq_reason             NVARCHAR(100)               -- metadata={"item_ref":"CSDQ004A", "item_status":"P"}
    );
END

INSERT INTO ssd_sdq_scores (
    csdq_table_id, 
    csdq_person_id, 
    csdq_sdq_completed_date, 
    csdq_sdq_score, 
    csdq_sdq_reason
)
SELECT
    ff.FACT_FORM_ID                         AS csdq_table_id,
    ff.DIM_PERSON_ID                        AS csdq_person_id,

    -- SDQ Completed date
    -- Prefer FormEndDate, or fall back to SDQScore answer time
    COALESCE(fed.FormEndDttm, sdq.SdqDttm)  AS csdq_sdq_completed_date,

    -- Numeric SDQ score for form
    sdq.SdqScoreNumeric                     AS csdq_sdq_score,

    'SSD_PH'                                AS csdq_sdq_reason   -- placeholder / reason [REVIEW]
FROM HDM.Child_Social.FACT_FORMS ff

-- Pull SDQ score (1 per form)
OUTER APPLY (
    SELECT TOP 1
        CASE 
            WHEN ISNUMERIC(ffa.ANSWER) = 1 
                THEN TRY_CAST(ffa.ANSWER AS INT)
            ELSE NULL
        END                        AS SdqScoreNumeric,
        ffa.ANSWERED_DTTM          AS SdqDttm
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE ffa.FACT_FORM_ID = ff.FACT_FORM_ID
      AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
      AND ffa.ANSWER_NO = 'SDQScore'
      AND ffa.ANSWER IS NOT NULL
    ORDER BY ffa.ANSWERED_DTTM DESC   -- if multiple SDQScore answers exist on form, take latest
) sdq

-- FormEndDate for this form if exists
OUTER APPLY (
    SELECT TOP 1
        ffa2.ANSWERED_DTTM AS FormEndDttm
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa2
    WHERE ffa2.FACT_FORM_ID = ff.FACT_FORM_ID
      AND ffa2.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
      AND ffa2.ANSWER_NO = 'FormEndDate'
      AND ffa2.ANSWER IS NOT NULL
    ORDER BY ffa2.ANSWERED_DTTM DESC
) fed

-- Limit FACT_FORMS to related to SDQ template
WHERE EXISTS (
    SELECT 1
    FROM HDM.Child_Social.FACT_FORM_ANSWERS fchk
    WHERE fchk.FACT_FORM_ID = ff.FACT_FORM_ID
      AND fchk.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
)
-- only rows with data
AND sdq.SdqScoreNumeric IS NOT NULL
-- apply rolling timeframe based on completed date [align to TAG SSD ver]
AND COALESCE(fed.FormEndDttm, sdq.SdqDttm) >= @ssd_window_start
AND EXISTS (
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
);

-- remove exact dupl SDQ rows
-- keep distinct scores and dates per person and form
;WITH Dedup AS (
    SELECT
        csdq_table_id,
        csdq_person_id,
        csdq_sdq_completed_date,
        csdq_sdq_score,
        csdq_sdq_reason,
        ROW_NUMBER() OVER (
            PARTITION BY 
                csdq_table_id,
                csdq_person_id,
                csdq_sdq_completed_date,
                csdq_sdq_score,
                csdq_sdq_reason
            ORDER BY csdq_table_id
        ) AS rn
    FROM ssd_sdq_scores
)
DELETE s
FROM ssd_sdq_scores s
JOIN Dedup d
  ON s.csdq_table_id           = d.csdq_table_id
 AND s.csdq_person_id          = d.csdq_person_id
 AND s.csdq_sdq_completed_date = d.csdq_sdq_completed_date
 AND s.csdq_sdq_score          = d.csdq_sdq_score
 AND s.csdq_sdq_reason         = d.csdq_sdq_reason
WHERE d.rn > 1;



-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
-- FOREIGN KEY (csdq_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_csdq_person_id ON ssd_sdq_scores(csdq_person_id);

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
