IF OBJECT_ID(N'proc_ssd_cla_convictions', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_convictions AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cla_convictions
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
-- - HDM.Child_Social.FACT_OFFENCE
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cla_convictions'', ''U'') IS NOT NULL DROP TABLE #ssd_cla_convictions;

IF OBJECT_ID(''ssd_cla_convictions'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_convictions)
        TRUNCATE TABLE ssd_cla_convictions;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_convictions (
        clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAC001A"}
        clac_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
        clac_cla_conviction_date    DATETIME,                   -- metadata={"item_ref":"CLAC003A"}
        clac_cla_conviction_offence NVARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
    );
END

INSERT INTO ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )
SELECT 
    fo.FACT_OFFENCE_ID,
    fo.DIM_PERSON_ID,
    fo.OFFENCE_DTTM,
    fo.DESCRIPTION
FROM 
    HDM.Child_Social.FACT_OFFENCE as fo

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fo.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_ssd_clac_to_person 
-- FOREIGN KEY (clac_person_id) REFERENCES ssd_person (pers_person_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clac_person_id ON ssd_cla_convictions(clac_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clac_conviction_date ON ssd_cla_convictions(clac_cla_conviction_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
