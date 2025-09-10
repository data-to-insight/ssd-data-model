/*
*********************************************************************************************************
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

*We strongly recommend that all initial pilot/trials of SSD scripts occur in a development|test environment.*

Script creates labelled persistent(unless set otherwise) tables in your existing|specified database. 

Data tables(with data copied from raw CMS tables) and indexes for the SSD are created, and therefore in some 
cases will need review and support and/or agreement from your IT or Intelligence team. 

The SQL script is non-destructive.
Reset|Clean-up scripts are available on request seperately, these would then be destructive.

Additional notes: 
A version that instead creates _temp|session tables is also available to enable those LA teams restricted to read access 
on the cms db|schema. A _temp script can also be created by performing the following adjustments:
    - Replace all instances of '' with '#'
    - Set @Run_SSD_As_Temporary_Tables = 0 - This turns off such as FK constraint creation

There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results; similarly some test related 
console outputs remain to aid such as run-time problem solving. These [TESTING] blocks can/will be removed. 
********************************************************************************************************** */

-- META-ELEMENT: {"type": "deployment_system"}
-- deployment, cms and db system info

-- META-ELEMENT: {"type": "deployment_status_note"}
/*
**********************************************************************************************************
Dev Object & Item Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [AR]waitingReview,  -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder

Development notes:
Currently in [REVIEW]
- DfE returns expect dd/mm/YYYY formating on dates, SSD Extract initially maintains DATETIME not DATE.
- Extended default field sizes - Some are exagerated e.g. family_id NVARCHAR(48), to ensure cms/la compatibility
- Caseload counts - should these be restricted to SSD timeframe counts(currently this) or full system counts?
- ITEM level metadata using the format/key labels: 
- metadata={
            "item_ref"      :"AAAA000A", 

            -- and where applicable any of the following: 
            "item_status"   :"[B], [D].." As per the above status list, 
            "expected_data" :[csv list of "strings" or nums]
            "info"          : "short string desc"
            }
**********************************************************************************************************
*/
-- META-ELEMENT: {"type": "config_metadata"}
-- Optional notes from la config file 

-- META-ELEMENT: {"type": "dev_set_up"}
GO 
SET NOCOUNT ON;

-- META-ELEMENT: {"type": "ssd_timeframe"}
DECLARE @ssd_timeframe_years INT = 6; -- ssd extract time-frame (YRS)
DECLARE @ssd_sub1_range_years INT = 1;



-- META-ELEMENT: {"type": "dbschema"}
-- Point to DB/TABLE_CATALOG if required (SSD tables created here)
USE HDM; -- 
--USE HDM_Local;                          

-- ALTER USER [ESCC\RobertHa] WITH DEFAULT_SCHEMA = [ssd_development];


-- META-END







/* ********************************************************************************************************** */
/* START SSD main extract */




-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. This the most connected table in the SSD.
-- Author: D2I
-- Version: 1.3
--              1.2: forename and surname added to aid onward data project on api 220125 RH
--             1.1: ssd_flag added for phase 2 non-core filter testing [1,0] 010824 RH
--             1.0: fixes to where filter in-line with existing cincplac reorting 040724 JH
--             0.2: upn _unknown size change in line with DfE to 4 160524 RH
--             0.1: Additional inclusion criteria added to capture care leavers 120324 JH
-- Status: [R]elease
-- Remarks:    
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


SELECT 
    TOP 100                              -- Limit returned rows to speed up run-time tests [TESTING]
    p.LEGACY_ID,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    p.FORENAME, 
    p.SURNAME,
    p.GENDER_MAIN_CODE AS pers_sex,        -- Sex/Gender as used in stat-returns
    p.GENDER_MAIN_CODE,                     -- Placeholder for those LAs that store sex and gender independently
    p.ETHNICITY_MAIN_CODE,
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL 
    END, -- or NULL
    NULL AS pers_common_child_id, -- Set to NULL as default(dev) / or set to NHS num
    -- COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
    p.EHM_SEN_FLAG,
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL 
    END, -- or NULL
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI') -- check for child relation only
        THEN 'Y'
        ELSE NULL -- No child relation found
    END,
    p.NATNL_CODE
FROM
    HDM.Child_Social.DIM_PERSON AS p

-- -- [TESTING][PLACEHOLDER] 903 table refresh only in reporting period?
-- LEFT JOIN (
--     -- no other accessible location for UPN data than 903 table
--     SELECT 
--         dim_person_id, 
--         no_upn_code
--     FROM 
--         f903_data_CTE
--     WHERE 
--         rn = 1
-- ) AS f903 
-- ON 
--     p.DIM_PERSON_ID = f903.dim_person_id

WHERE 
    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    -- AND YEAR(p.BIRTH_DTTM) != 1900 -- #DtoI-1814
    AND (p.IS_CLIENT = 'Y'
        OR (
            EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_CONTACTS fc
                WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
            )
            OR EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_REFERRALS fr
                WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND (
                    fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
                    OR fr.REFRL_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
                    OR fr.REFRL_END_DTTM IS NULL
                )
            )
            OR EXISTS (
                SELECT 1 FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
                WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND fccl.IN_TOUCH_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
            )
            OR EXISTS (
                SELECT 1 FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY dce
                WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
            )
            OR EXISTS (
                SELECT 1 FROM HDM.Child_Social.FACT_INVOLVEMENTS fi
                WHERE (fi.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' --Key Agencies (External)
				OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL OR fi.IS_ALLOCATED_CW_FLAG = 'Y')
				-- AND START_DTTM > '2009-12-04 00:54:49.947' -- #DtoI-1830 care leavers who were aged 22-25 and may not have had Allocated Case Worker relationship for years+.
				AND DIM_WORKER_ID <> '-1' 
                AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE()))
            )
        )
    )
    ;





-- META-CONTAINER: {"type": "table", "name": "ssd_family"}
-- =============================================================================
-- Description: Contains the family connections for each person
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
-- Dependencies: 
-- - HDM.Child_Social.FACT_CONTACTS
-- - ssd_person
-- =============================================================================



SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM HDM.Child_Social.FACT_CONTACTS AS fc

WHERE fc.DIM_PERSON_ID <> -1
;




-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description: Contains full address details for every person 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: Need to verify json obj structure on pre-2014 SQL server instances
--          Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.DIM_PERSON_ADDRESS
-- =============================================================================

