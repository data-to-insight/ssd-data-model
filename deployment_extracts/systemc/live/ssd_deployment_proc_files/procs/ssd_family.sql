IF OBJECT_ID(N'proc_ssd_family', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_family AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_family
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
-- Description: Contains the family connections for each person
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
-- Dependencies: 
-- - HDM.Child_Social.FACT_CONTACTS
-- - ssd_person
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_family', 'U') IS NOT NULL DROP TABLE #ssd_family;

IF OBJECT_ID('ssd_family', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_family)
        TRUNCATE TABLE ssd_family;
END

ELSE
BEGIN
    CREATE TABLE ssd_family (
        fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
        fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
        fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
    );
END

INSERT INTO ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )


SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM HDM.Child_Social.FACT_CONTACTS AS fc

WHERE fc.DIM_PERSON_ID <> -1
    AND EXISTS ( -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_family ADD CONSTRAINT FK_ssd_family_person
-- FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_family_person_id          ON ssd_family(fami_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_family_fami_family_id     ON ssd_family(fami_family_id);

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
