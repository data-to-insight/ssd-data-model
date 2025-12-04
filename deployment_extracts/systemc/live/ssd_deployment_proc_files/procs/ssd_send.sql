IF OBJECT_ID(N'proc_ssd_send', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_send AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_send
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled locally if accessible. 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_903_DATA
-- - HDM.Education.DIM_PERSON
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_send'', ''U'') IS NOT NULL DROP TABLE #ssd_send;

IF OBJECT_ID(''ssd_send'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_send)
        TRUNCATE TABLE ssd_send;
END

ELSE
BEGIN
    CREATE TABLE ssd_send (
        send_table_id       NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SEND001A"}
        send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
        send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
        send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
        send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );
END

-- for link_identifier_type "FORMER_UPN"
INSERT INTO ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    send_upn_unknown
)
SELECT
    NEWID() AS send_table_id,          -- generate unique id
    csp.dim_person_id AS send_person_id,
    ''SSD_PH'' AS send_upn,               -- csp.upn # only available with Education schema
    ''SSD_PH'' AS send_uln,               -- ep.uln # only available with Education schema              
    ''SSD_PH'' AS send_upn_unknown      
FROM
    HDM.Child_Social.DIM_PERSON csp

-- LEFT JOIN
--     -- we have to switch to Education schema in order to obtain this
--     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

WHERE
    EXISTS (
        SELECT 1
        FROM ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );
 


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
-- FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_send_person_id ON ssd_send (send_person_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
