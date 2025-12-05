IF OBJECT_ID(N'proc_ssd_cla_immunisations', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_immunisations AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_immunisations
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
-- - HDM.Child_Social.FACT_CLA
-- - HDM.Child_Social.FACT_903_DATA [Depreciated]
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_immunisations', 'U') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

IF OBJECT_ID('ssd_cla_immunisations','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_immunisations)
        TRUNCATE TABLE ssd_cla_immunisations;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_immunisations (
        clai_person_id                  NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAI002A"}
        clai_immunisations_status       NCHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
        clai_immunisations_status_date  DATETIME                    -- metadata={"item_ref":"CLAI005A"}
    );
END

-- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)
;WITH RankedImmunisations AS (
    SELECT
        fcla.DIM_PERSON_ID,
        fcla.IMMU_UP_TO_DATE_FLAG,
        fcla.LAST_UPDATED_DTTM,
        ROW_NUMBER() OVER (
            PARTITION BY fcla.DIM_PERSON_ID -- 
            ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
    FROM
        HDM.Child_Social.FACT_CLA AS fcla
    WHERE
        EXISTS ( -- only ssd relevant records be considered for ranking
            SELECT 1 
            FROM ssd_person p
            WHERE TRY_CAST(p.pers_person_id AS INT) = fcla.DIM_PERSON_ID -- #DtoI-1799
        )
)

-- (only most recent/rn==1 records)
INSERT INTO ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)
SELECT
    DIM_PERSON_ID,
    IMMU_UP_TO_DATE_FLAG,
    LAST_UPDATED_DTTM
FROM
    RankedImmunisations
WHERE
    rn = 1; -- pull needed record based on rank==1/most recent record for each DIM_PERSON_ID

-- ALTER TABLE ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
-- FOREIGN KEY (clai_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clai_person_id ON ssd_cla_immunisations(clai_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clai_immunisations_status ON ssd_cla_immunisations(clai_immunisations_status);

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
