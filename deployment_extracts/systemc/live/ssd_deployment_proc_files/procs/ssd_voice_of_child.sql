IF OBJECT_ID(N'proc_ssd_voice_of_child', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_voice_of_child AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_voice_of_child
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
-- Object Name: ssd_voice_of_child
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

IF OBJECT_ID('ssd_voice_of_child','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_voice_of_child)
        TRUNCATE TABLE ssd_voice_of_child;
END

ELSE
BEGIN
    CREATE TABLE ssd_voice_of_child (
        voch_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"VOCH007A"}
        voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
        voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
        voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
        voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
        voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
        voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
    );
END

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_voice_of_child (
--     -- row id ommitted as ID generated (voch_table_id,)
--     voch_person_id,
--     voch_explained_worries,
--     voch_story_help_understand,
--     voch_agree_worker,
--     voch_plan_safe,
--     voch_tablet_help_explain
-- )
-- VALUES
--     ('10001', 'Y', 'Y', 'Y', 'Y', 'Y'),
--     ('10002', 'Y', 'Y', 'Y', 'Y', 'Y');


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = source_table.DIM_PERSON_ID
--     );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_ssd_voch_to_person 
-- FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_voice_of_child_voch_person_id ON ssd_voice_of_child(voch_person_id);

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
