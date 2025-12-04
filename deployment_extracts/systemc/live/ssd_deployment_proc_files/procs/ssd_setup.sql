IF OBJECT_ID(N'ssd_setup', N'P') IS NULL
    EXEC('CREATE PROCEDURE ssd_setup AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE ssd_setup
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..##ssd_runtime_settings') IS NOT NULL DROP TABLE ##ssd_runtime_settings;

    DECLARE @src_db     sysname = N'HDM';
    DECLARE @src_schema sysname = N'';  -- empty string means use caller default schema

    DECLARE @ssd_timeframe_years INT = 6;
    DECLARE @ssd_sub1_range_years INT = 1;

    DECLARE @today_date  date     = CONVERT(date, GETDATE());
    DECLARE @today_dt    datetime = CONVERT(datetime, @today_date);

    DECLARE @ssd_window_end   date = @today_date;
    DECLARE @ssd_window_start date = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);

    DECLARE @CaseloadLastSept30th date =
        CASE WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30)
             THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
             ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;

    DECLARE @CaseloadTimeframeStartDate date =
        DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

    CREATE TABLE ##ssd_runtime_settings(
        src_db sysname,
        src_schema sysname,
        ssd_timeframe_years int,
        ssd_sub1_range_years int,
        today_date date,
        today_dt datetime,
        ssd_window_start date,
        ssd_window_end date,
        CaseloadLastSept30th date,
        CaseloadTimeframeStartDate date
    );

    INSERT INTO ##ssd_runtime_settings
    VALUES(@src_db, @src_schema, @ssd_timeframe_years, @ssd_sub1_range_years,
           @today_date, @today_dt, @ssd_window_start, @ssd_window_end,
           @CaseloadLastSept30th, @CaseloadTimeframeStartDate);
END
GO
