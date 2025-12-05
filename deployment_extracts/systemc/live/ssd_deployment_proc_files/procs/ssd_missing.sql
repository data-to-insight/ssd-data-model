IF OBJECT_ID(N'proc_ssd_missing', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_missing AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_missing
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
-- - HDM.Child_Social.FACT_MISSING_PERSON
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

IF OBJECT_ID('ssd_missing','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_missing)
        TRUNCATE TABLE ssd_missing;
END

ELSE
BEGIN
    CREATE TABLE ssd_missing (
        miss_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"MISS001A"}
        miss_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"MISS002A"}
        miss_missing_episode_start_date DATETIME,                   -- metadata={"item_ref":"MISS003A"}
        miss_missing_episode_type       NVARCHAR(100),              -- metadata={"item_ref":"MISS004A"}
        miss_missing_episode_end_date   DATETIME,                   -- metadata={"item_ref":"MISS005A"}
        miss_missing_rhi_offered        NVARCHAR(2),                -- metadata={"item_ref":"MISS006A", "expected_data":["N","Y","NA", NULL]}                
        miss_missing_rhi_accepted       NVARCHAR(2)                 -- metadata={"item_ref":"MISS007A"}
    );
END

INSERT INTO ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,                   
    miss_missing_rhi_accepted    
)
SELECT 
    fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
    fmp.DIM_PERSON_ID                   AS miss_person_id,
    fmp.START_DTTM                      AS miss_missing_episode_start_date,
    fmp.MISSING_STATUS                  AS miss_missing_episode_type,
    fmp.END_DTTM                        AS miss_missing_episode_end_date,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NA' THEN 'NA' -- #DtoI-1617
        WHEN fmp.RETURN_INTERVIEW_OFFERED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_offered,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NA' THEN 'NA' -- #DtoI-1617
        WHEN fmp.RETURN_INTERVIEW_ACCEPTED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_accepted

FROM 
    HDM.Child_Social.FACT_MISSING_PERSON AS fmp

WHERE
    (fmp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fmp.END_DTTM IS NULL)

AND EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fmp.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_missing ADD CONSTRAINT FK_ssd_missing_to_person
-- FOREIGN KEY (miss_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_person_id        ON ssd_missing(miss_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_episode_start    ON ssd_missing(miss_missing_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_episode_end      ON ssd_missing(miss_missing_episode_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_rhi_offered      ON ssd_missing(miss_missing_rhi_offered);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_rhi_accepted     ON ssd_missing(miss_missing_rhi_accepted);

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
