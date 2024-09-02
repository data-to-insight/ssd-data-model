
/*
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

Script creates labelled persistent(unless set otherwise) tables in your existing|specified database. 
There is no data sharing, and no changes to your existing systems are required. Data tables(with data copied 
from the raw CMS tables) and indexes for the SSD are created, and therefore in some cases will need support 
and/or agreement from either your IT or Intelligence team. The SQL script is always non-destructive, i.e. it 
does nothing to your existing data/tables/anything - the SSD process is simply a series of SELECT statements, 
pulling copied data into a new standardised field and table structure on your own system for access by only 
you/your LA.
*/


/* **********************************************************************************************************

Notes: 
This version of the SSD script creates persistant _perm tables. A version that instead creates _temp|session 
tables is also available to enable those restricted to read access on the cms db|schema.   

There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results; similarly some test related 
console outputs remain to aid such as run-time problem solving. These [TESTING] blocks can/will be removed. 

/*
Dev Objact & Item Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [AR]waitingReview,  -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder
*/

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
********************************************************************************************************** */
/* Development set up */

GO 
SET NOCOUNT ON;


/* ********************************************************************************************************** */
/* START SSD extract set up */

-- Point to DB/TABLE_CATALOG if required (SSD tables created here)
USE HDM_Local; 

-- ssd extract time-frame (YRS)
DECLARE @ssd_timeframe_years INT = 6;
DECLARE @ssd_sub1_range_years INT = 1;

-- store date on which CASELOAD count required. Currently : Most recent past Sept30th
DECLARE @LastSept30th DATE; 

/* END SSD extract set up */
/* ********************************************************************************************************** */



-- Run SSD into Temporary OR Persistent extract structure
-- 
DECLARE @Run_SSD_As_Temporary_Tables BIT;
SET     @Run_SSD_As_Temporary_Tables = 0;   -- 1==Single use SSD extract uses tempdb..# | 0==Persistent SSD table set up
                                            -- This flag enables/disables running such as FK constraints that don't apply to tempdb..# implementation

DECLARE @sql NVARCHAR(MAX) = N'';           -- used in both clean-up and logging







/* ********************************************************************************************************** */
/* Start [TESTING] Set up (these towards simplistic TEST run outputs and logging*/

 /* Simplistic run-time monitoring outputs (to be removed from live v2+)
*/
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder'; -- Note: also/seperately use @table_name in non-test|live elements of script. 

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Script start time

/* END [TESTING] Set up (these towards simplistic TEST run outputs and logging*/
/* ********************************************************************************************************** */








/* ********************************************************************************************************** */
/* START SSD public versioning infos */


/* 
=============================================================================
Object Name: ssd_version_log
Description: maintain SSD versioning meta data
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: SSD extract metadata enabling version consistency across LAs. 
Dependencies: 
- None
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_version_log_v';


-- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_version_log_v', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_version_log_v;
IF OBJECT_ID('tempdb..#ssd_version_log', 'U') IS NOT NULL DROP TABLE #ssd_version_log;


-- create versioning information object
CREATE TABLE ssd_development.ssd_version_log_v (
    version_number      NVARCHAR(10) NOT NULL,          -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                  -- date of version release
    description         NVARCHAR(100),                  -- brief description of version
    is_current          BIT NOT NULL DEFAULT 0,         -- flag to indicate if this is the current version
    created_at          DATETIME DEFAULT GETDATE(),     -- timestamp when record was created
    created_by          NVARCHAR(10),                   -- which user created the record
    impact_description  NVARCHAR(255)                   -- additional notes on the impact of the release
);

-- ensure any previous current-version flag is set to 0 (not current), before adding new current version
UPDATE ssd_development.ssd_version_log_v SET is_current = 0 WHERE is_current = 1;


-- insert & update current version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_development.ssd_version_log_v 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.0', GETDATE(), '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', 1, 'admin', 'impacts all _team fields, AAL7 outputs');


-- historic versioning log data
INSERT INTO ssd_development.ssd_version_log_v (version_number, release_date, description, is_current, created_by, impact_description)
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
    ('1.1.9', '2024-07-29', 'Applied CAST(person_id) + minor fixes', 0, 'admin', 'impacts all tables using where exists');


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;



/* ********************************************************************************************************** */
/* START SSD main extract */


/*
=============================================================================
Object Name: ssd_person
Description: Person/child details. This the most connected table in the SSD.
Author: D2I
Version: 1.1
            1.0: fixes to where filter in-line with existing cincplac reorting 040724 JH
            0.2: upn _unknown size change in line with DfE to 4 160524 RH
            0.1: Additional inclusion criteria added to capture care leavers 120324 JH
Status: [R]elease
Remarks:    
            Note: Due to part reliance on 903 table, be aware that if 903 not populated pre-ssd run, 
            this/subsequent queries can return v.low|unexpected row counts.
Dependencies:
- HDM.Child_Social.DIM_PERSON
- HDM.Child_Social.FACT_REFERRALS
- HDM.Child_Social.FACT_CONTACTS
- HDM.Child_Social.FACT_903_DATA
- HDM.Child_Social.FACT_CLA_CARE_LEAVERS
- HDM.Child_Social.DIM_CLA_ELIGIBILITY
=============================================================================
*/

-- check exists & drop
IF OBJECT_ID('ssd_development.ssd_person_v') IS NOT NULL DROP VIEW ssd_development.ssd_person_v;

GO

-- Create View
CREATE VIEW ssd_development.ssd_person_v AS
WITH f903_data_CTE AS (
    SELECT 
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        HDM.Child_Social.fact_903_data
)
SELECT
    p.LEGACY_ID AS pers_legacy_id,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)) AS pers_person_id,
    p.GENDER_MAIN_CODE AS pers_sex,
    p.NHS_NUMBER AS pers_gender,
    p.ETHNICITY_MAIN_CODE AS pers_ethnicity,
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM
        ELSE NULL 
    END AS pers_dob,
    NULL AS pers_common_child_id,
    COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS pers_upn_unknown,
    p.EHM_SEN_FLAG AS pers_send_flag,
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'
        THEN p.BIRTH_DTTM
        ELSE NULL 
    END AS pers_expected_dob,
    p.DEATH_DTTM AS pers_death_date,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND              
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI')
        THEN 'Y'
        ELSE NULL 
    END AS pers_is_mother,
    p.NATNL_CODE AS pers_nationality,
    1 AS ssd_flag
FROM
    HDM.Child_Social.DIM_PERSON AS p
LEFT JOIN (
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
    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
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
                AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' 
                OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL OR fi.IS_ALLOCATED_CW_FLAG = 'Y')
                AND START_DTTM > '2009-12-04 00:54:49.947'
                AND DIM_WORKER_ID <> '-1' 
                AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE()))
            )
        )
    );




/* 
=============================================================================
Object Name: ssd_family
Description: Contains the family connections for each person
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
Dependencies: 
- FACT_CONTACTS
- ssd.ssd_person
=============================================================================
*/

-- check exists & drop
IF OBJECT_ID('ssd_development.ssd_family_v') IS NOT NULL DROP VIEW ssd_development.ssd_family_v;

-- Create View
CREATE VIEW ssd_development.ssd_family_v AS
SELECT 
    fc.EXTERNAL_ID AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID AS fami_family_id,
    fc.DIM_PERSON_ID AS fami_person_id
