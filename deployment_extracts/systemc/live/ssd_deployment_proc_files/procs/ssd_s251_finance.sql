IF OBJECT_ID(N'proc_ssd_s251_finance', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_s251_finance AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_s251_finance
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
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_s251_finance'', ''U'') IS NOT NULL DROP TABLE #ssd_s251_finance;

IF OBJECT_ID(''ssd_s251_finance'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_s251_finance)
        TRUNCATE TABLE ssd_s251_finance;
END

ELSE
BEGIN
    CREATE TABLE ssd_s251_finance (
        s251_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S251001A"}
        s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
        s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
        s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
        s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
        s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
    );
END

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_s251_finance (
--     -- row id ommitted as ID generated (s251_table_id,)
--     s251_cla_placement_id,
--     s251_placeholder_1,
--     s251_placeholder_2,
--     s251_placeholder_3,
--     s251_placeholder_4
-- )
-- VALUES
--     (''SSD_PH'', ''SSD_PH'', ''SSD_PH'', ''SSD_PH'', ''SSD_PH'');


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_ssd_s251_to_cla_placement 
-- FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_s251_cla_placement_id ON ssd_s251_finance(s251_cla_placement_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