-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
SELECT 
    pa.DIM_PERSON_ADDRESS_ID,
    pa.DIM_PERSON_ID, 
    pa.ADDSS_TYPE_CODE,
    pa.START_DTTM,
    pa.END_DTTM,
    CASE 
    -- Some clean-up based on known data
        WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', ''))) THEN '' -- clear pcode of containing all X's
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''                                -- clear pcode of containing nopostcode
        ELSE REPLACE(pa.POSTCODE, ' ', '')                                                              -- remove all spaces for consistency
    END AS CleanedPostcode,
    (
    
    SELECT 
        -- SSD standard 
        -- all keys in structure regardless of data presence
        ISNULL(pa.ROOM_NO, '')    AS ROOM, 
        ISNULL(pa.FLOOR_NO, '')   AS FLOOR, 
        ISNULL(pa.FLAT_NO, '')    AS FLAT, 
        ISNULL(pa.BUILDING, '')   AS BUILDING, 
        ISNULL(pa.HOUSE_NO, '')   AS HOUSE, 
        ISNULL(pa.STREET, '')     AS STREET, 
        ISNULL(pa.TOWN, '')       AS TOWN,
        ISNULL(pa.UPRN, '')       AS UPRN,
        ISNULL(pa.EASTING, '')    AS EASTING,
        ISNULL(pa.NORTHING, '')   AS NORTHING
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS addr_address_json
FROM 
    HDM.Child_Social.DIM_PERSON_ADDRESS AS pa

WHERE pa.DIM_PERSON_ID <> -1;





-- META-CONTAINER: {"type": "table", "name": "ssd_disability"}
-- =============================================================================
-- Description: Contains the Y/N flag for persons with disability
-- Author: D2I
-- Version: 1.0
--             0.1: Removed disability_code replace() into Y/N flag 130324 RH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_DISABILITY
-- =============================================================================



SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id,  -- #TESTING|Debug, is this bringing NULL values through? 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    HDM.Child_Social.FACT_DISABILITY AS fd
    
WHERE fd.DIM_PERSON_ID <> -1;





-- META-CONTAINER: {"type": "table", "name": "ssd_immigration_status"}
-- =============================================================================
-- Description: (UASC)
-- Author: D2I
-- Version: 1.0
--             0.9 rem ims.DIM_LOOKUP_IMMGR_STATUS_DESC rpld with _CODE 270324 JH 
-- Status: [R]elease
-- Remarks: Replaced IMMIGRATION_STATUS_CODE with IMMIGRATION_STATUS_DESC and
--             increased field size to 100
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_IMMIGRATION_STATUS
-- =============================================================================


SELECT
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE ims.DIM_PERSON_ID <> -1;


-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.4
--             1.3 cine_referral_team now DIM_DEPARTMENT_ID #DtoI-1762 290724 RH
--             1.2: cine_referral_outcome_json size 500 to 4000 to include COMMENTS 160724 RH
--             1.2: fr.OUTCOME_COMMENTS added cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.2: fr.TOTAL_NUMBER_OF_OUTCOMES added cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.2: rem NFA_OUTCOME from cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             0.3 primary _need suffix of _code added #DtoI-1738 2105 RH
--             0.2: primary _need type/size adjustment from revised spec 160524 RH
--             0.1: contact_source_desc added, _source now populated with ID 141223 RH
-- Status: [R]elease
-- Remarks: Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - @ssd_timeframe_years
-- - HDM.Child_Social.FACT_REFERRALS
-- =============================================================================


-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
SELECT
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
    fr.DIM_LOOKUP_CONT_SORC_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 1
    (
        SELECT
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
            ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')   AS SINGLE_ASSESSMENT_FLAG,
            -- ISNULL(fr.OUTCOME_NFA_FLAG, '')                 AS NFA_FLAG,
            ISNULL(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fr.OUTCOME_CLA_REQUEST_FLAG, '')         AS CLA_REQUEST_FLAG,
            ISNULL(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS NON_AGENCY_ADOPTION_FLAG,
            ISNULL(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '')   AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '')      AS CP_TRANSFER_IN_FLAG,
            ISNULL(fr.OUTCOME_CP_CONFERENCE_FLAG, '')       AS CP_CONFERENCE_FLAG,
            ISNULL(fr.OUTCOME_CARE_LEAVER_FLAG, '')         AS CARE_LEAVER_FLAG,
            ISNULL(fr.OTHER_OUTCOMES_EXIST_FLAG, '')        AS OTHER_OUTCOMES_EXIST_FLAG,
            CASE 
                WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
                ELSE fr.TOTAL_NO_OF_OUTCOMES 
            END                                             AS NUMBER_OF_OUTCOMES,
            ISNULL(fr.OUTCOME_COMMENTS, '')                 AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
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
;

    



-- META-END

-- META-CONTAINER: {"type": "table", "name": "ssd_mother"}
-- =============================================================================
-- Description: Contains parent-child relations between mother-child 
-- Author: D2I
-- Version: 1.1:
--             1.0: Add ssd_cin_episodes filter towards #DtoI-1806 010824 RH
--             0.2: updated to exclude relationships with an end date 280224 JH
-- Status: [R]elease
-- Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_PERSON_RELATION
-- - Gender codes are populated/stored as single char M|F|... 
-- =============================================================================


SELECT
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
 
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr
JOIN
    HDM.Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> 'M' 
    AND
    fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND
    fpr.END_DTTM IS NULL;









-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.4
--             1.3 cine_referral_team now DIM_DEPARTMENT_ID #DtoI-1762 290724 RH
--             1.2: cine_referral_outcome_json size 500 to 4000 to include COMMENTS 160724 RH
--             1.2: fr.OUTCOME_COMMENTS added cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.2: fr.TOTAL_NUMBER_OF_OUTCOMES added cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.2: rem NFA_OUTCOME from cine_referral_outcome_json #DtoI-1796 160724 RH
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             0.3 primary _need suffix of _code added #DtoI-1738 2105 RH
--             0.2: primary _need type/size adjustment from revised spec 160524 RH
--             0.1: contact_source_desc added, _source now populated with ID 141223 RH
-- Status: [R]elease
-- Remarks: Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - @ssd_timeframe_years
-- - HDM.Child_Social.FACT_REFERRALS
-- =============================================================================



-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
SELECT
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
    fr.DIM_LOOKUP_CONT_SORC_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 1
    (
        SELECT
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
            ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')   AS SINGLE_ASSESSMENT_FLAG,
            -- ISNULL(fr.OUTCOME_NFA_FLAG, '')                 AS NFA_FLAG,
            ISNULL(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fr.OUTCOME_CLA_REQUEST_FLAG, '')         AS CLA_REQUEST_FLAG,
            ISNULL(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS NON_AGENCY_ADOPTION_FLAG,
            ISNULL(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '')   AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '')      AS CP_TRANSFER_IN_FLAG,
            ISNULL(fr.OUTCOME_CP_CONFERENCE_FLAG, '')       AS CP_CONFERENCE_FLAG,
            ISNULL(fr.OUTCOME_CARE_LEAVER_FLAG, '')         AS CARE_LEAVER_FLAG,
            ISNULL(fr.OTHER_OUTCOMES_EXIST_FLAG, '')        AS OTHER_OUTCOMES_EXIST_FLAG,
            CASE 
                WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
                ELSE fr.TOTAL_NO_OF_OUTCOMES 
            END                                             AS NUMBER_OF_OUTCOMES,
            ISNULL(fr.OUTCOME_COMMENTS, '')                 AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
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
;





-- META-CONTAINER: {"type": "table", "name": "ssd_mother"}
-- =============================================================================
-- Description: Contains parent-child relations between mother-child 
-- Author: D2I
-- Version: 1.1:
--             1.0: Add ssd_cin_episodes filter towards #DtoI-1806 010824 RH
--             0.2: updated to exclude relationships with an end date 280224 JH
-- Status: [R]elease
-- Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_PERSON_RELATION
-- - Gender codes are populated/stored as single char M|F|... 
-- =============================================================================



SELECT
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
 
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr
JOIN
    HDM.Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> 'M' 
    AND
    fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND
    fpr.END_DTTM IS NULL
;








-- META-CONTAINER: {"type": "table", "name": "ssd_legal_status"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_LEGAL_STATUS
-- =============================================================================

SELECT
    fls.FACT_LEGAL_STATUS_ID,
    fls.DIM_PERSON_ID,
    fls.DIM_LOOKUP_LGL_STATUS_DESC,
    fls.START_DTTM,
    fls.END_DTTM
FROM
    HDM.Child_Social.FACT_LEGAL_STATUS AS fls

WHERE 
    (fls.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fls.END_DTTM IS NULL)

;




-- META-CONTAINER: {"type": "table", "name": "ssd_contacts"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1
--             1.0: cont_contact_outcome_json size 500 to 4000 to include COMMENTS 160724 RH
--             1.0: fc.TOTAL_NO_OF_OUTCOMES added to cont_contact_outcome_json #DtoI-1796 160724 RH 
--             1.0: fc.OUTCOME_COMMENTS added to cont_contact_outcome_json #DtoI-1796 160724 RH
--             0.2: cont_contact_source_code field name edit 260124 RH
--             0.1: cont_contact_source_desc added RH
-- Status: [R]elease
-- Remarks:Inclusion in contacts might differ between LAs. 
--         Baseline definition:
--         Contains safeguarding and referral to early help data.
--         Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CONTACTS
-- =============================================================================


-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 3
    (   -- Create JSON string for outcomes
        SELECT 
            -- SSD standard 
            -- all keys in structure regardless of data presence
            ISNULL(fc.OUTCOME_NEW_REFERRAL_FLAG, '')         AS NEW_REFERRAL_FLAG,
            ISNULL(fc.OUTCOME_EXISTING_REFERRAL_FLAG, '')    AS EXISTING_REFERRAL_FLAG,
            ISNULL(fc.OUTCOME_CP_ENQUIRY_FLAG, '')           AS CP_ENQUIRY_FLAG,
            ISNULL(fc.OUTCOME_NFA_FLAG, '')                  AS NFA_FLAG,
            ISNULL(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '')  AS NON_AGENCY_ADOPTION_FLAG,
            ISNULL(fc.OUTCOME_PRIVATE_FOSTERING_FLAG, '')    AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fc.OUTCOME_ADVICE_FLAG, '')               AS ADVICE_FLAG,
            ISNULL(fc.OUTCOME_MISSING_FLAG, '')              AS MISSING_FLAG,
            ISNULL(fc.OUTCOME_OLA_CP_FLAG, '')               AS OLA_CP_FLAG,
            ISNULL(fc.OTHER_OUTCOMES_EXIST_FLAG, '')         AS OTHER_OUTCOMES_EXIST_FLAG,
            CASE 
                WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
                ELSE fc.TOTAL_NO_OF_OUTCOMES 
            END                                              AS NUMBER_OF_OUTCOMES,
            ISNULL(fc.OUTCOME_COMMENTS, '')                  AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS cont_contact_outcome_json
FROM 
    HDM.Child_Social.FACT_CONTACTS AS fc

WHERE
    (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
    AND fc.DIM_PERSON_ID <> -1
;



-- META-CONTAINER: {"type": "table", "name": "ssd_early_help_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CAF_EPISODE
-- =============================================================================

 
SELECT
    cafe.FACT_CAF_EPISODE_ID,
    cafe.DIM_PERSON_ID,
    cafe.EPISODE_START_DTTM,
    cafe.EPISODE_END_DTTM,
    cafe.START_REASON,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE,
    'SSD_PH'                             
FROM
    HDM.Child_Social.FACT_CAF_EPISODE AS cafe
 
WHERE 
    (cafe.EPISODE_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cafe.EPISODE_END_DTTM IS NULL)

;



-- META-CONTAINER: {"type": "table", "name": "ssd_cin_assessments"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.4 
--             1.3 COMPLETED_BY_USER_STAFF_ID swap to COMPLETED_BY_USER_ID #DtoI-1823 060924 RH
--             1.2 replace -1 vals _team_id and _worker_id with NULL #DtoI-1824 050924 RH
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.2: cina_assessment_child_seen type change from nvarchar 100524 RH
--             0.1: fa.COMPLETED_BY_USER_NAME replaces fa.COMPLETED_BY_USER_STAFF_ID 080524
-- Status: [R]elease
-- Remarks: Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================


WITH FormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER,
        ffa.DIM_ASSESSMENT_TEMPLATE_QUESTION_ID_DESC
    FROM HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
    WHERE ffa.ANSWER_NO IN ('seenYN', 'FormEndDate')
),
AggregatedFormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        MAX(CASE WHEN ffa.ANSWER_NO = 'seenYN'      THEN ffa.ANSWER END)                         AS seenYN,
        MAX(CASE WHEN ffa.ANSWER_NO = 'FormEndDate' THEN TRY_CAST(ffa.ANSWER AS datetime) END)   AS AssessmentAuthorisedDate
    FROM FormAnswers AS ffa
    GROUP BY ffa.FACT_FORM_ID
)
SELECT
    fa.FACT_SINGLE_ASSESSMENT_ID,
    fa.DIM_PERSON_ID,
    fa.FACT_REFERRAL_ID,
    fa.START_DTTM,
    CASE
        WHEN UPPER(LTRIM(RTRIM(afa.seenYN))) IN ('YES', 'Y') THEN 'Y'
        WHEN UPPER(LTRIM(RTRIM(afa.seenYN))) IN ('NO',  'N') THEN 'N'
        ELSE NULL
    END AS seenYN,
    afa.AssessmentAuthorisedDate,
    (
        SELECT
            ISNULL(fa.OUTCOME_NFA_FLAG, '')                       AS NFA_FLAG,
            ISNULL(fa.OUTCOME_NFA_S47_END_FLAG, '')               AS NFA_S47_END_FLAG,
            ISNULL(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '')       AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fa.OUTCOME_CLA_REQUEST_FLAG, '')               AS CLA_REQUEST_FLAG,
            ISNULL(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')         AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fa.OUTCOME_LEGAL_ACTION_FLAG, '')              AS LEGAL_ACTION_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')          AS PROV_OF_SERVICES_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')           AS PROV_OF_SB_CARE_FLAG,
            ISNULL(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '')     AS SPECIALIST_ASSESSMENT_FLAG,
            ISNULL(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')  AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')             AS OTHER_ACTIONS_FLAG,
            ISNULL(fa.OTHER_OUTCOMES_EXIST_FLAG, '')              AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fa.TOTAL_NO_OF_OUTCOMES, '')                   AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fa.OUTCOME_COMMENTS, '')                       AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cina_assessment_outcome_json,
    fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
    NULLIF(fa.COMPLETED_BY_DEPT_ID,  -1)                        AS cina_assessment_team,
    NULLIF(fa.COMPLETED_BY_USER_ID,  -1)                        AS cina_assessment_worker_id
FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fa
LEFT JOIN AggregatedFormAnswers AS afa
    ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X', 'D')
  AND (
        afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
        OR afa.AssessmentAuthorisedDate IS NULL
      )

;


-- META-CONTAINER: {"type": "table", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.3
--             1.2 Handling added for potential empty list into json WHEN LEN(Concat_Result)
--             1.1: ensure only factors with associated cina_assessment_id #DtoI-1769 090724 RH
--             1.0: New alternative structure for assessment_factors_json 250624 RH
-- Status: [R]elease
-- Remarks: This object referrences some large source tables- Instances of 45m+. 
-- Dependencies: 
-- - #ssd_TMP_PRE_assessment_factors (as staged pre-processing)
-- - ssd_cin_assessments
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================


-- Create TMP structure with filtered answers
SELECT 
    ffa.FACT_FORM_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
INTO #ssd_TMP_PRE_assessment_factors
FROM 
    HDM.Child_Social.FACT_FORM_ANSWERS ffa
WHERE 
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC = 'FAMILY ASSESSMENT'
    AND ffa.ANSWER_NO IN (  '1A', '1B', '1C'
                            ,'2A', '2B', '2C', '3A', '3B', '3C'
                            ,'4A', '4B', '4C'
                            ,'5A', '5B', '5C'
                            ,'6A', '6B', '6C'
                            ,'7A'
                            ,'8B', '8C', '8D', '8E', '8F'
                            ,'9A', '10A', '11A','12A', '13A', '14A', '15A', '16A', '17A'
                            ,'18A', '18B', '18C'
                            ,'19A', '19B', '19C'
                            ,'20', '21'
                            ,'22A', '23A', '24A')
    -- filters:                        
    AND LOWER(ffa.ANSWER) = 'yes'   -- expected [Yes/No/NULL], adds redundancy into resultant field but allows later expansion
    AND ffa.FACT_FORM_ID <> -1;     -- possible admin data present


-- -- Opt 0: Alternative backwards compatible, without use of string_agg, #LEGACY-PRE2016
-- -- Opt 0: filter and store results in tmp table
-- SELECT 
--     ffa.FACT_FORM_ID,
--     ffa.ANSWER_NO,
--     ffa.ANSWER
-- INTO #ssd_TMP_PRE_assessment_factors
-- FROM 
--     HDM.Child_Social.FACT_FORM_ANSWERS ffa
-- WHERE 
--     ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC = 'FAMILY ASSESSMENT'
--     AND ffa.ANSWER_NO IN ('1A', '1B', '1C'
--                             ,'2A', '2B', '2C', '3A', '3B', '3C'
--                             ,'4A', '4B', '4C'
--                             ,'5A', '5B', '5C'
--                             ,'6A', '6B', '6C'
--                             ,'7A'
--                             ,'8B', '8C', '8D', '8E', '8F'
--                             ,'9A', '10A', '11A','12A', '13A', '14A', '15A', '16A', '17A'
--                             ,'18A', '18B', '18C'
--                             ,'19A', '19B', '19C'
--                             ,'20', '21'
--                             ,'22A', '23A', '24A')
--     AND LOWER(ffa.ANSWER) = 'yes'
--     AND ffa.FACT_FORM_ID <> -1;




-- -- Opt1: (alternative implementation for backward compatibility but still uses STRING_AGG)
-- -- create field structure of flattened Key only json-like array structure 
-- -- ["1A","2B","3A", ...]           
-- SELECT 
--     fsa.EXTERNAL_ID AS cinf_table_id,
--     fsa.FACT_FORM_ID AS cinf_assessment_id,
--     (
--         SELECT 
--             -- SSD standard (modified)
--             -- This field differs from main standard _json structure in that because the data is pre-filtered
--             -- and extract method (Opt1) neccessitates a non-standard format within a forward-compatible structure

--         -- Concat ANSWER_NO values into JSON array structure ["1A","2B","3A", ...], wrap in [ ]
--             '[' + STRING_AGG('"' + tmp_af.ANSWER_NO + '"', ', ') + ']' 
--         FROM 
--             #ssd_TMP_PRE_assessment_factors tmp_af
--         WHERE 
--             tmp_af.FACT_FORM_ID = fsa.FACT_FORM_ID
--     ) AS cinf_assessment_factors_json
-- FROM 
--     HDM.Child_Social.FACT_SINGLE_ASSESSMENT fsa
-- WHERE 
--     fsa.EXTERNAL_ID <> -1
--     ;


-- Opt2: (commented implementation ready for forward compatibility)
-- create field structure of flattened Key-Value pair json structure 
-- {"1A": "Yes","2B": "No","3A": "Yes", ...}           
SELECT 
    fsa.EXTERNAL_ID AS cinf_table_id,
    fsa.FACT_FORM_ID AS cinf_assessment_id,
    (
        SELECT 
            -- create flattened Key-Value pair json structure {"1A": "Yes","2B": "No","3A": "Yes", ...}
            '{' + STRING_AGG('"' + tmp_af.ANSWER_NO + '": "' + tmp_af.ANSWER + '"', ', ') + '}' 
        FROM 
            #ssd_TMP_PRE_assessment_factors tmp_af
        WHERE 
            tmp_af.FACT_FORM_ID = fsa.FACT_FORM_ID
    ) AS cinf_assessment_factors_json
FROM 
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fsa
WHERE 
    fsa.EXTERNAL_ID <> -1;







-- META-CONTAINER: {"type": "table", "name": "ssd_cin_plans"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.1: Update fix returning new row for each revision of the plan JH 070224
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_CARE_PLAN_SUMMARY
-- =============================================================================


SELECT
    cps.FACT_CARE_PLAN_SUMMARY_ID      AS cinp_cin_plan_id,
    cps.FACT_REFERRAL_ID               AS cinp_referral_id,
    cps.DIM_PERSON_ID                  AS cinp_person_id,
    cps.START_DTTM                     AS cinp_cin_plan_start_date,
    cps.END_DTTM                       AS cinp_cin_plan_end_date,
 
    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
                THEN fp.DIM_PLAN_COORD_DEPT_ID END, '')))                                   -- was fp.DIM_PLAN_COORD_DEPT_ID_DESC
                                            AS cinp_cin_plan_team,

    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
                THEN fp.DIM_PLAN_COORD_ID END, '')))                                        -- was fp.DIM_PLAN_COORD_ID_DESC
                                            AS cinp_cin_plan_worker_id

