IF OBJECT_ID(N'proc_ssd_cp_visits', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cp_visits AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cp_visits
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
-- Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
--          using casenote ID as PK and linking to CP Visit where available.
--          Will have to use Person ID to link object to Person table
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_CASENOTES
-- - HDM.Child_Social.FACT_CP_VISIT
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cp_visits', 'U') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
IF OBJECT_ID('ssd_cp_visits','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cp_visits)
        TRUNCATE TABLE ssd_cp_visits;
END

ELSE
BEGIN
    CREATE TABLE ssd_cp_visits (
        cppv_cp_visit_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPV007A"} 
        cppv_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CPPV008A"}
        cppv_cp_plan_id                 NVARCHAR(48),   -- metadata={"item_ref":"CPPV001A"}
        cppv_cp_visit_date              DATETIME,       -- metadata={"item_ref":"CPPV003A"}
        cppv_cp_visit_seen              NCHAR(1),       -- metadata={"item_ref":"CPPV004A"}
        cppv_cp_visit_seen_alone        NCHAR(1),       -- metadata={"item_ref":"CPPV005A"}
        cppv_cp_visit_bedroom           NCHAR(1)        -- metadata={"item_ref":"CPPV006A"}
    );
END


-- CTE Ensure unique cases only, most recent has priority-- #DtoI-1715 
;WITH UniqueCasenotes AS (
    SELECT
        cn.FACT_CASENOTE_ID     AS cppv_cp_visit_id,  
        p.DIM_PERSON_ID         AS cppv_person_id,            
        cpv.FACT_CP_PLAN_ID     AS cppv_cp_plan_id,  
        cn.EVENT_DTTM           AS cppv_cp_visit_date,
        cn.SEEN_FLAG            AS cppv_cp_visit_seen,
        cn.SEEN_ALONE_FLAG      AS cppv_cp_visit_seen_alone,
        cn.SEEN_BEDROOM_FLAG    AS cppv_cp_visit_bedroom,
        ROW_NUMBER() OVER (
            PARTITION BY cn.FACT_CASENOTE_ID 
            ORDER BY cn.EVENT_DTTM DESC
        ) AS rn
    FROM
        HDM.Child_Social.FACT_CASENOTES AS cn
    LEFT JOIN
        HDM.Child_Social.FACT_CP_VISIT AS cpv ON cn.FACT_CASENOTE_ID = cpv.FACT_CASENOTE_ID
    LEFT JOIN
        HDM.Child_Social.DIM_PERSON p ON cn.DIM_PERSON_ID = p.DIM_PERSON_ID
    WHERE
        cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC') -- Ref. ( 'STVC','STVCPCOVID')
        AND (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
        OR cn.EVENT_DTTM IS NULL)
)

INSERT INTO ssd_cp_visits (
    cppv_cp_visit_id,
    cppv_person_id,            
    cppv_cp_plan_id,  
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
)
SELECT
    cppv_cp_visit_id,  
    cppv_person_id,            
    cppv_cp_plan_id,  
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
FROM
    UniqueCasenotes
WHERE
    rn = 1;

-- [TESTING]
-- ALTER TABLE ssd_cp_visits ADD CONSTRAINT FK_ssd_cppv_to_cppl
-- FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);

-- -- [TESTING] investigating the above constraint failure. (29 IDs not in cP_plans)
-- SELECT cppv_cp_plan_id
-- FROM ssd_cp_visits
-- WHERE cppv_cp_plan_id IS NOT NULL
--   AND cppv_cp_plan_id NOT IN (SELECT cppl_cp_plan_id FROM ssd_cp_plans);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_person_id        ON ssd_cp_visits(cppv_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_cp_plan_id       ON ssd_cp_visits(cppv_cp_plan_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_cp_visit_date    ON ssd_cp_visits(cppv_cp_visit_date);

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
