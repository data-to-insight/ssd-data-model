IF OBJECT_ID(N'proc_ssd_disability', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_disability AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_disability
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: Contains the Y/N flag for persons with disability
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_DISABILITY
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_disability'', ''U'') IS NOT NULL DROP TABLE #ssd_disability;

IF OBJECT_ID(''ssd_disability'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_disability)
        TRUNCATE TABLE ssd_disability;
END

ELSE
BEGIN
    CREATE TABLE ssd_disability
    (
        disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
        disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
        disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
    );
END

INSERT INTO ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)
SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id,  -- #TESTING|Debug, bringing NULL values through? 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    HDM.Child_Social.FACT_DISABILITY AS fd

WHERE fd.DIM_PERSON_ID <> -1
AND fd.DIM_LOOKUP_DISAB_CODE IS NOT NULL
    AND EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fd.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_disability ADD CONSTRAINT FK_ssd_disability_person 
-- FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_person_id  ON ssd_disability(disa_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_code       ON ssd_disability(disa_disability_code);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
