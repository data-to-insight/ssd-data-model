IF OBJECT_ID(N'proc_ssd_cin_visits', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cin_visits AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cin_visits
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks:    Source table can be very large! Avoid any unfiltered queries.
--             Notes: Does this need to be filtered by only visits in their current Referral episode?
--                     however for some this ==2 weeks, others==~17 years
--                 --> when run for records in ssd_person c.64k records 29s runtime
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_CASENOTES
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cin_visits'', ''U'') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
IF OBJECT_ID(''ssd_cin_visits'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_visits)
        TRUNCATE TABLE ssd_cin_visits;
END

ELSE
BEGIN
    CREATE TABLE ssd_cin_visits
    (
        cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINV001A"}      
        cinv_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINV007A"}
        cinv_cin_visit_date         DATETIME,                   -- metadata={"item_ref":"CINV003A"}
        cinv_cin_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CINV004A"}
        cinv_cin_visit_seen_alone   NCHAR(1),                   -- metadata={"item_ref":"CINV005A"}
        cinv_cin_visit_bedroom      NCHAR(1)                    -- metadata={"item_ref":"CINV006A"}
    );
END

INSERT INTO ssd_cin_visits
(
    cinv_cin_visit_id,                  
    cinv_person_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)
SELECT
    cn.FACT_CASENOTE_ID,                
    cn.DIM_PERSON_ID,
    cn.EVENT_DTTM,
    cn.SEEN_FLAG,
    cn.SEEN_ALONE_FLAG,
    cn.SEEN_BEDROOM_FLAG
FROM
    HDM.Child_Social.FACT_CASENOTES cn
 
WHERE
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN (''CNSTAT'', ''CNSTATCOVID'', ''STAT'', ''HVIS'', ''DRCT'', ''IRO'',
    ''SUPERCONT'', ''STVL'', ''STVLCOVID'', ''CNSTAT'', ''CNSTATCOVID'', ''STVC'', ''STVCPCOVID'')

AND
    (cn.EVENT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cn.EVENT_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cn.DIM_PERSON_ID -- #DtoI-1799
    );
 


-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
-- FOREIGN KEY (cinv_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cinv_person_id        ON ssd_cin_visits(cinv_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinv_cin_visit_date   ON ssd_cin_visits(cinv_cin_visit_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
