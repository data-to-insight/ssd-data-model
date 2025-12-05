IF OBJECT_ID(N'proc_ssd_cla_health', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_health AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_health
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
-- Object Name: ssd_cla_health
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 1.5 JH updated source for clah_health_check_type to resolve blanks.
--             Updated to use DIM_LOOKUP_EXAM_STATUS_DESC as opposed to _CODE
--             to inprove readability.
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_HEALTH_CHECK
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

IF OBJECT_ID('ssd_cla_health','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_health)
        TRUNCATE TABLE ssd_cla_health;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_health (
        clah_health_check_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAH001A"}
        clah_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
        clah_health_check_type      NVARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
        clah_health_check_date      DATETIME,                   -- metadata={"item_ref":"CLAH004A"}
        clah_health_check_status    NVARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
    );
END

INSERT INTO ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 
SELECT
    fhc.FACT_HEALTH_CHECK_ID,
    fhc.DIM_PERSON_ID,
    fhc.DIM_LOOKUP_EVENT_TYPE_DESC,
    fhc.START_DTTM,
    fhc.DIM_LOOKUP_EXAM_STATUS_DESC
FROM
    HDM.Child_Social.FACT_HEALTH_CHECK as fhc
 

WHERE
    (fhc.START_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fhc.START_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fhc.DIM_PERSON_ID -- #DtoI-1799
    );

-- ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_ssd_clah_to_clae 
-- FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_person_id ON ssd_cla_health (clah_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_health_check_date ON ssd_cla_health(clah_health_check_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_health_check_status ON ssd_cla_health(clah_health_check_status);

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
