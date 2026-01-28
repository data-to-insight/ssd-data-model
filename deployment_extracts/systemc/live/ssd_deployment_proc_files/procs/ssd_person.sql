IF OBJECT_ID(N'proc_ssd_person', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_person AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_person
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
-- Description: Person/child details. This the most connected table in the SSD.
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--             Note: Due to part reliance on 903 table, be aware that if 903 not populated pre-ssd run, 
--             this/subsequent queries can return v.low|unexpected row counts.
-- Dependencies:
-- - HDM.Child_Social.DIM_PERSON
-- - HDM.Child_Social.FACT_REFERRALS
-- - HDM.Child_Social.FACT_CONTACTS
-- - HDM.Child_Social.FACT_903_DATA
-- - HDM.Child_Social.FACT_CLA_CARE_LEAVERS
-- - HDM.Child_Social.DIM_CLA_ELIGIBILITY
-- =============================================================================




-- /* START - Temp Hard drop and recreate due to d2i structure changes  */
-- IF OBJECT_ID(N'ssd_person', N'U') IS NOT NULL
--     DROP TABLE ssd_person;
-- GO
-- /* END - remove this tmp block once SSD has run once for v1.3.5+!  */

IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;

IF OBJECT_ID('ssd_person') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_person)
        TRUNCATE TABLE ssd_person;
END
ELSE

BEGIN
    CREATE TABLE ssd_person (
        pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A", "info": "Legacy systems identifier. Common to SystemC"}                  
        pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"} 
        pers_upn                NVARCHAR(13),               -- metadata={"item_ref":"PERS006A"} 
        pers_forename           NVARCHAR(100),              -- metadata={"item_ref":"PERS015A"}  
        pers_surname            NVARCHAR(255),              -- metadata={"item_ref":"PERS016A"}  
        pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A", "item_status":"P", "info":"If -additional- status to Gender is held, as used in stat-returns, otherwise duplicate pers_gender"}    
        pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"R", "expected_data":["unknown",NULL,"F","U","M","I"]}       
        pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A", "expected_data":[NULL, tbc]} 
        pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A", "info": "SSD dat values render as 2024-12-10 00:00:00.000"} 
        pers_single_unique_id   NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
        pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
        pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
        pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
        pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
        pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
        pers_nationality        NVARCHAR(48)               -- metadata={"item_ref":"PERS012A", "expected_data":[NULL, tbc]}   
    );
END

-- CTE to get no_upn_code 
;WITH f903_data_CTE AS (
    SELECT 
        -- get most recent no_upn_code if exists
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        HDM.Child_Social.fact_903_data
    WHERE
        no_upn_code IS NOT NULL -- possible sparse data, filter for performance
)
INSERT INTO ssd_person
SELECT 
    -- TOP 100                                                              -- [TESTING|LA DEBUG]
    p.LEGACY_ID,                            -- pers_legacy_id               -- Common SystemC internal ID 
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- pers_person_id               -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    LEFT(LTRIM(RTRIM(p.UPN)), 13),          -- pers_upn                     -- Coerce data to expected 13+strip, to avoid downstream fallover     
    p.FORENAME,                             -- pers_forename
    p.SURNAME,                              -- pers_surname
    p.GENDER_MAIN_CODE,                     -- pers_sex                     -- Sex/Gender as used in stat-returns
    p.GENDER_MAIN_CODE,                     -- pers_gender                  -- Placeholder for those LAs that store sex and gender independently             
    dlde.NAT_ID,                            -- pers_ethnicity               -- COV change to align with national ID was LEFT(p.ETHNICITY_MAIN_CODE, 4) [REVIEW] 
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM                   -- pers_dob                     -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL                           -- or NULL
    END, 
    NULL AS pers_single_unique_id,           -- pers_single_unique_id       -- Set to NULL as default(dev) / or set to NHS num / or set to Single Unique Identifier(SUI)
    f903.NO_UPN_CODE AS pers_upn_unknown,    -- pers_upn_unknown            -- Source of upn_unknown likely to vary between LAs [REVIEW]
    p.EHM_SEN_FLAG,                          -- pers_send_flag
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM                   -- pers_expected_dob            -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL                           -- or NULL
    END, 
    p.DEATH_DTTM,                           -- pers_death_date
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND                                  -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI')          -- check for child relation only
        THEN 'Y'
        ELSE NULL                                                           -- or no child relation found
    END,                                    -- pers_is_mother
    p.NATNL_CODE                            -- pers_nationality             -- [REVIEW] LEFT(p.NATNL_CODE, 2)    
FROM
    HDM.Child_Social.DIM_PERSON AS p

-- [TESTING] 903 table refresh only in reporting period?
LEFT JOIN (
    -- [REVIEW|LA DEBUG] - accessible location for NO_UPN data other than 903 table?
    SELECT 
        dim_person_id, 
        no_upn_code
    FROM 
        f903_data_CTE
    WHERE 
        rn = 1
) AS f903 
ON 
    p.DIM_PERSON_ID = f903.dim_person_id

LEFT JOIN 
    -- align with national ID
    HDM.Child_Social.DIM_LOOKUP_DFE_ETHNIC dlde
        ON p.ETHNICITY_MAIN_CODE = dlde.MAIN_CODE
