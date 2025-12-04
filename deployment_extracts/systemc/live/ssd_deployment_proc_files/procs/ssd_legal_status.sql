IF OBJECT_ID(N'proc_ssd_legal_status', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_legal_status AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_legal_status
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
-- - HDM.Child_Social.FACT_LEGAL_STATUS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_legal_status'', ''U'') IS NOT NULL DROP TABLE #ssd_legal_status;

IF OBJECT_ID(''ssd_legal_status'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_legal_status)
        TRUNCATE TABLE ssd_legal_status;
END

ELSE
BEGIN
    CREATE TABLE ssd_legal_status (
        lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LEGA001A"}
        lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
        lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
        lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
        lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
    );
END

INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)
SELECT
    fls.FACT_LEGAL_STATUS_ID,
    fls.DIM_PERSON_ID,
    fls.DIM_LOOKUP_LGL_STATUS_DESC,
    fls.START_DTTM,
    fls.END_DTTM
FROM
    HDM.Child_Social.FACT_LEGAL_STATUS AS fls

WHERE 
    (fls.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fls.END_DTTM IS NULL)

AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fls.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_ssd_legal_status_person
-- FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_lega_person_id   ON ssd_legal_status(lega_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status                  ON ssd_legal_status(lega_legal_status);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_start            ON ssd_legal_status(lega_legal_status_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_end              ON ssd_legal_status(lega_legal_status_end_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
