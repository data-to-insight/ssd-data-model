IF OBJECT_ID(N'proc_ssd_s47_enquiry', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_s47_enquiry AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_s47_enquiry
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_S47
-- - HDM.Child_Social.FACT_CP_CONFERENCE
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_s47_enquiry'', ''U'') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

IF OBJECT_ID(''ssd_s47_enquiry'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_s47_enquiry)
        TRUNCATE TABLE ssd_s47_enquiry;
END

ELSE
BEGIN
    CREATE TABLE ssd_s47_enquiry (
        s47e_s47_enquiry_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S47E001A"}
        s47e_referral_id                    NVARCHAR(48),               -- metadata={"item_ref":"S47E010A"}
        s47e_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"S47E002A"}
        s47e_s47_start_date                 DATETIME,                   -- metadata={"item_ref":"S47E004A"}
        s47e_s47_end_date                   DATETIME,                   -- metadata={"item_ref":"S47E005A"}
        s47e_s47_nfa                        NCHAR(1),                   -- metadata={"item_ref":"S47E006A"}
        s47e_s47_outcome_json               NVARCHAR(1000),             -- metadata={"item_ref":"S47E007A"}
        s47e_s47_completed_by_team          NVARCHAR(48),               -- metadata={"item_ref":"S47E009A"}
        s47e_s47_completed_by_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"S47E008A"}
    );
END

INSERT INTO ssd_s47_enquiry(
    s47e_s47_enquiry_id,
    s47e_referral_id,
    s47e_person_id,
    s47e_s47_start_date,
    s47e_s47_end_date,
    s47e_s47_nfa,
    s47e_s47_outcome_json,
    s47e_s47_completed_by_team,
    s47e_s47_completed_by_worker_id
)

-- #LEGACY-PRE2016 
-- SQL compatible versions <2016
SELECT 
    s47.FACT_S47_ID,
    s47.FACT_REFERRAL_ID,
    s47.DIM_PERSON_ID,
    s47.START_DTTM,
    s47.END_DTTM,
    s47.OUTCOME_NFA_FLAG,
    (
        -- Manual JSON-like concatenation for s47e_s47_outcome_json
        ''{'' +
        ''"NFA_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"LEGAL_ACTION_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_LEGAL_ACTION_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"PROV_OF_SERVICES_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"PROV_OF_SB_CARE_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_PROV_OF_SB_CARE_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CP_CONFERENCE_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_CP_CONFERENCE_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NFA_CONTINUE_SINGLE_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"MONITOR_FLAG": "'' + ISNULL(TRY_CAST(s47.OUTCOME_MONITOR_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"OTHER_OUTCOMES_EXIST_FLAG": "'' + ISNULL(TRY_CAST(s47.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"TOTAL_NO_OF_OUTCOMES": '' + ISNULL(TRY_CAST(s47.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(3)), ''null'') + '', '' +
        ''"OUTCOME_COMMENTS": "'' + ISNULL(TRY_CAST(s47.OUTCOME_COMMENTS AS NVARCHAR(900)), '''') + ''"'' +
        ''}''
    ) AS s47e_s47_outcome_json,
    s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
    s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker_id
FROM 
    HDM.Child_Social.FACT_S47 AS s47
WHERE
    (s47.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR s47.END_DTTM IS NULL)
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = s47.DIM_PERSON_ID -- #DtoI-1799
);

-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT 
--     s47.FACT_S47_ID,
--     s47.FACT_REFERRAL_ID,
--     s47.DIM_PERSON_ID,
--     s47.START_DTTM,
--     s47.END_DTTM,
--     s47.OUTCOME_NFA_FLAG,
--     (
--         SELECT 
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             ISNULL(s47.OUTCOME_NFA_FLAG, '''')                   AS NFA_FLAG,
--             ISNULL(s47.OUTCOME_LEGAL_ACTION_FLAG, '''')          AS LEGAL_ACTION_FLAG,
--             ISNULL(s47.OUTCOME_PROV_OF_SERVICES_FLAG, '''')      AS PROV_OF_SERVICES_FLAG,
--             ISNULL(s47.OUTCOME_PROV_OF_SB_CARE_FLAG, '''')       AS PROV_OF_SB_CARE_FLAG,
--             ISNULL(s47.OUTCOME_CP_CONFERENCE_FLAG, '''')         AS CP_CONFERENCE_FLAG,
--             ISNULL(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG, '''')   AS NFA_CONTINUE_SINGLE_FLAG,
--             ISNULL(s47.OUTCOME_MONITOR_FLAG, '''')               AS MONITOR_FLAG,
--             ISNULL(s47.OTHER_OUTCOMES_EXIST_FLAG, '''')          AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(s47.TOTAL_NO_OF_OUTCOMES, '''')               AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(s47.OUTCOME_COMMENTS, '''')                   AS OUTCOME_COMMENTS
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         )                                                      AS s47e_s47_outcome_json,
--     s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
--     s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker_id

-- FROM 
--     HDM.Child_Social.FACT_S47 AS s47

-- WHERE
--     (s47.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR s47.END_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = s47.DIM_PERSON_ID -- #DtoI-1799
--     ) ;


-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_ssd_s47_person
-- FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_person_id     ON ssd_s47_enquiry(s47e_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_start_date    ON ssd_s47_enquiry(s47e_s47_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_end_date      ON ssd_s47_enquiry(s47e_s47_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_referral_id   ON ssd_s47_enquiry(s47e_referral_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
