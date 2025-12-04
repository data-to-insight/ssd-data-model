IF OBJECT_ID(N'proc_ssd_ehcp_assessment', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_ehcp_assessment AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_ehcp_assessment
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

IF OBJECT_ID(''tempdb..#ssd_ehcp_assessment'', ''U'') IS NOT NULL DROP TABLE #ssd_ehcp_assessment ;

IF OBJECT_ID(''ssd_ehcp_assessment'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_ehcp_assessment)
        TRUNCATE TABLE ssd_ehcp_assessment;
END

ELSE
BEGIN
    CREATE TABLE ssd_ehcp_assessment (
        ehca_ehcp_assessment_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCA001A"}
        ehca_ehcp_request_id                    NVARCHAR(48),               -- metadata={"item_ref":"EHCA002A"}
        ehca_ehcp_assessment_outcome_date       DATETIME,                   -- metadata={"item_ref":"EHCA003A"}
        ehca_ehcp_assessment_outcome            NVARCHAR(100),              -- metadata={"item_ref":"EHCA004A"}
        ehca_ehcp_assessment_exceptions         NVARCHAR(100)               -- metadata={"item_ref":"EHCA005A"}
    );
END





-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
-- FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);

-- -- META-ELEMENT: {"type": "create_idx"}

-- INSERT INTO ssd_ehcp_assessment (ehca_ehcp_assessment_id, ehca_ehcp_request_id, ehca_ehcp_assessment_outcome_date, ehca_ehcp_assessment_outcome, ehca_ehcp_assessment_exceptions)
-- VALUES (''SSD_PH'', ''SSD_PH'', ''1900/01/01'', ''SSD_PH'', ''SSD_PH'');

-- WHERE
--     (source_to_ehca_ehcp_assessment_outcome_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehca_ehcp_assessment_outcome_date  IS NULL)

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
