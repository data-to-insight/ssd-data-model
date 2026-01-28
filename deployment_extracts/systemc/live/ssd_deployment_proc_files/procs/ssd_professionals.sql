IF OBJECT_ID(N'proc_ssd_professionals', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_professionals AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_professionals
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
-- Dependencies: 
-- - @CaseloadLastSept30th
-- - @CaseloadTimeframeStartDate
-- - @ssd_timeframe_years
-- - HDM.Child_Social.DIM_WORKER
-- - HDM.Child_Social.FACT_REFERRALS
-- - ssd_cin_episodes (if counting caseloads within SSD timeframe)
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;

IF OBJECT_ID('ssd_professionals','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_professionals)
        TRUNCATE TABLE ssd_professionals;
END

ELSE
BEGIN
    CREATE TABLE ssd_professionals (
        prof_professional_id                NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PROF001A"}
        prof_staff_id                       NVARCHAR(48),               -- metadata={"item_ref":"PROF010A"}
        prof_professional_name              NVARCHAR(300),              -- metadata={"item_ref":"PROF013A"}
        prof_social_worker_registration_no  NVARCHAR(48),               -- metadata={"item_ref":"PROF002A"}
        prof_agency_worker_flag             NCHAR(1),                   -- metadata={"item_ref":"PROF014A", "item_status": "P", "info":"Not available in SSD V1"}
        prof_professional_job_title         NVARCHAR(500),              -- metadata={"item_ref":"PROF007A"}
        prof_professional_caseload          INT,                        -- metadata={"item_ref":"PROF008A", "item_status": "T"}             
        prof_professional_department        NVARCHAR(100),              -- metadata={"item_ref":"PROF012A"}
        prof_full_time_equivalency          FLOAT                       -- metadata={"item_ref":"PROF011A"}
    );
END

INSERT INTO ssd_professionals (
    prof_professional_id, 
    prof_staff_id, 
    prof_professional_name,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)


SELECT 
    dw.DIM_WORKER_ID                        AS prof_professional_id,                -- system based ID for workers
    LTRIM(RTRIM(dw.STAFF_ID))               AS prof_staff_id,                       -- Note that this is trimmed for non-printing chars
    CONCAT(dw.FORENAME, ' ', dw.SURNAME)    AS prof_professional_name,              -- used also as Allocated Worker|Assigned Worker
    dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,  -- Not tied to WORKER_ID, this is the social work reg number IF entered
    NULL                                    AS prof_agency_worker_flag,             -- Not available in SSD Ver/Iteration 1 [REVIEW] [PLACEHOLDER_DATA]
    dw.JOB_TITLE                            AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)                 AS prof_professional_caseload,          -- 0 when no open cases on given date.
    dw.DEPARTMENT_NAME                      AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY                AS prof_full_time_equivalency

FROM 
    HDM.Child_Social.DIM_WORKER AS dw

LEFT JOIN (
    SELECT 
        -- Calculate CASELOAD 
        -- [REVIEW][TESTING] count within restricted ssd timeframe only
        DIM_WORKER_ID,
        COUNT(*) AS OpenCases

    FROM 
        HDM.Child_Social.FACT_INVOLVEMENTS

    WHERE 
        START_DTTM <= @CaseloadLastSept30th AND 
        (END_DTTM IS NULL OR END_DTTM >= @CaseloadLastSept30th) AND
        START_DTTM >= @CaseloadTimeframeStartDate -- ssd timeframe constraint
        and IS_ALLOCATED_CW_FLAG = 'y'
    
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID
WHERE 
    dw.DIM_WORKER_ID <> -1
    AND LTRIM(RTRIM(dw.STAFF_ID)) IS NOT NULL           -- in theory would not occur
    AND LOWER(LTRIM(RTRIM(dw.STAFF_ID))) <> 'unknown';  -- data seen in some LAs



-- -- META-ELEMENT: {"type": "create_fk"}    

-- -- META-ELEMENT: {"type": "create_idx"} 
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_professional_id      ON ssd_professionals (prof_professional_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_staff_id             ON ssd_professionals (prof_staff_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_social_worker_reg_no ON ssd_professionals(prof_social_worker_registration_no);

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
