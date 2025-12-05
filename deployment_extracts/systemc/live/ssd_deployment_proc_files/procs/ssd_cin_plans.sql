IF OBJECT_ID(N'proc_ssd_cin_plans', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cin_plans AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cin_plans
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_CARE_PLAN_SUMMARY
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cin_plans'', ''U'') IS NOT NULL DROP TABLE #ssd_cin_plans;

IF OBJECT_ID(''ssd_cin_plans'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_plans)
        TRUNCATE TABLE ssd_cin_plans;
END

ELSE
BEGIN
    CREATE TABLE ssd_cin_plans (
        cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINP001A"}
        cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
        cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
        cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
        cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
        cinp_cin_plan_team          NVARCHAR(48),               -- metadata={"item_ref":"CINP005A"}
        cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
    );
END

INSERT INTO ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT
    cps.FACT_CARE_PLAN_SUMMARY_ID      AS cinp_cin_plan_id,
    cps.FACT_REFERRAL_ID               AS cinp_referral_id,
    cps.DIM_PERSON_ID                  AS cinp_person_id,
    cps.START_DTTM                     AS cinp_cin_plan_start_date,
    cps.END_DTTM                       AS cinp_cin_plan_end_date,
 
    -- (SELECT
    --     MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
    --              THEN ISNULL(fp.DIM_PLAN_COORD_DEPT_ID_DESC, '''') END))

    --                                    AS cinp_cin_plan_team_name,

    -- (SELECT
    --     MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
    --              THEN ISNULL(fp.DIM_PLAN_COORD_ID_DESC, '''') END))

    --                                    AS cinp_cin_plan_worker_name
    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
                THEN fp.DIM_PLAN_COORD_DEPT_ID END, '''')))                                   -- was fp.DIM_PLAN_COORD_DEPT_ID_DESC
                                            AS cinp_cin_plan_team,

    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
                THEN fp.DIM_PLAN_COORD_ID END, '''')))                                        -- was fp.DIM_PLAN_COORD_ID_DESC
                                            AS cinp_cin_plan_worker_id

FROM HDM.Child_Social.FACT_CARE_PLAN_SUMMARY cps  
 
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS fp ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
 
WHERE DIM_LOOKUP_PLAN_TYPE_CODE = ''FP'' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> ''z''
 
AND
    (cps.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cps.END_DTTM IS NULL)

AND EXISTS
(
    -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cps.DIM_PERSON_ID -- #DtoI-1799
)
 
GROUP BY
    cps.FACT_CARE_PLAN_SUMMARY_ID,
    cps.FACT_REFERRAL_ID,
    cps.DIM_PERSON_ID,
    cps.START_DTTM,
    cps.END_DTTM
    ;



-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_ssd_cinp_to_person 
-- FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_plans_person_id       ON ssd_cin_plans(cinp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_cin_plan_start_date  ON ssd_cin_plans(cinp_cin_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_cin_plan_end_date    ON ssd_cin_plans(cinp_cin_plan_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_referral_id          ON ssd_cin_plans(cinp_referral_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
