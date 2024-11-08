
-- META-CONTAINER: {"type": "header", "name": "extract_settings"}
-- META-ELEMENT: {"type": "header"}

/*
*********************************************************************************************************
STANDARD SAFEGUARDING DATASET EXTRACT VIEWS]
https://data-to-insight.github.io/ssd-data-model/

*We strongly recommend that all initial pilot/trials of SSD scripts occur in a development|test environment.*

Script creates labelled persistent VIEWS in your existing|specified database. 

The SQL script contains some named destructive statements. These are limited to the following:
- Preceding each named ssd_ view creation, the same named view is dropped if it exists. 
- The same explicit drop command is used prior to the named tables (see additional notes for list)


Additional notes: 
This script creates all the SSD objects as VIEWS, with the following exceptions that are required as tables 
[ssd_views_version_log, ssd_views_variables, and for an effective|true live deployment ssd_linked_identifiers_view should be converted to table]

********************************************************************************************************** */

-- META-ELEMENT: {"type": "dbschema"}
-- Point to DB/TABLE_CATALOG if required (SSD views created here, otherwise default schema)

-- META-END




-- META-CONTAINER: {"type": "view", "name": "ssd_views_variables"}
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: SSD extract metadata enabling version consistency across LAs. 
--          This remains as a TABLE even when SSD is immplemented as VIEWS
-- Dependencies: 
-- - None
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_views_variables') IS NOT NULL DROP TABLE ssd_views_variables;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_views_variables (
    ssd_timeframe_years INT,
    CaseloadLastSept30th DATE,
    CaseloadTimeframeStartDate DATE
);
GO


DECLARE @ssd_timeframe_years INT = 6;
DECLARE @CaseloadLastSept30th DATE;
DECLARE @CaseloadTimeframeStartDate DATE;

-- Calculate the Caseload Date (Currently: September 30th)
SET @CaseloadLastSept30th = CASE 
    WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
    THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
    ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
END;

-- Calculate the Timeframe Start Date
SET @CaseloadTimeframeStartDate = DATEADD(YEAR, -@ssd_timeframe_years, @CaseloadLastSept30th);

-- Update the permanent table with the calculated values
-- If the table is already populated, update the values

IF EXISTS (SELECT 1 FROM ssd_views_variables)
BEGIN
    UPDATE ssd_views_variables
    SET 
        ssd_timeframe_years = @ssd_timeframe_years,
        CaseloadLastSept30th = @CaseloadLastSept30th,
        CaseloadTimeframeStartDate = @CaseloadTimeframeStartDate;
END
ELSE
BEGIN
    INSERT INTO ssd_views_variables (
        ssd_timeframe_years, 
        CaseloadLastSept30th, 
        CaseloadTimeframeStartDate
    )
    VALUES (
        @ssd_timeframe_years, 
        @CaseloadLastSept30th, 
        @CaseloadTimeframeStartDate
    );
END;
GO


-- META-END









-- META-CONTAINER: {"type": "view", "name": "ssd_views_version_log"}
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: SSD extract metadata enabling version consistency across LAs. 
--          This remains as a TABLE even when SSD is immplemented as VIEWS
-- Dependencies: 
-- - None
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_views_version_log', 'U') IS NOT NULL DROP TABLE ssd_views_version_log;

-- META-ELEMENT: {"type": "create_table"}
-- create versioning information object
CREATE TABLE ssd_views_version_log (
    version_number      NVARCHAR(10) PRIMARY KEY,       -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                  -- date of version release
    description         NVARCHAR(100),                  -- brief description of version
    is_current          BIT NOT NULL DEFAULT 0,         -- flag to indicate if this is the current version
    created_at          DATETIME DEFAULT GETDATE(),     -- timestamp when record was created
    created_by          NVARCHAR(10),                   -- which user created the record
    impact_description  NVARCHAR(255)                   -- additional notes on the impact of the release
); 



-- ensure any previous current-version flag is set to 0 (not current), before adding new current version
UPDATE ssd_views_version_log SET is_current = 0 WHERE is_current = 1;

-- META-ELEMENT: {"type": "insert_data"}
-- insert & update for CURRENT version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_views_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.3', GETDATE(), 'non-core ssd_flag field removal', 1, 'admin', 'no wider impact');


-- HISTORIC versioning log data
INSERT INTO ssd_views_version_log (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.0.0', '2023-01-01', 'Initial alpha release (Phase 1 end)', 0, 'admin', ''),
    ('1.1.1', '2024-06-26', 'Minor updates with revised assessment_factors', 0, 'admin', 'Revised JSON Array structure implemented for CiN'),
    ('1.1.2', '2024-06-26', 'ssd_version_log obj added and minor patch fixes', 0, 'admin', 'Provide mech for extract ver visibility'),
    ('1.1.3', '2024-06-27', 'Revised filtering on ssd_person', 0, 'admin', 'Check IS_CLIENT flag first'),
    ('1.1.4', '2024-07-01', 'ssd_department obj added', 0, 'admin', 'Increased seperation btw professionals and depts enabling history'),
    ('1.1.5', '2024-07-09', 'ssd_person involvements history', 0, 'admin', 'Improved consistency on _json fields, clean-up involvements_history_json'),
    ('1.1.6', '2024-07-12', 'FK fixes for #DtoI-1769', 0, 'admin', 'non-unique/FK issues addressed: #DtoI-1769, #DtoI-1601'),
    ('1.1.7', '2024-07-15', 'Non-core ssd_person records added', 0, 'admin', 'Fix requ towards #DtoI-1802'),
    ('1.1.8', '2024-07-17', 'admin table creation logging process defined', 0, 'admin', ''),
    ('1.1.9', '2024-07-29', 'Applied CAST(person_id) + minor fixes', 0, 'admin', 'impacts all tables using where exists'),
    ('1.2.0', '2024-08-13', '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', 0, 'admin', 'impacts all _team fields, AAL7 outputs'),
    ('1.2.1', '2024-08-20', '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', 0, 'admin', 'priority patch fix'),
    ('1.2.2', '2024-11-06', '#DtoI-1826, META+YML restructure incl. remove opt blocks', 0, 'admin', 'feat/bespoke LA extracts');


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ssd_views_version_log'


-- META-END



/* ********************************************************************************************************** */
/* START SSD main extract */





-- META-CONTAINER: {"type": "view", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. This the most connected table in the SSD.
-- Author: D2I
-- Version: 1.0
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_person_core_filtered_view', 'V') IS NOT NULL DROP VIEW ssd_person_core_filtered_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_person_core_filtered_view AS
SELECT 
    p.DIM_PERSON_ID,
    p.LEGACY_ID,
    p.GENDER_MAIN_CODE,
    p.ETHNICITY_MAIN_CODE,
    p.BIRTH_DTTM,
    p.IS_CLIENT,
    p.DEATH_DTTM
FROM 
    HDM.Child_Social.DIM_PERSON AS p
JOIN 
    ssd_views_variables AS v ON 1 = 1 -- Join for variables like timeframe years
WHERE 
    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    AND (p.IS_CLIENT = 'Y'
        OR EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.FACT_CONTACTS fc
            WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND fc.CONTACT_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE())
        )
        OR EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.FACT_REFERRALS fr
            WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND (
                fr.REFRL_START_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
                OR fr.REFRL_END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
                OR fr.REFRL_END_DTTM IS NULL
              )
        )
        OR EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
            WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND fccl.IN_TOUCH_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE())
        )
        OR EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY dce
            WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
        )
        OR EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.FACT_INVOLVEMENTS fi
            WHERE fi.DIM_PERSON_ID = p.DIM_PERSON_ID
              AND (
                fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' -- Exclude Key Agencies
                OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL
                OR fi.IS_ALLOCATED_CW_FLAG = 'Y'
              )
              AND fi.START_DTTM > '2009-12-04'
              AND fi.DIM_WORKER_ID <> '-1' 
              AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE())
        )
    );
