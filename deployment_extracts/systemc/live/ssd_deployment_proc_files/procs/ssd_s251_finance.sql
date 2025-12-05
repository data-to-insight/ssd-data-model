IF OBJECT_ID(N'proc_ssd_s251_finance', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_s251_finance AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_s251_finance
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
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

IF OBJECT_ID('ssd_s251_finance','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_s251_finance)
        TRUNCATE TABLE ssd_s251_finance;
END

ELSE
BEGIN
    CREATE TABLE ssd_s251_finance (
        s251_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S251001A"}
        s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
        s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
        s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
        s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
        s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
    );
END

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_s251_finance (
--     -- row id ommitted as ID generated (s251_table_id,)
--     s251_cla_placement_id,
--     s251_placeholder_1,
--     s251_placeholder_2,
--     s251_placeholder_3,
--     s251_placeholder_4
-- )
-- VALUES
--     ('SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH');


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_ssd_s251_to_cla_placement 
-- FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_s251_cla_placement_id ON ssd_s251_finance(s251_cla_placement_id);

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
