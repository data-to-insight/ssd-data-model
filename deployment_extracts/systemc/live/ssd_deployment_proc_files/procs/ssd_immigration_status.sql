IF OBJECT_ID(N'proc_ssd_immigration_status', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_immigration_status AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_immigration_status
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
-- Description: (UASC)
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--          Replaced IMMIGRATION_STATUS_CODE with IMMIGRATION_STATUS_DESC and
--             increased field size to 100
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_IMMIGRATION_STATUS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_immigration_status', 'U') IS NOT NULL DROP TABLE #ssd_immigration_status;

IF OBJECT_ID('ssd_immigration_status','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_immigration_status)
        TRUNCATE TABLE ssd_immigration_status;
END

ELSE
BEGIN
    CREATE TABLE ssd_immigration_status (
        immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
        immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
        immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
        immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
        immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
    );
END

INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE
    EXISTS
    ( -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = ims.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_ssd_immigration_status_person
-- FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_start          ON ssd_immigration_status(immi_immigration_status_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_end            ON ssd_immigration_status(immi_immigration_status_end_date);

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