FROM HDM.Child_Social.FACT_CARE_PLAN_SUMMARY cps  
 
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS fp ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
 
WHERE DIM_LOOKUP_PLAN_TYPE_CODE = 'FP' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
 
AND
    (cps.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cps.END_DTTM IS NULL)

 
GROUP BY
    cps.FACT_CARE_PLAN_SUMMARY_ID,
    cps.FACT_REFERRAL_ID,
    cps.DIM_PERSON_ID,
    cps.START_DTTM,
    cps.END_DTTM
    ;




-- META-CONTAINER: {"type": "table", "name": "ssd_cin_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks:    Source table can be very large! Avoid any unfiltered queries.
--             Notes: Does this need to be filtered by only visits in their current Referral episode?
--                     however for some this ==2 weeks, others==~17 years
--                 --> when run for records in ssd_person c.64k records 29s runtime
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_CASENOTES
-- =============================================================================


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
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO',
    'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID')

AND
    (cn.EVENT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cn.EVENT_DTTM IS NULL)
;
 



-- META-CONTAINER: {"type": "table", "name": "ssd_s47_enquiry"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
-- Status: [R]elease
-- Remarks: Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_S47
-- - HDM.Child_Social.FACT_CP_CONFERENCE
-- =============================================================================


-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
SELECT 
    s47.FACT_S47_ID,
    s47.FACT_REFERRAL_ID,
    s47.DIM_PERSON_ID,
    s47.START_DTTM,
    s47.END_DTTM,
    s47.OUTCOME_NFA_FLAG,
    (
        SELECT 
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
            ISNULL(s47.OUTCOME_NFA_FLAG, '')                   AS NFA_FLAG,
            ISNULL(s47.OUTCOME_LEGAL_ACTION_FLAG, '')          AS LEGAL_ACTION_FLAG,
            ISNULL(s47.OUTCOME_PROV_OF_SERVICES_FLAG, '')      AS PROV_OF_SERVICES_FLAG,
            ISNULL(s47.OUTCOME_PROV_OF_SB_CARE_FLAG, '')       AS PROV_OF_SB_CARE_FLAG,
            ISNULL(s47.OUTCOME_CP_CONFERENCE_FLAG, '')         AS CP_CONFERENCE_FLAG,
            ISNULL(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG, '')   AS NFA_CONTINUE_SINGLE_FLAG,
            ISNULL(s47.OUTCOME_MONITOR_FLAG, '')               AS MONITOR_FLAG,
            ISNULL(s47.OTHER_OUTCOMES_EXIST_FLAG, '')          AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(s47.TOTAL_NO_OF_OUTCOMES, '')               AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(s47.OUTCOME_COMMENTS, '')                   AS OUTCOME_COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )                                                      AS s47e_s47_outcome_json,
    s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
    s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker_id

FROM 
    HDM.Child_Social.FACT_S47 AS s47

WHERE
    (s47.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR s47.END_DTTM IS NULL)
;





-- META-CONTAINER: {"type": "table", "name": "ssd_initial_cp_conference"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             0.3 Updated source of CP_PLAN_ID 100424 JH
--             0.2 Updated the worker fields 020424 JH
--             0.1 Re-instated the worker details 010224 JH
-- Status: [R]elease
-- Remarks:
-- Dependencies:
-- - HDM.Child_Social.FACT_CP_CONFERENCE
-- - HDM.Child_Social.FACT_MEETINGS
-- - HDM.Child_Social.FACT_CP_PLAN
-- =============================================================================

-- version for SQL compatible versions <2016
-- See below for #LEGACY-PRE2016
SELECT
    fcpc.FACT_CP_CONFERENCE_ID,
    fcpc.FACT_MEETING_ID,
    CASE 
        WHEN fcpc.FACT_S47_ID IN ('-1', -1) THEN NULL
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
        SELECT
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
            ISNULL(fcpc.OUTCOME_NFA_FLAG, '')                       AS NFA_FLAG,
            ISNULL(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')  AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')         AS SINGLE_ASSESSMENT_FLAG,
            ISNULL(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '')          AS PROV_OF_SERVICES_FLAG,
            ISNULL(fcpc.OUTCOME_CP_FLAG, '')                        AS CP_FLAG,
            ISNULL(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '')              AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fcpc.TOTAL_NO_OF_OUTCOMES, '')                   AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fcpc.OUTCOME_COMMENTS, '')                       AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )                                                           AS icpc_icpc_outcome_json,
    fcpc.ORGANISED_BY_DEPT_ID                                       AS icpc_icpc_team,          -- was fcpc.ORGANISED_BY_DEPT_NAME #DtoI-1762
    fcpc.ORGANISED_BY_USER_STAFF_ID                                 AS icpc_icpc_worker_id      -- was fcpc.ORGANISED_BY_USER_NAME
 
