IF OBJECT_ID(N'proc_ssd_person', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_person AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_person
AS
BEGIN
    SET NOCOUNT ON;
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




/* START - Temp Hard drop and recreate due to d2i structure changes  */
IF OBJECT_ID(N''ssd_person'', N''U'') IS NOT NULL
    DROP TABLE ssd_person;

/* END - remove this tmp block once SSD has run once for v1.3.5+!  */

IF OBJECT_ID(''tempdb..#ssd_person'') IS NOT NULL DROP TABLE #ssd_person;

IF OBJECT_ID(''ssd_person'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_person)
        TRUNCATE TABLE ssd_person;
END
ELSE

BEGIN
    CREATE TABLE ssd_person (
        pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
        pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"} 
        pers_upn                NVARCHAR(13),               -- metadata={"item_ref":"PERS006A"} 
        pers_forename           NVARCHAR(100),              -- metadata={"item_ref":"PERS015A"}  
        pers_surname            NVARCHAR(255),              -- metadata={"item_ref":"PERS016A"}  
        pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A", "item_status":"P", "info":"If -additional- status to Gender is held, otherwise duplicate pers_gender"}    
        pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"R", "expected_data":["unknown",NULL,"F","U","M","I"]}       
        pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A", "expected_data":[NULL, tbc]} 
        pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
        pers_single_unique_id   NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
        pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
        pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
        pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
        pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
        pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
        pers_nationality        NVARCHAR(48)               -- metadata={"item_ref":"PERS012A", "expected_data":[NULL, tbc]}   
    );
END

-- CTE to get a no_upn_code 
-- (assumption here is that all codes will be the same/current)
;WITH f903_data_CTE AS (
    SELECT 
        -- get the most recent no_upn_code if exists
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        HDM.Child_Social.fact_903_data
    WHERE
        no_upn_code IS NOT NULL -- sparse data in this field, filter for performance
)
INSERT INTO ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_upn,
    pers_forename,
    pers_surname,
    pers_sex,       -- as used in stat-returns
    pers_gender,    -- Placeholder for those LAs that store sex and gender independently
    pers_ethnicity,
    pers_dob,
    pers_single_unique_id,                               
    pers_upn_unknown,                                  
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality
    
)
SELECT 
    -- TOP 100                              -- Limit returned rows to speed up run-time tests [TESTING|LA DEBUG]
    p.LEGACY_ID,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    LEFT(LTRIM(RTRIM(p.UPN)), 13),           -- Coerce data to expected 13+strip, to avoid downstream fallover     
    p.FORENAME, 
    p.SURNAME,
    p.GENDER_MAIN_CODE AS pers_sex,         -- Sex/Gender as used in stat-returns
    p.GENDER_MAIN_CODE,                     -- Placeholder for those LAs that store sex and gender independently
    p.ETHNICITY_MAIN_CODE,                  -- [REVIEW] LEFT(p.ETHNICITY_MAIN_CODE, 4)
    CASE WHEN (p.DOB_ESTIMATED) = ''N''              
        THEN p.BIRTH_DTTM                   -- Set to BIRTH_DTTM when DOB_ESTIMATED = ''N''
        ELSE NULL                           -- or NULL
    END, 
    NULL AS pers_single_unique_id,           -- Set to NULL as default(dev) / or set to NHS num / or set to Single Unique Identifier(SUI)
    -- COALESCE(f903.NO_UPN_CODE, ''SSD_PH'') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or ''SSD_PH'' as placeholder
    f903.NO_UPN_CODE AS pers_upn_unknown, 
    p.EHM_SEN_FLAG,
    CASE WHEN (p.DOB_ESTIMATED) = ''Y''              
        THEN p.BIRTH_DTTM                   -- Set to BIRTH_DTTM when DOB_ESTIMATED = ''Y''
        ELSE NULL                           -- or NULL
    END, 
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> ''M'' AND  -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = ''CHI'') -- check for child relation only
        THEN ''Y''
        ELSE NULL                           -- No child relation found
    END,
    p.NATNL_CODE                            -- [REVIEW] LEFT(p.NATNL_CODE, 2)    
FROM
    HDM.Child_Social.DIM_PERSON AS p

-- [TESTING] 903 table refresh only in reporting period?
LEFT JOIN (
    -- ??other accessible location for NO_UPN data than 903 table?? -- [TESTING|LA DEBUG]
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

WHERE 
    /* EXCLUSIONS */

    -- p.DIM_PERSON_ID IN (1, 2, 3) AND --  -- hard filter on CMS person ids for LA reduced cohort testing

    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    -- AND YEAR(p.BIRTH_DTTM) != 1900 -- Remove admin records hard-filter -- #DtoI-1814 

    /* INCLUSIONS */
    AND (
        p.IS_CLIENT = ''Y''

        OR (
            -- Contacts in SSD window
            EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_CONTACTS fc
                WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
                  AND fc.CONTACT_DTTM >= @ssd_window_start
                  -- Optional upper bound, if needing a closed window
                  -- AND fc.CONTACT_DTTM < DATEADD(day, 1, @ssd_window_end)
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
                WHERE (fi.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE ''KA%'' --Key Agencies (External)
				     OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL 
                     OR fi.IS_ALLOCATED_CW_FLAG = ''Y'')
				-- AND START_DTTM > ''2009-12-04 00:54:49.947'' -- #DtoI-1830 care leavers who were aged 22-25 and may not have had Allocated Case Worker relationship for years+
				AND DIM_WORKER_ID <> ''-1'' 
                
                AND (fi.END_DTTM IS NULL OR fi.END_DTTM > @ssd_window_start))
            )
        )
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
END');