GO


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_person_view', 'V') IS NOT NULL DROP VIEW ssd_person_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_person_view AS
WITH f903_data_CTE AS (
    SELECT 
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        HDM.Child_Social.fact_903_data
    WHERE
        no_upn_code IS NOT NULL
)
SELECT 
    core.LEGACY_ID AS pers_legacy_id,
    CAST(core.DIM_PERSON_ID AS NVARCHAR(48)) AS pers_person_id,
    'SSD_PH' AS pers_sex,
    core.GENDER_MAIN_CODE AS pers_gender,
    core.ETHNICITY_MAIN_CODE AS pers_ethnicity,
    CASE WHEN dp.DOB_ESTIMATED = 'N'
         THEN core.BIRTH_DTTM 
         ELSE NULL 
    END AS pers_dob,
    NULL AS pers_common_child_id,
    COALESCE(f903.no_upn_code, 'SSD_PH') AS pers_upn_unknown,
    dp.EHM_SEN_FLAG AS pers_send_flag,
    CASE WHEN dp.DOB_ESTIMATED = 'Y'
         THEN core.BIRTH_DTTM 
         ELSE NULL 
    END AS pers_expected_dob, 
    core.DEATH_DTTM AS pers_death_date,
    CASE 
        WHEN core.GENDER_MAIN_CODE <> 'M' AND EXISTS (
            SELECT 1 
            FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
            WHERE fpr.DIM_PERSON_ID = core.DIM_PERSON_ID 
              AND fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI'
        ) 
        THEN 'Y'
        ELSE NULL 
    END AS pers_is_mother,
    dp.NATNL_CODE AS pers_nationality
FROM
    ssd_person_core_filtered_view AS core
LEFT JOIN (
    SELECT dim_person_id, no_upn_code
    FROM f903_data_CTE
    WHERE rn = 1
) AS f903 ON core.DIM_PERSON_ID = f903.dim_person_id
JOIN HDM.Child_Social.DIM_PERSON AS dp ON core.DIM_PERSON_ID = dp.DIM_PERSON_ID

JOIN ssd_views_variables AS v ON 1 = 1;
GO



-- META-END



-- META-CONTAINER: {"type": "view", "name": "ssd_family"}
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_family_view', 'V') IS NOT NULL 
DROP VIEW ssd_family_view;
Go

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_family_view AS
SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id
FROM 
    HDM.Child_Social.FACT_CONTACTS AS fc

-- Reference the core view to ensure filtering
JOIN 
    ssd_person_core_filtered_view AS p 
    ON CAST(p.DIM_PERSON_ID AS INT) = fc.DIM_PERSON_ID;
GO


-- META-END



-- META-CONTAINER: {"type": "view", "name": "ssd_address"}
-- =============================================================================
-- Description: Contains full address details for every person 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: Need to verify json obj structure on pre-2014 SQL server instances
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.DIM_PERSON_ADDRESS
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_address_view', 'V') IS NOT NULL 
DROP VIEW ssd_address_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_address_view AS
SELECT 
    pa.DIM_PERSON_ADDRESS_ID           AS addr_table_id,
    pa.DIM_PERSON_ID                   AS addr_person_id,
    pa.ADDSS_TYPE_CODE                 AS addr_address_type,
    pa.START_DTTM                      AS addr_address_start_date,
    pa.END_DTTM                        AS addr_address_end_date,
    CASE 
        -- Clean up postcode based on known data patterns
        WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', ''))) THEN '' -- clear postcode of all X's
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''                                -- clear postcode containing 'nopostcode'
        ELSE REPLACE(pa.POSTCODE, ' ', '')                                                              -- remove spaces for consistency
    END AS addr_address_postcode,
    (
        SELECT 
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

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = pa.DIM_PERSON_ID; 
GO


-- META-END




-- META-CONTAINER: {"type": "view", "name": "ssd_disability"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_disability_view', 'V') IS NOT NULL 
DROP VIEW ssd_disability_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_disability_view AS
SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id, 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    HDM.Child_Social.FACT_DISABILITY AS fd

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fd.DIM_PERSON_ID;
GO




-- META-END



-- META-CONTAINER: {"type": "view", "name": "ssd_immigration_status"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_immigration_status_view', 'V') IS NOT NULL 
DROP VIEW ssd_immigration_status_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_immigration_status_view AS
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID        AS immi_immigration_status_id,
    ims.DIM_PERSON_ID                     AS immi_person_id,
    ims.START_DTTM                        AS immi_immigration_status_start_date,
    ims.END_DTTM                          AS immi_immigration_status_end_date,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC      AS immi_immigration_status
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = ims.DIM_PERSON_ID;
GO


-- META-END





-- META-CONTAINER: {"type": "view", "name": "ssd_cin_episodes"}
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
-- Remarks: 
-- Dependencies: 
-- - @ssd_timeframe_years
-- - HDM.Child_Social.FACT_REFERRALS
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_cin_episodes_view', 'V') IS NOT NULL 
DROP VIEW ssd_cin_episodes_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cin_episodes_view AS
SELECT
    fr.FACT_REFERRAL_ID                   AS cine_referral_id,
    fr.DIM_PERSON_ID                      AS cine_person_id,
    fr.REFRL_START_DTTM                   AS cine_referral_date,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE   AS cine_cin_primary_need_code,
    fr.DIM_LOOKUP_CONT_SORC_ID            AS cine_referral_source_code,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC       AS cine_referral_source_desc,
    (
        SELECT
            ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')   AS SINGLE_ASSESSMENT_FLAG,
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
    fr.OUTCOME_NFA_FLAG                   AS cine_referral_nfa,
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE    AS cine_close_reason,
    fr.REFRL_END_DTTM                     AS cine_close_date,
    fr.DIM_DEPARTMENT_ID                  AS cine_referral_team, -- Swap out on DIM_DEPARTMENT_ID_DESC #DtoI-1762
    fr.DIM_WORKER_ID_DESC                 AS cine_referral_worker_id
FROM
    HDM.Child_Social.FACT_REFERRALS AS fr
-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fr.DIM_PERSON_ID
WHERE
    (fr.REFRL_START_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE())    -- Use`ssd_timeframe_years` variable from ssd_views_variables table
    OR fr.REFRL_END_DTTM IS NULL)
AND fr.DIM_PERSON_ID <> -1;  -- Exclude rows with -1
GO


-- META-END



-- META-CONTAINER: {"type": "view", "name": "ssd_mother"}
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
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_mother_view', 'V') IS NOT NULL 
DROP VIEW ssd_mother_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_mother_view AS
SELECT
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr

-- Join to core filtered view to filter relevant person records (i.e., only SSD relevant persons)
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fpr.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

WHERE
    p.GENDER_MAIN_CODE <> 'M'  -- Ensure that the person is not male (assuming only female can be a mother)
    AND fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND fpr.END_DTTM IS NULL
    AND EXISTS ( 
        -- Filter for CIN episodes to ensure only relevant SSD records are included
        SELECT 1 
        FROM ssd_cin_episodes_view ce
        WHERE CAST(ce.cine_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1806
    );
GO

-- META-END




-- META-CONTAINER: {"type": "view", "name": "ssd_legal_status"}
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_mother_view', 'V') IS NOT NULL 
DROP VIEW ssd_mother_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_mother_view AS
SELECT
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fpr.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

WHERE
    p.GENDER_MAIN_CODE <> 'M'  -- Filter out males (assuming only females can be mothers)
    AND fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND fpr.END_DTTM IS NULL
    AND EXISTS ( 
        -- Filter for CIN episodes to ensure only SSD-relevant records are included
        SELECT 1 
        FROM ssd_cin_episodes_view ce
        WHERE CAST(ce.cine_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1806
    );
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_contacts"}
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
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CONTACTS
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_contacts_view', 'V') IS NOT NULL 
DROP VIEW ssd_contacts_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_contacts_view AS
SELECT 
    fc.FACT_CONTACT_ID                 AS cont_contact_id,
    fc.DIM_PERSON_ID                   AS cont_person_id, 
    fc.CONTACT_DTTM                    AS cont_contact_date,
    fc.DIM_LOOKUP_CONT_SORC_ID         AS cont_contact_source_code,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC    AS cont_contact_source_desc,
    (
        -- Create JSON string for outcomes
        SELECT 
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
-- Join to get ssd_timeframe_ or other defined variable(s)
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799

WHERE 
    fc.CONTACT_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- `ssd_timeframe_years` variable from ssd_views_variables table;
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_early_help_episodes"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_early_help_episodes_view', 'V') IS NOT NULL 
DROP VIEW ssd_early_help_episodes_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_early_help_episodes_view AS
SELECT
    cafe.FACT_CAF_EPISODE_ID                AS earl_episode_id,
    cafe.DIM_PERSON_ID                      AS earl_person_id,
    cafe.EPISODE_START_DTTM                 AS earl_episode_start_date,
    cafe.EPISODE_END_DTTM                   AS earl_episode_end_date,
    cafe.START_REASON                       AS earl_episode_reason,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE   AS earl_episode_end_reason,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE AS earl_episode_organisation,
    'SSD_PH'                                AS earl_episode_worker_id -- Placeholder
FROM
    HDM.Child_Social.FACT_CAF_EPISODE AS cafe

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = cafe.DIM_PERSON_ID

WHERE 
    (cafe.EPISODE_END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
    OR cafe.EPISODE_END_DTTM IS NULL);
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cin_assessments"}
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
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cin_assessments_view', 'V') IS NOT NULL 
DROP VIEW ssd_cin_assessments_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cin_assessments_view AS
WITH RelevantPersons AS (
    SELECT p.pers_person_id
    FROM ssd_person_view p
),
FormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER,
        ffa.DIM_ASSESSMENT_TEMPLATE_QUESTION_ID_DESC
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE ffa.ANSWER_NO IN ('seenYN', 'FormEndDate')
),
AggregatedFormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'seenYN' THEN ffa.ANSWER ELSE NULL END, ''))                                       AS seenYN,
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'FormEndDate' THEN TRY_CAST(ffa.ANSWER AS DATETIME) ELSE NULL END, '1900-01-01'))  AS AssessmentAuthorisedDate
    FROM FormAnswers ffa
    GROUP BY ffa.FACT_FORM_ID
)
SELECT
    fa.FACT_SINGLE_ASSESSMENT_ID            AS cina_assessment_id,
    fa.DIM_PERSON_ID                        AS cina_person_id,
    fa.FACT_REFERRAL_ID                     AS cina_referral_id,
    fa.START_DTTM                           AS cina_assessment_start_date,
    CASE
        WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
        WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
        ELSE NULL
    END AS seenYN,
    afa.AssessmentAuthorisedDate            AS cina_assessment_auth_date,
    (
        SELECT
            ISNULL(fa.OUTCOME_NFA_FLAG, '')                     AS NFA_FLAG,
            ISNULL(fa.OUTCOME_NFA_S47_END_FLAG, '')             AS NFA_S47_END_FLAG,
            ISNULL(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '')     AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fa.OUTCOME_CLA_REQUEST_FLAG, '')             AS CLA_REQUEST_FLAG,
            ISNULL(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')       AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fa.OUTCOME_LEGAL_ACTION_FLAG, '')            AS LEGAL_ACTION_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')        AS PROV_OF_SERVICES_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')         AS PROV_OF_SB_CARE_FLAG,
            ISNULL(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '')   AS SPECIALIST_ASSESSMENT_FLAG,
            ISNULL(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')           AS OTHER_ACTIONS_FLAG,
            ISNULL(fa.OTHER_OUTCOMES_EXIST_FLAG, '')            AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fa.TOTAL_NO_OF_OUTCOMES, '')                 AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fa.OUTCOME_COMMENTS, '')                     AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cina_assessment_outcome_json,
    fa.OUTCOME_NFA_FLAG                     AS cina_assessment_outcome_nfa,
    NULLIF(fa.COMPLETED_BY_DEPT_ID, -1)     AS cina_assessment_team,
    NULLIF(fa.COMPLETED_BY_USER_ID, -1)     AS cina_assessment_worker_id