FROM
    HDM.Child_Social.FACT_CP_CONFERENCE AS fcpc
JOIN
    HDM.Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID

WHERE
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'
AND
    (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fm.ACTUAL_DTTM IS NULL)
 ;







-- META-CONTAINER: {"type": "table", "name": "ssd_cp_plans"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.1:
--             1.0: #DtoI-1809 fix on cppl_referral_id/cppl_icpc_id 010824 RH
--             0.4: cppl_cp_plan_ola type change from nvarchar 100524 RH
--             0.3: added IS_OLA field to identify OLA temporary plans
--             which need to be excluded from statutory returns 090224 JCH
--             0.2: removed depreciated team/worker id fields RH
-- Status: [R]elease
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - ssd_initial_cp_conference
-- - HDM.Child_Social.FACT_CP_PLAN
-- =============================================================================


SELECT
    cpp.FACT_CP_PLAN_ID                 AS cppl_cp_plan_id,
    CASE 
        WHEN cpp.FACT_REFERRAL_ID = -1 THEN NULL
        ELSE cpp.FACT_REFERRAL_ID
    END                                 AS cppl_referral_id,
    CASE 
        WHEN cpp.FACT_INITIAL_CP_CONFERENCE_ID = -1 THEN NULL
        ELSE cpp.FACT_INITIAL_CP_CONFERENCE_ID
    END                                 AS cppl_icpc_id,
    cpp.DIM_PERSON_ID                   AS cppl_person_id,
    cpp.START_DTTM                      AS cppl_cp_plan_start_date,
    cpp.END_DTTM                        AS cppl_cp_plan_end_date,
    cpp.IS_OLA                          AS cppl_cp_plan_ola,
    cpp.INIT_CATEGORY_DESC              AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC                AS cppl_cp_plan_latest_category
 
FROM
    HDM.Child_Social.FACT_CP_PLAN cpp
 
WHERE
    (cpp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cpp.END_DTTM IS NULL)

;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cp_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.1:
--             1.0: prev v1.2.0 - #DtoI-1715 fix on PK violation 010824 RH
--             0.3: (cppv casenote date) removed 070524 RH
--             0.2: cppv_person_id added, where claus removed 'STVCPCOVID' 130224 JH
-- Status: [R]elease
-- Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
--          using casenote ID as PK and linking to CP Visit where available.
--          Will have to use Person ID to link object to Person table
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_CASENOTES
-- - HDM.Child_Social.FACT_CP_VISIT
-- =============================================================================

-- CTE Ensure unique cases only, most recent has priority-- #DtoI-1715 

    SELECT
        cn.FACT_CASENOTE_ID     AS cppv_cp_visit_id,  
        p.DIM_PERSON_ID         AS cppv_person_id,            
        cpv.FACT_CP_PLAN_ID     AS cppv_cp_plan_id,  
        cn.EVENT_DTTM           AS cppv_cp_visit_date,
        cn.SEEN_FLAG            AS cppv_cp_visit_seen,
        cn.SEEN_ALONE_FLAG      AS cppv_cp_visit_seen_alone,
        cn.SEEN_BEDROOM_FLAG    AS cppv_cp_visit_bedroom,
        ROW_NUMBER() OVER (
            PARTITION BY cn.FACT_CASENOTE_ID 
            ORDER BY cn.EVENT_DTTM DESC
        ) AS rn
    FROM
        HDM.Child_Social.FACT_CASENOTES AS cn
    LEFT JOIN
        HDM.Child_Social.FACT_CP_VISIT AS cpv ON cn.FACT_CASENOTE_ID = cpv.FACT_CASENOTE_ID
    LEFT JOIN
        HDM.Child_Social.DIM_PERSON p ON cn.DIM_PERSON_ID = p.DIM_PERSON_ID
    WHERE
        cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC') -- Ref. ( 'STVC','STVCPCOVID')
        AND (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
        OR cn.EVENT_DTTM IS NULL)
;






-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cp_reviews"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
--             0.1: Resolved issue with linking to Quoracy information 130224 JH
-- Status: [R]elease
-- Remarks:    cppr_cp_review_participation - ON HOLD/Not included in SSD Ver/Iteration 1
--             Resolved issue with linking to Quoracy information. Added fm.FACT_MEETING_ID
--             so users can identify conferences including multiple children. Reviews held
--             pre-LCS implementation don't have a CP_PLAN_ID recorded so have added
--             cpr.DIM_PERSON_ID for linking reviews to the ssd_cp_plans object.
--             Re-named cppr_cp_review_outcome_continue_cp for clarity.
-- Dependencies:
-- - ssd_person
-- - ssd_cp_plans
-- - HDM.Child_Social.FACT_CP_REVIEW
-- - HDM.Child_Social.FACT_MEETINGS
-- - HDM.Child_Social.FACT_MEETING_SUBJECTS
-- - HDM.Child_Social.FACT_FORM_ANSWERS [Participation info - ON HOLD/Not included in SSD Ver/Iteration 1]
-- =============================================================================


SELECT
    cpr.FACT_CP_REVIEW_ID                       AS cppr_cp_review_id ,
    cpr.FACT_CP_PLAN_ID                         AS cppr_cp_plan_id,
    cpr.DIM_PERSON_ID                           AS cppr_person_id,
    cpr.DUE_DTTM                                AS cppr_cp_review_due,
    cpr.MEETING_DTTM                            AS cppr_cp_review_date,
    fm.FACT_MEETING_ID                          AS cppr_cp_review_meeting_id,
    cpr.OUTCOME_CONTINUE_CP_FLAG                AS cppr_cp_review_outcome_continue_cp,
    (CASE WHEN ffa.ANSWER_NO = 'WasConf'
        AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
        THEN ffa.ANSWER END)                    AS cppr_cp_review_quorate,    
    'SSD_PH'                                    AS cppr_cp_review_participation
 
FROM
    HDM.Child_Social.FACT_CP_REVIEW as cpr
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm               ON cpr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms      ON cpr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND cpr.DIM_PERSON_ID = fms.DIM_PERSON_ID
 
LEFT JOIN    
    HDM.Child_Social.FACT_FORM_ANSWERS ffa          ON fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.ANSWER_NO = 'WasConf'
    AND fms.FACT_OUTCM_FORM_ID IS NOT NULL
    AND fms.FACT_OUTCM_FORM_ID <> '-1'
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON cpr.DIM_PERSON_ID = p.DIM_PERSON_ID

WHERE
    (cpr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cpr.MEETING_DTTM IS NULL)

GROUP BY cpr.FACT_CP_REVIEW_ID,
    cpr.FACT_CP_PLAN_ID,
    cpr.DIM_PERSON_ID,
    cpr.DUE_DTTM,
    cpr.MEETING_DTTM,
    fm.FACT_MEETING_ID,
    cpr.OUTCOME_CONTINUE_CP_FLAG,
    fms.FACT_OUTCM_FORM_ID,
    ffa.ANSWER_NO,
    ffa.FACT_FORM_ID,
    ffa.ANSWER;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1 clae_cla_episode_ceased _ date suffix add 310125 RH
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.2: primary _need type/size adjustment from revised spec 160524 RH
--             0.1: cla_placement_id added as part of cla_placements review RH 060324
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_involvements
-- - ssd_person
-- - HDM.Child_Social.FACT_CLA
-- - HDM.Child_Social.FACT_REFERRALS
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CASENOTES
-- =============================================================================


-- CTE to filter records
-- approach taken over the [TESTING] version below as (SQL server)execution plan
-- potentially affecting how the EXISTS filter against ssd_person is applied
WITH FilteredData AS (
    SELECT
        fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
        fce.FACT_CLA_PLACEMENT_ID               AS clae_cla_placement_id,
        TRY_CAST(fce.DIM_PERSON_ID AS NVARCHAR(48)) AS clae_person_id,
        fce.CARE_START_DATE                     AS clae_cla_episode_start_date,
        fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
        fce.CIN_903_CODE                        AS clae_cla_primary_need_code,
        fce.CARE_END_DATE                       AS clae_cla_episode_ceased,
        fce.CARE_REASON_END_DESC                AS clae_cla_episode_ceased_reason,
        fc.FACT_CLA_ID                          AS clae_cla_id,                    
        fc.FACT_REFERRAL_ID                     AS clae_referral_id,
        (SELECT MAX(ISNULL(CASE WHEN fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
            AND cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
            THEN cn.EVENT_DTTM END, '1900-01-01')))                                                      
                                                AS clae_cla_last_iro_contact_date,
        fc.START_DTTM                           AS clae_entered_care_date
    FROM
        HDM.Child_Social.FACT_CARE_EPISODES AS fce

    JOIN
        HDM.Child_Social.FACT_CLA AS fc ON fce.FACT_CLA_ID = fc.FACT_CLA_ID
    LEFT JOIN
        HDM.Child_Social.FACT_CASENOTES cn ON fce.DIM_PERSON_ID = cn.DIM_PERSON_ID

    WHERE
        (fce.CARE_END_DATE  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
        OR fce.CARE_END_DATE IS NULL)


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
        fc.START_DTTM,
        cn.DIM_PERSON_ID
)


-- META-END

-- META-CONTAINER: {"type": "table", "name": "ssd_cla_convictions"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_OFFENCE
-- =============================================================================

SELECT 
    fo.FACT_OFFENCE_ID,
    fo.DIM_PERSON_ID,
    fo.OFFENCE_DTTM,
    fo.DESCRIPTION
FROM 
    HDM.Child_Social.FACT_OFFENCE as fo

;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_health"}
-- =============================================================================
-- Object Name: ssd_cla_health
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: 1.5 JH updated source for clah_health_check_type to resolve blanks.
--             Updated to use DIM_LOOKUP_EXAM_STATUS_DESC as opposed to _CODE
--             to inprove readability.
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_HEALTH_CHECK
-- =============================================================================

 
SELECT
    fhc.FACT_HEALTH_CHECK_ID,
    fhc.DIM_PERSON_ID,
    fhc.DIM_LOOKUP_EVENT_TYPE_DESC,
    fhc.START_DTTM,
    fhc.DIM_LOOKUP_EXAM_STATUS_DESC
FROM
    HDM.Child_Social.FACT_HEALTH_CHECK as fhc
 

WHERE
    (fhc.START_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fhc.START_DTTM IS NULL)

;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_immunisations"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
--             0.2: most recent status reworked / 903 source removed 220224 JH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CLA
-- - HDM.Child_Social.FACT_903_DATA [Depreciated]
-- =============================================================================

-- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)

SELECT
    fcla.DIM_PERSON_ID,
    fcla.IMMU_UP_TO_DATE_FLAG,
    fcla.LAST_UPDATED_DTTM,
    ROW_NUMBER() OVER (
        PARTITION BY fcla.DIM_PERSON_ID -- 
        ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
FROM
    HDM.Child_Social.FACT_CLA AS fcla



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_substance_misuse"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.ssd_person
-- - HDM.Child_Social.FACT_SUBSTANCE_MISUSE
-- =============================================================================

SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID               AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID                          AS clas_person_id,
    fsm.START_DTTM                             AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE         AS clas_substance_misused,
    fsm.ACCEPT_FLAG                            AS clas_intervention_received
FROM 
    HDM.Child_Social.FACT_SUBSTANCE_MISUSE AS fsm

;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_placement"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0 
--             0.2: 060324 JH
--             0.1: Corrected/removal of placement_la & episode_id 090124 RH
-- Status: [R]elease
-- Remarks: DEV: filtering for OFSTED_URN LIKE 'SC%'
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CLA_PLACEMENT
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- =============================================================================

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
            AND    fce.OFSTED_URN LIKE 'SC%'
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
 
WHERE fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
                                            'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
                                            'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')

AND
    (fcp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fcp.END_DTTM IS NULL);



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_reviews"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
--             0.2: clar_cla_review_cancelled type change from nvarchar 100524 RH
--             0.1: clar_cla_id change from clar cla episode id 120124 JH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - ssd_cla_episodes
-- - HDM.Child_Social.FACT_CLA_REVIEW
-- - HDM.Child_Social.FACT_MEETING_SUBJECTS 
-- - HDM.Child_Social.FACT_MEETINGS
-- =============================================================================

SELECT
    fcr.FACT_CLA_REVIEW_ID                          AS clar_cla_review_id,
    fcr.FACT_CLA_ID                                 AS clar_cla_id,                
    fcr.DUE_DTTM                                    AS clar_cla_review_due_date,
    fcr.MEETING_DTTM                                AS clar_cla_review_date,
    fm.CANCELLED                                    AS clar_cla_review_cancelled,
 
    (SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
        AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
        THEN ISNULL(fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC, '') END)) 
                                                    AS clar_cla_review_participation
 
