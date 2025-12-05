IF OBJECT_ID(N'proc_ssd_cla_reviews', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_reviews AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_reviews
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
-- - ssd_cla_episodes
-- - HDM.Child_Social.FACT_CLA_REVIEW
-- - HDM.Child_Social.FACT_MEETING_SUBJECTS 
-- - HDM.Child_Social.FACT_MEETINGS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
IF OBJECT_ID('ssd_cla_reviews','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_reviews)
        TRUNCATE TABLE ssd_cla_reviews;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_reviews (
        clar_cla_review_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAR001A"}
        clar_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
        clar_cla_review_due_date        DATETIME,                   -- metadata={"item_ref":"CLAR003A"}
        clar_cla_review_date            DATETIME,                   -- metadata={"item_ref":"CLAR004A"}
        clar_cla_review_cancelled       NCHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
        clar_cla_review_participation   NVARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
    );
END

INSERT INTO ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
) 
SELECT
    fcr.FACT_CLA_REVIEW_ID                          AS clar_cla_review_id,
    fcr.FACT_CLA_ID                                 AS clar_cla_id,                
    fcr.DUE_DTTM                                    AS clar_cla_review_due_date,
    fcr.MEETING_DTTM                                AS clar_cla_review_date,
    fm.CANCELLED                                    AS clar_cla_review_cancelled,
 
    (SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
        AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
        THEN ISNULL(fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC, '') END)) 
                                                    AS clar_cla_review_participation
 
FROM
    HDM.Child_Social.FACT_CLA_REVIEW AS fcr
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm               ON fcr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms      ON fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_FORMS ff ON fms.FACT_OUTCM_FORM_ID = ff.FACT_FORM_ID
    AND fms.FACT_OUTCM_FORM_ID <> '1071252'     -- duplicate outcomes form for ESCC causing PK error
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON fcr.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'

AND
    (fcr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fcr.MEETING_DTTM IS NULL)
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fcr.DIM_PERSON_ID -- #DtoI-1799
    )
 
GROUP BY fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID,
    ff.FACT_FORM_ID,
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE
    ;



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_cla_reviews ADD CONSTRAINT FK_ssd_clar_to_clae 
-- FOREIGN KEY (clar_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_cla_id ON ssd_cla_reviews(clar_cla_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_review_due_date ON ssd_cla_reviews(clar_cla_review_due_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_review_date ON ssd_cla_reviews(clar_cla_review_date);

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