FROM
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
LEFT JOIN
    AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID

-- Join to get ssd_timeframe_ or other defined variable(s)
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity
-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fa.DIM_PERSON_ID
WHERE 
    fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D') -- Exclude draft and cancelled assessments
    AND (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR afa.AssessmentAuthorisedDate IS NULL);
GO


-- META-END

-- META-CONTAINER: {"type": "view", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
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


-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_assessment_factors_view', 'V') IS NOT NULL 
DROP VIEW ssd_assessment_factors_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_assessment_factors_view AS
WITH TMP_PRE_assessment_factors AS (
    SELECT 
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER
    FROM 
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE 
        ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC = 'FAMILY ASSESSMENT'
        AND ffa.ANSWER_NO IN (
            '1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C',
            '4A', '4B', '4C', '5A', '5B', '5C', '6A', '6B', '6C',
            '7A', '8B', '8C', '8D', '8E', '8F', '9A', '10A', '11A', '12A',
            '13A', '14A', '15A', '16A', '17A', '18A', '18B', '18C', '19A',
            '19B', '19C', '20', '21', '22A', '23A', '24A'
        )
        AND LOWER(ffa.ANSWER) = 'yes'  -- expected [Yes/No/NULL]
        AND ffa.FACT_FORM_ID <> -1
),
AggregatedAnswers AS (
    SELECT 
        fsa.EXTERNAL_ID AS cinf_table_id,
        fsa.FACT_FORM_ID AS cinf_assessment_id,
        '[' + STRING_AGG('"' + tmp_af.ANSWER_NO + '"', ', ') + ']' AS cinf_assessment_factors_json
    FROM 
        HDM.Child_Social.FACT_SINGLE_ASSESSMENT fsa
    JOIN 
        TMP_PRE_assessment_factors tmp_af ON fsa.FACT_FORM_ID = tmp_af.FACT_FORM_ID
    WHERE 
        fsa.EXTERNAL_ID <> -1
        AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_cin_assessments_view)
    GROUP BY 
        fsa.EXTERNAL_ID, fsa.FACT_FORM_ID
)
SELECT 
    cinf_table_id,
    cinf_assessment_id,
    cinf_assessment_factors_json
FROM 
    AggregatedAnswers;
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cin_plans"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cin_plans_view', 'V') IS NOT NULL 
DROP VIEW ssd_cin_plans_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cin_plans_view AS
WITH PlanDetails AS (
    SELECT 
        cps.FACT_CARE_PLAN_SUMMARY_ID,
        cps.FACT_REFERRAL_ID,
        cps.DIM_PERSON_ID,
        cps.START_DTTM,
        cps.END_DTTM,
        MAX(ISNULL(CASE 
            WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID 
            THEN fp.DIM_PLAN_COORD_DEPT_ID END, '')) AS cinp_cin_plan_team,
        MAX(ISNULL(CASE 
            WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID 
            THEN fp.DIM_PLAN_COORD_ID END, '')) AS cinp_cin_plan_worker_id
    FROM 
        HDM.Child_Social.FACT_CARE_PLAN_SUMMARY cps
    LEFT JOIN 
        HDM.Child_Social.FACT_CARE_PLANS fp 
    ON 
        fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
    -- Join to get ssd_timeframe and other defined variable(s)
    JOIN 
        ssd_views_variables AS v 
        ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity
    -- Join to core filtered view to filter relevant person records
    JOIN 
        ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON 
        CAST(p.DIM_PERSON_ID AS INT) = cps.DIM_PERSON_ID
    WHERE 
        cps.DIM_LOOKUP_PLAN_TYPE_CODE = 'FP'
        AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
        AND (cps.END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
        OR cps.END_DTTM IS NULL)
    GROUP BY 
        cps.FACT_CARE_PLAN_SUMMARY_ID,
        cps.FACT_REFERRAL_ID,
        cps.DIM_PERSON_ID,
        cps.START_DTTM,
        cps.END_DTTM
)
SELECT 
    pd.FACT_CARE_PLAN_SUMMARY_ID       AS cinp_cin_plan_id,
    pd.FACT_REFERRAL_ID                AS cinp_referral_id,
    pd.DIM_PERSON_ID                   AS cinp_person_id,
    pd.START_DTTM                      AS cinp_cin_plan_start_date,
    pd.END_DTTM                        AS cinp_cin_plan_end_date,
    pd.cinp_cin_plan_team,
    pd.cinp_cin_plan_worker_id
FROM 
    PlanDetails pd
    
-- Join to get ssd_timeframe_ or other defined variable(s)
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cin_visits"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cin_visits_view', 'V') IS NOT NULL 
DROP VIEW ssd_cin_visits_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cin_visits_view AS
SELECT
    cn.FACT_CASENOTE_ID         AS cinv_cin_visit_id,                
    cn.DIM_PERSON_ID            AS cinv_person_id,
    cn.EVENT_DTTM               AS cinv_cin_visit_date,
    cn.SEEN_FLAG                AS cinv_cin_visit_seen,
    cn.SEEN_ALONE_FLAG          AS cinv_cin_visit_seen_alone,
    cn.SEEN_BEDROOM_FLAG        AS cinv_cin_visit_bedroom
FROM
    HDM.Child_Social.FACT_CASENOTES cn
-- Join to core filtered view to filter relevant person records
JOIN 
    ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = cn.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular ref

