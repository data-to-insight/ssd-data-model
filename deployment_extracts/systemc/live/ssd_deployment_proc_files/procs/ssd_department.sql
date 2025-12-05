IF OBJECT_ID(N'proc_ssd_department', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_department AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_department
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
-- Remarks: 
-- Dependencies: 
-- - HDM.Child_Social.DIM_DEPARTMENT
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_department', 'U') IS NOT NULL DROP TABLE #ssd_department;

IF OBJECT_ID('ssd_department','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_department)
        TRUNCATE TABLE ssd_department;
END

ELSE
BEGIN
    CREATE TABLE ssd_department (
        dept_team_id           NVARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
        dept_team_name         NVARCHAR(255), -- metadata={"item_ref":"DEPT1002A"}
        dept_team_parent_id    NVARCHAR(48),  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
        dept_team_parent_name  NVARCHAR(255)  -- metadata={"item_ref":"DEPT1004A"}
    );
END

INSERT INTO ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)
SELECT 
    dpt.DIM_DEPARTMENT_ID       AS dept_team_id,
    dpt.NAME                    AS dept_team_name,
    dpt.DEPT_ID                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name

FROM HDM.Child_Social.DIM_DEPARTMENT dpt

WHERE dpt.dim_department_id <> -1;

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_department ADD CONSTRAINT FK_ssd_dept_team_parent_id 
-- FOREIGN KEY (dept_team_parent_id) REFERENCES ssd_department(dept_team_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE INDEX IX_ssd_dept_team_id ON ssd_department (dept_team_id);

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
