IF OBJECT_ID(N'proc_ssd_cp_plans', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cp_plans AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cp_plans
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
-- - ssd_initial_cp_conference
-- - HDM.Child_Social.FACT_CP_PLAN
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cp_plans'', ''U'') IS NOT NULL DROP TABLE #ssd_cp_plans;

IF OBJECT_ID(''ssd_cp_plans'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cp_plans)
        TRUNCATE TABLE ssd_cp_plans;
END

ELSE
BEGIN
    CREATE TABLE ssd_cp_plans (
        cppl_cp_plan_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPL001A"}
        cppl_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CPPL007A"}
        cppl_icpc_id                    NVARCHAR(48),               -- metadata={"item_ref":"CPPL008A"}
        cppl_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CPPL002A"}
        cppl_cp_plan_start_date         DATETIME,                   -- metadata={"item_ref":"CPPL003A"}
        cppl_cp_plan_end_date           DATETIME,                   -- metadata={"item_ref":"CPPL004A"}
        cppl_cp_plan_ola                NCHAR(1),                   -- metadata={"item_ref":"CPPL011A"}       
        cppl_cp_plan_initial_category   NVARCHAR(100),              -- metadata={"item_ref":"CPPL009A"}
        cppl_cp_plan_latest_category    NVARCHAR(100),              -- metadata={"item_ref":"CPPL010A"}
    );
END

INSERT INTO ssd_cp_plans (
    cppl_cp_plan_id,
    cppl_referral_id,
    cppl_icpc_id,
    cppl_person_id,
    cppl_cp_plan_start_date,
    cppl_cp_plan_end_date,
    cppl_cp_plan_ola,
    cppl_cp_plan_initial_category,
    cppl_cp_plan_latest_category
)
SELECT
    cpp.FACT_CP_PLAN_ID                 AS cppl_cp_plan_id,
    CASE 
        WHEN cpp.FACT_REFERRAL_ID = -1 THEN NULL
        ELSE cpp.FACT_REFERRAL_ID
    END                                 AS cppl_referral_id,
    CASE 
        WHEN cpp.FACT_INITIAL_CP_CONFERENCE_ID = -1 THEN NULL
        ELSE cpp.FACT_INITIAL_CP_CONFERENCE_ID
    END                                 AS cppl_icpc_id,
    cpp.DIM_PERSON_ID                   AS cppl_person_id,
    cpp.START_DTTM                      AS cppl_cp_plan_start_date,
    cpp.END_DTTM                        AS cppl_cp_plan_end_date,
    cpp.IS_OLA                          AS cppl_cp_plan_ola,
    cpp.INIT_CATEGORY_DESC              AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC                AS cppl_cp_plan_latest_category
 
FROM
    HDM.Child_Social.FACT_CP_PLAN cpp
 
WHERE
    (cpp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cpp.END_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cpp.DIM_PERSON_ID -- #DtoI-1799
    );


-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_person_id
-- FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id);


-- ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_icpc_id
-- FOREIGN KEY (cppl_icpc_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id);

-- -- used to test compatibility with the above constraint
-- SELECT cppl_icpc_id
-- FROM ssd_cp_plans
-- WHERE cppl_icpc_id IS NOT NULL
--   AND cppl_icpc_id NOT IN (SELECT icpc_icpc_id FROM ssd_initial_cp_conference)
--   and cppl_icpc_id <> -1;

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_person_id ON ssd_cp_plans(cppl_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_icpc_id ON ssd_cp_plans(cppl_icpc_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_referral_id ON ssd_cp_plans(cppl_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_start_date ON ssd_cp_plans(cppl_cp_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_end_date ON ssd_cp_plans(cppl_cp_plan_end_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
