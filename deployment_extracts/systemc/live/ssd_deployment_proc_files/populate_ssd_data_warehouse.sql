-- Master deploy runner for SSD table procs
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- shared vars, passed to every proc
DECLARE @src_db     sysname = N'HDM';
DECLARE @src_schema sysname = N'';    -- empty uses caller default schema

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
DECLARE @CaseloadTimeframeStartDate date = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @schema_name sysname = NULLIF(@src_schema, N'');
    DECLARE @proc nvarchar(512);

    -- proc_ssd_person
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_person_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_person_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_person';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_person';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cohort
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cohort_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cohort_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cohort';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cohort';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_family
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_family_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_family_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_family';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_family';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_address
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_address_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_address_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_address';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_address';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_disability
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_disability_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_disability_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_disability';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_disability';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_immigration_status
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_immigration_status_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_immigration_status_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_immigration_status';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_immigration_status';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cin_episodes
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cin_episodes_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_episodes_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cin_episodes';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_episodes';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_mother
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_mother_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_mother_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_mother';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_mother';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_legal_status
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_legal_status_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_legal_status_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_legal_status';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_legal_status';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_contacts
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_contacts_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_contacts_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_contacts';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_contacts';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_early_help_episodes
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_early_help_episodes_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_early_help_episodes_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_early_help_episodes';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_early_help_episodes';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cin_assessments
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cin_assessments_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_assessments_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cin_assessments';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_assessments';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_assessment_factors
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_assessment_factors_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_assessment_factors_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_assessment_factors';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_assessment_factors';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cin_plans
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cin_plans_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_plans_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cin_plans';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_plans';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cin_visits
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cin_visits_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_visits_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cin_visits';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cin_visits';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_s47_enquiry
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_s47_enquiry_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_s47_enquiry_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_s47_enquiry';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_s47_enquiry';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_initial_cp_conference
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_initial_cp_conference_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_initial_cp_conference_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_initial_cp_conference';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_initial_cp_conference';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cp_plans
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cp_plans_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_plans_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cp_plans';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_plans';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cp_visits
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cp_visits_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_visits_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cp_visits';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_visits';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cp_reviews
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cp_reviews_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_reviews_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cp_reviews';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cp_reviews';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_episodes
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_episodes_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_episodes_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_episodes';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_episodes';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_convictions
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_convictions_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_convictions_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_convictions';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_convictions';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_health
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_health_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_health_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_health';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_health';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_immunisations
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_immunisations_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_immunisations_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_immunisations';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_immunisations';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_substance_misuse
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_substance_misuse_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_substance_misuse_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_substance_misuse';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_substance_misuse';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_placement
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_placement_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_placement_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_placement';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_placement';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_reviews
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_reviews_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_reviews_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_reviews';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_reviews';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_previous_permanence
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_previous_permanence_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_previous_permanence_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_previous_permanence';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_previous_permanence';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_pre_cla_care_plan
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_pre_cla_care_plan_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_pre_cla_care_plan_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_pre_cla_care_plan';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_pre_cla_care_plan';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_cla_visits
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_cla_visits_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_visits_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_cla_visits';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_cla_visits';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_sdq_scores
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_sdq_scores_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_sdq_scores_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_sdq_scores';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_sdq_scores';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_missing
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_missing_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_missing_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_missing';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_missing';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_care_leavers
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_care_leavers_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_care_leavers_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_care_leavers';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_care_leavers';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_permanence
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_permanence_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_permanence_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_permanence';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_permanence';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_professionals
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_professionals_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_professionals_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_professionals';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_professionals';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_department
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_department_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_department_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_department';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_department';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_involvements
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_involvements_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_involvements_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_involvements';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_involvements';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_linked_identifiers
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_linked_identifiers_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_linked_identifiers_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_linked_identifiers';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_linked_identifiers';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_s251_finance
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_s251_finance_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_s251_finance_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_s251_finance';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_s251_finance';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_voice_of_child
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_voice_of_child_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_voice_of_child_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_voice_of_child';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_voice_of_child';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_pre_proceedings
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_pre_proceedings_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_pre_proceedings_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_pre_proceedings';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_pre_proceedings';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_send
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_send_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_send_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_send';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_send';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_sen_need
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_sen_need_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_sen_need_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_sen_need';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_sen_need';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_ehcp_requests
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_ehcp_requests_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_requests_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_ehcp_requests';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_requests';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_ehcp_assessment
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_ehcp_assessment_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_assessment_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_ehcp_assessment';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_assessment';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_ehcp_named_plan
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_ehcp_named_plan_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_named_plan_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_ehcp_named_plan';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_named_plan';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    -- proc_ssd_ehcp_active_plans
    IF @schema_name IS NULL
        SET @proc = N'proc_ssd_ehcp_active_plans_custom';
    ELSE
        SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_active_plans_custom';

    IF OBJECT_ID(@proc, N'P') IS NOT NULL
    BEGIN
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END
    ELSE
    BEGIN
        IF @schema_name IS NULL SET @proc = N'proc_ssd_ehcp_active_plans';
        ELSE              SET @proc = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_active_plans';
        EXEC @proc
             @src_db=@src_db, @src_schema=@src_schema,
             @ssd_timeframe_years=@ssd_timeframe_years, @ssd_sub1_range_years=@ssd_sub1_range_years,
             @today_date=@today_date, @today_dt=@today_dt,
             @ssd_window_start=@ssd_window_start, @ssd_window_end=@ssd_window_end,
             @CaseloadLastSept30th=@CaseloadLastSept30th,
             @CaseloadTimeframeStartDate=@CaseloadTimeframeStartDate;
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
