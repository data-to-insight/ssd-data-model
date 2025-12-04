IF OBJECT_ID(N'proc_ssd_initial_cp_conference', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_initial_cp_conference AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_initial_cp_conference
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
-- - HDM.Child_Social.FACT_CP_CONFERENCE
-- - HDM.Child_Social.FACT_MEETINGS
-- - HDM.Child_Social.FACT_CP_PLAN
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_initial_cp_conference'', ''U'') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;

IF OBJECT_ID(''ssd_initial_cp_conference'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_initial_cp_conference)
        TRUNCATE TABLE ssd_initial_cp_conference;
END

ELSE
BEGIN
    CREATE TABLE ssd_initial_cp_conference (
        icpc_icpc_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ICPC001A"}
        icpc_icpc_meeting_id        NVARCHAR(48),               -- metadata={"item_ref":"ICPC009A"}
        icpc_s47_enquiry_id         NVARCHAR(48),               -- metadata={"item_ref":"ICPC002A"}
        icpc_person_id              NVARCHAR(48),               -- metadata={"item_ref":"ICPC010A"}
        icpc_cp_plan_id             NVARCHAR(48),               -- metadata={"item_ref":"ICPC011A"}
        icpc_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"ICPC012A"}
        icpc_icpc_transfer_in       NCHAR(1),                   -- metadata={"item_ref":"ICPC003A"}
        icpc_icpc_target_date       DATETIME,                   -- metadata={"item_ref":"ICPC004A"}
        icpc_icpc_date              DATETIME,                   -- metadata={"item_ref":"ICPC005A"}
        icpc_icpc_outcome_cp_flag   NCHAR(1),                   -- metadata={"item_ref":"ICPC013A"}
        icpc_icpc_outcome_json      NVARCHAR(1000),             -- metadata={"item_ref":"ICPC006A"}
        icpc_icpc_team              NVARCHAR(48),               -- metadata={"item_ref":"ICPC007A"}
        icpc_icpc_worker_id         NVARCHAR(100),              -- metadata={"item_ref":"ICPC008A"}
    );
END

INSERT INTO ssd_initial_cp_conference(
    icpc_icpc_id,
    icpc_icpc_meeting_id,
    icpc_s47_enquiry_id,
    icpc_person_id,
    icpc_cp_plan_id,
    icpc_referral_id,
    icpc_icpc_transfer_in,
    icpc_icpc_target_date,
    icpc_icpc_date,
    icpc_icpc_outcome_cp_flag,
    icpc_icpc_outcome_json,
    icpc_icpc_team,
    icpc_icpc_worker_id
)
-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fcpc.FACT_CP_CONFERENCE_ID,
    fcpc.FACT_MEETING_ID,
    CASE 
        WHEN fcpc.FACT_S47_ID IN (''-1'', -1) THEN NULL
        ELSE fcpc.FACT_S47_ID 
    END AS icpc_s47_enquiry_id,
    fcpc.DIM_PERSON_ID,
    fcpp.FACT_CP_PLAN_ID,
    fcpc.FACT_REFERRAL_ID,
    fcpc.TRANSFER_IN_FLAG,
    fcpc.DUE_DTTM,
    fm.ACTUAL_DTTM,
    fcpc.OUTCOME_CP_FLAG,
        (
            -- Manual JSON-like concatenation for icpc_icpc_outcome_json
            ''{'' +
            ''"NFA_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"REFERRAL_TO_OTHER_AGENCY_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"SINGLE_ASSESSMENT_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"PROV_OF_SERVICES_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"CP_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_CP_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"OTHER_OUTCOMES_EXIST_FLAG": "'' + ISNULL(TRY_CAST(fcpc.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '''') + ''", '' +
            ''"TOTAL_NO_OF_OUTCOMES": '' + ISNULL(TRY_CAST(fcpc.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(4)), ''null'') + '', '' +
            ''"COMMENTS": "'' + ISNULL(TRY_CAST(fcpc.OUTCOME_COMMENTS AS NVARCHAR(900)), '''') + ''"'' +
            ''}''
        ) AS icpc_icpc_outcome_json,
    fcpc.ORGANISED_BY_DEPT_ID                                       AS icpc_icpc_team,          -- was fcpc.ORGANISED_BY_DEPT_NAME #DtoI-1762
    fcpc.ORGANISED_BY_USER_STAFF_ID                                 AS icpc_icpc_worker_id      -- was fcpc.ORGANISED_BY_USER_NAME
 
FROM
    HDM.Child_Social.FACT_CP_CONFERENCE AS fcpc
JOIN
    HDM.Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID

WHERE
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = ''CPConference''
AND
    (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fm.ACTUAL_DTTM IS NULL)
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID -- #DtoI-1799
    ) ;

-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT
--     fcpc.FACT_CP_CONFERENCE_ID,
--     fcpc.FACT_MEETING_ID,
--     CASE 
--         WHEN fcpc.FACT_S47_ID IN (''-1'', -1) THEN NULL
--         ELSE fcpc.FACT_S47_ID 
--     END AS icpc_s47_enquiry_id,
--     fcpc.DIM_PERSON_ID,
--     fcpp.FACT_CP_PLAN_ID,
--     fcpc.FACT_REFERRAL_ID,
--     fcpc.TRANSFER_IN_FLAG,
--     fcpc.DUE_DTTM,
--     fm.ACTUAL_DTTM,
--     fcpc.OUTCOME_CP_FLAG,
--     (
--         SELECT
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             ISNULL(fcpc.OUTCOME_NFA_FLAG, '''')                       AS NFA_FLAG,
--             ISNULL(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '''')  AS REFERRAL_TO_OTHER_AGENCY_FLAG,
--             ISNULL(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '''')         AS SINGLE_ASSESSMENT_FLAG,
--             ISNULL(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '''')          AS PROV_OF_SERVICES_FLAG,
--             ISNULL(fcpc.OUTCOME_CP_FLAG, '''')                        AS CP_FLAG,
--             ISNULL(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '''')              AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(fcpc.TOTAL_NO_OF_OUTCOMES, '''')                   AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(fcpc.OUTCOME_COMMENTS, '''')                       AS COMMENTS
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         )                                                           AS icpc_icpc_outcome_json,
--     fcpc.ORGANISED_BY_DEPT_ID                                       AS icpc_icpc_team,          -- was fcpc.ORGANISED_BY_DEPT_NAME #DtoI-1762
--     fcpc.ORGANISED_BY_USER_STAFF_ID                                 AS icpc_icpc_worker_id      -- was fcpc.ORGANISED_BY_USER_NAME
 
-- FROM
--     HDM.Child_Social.FACT_CP_CONFERENCE AS fcpc
-- JOIN
--     HDM.Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
-- LEFT JOIN
--     HDM.Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID

-- WHERE
--     fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = ''CPConference''
-- AND
--     (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fm.ACTUAL_DTTM IS NULL)
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID -- #DtoI-1799
--     ) ;


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_person_id
-- FOREIGN KEY (icpc_person_id) REFERENCES ssd_person(pers_person_id);

-- -- [TESTING] #DtoI-1769 - failing at 160724 RH
-- ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_referral_id
-- FOREIGN KEY (icpc_referral_id) REFERENCES ssd_cin_episodes(cine_referral_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_person_id        ON ssd_initial_cp_conference(icpc_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_s47_enquiry_id   ON ssd_initial_cp_conference(icpc_s47_enquiry_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_referral_id      ON ssd_initial_cp_conference(icpc_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_icpc_date        ON ssd_initial_cp_conference(icpc_icpc_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
