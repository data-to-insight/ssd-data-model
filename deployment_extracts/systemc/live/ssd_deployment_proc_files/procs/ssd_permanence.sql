IF OBJECT_ID(N'proc_ssd_permanence', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_permanence AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_permanence
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
--         DEV: 181223: Assumed that only one permanence order per child. 
--         - In order to handle/reflect the v.rare cases where this has broken down, further work is required.

--         DEV: Some fields need spec checking for datatypes e.g. perm_adopted_by_carer_flag and others

-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_ADOPTION
-- - HDM.Child_Social.FACT_CLA_PLACEMENT
-- - HDM.Child_Social.FACT_LEGAL_STATUS
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CLA
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

IF OBJECT_ID('ssd_permanence','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_permanence)
        TRUNCATE TABLE ssd_permanence;
END

ELSE
BEGIN
    CREATE TABLE ssd_permanence (
        perm_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PERM001A"}
        perm_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"PERM002A"}
        perm_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"PERM022A"}
        perm_adm_decision_date          DATETIME,                   -- metadata={"item_ref":"PERM003A"}
        perm_part_of_sibling_group      NCHAR(1),                   -- metadata={"item_ref":"PERM012A"}
        perm_siblings_placed_together   INT,                        -- metadata={"item_ref":"PERM013A"}
        perm_siblings_placed_apart      INT,                        -- metadata={"item_ref":"PERM014A"}
        perm_ffa_cp_decision_date       DATETIME,                   -- metadata={"item_ref":"PERM004A"}              
        perm_placement_order_date       DATETIME,                   -- metadata={"item_ref":"PERM006A"}
        perm_matched_date               DATETIME,                   -- metadata={"item_ref":"PERM008A"}
        perm_adopter_sex                NVARCHAR(48),               -- metadata={"item_ref":"PERM025A"}
        perm_adopter_legal_status       NVARCHAR(100),              -- metadata={"item_ref":"PERM026A"}
        perm_number_of_adopters         INT,                        -- metadata={"item_ref":"PERM027A"}
        perm_placed_for_adoption_date   DATETIME,                   -- metadata={"item_ref":"PERM007A"}             
        perm_adopted_by_carer_flag      NCHAR(1),                   -- metadata={"item_ref":"PERM021A"}
        perm_placed_foster_carer_date   DATETIME,                   -- metadata={"item_ref":"PERM011A"}
        perm_placed_ffa_cp_date         DATETIME,                   -- metadata={"item_ref":"PERM009A"}
        perm_placement_provider_urn     NVARCHAR(48),               -- metadata={"item_ref":"PERM015A"}  
        perm_decision_reversed_date     DATETIME,                   -- metadata={"item_ref":"PERM010A"}                  
        perm_decision_reversed_reason   NVARCHAR(100),              -- metadata={"item_ref":"PERM016A"}
        perm_permanence_order_date      DATETIME,                   -- metadata={"item_ref":"PERM017A"}              
        perm_permanence_order_type      NVARCHAR(100),              -- metadata={"item_ref":"PERM018A"}        
        perm_adoption_worker_id         NVARCHAR(100)               -- metadata={"item_ref":"PERM023A"}
        
    );
END

