IF OBJECT_ID(N'proc_ssd_immigration_status', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_immigration_status AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_immigration_status
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: (UASC)
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: Replaced IMMIGRATION_STATUS_CODE with IMMIGRATION_STATUS_DESC and
--             increased field size to 100
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_IMMIGRATION_STATUS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_immigration_status'', ''U'') IS NOT NULL DROP TABLE #ssd_immigration_status;

IF OBJECT_ID(''ssd_immigration_status'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_immigration_status)
        TRUNCATE TABLE ssd_immigration_status;
END

ELSE
BEGIN
    CREATE TABLE ssd_immigration_status (
        immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
        immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
        immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
        immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
        immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
    );
END

INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE
    EXISTS
    ( -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = ims.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_ssd_immigration_status_person
-- FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_start          ON ssd_immigration_status(immi_immigration_status_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_end            ON ssd_immigration_status(immi_immigration_status_end_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
