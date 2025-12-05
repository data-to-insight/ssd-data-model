IF OBJECT_ID(N'proc_ssd_cla_previous_permanence', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_previous_permanence AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_previous_permanence
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
-- Remarks: Adapted from 1.3 ver, needs re-test also with Knowsley.
--         1.5 JH tmp table was not being referenced, updated query and reduced running
--         time considerably, also filtered out rows where ANSWER IS NULL
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_903_DATA [depreciated]
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_previous_permanence') IS NOT NULL DROP TABLE #ssd_TMP_PRE_previous_permanence;

-- Create TMP structure with filtered answers
SELECT
    ffa.FACT_FORM_ID,
    ffa.FACT_FORM_ANSWER_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
INTO #ssd_TMP_PRE_previous_permanence
FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
WHERE
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'
    AND ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
    AND ffa.ANSWER IS NOT NULL;
 
IF OBJECT_ID('ssd_cla_previous_permanence','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_previous_permanence)
        TRUNCATE TABLE ssd_cla_previous_permanence;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_previous_permanence (
        lapp_table_id                               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LAPP001A"}
        lapp_person_id                              NVARCHAR(48),   -- metadata={"item_ref":"LAPP002A"}
        lapp_previous_permanence_option             NVARCHAR(200),  -- metadata={"item_ref":"LAPP003A"}
        lapp_previous_permanence_la                 NVARCHAR(100),  -- metadata={"item_ref":"LAPP004A"}
        lapp_previous_permanence_order_date         NVARCHAR(10)    -- metadata={"item_ref":"LAPP005A"}
    );
END

INSERT INTO ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date

           )
SELECT
    tmp_ffa.FACT_FORM_ID AS lapp_table_id,
    ff.DIM_PERSON_ID AS lapp_person_id,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_option,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_la,
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '')) = 0 AND 
             TRY_CAST(ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '0') AS INT) BETWEEN 1 AND 31 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zz' 
    END + '/' + 
    CASE 
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('January', 'Jan')  THEN '01'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('February', 'Feb') THEN '02'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('March', 'Mar')    THEN '03'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('April', 'Apr')    THEN '04'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('May')             THEN '05'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('June', 'Jun')     THEN '06'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('July', 'Jul')     THEN '07'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('August', 'Aug')   THEN '08'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('September', 'Sep') THEN '09'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') 
        IN ('October', 'Oct')  THEN '10'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('November', 'Nov') THEN '11'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('December', 'Dec') THEN '12'
        ELSE 'zz' 
    END + '/' + 
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '')) = 0 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zzzz' 
    END
    AS lapp_previous_permanence_order_date
FROM
    #ssd_TMP_PRE_previous_permanence tmp_ffa
JOIN
    HDM.Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID
AND EXISTS (
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
)
GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;



-- -- META-ELEMENT: {"type": "create_fk"}   
-- ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_ssd_lapp_person_id
-- FOREIGN KEY (lapp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_lapp_person_id ON ssd_cla_previous_permanence(lapp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_lapp_previous_permanence_option ON ssd_cla_previous_permanence(lapp_previous_permanence_option);

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
