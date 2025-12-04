IF OBJECT_ID(N'proc_ssd_ehcp_requests', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_ehcp_requests AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_ehcp_requests
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

IF OBJECT_ID(''tempdb..#ssd_ehcp_requests'', ''U'') IS NOT NULL DROP TABLE #ssd_ehcp_requests ;

IF OBJECT_ID(''ssd_ehcp_requests'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_ehcp_requests)
        TRUNCATE TABLE ssd_ehcp_requests;
END

ELSE
BEGIN
    CREATE TABLE ssd_ehcp_requests (
        ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCR001A"}
        ehcr_send_table_id              NVARCHAR(48),               -- metadata={"item_ref":"EHCR002A"}
        ehcr_ehcp_req_date              DATETIME,                   -- metadata={"item_ref":"EHCR003A"}
        ehcr_ehcp_req_outcome_date      DATETIME,                   -- metadata={"item_ref":"EHCR004A"}
        ehcr_ehcp_req_outcome           NVARCHAR(100)               -- metadata={"item_ref":"EHCR005A"}
    );
END






-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
-- FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_send(send_table_id);


-- -- META-ELEMENT: {"type": "create_idx"}

-- INSERT INTO ssd_ehcp_requests (ehcr_ehcp_request_id, ehcr_send_table_id, ehcr_ehcp_req_date, ehcr_ehcp_req_outcome_date, ehcr_ehcp_req_outcome)
-- VALUES (''SSD_PH'', ''SSD_PH'', ''1900/01/01'', ''1900/01/01'', ''SSD_PH'');

-- WHERE
--     (source_to_ehcr_ehcp_req_outcome_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehcr_ehcp_req_outcome_date  IS NULL)

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
