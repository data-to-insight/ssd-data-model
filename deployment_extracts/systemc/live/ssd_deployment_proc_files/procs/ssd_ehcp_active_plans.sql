IF OBJECT_ID(N'proc_ssd_ehcp_active_plans', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_ehcp_active_plans AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_ehcp_active_plans
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_ehcp_active_plans'', ''U'') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

IF OBJECT_ID(''ssd_ehcp_active_plans'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_ehcp_active_plans)
        TRUNCATE TABLE ssd_ehcp_active_plans;
END

ELSE
BEGIN
    CREATE TABLE ssd_ehcp_active_plans (
        ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCP001A"}
        ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
        ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
    );
END


-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
-- FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);


-- -- META-ELEMENT: {"type": "create_idx"}

-- INSERT INTO ssd_ehcp_active_plans (ehcp_active_ehcp_id, ehcp_ehcp_request_id, ehcp_active_ehcp_last_review_date)
-- VALUES (''SSD_PH'', ''SSD_PH'', ''1900/01/01'');

-- WHERE
--     (source_to_ehcp_active_ehcp_last_review_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehcp_active_ehcp_last_review_date IS NULL)

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