FROM HDM.Child_Social.FACT_CONTACTS AS fc
WHERE EXISTS 
    (
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_address_v
Description: Contains full address details for every person 
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: Need to verify json obj structure on pre-2014 SQL server instances
Dependencies: 
- ssd_person
- DIM_PERSON_ADDRESS
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_address_v') IS NOT NULL DROP VIEW ssd_development.ssd_address_v;

-- Create View
CREATE VIEW ssd_development.ssd_address_v AS
SELECT 
    pa.DIM_PERSON_ADDRESS_ID AS addr_table_id,
    pa.DIM_PERSON_ID AS addr_person_id,
    pa.ADDSS_TYPE_CODE AS addr_address_type,
    pa.START_DTTM AS addr_address_start_date,
    pa.END_DTTM AS addr_address_end_date,
    CASE 
        WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', ''))) THEN ''
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''
        ELSE REPLACE(pa.POSTCODE, ' ', '')
    END AS addr_address_postcode,
    (
        SELECT 
            ISNULL(pa.ROOM_NO, '') AS ROOM, 
            ISNULL(pa.FLOOR_NO, '') AS FLOOR, 
            ISNULL(pa.FLAT_NO, '') AS FLAT, 
            ISNULL(pa.BUILDING, '') AS BUILDING, 
            ISNULL(pa.HOUSE_NO, '') AS HOUSE, 
            ISNULL(pa.STREET, '') AS STREET, 
            ISNULL(pa.TOWN, '') AS TOWN,
            ISNULL(pa.UPRN, '') AS UPRN,
            ISNULL(pa.EASTING, '') AS EASTING,
            ISNULL(pa.NORTHING, '') AS NORTHING
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS addr_address_json
FROM 
    HDM.Child_Social.DIM_PERSON_ADDRESS AS pa
WHERE EXISTS 
    (
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_disability_v
Description: Contains the Y/N flag for persons with disability
Author: D2I
Version: 1.0
            0.1: Removed disability_code replace() into Y/N flag 130324 RH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_DISABILITY
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_disability_v') IS NOT NULL DROP VIEW ssd_development.ssd_disability_v;

-- Create View
CREATE VIEW ssd_development.ssd_disability_v AS
SELECT 
    fd.FACT_DISABILITY_ID AS disa_table_id, 
    fd.DIM_PERSON_ID AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE AS disa_disability_code
FROM 
    HDM.Child_Social.FACT_DISABILITY AS fd
WHERE EXISTS 
    (
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fd.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_immigration_status_v (UASC)
Description:
Author: D2I
Version: 1.0
            0.9 rem ims.DIM_LOOKUP_IMMGR_STATUS_DESC rpld with _CODE 270324 JH 
Status: [R]elease
Remarks: Replaced IMMIGRATION_STATUS_CODE with IMMIGRATION_STATUS_DESC and
            increased field size to 100
Dependencies:
- ssd_person
- FACT_IMMIGRATION_STATUS
=============================================================================
*/
 -- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_immigration_status_v') IS NOT NULL DROP VIEW ssd_development.ssd_immigration_status_v;

-- Create View
CREATE VIEW ssd_development.ssd_immigration_status_v AS
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID AS immi_immigration_status_id,
    ims.DIM_PERSON_ID AS immi_person_id,
    ims.START_DTTM AS immi_immigration_status_start_date,
    ims.END_DTTM AS immi_immigration_status_end_date,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC AS immi_immigration_status
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims
WHERE
    EXISTS
    (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = ims.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_mother_v
Description: Contains parent-child relations between mother-child 
Author: D2I
Version: 1.0
            0.2: updated to exclude relationships with an end date 280224 JH
Status: [R]elease
Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
Dependencies: 
- ssd_person
- FACT_PERSON_RELATION
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_mother_v') IS NOT NULL DROP VIEW ssd_development.ssd_mother_v;

-- Create View
CREATE VIEW ssd_development.ssd_mother_v AS
SELECT
    fpr.FACT_PERSON_RELATION_ID AS moth_table_id,
    fpr.DIM_PERSON_ID AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB AS moth_childs_dob
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr
JOIN
    HDM.Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> 'M'
    AND fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI'
    AND fpr.END_DTTM IS NULL
    AND EXISTS
    (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = fpr.DIM_PERSON_ID
    );





/* 
=============================================================================
Object Name: ssd_legal_status_v
Description: 
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_LEGAL_STATUS
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_legal_status_v') IS NOT NULL DROP VIEW ssd_development.ssd_legal_status_v;

-- Create View
CREATE VIEW ssd_development.ssd_legal_status_v AS
SELECT
    fls.FACT_LEGAL_STATUS_ID AS lega_legal_status_id,
    fls.DIM_PERSON_ID AS lega_person_id,
    fls.DIM_LOOKUP_LGL_STATUS_DESC AS lega_legal_status,
    fls.START_DTTM AS lega_legal_status_start_date,
    fls.END_DTTM AS lega_legal_status_end_date
FROM
    HDM.Child_Social.FACT_LEGAL_STATUS AS fls
WHERE 
    (fls.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    OR fls.END_DTTM IS NULL)
AND EXISTS
    (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fls.DIM_PERSON_ID
    );



/* 
=============================================================================
Object Name: ssd_contacts
Description: 
Author: D2I
Version: 1.1
            1.0: cont_contact_outcome_json size 500 to 4000 to include COMMENTS 160724 RH
            1.0: fc.TOTAL_NO_OF_OUTCOMES added to cont_contact_outcome_json #DtoI-1796 160724 RH 
            1.0: fc.OUTCOME_COMMENTS added to cont_contact_outcome_json #DtoI-1796 160724 RH
            0.2: cont_contact_source_code field name edit 260124 RH
            0.1: cont_contact_source_desc added RH
Status: [R]elease
Remarks:Inclusion in contacts might differ between LAs. 
        Baseline definition:
        Contains safeguarding and referral to early help data.
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_contacts_v') IS NOT NULL DROP VIEW ssd_development.ssd_contacts_v;

-- Create View
CREATE VIEW ssd_development.ssd_contacts_v AS
SELECT 
    fc.FACT_CONTACT_ID AS cont_contact_id,
    fc.DIM_PERSON_ID AS cont_person_id,
    fc.CONTACT_DTTM AS cont_contact_date,
    fc.DIM_LOOKUP_CONT_SORC_ID AS cont_contact_source_code,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC AS cont_contact_source_desc,
    (   -- Create JSON string for outcomes
        SELECT 
            ISNULL(fc.OUTCOME_NEW_REFERRAL_FLAG, '') AS NEW_REFERRAL_FLAG,
            ISNULL(fc.OUTCOME_EXISTING_REFERRAL_FLAG, '') AS EXISTING_REFERRAL_FLAG,
            ISNULL(fc.OUTCOME_CP_ENQUIRY_FLAG, '') AS CP_ENQUIRY_FLAG,
            ISNULL(fc.OUTCOME_NFA_FLAG, '') AS NFA_FLAG,
            ISNULL(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS NON_AGENCY_ADOPTION_FLAG,
            ISNULL(fc.OUTCOME_PRIVATE_FOSTERING_FLAG, '') AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fc.OUTCOME_ADVICE_FLAG, '') AS ADVICE_FLAG,
            ISNULL(fc.OUTCOME_MISSING_FLAG, '') AS MISSING_FLAG,
            ISNULL(fc.OUTCOME_OLA_CP_FLAG, '') AS OLA_CP_FLAG,
            ISNULL(fc.OTHER_OUTCOMES_EXIST_FLAG, '') AS OTHER_OUTCOMES_EXIST_FLAG,
            CASE 
                WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
                ELSE fc.TOTAL_NO_OF_OUTCOMES 
            END AS NUMBER_OF_OUTCOMES,
            ISNULL(fc.OUTCOME_COMMENTS, '') AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cont_contact_outcome_json
FROM 
    HDM.Child_Social.FACT_CONTACTS AS fc
WHERE 
    (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
AND EXISTS
    (
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );




/* 
=============================================================================
Object Name: ssd_early_help_episodes
Description: 
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_CAF_EPISODE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_early_help_episodes_v') IS NOT NULL DROP VIEW ssd_development.ssd_early_help_episodes_v;

-- Create View
CREATE VIEW ssd_development.ssd_early_help_episodes_v AS
SELECT
    cafe.FACT_CAF_EPISODE_ID AS earl_episode_id,
    cafe.DIM_PERSON_ID AS earl_person_id,
    cafe.EPISODE_START_DTTM AS earl_episode_start_date,
    cafe.EPISODE_END_DTTM AS earl_episode_end_date,
    cafe.START_REASON AS earl_episode_reason,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE AS earl_episode_end_reason,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE AS earl_episode_organisation,
    'SSD_PH' AS earl_episode_worker_id
FROM
    HDM.Child_Social.FACT_CAF_EPISODE AS cafe
WHERE 
    (cafe.EPISODE_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    OR cafe.EPISODE_END_DTTM IS NULL)
AND EXISTS
    (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = cafe.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Version: 1.4
            1.3 cine_referral_team now DIM_DEPARTMENT_ID #DtoI-1762 290724 RH
            1.2: cine_referral_outcome_json size 500 to 4000 to include COMMENTS 160724 RH
            1.2: fr.OUTCOME_COMMENTS added cine_referral_outcome_json #DtoI-1796 160724 RH
            1.2: fr.TOTAL_NUMBER_OF_OUTCOMES added cine_referral_outcome_json #DtoI-1796 160724 RH
            1.2: rem NFA_OUTCOME from cine_referral_outcome_json #DtoI-1796 160724 RH
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            0.3 primary _need suffix of _code added #DtoI-1738 2105 RH
            0.2: primary _need type/size adjustment from revised spec 160524 RH
            0.1: contact_source_desc added, _source now populated with ID 141223 RH
Status: [R]elease
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- FACT_REFERRALS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cin_episodes_v') IS NOT NULL DROP VIEW ssd_development.ssd_cin_episodes_v;

-- Create View
CREATE VIEW ssd_development.ssd_cin_episodes_v AS
SELECT
    fr.FACT_REFERRAL_ID AS cine_referral_id,
    fr.DIM_PERSON_ID AS cine_person_id,
    fr.REFRL_START_DTTM AS cine_referral_date,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE AS cine_cin_primary_need_code,
    fr.DIM_LOOKUP_CONT_SORC_ID AS cine_referral_source_code,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC AS cine_referral_source_desc,
    (
        SELECT
            ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '') AS SINGLE_ASSESSMENT_FLAG,
            ISNULL(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fr.OUTCOME_CLA_REQUEST_FLAG, '') AS CLA_REQUEST_FLAG,
            ISNULL(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS NON_AGENCY_ADOPTION_FLAG,
            ISNULL(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '') AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '') AS CP_TRANSFER_IN_FLAG,
            ISNULL(fr.OUTCOME_CP_CONFERENCE_FLAG, '') AS CP_CONFERENCE_FLAG,
            ISNULL(fr.OUTCOME_CARE_LEAVER_FLAG, '') AS CARE_LEAVER_FLAG,
            ISNULL(fr.OTHER_OUTCOMES_EXIST_FLAG, '') AS OTHER_OUTCOMES_EXIST_FLAG,
            CASE 
                WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL
                ELSE fr.TOTAL_NO_OF_OUTCOMES 
            END AS NUMBER_OF_OUTCOMES,
            ISNULL(fr.OUTCOME_COMMENTS, '') AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cine_referral_outcome_json,
    fr.OUTCOME_NFA_FLAG AS cine_referral_nfa,
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE AS cine_close_reason,
    fr.REFRL_END_DTTM AS cine_close_date,
    fr.DIM_DEPARTMENT_ID AS cine_referral_team,
    fr.DIM_WORKER_ID_DESC AS cine_referral_worker_id
FROM
    HDM.Child_Social.FACT_REFERRALS AS fr
WHERE
    (fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    OR fr.REFRL_END_DTTM IS NULL)
    AND DIM_PERSON_ID <> -1
    AND EXISTS
    (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fr.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_cin_assessments
Description: 
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            1.0: Fix Aggr warnings use of isnull() 310524 RH
            0.2: cina_assessment_child_seen type change from nvarchar 100524 RH
            0.1: fa.COMPLETED_BY_USER_NAME replaces fa.COMPLETED_BY_USER_STAFF_ID 080524
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_SINGLE_ASSESSMENT
- FACT_FORMS
- FACT_FORM_ANSWERS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cin_assessments_v') IS NOT NULL DROP VIEW ssd_development.ssd_cin_assessments_v;

-- Create View
CREATE VIEW ssd_development.ssd_cin_assessments_v AS
WITH RelevantPersons AS (
    SELECT p.pers_person_id
    FROM ssd_development.ssd_person_v p
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
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'seenYN' THEN ffa.ANSWER ELSE NULL END, '')) AS seenYN,
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'FormEndDate' THEN TRY_CAST(ffa.ANSWER AS DATETIME) ELSE NULL END, '1900-01-01')) AS AssessmentAuthorisedDate
    FROM FormAnswers ffa
    GROUP BY ffa.FACT_FORM_ID
)
SELECT
    fa.FACT_SINGLE_ASSESSMENT_ID AS cina_assessment_id,
    fa.DIM_PERSON_ID AS cina_person_id,
    fa.FACT_REFERRAL_ID AS cina_referral_id,
    fa.START_DTTM AS cina_assessment_start_date,
    CASE
        WHEN UPPER(afa.seenYN) = 'YES' THEN 'Y'
        WHEN UPPER(afa.seenYN) = 'NO' THEN 'N'
        ELSE NULL
    END AS cina_assessment_child_seen,
    afa.AssessmentAuthorisedDate AS cina_assessment_auth_date,
    (
        SELECT
            ISNULL(fa.OUTCOME_NFA_FLAG, '') AS NFA_FLAG,
            ISNULL(fa.OUTCOME_NFA_S47_END_FLAG, '') AS NFA_S47_END_FLAG,
            ISNULL(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS STRATEGY_DISCUSSION_FLAG,
            ISNULL(fa.OUTCOME_CLA_REQUEST_FLAG, '') AS CLA_REQUEST_FLAG,
            ISNULL(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '') AS PRIVATE_FOSTERING_FLAG,
            ISNULL(fa.OUTCOME_LEGAL_ACTION_FLAG, '') AS LEGAL_ACTION_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '') AS PROV_OF_SERVICES_FLAG,
            ISNULL(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '') AS PROV_OF_SB_CARE_FLAG,
            ISNULL(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '') AS SPECIALIST_ASSESSMENT_FLAG,
            ISNULL(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fa.OUTCOME_OTHER_ACTIONS_FLAG, '') AS OTHER_ACTIONS_FLAG,
            ISNULL(fa.OTHER_OUTCOMES_EXIST_FLAG, '') AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fa.TOTAL_NO_OF_OUTCOMES, '') AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fa.OUTCOME_COMMENTS, '') AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cina_assessment_outcome_json,
    fa.OUTCOME_NFA_FLAG AS cina_assessment_outcome_nfa,
    fa.COMPLETED_BY_DEPT_ID AS cina_assessment_team,
    fa.COMPLETED_BY_USER_STAFF_ID AS cina_assessment_worker_id
FROM
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
LEFT JOIN
    AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')
    AND (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR afa.AssessmentAuthorisedDate IS NULL)
    AND EXISTS (
        SELECT 1
        FROM RelevantPersons p
        WHERE CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID
    );





/* 
=============================================================================
Object Name: ssd_assessment_factors
Description: 
Author: D2I
Version: 1.2
            1.1: ensure only factors with associated cina_assessment_id #DtoI-1769 090724 RH
            1.0: New alternative structure for assessment_factors_json 250624 RH
Status: [R]elease
Remarks: This object referrences some large source tables- Instances of 45m+. 
Dependencies: 
- #ssd_TMP_PRE_assessment_factors (as staged pre-processing)
- ssd_cin_assessments
- FACT_SINGLE_ASSESSMENT
- FACT_FORM_ANSWERS
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_assessment_factors_v') IS NOT NULL DROP VIEW ssd_development.ssd_assessment_factors_v;

-- Create View
CREATE VIEW ssd_development.ssd_assessment_factors_v AS
WITH TMP_PRE_assessment_factors AS (
    SELECT 
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER
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
        AND LOWER(ffa.ANSWER) = 'yes'
        AND ffa.FACT_FORM_ID <> -1
)
SELECT 
    fsa.EXTERNAL_ID AS cinf_table_id,
    fsa.FACT_FORM_ID AS cinf_assessment_id,
    (
        SELECT 
            '[' + STRING_AGG('"' + tmp_af.ANSWER_NO + '"', ', ') + ']' 
        FROM 
            TMP_PRE_assessment_factors tmp_af
        WHERE 
            tmp_af.FACT_FORM_ID = fsa.FACT_FORM_ID
    ) AS cinf_assessment_factors_json
FROM 
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fsa
WHERE 
    fsa.EXTERNAL_ID <> -1
    AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_development.ssd_cin_assessments_v);






/* 
=============================================================================
Object Name: ssd_cin_plans_v
Description: 
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            1.0: Fix Aggr warnings use of isnull() 310524 RH
            0.1: Update fix returning new row for each revision of the plan JH 070224
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_CARE_PLANS
- FACT_CARE_PLAN_SUMMARY
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cin_plans_v') IS NOT NULL DROP VIEW ssd_development.ssd_cin_plans_v;

-- Create View
CREATE VIEW ssd_development.ssd_cin_plans_v AS
SELECT
    cps.FACT_CARE_PLAN_SUMMARY_ID AS cinp_cin_plan_id,
    cps.FACT_REFERRAL_ID AS cinp_referral_id,
    cps.DIM_PERSON_ID AS cinp_person_id,
    cps.START_DTTM AS cinp_cin_plan_start_date,
    cps.END_DTTM AS cinp_cin_plan_end_date,
    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID THEN fp.DIM_PLAN_COORD_DEPT_ID END, ''))
    ) AS cinp_cin_plan_team,
    (SELECT
        MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID THEN fp.DIM_PLAN_COORD_ID END, ''))
    ) AS cinp_cin_plan_worker_id
FROM HDM.Child_Social.FACT_CARE_PLAN_SUMMARY cps
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS fp ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
WHERE DIM_LOOKUP_PLAN_TYPE_CODE = 'FP'
    AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
    AND (cps.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR cps.END_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = cps.DIM_PERSON_ID
    )
GROUP BY
    cps.FACT_CARE_PLAN_SUMMARY_ID,
    cps.FACT_REFERRAL_ID,
    cps.DIM_PERSON_ID,
    cps.START_DTTM,
    cps.END_DTTM;





/*
=============================================================================
Object Name: ssd_cin_visits_v
Description:
Author: D2I
Version: 1.0
Status: [R]elease
Remarks:    Source table can be very large! Avoid any unfiltered queries.
            Notes: Does this need to be filtered by only visits in their current Referral episode?
                    however for some this ==2 weeks, others==~17 years
                --> when run for records in ssd_person c.64k records 29s runtime
Dependencies:
- ssd_person
- FACT_CASENOTES
=============================================================================
*/
 -- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_cin_visits_v') IS NOT NULL DROP VIEW ssd_development.ssd_cin_visits_v;

-- Create View
CREATE VIEW ssd_development.ssd_cin_visits_v AS
SELECT
    cn.FACT_CASENOTE_ID AS cinv_cin_visit_id,
    cn.DIM_PERSON_ID AS cinv_person_id,
    cn.EVENT_DTTM AS cinv_cin_visit_date,
    cn.SEEN_FLAG AS cinv_cin_visit_seen,
    cn.SEEN_ALONE_FLAG AS cinv_cin_visit_seen_alone,
    cn.SEEN_BEDROOM_FLAG AS cinv_cin_visit_bedroom
FROM
    HDM.Child_Social.FACT_CASENOTES cn
WHERE
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO',
    'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID')
    AND (cn.EVENT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR cn.EVENT_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = cn.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_s47_enquiry_v
Description: 
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_s47_enquiry_v') IS NOT NULL DROP VIEW ssd_development.ssd_s47_enquiry_v;

-- Create View
CREATE VIEW ssd_development.ssd_s47_enquiry_v AS
SELECT 
    s47.FACT_S47_ID AS s47e_s47_enquiry_id,
    s47.FACT_REFERRAL_ID AS s47e_referral_id,
    s47.DIM_PERSON_ID AS s47e_person_id,
    s47.START_DTTM AS s47e_s47_start_date,
    s47.END_DTTM AS s47e_s47_end_date,
    s47.OUTCOME_NFA_FLAG AS s47e_s47_nfa,
    (
        SELECT 
            ISNULL(s47.OUTCOME_NFA_FLAG, '') AS NFA_FLAG,
            ISNULL(s47.OUTCOME_LEGAL_ACTION_FLAG, '') AS LEGAL_ACTION_FLAG,
            ISNULL(s47.OUTCOME_PROV_OF_SERVICES_FLAG, '') AS PROV_OF_SERVICES_FLAG,
            ISNULL(s47.OUTCOME_PROV_OF_SB_CARE_FLAG, '') AS PROV_OF_SB_CARE_FLAG,
            ISNULL(s47.OUTCOME_CP_CONFERENCE_FLAG, '') AS CP_CONFERENCE_FLAG,
            ISNULL(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG, '') AS NFA_CONTINUE_SINGLE_FLAG,
            ISNULL(s47.OUTCOME_MONITOR_FLAG, '') AS MONITOR_FLAG,
            ISNULL(s47.OTHER_OUTCOMES_EXIST_FLAG, '') AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(s47.TOTAL_NO_OF_OUTCOMES, '') AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(s47.OUTCOME_COMMENTS, '') AS OUTCOME_COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS s47e_s47_outcome_json,
    s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
    s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker_id
FROM 
    HDM.Child_Social.FACT_S47 AS s47
WHERE
    (s47.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR s47.END_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = s47.DIM_PERSON_ID
    );





/*
=============================================================================
Object Name: ssd_initial_cp_conference_v
Description:
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            0.3 Updated source of CP_PLAN_ID 100424 JH
            0.2 Updated the worker fields 020424 JH
            0.1 Re-instated the worker details 010224 JH
Status: [R]elease
Remarks:
Dependencies:
- FACT_CP_CONFERENCE
- FACT_MEETINGS
- FACT_CP_PLAN
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_initial_cp_conference_v') IS NOT NULL DROP VIEW ssd_development.ssd_initial_cp_conference_v;

-- Create View
CREATE VIEW ssd_development.ssd_initial_cp_conference_v AS
SELECT
    fcpc.FACT_CP_CONFERENCE_ID AS icpc_icpc_id,
    fcpc.FACT_MEETING_ID AS icpc_icpc_meeting_id,
    CASE 
        WHEN fcpc.FACT_S47_ID IN ('-1', -1) THEN NULL
        ELSE fcpc.FACT_S47_ID 
    END AS icpc_s47_enquiry_id,
    fcpc.DIM_PERSON_ID AS icpc_person_id,
    fcpp.FACT_CP_PLAN_ID AS icpc_cp_plan_id,
    fcpc.FACT_REFERRAL_ID AS icpc_referral_id,
    fcpc.TRANSFER_IN_FLAG AS icpc_icpc_transfer_in,
    fcpc.DUE_DTTM AS icpc_icpc_target_date,
    fm.ACTUAL_DTTM AS icpc_icpc_date,
    fcpc.OUTCOME_CP_FLAG AS icpc_icpc_outcome_cp_flag,
    (
        SELECT
            ISNULL(fcpc.OUTCOME_NFA_FLAG, '') AS NFA_FLAG,
            ISNULL(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS REFERRAL_TO_OTHER_AGENCY_FLAG,
            ISNULL(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '') AS SINGLE_ASSESSMENT_FLAG,
            ISNULL(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '') AS PROV_OF_SERVICES_FLAG,
            ISNULL(fcpc.OUTCOME_CP_FLAG, '') AS CP_FLAG,
            ISNULL(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '') AS OTHER_OUTCOMES_EXIST_FLAG,
            ISNULL(fcpc.TOTAL_NO_OF_OUTCOMES, '') AS TOTAL_NO_OF_OUTCOMES,
            ISNULL(fcpc.OUTCOME_COMMENTS, '') AS COMMENTS
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS icpc_icpc_outcome_json,
    fcpc.ORGANISED_BY_DEPT_ID AS icpc_icpc_team,
    fcpc.ORGANISED_BY_USER_STAFF_ID AS icpc_icpc_worker_id
FROM
    HDM.Child_Social.FACT_CP_CONFERENCE AS fcpc
JOIN
    HDM.Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID
WHERE
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'
    AND (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fm.ACTUAL_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID
    );




/*
=============================================================================
Object Name: ssd_cp_plans
Description:
Author: D2I
Version: 1.1:
            1.0: #DtoI-1809 fix on cppl_referral_id/cppl_icpc_id 010824 RH
            0.4: cppl_cp_plan_ola type change from nvarchar 100524 RH
            0.3: added IS_OLA field to identify OLA temporary plans
            which need to be excluded from statutory returns 090224 JCH
            0.2: removed depreciated team/worker id fields RH
Status: [R]elease
Remarks:
Dependencies:
- ssd_person
- ssd_initial_cp_conference
- FACT_CP_PLAN
=============================================================================
*/

-- Check if exists & drop 
IF OBJECT_ID('ssd_development.ssd_cp_plans_v') IS NOT NULL DROP VIEW ssd_development.ssd_cp_plans_v;

-- Create View
CREATE VIEW ssd_development.ssd_cp_plans_v AS
SELECT
    cpp.FACT_CP_PLAN_ID AS cppl_cp_plan_id,
    CASE 
        WHEN cpp.FACT_REFERRAL_ID = -1 THEN NULL
        ELSE cpp.FACT_REFERRAL_ID
    END                                 AS cppl_referral_id,
    CASE 
        WHEN cpp.FACT_INITIAL_CP_CONFERENCE_ID = -1 THEN NULL
        ELSE cpp.FACT_INITIAL_CP_CONFERENCE_ID
    END                                 AS cppl_icpc_id,
    cpp.DIM_PERSON_ID AS cppl_person_id,
    cpp.START_DTTM AS cppl_cp_plan_start_date,
    cpp.END_DTTM AS cppl_cp_plan_end_date,
    cpp.IS_OLA AS cppl_cp_plan_ola,
    cpp.INIT_CATEGORY_DESC AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC AS cppl_cp_plan_latest_category
FROM
    HDM.Child_Social.FACT_CP_PLAN cpp
WHERE
    (cpp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR cpp.END_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = cpp.DIM_PERSON_ID
    );





/*
=============================================================================
Object Name: ssd_cp_visits_v
Description:
Author: D2I
Version: 1.1:
            1.0: #DtoI-1715 fix on PK violation 010824 RH
            0.3: (cppv casenote date) removed 070524 RH
            0.2: cppv_person_id added, where claus removed 'STVCPCOVID' 130224 JH
Status: [R]elease
Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
         using casenote ID as PK and linking to CP Visit where available.
         Will have to use Person ID to link object to Person table
Dependencies:
- FACT_CASENOTES
- FACT_CP_VISIT
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cp_visits_v') IS NOT NULL DROP VIEW ssd_development.ssd_cp_visits_v;

-- Create View
CREATE VIEW ssd_development.ssd_cp_visits_v AS
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
    LEFT JOIN
        HDM.Child_Social.DIM_PERSON p ON cn.DIM_PERSON_ID = p.DIM_PERSON_ID
    WHERE
        cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC') -- Ref. ( 'STVC','STVCPCOVID')
        AND (cn.EVENT_DTTM  >= DATEADD(YEAR, -1, GETDATE()) -- Assuming 1 year as a placeholder
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




/*
=============================================================================
Object Name: ssd_cp_reviews_v
Description:
Author: D2I
Version: 1.0
            0.1: Resolved issue with linking to Quoracy information 130224 JH
Status: [R]elease
Remarks:    cppr_cp_review_participation - ON HOLD/Not included in SSD Ver/Iteration 1
            Resolved issue with linking to Quoracy information. Added fm.FACT_MEETING_ID
            so users can identify conferences including multiple children. Reviews held
            pre-LCS implementation don't have a CP_PLAN_ID recorded so have added
            cpr.DIM_PERSON_ID for linking reviews to the ssd_cp_plans object.
            Re-named cppr_cp_review_outcome_continue_cp for clarity.
Dependencies:
- ssd_person
- ssd_cp_plans
- FACT_CP_REVIEW
- FACT_MEETINGS
- FACT_MEETING_SUBJECTS
- FACT_FORM_ANSWERS [Participation info - ON HOLD/Not included in SSD Ver/Iteration 1]
=============================================================================
*/
 -- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cp_reviews_v') IS NOT NULL DROP VIEW ssd_development.ssd_cp_reviews_v;

-- Create View
CREATE VIEW ssd_development.ssd_cp_reviews_v AS
SELECT
    cpr.FACT_CP_REVIEW_ID AS cppr_cp_review_id,
    cpr.FACT_CP_PLAN_ID AS cppr_cp_plan_id,
    cpr.DIM_PERSON_ID AS cppr_person_id,
    cpr.DUE_DTTM AS cppr_cp_review_due,
    cpr.MEETING_DTTM AS cppr_cp_review_date,
    fm.FACT_MEETING_ID AS cppr_cp_review_meeting_id,
    cpr.OUTCOME_CONTINUE_CP_FLAG AS cppr_cp_review_outcome_continue_cp,
    (CASE WHEN ffa.ANSWER_NO = 'WasConf'
        AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
        THEN ffa.ANSWER END) AS cppr_cp_review_quorate,    
    'SSD_PH' AS cppr_cp_review_participation
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
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON cpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    (cpr.MEETING_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR cpr.MEETING_DTTM IS NULL)
    AND EXISTS (
        SELECT 1 
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = cpr.DIM_PERSON_ID
    )
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




/* 
=============================================================================
Object Name: ssd_cla_episodes_v
Description: 
Author: D2I
Version: 1.1
            1.0: Fix Aggr warnings use of isnull() 310524 RH
            0.2: primary _need type/size adjustment from revised spec 160524 RH
            0.1: cla_placement_id added as part of cla_placements review RH 060324
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_involvements
- ssd_person
- FACT_CLA
- FACT_REFERRALS
- FACT_CARE_EPISODES
- FACT_CASENOTES
=============================================================================
*/
-- Check if table exists, & drop
IF OBJECT_ID('ssd_development.ssd_cla_episodes_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_episodes_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_episodes_v AS
WITH FilteredData AS (
    SELECT
        fce.FACT_CARE_EPISODES_ID AS clae_cla_episode_id,
        fce.FACT_CLA_PLACEMENT_ID AS clae_cla_placement_id,
        CAST(fce.DIM_PERSON_ID AS NVARCHAR(48)) AS clae_person_id,
        fce.CARE_START_DATE AS clae_cla_episode_start_date,
        fce.CARE_REASON_DESC AS clae_cla_episode_start_reason,
        fce.CIN_903_CODE AS clae_cla_primary_need_code,
        fce.CARE_END_DATE AS clae_cla_episode_ceased,
        fce.CARE_REASON_END_DESC AS clae_cla_episode_ceased_reason,
        fc.FACT_CLA_ID AS clae_cla_id,                    
        fc.FACT_REFERRAL_ID AS clae_referral_id,
        (
            SELECT MAX(ISNULL(CASE WHEN fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
                AND cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
                THEN cn.EVENT_DTTM END, '1900-01-01'))
        ) AS clae_cla_last_iro_contact_date,
        fc.START_DTTM AS clae_entered_care_date
    FROM
        HDM.Child_Social.FACT_CARE_EPISODES AS fce
    JOIN
        HDM.Child_Social.FACT_CLA AS fc ON fce.FACT_CLA_ID = fc.FACT_CLA_ID
    LEFT JOIN
        HDM.Child_Social.FACT_CASENOTES cn ON fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
    WHERE
        fce.DIM_PERSON_ID IN (SELECT CAST(pers_person_id AS INT) FROM ssd_development.ssd_person_v)
        AND (fce.CARE_END_DATE >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fce.CARE_END_DATE IS NULL)
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





/* 
=============================================================================
Object Name: ssd_cla_convictions_v
Description: 
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_OFFENCE
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_convictions_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_convictions_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_convictions_v AS
SELECT 
    fo.FACT_OFFENCE_ID AS clac_cla_conviction_id,
    fo.DIM_PERSON_ID AS clac_person_id,
    fo.OFFENCE_DTTM AS clac_cla_conviction_date,
    fo.DESCRIPTION AS clac_cla_conviction_offence
FROM 
    HDM.Child_Social.FACT_OFFENCE AS fo
WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fo.DIM_PERSON_ID
    );



/*
=============================================================================
Object Name: ssd_cla_health_v
Description:
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: 1.5 JH updated source for clah_health_check_type to resolve blanks.
            Updated to use DIM_LOOKUP_EXAM_STATUS_DESC as opposed to _CODE
            to inprove readability.
Dependencies:
- ssd_person
- FACT_HEALTH_CHECK
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_health_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_health_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_health_v AS
SELECT
    fhc.FACT_HEALTH_CHECK_ID AS clah_health_check_id,
    fhc.DIM_PERSON_ID AS clah_person_id,
    fhc.DIM_LOOKUP_EVENT_TYPE_DESC AS clah_health_check_type,
    fhc.START_DTTM AS clah_health_check_date,
    fhc.DIM_LOOKUP_EXAM_STATUS_DESC AS clah_health_check_status
FROM
    HDM.Child_Social.FACT_HEALTH_CHECK AS fhc
WHERE
    (fhc.START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fhc.START_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = fhc.DIM_PERSON_ID
    );



/* 
=============================================================================
Object Name: ssd_cla_immunisations_v
Description: 
Author: D2I
Version: 1.0
            0.2: most recent status reworked / 903 source removed 220224 JH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_CLA
- FACT_903_DATA [Depreciated]
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_immunisations_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_immunisations_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_immunisations_v AS
WITH RankedImmunisations AS (
    SELECT
        fcla.DIM_PERSON_ID,
        fcla.IMMU_UP_TO_DATE_FLAG,
        fcla.LAST_UPDATED_DTTM,
        ROW_NUMBER() OVER (
            PARTITION BY fcla.DIM_PERSON_ID
            ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn
    FROM
        HDM.Child_Social.FACT_CLA AS fcla
    WHERE
        EXISTS ( 
            SELECT 1 
            FROM ssd_development.ssd_person_v p
            WHERE CAST(p.pers_person_id AS INT) = fcla.DIM_PERSON_ID
        )
)
SELECT
    DIM_PERSON_ID AS clai_person_id,
    IMMU_UP_TO_DATE_FLAG AS clai_immunisations_status,
    LAST_UPDATED_DTTM AS clai_immunisations_status_date
FROM
    RankedImmunisations
WHERE
    rn = 1;




/* 
=============================================================================
Object Name: ssd_cla_substance_misuse_v
Description: 
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_SUBSTANCE_MISUSE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_substance_misuse_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_substance_misuse_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_substance_misuse_v AS
SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID AS clas_person_id,
    fsm.START_DTTM AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE AS clas_substance_misused,
    fsm.ACCEPT_FLAG AS clas_intervention_received
FROM 
    HDM.Child_Social.FACT_SUBSTANCE_MISUSE AS fsm
WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fsm.DIM_PERSON_ID
    );




/* 
=============================================================================
Object Name: ssd_cla_placement_v
Description: 
Author: D2I
Version: 1.0 
            0.2: 060324 JH
            0.1: Corrected/removal of placement_la & episode_id 090124 RH
Status: [R]elease
Remarks: DEV: filtering for OFSTED_URN LIKE 'SC%'
Dependencies: 
- ssd_person
- FACT_CLA_PLACEMENT
- FACT_CARE_EPISODES
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_placement_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_placement_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_placement_v AS
SELECT
    fcp.FACT_CLA_PLACEMENT_ID AS clap_cla_placement_id,
    fcp.FACT_CLA_ID AS clap_cla_id,   
    fcp.DIM_PERSON_ID AS clap_person_id,                             
    fcp.START_DTTM AS clap_cla_placement_start_date,
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE AS clap_cla_placement_type,
    (
        SELECT
            TOP(1) fce.OFSTED_URN
            FROM HDM.Child_Social.FACT_CARE_EPISODES fce
            WHERE fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
            AND fce.OFSTED_URN LIKE 'SC%'
            AND fce.OFSTED_URN IS NOT NULL        
    ) AS clap_cla_placement_urn,
    TRY_CAST(fcp.DISTANCE_FROM_HOME AS FLOAT) AS clap_cla_placement_distance,
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE AS clap_cla_placement_provider,
    CASE
        WHEN LEN(LTRIM(RTRIM(fcp.POSTCODE))) <= 4 THEN NULL
        ELSE LTRIM(RTRIM(fcp.POSTCODE))
    END AS clap_cla_placement_postcode,
    fcp.END_DTTM AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE AS clap_cla_placement_change_reason
FROM
    HDM.Child_Social.FACT_CLA_PLACEMENT AS fcp
WHERE fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
                                            'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
                                            'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')
AND
    (fcp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fcp.END_DTTM IS NULL);





/* 
=============================================================================
Object Name: ssd_cla_reviews_v
Description: 
Author: D2I
Version: 1.0
            0.2: clar_cla_review_cancelled type change from nvarchar 100524 RH
            0.1: clar_cla_id change from clar cla episode id 120124 JH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_cla_episodes
- FACT_CLA_REVIEW
- FACT_MEETING_SUBJECTS 
- FACT_MEETINGS
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_reviews_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_reviews_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_reviews_v AS
SELECT
    fcr.FACT_CLA_REVIEW_ID AS clar_cla_review_id,
    fcr.FACT_CLA_ID AS clar_cla_id,                
    fcr.DUE_DTTM AS clar_cla_review_due_date,
    fcr.MEETING_DTTM AS clar_cla_review_date,
    fm.CANCELLED AS clar_cla_review_cancelled,
    (
        SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
            AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
            THEN ISNULL(fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC, '') END)
    ) AS clar_cla_review_participation
FROM
    HDM.Child_Social.FACT_CLA_REVIEW AS fcr
LEFT JOIN
    HDM.Child_Social.FACT_MEETINGS fm ON fcr.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    HDM.Child_Social.FACT_MEETING_SUBJECTS fms ON fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
LEFT JOIN
    HDM.Child_Social.FACT_FORMS ff ON fms.FACT_OUTCM_FORM_ID = ff.FACT_FORM_ID
    AND fms.FACT_OUTCM_FORM_ID <> '1071252'
LEFT JOIN
    HDM.Child_Social.DIM_PERSON p ON fcr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')
    AND (fcr.MEETING_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fcr.MEETING_DTTM IS NULL)
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = fcr.DIM_PERSON_ID
    )
GROUP BY
    fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID,
    ff.FACT_FORM_ID,
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE;



/*
=============================================================================
Object Name: ssd_cla_previous_permanence_v
Description:
Author: D2I
Version: 1.1 
            1.0: Fix Aggr warnings use of isnull() 310524 RH
Status: [R]elease
Remarks: Adapted from 1.3 ver, needs re-test also with Knowsley.
        1.5 JH tmp table was not being referenced, updated query and reduced running
        time considerably, also filtered out rows where ANSWER IS NULL
Dependencies:
- ssd_person
- FACT_903_DATA [depreciated]
- FACT_FORMS
- FACT_FORM_ANSWERS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_previous_permanence_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_previous_permanence_v;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_previous_permanence') IS NOT NULL DROP TABLE #ssd_TMP_PRE_previous_permanence;

-- Create TMP structure with filtered answers
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
    AND ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
    AND ffa.ANSWER IS NOT NULL;

-- Create View
CREATE VIEW ssd_development.ssd_cla_previous_permanence_v AS
SELECT
    tmp_ffa.FACT_FORM_ID AS lapp_table_id,
    ff.DIM_PERSON_ID AS lapp_person_id,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_option,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_la,
    CASE 
        WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '')) = 0 AND 
             CAST(ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '0') AS INT) BETWEEN 1 AND 31 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '') 
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
    END AS lapp_previous_permanence_order_date
FROM
    #ssd_TMP_PRE_previous_permanence tmp_ffa
JOIN
    HDM.Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID
AND EXISTS (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID
)
GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;

-- Drop TMP structure
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_previous_permanence') IS NOT NULL DROP TABLE #ssd_TMP_PRE_previous_permanence;




/*
=============================================================================
Object Name: ssd_cla_care_plan
Description:
Author: D2I
Version: 1.1
            1.0: Fix Aggr warnings use of isnull() 310524 RH
            0.1: Altered _json keys and groupby towards > clarity 190224 JH
Status: [R]elease
Remarks:    Added short codes to plan type questions to improve readability.
            Removed form type filter, only filtering ffa. on ANSWER_NO.
Dependencies:
- FACT_CARE_PLANS
- FACT_FORMS
- FACT_FORM_ANSWERS
- #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_care_plan_v') IS NOT NULL DROP VIEW ssd_development.ssd_cla_care_plan_v;

-- Create persistent tmp/pre-processing table (not part of core ssd, clean-up occurs later)
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_pre_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;

CREATE TABLE ssd_development.ssd_pre_cla_care_plan (
    FACT_FORM_ID        NVARCHAR(48),
    DIM_PERSON_ID       NVARCHAR(48),
    ANSWER_NO           NVARCHAR(10),
    ANSWER              NVARCHAR(255),
    LatestResponseDate  DATETIME
);

WITH MostRecentQuestionResponse AS (
    SELECT  -- Return the most recent response for each question for each persons
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    JOIN
        HDM.Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID    -- obtain the relevant person_id
    WHERE
        ffa.ANSWER_NO    IN ('CPFUP1', 'CPFUP10', 'CPFUP2', 'CPFUP3', 'CPFUP4', 'CPFUP5', 'CPFUP6', 'CPFUP7', 'CPFUP8', 'CPFUP9')
    GROUP BY
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO
),
LatestResponses AS (
    SELECT  -- Now add the answered_date (only indirectly of use here/cross referencing)
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
 
INSERT INTO ssd_development.ssd_pre_cla_care_plan (
    FACT_FORM_ID,
    DIM_PERSON_ID,
    ANSWER_NO,
    ANSWER,
    LatestResponseDate
)
SELECT
    lr.FACT_FORM_ID,
    lr.DIM_PERSON_ID,
    lr.ANSWER_NO,
    lr.ANSWER,
    lr.LatestResponseDate
FROM
    LatestResponses lr
ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;

-- Create View
CREATE VIEW ssd_development.ssd_cla_care_plan_v AS
SELECT
    fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
    fcp.DIM_PERSON_ID              AS lacp_person_id,
    fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
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
            ssd_development.ssd_pre_cla_care_plan tmp_cpl
        WHERE
            tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
        GROUP BY tmp_cpl.DIM_PERSON_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS lacp_cla_care_plan_json
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp
WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID
    );





/*
=============================================================================
Object Name: ssd_cla_visits
Description:
Author: D2I
Version: 1.0!
            !0.3: Prep for casenote _ id to be removed... not yet actioned RH
            0.2: FK updated to person_id. change from clav.VISIT_DTTM  150224 JH
            0.1: pers_person_id and clav_cla_id  added JH
Status: [R]elease
Remarks:
Dependencies:
- FACT_CARE_EPISODES
- FACT_CASENOTES
- FACT_CLA_VISIT
=============================================================================
*/
 -- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cla_visits_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_cla_visits_v;

-- Create View
CREATE VIEW ssd_development.ssd_cla_visits_v AS
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
    (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    OR cn.EVENT_DTTM IS NULL)
AND EXISTS (
    -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = clav.DIM_PERSON_ID
    );





/*
=============================================================================
Object Name: ssd_sdq_scores_v
Description:
Author: D2I
Version: 1.0
Status: [R]elease
Remarks: ASSESSMENT_TEMPLATE_ID_CODEs ranges validated at 12/12/23
        Removed csdq _form_ id as the form id is also being used as csdq_table_id
        Added placeholder for csdq_sdq_reason
        Removed PRIMARY KEY stipulation for csdq_table_id
Dependencies:
- ssd_person
- FACT_FORMS
- FACT_FORM_ANSWERS
=============================================================================
*/

 -- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_sdq_scores_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_sdq_scores_v;

-- Create View
CREATE VIEW ssd_development.ssd_sdq_scores_v AS
WITH RankedSDQScores AS (
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
        'SSD_PH'                            AS csdq_sdq_reason,
        ROW_NUMBER() OVER (PARTITION BY ff.DIM_PERSON_ID ORDER BY ff.FACT_FORM_ID DESC) AS rn
    FROM
        HDM.Child_Social.FACT_FORMS ff
    JOIN
        HDM.Child_Social.FACT_FORM_ANSWERS ffa ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
        AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
        AND ffa.ANSWER_NO IN ('FormEndDate', 'SDQScore')
        AND ffa.ANSWER IS NOT NULL
    WHERE EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID
    )
)
SELECT
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_completed_date,
    csdq_sdq_score,
    csdq_sdq_reason
FROM RankedSDQScores
WHERE rn = 1;





/* 
=============================================================================
Object Name: ssd_missing_v
Description: 
Author: D2I
Version: 1.1
            1.0 miss_ missing_ rhi_accepted/offered 'NA' not valid value 240524 RH
            0.9 miss_missing_rhi_accepted/offered increased to size (2) 100524 RH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_MISSING_PERSON
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_missing_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_missing_v;

-- Create View
CREATE VIEW ssd_development.ssd_missing_v AS
SELECT 
    fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
    fmp.DIM_PERSON_ID                   AS miss_person_id,
    fmp.START_DTTM                      AS miss_missing_episode_start_date,
    fmp.MISSING_STATUS                  AS miss_missing_episode_type,
    fmp.END_DTTM                        AS miss_missing_episode_end_date,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NA' THEN 'NA'
        WHEN fmp.RETURN_INTERVIEW_OFFERED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_offered,
    CASE 
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'YES' THEN 'Y'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NO' THEN 'N'
        WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NA' THEN 'NA'
        WHEN fmp.RETURN_INTERVIEW_ACCEPTED = '' THEN NULL
        ELSE NULL
    END AS miss_missing_rhi_accepted

FROM 
    HDM.Child_Social.FACT_MISSING_PERSON AS fmp

WHERE
    (fmp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    OR fmp.END_DTTM IS NULL)

AND EXISTS 
    (
    SELECT 1 
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fmp.DIM_PERSON_ID
    );




/*
=============================================================================
Object Name: ssd_care_leavers_v
Description:
Author: D2I
Version: 1.3:
            1.2: Added NULLIF(NULLIF(... fixes for CurrentWorker & AllocatedTeam 290724 RH
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            1.0: Fix Aggr warnings use of isnull() 310524 RH
            0.3: change of main source to DIM_CLA_ELIGIBILITY in order to capture full care leaver cohort 12/03/24 JH
            0.2: switch field _worker)nm and _team_nm around as in wrong order RH
            0.1: worker/p.a id field changed to descriptive name towards AA reporting JH
Status: [R]elease
Remarks:    Dev: Note that <multiple> refs to ssd_person need changing when porting code to tempdb.. versions.
            Dev: Ensure index on ssd_person.pers_person_id is intact to ensure performance on <FROM ssd_development.ssd_person> references in the CTEs(added for performance)
            Dev: Revised V3/4 to aid performance on large involvements table aggr
Dependencies:
- FACT_INVOLVEMENTS
- FACT_CLA_CARE_LEAVERS
- DIM_CLA_ELIGIBILITY
- FACT_CARE_PLANS
- ssd_person
=============================================================================
*/

 -- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_care_leavers_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_care_leavers_v;

-- Create View
CREATE VIEW ssd_development.ssd_care_leavers_v AS
WITH InvolvementHistoryCTE AS (
    SELECT
        fi.DIM_PERSON_ID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(fi.DIM_WORKER_ID, 0) ELSE NULL END) AS CurrentWorker,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(NULLIF(fi.FACT_WORKER_HISTORY_DEPARTMENT_ID, -1), 0) ELSE NULL END) AS AllocatedTeam,
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_ID ELSE NULL END) AS PersonalAdvisor
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS')
            AND DIM_WORKER_ID <> -1
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
    ) fi
    GROUP BY fi.DIM_PERSON_ID
)
SELECT
    CONCAT(dce.DIM_CLA_ELIGIBILITY_ID, fccl.FACT_CLA_CARE_LEAVERS_ID) AS clea_table_id,
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
FROM
    HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
LEFT JOIN HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
LEFT JOIN HDM.Child_Social.DIM_PERSON p ON dce.DIM_PERSON_ID = p.DIM_PERSON_ID
LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID
WHERE EXISTS (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = dce.DIM_PERSON_ID
)
GROUP BY
    dce.DIM_CLA_ELIGIBILITY_ID,
    fccl.FACT_CLA_CARE_LEAVERS_ID,
    p.LEGACY_ID,
    dce.DIM_PERSON_ID,
    dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE,
    fccl.IN_TOUCH_DTTM,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC,
    ih.PersonalAdvisor,
    ih.CurrentWorker,
    ih.AllocatedTeam;





/* 
=============================================================================
Object Name: ssd_permanence_v
Description: 
Author: D2I
Version: 1.2
            1.1: Roll-back to use of worker_id #DtoI-1755 040624 RH
            0.5: perm_placed_foster_carer_date placeholder re-added 240424 RH
            0.4: worker_name field name change for consistency 100424 JH
            0.3: entered_care_date removed/moved to cla_episodes 060324 RH
            0.2: perm_placed_foster_carer_date (from fc.START_DTTM) removed RH
            0.1: perm_adopter_sex, perm_adopter_legal_status added RH
Status: [R]elease
Remarks: 
        DEV: 181223: Assumed that only one permanence order per child. 
        - In order to handle/reflect the v.rare cases where this has broken down, further work is required.

        DEV: Some fields need spec checking for datatypes e.g. perm_adopted_by_carer_flag and others

Dependencies: 
- ssd_person
- FACT_ADOPTION
- FACT_CLA_PLACEMENT
- FACT_LEGAL_STATUS
- FACT_CARE_EPISODES
- FACT_CLA
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_permanence_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_permanence_v;

-- Create view
CREATE VIEW ssd_development.ssd_permanence_v AS
WITH RankedPermanenceData AS (
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
            ORDER BY CAST(RIGHT(CASE 
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
)

-- Select data for view
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
(
    -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE p.pers_person_id = perm_person_id -- this a NVARCHAR(48) equality link
);




/* 
=============================================================================
Object Name: ssd_professionals_v
Description: 
Author: D2I
Version: 1.2
            1.1: staff_id field clean-up, removal of dirty|admin values 090724 RH
            1.0: #DtoI-1743 caseload count revised to be within ssd timeframe 170524 RH
            0.9: prof_professional_id now becomes staff_id 090424 JH
            0.8: prof _table_ id(prof _system_ id) becomes prof _professional_ id 090424 JH
Status: [R]elease
Remarks: 
Dependencies: 
- @LastSept30th
- @TimeframeStartDate
- @ssd_timeframe_years
- DIM_WORKER
- FACT_REFERRALS
- ssd_cin_episodes (if counting caseloads within SSD timeframe)
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_professionals_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_professionals_v;

-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;

DECLARE @TimeframeStartDate DATE = DATEADD(YEAR, -@ssd_timeframe_years, @LastSept30th);

-- Create view
CREATE VIEW ssd_development.ssd_professionals_v AS
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
        REFRL_START_DTTM <= @LastSept30th AND 
        (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM >= @LastSept30th) AND
        REFRL_START_DTTM >= @TimeframeStartDate  -- ssd timeframe constraint
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID
WHERE 
    dw.DIM_WORKER_ID <> -1
    AND TRIM(dw.STAFF_ID) IS NOT NULL           -- in theory would not occur
    AND LOWER(TRIM(dw.STAFF_ID)) <> 'unknown';



/* 
=============================================================================
Object Name: ssd_department_v
Description: 
Author: D2I
Version: 1.1:
            1.0: 
Status: [T]est
Remarks: 
Dependencies: 
-
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_department_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_department_v;

-- Create view
CREATE VIEW ssd_development.ssd_department_v AS
SELECT 
    dpt.dim_department_id       AS dept_team_id,
    dpt.name                    AS dept_team_name,
    dpt.dept_id                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name
FROM HDM.Child_Social.DIM_DEPARTMENT dpt
WHERE dpt.dim_department_id <> -1;



/*
=============================================================================
Object Name: ssd_involvements
Description:
Author: D2I
Version: 1.2:
            1.1: Revisions to 1.0/0.9. DEPT_ID else .._HISTORY_DEPARTMENT_ID 300724 RH
            1.0: Trancated professional_team field IF comment data populates 110624 RH
            0.9: added person_id and changed source of professional_team 090424 JH
Status: [R]elease
Remarks:    v1.2 revisions backtrack prev changes in favour of dept/hist ID fields

            [TESTING] The below towards v1.0 for ref. only
            Regarding the increased size/len on invo_professional_team
            The (truncated)COMMENTS field is only used if:
                WORKER_HISTORY_DEPARTMENT_DESC is NULL.
                DEPARTMENT_NAME is NULL.
                GROUP_NAME is NULL.
                COMMENTS contains the keyword %WORKER% or %ALLOC%.
Dependencies:
- ssd_person
- FACT_INVOLVEMENTS
- ssd_departments (if obtaining team_name)
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_involvements_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_involvements_v;

-- Create view
CREATE VIEW ssd_development.ssd_involvements_v AS
SELECT
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    CASE 
        -- replace admin -1 values for when no worker associated
        WHEN fi.DIM_WORKER_ID IN ('-1', -1) THEN NULL    -- THEN '' (alternative null replacement)
        ELSE fi.DIM_WORKER_ID 
    END                                           AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
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
AND EXISTS (
    SELECT 1
    FROM ssd_development.ssd_person_v p
    WHERE CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799
);





/* 
=============================================================================
Object Name: ssd_linked_identifiers
Description: 
Author: D2I
Version: 1.1
            1.0: added source data for UPN+FORMER_UPN 140624 RH
            
Status: [R]elease
Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
            CMS modules. Can be re-enabled on a localised basis. 

        The list of allowed identifier_type codes are:
            ['Case Number', 
            'Unique Pupil Number', 
            'NHS Number', 
            'Home Office Registration', 
            'National Insurance Number', 
            'YOT Number', 
            'Court Case Number', 
            'RAA ID', 
            'Incident ID']
            To have any further codes agreed into the standard, issue a change request

Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_linked_identifiers_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_linked_identifiers_v;

-- Create view
CREATE VIEW ssd_development.ssd_linked_identifiers_v AS
SELECT
    NEWID()                            AS link_table_id,
    csp.dim_person_id                  AS link_person_id,
    'Former Unique Pupil Number'       AS link_identifier_type,
    'SSD_PH'                           AS link_identifier_value,       -- csp.former_upn [TESTING] Removed for compatibility
    NULL                               AS link_valid_from_date,        -- NULL for valid_from_date
    NULL                               AS link_valid_to_date           -- NULL for valid_to_date
FROM
    HDM.Child_Social.DIM_PERSON csp
WHERE
    csp.former_upn IS NOT NULL
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE p.pers_person_id = csp.dim_person_id
    )
UNION ALL
SELECT
    NEWID()                            AS link_table_id,
    csp.dim_person_id                  AS link_person_id,
    'Unique Pupil Number'              AS link_identifier_type,
    'SSD_PH'                           AS link_identifier_value,       -- csp.upn [TESTING] Removed for compatibility
    NULL                               AS link_valid_from_date,        -- NULL for valid_from_date
    NULL                               AS link_valid_to_date           -- NULL for valid_to_date
FROM
    HDM.Child_Social.DIM_PERSON csp
WHERE
    csp.upn IS NOT NULL
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE p.pers_person_id = csp.dim_person_id
    );



/* 
=============================================================================
Object Name: ssd_s251_finance_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists & drop 
IF OBJECT_ID('ssd_development.ssd_s251_finance_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_s251_finance_v;

-- Create view
CREATE VIEW ssd_development.ssd_s251_finance_v AS
SELECT
    NEWID() AS s251_table_id,
    NULL AS s251_cla_placement_id,
    NULL AS s251_placeholder_1,
    NULL AS s251_placeholder_2,
    NULL AS s251_placeholder_3,
    NULL AS s251_placeholder_4
WHERE 1 = 0;



/* 
=============================================================================
Object Name: ssd_voice_of_child_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists & drop 
IF OBJECT_ID('ssd_development.ssd_voice_of_child_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_voice_of_child_v;

-- Create view
CREATE VIEW ssd_development.ssd_voice_of_child_v AS
SELECT
    NEWID() AS voch_table_id,
    NULL AS voch_person_id,
    NULL AS voch_explained_worries,
    NULL AS voch_story_help_understand,
    NULL AS voch_agree_worker,
    NULL AS voch_plan_safe,
    NULL AS voch_tablet_help_explain
WHERE 1 = 0;




/* 
=============================================================================
Object Name: ssd_pre_proceedings_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_pre_proceedings_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_pre_proceedings_v;

-- Create view
CREATE VIEW ssd_development.ssd_pre_proceedings_v AS
SELECT
    NEWID() AS prep_table_id,
    NULL AS prep_person_id,
    NULL AS prep_plo_family_id,
    NULL AS prep_pre_pro_decision_date,
    NULL AS prep_initial_pre_pro_meeting_date,
    NULL AS prep_pre_pro_outcome,
    NULL AS prep_agree_stepdown_issue_date,
    NULL AS prep_cp_plans_referral_period,
    NULL AS prep_legal_gateway_outcome,
    NULL AS prep_prev_pre_proc_child,
    NULL AS prep_prev_care_proc_child,
    NULL AS prep_pre_pro_letter_date,
    NULL AS prep_care_pro_letter_date,
    NULL AS prep_pre_pro_meetings_num,
    NULL AS prep_pre_pro_parents_legal_rep,
    NULL AS prep_parents_legal_rep_point_of_issue,
    NULL AS prep_court_reference,
    NULL AS prep_care_proc_court_hearings,
    NULL AS prep_care_proc_short_notice,
    NULL AS prep_proc_short_notice_reason,
    NULL AS prep_la_inital_plan_approved,
    NULL AS prep_la_initial_care_plan,
    NULL AS prep_la_final_plan_approved,
    NULL AS prep_la_final_care_plan
WHERE 1 = 0;



/* 
=============================================================================
Object Name: ssd_send_v
Description: 
Author: D2I
Version: 1.0
            0.1: upn _unknown size change in line with DfE to 4 160524 RH
Status: [P]laceholder
Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
            CMS modules. Can be re-enabled on a localised basis. 
Dependencies: 
- FACT_903_DATA
- ssd_person
- Education.DIM_PERSON
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_send_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_send_v;

-- Create view
CREATE VIEW ssd_development.ssd_send_v AS
SELECT
    NEWID() AS send_table_id,          -- generate unique id
    csp.dim_person_id AS send_person_id,
    csp.upn AS send_upn,               -- csp.upn
    ep.uln  AS send_uln,               -- ep.uln               
    'SSD_PH' AS send_upn_unknown
FROM
    HDM.Child_Social.DIM_PERSON csp

LEFT JOIN
    -- we have to switch to Education schema in order to obtain this
    Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

WHERE
    EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person_v p
        WHERE p.pers_person_id = csp.dim_person_id
    );



/*
=============================================================================
Object Name: ssd_sen_need_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_sen_need_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_sen_need_v;

-- Create view
CREATE VIEW ssd_development.ssd_sen_need_v AS
SELECT
    NEWID() AS senn_table_id,          -- generate unique id
    NULL AS senn_active_ehcp_id,       -- placeholder field for active EHCP id
    NULL AS senn_active_ehcp_need_type,-- placeholder field for active EHCP need type
    NULL AS senn_active_ehcp_need_rank -- placeholder field for active EHCP need rank
WHERE 1 = 0;  --  view returns no rows|placeholder



/* 
=============================================================================
Object Name: ssd_ehcp_requests_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_ehcp_requests_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_ehcp_requests_v;

-- Create view
CREATE VIEW ssd_development.ssd_ehcp_requests_v AS
SELECT
    NEWID() AS ehcr_ehcp_request_id,    -- generate unique id
    NULL AS ehcr_send_table_id,         -- placeholder field for send table id
    NULL AS ehcr_ehcp_req_date,         -- placeholder field for EHCP request date
    NULL AS ehcr_ehcp_req_outcome_date, -- placeholder field for EHCP request outcome date
    NULL AS ehcr_ehcp_req_outcome       -- placeholder field for EHCP request outcome
WHERE 1 = 0;  -- This ensures the view returns no rows



/* 
=============================================================================
Object Name: ssd_ehcp_assessment_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_ehcp_assessment_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_ehcp_assessment_v;

-- Create view
CREATE VIEW ssd_development.ssd_ehcp_assessment_v AS
SELECT
    NEWID() AS ehca_ehcp_assessment_id,            -- generate unique id
    NULL AS ehca_ehcp_request_id,                  -- placeholder field for EHCP request id
    NULL AS ehca_ehcp_assessment_outcome_date,     -- placeholder field for EHCP assessment outcome date
    NULL AS ehca_ehcp_assessment_outcome,          -- placeholder field for EHCP assessment outcome
    NULL AS ehca_ehcp_assessment_exceptions        -- placeholder field for EHCP assessment exceptions
WHERE 1 = 0;  -- This ensures the view returns no rows



/* 
=============================================================================
Object Name: ssd_ehcp_named_plan_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_ehcp_named_plan_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_ehcp_named_plan_v;

-- Create view
CREATE VIEW ssd_development.ssd_ehcp_named_plan_v AS
SELECT
    NEWID() AS ehcn_named_plan_id,            -- generate unique id
    NULL AS ehcn_ehcp_asmt_id,                -- placeholder field for EHCP assessment id
    NULL AS ehcn_named_plan_start_date,       -- placeholder field for named plan start date
    NULL AS ehcn_named_plan_ceased_date,      -- placeholder field for named plan ceased date
    NULL AS ehcn_named_plan_ceased_reason     -- placeholder field for named plan ceased reason
WHERE 1 = 0;  -- This ensures the view returns no rows



/* 
=============================================================================
Object Name: ssd_ehcp_active_plans_v
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_ehcp_active_plans_v', 'V') IS NOT NULL DROP VIEW ssd_development.ssd_ehcp_active_plans_v;

-- Create view
CREATE VIEW ssd_development.ssd_ehcp_active_plans_v AS
SELECT
    NEWID() AS ehcp_active_ehcp_id,                -- generate unique id
    NULL AS ehcp_ehcp_request_id,                  -- placeholder field for EHCP request id
    NULL AS ehcp_active_ehcp_last_review_date      -- placeholder field for EHCP last review date
WHERE 1 = 0;  -- This ensures the view returns no rows



