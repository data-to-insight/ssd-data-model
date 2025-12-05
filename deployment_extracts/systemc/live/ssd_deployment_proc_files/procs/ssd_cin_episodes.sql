IF OBJECT_ID(N'proc_ssd_cin_episodes', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cin_episodes AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cin_episodes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
-- - @ssd_timeframe_years
-- - HDM.Child_Social.FACT_REFERRALS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_cin_episodes'', ''U'') IS NOT NULL DROP TABLE #ssd_cin_episodes;

IF OBJECT_ID(''ssd_cin_episodes'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_episodes)
        TRUNCATE TABLE ssd_cin_episodes;
END

ELSE
BEGIN
    CREATE TABLE ssd_cin_episodes
    (
        cine_referral_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINE001A"}
        cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
        cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
        cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
        cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
        cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
        cine_referral_outcome_json      NVARCHAR(4000), -- metadata={"item_ref":"CINE005A"}
        cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A", "info":"Consider for conversion to Bool"}
        cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
        cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
        cine_referral_team              NVARCHAR(48),   -- metadata={"item_ref":"CINE008A"}
        cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
    );
END

INSERT INTO ssd_cin_episodes
(
    cine_referral_id,
    cine_person_id,
    cine_referral_date,
    cine_cin_primary_need_code,
    cine_referral_source_code,
    cine_referral_source_desc,
    cine_referral_outcome_json,
    cine_referral_nfa,
    cine_close_reason,
    cine_close_date,
    cine_referral_team,
    cine_referral_worker_id
)
   
-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
    fr.DIM_LOOKUP_CONT_SORC_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 2
    (
        -- Manual JSON-like concatenation for cine_referral_outcome_json
        ''{'' +
        ''"SINGLE_ASSESSMENT_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        -- ''"NFA_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '''') + ''", '' + -- Uncomment if needed
        ''"STRATEGY_DISCUSSION_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CLA_REQUEST_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_CLA_REQUEST_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NON_AGENCY_ADOPTION_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"PRIVATE_FOSTERING_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CP_TRANSFER_IN_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_CP_TRANSFER_IN_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CP_CONFERENCE_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_CP_CONFERENCE_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CARE_LEAVER_FLAG": "'' + ISNULL(TRY_CAST(fr.OUTCOME_CARE_LEAVER_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"OTHER_OUTCOMES_EXIST_FLAG": "'' + ISNULL(TRY_CAST(fr.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NUMBER_OF_OUTCOMES": '' + 
            ISNULL(TRY_CAST(CASE 
                WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL
                ELSE fr.TOTAL_NO_OF_OUTCOMES 
            END AS NVARCHAR(4)), ''null'') + '', '' +
        ''"COMMENTS": "'' + ISNULL(TRY_CAST(fr.OUTCOME_COMMENTS AS NVARCHAR(900)), '''') + ''"'' +
        ''}''
    ) AS cine_referral_outcome_json,
    fr.OUTCOME_NFA_FLAG,
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
    fr.REFRL_END_DTTM,
    fr.DIM_DEPARTMENT_ID, -- Swap out on DIM_DEPARTMENT_ID_DESC #DtoI-1762
    fr.DIM_WORKER_ID_DESC
FROM
    HDM.Child_Social.FACT_REFERRALS AS fr
WHERE
    (fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())    -- #DtoI-1806
    OR fr.REFRL_END_DTTM IS NULL)
AND
    DIM_PERSON_ID <> -1  -- Exclude rows with -1
AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fr.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
-- SELECT
--     fr.FACT_REFERRAL_ID,
--     fr.DIM_PERSON_ID,
--     fr.REFRL_START_DTTM,
--     fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
--     fr.DIM_LOOKUP_CONT_SORC_ID,
--     fr.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 1
--     (
--         SELECT
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '''')   AS SINGLE_ASSESSMENT_FLAG,
--             -- ISNULL(fr.OUTCOME_NFA_FLAG, '''')                 AS NFA_FLAG,
--             ISNULL(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '''') AS STRATEGY_DISCUSSION_FLAG,
--             ISNULL(fr.OUTCOME_CLA_REQUEST_FLAG, '''')         AS CLA_REQUEST_FLAG,
--             ISNULL(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '''') AS NON_AGENCY_ADOPTION_FLAG,
--             ISNULL(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '''')   AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '''')      AS CP_TRANSFER_IN_FLAG,
--             ISNULL(fr.OUTCOME_CP_CONFERENCE_FLAG, '''')       AS CP_CONFERENCE_FLAG,
--             ISNULL(fr.OUTCOME_CARE_LEAVER_FLAG, '''')         AS CARE_LEAVER_FLAG,
--             ISNULL(fr.OTHER_OUTCOMES_EXIST_FLAG, '''')        AS OTHER_OUTCOMES_EXIST_FLAG,
--             CASE 
--                 WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
--                 ELSE fr.TOTAL_NO_OF_OUTCOMES 
--             END                                             AS NUMBER_OF_OUTCOMES,
--             ISNULL(fr.OUTCOME_COMMENTS, '''')                 AS COMMENTS
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         ) AS cine_referral_outcome_json,
--     fr.OUTCOME_NFA_FLAG, -- Consider conversion straight to bool
--     fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
--     fr.REFRL_END_DTTM,
--     fr.DIM_DEPARTMENT_ID, -- Swap out on DIM_DEPARTMENT_ID_DESC #DtoI-1762
--     fr.DIM_WORKER_ID_DESC
-- FROM
--     HDM.Child_Social.FACT_REFERRALS AS fr
 
-- WHERE
--     (fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())    -- #DtoI-1806
--     OR fr.REFRL_END_DTTM IS NULL)

-- AND
--     DIM_PERSON_ID <> -1  -- Exclude rows with -1

-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fr.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
-- FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_episodes_person_id    ON ssd_cin_episodes(cine_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_referral_date             ON ssd_cin_episodes(cine_referral_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_close_date                ON ssd_cin_episodes(cine_close_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
