IF OBJECT_ID(N'proc_ssd_early_help_episodes', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_early_help_episodes AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_early_help_episodes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CAF_EPISODE
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_early_help_episodes'', ''U'') IS NOT NULL DROP TABLE #ssd_early_help_episodes;

IF OBJECT_ID(''ssd_early_help_episodes'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_early_help_episodes)
        TRUNCATE TABLE ssd_early_help_episodes;
END

ELSE
BEGIN
    CREATE TABLE ssd_early_help_episodes (
        earl_episode_id             NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EARL001A"}
        earl_person_id              NVARCHAR(48),               -- metadata={"item_ref":"EARL002A"}
        earl_episode_start_date     DATETIME,                   -- metadata={"item_ref":"EARL003A"}
        earl_episode_end_date       DATETIME,                   -- metadata={"item_ref":"EARL004A"}
        earl_episode_reason         NVARCHAR(MAX),              -- metadata={"item_ref":"EARL005A"}
        earl_episode_end_reason     NVARCHAR(MAX),              -- metadata={"item_ref":"EARL006A"}
        earl_episode_organisation   NVARCHAR(MAX),              -- metadata={"item_ref":"EARL007A"}
        earl_episode_worker_id      NVARCHAR(100)               -- metadata={"item_ref":"EARL008A", "item_status": "A", "info":"Consider for removal"}
    );
END

INSERT INTO ssd_early_help_episodes (
    earl_episode_id,
    earl_person_id,
    earl_episode_start_date,
    earl_episode_end_date,
    earl_episode_reason,
    earl_episode_end_reason,
    earl_episode_organisation,
    earl_episode_worker_id                    
)
 
SELECT
    cafe.FACT_CAF_EPISODE_ID,
    cafe.DIM_PERSON_ID,
    cafe.EPISODE_START_DTTM,
    cafe.EPISODE_END_DTTM,
    cafe.START_REASON,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE,
    ''SSD_PH''                             
FROM
    HDM.Child_Social.FACT_CAF_EPISODE AS cafe
 
WHERE 
    (cafe.EPISODE_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cafe.EPISODE_END_DTTM IS NULL)

AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cafe.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_ssd_earl_to_person 
-- FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_episodes_person_id     ON ssd_early_help_episodes(earl_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_start_date             ON ssd_early_help_episodes(earl_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_end_date               ON ssd_early_help_episodes(earl_episode_end_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
