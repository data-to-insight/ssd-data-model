IF OBJECT_ID(N'proc_ssd_cla_substance_misuse', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_substance_misuse AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_substance_misuse
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
-- - ssd_person
-- - HDM.Child_Social.ssd_person
-- - HDM.Child_Social.FACT_SUBSTANCE_MISUSE
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse', 'U') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

IF OBJECT_ID('ssd_cla_substance_misuse','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_substance_misuse)
        TRUNCATE TABLE ssd_cla_substance_misuse;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_substance_misuse (
        clas_substance_misuse_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAS001A"}
        clas_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
        clas_substance_misuse_date      DATETIME,                   -- metadata={"item_ref":"CLAS003A"}
        clas_substance_misused          NVARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
        clas_intervention_received      NCHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
    );
END

INSERT INTO ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)
SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID               AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID                          AS clas_person_id,
    fsm.START_DTTM                             AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE         AS clas_substance_misused,
    fsm.ACCEPT_FLAG                            AS clas_intervention_received
FROM 
    HDM.Child_Social.FACT_SUBSTANCE_MISUSE AS fsm

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fsm.DIM_PERSON_ID -- #DtoI-1799
    );

-- ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
-- FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clas_person_id ON ssd_cla_substance_misuse (clas_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clas_substance_misuse_date ON ssd_cla_substance_misuse(clas_substance_misuse_date);

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
