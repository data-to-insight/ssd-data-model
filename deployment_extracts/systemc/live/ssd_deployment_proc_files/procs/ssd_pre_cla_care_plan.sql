IF OBJECT_ID(N'proc_ssd_pre_cla_care_plan', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_pre_cla_care_plan AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_pre_cla_care_plan
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks:    Added short codes to plan type questions to improve readability.
--             Removed form type filter, only filtering ffa. on ANSWER_NO.
--             Requires #LEGACY-PRE2016 changes.
-- Dependencies:
-- - ssd_person
-- - #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cla_care_plan'', ''U'') IS NOT NULL DROP TABLE #ssd_cla_care_plan;
IF OBJECT_ID(''tempdb..#ssd_pre_cla_care_plan'', ''U'') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;

IF OBJECT_ID(''ssd_pre_cla_care_plan'',''U'') IS NOT NULL
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

IF OBJECT_ID(''ssd_cla_care_plan'',''U'') IS NOT NULL
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
        ffa.ANSWER_NO    IN (''CPFUP1'', ''CPFUP10'', ''CPFUP2'', ''CPFUP3'', ''CPFUP4'', ''CPFUP5'', ''CPFUP6'', ''CPFUP7'', ''CPFUP8'', ''CPFUP9'')
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
    (
        -- Manual JSON-like concatenation for lacp_cla_care_plan_json
        ''{'' +
        ''"REMAINSUP": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP1'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"RETURN1M": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP2'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"RETURN6M": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP3'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"RETURNEV": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP4'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"LTRELFR": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP5'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"LTFOST18": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP6'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"RESPLMT": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP7'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"SUPPLIV": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP8'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"ADOPTION": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP9'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''", '' +
        ''"OTHERPLN": "'' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP10'' THEN tmp_cpl.ANSWER END), '''') AS NVARCHAR(50)), '''') + ''"'' +
        ''}''
    ) AS lacp_cla_care_plan_json
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp
LEFT JOIN 
    ssd_pre_cla_care_plan tmp_cpl 
    ON tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
WHERE 
    fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = ''A''
    AND EXISTS (
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
    )
GROUP BY
    fcp.FACT_CARE_PLAN_ID,
    fcp.DIM_PERSON_ID,
    fcp.START_DTTM,
    fcp.END_DTTM;

-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT
--     fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
--     fcp.DIM_PERSON_ID              AS lacp_person_id,
--     fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
--     fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
--     (
--         SELECT  -- Combined _json field with ''ICP'' responses
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP1''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS REMAINSUP,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP2''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS RETURN1M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP3''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS RETURN6M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP4''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS RETURNEV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP5''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS LTRELFR,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP6''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS LTFOST18,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP7''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS RESPLMT,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP8''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS SUPPLIV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP9''  THEN tmp_cpl.ANSWER END, '''')), NULL) AS ADOPTION,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = ''CPFUP10'' THEN tmp_cpl.ANSWER END, '''')), NULL) AS OTHERPLN
--         FROM
--             -- #ssd_TMP_PRE_cla_care_plan tmp_cpl
--             ssd_pre_cla_care_plan tmp_cpl

--         WHERE
--             tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
 
--         GROUP BY tmp_cpl.DIM_PERSON_ID
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS lacp_cla_care_plan_json
 
-- FROM
--     HDM.Child_Social.FACT_CARE_PLANS AS fcp


-- WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = ''A''
--     AND EXISTS (
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

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
