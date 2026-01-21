IF OBJECT_ID(N'proc_ssd_cla_episodes', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_cla_episodes AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_cla_episodes
    @src_db sysname = NULL,
    @src_schema sysname = NULL,
    @ssd_timeframe_years int = NULL,
    @ssd_sub1_range_years int = NULL,
    @today_date date = NULL,
    @today_dt datetime = NULL,
    @ssd_window_start date = NULL,
    @ssd_window_end date = NULL,
    @CaseloadLastSept30th date = NULL,
    @CaseloadTimeframeStartDate date = NULL

AS
BEGIN
    SET NOCOUNT ON;
    -- normalise defaults if not provided
    IF @src_db IS NULL SET @src_db = DB_NAME();
    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();
    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;
    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;
    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());
    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);
    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;
    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);
    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE
        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;
    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CLA
-- - HDM.Child_Social.FACT_CASENOTES
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_episodes','U') IS NOT NULL DROP TABLE #ssd_cla_episodes;

IF OBJECT_ID('ssd_cla_episodes','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_episodes)
        TRUNCATE TABLE ssd_cla_episodes;
END

ELSE
BEGIN
    CREATE TABLE ssd_cla_episodes (
        clae_cla_episode_id             nvarchar(48) PRIMARY KEY,
        clae_person_id                  nvarchar(48),
        clae_cla_placement_id           nvarchar(48),
        clae_cla_episode_start_date     datetime,
        clae_cla_episode_start_reason   nvarchar(100),
        clae_cla_primary_need_code      nvarchar(3),
        clae_cla_episode_ceased_date    datetime,
        clae_cla_episode_ceased_reason  nvarchar(255),
        clae_cla_id                     nvarchar(48),
        clae_referral_id                nvarchar(48),
        clae_cla_last_iro_contact_date  datetime,
        clae_entered_care_date          datetime
    );
END

-- filtered source
;WITH FilteredData AS (
    SELECT
        fce.FACT_CARE_EPISODES_ID                 AS clae_cla_episode_id,
        TRY_CAST(fce.DIM_PERSON_ID AS nvarchar(48)) AS clae_person_id,
        fce.FACT_CLA_PLACEMENT_ID                 AS clae_cla_placement_id,
        fce.CARE_START_DATE                       AS clae_cla_episode_start_date,
        fce.CARE_REASON_DESC                      AS clae_cla_episode_start_reason,
        fce.CIN_903_CODE                          AS clae_cla_primary_need_code,
        fce.CARE_END_DATE                         AS clae_cla_episode_ceased_date,
        fce.CARE_REASON_END_DESC                  AS clae_cla_episode_ceased_reason,
        fc.FACT_CLA_ID                            AS clae_cla_id,
        fc.FACT_REFERRAL_ID                       AS clae_referral_id,
        MAX(CASE
                WHEN cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
                THEN cn.EVENT_DTTM
            END)                                  AS clae_cla_last_iro_contact_date,
        fc.START_DTTM                             AS clae_entered_care_date
    FROM HDM.Child_Social.FACT_CARE_EPISODES AS fce
    JOIN HDM.Child_Social.FACT_CLA AS fc
      ON fc.FACT_CLA_ID = fce.FACT_CLA_ID
    LEFT JOIN HDM.Child_Social.FACT_CASENOTES AS cn
      ON cn.DIM_PERSON_ID = fce.DIM_PERSON_ID
    WHERE EXISTS (
              SELECT 1
              FROM ssd_person p
              WHERE TRY_CAST(p.pers_person_id AS int) = fce.DIM_PERSON_ID
          )
      AND (
            fce.CARE_END_DATE >= DATEADD(year, -@ssd_timeframe_years, GETDATE())
            OR fce.CARE_END_DATE IS NULL
          )
    GROUP BY
        fce.FACT_CARE_EPISODES_ID,
        fce.DIM_PERSON_ID,
        fce.FACT_CLA_PLACEMENT_ID,
        fce.CARE_START_DATE,
        fce.CARE_REASON_DESC,
        fce.CIN_903_CODE,
        fce.CARE_END_DATE,
        fce.CARE_REASON_END_DESC,
        fc.FACT_CLA_ID,
        fc.FACT_REFERRAL_ID,
        fc.START_DTTM
)
INSERT INTO ssd_cla_episodes (
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_placement_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need_code,
    clae_cla_episode_ceased_date,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_last_iro_contact_date,
    clae_entered_care_date
)
SELECT
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_placement_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need_code,
    clae_cla_episode_ceased_date,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_last_iro_contact_date,
    clae_entered_care_date
FROM FilteredData;



-- -- META-ELEMENT: {"type": "insert_data"}
-- -- [TESTING]
-- INSERT INTO ssd_cla_episodes (
--     clae_cla_episode_id,
--     clae_person_id,
--     clae_cla_placement_id,
--     clae_cla_episode_start_date,
--     clae_cla_episode_start_reason,
--     clae_cla_primary_need_code,
--     clae_cla_episode_ceased_date,
--     clae_cla_episode_ceased_reason,
--     clae_cla_id,
--     clae_referral_id,
--     clae_cla_last_iro_contact_date,
--     clae_entered_care_date 
-- )
-- SELECT
--     fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
--     fce.FACT_CLA_PLACEMENT_ID               AS clae_cla_placement_id,
--     fce.DIM_PERSON_ID                       AS clae_person_id,
--     fce.CARE_START_DATE                     AS clae_cla_episode_start_date,
--     fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
--     fce.CIN_903_CODE                        AS clae_cla_primary_need_code,
--     fce.CARE_END_DATE                       AS clae_cla_episode_ceased_date,
--     fce.CARE_REASON_END_DESC                AS clae_cla_episode_ceased_reason,
--     fc.FACT_CLA_ID                          AS clae_cla_id,                    
--     fc.FACT_REFERRAL_ID                     AS clae_referral_id,
--     (SELECT MAX(ISNULL(CASE WHEN fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
--         AND cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
--         THEN cn.EVENT_DTTM END, '1900-01-01')))                                                      
--                                             AS clae_cla_last_iro_contact_date,
--     fc.START_DTTM                           AS clae_entered_care_date
-- FROM
--     HDM.Child_Social.FACT_CARE_EPISODES AS fce
-- JOIN
--     HDM.Child_Social.FACT_CLA AS fc ON fce.FACT_CLA_ID = fc.FACT_CLA_ID
-- LEFT JOIN
--     HDM.Child_Social.FACT_CASENOTES cn ON fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
    
-- WHERE EXISTS (
--     SELECT 1
--     FROM ssd_person p
--      WHERE TRY_CAST(p.pers_person_id AS INT) = fce.DIM_PERSON_ID -- #DtoI-1799
-- )
-- -- WHERE
-- --     fce.DIM_PERSON_ID IN (SELECT pers_person_id FROM ssd_person)

-- GROUP BY
--     fce.FACT_CARE_EPISODES_ID,
--     fce.DIM_PERSON_ID,
--     fce.FACT_CLA_PLACEMENT_ID,
--     fce.CARE_START_DATE,
--     fce.CARE_REASON_DESC,
--     fce.CIN_903_CODE,
--     fce.CARE_END_DATE,
--     fce.CARE_REASON_END_DESC,
--     fc.FACT_CLA_ID,                    
--     fc.FACT_REFERRAL_ID,
--     fc.START_DTTM,
--     cn.DIM_PERSON_ID;

-- -- [TESTING]
-- SELECT DISTINCT clae_person_id FROM ssd_cla_episodes WHERE clae_person_id NOT IN (SELECT pers_person_id FROM ssd_person);





-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_to_person 
-- FOREIGN KEY (clae_person_id) REFERENCES ssd_person (pers_person_id);

-- -- [TESTING]
-- ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_cla_placement_id
-- FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_cla_placements (clap_cla_placement_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_person_id ON ssd_cla_episodes(clae_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_episode_start_date ON ssd_cla_episodes(clae_cla_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_episode_ceased_date ON ssd_cla_episodes(clae_cla_episode_ceased_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_referral_id ON ssd_cla_episodes(clae_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_cla_last_iro_contact_date ON ssd_cla_episodes(clae_cla_last_iro_contact_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_cla_placement_id ON ssd_cla_episodes(clae_cla_placement_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
