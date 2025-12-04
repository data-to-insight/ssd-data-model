IF OBJECT_ID(N'proc_ssd_voice_of_child', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_voice_of_child AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_voice_of_child
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Object Name: ssd_voice_of_child
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_voice_of_child'', ''U'') IS NOT NULL DROP TABLE #ssd_voice_of_child;

IF OBJECT_ID(''ssd_voice_of_child'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_voice_of_child)
        TRUNCATE TABLE ssd_voice_of_child;
END

ELSE
BEGIN
    CREATE TABLE ssd_voice_of_child (
        voch_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"VOCH007A"}
        voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
        voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
        voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
        voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
        voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
        voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
    );
END

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_voice_of_child (
--     -- row id ommitted as ID generated (voch_table_id,)
--     voch_person_id,
--     voch_explained_worries,
--     voch_story_help_understand,
--     voch_agree_worker,
--     voch_plan_safe,
--     voch_tablet_help_explain
-- )
-- VALUES
--     (''10001'', ''Y'', ''Y'', ''Y'', ''Y'', ''Y''),
--     (''10002'', ''Y'', ''Y'', ''Y'', ''Y'', ''Y'');


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = source_table.DIM_PERSON_ID
--     );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_ssd_voch_to_person 
-- FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_voice_of_child_voch_person_id ON ssd_voice_of_child(voch_person_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
