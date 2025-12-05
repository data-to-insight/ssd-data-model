IF OBJECT_ID(N'proc_ssd_pre_proceedings', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_pre_proceedings AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_pre_proceedings
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
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

IF OBJECT_ID('ssd_pre_proceedings','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_pre_proceedings)
        TRUNCATE TABLE ssd_pre_proceedings;
END

ELSE
BEGIN
    CREATE TABLE ssd_pre_proceedings (
        prep_table_id                           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PREP024A"}
        prep_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"PREP001A"}
        prep_plo_family_id                      NVARCHAR(48),               -- metadata={"item_ref":"PREP002A"}
        prep_pre_pro_decision_date              DATETIME,                   -- metadata={"item_ref":"PREP003A"}
        prep_initial_pre_pro_meeting_date       DATETIME,                   -- metadata={"item_ref":"PREP004A"}
        prep_pre_pro_outcome                    NVARCHAR(100),              -- metadata={"item_ref":"PREP005A"}
        prep_agree_stepdown_issue_date          DATETIME,                   -- metadata={"item_ref":"PREP006A"}
        prep_cp_plans_referral_period           INT,                        -- metadata={"item_ref":"PREP007A"}
        prep_legal_gateway_outcome              NVARCHAR(100),              -- metadata={"item_ref":"PREP008A"}
        prep_prev_pre_proc_child                INT,                        -- metadata={"item_ref":"PREP009A"}
        prep_prev_care_proc_child               INT,                        -- metadata={"item_ref":"PREP010A"}
        prep_pre_pro_letter_date                DATETIME,                   -- metadata={"item_ref":"PREP011A"}
        prep_care_pro_letter_date               DATETIME,                   -- metadata={"item_ref":"PREP012A"}
        prep_pre_pro_meetings_num               INT,                        -- metadata={"item_ref":"PREP013A"}
        prep_pre_pro_parents_legal_rep          NCHAR(1),                   -- metadata={"item_ref":"PREP014A"}
        prep_parents_legal_rep_point_of_issue   NCHAR(2),                   -- metadata={"item_ref":"PREP015A"}
        prep_court_reference                    NVARCHAR(48),               -- metadata={"item_ref":"PREP016A"}
        prep_care_proc_court_hearings           INT,                        -- metadata={"item_ref":"PREP017A"}
        prep_care_proc_short_notice             NCHAR(1),                   -- metadata={"item_ref":"PREP018A"}
        prep_proc_short_notice_reason           NVARCHAR(100),              -- metadata={"item_ref":"PREP019A"}
        prep_la_inital_plan_approved            NCHAR(1),                   -- metadata={"item_ref":"PREP020A"}
        prep_la_initial_care_plan               NVARCHAR(100),              -- metadata={"item_ref":"PREP021A"}
        prep_la_final_plan_approved             NCHAR(1),                   -- metadata={"item_ref":"PREP022A"}
        prep_la_final_care_plan                 NVARCHAR(100)               -- metadata={"item_ref":"PREP023A"}
    );
END

-- -- Insert placeholder data
-- INSERT INTO ssd_pre_proceedings (
--     -- row id ommitted as ID generated (prep_table_id,)
--     prep_person_id,
--     prep_plo_family_id,
--     prep_pre_pro_decision_date,
--     prep_initial_pre_pro_meeting_date,
--     prep_pre_pro_outcome,
--     prep_agree_stepdown_issue_date,
--     prep_cp_plans_referral_period,
--     prep_legal_gateway_outcome,
--     prep_prev_pre_proc_child,
--     prep_prev_care_proc_child,
--     prep_pre_pro_letter_date,
--     prep_care_pro_letter_date,
--     prep_pre_pro_meetings_num,
--     prep_pre_pro_parents_legal_rep,
--     prep_parents_legal_rep_point_of_issue,
--     prep_court_reference,
--     prep_care_proc_court_hearings,
--     prep_care_proc_short_notice,
--     prep_proc_short_notice_reason,
--     prep_la_inital_plan_approved,
--     prep_la_initial_care_plan,
--     prep_la_final_plan_approved,
--     prep_la_final_care_plan
-- )
-- VALUES
--     (
--     'SSD_PH', 'PLO_FAMILY1', '1900/01/01', '1900/01/01', 'Outcome1', 
--     '1900/01/01', 3, 'Approved', 2, 1, '1900/01/01', '1900/01/01', 2, 'Y', 
--     'NA', 'COURT_REF_1', 1, 'Y', 'Reason1', 'Y', 'Initial Plan 1', 'Y', 'Final Plan 1'
--     ),
--     (
--     'SSD_PH', 'PLO_FAMILY2', '1900/01/01', '1900/01/01', 'Outcome2',
--     '1900/01/01', 4, 'Denied', 1, 2, '1900/01/01', '1900/01/01', 3, 'Y',
--     'IS', 'COURT_REF_2', 2, 'Y', 'Reason2', 'Y', 'Initial Plan 2', 'Y', 'Final Plan 2'
--     );



-- To switch on once source data defined.
-- WHERE EXISTS 
-- ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = plo_source_data_table.DIM_PERSON_ID
--     );





-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_ssd_prep_to_person 
-- FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_person_id                ON ssd_pre_proceedings (prep_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_pre_pro_decision_date    ON ssd_pre_proceedings (prep_pre_pro_decision_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_legal_gateway_outcome    ON ssd_pre_proceedings (prep_legal_gateway_outcome);

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
