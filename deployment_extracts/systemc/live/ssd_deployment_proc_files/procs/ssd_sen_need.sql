IF OBJECT_ID(N'proc_ssd_sen_need', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_sen_need AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_sen_need
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

IF OBJECT_ID(''tempdb..#ssd_sen_need'', ''U'') IS NOT NULL DROP TABLE #ssd_sen_need;
 
IF OBJECT_ID(''ssd_sen_need'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_sen_need)
        TRUNCATE TABLE ssd_sen_need;
END

ELSE
BEGIN
    CREATE TABLE ssd_sen_need (
        senn_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SENN001A"}
        senn_active_ehcp_id             NVARCHAR(48),               -- metadata={"item_ref":"SENN002A"}
        senn_active_ehcp_need_type      NVARCHAR(100),              -- metadata={"item_ref":"SENN003A"}
        senn_active_ehcp_need_rank      NCHAR(1)                    -- metadata={"item_ref":"SENN004A"}
    );
END


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
-- FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_ehcp_active_plans(ehcp_active_ehcp_id);

-- INSERT INTO ssd_sen_need (senn_table_id, senn_active_ehcp_id, senn_active_ehcp_need_type, senn_active_ehcp_need_rank)
-- VALUES (''SSD_PH'', ''SSD_PH'', ''SSD_PH'', ''0'');

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
