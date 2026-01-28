IF OBJECT_ID(N'proc_ssd_disability', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_disability AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_disability
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
-- Description: Contains the Y/N flag for persons with disability
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_DISABILITY
-- - HDM.Child_Social.DIM_LOOKUP_DISAB
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_disability', 'U') IS NOT NULL DROP TABLE #ssd_disability;

IF OBJECT_ID('ssd_disability','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_disability)
        TRUNCATE TABLE ssd_disability;
END

ELSE
BEGIN
    CREATE TABLE ssd_disability
    (
        disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
        disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
        disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
    );
END

INSERT INTO ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)
SELECT
    fd.FACT_DISABILITY_ID         AS disa_table_id,
    fd.DIM_PERSON_ID              AS disa_person_id,
    LTRIM(RTRIM(dislup.NAT_ID))   AS disa_disability_code

FROM HDM.Child_Social.FACT_DISABILITY fd
INNER JOIN HDM.Child_Social.DIM_LOOKUP_DISAB dislup         -- [REVIEW]
    -- if the internal disa code has associated NAT_ID 
    ON dislup.MAIN_CODE = fd.DIM_LOOKUP_DISAB_CODE
WHERE fd.DIM_PERSON_ID <> -1
  AND fd.DIM_LOOKUP_DISAB_CODE IS NOT NULL
  AND (fd.END_DTTM IS NULL OR fd.END_DTTM > GETDATE()) -- current|not yet closed disa codes
  AND NULLIF(LTRIM(RTRIM(dislup.NAT_ID)), '') IS NOT NULL

  AND EXISTS (   -- only ssd relevant records
      SELECT 1
      FROM ssd_person p
      WHERE TRY_CAST(p.pers_person_id AS INT) = fd.DIM_PERSON_ID -- #DtoI-1799
  );


-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_disability ADD CONSTRAINT FK_ssd_disability_person 
-- FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_person_id  ON ssd_disability(disa_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_code       ON ssd_disability(disa_disability_code);

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