WHERE
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN (
        'CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO',
        'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID'
    )
AND
    (cn.EVENT_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
    OR cn.EVENT_DTTM IS NULL);
GO







-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_s47_enquiry"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
--             1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_S47
-- - HDM.Child_Social.FACT_CP_CONFERENCE
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_s47_enquiry_view', 'V') IS NOT NULL 
DROP VIEW ssd_s47_enquiry_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_s47_enquiry_view AS
SELECT 
    s47.FACT_S47_ID                       AS s47e_s47_enquiry_id,
    s47.FACT_REFERRAL_ID                  AS s47e_referral_id,
    s47.DIM_PERSON_ID                     AS s47e_person_id,
    s47.START_DTTM                        AS s47e_s47_start_date,
    s47.END_DTTM                          AS s47e_s47_end_date,
    s47.OUTCOME_NFA_FLAG                  AS s47e_s47_nfa,
    (
        SELECT 
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
    ) AS s47e_s47_outcome_json,
    s47.COMPLETED_BY_DEPT_ID              AS s47e_s47_completed_by_team,
    s47.COMPLETED_BY_USER_STAFF_ID        AS s47e_s47_completed_by_worker_id
FROM 
    HDM.Child_Social.FACT_S47 AS s47
-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p
    ON CAST(p.DIM_PERSON_ID AS INT) = s47.DIM_PERSON_ID
-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 
WHERE
    (s47.END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR s47.END_DTTM IS NULL);
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_initial_cp_conference"}
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

IF OBJECT_ID('ssd_initial_cp_conference_view', 'V') IS NOT NULL 
DROP VIEW ssd_initial_cp_conference_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_initial_cp_conference_view AS
SELECT
    fcpc.FACT_CP_CONFERENCE_ID                  AS icpc_icpc_id,
    fcpc.FACT_MEETING_ID                        AS icpc_icpc_meeting_id,
    CASE 
        WHEN fcpc.FACT_S47_ID IN ('-1', -1) THEN NULL
        ELSE fcpc.FACT_S47_ID 
    END AS icpc_s47_enquiry_id,
    fcpc.DIM_PERSON_ID                          AS icpc_person_id,
    fcpp.FACT_CP_PLAN_ID                        AS icpc_cp_plan_id,
    fcpc.FACT_REFERRAL_ID                       AS icpc_referral_id,
    fcpc.TRANSFER_IN_FLAG                       AS icpc_icpc_transfer_in,
    fcpc.DUE_DTTM                               AS icpc_icpc_target_date,
    fm.ACTUAL_DTTM                              AS icpc_icpc_date,
    fcpc.OUTCOME_CP_FLAG                        AS icpc_icpc_outcome_cp_flag,
    (
        SELECT
            ISNULL(fcpc.OUTCOME_NFA_FLAG, '')                       AS NFA_FLAG,
            ISNULL(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')  AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')         AS SINGLE_ASSESSMENT_FLAG,
            ISNULL(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '')          AS PROV_OF_SERVICES_FLAG,
            ISNULL(fcpc.OUTCOME_CP_FLAG, '')                        AS CP_FLAG,
            ISNULL(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '')              AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fcpc.TOTAL_NO_OF_OUTCOMES, '')                   AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fcpc.OUTCOME_COMMENTS, '')                       AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS icpc_icpc_outcome_json,
    fcpc.ORGANISED_BY_DEPT_ID                  AS icpc_icpc_team,          
    fcpc.ORGANISED_BY_USER_STAFF_ID            AS icpc_icpc_worker_id
FROM
    HDM.Child_Social.FACT_CP_CONFERENCE AS fcpc
JOIN
    HDM.Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p 
    ON CAST(p.DIM_PERSON_ID AS INT) = fcpc.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 

WHERE
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'
AND
    (fm.ACTUAL_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR fm.ACTUAL_DTTM IS NULL);
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cp_plans"}
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
-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cp_plans_view', 'V') IS NOT NULL 
DROP VIEW ssd_cp_plans_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cp_plans_view AS
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

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p 
    ON CAST(p.DIM_PERSON_ID AS INT) = cpp.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 

WHERE
    (cpp.END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR cpp.END_DTTM IS NULL);
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cp_visits"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cp_visits_view', 'V') IS NOT NULL 
DROP VIEW ssd_cp_visits_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cp_visits_view AS
WITH UniqueCasenotes AS (
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

    -- Join to core filtered view to filter relevant person records
    JOIN ssd_person_core_filtered_view AS p 
        ON CAST(p.DIM_PERSON_ID AS INT) = cn.DIM_PERSON_ID

    -- Join to get ssd_timeframe and other defined variables
    JOIN ssd_views_variables AS v 
        ON 1 = 1 

    WHERE
        cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC') 
        AND (cn.EVENT_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
        OR cn.EVENT_DTTM IS NULL)
)
SELECT
    cppv_cp_visit_id,  
    cppv_person_id,            
    cppv_cp_plan_id,  
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
FROM
    UniqueCasenotes
WHERE
    rn = 1;
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cp_reviews"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cp_reviews_view', 'V') IS NOT NULL 
DROP VIEW ssd_cp_reviews_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cp_reviews_view AS
SELECT
    cpr.FACT_CP_REVIEW_ID                    AS cppr_cp_review_id,
    cpr.FACT_CP_PLAN_ID                      AS cppr_cp_plan_id,
    cpr.DIM_PERSON_ID                        AS cppr_person_id,
    cpr.DUE_DTTM                             AS cppr_cp_review_due,
    cpr.MEETING_DTTM                         AS cppr_cp_review_date,
    fm.FACT_MEETING_ID                       AS cppr_cp_review_meeting_id,
    cpr.OUTCOME_CONTINUE_CP_FLAG             AS cppr_cp_review_outcome_continue_cp,
    (CASE WHEN ffa.ANSWER_NO = 'WasConf'
          AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
          THEN ffa.ANSWER END)               AS cppr_cp_review_quorate,    
    'SSD_PH'                                 AS cppr_cp_review_participation
FROM
    HDM.Child_Social.FACT_CP_REVIEW AS cpr
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm ON cpr.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms ON cpr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND cpr.DIM_PERSON_ID = fms.DIM_PERSON_ID
LEFT JOIN    
    HDM.Child_Social.FACT_FORM_ANSWERS ffa ON fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.ANSWER_NO = 'WasConf'
    AND fms.FACT_OUTCM_FORM_ID IS NOT NULL
    AND fms.FACT_OUTCM_FORM_ID <> '-1'

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p 
    ON CAST(p.DIM_PERSON_ID AS INT) = cpr.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1

WHERE
    (cpr.MEETING_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR cpr.MEETING_DTTM IS NULL)
