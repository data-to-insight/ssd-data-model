IF OBJECT_ID(N'proc_ssd_assessment_factors', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_assessment_factors AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_assessment_factors
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
-- Remarks: [EA_API_PRIORITY_TABLE]
--          This object referrences some large source tables- Instances of 45m+. 
-- Dependencies: 
-- - #ssd_TMP_PRE_assessment_factors (as staged pre-processing)
-- - ssd_cin_assessments
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors','U') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;
IF OBJECT_ID('tempdb..#ssd_d_codes','U') IS NOT NULL DROP TABLE #ssd_d_codes; -- de-duped + precomputed sort keys

IF OBJECT_ID('ssd_assessment_factors','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_assessment_factors)
        TRUNCATE TABLE ssd_assessment_factors;
END

ELSE
BEGIN
    CREATE TABLE ssd_assessment_factors (
        cinf_table_id                nvarchar(48)  NOT NULL,
        cinf_assessment_id           nvarchar(48)  NOT NULL,
        cinf_assessment_factors_json nvarchar(max) NULL,
        CONSTRAINT PK_ssd_assessment_factors PRIMARY KEY CLUSTERED (cinf_table_id, cinf_assessment_id)
    );
END

/* ========================================================================
   Assessment factors (dual-path: modern + legacy, with ordered codes table)
   - Shared prep builds filtered temp rows from Single Assessments
   - #ssd_d_codes: de-dup + precomputed sort keys + (optional) clustered index
   - Modern path: STRING_AGG (SQL 2022+/Azure SQL) 
   - Legacy path: FOR XML PATH (SQL Server 2012+)
   ======================================================================== */

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* -------------------------------------------
       Shared prep (raw filtered rows)
       ------------------------------------------- */
    
    SELECT
        fsa.FACT_SINGLE_ASSESSMENT_ID,
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER
    INTO #ssd_TMP_PRE_assessment_factors
    FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
    INNER JOIN HDM.Child_Social.FACT_FORM_ANSWERS   AS ffa
      ON fsa.FACT_FORM_ID = ffa.FACT_FORM_ID
    WHERE ffa.ANSWER_NO IN (
          '1A','1B','1C'
        ,'2A','2B','2C','3A','3B','3C'
        ,'4A','4B','4C'
        ,'5A','5B','5C'
        ,'6A','6B','6C'
        ,'7A'
        ,'8B','8C','8D','8E','8F'
        ,'9A','10A','11A','12A','13A','14A','15A','16A','17A'
        ,'18A','18B','18C'
        ,'19A','19B','19C'
        ,'20','21'
        ,'22A','23A','24A'
    )
      AND LOWER(ffa.ANSWER) = 'yes'
      AND ffa.FACT_FORM_ID <> -1;

    /* -------------------------------------------
       Compact codes table (de-dup + sort keys)
       ------------------------------------------- */
    
    SELECT DISTINCT
        d.FACT_SINGLE_ASSESSMENT_ID,
        d.FACT_FORM_ID,
        d.ANSWER_NO,
        d.ANSWER,
        -- sort parts: numeric prefix then alpha suffix (or '' if none)
        TRY_CONVERT(int, LEFT(d.ANSWER_NO, CASE
            WHEN PATINDEX('%[^0-9]%', d.ANSWER_NO) = 0 THEN LEN(d.ANSWER_NO)
            ELSE PATINDEX('%[^0-9]%', d.ANSWER_NO) - 1
        END)) AS num_part,
        CASE
            WHEN PATINDEX('%[^0-9]%', d.ANSWER_NO) = 0 THEN N''
            ELSE SUBSTRING(d.ANSWER_NO, PATINDEX('%[^0-9]%', d.ANSWER_NO), 10)
        END AS alpha_part
    INTO #ssd_d_codes
    FROM #ssd_TMP_PRE_assessment_factors AS d;



    -- Optional index (IF your LA assessments row count is millions)
    -- CREATE CLUSTERED INDEX IX_codes ON #ssd_d_codes(FACT_FORM_ID, num_part, alpha_part, ANSWER_NO) INCLUDE (ANSWER);

    /* -------------------------------------------
       Legacy path: SQL Server 2012+
       Build JSON via FOR XML PATH using ordered #ssd_d_codes
       ------------------------------------------- */
    INSERT INTO ssd_assessment_factors (
        cinf_table_id,
        cinf_assessment_id,
        cinf_assessment_factors_json
    )
    SELECT
        fsa.EXTERNAL_ID AS cinf_table_id,
        fsa.FACT_SINGLE_ASSESSMENT_ID AS cinf_assessment_id,
        (

                -- -- KEY-VALUES output e.g. {"1B": "Yes", "2B": "Yes", ...}  (alternative 1):
                -- '{' +
                -- STUFF((
                --     SELECT
                --         ', "' + x.ANSWER_NO + '": ' + QUOTENAME(x.ANSWER, '"')
                --     FROM #ssd_d_codes AS x
                --     WHERE x.FACT_SINGLE_ASSESSMENT_ID = fsa.FACT_SINGLE_ASSESSMENT_ID
                --     ORDER BY x.num_part, x.alpha_part
                --     FOR XML PATH(''), TYPE
                -- ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') +
                -- '}'


                -- Awaiting LA/DfE approval
                -- KEYS-ONLY output e.g. ["1A","2B", ...] (alternative 2):
            '[' + STUFF((
                SELECT ', "' + x.ANSWER_NO + '"'
                FROM #ssd_d_codes AS x
                WHERE x.FACT_SINGLE_ASSESSMENT_ID = fsa.FACT_SINGLE_ASSESSMENT_ID
                AND x.ANSWER_NO IS NOT NULL
                ORDER BY x.num_part, x.alpha_part
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ']'
        ) AS cinf_assessment_factors_json
    FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
    JOIN (SELECT DISTINCT FACT_SINGLE_ASSESSMENT_ID FROM #ssd_d_codes) AS d
    ON d.FACT_SINGLE_ASSESSMENT_ID = fsa.FACT_SINGLE_ASSESSMENT_ID
    WHERE fsa.EXTERNAL_ID <> -1
    AND fsa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D'); -- filter consistent with cin_assessments (exclude drafts and cancelled)
    -- Optional scope:
    -- AND fsa.FACT_SINGLE_ASSESSMENT_ID IN (SELECT cina_assessment_id FROM ssd_cin_assessments)


    -- /* -------------------------------------------
    --    Modern path: SQL Server 2022 or Azure SQL only
    --    enable on modern servers, comment out legacy INSERT above and 
    --    uncomment this whole block
    --    ------------------------------------------- */

        -- INSERT INTO ssd_assessment_factors (
        --     cinf_table_id,
        --     cinf_assessment_id,
        --     cinf_assessment_factors_json
        -- )
        -- SELECT
        --     fsa.EXTERNAL_ID AS cinf_table_id,
        --     fsa.FACT_SINGLE_ASSESSMENT_ID AS cinf_assessment_id,


        --     -- -- KEY-VALUES output {"1B": "Yes", "2B": "Yes", ...}
        --     -- N'{' + STRING_AGG(
        --     --         CONCAT('"', c.ANSWER_NO, '": ', QUOTENAME(c.ANSWER, '"')),
        --     --         N', '
        --     --     ) WITHIN GROUP (ORDER BY c.num_part, c.alpha_part)
        --     -- + N'}' AS cinf_assessment_factors_json

        --     -- KEYS-ONLY alternative ["1A","2B",...] 
        --     N'[' + STRING_AGG(
        --             CONCAT('"', c.ANSWER_NO, '"'),
        --             N', '
        --          ) WITHIN GROUP (ORDER BY c.num_part, c.alpha_part)
        --        + N']' AS cinf_assessment_factors_json

        -- FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
        -- JOIN #ssd_d_codes AS c
        -- ON c.FACT_SINGLE_ASSESSMENT_ID = fsa.FACT_SINGLE_ASSESSMENT_ID

        -- WHERE fsa.EXTERNAL_ID <> -1
        -- AND fsa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')

        -- GROUP BY fsa.EXTERNAL_ID, fsa.FACT_SINGLE_ASSESSMENT_ID;
        -- -- Optional scope:
        -- -- AND fsa.FACT_SINGLE_ASSESSMENT_ID IN (SELECT cina_assessment_id FROM ssd_cin_assessments)


    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;  -- handles both 1 and -1 states
    THROW;  -- preserve original error details
END CATCH;

-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_assessment_factors ADD CONSTRAINT FK_ssd_cinf_assessment_id
-- FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_cin_assessments(cina_assessment_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE CLUSTERED INDEX IX_codes ON #ssd_d_codes(FACT_SINGLE_ASSESSMENT_ID, num_part, alpha_part, ANSWER_NO) INCLUDE (ANSWER, FACT_FORM_ID);

-- Cleanup
IF OBJECT_ID('tempdb..#ssd_d_codes','U') IS NOT NULL DROP TABLE #ssd_d_codes;
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors','U') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;

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