FROM
    HDM.Child_Social.FACT_CLA_REVIEW AS fcr
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm               ON fcr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms      ON fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
 
LEFT JOIN
    HDM.Child_Social.FACT_FORMS ff ON fms.FACT_OUTCM_FORM_ID = ff.FACT_FORM_ID
    AND fms.FACT_OUTCM_FORM_ID <> '1071252'     -- duplicate outcomes form for ESCC causing PK error
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON fcr.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'

AND
    (fcr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fcr.MEETING_DTTM IS NULL)

GROUP BY fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID,
    ff.FACT_FORM_ID,
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE
    ;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_previous_permanence"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.1 
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
-- Status: [R]elease
-- Remarks: Adapted from 1.3 ver, needs re-test also with Knowsley.
--         1.5 JH tmp table was not being referenced, updated query and reduced running
--         time considerably, also filtered out rows where ANSWER IS NULL
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_903_DATA [depreciated]
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

SELECT
    ffa.FACT_FORM_ID,
    ffa.FACT_FORM_ANSWER_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
 
INTO #ssd_TMP_PRE_previous_permanence
FROM
    HDM.Child_Social.FACT_FORM_ANSWERS ffa
WHERE
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'
    AND
    ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
    AND
    ffa.ANSWER IS NOT NULL
 