WHERE
    /* EXCLUSIONS */

    -- p.DIM_PERSON_ID IN (1, 2, 3)  -- hard filter for tiny cohort LA testing [TESTING|DEBUG]

    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    -- AND p.BIRTH_DTTM < DATEADD(Y, -100, GETDATE()) -- hard-filter possible 1900 yr admin records -- #DtoI-1814

    /* INCLUSIONS */

    -- /* Optional flags (uncomment to enable|disable) */
    AND (
           p.IS_CLIENT = 'Y'        -- Toggle as might not apply to all SystemC LAs [REVIEW]
    --     OR p.IS_FOSTER = 'Y'
    --     OR p.WAS_FOSTER = 'Y'
    --     OR p.IS_ADOPTOR = 'Y'
    --     OR p.WAS_ADOPTOR = 'Y'
    )
    

    AND (
        -- Contacts in SSD window
        EXISTS (
            SELECT 1
            FROM HDM.Child_Social.FACT_CONTACTS fc
            WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND fc.CONTACT_DTTM >= @ssd_window_start
              -- Optional upper bound, if needing a closed window
              AND fc.CONTACT_DTTM < DATEADD(day, 1, @ssd_window_end)
        )

        -- Referrals that touch the SSD window
        OR EXISTS (
            SELECT 1
            FROM HDM.Child_Social.FACT_REFERRALS fr
            WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND (
                     fr.REFRL_START_DTTM >= @ssd_window_start
                  OR fr.REFRL_END_DTTM   >= @ssd_window_start
                  OR fr.REFRL_END_DTTM IS NULL
              )
        )

        -- Care leaver in touch in SSD window
        OR EXISTS (
            SELECT 1
            FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
            WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND fccl.IN_TOUCH_DTTM >= @ssd_window_start
              -- Optional upper bound
              -- AND fccl.IN_TOUCH_DTTM < DATEADD(day, 1, @ssd_window_end)
        )

        -- Eligibility flag
        OR EXISTS (
            SELECT 1
            FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY dce
            WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
        )

        -- Involvements
        OR EXISTS (
            SELECT 1
            FROM HDM.Child_Social.FACT_INVOLVEMENTS fi
            WHERE fi.DIM_PERSON_ID = p.DIM_PERSON_ID

              -- exclude Key Agency (KA%) involvements unless allocated CW
              AND NOT (
                  COALESCE(fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '') LIKE 'KA%'
                  AND COALESCE(fi.IS_ALLOCATED_CW_FLAG, 'N') <> 'Y'
              )

              -- AND fi.START_DTTM > '2009-12-04 00:54:49.947'   -- #DtoI-1830 optional
              AND fi.DIM_WORKER_ID <> '-1'
              AND (fi.END_DTTM IS NULL OR fi.END_DTTM > @ssd_window_start)
        )

        /* --------------------------------------------------------------------
           Potential optional inclusions (comment out by default)
           Reference as filters that also apply to such as DfE EA API cohort

           IMPORTANT: Tables|data might not exist in some LAs
           -------------------------------------------------------------------- */

        -- OR EXISTS (   -- [OPTIONAL] Early Help contacts
        --     SELECT 1
        --     FROM HDM.Child_Social.FACT_EHM_CONTACT ehc
        --     WHERE ehc.DIM_PERSON_ID = p.DIM_PERSON_ID
        --       AND ehc.CONTACT_DTTM >= @ssd_window_start
        --       -- Optional upper bound
        --       -- AND ehc.CONTACT_DTTM < DATEADD(day, 1, @ssd_window_end)
        -- )

        -- OR EXISTS (   -- [OPTIONAL] CAF episodes
        --     SELECT 1
        --     FROM HDM.Child_Social.FACT_CAF_EPISODE caf
        --     WHERE caf.DIM_PERSON_ID = p.DIM_PERSON_ID
        --       AND (
        --              caf.EPISODE_START_DTTM >= @ssd_window_start
        --           OR caf.EPISODE_END_DTTM   >= @ssd_window_start
        --           OR caf.EPISODE_END_DTTM IS NULL
        --       )
        -- )

        -- OR EXISTS (   -- [OPTIONAL] Workspace
        --     SELECT 1
        --     FROM HDM.Child_Social.FACT_WORKSPACE fw
        --     WHERE fw.DIM_PERSON_ID = p.DIM_PERSON_ID
        --       AND (
        --              fw.START_DTTM >= @ssd_window_start
        --           OR fw.END_DTTM   >= @ssd_window_start
        --           OR fw.END_DTTM IS NULL
        --       )
        -- )
    );



-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_person_pers_dob               ON ssd_person(pers_dob);
-- CREATE NONCLUSTERED INDEX IX_ssd_person_pers_common_child_id   ON ssd_person(pers_common_child_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_person_ethnicity_gender       ON ssd_person(pers_ethnicity, pers_gender);








/*SSD Person filter (notes): - ON HOLD/Not included in SSD Ver/Iteration 1*/
--1
-- ehcp request in last 6yrs - HDM.Child_Social.FACT_EHCP_EPISODE.REQUEST_DTTM ; [perhaps not in iteration|version 1]
    -- OR EXISTS (
    --     -- ehcp request in last x@yrs
    --     SELECT 1 FROM HDM.Child_Social.FACT_EHCP_EPISODE fe 
    --     WHERE fe.DIM_PERSON_ID = p.DIM_PERSON_ID
    --     AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    -- )
    
--2 (Uncertainty re access EH)
-- Has eh_referral open in last 6yrs - 

--3 (Uncertainty re access SEN)
-- Has a record in send - HDM.Child_Social.FACT_SEN, DIM_LOOKUP_SEN, DIM_LOOKUP_SEN_TYPE ?

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
