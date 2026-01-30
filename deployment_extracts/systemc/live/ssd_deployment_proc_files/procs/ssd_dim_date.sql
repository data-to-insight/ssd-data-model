IF OBJECT_ID(N'proc_ssd_dim_date', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_dim_date AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_dim_date
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
-- Description: Centralised time-frame references for SSD and upstream reporting|tools
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--          This is an in DEvelopment inclusion for the SSD and as such is being phased in. 
--          Added here for both visibility and LA feedback, but not yet fully integrated. 
--          The table set to replace declarations within: META-ELEMENT: {"type": "ssd_timeframe"}
-- Dependencies:
-- 
-- =============================================================================


IF OBJECT_ID('ssd_dim_date', 'U') IS NOT NULL
    DROP TABLE ssd_dim_date;

CREATE TABLE ssd_dim_date
(
    date_key                   int         NOT NULL,  -- yyyymmdd
    full_date                  date        NOT NULL,  -- upstream JSON processing use ISO 8601, DfE/Ofted style dd/mm/yyyy

    calendar_year              int         NOT NULL,
    calendar_quarter           tinyint     NOT NULL,
    month_number               tinyint     NOT NULL,
    day_of_month               tinyint     NOT NULL,

    iso_year                  int         NOT NULL,  -- ISO-8601 week-based year
    iso_week                  tinyint     NOT NULL,  -- ISO week number (1-53)

    day_of_week_monday1        tinyint     NOT NULL,  -- Monday=1..Sunday=7, consistent across DATEFIRST settings
    is_weekend                 bit         NOT NULL,

    month_start_date           date        NOT NULL,
    month_end_date             date        NOT NULL,
    quarter_start_date         date        NOT NULL,
    quarter_end_date           date        NOT NULL,
    year_start_date            date        NOT NULL,
    year_end_date              date        NOT NULL,

    fiscal_year_start_year     int         NOT NULL,  -- eg 2025 for FY 2025/26
    fiscal_year_label          varchar(7)  NOT NULL,  -- eg '2025/26'
    fiscal_year_start_date     date        NOT NULL,  -- 1 April
    fiscal_year_end_date       date        NOT NULL,  -- 31 March

    fiscal_quarter             tinyint     NOT NULL,  -- Q1=Apr-Jun
    fiscal_quarter_start_date  date        NOT NULL,
    fiscal_quarter_end_date    date        NOT NULL,

    CONSTRAINT PK_ssd_dim_date PRIMARY KEY CLUSTERED (date_key),
    CONSTRAINT UQ_ssd_dim_date_full_date UNIQUE (full_date)
);


DECLARE @StartDate date = '2015-01-01';
DECLARE @EndDate   date = CONVERT(date, GETDATE());  -- end at today

;WITH N AS
(
    SELECT TOP (DATEDIFF(day, @StartDate, @EndDate) + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
D AS
(
    SELECT DATEADD(day, n, @StartDate) AS d
    FROM N
),
Base AS
(
    SELECT
        d.d AS full_date,
        CONVERT(int, CONVERT(char(8), d.d, 112)) AS date_key,

        YEAR(d.d) AS calendar_year,
        DATEPART(quarter, d.d) AS calendar_quarter,
        MONTH(d.d) AS month_number,
        DAY(d.d) AS day_of_month,

        DATEPART(ISO_WEEK, d.d) AS iso_week,
        /* ISO year = year of Thursday in the ISO week, weekday use Monday=1..Sunday=7 */
        YEAR(DATEADD(day, 4 - ((DATEDIFF(day, '19000101', d.d) % 7) + 1), d.d)) AS iso_year,


        /* Monday=1..Sunday=7, independent of server DATEFIRST */
        ((DATEDIFF(day, '19000101', d.d) % 7) + 1) AS day_of_week_monday1,

        DATEFROMPARTS(YEAR(d.d), MONTH(d.d), 1) AS month_start_date,
        DATEADD(day, -1, DATEADD(month, 1, DATEFROMPARTS(YEAR(d.d), MONTH(d.d), 1))) AS month_end_date,

        DATEFROMPARTS(YEAR(d.d), ((DATEPART(quarter, d.d) - 1) * 3) + 1, 1) AS quarter_start_date,
        DATEADD(day, -1, DATEADD(month, 3, DATEFROMPARTS(YEAR(d.d), ((DATEPART(quarter, d.d) - 1) * 3) + 1, 1))) AS quarter_end_date,

        DATEFROMPARTS(YEAR(d.d), 1, 1) AS year_start_date,
        DATEFROMPARTS(YEAR(d.d), 12, 31) AS year_end_date,

        /* UK FY starts 1 April */
        CASE WHEN MONTH(d.d) >= 4 THEN YEAR(d.d) ELSE YEAR(d.d) - 1 END AS fiscal_year_start_year
    FROM D d
)
INSERT ssd_dim_date
(
    date_key,
    full_date,

    calendar_year,
    calendar_quarter,
    month_number,
    day_of_month,

    iso_year,
    iso_week,

    day_of_week_monday1,
    is_weekend,

    month_start_date,
    month_end_date,
    quarter_start_date,
    quarter_end_date,
    year_start_date,
    year_end_date,

    fiscal_year_start_year,
    fiscal_year_label,
    fiscal_year_start_date,
    fiscal_year_end_date,

    fiscal_quarter,
    fiscal_quarter_start_date,
    fiscal_quarter_end_date
)
SELECT
    b.date_key,
    b.full_date,

    b.calendar_year,
    b.calendar_quarter,
    b.month_number,
    b.day_of_month,

    b.iso_year,
    b.iso_week,

    b.day_of_week_monday1,
    CASE WHEN b.day_of_week_monday1 IN (6, 7) THEN 1 ELSE 0 END AS is_weekend,

    b.month_start_date,
    b.month_end_date,
    b.quarter_start_date,
    b.quarter_end_date,
    b.year_start_date,
    b.year_end_date,

    b.fiscal_year_start_year,

    CONCAT(
        b.fiscal_year_start_year,
        '/',
        RIGHT(CONVERT(varchar(4), b.fiscal_year_start_year + 1), 2)
    ) AS fiscal_year_label,

    DATEFROMPARTS(b.fiscal_year_start_year, 4, 1) AS fiscal_year_start_date,
    DATEADD(day, -1, DATEFROMPARTS(b.fiscal_year_start_year + 1, 4, 1)) AS fiscal_year_end_date,

    CASE
        WHEN b.month_number BETWEEN 4 AND 6  THEN 1
        WHEN b.month_number BETWEEN 7 AND 9  THEN 2
        WHEN b.month_number BETWEEN 10 AND 12 THEN 3
        ELSE 4
    END AS fiscal_quarter,

    CASE
        WHEN b.month_number BETWEEN 4 AND 6  THEN DATEFROMPARTS(b.fiscal_year_start_year, 4, 1)
        WHEN b.month_number BETWEEN 7 AND 9  THEN DATEFROMPARTS(b.fiscal_year_start_year, 7, 1)
        WHEN b.month_number BETWEEN 10 AND 12 THEN DATEFROMPARTS(b.fiscal_year_start_year, 10, 1)
        ELSE DATEFROMPARTS(b.fiscal_year_start_year + 1, 1, 1)
    END AS fiscal_quarter_start_date,

    DATEADD(day, -1, DATEADD(month, 3,
        CASE
            WHEN b.month_number BETWEEN 4 AND 6  THEN DATEFROMPARTS(b.fiscal_year_start_year, 4, 1)
            WHEN b.month_number BETWEEN 7 AND 9  THEN DATEFROMPARTS(b.fiscal_year_start_year, 7, 1)
            WHEN b.month_number BETWEEN 10 AND 12 THEN DATEFROMPARTS(b.fiscal_year_start_year, 10, 1)
            ELSE DATEFROMPARTS(b.fiscal_year_start_year + 1, 1, 1)
        END
    )) AS fiscal_quarter_end_date
FROM Base b;

-- -- Suggested indexes as required
-- CREATE INDEX IX_ssd_dim_date_full_date
-- ON ssd_dim_date (full_date)
-- INCLUDE (date_key, fiscal_year_start_date, fiscal_year_end_date, fiscal_quarter, fiscal_quarter_start_date, fiscal_quarter_end_date);

-- CREATE INDEX IX_ssd_dim_date_fyq
-- ON ssd_dim_date (fiscal_year_start_year, fiscal_quarter)
-- INCLUDE (full_date, fiscal_quarter_start_date, fiscal_quarter_end_date);

-- CREATE INDEX IX_ssd_dim_date_fy
-- ON ssd_dim_date (fiscal_year_start_year)
-- INCLUDE (full_date, fiscal_year_start_date, fiscal_year_end_date);

-- CREATE INDEX IX_ssd_dim_date_iso_year_week
-- ON ssd_dim_date (iso_year, iso_week)
-- INCLUDE (full_date, date_key);

-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--          This is an in Development inclusion for the SSD and as such is being phased in. 
--          Added here for both visibility and LA feedback, but not yet fully integrated.
--          VIEW currently commented as use of GO mid-single-script resets var declarations, 
--          and VIEW definitions required to be first running object. *LA's can run seperately as needed* 
--          The table set to replace declarations within: META-ELEMENT: {"type": "ssd_timeframe"}
-- Dependencies:
-- 
-- =============================================================================

-- CREATE OR ALTER VIEW ssd_vw_current_time_windows
-- AS
-- WITH x AS
-- (
--     SELECT CONVERT(date, GETDATE()) AS run_date
-- ),
-- p AS
-- (
--     /* Centralised params */
--     SELECT
--         CAST(24 AS int) AS ea_months_back,          -- Early Adopters
--         CAST(6  AS int) AS ssd_timeframe_years      -- SSD main
-- )
-- SELECT
--     x.run_date AS ssd_run_date,

--     /* SSD main timeframe (start and end exclusive) */
--     DATEADD(year, -p.ssd_timeframe_years, x.run_date) AS ssd_window_start,
--     DATEADD(day, 1, x.run_date) AS ssd_window_end,

--     /* EA window (24 months back, then FY start for that anchor date) */
--     p.ea_months_back AS ea_months_back,
--     DATEADD(month, -p.ea_months_back, x.run_date) AS ea_anchor_date,
--     ea.fiscal_year_start_date AS ea_window_start,
--     DATEADD(day, 1, x.run_date) AS ea_window_end,

--     /* Caseload anchor (last Sept 30 on or before run_date) */
--     p.ssd_timeframe_years AS ssd_timeframe_years,
--     caseload.last_sept30 AS sw_caseload_anchor,
--     DATEADD(year, -p.ssd_timeframe_years, caseload.last_sept30) AS sw_caseload_window_start
-- FROM x
-- CROSS JOIN p
-- JOIN ssd_dim_date ea
--   ON ea.full_date = DATEADD(month, -p.ea_months_back, x.run_date)
-- CROSS APPLY
-- (
--     SELECT MAX(d.full_date) AS last_sept30
--     FROM ssd_dim_date d
--     WHERE d.month_number = 9
--       AND d.day_of_month = 30
--       AND d.full_date <= x.run_date
-- ) caseload;


-- select * from ssd_vw_current_time_windows;

-- -- META-END

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