;WITH RankedPermanenceData AS (
    -- CTE to rank permanence rows for each person
    -- used to assist in dup filtering on/towards perm_table_id

    SELECT
        CASE 
            WHEN (fa.DIM_PERSON_ID = fce.DIM_PERSON_ID)
            THEN CONCAT(fa.FACT_ADOPTION_ID, fce.FACT_CARE_EPISODES_ID)
            ELSE fce.FACT_CARE_EPISODES_ID 
        END                                               AS perm_table_id,
        p.LEGACY_ID                                       AS perm_person_id,
        fce.FACT_CLA_ID                                   AS perm_cla_id,
        fa.DECISION_DTTM                                  AS perm_adm_decision_date,              
        fa.SIBLING_GROUP                                  AS perm_part_of_sibling_group,
        fa.NUMBER_TOGETHER                                AS perm_siblings_placed_together,
        fa.NUMBER_APART                                   AS perm_siblings_placed_apart,              
        fcpl.FFA_IS_PLAN_DATE                             AS perm_ffa_cp_decision_date,
        fa.PLACEMENT_ORDER_DTTM                           AS perm_placement_order_date,
        fa.MATCHING_DTTM                                  AS perm_matched_date,
        fa.DIM_LOOKUP_ADOPTER_GENDER_CODE                 AS perm_adopter_sex,
        fa.DIM_LOOKUP_ADOPTER_LEGAL_STATUS_CODE           AS perm_adopter_legal_status,
        fa.NO_OF_ADOPTERS                                 AS perm_number_of_adopters,
        CASE 
            WHEN fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3','A4','A5','A6')
            THEN fcpl.START_DTTM 
            ELSE NULL 
        END                                               AS perm_placed_for_adoption_date,
        fa.ADOPTED_BY_CARER_FLAG                          AS perm_adopted_by_carer_flag,
        CAST('1900/01/01' AS DATETIME)                    AS perm_placed_foster_carer_date,         -- [PLACEHOLDER_DATA] [TESTING] 
        fa.FOSTER_TO_ADOPT_DTTM                           AS perm_placed_ffa_cp_date,
        CASE 
            WHEN fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3','A4','A5','A6')
            THEN fce.OFSTED_URN 
            ELSE NULL 
        END                                               AS perm_placement_provider_urn,
        fa.NO_LONGER_PLACED_DTTM                          AS perm_decision_reversed_date,
        fa.DIM_LOOKUP_ADOP_REASON_CEASED_CODE             AS perm_decision_reversed_reason,
        fce.PLACEND                                       AS perm_permanence_order_date,
        CASE
            WHEN fce.CARE_REASON_END_CODE IN ('E1', 'E12', 'E11') THEN 'Adoption'
            WHEN fce.CARE_REASON_END_CODE IN ('E48', 'E44', 'E43', '45', 'E45', 'E47', 'E46') THEN 'Special Guardianship Order'
            WHEN fce.CARE_REASON_END_CODE IN ('45', 'E41') THEN 'Child Arrangements/ Residence Order'
            ELSE NULL
        END                                               AS perm_permanence_order_type,
        fa.ADOPTION_SOCIAL_WORKER_ID                      AS perm_adoption_worker_id,
        ROW_NUMBER() OVER (
            PARTITION BY p.LEGACY_ID                     -- partition on person identifier
            ORDER BY TRY_CAST(RIGHT(CASE 
                                    WHEN (fa.DIM_PERSON_ID = fce.DIM_PERSON_ID)
                                    THEN CONCAT(fa.FACT_ADOPTION_ID, fce.FACT_CARE_EPISODES_ID)
                                    ELSE fce.FACT_CARE_EPISODES_ID 
                                END, 5) AS INT) DESC    -- take last 5 digits, coerce to int so we can sort/order
        )                                                 AS rn -- we only want rn==1
    FROM HDM.Child_Social.FACT_CARE_EPISODES fce

    LEFT JOIN HDM.Child_Social.FACT_ADOPTION AS fa ON fa.DIM_PERSON_ID = fce.DIM_PERSON_ID AND fa.START_DTTM IS NOT NULL
    LEFT JOIN HDM.Child_Social.FACT_CLA AS fc ON fc.FACT_CLA_ID = fce.FACT_CLA_ID -- [TESTING] IS this still requ if fc.START_DTTM not in use here? 
    LEFT JOIN HDM.Child_Social.FACT_CLA_PLACEMENT AS fcpl ON fcpl.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
        AND fcpl.FACT_CLA_PLACEMENT_ID <> '-1'
        AND (fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3', 'A4', 'A5', 'A6') OR fcpl.FFA_IS_PLAN_DATE IS NOT NULL)

    LEFT JOIN HDM.Child_Social.DIM_PERSON p ON fce.DIM_PERSON_ID = p.DIM_PERSON_ID

    WHERE ((fce.PLACEND IS NULL AND fa.START_DTTM IS NOT NULL)
        OR fce.CARE_REASON_END_CODE IN ('E48', 'E1', 'E44', 'E12', 'E11', 'E43', '45', 'E41', 'E45', 'E47', 'E46'))
        AND fce.DIM_PERSON_ID <> '-1'

        -- -- Exclusion block commented for further [TESTING] 
        -- AND EXISTS ( -- ssd records only
        --     SELECT 1
        --     FROM ssd_person p
        --      WHERE TRY_CAST(p.pers_person_id AS INT) = fce.DIM_PERSON_ID -- #DtoI-1799
        -- )

)

INSERT INTO ssd_permanence (
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_adopter_sex,
    perm_adopter_legal_status,
    perm_number_of_adopters,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_foster_carer_date,
    perm_placed_ffa_cp_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker_id
)  


SELECT
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_adopter_sex,
    perm_adopter_legal_status,
    perm_number_of_adopters,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_foster_carer_date,
    perm_placed_ffa_cp_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker_id

FROM RankedPermanenceData
WHERE rn = 1
AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = perm_person_id -- this a NVARCHAR(48) equality link
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_permanence ADD CONSTRAINT FK_ssd_perm_person_id
-- FOREIGN KEY (perm_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_person_id            ON ssd_permanence(perm_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_adm_decision_date    ON ssd_permanence(perm_adm_decision_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_order_date           ON ssd_permanence(perm_permanence_order_date);

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