SELECT
    tmp_ffa.FACT_FORM_ID AS lapp_table_id,
    ff.DIM_PERSON_ID AS lapp_person_id,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_option,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_la,
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '')) = 0 AND 
             TRY_CAST(ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '0') AS INT) BETWEEN 1 AND 31 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zz' 
    END + '/' + 
    CASE 
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('January', 'Jan')  THEN '01'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('February', 'Feb') THEN '02'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('March', 'Mar')    THEN '03'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('April', 'Apr')    THEN '04'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('May')             THEN '05'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('June', 'Jun')     THEN '06'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('July', 'Jul')     THEN '07'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('August', 'Aug')   THEN '08'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('September', 'Sep') THEN '09'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') 
        IN ('October', 'Oct')  THEN '10'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('November', 'Nov') THEN '11'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('December', 'Dec') THEN '12'
        ELSE 'zz' 
    END + '/' + 
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '')) = 0 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zzzz' 
    END
    AS lapp_previous_permanence_order_date
FROM
    #ssd_TMP_PRE_previous_permanence tmp_ffa
JOIN
    HDM.Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID

GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;





-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_care_plan"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.1
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.1: Altered _json keys and groupby towards > clarity 190224 JH
-- Status: [R]elease
-- Remarks:    Added short codes to plan type questions to improve readability.
--             Removed form type filter, only filtering ffa. on ANSWER_NO.
--             Requires #LEGACY-PRE2016 changes.
-- Dependencies:
-- - ssd_person
-- - #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

-- option A

;WITH required(table_name, column_name) AS (
    SELECT 'HDM.Child_Social.FACT_FORM_ANSWERS', 'FACT_FORM_ID' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORM_ANSWERS', 'ANSWER_NO' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORM_ANSWERS', 'ANSWER' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORM_ANSWERS', 'ANSWERED_DTTM' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORM_ANSWERS', 'DIM_ASSESSMENT_TEMPLATE_ID_DESC' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORMS',        'FACT_FORM_ID' UNION ALL
    SELECT 'HDM.Child_Social.FACT_FORMS',        'DIM_PERSON_ID' UNION ALL
    SELECT 'HDM.Child_Social.FACT_CARE_PLANS',   'FACT_CARE_PLAN_ID' UNION ALL
    SELECT 'HDM.Child_Social.FACT_CARE_PLANS',   'DIM_PERSON_ID' UNION ALL
    SELECT 'HDM.Child_Social.FACT_CARE_PLANS',   'START_DTTM' UNION ALL
    SELECT 'HDM.Child_Social.FACT_CARE_PLANS',   'END_DTTM' UNION ALL
    SELECT 'HDM.Child_Social.FACT_CARE_PLANS',   'DIM_LOOKUP_PLAN_STATUS_ID_CODE'
)
SELECT
    r.table_name,
    r.column_name,
    CASE
      WHEN OBJECT_ID(r.table_name) IS NULL THEN 'MISSING TABLE'
      WHEN NOT EXISTS (
            SELECT 1
            FROM sys.columns c
            WHERE c.object_id = OBJECT_ID(r.table_name)
              AND c.name = r.column_name
      ) THEN 'MISSING COLUMN'
      ELSE 'OK'
    END AS status
FROM required r
ORDER BY r.table_name, r.column_name;

-- 2a) latest response per person per CPFUP question, small sample
WITH MostRecentQuestionResponse AS (
    SELECT
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
    JOIN HDM.Child_Social.FACT_FORMS        AS ff
      ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
    WHERE ffa.ANSWER_NO IN ('CPFUP1','CPFUP2','CPFUP3','CPFUP4','CPFUP5','CPFUP6','CPFUP7','CPFUP8','CPFUP9','CPFUP10')
    GROUP BY ff.DIM_PERSON_ID, ffa.ANSWER_NO
),
LatestResponses AS (
    SELECT
        m.DIM_PERSON_ID,
        m.ANSWER_NO,
        m.MaxFormID AS FACT_FORM_ID,
        ffa.ANSWER,
        ffa.ANSWERED_DTTM AS LatestResponseDate
    FROM MostRecentQuestionResponse AS m
    JOIN HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
      ON ffa.FACT_FORM_ID = m.MaxFormID
     AND ffa.ANSWER_NO   = m.ANSWER_NO
)
SELECT TOP (50)
    lr.FACT_FORM_ID,
    lr.DIM_PERSON_ID,
    lr.ANSWER_NO,
    lr.ANSWER,
    lr.LatestResponseDate
FROM LatestResponses AS lr
ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;

-- 2b) care plan slice with manual JSON built from HDM tables only, small sample
SELECT TOP (50)
    fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
    fcp.DIM_PERSON_ID              AS lacp_person_id,
    fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
    N'{' +
      N'"REMAINSUP":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP1'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"RETURN1M":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP2'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"RETURN6M":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP3'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"RETURNEV":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP4'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"LTRELFR":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP5'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"LTFOST18":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP6'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"RESPLMT":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP7'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"SUPPLIV":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP8'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"ADOPTION":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP9'  THEN ffa.ANSWER END), N'')) + N'",' +
      N'"OTHERPLN":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP10' THEN ffa.ANSWER END), N'')) + N'"}'
      AS lacp_cla_care_plan_json
FROM HDM.Child_Social.FACT_CARE_PLANS AS fcp
LEFT JOIN HDM.Child_Social.FACT_FORMS        AS ff
  ON ff.DIM_PERSON_ID = fcp.DIM_PERSON_ID
LEFT JOIN HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
  ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID
 AND ffa.ANSWER_NO IN ('CPFUP1','CPFUP2','CPFUP3','CPFUP4','CPFUP5','CPFUP6','CPFUP7','CPFUP8','CPFUP9','CPFUP10')
WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
GROUP BY
    fcp.FACT_CARE_PLAN_ID,
    fcp.DIM_PERSON_ID,
    fcp.START_DTTM,
    fcp.END_DTTM
ORDER BY fcp.FACT_CARE_PLAN_ID;

 


-- -- -- option B
-- -- 2a) Latest response per person per CPFUP question, small sample
-- WITH MostRecentQuestionResponse AS (
--     SELECT
--         ff.DIM_PERSON_ID,
--         ffa.ANSWER_NO,
--         MAX(ffa.FACT_FORM_ID) AS MaxFormID
--     FROM HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
--     JOIN HDM.Child_Social.FACT_FORMS        AS ff
--       ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
--     WHERE ffa.ANSWER_NO IN ('CPFUP1','CPFUP2','CPFUP3','CPFUP4','CPFUP5','CPFUP6','CPFUP7','CPFUP8','CPFUP9','CPFUP10')
--     GROUP BY ff.DIM_PERSON_ID, ffa.ANSWER_NO
-- ),
-- LatestResponses AS (
--     SELECT
--         m.DIM_PERSON_ID,
--         m.ANSWER_NO,
--         m.MaxFormID AS FACT_FORM_ID,
--         ffa.ANSWER,
--         ffa.ANSWERED_DTTM AS LatestResponseDate
--     FROM MostRecentQuestionResponse AS m
--     JOIN HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
--       ON ffa.FACT_FORM_ID = m.MaxFormID
--      AND ffa.ANSWER_NO   = m.ANSWER_NO
-- )
-- SELECT TOP (50)
--     lr.FACT_FORM_ID,
--     lr.DIM_PERSON_ID,
--     lr.ANSWER_NO,
--     lr.ANSWER,
--     lr.LatestResponseDate
-- FROM LatestResponses AS lr
-- ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;


