IF OBJECT_ID(N'proc_ssd_cp_reviews', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cp_reviews AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cp_reviews
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
-- Remarks:    cppr_cp_review_participation - ON HOLD/Not included in SSD Ver/Iteration 1
--             Resolved issue with linking to Quoracy information. Added fm.FACT_MEETING_ID
--             so users can identify conferences including multiple children. Reviews held
--             pre-LCS implementation don't have a CP_PLAN_ID recorded so have added
--             cpr.DIM_PERSON_ID for linking reviews to the ssd_cp_plans object.
--             Re-named cppr_cp_review_outcome_continue_cp for clarity.
-- Dependencies:
-- - ssd_person
-- - ssd_cp_plans
-- - HDM.Child_Social.FACT_CP_REVIEW
-- - HDM.Child_Social.FACT_MEETINGS
-- - HDM.Child_Social.FACT_MEETING_SUBJECTS
-- - HDM.Child_Social.FACT_FORM_ANSWERS [Participation info - ON HOLD/Not included in SSD Ver/Iteration 1]
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cp_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
IF OBJECT_ID('ssd_cp_reviews','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cp_reviews)
        TRUNCATE TABLE ssd_cp_reviews;
END

ELSE
BEGIN
    CREATE TABLE ssd_cp_reviews
    (
        cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPR001A"}
        cppr_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CPPR008A"}
        cppr_cp_plan_id                     NVARCHAR(48),               -- metadata={"item_ref":"CPPR002A"}  
        cppr_cp_review_due                  DATETIME NULL,              -- metadata={"item_ref":"CPPR003A"}
        cppr_cp_review_date                 DATETIME NULL,              -- metadata={"item_ref":"CPPR004A"}
        cppr_cp_review_meeting_id           NVARCHAR(48),               -- metadata={"item_ref":"CPPR009A"}      
        cppr_cp_review_outcome_continue_cp  NCHAR(1),                   -- metadata={"item_ref":"CPPR005A"}
        cppr_cp_review_quorate              NVARCHAR(100),              -- metadata={"item_ref":"CPPR006A"}      
        cppr_cp_review_participation        NVARCHAR(100)               -- metadata={"item_ref":"CPPR007A"}
    );
END

INSERT INTO ssd_cp_reviews
(
    cppr_cp_review_id,
    cppr_cp_plan_id,
    cppr_person_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_meeting_id,
    cppr_cp_review_outcome_continue_cp,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
)
SELECT
    cpr.FACT_CP_REVIEW_ID                       AS cppr_cp_review_id ,
    cpr.FACT_CP_PLAN_ID                         AS cppr_cp_plan_id,
    cpr.DIM_PERSON_ID                           AS cppr_person_id,
    cpr.DUE_DTTM                                AS cppr_cp_review_due,
    cpr.MEETING_DTTM                            AS cppr_cp_review_date,
    fm.FACT_MEETING_ID                          AS cppr_cp_review_meeting_id,
    cpr.OUTCOME_CONTINUE_CP_FLAG                AS cppr_cp_review_outcome_continue_cp,
    (CASE WHEN ffa.ANSWER_NO = 'WasConf'
        AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
        THEN ffa.ANSWER END)                    AS cppr_cp_review_quorate,    
    'SSD_PH'                                    AS cppr_cp_review_participation
 
FROM
    HDM.Child_Social.FACT_CP_REVIEW as cpr
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm               ON cpr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms      ON cpr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND cpr.DIM_PERSON_ID = fms.DIM_PERSON_ID
 
LEFT JOIN    
    HDM.Child_Social.FACT_FORM_ANSWERS ffa          ON fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.ANSWER_NO = 'WasConf'
    AND fms.FACT_OUTCM_FORM_ID IS NOT NULL
    AND fms.FACT_OUTCM_FORM_ID <> '-1'
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON cpr.DIM_PERSON_ID = p.DIM_PERSON_ID

WHERE
    (cpr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cpr.MEETING_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cpr.DIM_PERSON_ID -- #DtoI-1799
)
GROUP BY cpr.FACT_CP_REVIEW_ID,
    cpr.FACT_CP_PLAN_ID,
    cpr.DIM_PERSON_ID,
    cpr.DUE_DTTM,
    cpr.MEETING_DTTM,
    fm.FACT_MEETING_ID,
    cpr.OUTCOME_CONTINUE_CP_FLAG,
    fms.FACT_OUTCM_FORM_ID,
    ffa.ANSWER_NO,
    ffa.FACT_FORM_ID,
    ffa.ANSWER;

-- ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
-- FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_person_id ON ssd_cp_reviews(cppr_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_plan_id ON ssd_cp_reviews(cppr_cp_plan_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_due ON ssd_cp_reviews(cppr_cp_review_due);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_date ON ssd_cp_reviews(cppr_cp_review_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_meeting_id ON ssd_cp_reviews(cppr_cp_review_meeting_id);

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
