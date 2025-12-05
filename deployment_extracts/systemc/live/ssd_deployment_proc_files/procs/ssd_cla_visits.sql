IF OBJECT_ID(N'proc_ssd_cla_visits', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_visits AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_visits
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
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CASENOTES
-- - HDM.Child_Social.FACT_CLA_VISIT
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;

IF OBJECT_ID('ssd_cla_visits','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_visits)
        TRUNCATE TABLE ssd_cla_visits;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_visits (
        clav_cla_visit_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAV001A"}
        clav_cla_id                 NVARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
        clav_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
        clav_cla_visit_date         DATETIME,                   -- metadata={"item_ref":"CLAV003A"}
        clav_cla_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
        clav_cla_visit_seen_alone   NCHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
    );
END

INSERT INTO ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 
SELECT
    clav.FACT_CLA_VISIT_ID      AS clav_cla_visit_id,
    clav.FACT_CLA_ID            AS clav_cla_id,
    clav.DIM_PERSON_ID          AS clav_person_id,
    cn.EVENT_DTTM               AS clav_cla_visit_date,
    cn.SEEN_FLAG                AS clav_cla_visit_seen,
    cn.SEEN_ALONE_FLAG          AS clav_cla_visit_seen_alone
 
FROM
    HDM.Child_Social.FACT_CLA_VISIT AS clav
 
LEFT JOIN
    HDM.Child_Social.FACT_CASENOTES AS cn ON  clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
    AND clav.DIM_PERSON_ID = cn.DIM_PERSON_ID
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON   clav.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVL')

AND
    (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cn.EVENT_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = clav.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}   
-- ALTER TABLE ssd_cla_visits ADD CONSTRAINT FK_ssd_clav_person_id
-- FOREIGN KEY (clav_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_person_id ON ssd_cla_visits(clav_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_visit_date ON ssd_cla_visits(clav_cla_visit_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_cla_id ON ssd_cla_visits(clav_cla_id);

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