-- -- 2b) Care plan slice with manual JSON preview per person, HDM only, small sample
-- SELECT TOP (50)
--     fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
--     fcp.DIM_PERSON_ID              AS lacp_person_id,
--     fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
--     fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
--     N'{' +
--       N'"REMAINSUP":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP1'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"RETURN1M":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP2'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"RETURN6M":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP3'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"RETURNEV":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP4'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"LTRELFR":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP5'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"LTFOST18":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP6'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"RESPLMT":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP7'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"SUPPLIV":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP8'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"ADOPTION":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP9'  THEN ffa.ANSWER END), N'')) + N'",' +
--       N'"OTHERPLN":"' + CONVERT(nvarchar(max), COALESCE(MAX(CASE WHEN ffa.ANSWER_NO='CPFUP10' THEN ffa.ANSWER END), N'')) + N'"}'
--       AS lacp_cla_care_plan_json
-- FROM HDM.Child_Social.FACT_CARE_PLANS AS fcp
-- LEFT JOIN HDM.Child_Social.FACT_FORMS        AS ff
--   ON ff.DIM_PERSON_ID = fcp.DIM_PERSON_ID
-- LEFT JOIN HDM.Child_Social.FACT_FORM_ANSWERS AS ffa
--   ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID
--  AND ffa.ANSWER_NO IN ('CPFUP1','CPFUP2','CPFUP3','CPFUP4','CPFUP5','CPFUP6','CPFUP7','CPFUP8','CPFUP9','CPFUP10')
-- WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
-- GROUP BY
--     fcp.FACT_CARE_PLAN_ID,
--     fcp.DIM_PERSON_ID,
--     fcp.START_DTTM,
--     fcp.END_DTTM
-- ORDER BY fcp.FACT_CARE_PLAN_ID;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0!
--             !0.3: Prep for casenote _ id to be removed... not yet actioned RH
--             0.2: FK updated to person_id. change from clav.VISIT_DTTM  150224 JH
--             0.1: pers_person_id and clav_cla_id  added JH
-- Status: [R]elease
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CASENOTES
-- - HDM.Child_Social.FACT_CLA_VISIT
-- =============================================================================

 
 
SELECT
    clav.FACT_CLA_VISIT_ID      AS clav_cla_visit_id,
    clav.FACT_CLA_ID            AS clav_cla_id,
    clav.DIM_PERSON_ID          AS clav_person_id,
    cn.EVENT_DTTM               AS clav_cla_visit_date,
    cn.SEEN_FLAG                AS clav_cla_visit_seen,
    cn.SEEN_ALONE_FLAG          AS clav_cla_visit_seen_alone
 
FROM
    HDM.Child_Social.FACT_CLA_VISIT AS clav
 
LEFT JOIN
    HDM.Child_Social.FACT_CASENOTES AS cn ON  clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
    AND clav.DIM_PERSON_ID = cn.DIM_PERSON_ID
 
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON   clav.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVL')

AND
    (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cn.EVENT_DTTM IS NULL)

;


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_sdq_scores"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: ASSESSMENT_TEMPLATE_ID_CODEs ranges validated at 12/12/23
--         Removed csdq _form_ id as the form id is also being used as csdq_table_id
--         Added placeholder for csdq_sdq_reason
--         Removed PRIMARY KEY stipulation for csdq_table_id
-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================


SELECT
    ff.FACT_FORM_ID                     AS csdq_table_id,
    ff.DIM_PERSON_ID                    AS csdq_person_id,
    CAST('1900-01-01' AS DATETIME)      AS csdq_sdq_completed_date,
    (
        SELECT TOP 1
            CASE
                WHEN ISNUMERIC(ffa_inner.ANSWER) = 1 THEN TRY_CAST(ffa_inner.ANSWER AS INT)
                ELSE NULL
            END
        FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa_inner
        WHERE ffa_inner.FACT_FORM_ID = ff.FACT_FORM_ID
            AND ffa_inner.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
            AND ffa_inner.ANSWER_NO = 'SDQScore'
            AND ffa_inner.ANSWER IS NOT NULL
        ORDER BY ffa_inner.ANSWER DESC
    )                                   AS csdq_sdq_score,
    'SSD_PH'                            AS csdq_sdq_reason
FROM
    HDM.Child_Social.FACT_FORMS ff
JOIN
    HDM.Child_Social.FACT_FORM_ANSWERS ffa ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
    AND ffa.ANSWER_NO IN ('FormEndDate', 'SDQScore')
    AND ffa.ANSWER IS NOT NULL
;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_missing"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1
--             1.0 miss_ missing_ rhi_accepted/offered 'NA' not valid value #DtoI-1617 240524 RH
--             0.9 miss_missing_rhi_accepted/offered increased to size (2) 100524 RH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_MISSING_PERSON
-- =============================================================================

SELECT 
    fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
    fmp.DIM_PERSON_ID                   AS miss_person_id,
    fmp.START_DTTM                      AS miss_missing_episode_start_date,
    fmp.MISSING_STATUS                  AS miss_missing_episode_type,
    fmp.END_DTTM                        AS miss_missing_episode_end_date,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NA' THEN 'NA' -- #DtoI-1617
        WHEN fmp.RETURN_INTERVIEW_OFFERED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_offered,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NA' THEN 'NA' -- #DtoI-1617
        WHEN fmp.RETURN_INTERVIEW_ACCEPTED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_accepted

FROM 
    HDM.Child_Social.FACT_MISSING_PERSON AS fmp

WHERE
    (fmp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fmp.END_DTTM IS NULL)

;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_care_leavers"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.3:
--             1.2: Added NULLIF(NULLIF(... fixes for CurrentWorker & AllocatedTeam 290724 RH
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.3: change of main source to DIM_CLA_ELIGIBILITY in order to capture full care leaver cohort 12/03/24 JH
--             0.2: switch field _worker)nm and _team_nm around as in wrong order RH
--             0.1: worker/p.a id field changed to descriptive name towards AA reporting JH
-- Status: [R]elease
-- Remarks:    Dev: Note that <multiple> refs to ssd_person need changing when porting code to tempdb.. versions.
--             Dev: Ensure index on ssd_person.pers_person_id is intact to ensure performance on <FROM ssd_development.ssd_person> references in the CTEs(added for performance)
--             Dev: Revised V3/4 to aid performance on large involvements table aggr

--             This table the cohort of children who are preparing to leave care, typically 15/16/17yrs+; 
--             Not those who are finishing a period of care. 
--             clea_care_leaver_eligibility == LAC for 13wks+(since 14yrs)+LAC since 16yrs 

-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- - HDM.Child_Social.FACT_CLA_CARE_LEAVERS
-- - HDM.Child_Social.DIM_CLA_ELIGIBILITY
-- - HDM.Child_Social.FACT_CARE_PLANS
-- =============================================================================



WITH ranked AS (
  SELECT
    DIM_PERSON_ID,
    DIM_WORKER_ID,
    FACT_WORKER_HISTORY_DEPARTMENT_ID,
    DIM_LOOKUP_INVOLVEMENT_TYPE_CODE,
    IS_ALLOCATED_CW_FLAG,
    FACT_INVOLVEMENTS_ID,
    END_DTTM,
    ROW_NUMBER() OVER (
      PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE
      ORDER BY FACT_INVOLVEMENTS_ID DESC
    ) AS rn
  FROM HDM.Child_Social.FACT_INVOLVEMENTS
  WHERE DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW','16PLUS')
    AND DIM_WORKER_ID IS NOT NULL
    AND DIM_WORKER_ID <> -1
    AND (
          DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW'
          OR IS_ALLOCATED_CW_FLAG = 'Y'
        )
)
SELECT
  DIM_PERSON_ID,
  MAX(CASE WHEN DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW'
           THEN NULLIF(DIM_WORKER_ID, 0) END)                                            AS CurrentWorker,
  MAX(CASE WHEN DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW'
           THEN NULLIF(NULLIF(FACT_WORKER_HISTORY_DEPARTMENT_ID, -1), 0) END)            AS AllocatedTeam,
  MAX(CASE WHEN DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = '16PLUS'
           THEN NULLIF(DIM_WORKER_ID, 0) END)                                            AS PersonalAdvisor
FROM ranked
WHERE rn = 1
GROUP BY DIM_PERSON_ID;


 
 
-- Latest record per person from care leavers
WITH last_fccl AS (
  SELECT
      fccl.DIM_PERSON_ID,
      fccl.FACT_CLA_CARE_LEAVERS_ID,
      fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE,
      fccl.IN_TOUCH_DTTM,
      fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC,
      fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
      fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC,
      ROW_NUMBER() OVER (
          PARTITION BY fccl.DIM_PERSON_ID
          ORDER BY fccl.IN_TOUCH_DTTM DESC, fccl.FACT_CLA_CARE_LEAVERS_ID DESC
      ) AS rn
  FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl
),

-- Latest PATH plan review per person
last_path AS (
  SELECT
      fcp.DIM_PERSON_ID,
      MAX(fcp.MODIF_DTTM) AS clea_pathway_plan_review_date
  FROM HDM.Child_Social.FACT_CARE_PLANS AS fcp
  WHERE fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH'
  GROUP BY fcp.DIM_PERSON_ID
)

SELECT
    -- deterministic id if you want to stop using NEWID for testing
    CONCAT(CAST(dce.DIM_CLA_ELIGIBILITY_ID AS nvarchar(20)), '-', CAST(lc.FACT_CLA_CARE_LEAVERS_ID AS nvarchar(20))) AS clea_table_id,
    dce.DIM_PERSON_ID                                                                                                   AS clea_person_id,
    COALESCE(dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC, N'No Current Eligibility')                                         AS clea_care_leaver_eligibility,
    lc.DIM_LOOKUP_IN_TOUCH_CODE_CODE                                                                                    AS clea_care_leaver_in_touch,
    lc.IN_TOUCH_DTTM                                                                                                    AS clea_care_leaver_latest_contact,
    lc.DIM_LOOKUP_ACCOMMODATION_CODE_DESC                                                                               AS clea_care_leaver_accommodation,
    lc.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC                                                                           AS clea_care_leaver_accom_suitable,
    lc.DIM_LOOKUP_MAIN_ACTIVITY_DESC                                                                                    AS clea_care_leaver_activity,
    lp.clea_pathway_plan_review_date,
    ih.PersonalAdvisor                                                                                                  AS clea_care_leaver_personal_advisor,
    ih.AllocatedTeam                                                                                                    AS clea_care_leaver_allocated_team,
    ih.CurrentWorker                                                                                                    AS clea_care_leaver_worker_id
FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
LEFT JOIN last_fccl AS lc
  ON lc.DIM_PERSON_ID = dce.DIM_PERSON_ID
 AND lc.rn = 1
LEFT JOIN last_path AS lp
  ON lp.DIM_PERSON_ID = dce.DIM_PERSON_ID
LEFT JOIN InvolvementHistoryCTE AS ih
  ON ih.DIM_PERSON_ID = dce.DIM_PERSON_ID;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_permanence"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
--             0.5: perm_placed_foster_carer_date placeholder re-added 240424 RH
--             0.4: worker_name field name change for consistency 100424 JH
--             0.3: entered_care_date removed/moved to cla_episodes 060324 RH
--             0.2: perm_placed_foster_carer_date (from fc.START_DTTM) removed RH
--             0.1: perm_adopter_sex, perm_adopter_legal_status added RH
-- Status: [R]elease
-- Remarks: 
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

;

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_professionals"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.3
--             1.2: idx added o prof_professional_id towards csc api work 220125 RH
--             1.1: staff_id field clean-up, removal of dirty|admin values 090724 RH
--             1.0: #DtoI-1743 caseload count revised to be within ssd timeframe 170524 RH
--             0.9: prof_professional_id now becomes staff_id 090424 JH
--             0.8: prof _table_ id(prof _system_ id) becomes prof _professional_ id 090424 JH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - @CaseloadLastSept30th
-- - @CaseloadTimeframeStartDate
-- - @ssd_timeframe_years
-- - HDM.Child_Social.DIM_WORKER
-- - HDM.Child_Social.FACT_REFERRALS
-- - ssd_cin_episodes (if counting caseloads within SSD timeframe)
-- =============================================================================


SELECT 
    dw.DIM_WORKER_ID                        AS prof_professional_id,                -- system based ID for workers
    TRIM(dw.STAFF_ID)                       AS prof_staff_id,                       -- Note that this is trimmed for non-printing chars
    CONCAT(dw.FORENAME, ' ', dw.SURNAME)    AS prof_professional_name,              -- used also as Allocated Worker|Assigned Worker
    dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,  -- Not tied to WORKER_ID, this is the social work reg number IF entered
    ''                                      AS prof_agency_worker_flag,             -- Not available in SSD Ver/Iteration 1 [TESTING] [PLACEHOLDER_DATA]
    dw.JOB_TITLE                            AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)                 AS prof_professional_caseload,          -- 0 when no open cases on given date.
    dw.DEPARTMENT_NAME                      AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY                AS prof_full_time_equivalency
