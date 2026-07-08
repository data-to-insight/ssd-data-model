IF OBJECT_ID(N'proc_ssd_pre_cla_care_plan', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_pre_cla_care_plan AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_pre_cla_care_plan
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
-- - #ssd_TMP_PRE_cla_care_plan - stage/prep most recent relevant form response
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;

IF OBJECT_ID('ssd_pre_cla_care_plan','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_pre_cla_care_plan)
        TRUNCATE TABLE ssd_pre_cla_care_plan;
END

ELSE
BEGIN
    CREATE TABLE ssd_pre_cla_care_plan (
        FACT_FORM_ID        NVARCHAR(48),
        DIM_PERSON_ID       NVARCHAR(48),
        ANSWER_NO           NVARCHAR(10),
        ANSWER              NVARCHAR(255),
        LatestResponseDate  DATETIME
    );
END

IF OBJECT_ID('ssd_cla_care_plan','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_care_plan)
        TRUNCATE TABLE ssd_cla_care_plan;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_care_plan (
        lacp_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LACP001A"}
        lacp_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LACP007A"}
        lacp_cla_care_plan_start_date   DATETIME,                   -- metadata={"item_ref":"LACP004A"}
        lacp_cla_care_plan_end_date     DATETIME,                   -- metadata={"item_ref":"LACP005A"}
        lacp_cla_care_plan_json         NVARCHAR(1000)              -- metadata={"item_ref":"LACP003A"}
    );
END

;WITH MostRecentQuestionResponse AS (
    SELECT  -- Return the most recent response for each question for each persons
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    JOIN
        HDM.Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID    -- obtain the relevant person_id
    WHERE
        ffa.ANSWER_NO IN ('CPFUP1','CPFUP10','CPFUP2','CPFUP3','CPFUP4','CPFUP5','CPFUP6','CPFUP7','CPFUP8','CPFUP9')
        AND ffa.FACT_FORM_ID IS NOT NULL -- [REVIEW] Added to assist null filter 

    GROUP BY
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO
),
LatestResponses AS (
    SELECT  -- Now add the answered_date (only indirectly of use here/cross referencing)
        mrqr.DIM_PERSON_ID,
        mrqr.ANSWER_NO,
        mrqr.MaxFormID      AS FACT_FORM_ID,
        ffa.ANSWER,
        ffa.ANSWERED_DTTM   AS LatestResponseDate
    FROM
        MostRecentQuestionResponse mrqr
    JOIN
        HDM.Child_Social.FACT_FORM_ANSWERS ffa ON mrqr.MaxFormID = ffa.FACT_FORM_ID AND mrqr.ANSWER_NO = ffa.ANSWER_NO
)

INSERT INTO ssd_pre_cla_care_plan (
    FACT_FORM_ID,
    DIM_PERSON_ID,
    ANSWER_NO,
    ANSWER,
    LatestResponseDate
)
SELECT
    lr.FACT_FORM_ID,
    lr.DIM_PERSON_ID,
    lr.ANSWER_NO,
    lr.ANSWER,
    lr.LatestResponseDate
FROM
    LatestResponses lr
ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;

INSERT INTO ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)
-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
    fcp.DIM_PERSON_ID              AS lacp_person_id,
    fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
    /* Manual JSON-like concatenation for lacp_cla_care_plan_json (no aggregates) */
    LEFT(
        '{' +
        '"REMAINSUP": "' + ISNULL(TRY_CAST(a1.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"RETURN1M": "'  + ISNULL(TRY_CAST(a2.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"RETURN6M": "'  + ISNULL(TRY_CAST(a3.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"RETURNEV": "'  + ISNULL(TRY_CAST(a4.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"LTRELFR": "'   + ISNULL(TRY_CAST(a5.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"LTFOST18": "'  + ISNULL(TRY_CAST(a6.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"RESPLMT": "'   + ISNULL(TRY_CAST(a7.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"SUPPLIV": "'   + ISNULL(TRY_CAST(a8.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"ADOPTION": "'  + ISNULL(TRY_CAST(a9.ANSWER  AS NVARCHAR(50)), '') + '", ' +
        '"OTHERPLN": "'  + ISNULL(TRY_CAST(a10.ANSWER AS NVARCHAR(50)), '') + '"' +
        '}'
    , 1000) AS lacp_cla_care_plan_json
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp

/* Latest answer per code, per person — no aggrs */
OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP1'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a1

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP2'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a2

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP3'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a3

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP4'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a4

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP5'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a5

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP6'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a6

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP7'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a7

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP8'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a8

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP9'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a9

OUTER APPLY (
    SELECT TOP (1) cpl.ANSWER
    FROM ssd_pre_cla_care_plan AS cpl
    WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
      AND cpl.ANSWER_NO = 'CPFUP10'
      AND cpl.ANSWER IS NOT NULL
    ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
) AS a10

WHERE 
    fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
    AND EXISTS (
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID  -- #DtoI-1799
    );



-- -- #LEGACY-PRE2016  
-- -- SQL compatible versions >=2016+
-- SELECT
--     fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
--     fcp.DIM_PERSON_ID              AS lacp_person_id,
--     fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
--     fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,

--     (
--         SELECT
--             ISNULL(a1.ANSWER,  '') AS REMAINSUP,
--             ISNULL(a2.ANSWER,  '') AS RETURN1M,
--             ISNULL(a3.ANSWER,  '') AS RETURN6M,
--             ISNULL(a4.ANSWER,  '') AS RETURNEV,
--             ISNULL(a5.ANSWER,  '') AS LTRELFR,
--             ISNULL(a6.ANSWER,  '') AS LTFOST18,
--             ISNULL(a7.ANSWER,  '') AS RESPLMT,
--             ISNULL(a8.ANSWER,  '') AS SUPPLIV,
--             ISNULL(a9.ANSWER,  '') AS ADOPTION,
--             ISNULL(a10.ANSWER, '') AS OTHERPLN
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS lacp_cla_care_plan_json

-- FROM HDM.Child_Social.FACT_CARE_PLANS AS fcp

-- /* OUTER APPLY: latest answer per code, no aggr */
-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP1'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a1

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP2'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a2

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP3'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a3

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP4'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a4

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP5'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a5

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP6'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a6

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP7'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a7

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP8'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a8

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP9'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a9

-- OUTER APPLY (
--     SELECT TOP (1) cpl.ANSWER
--     FROM ssd_pre_cla_care_plan cpl
--     WHERE cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
--       AND cpl.ANSWER_NO = 'CPFUP10'
--       AND cpl.ANSWER IS NOT NULL
--     ORDER BY cpl.FACT_FORM_ID DESC, cpl.LatestResponseDate DESC
-- ) a10

-- WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
--   AND EXISTS (
--         SELECT 1
--         FROM ssd_person p
--         WHERE TRY_CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_cla_care_plan ADD CONSTRAINT FK_ssd_lacp_person_id
-- FOREIGN KEY (lacp_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_person_id ON ssd_cla_care_plan(lacp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_care_plan_start_date ON ssd_cla_care_plan(lacp_cla_care_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_care_plan_end_date ON ssd_cla_care_plan(lacp_cla_care_plan_end_date);

-- -- Additionally towards APPLY lookups:
-- CREATE INDEX IX_ssd_pre_cla_person_code_form ON ssd_pre_cla_care_plan
-- (DIM_PERSON_ID, ANSWER_NO, FACT_FORM_ID DESC) INCLUDE (ANSWER, LatestResponseDate);

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