GROUP BY 
    cpr.FACT_CP_REVIEW_ID,
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
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_episodes_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_episodes_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_episodes_view AS
WITH FilteredData AS (
    SELECT
        fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
        fce.FACT_CLA_PLACEMENT_ID               AS clae_cla_placement_id,
        CAST(fce.DIM_PERSON_ID AS NVARCHAR(48)) AS clae_person_id,
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
    -- Join to core filtered view for filtering
    JOIN 
        ssd_person_core_filtered_view AS p 
        ON CAST(p.DIM_PERSON_ID AS INT) = fce.DIM_PERSON_ID
    -- Join to get ssd_timeframe and other defined variables
    JOIN 
        ssd_views_variables AS v 
        ON 1 = 1 -- Ensure join avoids circular reference
    WHERE
        (fce.CARE_END_DATE >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE())
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
SELECT
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_placement_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need_code,
    clae_cla_episode_ceased,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_last_iro_contact_date,
    clae_entered_care_date
FROM
    FilteredData;
GO





-- META-END

-- META-CONTAINER: {"type": "view", "name": "ssd_cla_convictions"}
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


-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_convictions_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_convictions_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_convictions_view AS
SELECT 
    fo.FACT_OFFENCE_ID              AS clac_cla_conviction_id,
    fo.DIM_PERSON_ID                AS clac_person_id,
    fo.OFFENCE_DTTM                 AS clac_cla_conviction_date,
    fo.DESCRIPTION                  AS clac_cla_conviction_offence
FROM 
    HDM.Child_Social.FACT_OFFENCE AS fo
-- Join to core filtered view for filtering relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fo.DIM_PERSON_ID
-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular reference
WHERE EXISTS (
    -- only ssd relevant records
    SELECT 1 
    FROM ssd_person_core_filtered_view p -- Reference core filtered view for filtering
    WHERE CAST(p.DIM_PERSON_ID AS INT) = fo.DIM_PERSON_ID -- #DtoI-1799
);
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_health"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_health_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_health_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_health_view AS
SELECT
    fhc.FACT_HEALTH_CHECK_ID           AS clah_health_check_id,
    fhc.DIM_PERSON_ID                  AS clah_person_id,
    fhc.DIM_LOOKUP_EVENT_TYPE_DESC     AS clah_health_check_type,
    fhc.START_DTTM                     AS clah_health_check_date,
    fhc.DIM_LOOKUP_EXAM_STATUS_DESC    AS clah_health_check_status
FROM
    HDM.Child_Social.FACT_HEALTH_CHECK AS fhc
-- Join to core filtered view for filtering relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fhc.DIM_PERSON_ID
-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular reference
WHERE
    (fhc.START_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
    OR fhc.START_DTTM IS NULL);
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_immunisations"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_immunisations_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_immunisations_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_immunisations_view AS
WITH RankedImmunisations AS (
    SELECT
        fcla.DIM_PERSON_ID,
        fcla.IMMU_UP_TO_DATE_FLAG,
        fcla.LAST_UPDATED_DTTM,
        ROW_NUMBER() OVER (
            PARTITION BY fcla.DIM_PERSON_ID 
            ORDER BY fcla.LAST_UPDATED_DTTM DESC
        ) AS rn -- rank the order / most recent(rn==1)
    FROM
        HDM.Child_Social.FACT_CLA AS fcla
    -- Join to core filtered view for filtering relevant person records
    JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
        ON CAST(p.DIM_PERSON_ID AS INT) = fcla.DIM_PERSON_ID
    -- Join to get ssd_timeframe and other defined variables
    JOIN 
        ssd_views_variables AS v 
        ON 1 = 1 -- Ensure join avoids circular reference or ambiguity
)
SELECT
    DIM_PERSON_ID                        AS clai_person_id,
    IMMU_UP_TO_DATE_FLAG                 AS clai_immunisations_status,
    LAST_UPDATED_DTTM                    AS clai_immunisations_status_date
FROM
    RankedImmunisations
WHERE
    rn = 1; -- pull needed record based on rank==1/most recent record for each DIM_PERSON_ID
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_substance_misuse"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_substance_misuse_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_substance_misuse_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_substance_misuse_view AS
SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID           AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID                      AS clas_person_id,
    fsm.START_DTTM                         AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE     AS clas_substance_misused,
    fsm.ACCEPT_FLAG                        AS clas_intervention_received
FROM 
    HDM.Child_Social.FACT_SUBSTANCE_MISUSE AS fsm
JOIN ssd_person_core_filtered_view AS p 
    ON CAST(p.DIM_PERSON_ID AS INT) = fsm.DIM_PERSON_ID
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1;

GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_placement"}
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


-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_placement_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_placement_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_placement_view AS
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
    TRY_CAST(fcp.DISTANCE_FROM_HOME AS FLOAT)   AS clap_cla_placement_distance,                         
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
    CASE 
        WHEN LEN(LTRIM(RTRIM(fcp.POSTCODE))) <= 4 THEN NULL
        ELSE LTRIM(RTRIM(fcp.POSTCODE))        
    END                                         AS clap_cla_placement_postcode,
    fcp.END_DTTM                                AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE          AS clap_cla_placement_change_reason
FROM
    HDM.Child_Social.FACT_CLA_PLACEMENT AS fcp
-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fcp.DIM_PERSON_ID
-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular reference or ambiguity
WHERE 
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
                                            'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
                                            'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')
AND
    (fcp.END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use  `ssd_timeframe_years` variable from ssd_views_variables table
    OR fcp.END_DTTM IS NULL);
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_reviews"}
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

-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_reviews_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_reviews_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_reviews_view AS
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
    
-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fcr.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join avoids circular reference or ambiguity
WHERE  
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'
AND
    (fcr.MEETING_DTTM  >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
    OR fcr.MEETING_DTTM IS NULL)
GROUP BY fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID,
    ff.FACT_FORM_ID,
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE;
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_previous_permanence"}
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
-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_previous_permanence_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_previous_permanence_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_previous_permanence_view AS
WITH FilteredAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        ffa.FACT_FORM_ANSWER_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER
    FROM
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE
        ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'
        AND ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
        AND ffa.ANSWER IS NOT NULL
)
SELECT
    tmp_ffa.FACT_FORM_ID                           AS lapp_table_id,
    ff.DIM_PERSON_ID                               AS lapp_person_id,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_option,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_la,
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '')) = 0 
             AND CAST(ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '0') AS INT) BETWEEN 1 AND 31 
        THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zz' 
    END + '/' + 
    CASE 
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('January', 'Jan') THEN '01'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('February', 'Feb') THEN '02'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('March', 'Mar') THEN '03'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('April', 'Apr') THEN '04'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('May') THEN '05'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('June', 'Jun') THEN '06'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('July', 'Jul') THEN '07'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('August', 'Aug') THEN '08'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('September', 'Sep') THEN '09'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('October', 'Oct') THEN '10'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('November', 'Nov') THEN '11'
        WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('December', 'Dec') THEN '12'
        ELSE 'zz'
    END + '/' +
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '')) = 0 
        THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '') 
        ELSE 'zzzz'
    END AS lapp_previous_permanence_order_date
FROM
    FilteredAnswers tmp_ffa
JOIN
    HDM.Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID
    
-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = ff.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity
GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_care_plan"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.1
--             1.0: Fix Aggr warnings use of isnull() 310524 RH
--             0.1: Altered _json keys and groupby towards > clarity 190224 JH
-- Status: [R]elease
-- Remarks:    Added short codes to plan type questions to improve readability.
--             Removed form type filter, only filtering ffa. on ANSWER_NO.
-- Dependencies:
-- - ssd_person
-- - #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
-- - HDM.Child_Social.FACT_CARE_PLANS
-- - HDM.Child_Social.FACT_FORMS
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================


-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_care_plan_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_care_plan_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_care_plan_view AS
WITH MostRecentQuestionResponse AS (
    SELECT  -- Return the most recent response for each question for each person
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    JOIN
        HDM.Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID    -- obtain the relevant person_id
    WHERE
        ffa.ANSWER_NO IN ('CPFUP1', 'CPFUP10', 'CPFUP2', 'CPFUP3', 'CPFUP4', 'CPFUP5', 'CPFUP6', 'CPFUP7', 'CPFUP8', 'CPFUP9')
    GROUP BY
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO
),
LatestResponses AS (
    SELECT  -- Add the answered_date (only indirectly of use here/cross-referencing)
        mrqr.DIM_PERSON_ID,
        mrqr.ANSWER_NO,
        mrqr.MaxFormID      AS FACT_FORM_ID,
        ffa.ANSWER,
        ffa.ANSWERED_DTTM   AS LatestResponseDate
    FROM
        MostRecentQuestionResponse mrqr
    JOIN
        HDM.Child_Social.FACT_FORM_ANSWERS ffa ON mrqr.MaxFormID = ffa.FACT_FORM_ID AND mrqr.ANSWER_NO = ffa.ANSWER_NO
)
SELECT
    fcp.FACT_CARE_PLAN_ID AS lacp_table_id,
    fcp.DIM_PERSON_ID     AS lacp_person_id,
    fcp.START_DTTM        AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM          AS lacp_cla_care_plan_end_date,
    (
        SELECT  -- Combined _json field with 'ICP' responses
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END, '')), NULL) AS REMAINSUP,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN1M,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN6M,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURNEV,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTRELFR,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTFOST18,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RESPLMT,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END, '')), NULL) AS SUPPLIV,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END, '')), NULL) AS ADOPTION,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END, '')), NULL) AS OTHERPLN
        FROM
            LatestResponses tmp_cpl
        WHERE
            tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
        GROUP BY tmp_cpl.DIM_PERSON_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS lacp_cla_care_plan_json
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fcp.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variable(s)
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A';
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_cla_visits"}
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

 -- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_cla_visits_view', 'V') IS NOT NULL 
DROP VIEW ssd_cla_visits_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_cla_visits_view AS
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
    HDM.Child_Social.FACT_CASENOTES AS cn ON clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
    AND clav.DIM_PERSON_ID = cn.DIM_PERSON_ID

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = clav.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variable(s)
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVL')
AND 
    (cn.EVENT_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- Use `ssd_timeframe_years` variable from ssd_views_variables table
    OR cn.EVENT_DTTM IS NULL);