FROM 
    HDM.Child_Social.DIM_WORKER AS dw

LEFT JOIN (
    SELECT 
        -- Calculate CASELOAD 
        -- [REVIEW][TESTING] count within restricted ssd timeframe only
        DIM_WORKER_ID,
        COUNT(*) AS OpenCases
    FROM 
        HDM.Child_Social.FACT_REFERRALS

    WHERE 
        REFRL_START_DTTM <= @CaseloadLastSept30th AND 
        (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM >= @CaseloadLastSept30th) AND
        REFRL_START_DTTM >= @CaseloadTimeframeStartDate  -- ssd timeframe constraint
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID
WHERE 
    dw.DIM_WORKER_ID <> -1
    AND TRIM(dw.STAFF_ID) IS NOT NULL           -- in theory would not occur
    AND LOWER(TRIM(dw.STAFF_ID)) <> 'unknown';  -- data seen in some LAs






-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_department"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1:
--             1.0: 
-- Status: [T]est
-- Remarks: 
-- Dependencies: 
-- - HDM.Child_Social.DIM_DEPARTMENT
-- =============================================================================


SELECT 
    dpt.DIM_DEPARTMENT_ID       AS dept_team_id,
    dpt.NAME                    AS dept_team_name,
    dpt.DEPT_ID                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name

FROM HDM.Child_Social.DIM_DEPARTMENT dpt

WHERE dpt.dim_department_id <> -1;

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_involvements"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.3
--             1.2: idex on invo_professional_id added towards csc api work 220125 RH
--             1.1: Revisions to 1.0/0.9. DEPT_ID else .._HISTORY_DEPARTMENT_ID 300724 RH
--             1.0: Trancated professional_team field IF comment data populates 110624 RH
--             0.9: added person_id and changed source of professional_team 090424 JH
-- Status: [R]elease
-- Remarks:    v1.2 revisions backtrack prev changes in favour of dept/hist ID fields

--             [TESTING] The below towards v1.0 for ref. only
--             Regarding the increased size/len on invo_professional_team
--             The (truncated)COMMENTS field is only used if:
--                 WORKER_HISTORY_DEPARTMENT_DESC is NULL.
--                 DEPARTMENT_NAME is NULL.
--                 GROUP_NAME is NULL.
--                 COMMENTS contains the keyword %WORKER% or %ALLOC%.
-- Dependencies:
-- - ssd_person
-- - ssd_departments (if obtaining team_name)
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- =============================================================================

SELECT
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    CASE 
        -- replace admin -1 values for when no worker associated
        WHEN fi.DIM_WORKER_ID IN ('-1', -1) THEN NULL    -- THEN '' (alternative null replacement)
        ELSE fi.DIM_WORKER_ID 
    END                                           AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    
    -- -- use first non-NULL value for prof team, in order of : i)dept, ii)grp, or iii)relevant comment
    -- LEFT(
    --     COALESCE(
    --     fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC,   -- prev/relevant dept name if available
    --     fi.DIM_DEPARTMENT_NAME,                   -- otherwise, use existing dept name
    --     fi.DIM_GROUP_NAME,                        -- then, use wider grp name if the above are NULL

    --     CASE -- if still NULL, refer into comments data but only when...
    --         WHEN fi.COMMENTS LIKE '%WORKER%' OR fi.COMMENTS LIKE '%ALLOC%' -- refer to comments for specific keywords
    --         THEN fi.COMMENTS 
    --     END -- if fi.COMMENTS is NULL, results in NULL
    -- ), 255)                                       AS invo_professional_team,
   
    CASE 
        WHEN fi.DIM_DEPARTMENT_ID IS NOT NULL AND fi.DIM_DEPARTMENT_ID != -1 THEN fi.DIM_DEPARTMENT_ID
        ELSE CASE 
            -- replace system -1 values for when no worker associated [TESTING] #DtoI-1762
            WHEN fi.FACT_WORKER_HISTORY_DEPARTMENT_ID = -1 THEN NULL
            ELSE fi.FACT_WORKER_HISTORY_DEPARTMENT_ID 
        END 
    END                                           AS invo_professional_team, 
    fi.DIM_PERSON_ID                              AS invo_person_id,
    fi.START_DTTM                                 AS invo_involvement_start_date,
    fi.END_DTTM                                   AS invo_involvement_end_date,
    fi.DIM_LOOKUP_CWREASON_CODE                   AS invo_worker_change_reason,
    fi.FACT_REFERRAL_ID                           AS invo_referral_id
FROM
    HDM.Child_Social.FACT_INVOLVEMENTS AS fi

WHERE
    (fi.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fi.END_DTTM  IS NULL)

;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_linked_identifiers"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1
--             1.0: added source data for UPN+FORMER_UPN 140624 RH
            
-- Status: [R]elease
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled on a localised basis. 

--         The list of allowed identifier_type codes are:
--             ['Case Number', 
--             'Unique Pupil Number', 
--             'NHS Number', 
--             'Home Office Registration', 
--             'National Insurance Number', 
--             'YOT Number', 
--             'Court Case Number', 
--             'RAA ID', 
--             'Incident ID']
--             To have any further codes agreed into the standard, issue a change request

-- Dependencies: 
-- - Will be LA specific depending on systems/data being linked
-- - ssd_person
-- - HDM.Child_Social.DIM_PERSON
-- =============================================================================

SELECT
    csp.dim_person_id                   AS link_person_id,
    'Former Unique Pupil Number'        AS link_identifier_type,
    'SSD_PH'                            AS link_identifier_value,       -- csp.former_upn [TESTING] Removed for compatibility
    NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
    NULL                                AS link_valid_to_date           -- NULL for valid_to_date
FROM
    HDM.Child_Social.DIM_PERSON csp
WHERE
    csp.former_upn IS NOT NULL

-- AND (link_valid_to_date IS NULL OR link_valid_to_date > GETDATE()) -- We can't yet apply this until source(s) defined. 
-- Filter shown here for future reference #DtoI-1806

;




/* END SSD main extract */
/* ********************************************************************************************************** */



