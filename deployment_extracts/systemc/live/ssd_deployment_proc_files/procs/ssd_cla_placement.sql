IF OBJECT_ID(N'proc_ssd_cla_placement', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_placement AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cla_placement
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: DEV: filtering for OFSTED_URN LIKE ''SC%''
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CLA_PLACEMENT
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cla_placement'', ''U'') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
IF OBJECT_ID(''ssd_cla_placement'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_placement)
        TRUNCATE TABLE ssd_cla_placement;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_placement (
        clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAP001A"}
        clap_cla_id                         NVARCHAR(48),               -- metadata={"item_ref":"CLAP012A"}
        clap_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CLAP013A"}
        clap_cla_placement_start_date       DATETIME,                   -- metadata={"item_ref":"CLAP003A"}
        clap_cla_placement_type             NVARCHAR(100),              -- metadata={"item_ref":"CLAP004A"}
        clap_cla_placement_urn              NVARCHAR(48),               -- metadata={"item_ref":"CLAP005A"}
        clap_cla_placement_distance         FLOAT,                      -- metadata={"item_ref":"CLAP011A"}
        clap_cla_placement_provider         NVARCHAR(48),               -- metadata={"item_ref":"CLAP007A"}
        clap_cla_placement_postcode         NVARCHAR(8),                -- metadata={"item_ref":"CLAP008A"}
        clap_cla_placement_end_date         DATETIME,                   -- metadata={"item_ref":"CLAP009A"}
        clap_cla_placement_change_reason    NVARCHAR(100)               -- metadata={"item_ref":"CLAP010A"}
    );
END

INSERT INTO ssd_cla_placement (
    clap_cla_placement_id,
    clap_cla_id,
    clap_person_id,
    clap_cla_placement_start_date,
    clap_cla_placement_type,
    clap_cla_placement_urn,
    clap_cla_placement_distance,
    clap_cla_placement_provider,
    clap_cla_placement_postcode,
    clap_cla_placement_end_date,
    clap_cla_placement_change_reason  
)
SELECT
    fcp.FACT_CLA_PLACEMENT_ID                   AS clap_cla_placement_id,
    fcp.FACT_CLA_ID                             AS clap_cla_id,   
    fcp.DIM_PERSON_ID                           AS clap_person_id,                             
    fcp.START_DTTM                              AS clap_cla_placement_start_date,
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE          AS clap_cla_placement_type,
    (
        SELECT
            TOP(1) fce.OFSTED_URN
            FROM   HDM.Child_Social.FACT_CARE_EPISODES fce
            WHERE  fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
            AND    fce.OFSTED_URN LIKE ''SC%''
            AND fce.OFSTED_URN IS NOT NULL        
    )                                           AS clap_cla_placement_urn,
 
    TRY_CAST(fcp.DISTANCE_FROM_HOME AS FLOAT)   AS clap_cla_placement_distance,                         -- convert to FLOAT (source col is nvarchar, also holds nulls/ints)
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
 
    CASE -- removal of common/invalid placeholder data i.e ZZZ, XX
        WHEN LEN(LTRIM(RTRIM(fcp.POSTCODE))) <= 4 THEN NULL
        ELSE LTRIM(RTRIM(fcp.POSTCODE))        -- simplistic clean-up
    END                                         AS clap_cla_placement_postcode,
    fcp.END_DTTM                                AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE          AS clap_cla_placement_change_reason
 
FROM
    HDM.Child_Social.FACT_CLA_PLACEMENT AS fcp
 
-- JOIN
--     HDM.Child_Social.FACT_CARE_EPISODES AS fce ON fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID    -- [TESTING]
 
WHERE fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN (''A1'',''A2'',''A3'',''A4'',''A5'',''A6'',''F1'',''F2'',''F3'',''F4'',''F5'',''F6'',''H1'',''H2'',''H3'',
                                            ''H4'',''H5'',''H5a'',''K1'',''K2'',''M2'',''M3'',''P1'',''P2'',''Q1'',''Q2'',''R1'',''R2'',''R3'',
                                            ''R5'',''S1'',''T0'',''T1'',''U1'',''U2'',''U3'',''U4'',''U5'',''U6'',''Z1'')

AND
    (fcp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fcp.END_DTTM IS NULL);



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_ssd_clap_to_clae 
-- FOREIGN KEY (clap_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_cla_placement_urn ON ssd_cla_placement (clap_cla_placement_urn);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_cla_id ON ssd_cla_placement(clap_cla_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_start_date ON ssd_cla_placement(clap_cla_placement_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_end_date ON ssd_cla_placement(clap_cla_placement_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_postcode ON ssd_cla_placement(clap_cla_placement_postcode);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_type ON ssd_cla_placement(clap_cla_placement_type);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