GO



-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_sdq_scores"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_sdq_scores_view', 'V') IS NOT NULL 
DROP VIEW ssd_sdq_scores_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_sdq_scores_view AS
SELECT
    ff.FACT_FORM_ID                     AS csdq_table_id,
    ff.DIM_PERSON_ID                    AS csdq_person_id,
    CAST('1900-01-01' AS DATETIME)      AS csdq_sdq_completed_date,
    (
        SELECT TOP 1
            CASE
                WHEN ISNUMERIC(ffa_inner.ANSWER) = 1 THEN CAST(ffa_inner.ANSWER AS INT)
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

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = ff.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variable(s)
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

WHERE EXISTS (
    SELECT 1
    FROM ssd_person_core_filtered_view p
    WHERE CAST(p.DIM_PERSON_ID AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
);
GO

 



-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_missing"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_missing_view', 'V') IS NOT NULL 
DROP VIEW ssd_missing_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_missing_view AS
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

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = fmp.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variable(s)
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

WHERE
    (fmp.END_DTTM >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fmp.END_DTTM IS NULL);
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_care_leavers"}
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_care_leavers_view', 'V') IS NOT NULL 
DROP VIEW ssd_care_leavers_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_care_leavers_view AS
WITH InvolvementHistoryCTE AS (
    SELECT
        fi.DIM_PERSON_ID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(fi.DIM_WORKER_ID, 0) ELSE NULL END) AS CurrentWorker,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(NULLIF(fi.FACT_WORKER_HISTORY_DEPARTMENT_ID, -1), 0) ELSE NULL END) AS AllocatedTeam,
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_ID ELSE NULL END) AS PersonalAdvisor
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE ORDER BY FACT_INVOLVEMENTS_ID DESC) AS rn,
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS')
            AND DIM_WORKER_ID <> -1
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
    ) fi
    GROUP BY fi.DIM_PERSON_ID
)
SELECT
    NEWID() AS clea_table_id,
    dce.DIM_PERSON_ID AS clea_person_id,
    CASE WHEN dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NULL THEN 'No Current Eligibility' ELSE dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC END AS clea_care_leaver_eligibility,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE AS clea_care_leaver_in_touch,
    fccl.IN_TOUCH_DTTM AS clea_care_leaver_latest_contact,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC AS clea_care_leaver_accommodation,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC AS clea_care_leaver_accom_suitable,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC AS clea_care_leaver_activity,
    MAX(ISNULL(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH' THEN fcp.MODIF_DTTM END, '1900-01-01')) AS clea_pathway_plan_review_date,
    ih.PersonalAdvisor AS clea_care_leaver_personal_advisor,
    ih.AllocatedTeam AS clea_care_leaver_allocated_team,
    ih.CurrentWorker AS clea_care_leaver_worker_id
FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
LEFT JOIN HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID

-- Join to core filtered view to filter relevant person records
JOIN ssd_person_core_filtered_view AS p -- Ref core view for filtering
    ON CAST(p.DIM_PERSON_ID AS INT) = dce.DIM_PERSON_ID

-- Join to get ssd_timeframe and other defined variables
JOIN ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

WHERE EXISTS (
    SELECT 1 FROM ssd_person_core_filtered_view p WHERE CAST(p.DIM_PERSON_ID AS INT) = dce.DIM_PERSON_ID
)
GROUP BY dce.DIM_CLA_ELIGIBILITY_ID, fccl.FACT_CLA_CARE_LEAVERS_ID, dce.DIM_PERSON_ID, dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE, fccl.IN_TOUCH_DTTM, fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC, fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC, ih.PersonalAdvisor, ih.CurrentWorker, ih.AllocatedTeam;
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_permanence"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_permanence_view', 'V') IS NOT NULL 
DROP VIEW ssd_permanence_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_permanence_view AS
WITH RankedPermanenceData AS (
    -- CTE to rank permanence rows for each person, used to assist in filtering duplicates towards perm_table_id

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
        CAST('1900/01/01' AS DATETIME)                    AS perm_placed_foster_carer_date,         -- Placeholder data
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
            PARTITION BY p.LEGACY_ID                     -- Partition on person identifier
            ORDER BY CAST(RIGHT(CASE 
                                    WHEN (fa.DIM_PERSON_ID = fce.DIM_PERSON_ID)
                                    THEN CONCAT(fa.FACT_ADOPTION_ID, fce.FACT_CARE_EPISODES_ID)
                                    ELSE fce.FACT_CARE_EPISODES_ID 
                                END, 5) AS INT) DESC    -- Sort by last 5 digits coerced to INT
        )                                                 AS rn -- We only want rn == 1
    FROM HDM.Child_Social.FACT_CARE_EPISODES fce

    LEFT JOIN HDM.Child_Social.FACT_ADOPTION AS fa ON fa.DIM_PERSON_ID = fce.DIM_PERSON_ID AND fa.START_DTTM IS NOT NULL
    LEFT JOIN HDM.Child_Social.FACT_CLA AS fc ON fc.FACT_CLA_ID = fce.FACT_CLA_ID -- Test if needed
    LEFT JOIN HDM.Child_Social.FACT_CLA_PLACEMENT AS fcpl ON fcpl.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
        AND fcpl.FACT_CLA_PLACEMENT_ID <> '-1'
        AND (fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3', 'A4', 'A5', 'A6') OR fcpl.FFA_IS_PLAN_DATE IS NOT NULL)

    LEFT JOIN HDM.Child_Social.DIM_PERSON p ON fce.DIM_PERSON_ID = p.DIM_PERSON_ID

    -- Join to get ssd_timeframe and other defined variables
    JOIN ssd_views_variables AS v 
        ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity

    WHERE ((fce.PLACEND IS NULL AND fa.START_DTTM IS NOT NULL)
        OR fce.CARE_REASON_END_CODE IN ('E48', 'E1', 'E44', 'E12', 'E11', 'E43', '45', 'E41', 'E45', 'E47', 'E46'))
        AND fce.DIM_PERSON_ID <> '-1'
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
    ( -- Only relevant SSD records
    SELECT 1
    FROM ssd_person_core_filtered_view p  -- Referencing the filtered core view
    WHERE CAST(p.DIM_PERSON_ID AS INT) = perm_person_id -- This is an NVARCHAR(48) equality link
    );
GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_professionals"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.2
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_professionals_view', 'V') IS NOT NULL 
DROP VIEW ssd_professionals_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_professionals_view AS
SELECT 
    dw.DIM_WORKER_ID                        AS prof_professional_id,                -- system-based ID for workers
    TRIM(dw.STAFF_ID)                       AS prof_staff_id,                       -- Trimmed to remove non-printing chars
    CONCAT(dw.FORENAME, ' ', dw.SURNAME)    AS prof_professional_name,              -- Allocated or assigned worker name
    dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,  -- Social worker registration number, if present
    ''                                      AS prof_agency_worker_flag,             -- Placeholder for agency worker flag
    dw.JOB_TITLE                            AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)                 AS prof_professional_caseload,          -- Number of open cases (default is 0)
    dw.DEPARTMENT_NAME                      AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY                AS prof_full_time_equivalency,
    v.CaseloadLastSept30th,                 -- Expose CaseloadLastSept30th for use in the subquery
    v.CaseloadTimeframeStartDate            -- Expose CaseloadTimeframeStartDate for use in the subquery
FROM 
    HDM.Child_Social.DIM_WORKER AS dw
    
-- Join to get ssd_timeframe and other defined variables
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity
LEFT JOIN (
    SELECT 
        DIM_WORKER_ID,
        COUNT(*) AS OpenCases
    FROM 
        HDM.Child_Social.FACT_REFERRALS
    WHERE 
        REFRL_START_DTTM <= (SELECT CaseloadLastSept30th FROM ssd_views_variables) -- Access CaseloadLastSept30th directly
        AND (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM >= (SELECT CaseloadLastSept30th FROM ssd_views_variables))
        AND REFRL_START_DTTM >= (SELECT CaseloadTimeframeStartDate FROM ssd_views_variables) -- Access CaseloadTimeframeStartDate directly
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID
WHERE 
    dw.DIM_WORKER_ID <> -1
    AND TRIM(dw.STAFF_ID) IS NOT NULL          -- Filter to avoid unknown staff IDs
    AND LOWER(TRIM(dw.STAFF_ID)) <> 'unknown';
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_department"}
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

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_department_view', 'V') IS NOT NULL 
DROP VIEW ssd_department_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_department_view AS
SELECT 
    dpt.DIM_DEPARTMENT_ID       AS dept_team_id,
    dpt.NAME                    AS dept_team_name,
    dpt.DEPT_ID                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name
FROM 
    HDM.Child_Social.DIM_DEPARTMENT dpt
WHERE 
    dpt.dim_department_id <> -1;
GO



-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_involvements"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.2:
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
-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_involvements_view', 'V') IS NOT NULL 
DROP VIEW ssd_involvements_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_involvements_view AS
SELECT
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    CASE 
        -- replace admin -1 values for when no worker associated
        WHEN fi.DIM_WORKER_ID IN ('-1', -1) THEN NULL
        ELSE fi.DIM_WORKER_ID 
    END                                           AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    CASE 
        WHEN fi.DIM_DEPARTMENT_ID IS NOT NULL AND fi.DIM_DEPARTMENT_ID != -1 THEN fi.DIM_DEPARTMENT_ID
        ELSE CASE 
            -- replace system -1 values for when no worker associated
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
    
-- Join to get ssd_timeframe_ or other defined variable(s)
JOIN 
    ssd_views_variables AS v 
    ON 1 = 1 -- Ensure join does not introduce a circular reference or ambiguity 
WHERE
    (fi.END_DTTM  >= DATEADD(YEAR, -v.ssd_timeframe_years, GETDATE()) 
    OR fi.END_DTTM IS NULL)
AND EXISTS (
    SELECT 1
    FROM ssd_person_core_filtered_view p -- Use core filtered view for relevant records
    WHERE CAST(p.DIM_PERSON_ID AS INT) = fi.DIM_PERSON_ID -- only ssd relevant records
);
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_linked_identifiers"}
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


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_linked_identifiers_view', 'V') IS NOT NULL 
DROP VIEW ssd_linked_identifiers_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_linked_identifiers_view AS
SELECT
    NEWID()                                AS link_table_id,
    csp.dim_person_id                      AS link_person_id,
    CASE 
        WHEN csp.former_upn IS NOT NULL THEN 'Former Unique Pupil Number'
        WHEN csp.upn IS NOT NULL THEN 'Unique Pupil Number'
    END                                    AS link_identifier_type,
    'SSD_PH'                               AS link_identifier_value,  -- Placeholder for testing
    NULL                                   AS link_valid_from_date,
    NULL                                   AS link_valid_to_date
FROM
    HDM.Child_Social.DIM_PERSON csp
-- Ensure only relevant SSD records are included
JOIN 
    ssd_person_core_filtered_view AS p 
    ON p.DIM_PERSON_ID = csp.dim_person_id
WHERE
    csp.former_upn IS NOT NULL OR csp.upn IS NOT NULL;
GO




/* END SSD main extract */
/* ********************************************************************************************************** */





/* Start 

         SSDF Other DfE projects (e.g. 1b, 2(a,b) elements extracts 
        
        */


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_s251_finance"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================


-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_s251_finance_view', 'V') IS NOT NULL 
DROP VIEW ssd_s251_finance_view;
GO

-- META-ELEMENT: {"type": "create_view"} 
CREATE VIEW ssd_s251_finance_view AS
SELECT 
    NEWID()                               AS s251_table_id,
    'SSD_PH'                              AS s251_cla_placement_id, -- Placeholder 
    'SSD_PH'                              AS s251_placeholder_1, -- Placeholder 
    'SSD_PH'                              AS s251_placeholder_2, -- Placeholder 
    'SSD_PH'                              AS s251_placeholder_3, -- Placeholder 
    'SSD_PH'                              AS s251_placeholder_4 -- Placeholder 
    ;
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_voice_of_child"}
-- =============================================================================
-- Object Name: ssd_voice_of_child
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================



-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_voice_of_child_view', 'V') IS NOT NULL 
DROP VIEW ssd_voice_of_child_view;
GO

-- META-ELEMENT: {"type": "create_view"} 
CREATE VIEW ssd_voice_of_child_view AS
SELECT 
    NEWID()                                AS voch_table_id,
    p.DIM_PERSON_ID                        AS voch_person_id,
    'Y'                                    AS voch_explained_worries,     -- Placeholder 
    'Y'                                    AS voch_story_help_understand, -- Placeholder 
    'Y'                                    AS voch_agree_worker,          -- Placeholder 
    'Y'                                    AS voch_plan_safe,             -- Placeholder 
    'Y'                                    AS voch_tablet_help_explain    -- Placeholder 
FROM 
    ssd_person_core_filtered_view AS p           
WHERE EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person_core_filtered_view sp
    WHERE sp.DIM_PERSON_ID = p.DIM_PERSON_ID
    );

GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_pre_proceedings"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================



-- META-ELEMENT: {"type": "drop_view"} 
IF OBJECT_ID('ssd_pre_proceedings_view', 'V') IS NOT NULL 
DROP VIEW ssd_pre_proceedings_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_pre_proceedings_view AS
SELECT
    NEWID()                                  AS prep_table_id,                  -- Generate unique id
    p.DIM_PERSON_ID                          AS prep_person_id,
    'PLO_FAMILY1'                            AS prep_plo_family_id,             -- Placeholder 
    '1900-01-01'                             AS prep_pre_pro_decision_date,     -- Placeholder 
    '1900-01-01'                             AS prep_initial_pre_pro_meeting_date, -- Placeholder
    'Outcome1'                               AS prep_pre_pro_outcome,           -- Placeholder 
    '1900-01-01'                             AS prep_agree_stepdown_issue_date, -- Placeholder 
    3                                        AS prep_cp_plans_referral_period,  -- Placeholder 
    'Approved'                               AS prep_legal_gateway_outcome,     -- Placeholder 
    2                                        AS prep_prev_pre_proc_child,       -- Placeholder
    1                                        AS prep_prev_care_proc_child,      -- Placeholder 
    '1900-01-01'                             AS prep_pre_pro_letter_date,       -- Placeholder 
    '1900-01-01'                             AS prep_care_pro_letter_date,      -- Placeholder 
    2                                        AS prep_pre_pro_meetings_num,      -- Placeholder 
    'Y'                                      AS prep_pre_pro_parents_legal_rep, -- Placeholder 
    'NA'                                     AS prep_parents_legal_rep_point_of_issue, -- Placeholder 
    'COURT_REF_1'                            AS prep_court_reference,           -- Placeholder 
    1                                        AS prep_care_proc_court_hearings,  -- Placeholder 
    'Y'                                      AS prep_care_proc_short_notice,    -- Placeholder 
    'Reason1'                                AS prep_proc_short_notice_reason,  -- Placeholder
    'Y'                                      AS prep_la_inital_plan_approved,   -- Placeholder 
    'Initial Plan 1'                         AS prep_la_initial_care_plan,      -- Placeholder
    'Y'                                      AS prep_la_final_plan_approved,    -- Placeholder 
    'Final Plan 1'                           AS prep_la_final_care_plan         -- Placeholder 
FROM 
    ssd_person_core_filtered_view AS p            

WHERE EXISTS 
    ( -- Only ssd relevant records
    SELECT 1 
    FROM ssd_person_core_filtered_view sp
    WHERE sp.DIM_PERSON_ID = p.DIM_PERSON_ID
    );

GO



-- META-END



/* End

        SSDF Other projects elements extracts 
        
        */



/* Start 

        Non-Core Liquid Logic elements extracts (E.g. SEND/EH Module data)
        
        */




-- META-CONTAINER: {"type": "view", "name": "ssd_send"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
--             0.1: upn _unknown size change in line with DfE to 4 160524 RH
-- Status: [P]laceholder
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled locally if accessible. 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_903_DATA
-- - HDM.Education.DIM_PERSON
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_send_view', 'V') IS NOT NULL 
DROP VIEW ssd_send_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_send_view AS
SELECT
    NEWID()             AS send_table_id,          -- Generate unique ID
    p.DIM_PERSON_ID     AS send_person_id,
    'SSD_PH'            AS send_upn,               -- Placeholder for UPN
    'SSD_PH'            AS send_uln,               -- Placeholder for ULN
    'SSD_PH'            AS send_upn_unknown        -- Placeholder for UPN unknown flag
FROM
    ssd_person_core_filtered_view AS p           -- Using core filtered view to ensure correct filtering

WHERE
    EXISTS (
        SELECT 1
        FROM ssd_person_core_filtered_view sp
        WHERE sp.DIM_PERSON_ID = p.DIM_PERSON_ID
    );

GO





-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_sen_need"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks:
-- Dependencies:
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_sen_need_view', 'V') IS NOT NULL 
DROP VIEW ssd_sen_need_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_sen_need_view AS
SELECT 
    NEWID()     AS senn_table_id,                -- Generate unique id
    'SSD_PH'    AS senn_active_ehcp_id,          -- Placeholder
    'SSD_PH'    AS senn_active_ehcp_need_type,   -- Placeholder 
    '0'         AS senn_active_ehcp_need_rank    -- Placeholder
    ;
GO




-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_ehcp_requests"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_ehcp_requests_view', 'V') IS NOT NULL 
DROP VIEW ssd_ehcp_requests_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_ehcp_requests_view AS
SELECT 
    'SSD_PH'                        AS ehcr_ehcp_request_id,      -- Placeholder 
    'SSD_PH'                        AS ehcr_send_table_id,        -- Placeholder
    CAST('1900-01-01' AS DATETIME)  AS ehcr_ehcp_req_date,        -- Placeholder
    CAST('1900-01-01' AS DATETIME)  AS ehcr_ehcp_req_outcome_date,-- Placeholder
    'SSD_PH'                        AS ehcr_ehcp_req_outcome      -- Placeholder 
    ;
GO



-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_ehcp_assessment"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================


-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_ehcp_assessment_view', 'V') IS NOT NULL 
DROP VIEW ssd_ehcp_assessment_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_ehcp_assessment_view AS
SELECT 
    'SSD_PH'            AS ehca_ehcp_assessment_id,                 -- Placeholder 
    'SSD_PH'            AS ehca_ehcp_request_id,                    -- Placeholder 
    CAST('1900-01-01'   AS DATETIME) AS ehca_ehcp_assessment_outcome_date,  -- Placeholder 
    'SSD_PH'            AS ehca_ehcp_assessment_outcome,            -- Placeholder
    'SSD_PH'            AS ehca_ehcp_assessment_exceptions          -- Placeholder
    ;
GO



-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_ehcp_named_plan"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_ehcp_named_plan_view', 'V') IS NOT NULL 
DROP VIEW ssd_ehcp_named_plan_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_ehcp_named_plan_view AS
SELECT
    NEWID()                            AS ehcn_named_plan_id,             -- Generate unique ID as placeholder
    'SSD_PH'                           AS ehcn_ehcp_asmt_id,              -- Placeholder for EHCP assessment ID
    CAST('1900-01-01' AS DATETIME)     AS ehcn_named_plan_start_date,     -- Placeholder for Named Plan Start Date
    CAST('1900-01-01' AS DATETIME)     AS ehcn_named_plan_ceased_date,    -- Placeholder for Named Plan Ceased Date
    'No Reason Provided'               AS ehcn_named_plan_ceased_reason   -- Placeholder for Named Plan Ceased Reason
;
GO


-- META-END


-- META-CONTAINER: {"type": "view", "name": "ssd_ehcp_active_plans"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_view"}
IF OBJECT_ID('ssd_ehcp_active_plans_view', 'V') IS NOT NULL 
DROP VIEW ssd_ehcp_active_plans_view;
GO

-- META-ELEMENT: {"type": "create_view"}
CREATE VIEW ssd_ehcp_active_plans_view AS
SELECT
    NEWID()                            AS ehcp_active_ehcp_id,              -- Generate unique ID as placeholder
    'SSD_PH'                           AS ehcp_ehcp_request_id,             -- Placeholder for EHCP Request ID
    CAST('1900-01-01' AS DATETIME)     AS ehcp_active_ehcp_last_review_date -- Placeholder for EHCP Last Review Date
;
GO


-- META-END






/* End

        Non-Core Liquid Logic elements extracts 
        
        */
/* ********************************************************************************************************** */




/* ********************************************************************************************************** */

/* Start

        SSD Object Constraints

        */


/* Start

        SSD Extract Logging
        */





-- META-CONTAINER: {"type": "view", "name": "ssd_extract_log"}
-- =============================================================================
-- Description: Enable LA extract overview logging
-- Author: D2I
-- Version: 0.1
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - 
-- =============================================================================





-- META-END


/* Start

        Non-SDD Bespoke extract mods
        
        Examples of how to build on the ssd with bespoke additional fields. These can be 
        refreshed|incl. within the rebuild script and rebuilt at the same time as the SSD
        Changes should be limited to additional, non-destructive enhancements that do not
        alter the core structure of the SSD. 
        */




-- META-CONTAINER: {"type": "view", "name": "involvements_history"}
-- =============================================================================
-- ssd_non_core_modification
-- MOD Name: involvements history, involvements type history
-- Description: 
-- Author: D2I
-- Version: 0.2
--             0.1: involvement_history_json size change from 4000 to max fix trunc err 040724 RH
-- Status: [DT]ataTesting
-- Remarks: The addition of these MOD columns is overhead heavy. This is <especially> noticable 
--          on larger dimension versions of ssd_person (i.e. > 40k).
--          Recommend that this MOD is switched off during any test runs|peak-time extract runs
-- Dependencies: 
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- - ssd_person
-- =============================================================================


-- META-ELEMENT: {"type": "alter_view"}
ALTER VIEW ssd_person_view AS
WITH InvolvementHistoryCTE AS (
    SELECT 
        fi.DIM_PERSON_ID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.DIM_WORKER_ID END) AS CurrentWorkerID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END) AS AllocatedTeam,
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_ID END) AS PersonalAdvisorID,
        JSON_QUERY(( 
            SELECT 
                ISNULL(fi2.FACT_INVOLVEMENTS_ID, '') AS INVOLVEMENT_ID,
                ISNULL(fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '') AS INVOLVEMENT_TYPE_CODE,
                ISNULL(fi2.START_DTTM, '') AS START_DATE, 
                ISNULL(fi2.END_DTTM, '') AS END_DATE, 
                ISNULL(fi2.DIM_WORKER_ID, '') AS WORKER_ID, 
                ISNULL(fi2.DIM_DEPARTMENT_ID, '') AS DEPARTMENT_ID
            FROM 
                HDM.Child_Social.FACT_INVOLVEMENTS fi2
            WHERE 
                fi2.DIM_PERSON_ID = fi.DIM_PERSON_ID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS involvement_history
    FROM (
        SELECT *,
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE 
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
            AND DIM_WORKER_ID IS NOT NULL
            AND DIM_WORKER_ID <> -1
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
    ) fi
    WHERE 
        EXISTS (
            SELECT 1 FROM ssd_person_core_filtered_view p -- Use core view instead
            WHERE CAST(p.DIM_PERSON_ID AS INT) = fi.DIM_PERSON_ID
        )
    GROUP BY 
        fi.DIM_PERSON_ID
),
InvolvementTypeStoryCTE AS (
    SELECT 
        fi.DIM_PERSON_ID,
        STUFF((
            SELECT CONCAT(',', '"', fi3.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '"')
            FROM HDM.Child_Social.FACT_INVOLVEMENTS fi3
            WHERE fi3.DIM_PERSON_ID = fi.DIM_PERSON_ID
            AND EXISTS (
                SELECT 1 FROM ssd_person_core_filtered_view p -- Use core view instead
                WHERE CAST(p.DIM_PERSON_ID AS INT) = fi3.DIM_PERSON_ID
            )
            ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
            FOR XML PATH('')
        ), 1, 1, '') AS InvolvementTypeStory
    FROM 
        HDM.Child_Social.FACT_INVOLVEMENTS fi
    WHERE 
        EXISTS (
            SELECT 1 FROM ssd_person_core_filtered_view p -- Use core view instead
            WHERE CAST(p.DIM_PERSON_ID AS INT) = fi.DIM_PERSON_ID
        )
    GROUP BY 
        fi.DIM_PERSON_ID
)
SELECT 
    p.*,
    ih.involvement_history AS pers_involvement_history_json,
    CONCAT('[', its.InvolvementTypeStory, ']') AS pers_involvement_type_story
FROM 
    ssd_person_core_filtered_view AS p  -- Use core filtered view here instead of person_view
LEFT JOIN InvolvementHistoryCTE ih ON CAST(p.DIM_PERSON_ID AS INT) = ih.DIM_PERSON_ID
LEFT JOIN InvolvementTypeStoryCTE its ON CAST(p.DIM_PERSON_ID AS INT) = its.DIM_PERSON_ID;
GO


-- META-END



