
-- META-CONTAINER: {"type": "header", "name": "extract_settings"}
-- META-ELEMENT: {"type": "header"}


/*
*********************************************************************************************************
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

*We strongly recommend that all initial pilot/trials of SSD scripts occur in a development|test environment.*
*To make development deployment easier, we have left schema.table references where 'ssd_development.' is a 
default schema reference that can be easily removed or replaced as required. 
TO REMOVE: Search and replace the entire script 'ssd_development.' replace with ''(blank/nothing)
TO REPLACE: Search and replace the entire script 'ssd_development.' replace with 'your_dev_schema_name.'
- where quotes shown here are NOT used when doing the replacement! 

#LEGACY-PRE2016
For LA's running T-SQL 2016-Sp1+, search and re-activate the improved non-legacy blocks in the script. 
- Search for references to the tag #LEGACY-PRE2016 to find those. You then can remove the default legacy SQL. 

Script creates labelled persistent(unless set otherwise) tables in your existing|specified database. 

Data tables(with data copied from raw CMS tables) and indexes for the SSD are created, and therefore in some 
cases will need review and support and/or agreement from your IT or Intelligence team. 

The SQL script is non-destructive, but...(!)
The SSD script does use explicitly named DROP TABLE SSD_* commands. It does however not touch anything that is not 
prefixed SSD_. All SSD componenets are named SSD (indexes IX_SSD_ or UX_SSD_ or CIX_SSD_) to ensure schema clarity/oversight. 


Additional notes: 
A version that instead creates _temp|session tables is also available to enable those LA teams restricted to read access 
on the cms db|schema. A _temp script can also be created by performing the following adjustments:
    - Replace all instances of 'ssd_development.' with '#'

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
            [P]laceholder       -- Data not expected to be held by most LAs or new data, - placeholder structure

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

-- Core SSD timeframe parameter
DECLARE @ssd_timeframe_years INT = 6;   -- ssd extract time-frame (YRS)
DECLARE @ssd_sub1_range_years INT = 1;  -- ssd sub-window internal or additional LA use

-- Fix <today>
DECLARE @today_date  date     = CONVERT(date, GETDATE());
DECLARE @today_dt    datetime = CONVERT(datetime, @today_date);

-- Main SSD window, based on today
DECLARE @ssd_window_end   datetime = @today_dt;
DECLARE @ssd_window_start datetime = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);


-- CASELOAD count Date (Currently anchored: September 30th)
DECLARE @CaseloadLastSept30th date =
    CASE
        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30)
            THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30)
    END;

DECLARE @CaseloadTimeframeStartDate date =
    DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);
-- Example resultant dates into @CaseloadTimeframeStartDate
                                -- With 
                                -- @CaseloadLastSept30th = 30th September 2023
                                -- @CaseloadTimeframeStartDate = 30th September 2017



-- META-ELEMENT: {"type": "dbschema"}
-- Point to DB/TABLE_CATALOG if required (SSD tables created here)
USE HDM_Local;                           -- used in logging (and seperate clean-up script(s))

-- Example/Reference
-- ALTER USER [ESCC\RobertHa] WITH DEFAULT_SCHEMA = [ssd_development];

-- META-ELEMENT: {"type": "test"}
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder'; -- Note: also/seperately use of @table_name in non-test|live elements of script. 

-- META-END





/* ********************************************************************************************************** */
-- META-CONTAINER: {"type": "settings", "name": "testing"}
/* Towards simplistic TEST run outputs and logging  (to be removed from live v2+) */

-- META-ELEMENT: {"type": "test"}
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Script start time

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_version_log"}
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: SSD extract metadata enabling version consistency across LAs. 
-- Dependencies: 
-- - None
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_version_log';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_version_log', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_version_log)
        TRUNCATE TABLE ssd_development.ssd_version_log;
END
ELSE
BEGIN
    -- META-ELEMENT: {"type": "create_table"}
    -- create versioning information object
    CREATE TABLE ssd_development.ssd_version_log (
        version_number      NVARCHAR(10) PRIMARY KEY,   -- version num (e.g., "1.0.0")
        release_date        DATE NOT NULL,              -- date of version release
        description         NVARCHAR(100),              -- brief description of version
        is_current          BIT NOT NULL DEFAULT 0,     -- flag to indicate if this is the current version
        created_at          DATETIME DEFAULT GETDATE(), -- timestamp when record was created
        created_by          NVARCHAR(10),               -- which user created the record
        impact_description  NVARCHAR(255)               -- additional notes on the impact of the release
    );
END


-- ensure any previous current-version flag is set to 0 (not current), before adding new current version detail
UPDATE ssd_development.ssd_version_log SET is_current = 0 WHERE is_current = 1;

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    -- CURRENT version (using MAJOR.MINOR.PATCH)
    ('1.3.6', '2025-12-03', 'drop use of ssd_cutoff, correction in cohort verification', 1, 'admin', 'drop @ssd_cutoff, reuse @ssd_window_start as core timeframe anchor');


-- HISTORIC versioning log data
INSERT INTO ssd_development.ssd_version_log (version_number, release_date, description, is_current, created_by, impact_description)
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
    ('1.2.2', '2024-11-06', '#DtoI-1826, META+YML restructure incl. remove opt blocks', 0, 'admin', 'feat/bespoke LA extracts'),
    ('1.2.3', '2024-11-20', 'non-core ssd_flag field removal', 0, 'admin', 'no wider impact'),
    ('1.2.4', '2025-09-10', 'legacy support for json fields #LEGACY-PRE2016 tags', 0, 'admin', 'all json field alternative sql'),
    ('1.2.6', '2025-09-10', 'Disable FK definitions by default', 0, 'admin', 'improve deployment compatiblity'),
    ('1.2.7', '2025-09-10', 'remove ssd_api_data_staging - now part of api release', 0, 'admin', 'patch fix'),
    ('1.2.8', '2025-09-13', 'assessment_factors & cla_episodes refactor', 0, 'admin', 'early adopters suggested patch fix'),
    ('1.2.9', '2025-09-22', 'assessment_factors refactor now with pre-aggr, fix pre-compile issue SQL <2016', 0, 'admin', 'improved run time perf, ease of opt A/B toggle'),
    ('1.3.0', '2025-09-24', 'New ssd_cohort for cohort visibility/monitoring', 0, 'admin', 'provides breakdown of cohort origins - later use to ease current EXISTS backchecks on ssd_person'),
    ('1.3.1', '2025-10-03', 'Coventry suggested on ssd_assessment_factors', 0, 'admin', 'adjmts provided by Coventry to provide more robust pulling of assessment factor data where filter might not align with prev-family assessments-'),
    ('1.3.2', '2025-11-10', 'Block out string_agg on ssd_assessment_factors', 0, 'admin', 'fix needed to prevent legacy sql failing on string_agg in modern selection block'),
    ('1.3.3', '2025-11-13', 's-colon pre CTE bug fix', 0, 'admin', 'non-recognised s-colon pre CTEs + introduced commented hard filter on child ids for LA use'),
    ('1.3.4', '2025-11-20', 'sdq scores history, score date and timeframe fix', 0, 'admin', 'patch missing sdq scores history, incorrect hard-coded sdq date field'),
    ('1.3.5', '2025-11-21', 'new pre-computed window_start filter added', 0, 'admin', 'Initially applied to sdq scores as timeframe filter. Will be applied throughout');


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END



/* ********************************************************************************************************** */
/* START SSD main extract */




-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. This the most connected table in the SSD.
-- Author: D2I
-- Version: 
--              1.4: pers_common_child_id renamed - to pers_single_unique_id (TAG|System C approved (NHS IG Toolkit))
--              1.3: upn reinstated as pulled from dim_person 171125 RH
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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_person';


/* START - Temp Hard drop and recreate due to d2i structure changes  */
IF OBJECT_ID(N'ssd_development.ssd_person', N'U') IS NOT NULL
    DROP TABLE ssd_development.ssd_person;
/* END - remove this tmp block once SSD has run once for v1.3.5+!  */


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;

IF OBJECT_ID('ssd_development.ssd_person') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_person)
        TRUNCATE TABLE ssd_development.ssd_person;
END
ELSE
-- META-ELEMENT: {"type": "create_table"}
BEGIN
    CREATE TABLE ssd_development.ssd_person (
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


-- META-ELEMENT: {"type": "insert_data"}
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
INSERT INTO ssd_development.ssd_person (
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
    p.UPN,                                  --     
    p.FORENAME, 
    p.SURNAME,
    p.GENDER_MAIN_CODE AS pers_sex,         -- Sex/Gender as used in stat-returns
    p.GENDER_MAIN_CODE,                     -- Placeholder for those LAs that store sex and gender independently
    p.ETHNICITY_MAIN_CODE,                  -- [REVIEW] LEFT(p.ETHNICITY_MAIN_CODE, 4)
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM                   -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL                           -- or NULL
    END, 
    NULL AS pers_single_unique_id,           -- Set to NULL as default(dev) / or set to NHS num / or set to Single Unique Identifier(SUI)
    -- COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
    f903.NO_UPN_CODE AS pers_upn_unknown, 
    p.EHM_SEN_FLAG,
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM                   -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL                           -- or NULL
    END, 
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND  -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI') -- check for child relation only
        THEN 'Y'
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
				-- AND START_DTTM > '2009-12-04 00:54:49.947' -- #DtoI-1830 care leavers who were aged 22-25 and may not have had Allocated Case Worker relationship for years+
				AND DIM_WORKER_ID <> '-1' 
                AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE()))
            )
        )
    )
;


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_person_pers_dob               ON ssd_development.ssd_person(pers_dob);
-- CREATE NONCLUSTERED INDEX IX_ssd_person_pers_common_child_id   ON ssd_development.ssd_person(pers_common_child_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_person_ethnicity_gender       ON ssd_development.ssd_person(pers_ethnicity, pers_gender);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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


-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cohort"}
-- =============================================================================
-- Description: Test deployment to avoid EXISTS hits on ssd_person + enable source checks 
-- Author: D2I
-- Version: 1.0
--          
-- Status: [D]ev
-- Remarks: This is an in-dev table in order to better optimise the process of getting SSD cohort 
--          details into other related tables and help flag why they are included. 
--          Provides stable join pattern everywhere, shift from ssd_person
--          for WHERE EXISTS to reduce scan loads during ssd deployment. Provide 
--          flags for record(s) source visibility.   
-- Dependencies:

-- =============================================================================


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cohort';

-- -- Use-case: We're rolling this out to (new)ssd tables 
-- INNER JOIN ssd_development.ssd_cohort co
--   ON co.dim_person_id = TRY_CONVERT(nvarchar(48), p.DIM_PERSON_ID)
-- -- WHERE co.has_contact = 1 -- e.g. filter on 

-- -- Sanity check (date threshold == today’s date(midnight) - SSDyrs )
-- SELECT DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE()))) AS current_cutoff_local;

SET NOCOUNT ON;

DECLARE @src_db     sysname = N'HDM';
DECLARE @src_schema sysname = N'Child_Social';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cohort', 'U') IS NOT NULL DROP TABLE #ssd_cohort;

-- IF OBJECT_ID(N'ssd_development.ssd_cohort', N'U') IS NOT NULL
-- DROP TABLE ssd_development.ssd_cohort;

IF OBJECT_ID('ssd_development.ssd_cohort', 'U') IS NOT NULL
BEGIN
  IF EXISTS (SELECT 1 FROM ssd_development.ssd_cohort)
    TRUNCATE TABLE ssd_development.ssd_cohort;
END
ELSE
-- META-ELEMENT: {"type": "create_table"}
BEGIN
  CREATE TABLE ssd_development.ssd_cohort(
    dim_person_id         nvarchar(48)  NOT NULL PRIMARY KEY,
    legacy_id             nvarchar(48)  NULL,

    has_contact           bit           NOT NULL DEFAULT(0),
    has_referral          bit           NOT NULL DEFAULT(0),
    has_903               bit           NOT NULL DEFAULT(0),
    is_care_leaver        bit           NOT NULL DEFAULT(0),
    has_eligibility       bit           NOT NULL DEFAULT(0),
    has_client_flag       bit           NOT NULL DEFAULT(0),
    has_involvement       bit           NOT NULL DEFAULT(0),

    first_activity_dttm   datetime      NULL,   -- min of contact/referral dates
    last_activity_dttm    datetime      NULL    -- max of contact/referral dates
  );
END


/* Build 3-part prefix once */
DECLARE @dbq  nvarchar(260) = QUOTENAME(@src_db);
DECLARE @scq  nvarchar(260) = QUOTENAME(@src_schema);
DECLARE @src3 nvarchar(600) = @dbq + N'.' + @scq + N'.';

/* Template with placeholder for 3-part name: __SRC__ */
DECLARE @tpl nvarchar(max) = N'
;WITH contacts AS (
  SELECT
    TRY_CONVERT(nvarchar(48), c.DIM_PERSON_ID) AS dim_person_id,
    MAX(TRY_CONVERT(datetime, c.CONTACT_DTTM)) AS last_contact_dttm,
    MIN(TRY_CONVERT(datetime, c.CONTACT_DTTM)) AS first_contact_dttm
  FROM __SRC__FACT_CONTACTS AS c
  WHERE (@ssd_timeframe_years IS NULL
         OR c.CONTACT_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE()))))
    AND c.DIM_PERSON_ID <> -1
  GROUP BY c.DIM_PERSON_ID
),
a903 AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), f.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_903_DATA AS f
  WHERE f.DIM_PERSON_ID <> -1
),
clients AS (
  SELECT TRY_CONVERT(nvarchar(48), p.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__DIM_PERSON p
  WHERE p.DIM_PERSON_ID <> -1
    AND p.IS_CLIENT = ''Y''
),
refs AS (
  SELECT
    TRY_CONVERT(nvarchar(48), r.DIM_PERSON_ID) AS dim_person_id,
    MAX(TRY_CONVERT(datetime, r.REFRL_START_DTTM)) AS last_ref_dttm,
    MIN(TRY_CONVERT(datetime, r.REFRL_START_DTTM)) AS first_ref_dttm
  FROM __SRC__FACT_REFERRALS r
  WHERE r.DIM_PERSON_ID <> -1
    AND (
         r.REFRL_START_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
      OR r.REFRL_END_DTTM   >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
      OR r.REFRL_END_DTTM IS NULL
    )
  GROUP BY r.DIM_PERSON_ID
),
careleaver AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), cl.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_CLA_CARE_LEAVERS cl
  WHERE cl.DIM_PERSON_ID <> -1
    AND cl.IN_TOUCH_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
),
elig AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), e.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__DIM_CLA_ELIGIBILITY e
  WHERE e.DIM_PERSON_ID <> -1
    AND e.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
),
involvements AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), i.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_INVOLVEMENTS i
  WHERE i.DIM_PERSON_ID <> -1
    AND (i.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE ''KA%'' 
         OR i.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL
         OR i.IS_ALLOCATED_CW_FLAG = ''Y'')
    AND i.DIM_WORKER_ID <> ''-1''
    AND (i.END_DTTM IS NULL OR i.END_DTTM > GETDATE())
),
unioned AS (
  SELECT dim_person_id, 1 AS has_contact, 0 AS has_referral, 0 AS has_903, 0 AS is_care_leaver, 0 AS has_eligibility, 1 AS has_client_flag, 0 AS has_involvement, first_contact_dttm AS first_dttm, last_contact_dttm AS last_dttm FROM contacts
  UNION ALL SELECT dim_person_id, 0,1,0,0,0,0,0, first_ref_dttm,  last_ref_dttm  FROM refs
  UNION ALL SELECT dim_person_id, 0,0,1,0,0,0,0, NULL,            NULL           FROM a903
  UNION ALL SELECT dim_person_id, 0,0,0,1,0,0,0, NULL,            NULL           FROM careleaver
  UNION ALL SELECT dim_person_id, 0,0,0,0,1,0,0, NULL,            NULL           FROM elig
  UNION ALL SELECT dim_person_id, 0,0,0,0,0,1,0, NULL,            NULL           FROM clients
  UNION ALL SELECT dim_person_id, 0,0,0,0,0,0,1, NULL,            NULL           FROM involvements
),
rollup AS (
  SELECT
    u.dim_person_id,
    CAST(MAX(CASE WHEN has_contact           = 1 THEN 1 ELSE 0 END) AS bit) AS has_contact,
    CAST(MAX(CASE WHEN has_referral          = 1 THEN 1 ELSE 0 END) AS bit) AS has_referral,
    CAST(MAX(CASE WHEN has_903               = 1 THEN 1 ELSE 0 END) AS bit) AS has_903,
    CAST(MAX(CASE WHEN is_care_leaver        = 1 THEN 1 ELSE 0 END) AS bit) AS is_care_leaver,
    CAST(MAX(CASE WHEN has_eligibility       = 1 THEN 1 ELSE 0 END) AS bit) AS has_eligibility,
    CAST(MAX(CASE WHEN has_client_flag       = 1 THEN 1 ELSE 0 END) AS bit) AS has_client_flag,
    CAST(MAX(CASE WHEN has_involvement       = 1 THEN 1 ELSE 0 END) AS bit) AS has_involvement,
    MIN(first_dttm) AS first_activity_dttm,
    MAX(last_dttm)  AS last_activity_dttm
  FROM unioned u
  GROUP BY u.dim_person_id
)
INSERT ssd_development.ssd_cohort(
  dim_person_id, legacy_id,
  has_contact, has_referral, has_903, is_care_leaver, has_eligibility,
  has_client_flag, has_involvement,            
  first_activity_dttm, last_activity_dttm
)
SELECT
  r.dim_person_id,
  MAX(dp.LEGACY_ID) AS legacy_id,
  r.has_contact, r.has_referral, r.has_903, r.is_care_leaver, r.has_eligibility,
  r.has_client_flag, r.has_involvement,        
  r.first_activity_dttm, r.last_activity_dttm
FROM rollup AS r
LEFT JOIN __SRC__DIM_PERSON AS dp
  ON dp.DIM_PERSON_ID = TRY_CONVERT(int, r.dim_person_id)
GROUP BY r.dim_person_id, r.has_contact, r.has_referral, r.has_903, r.is_care_leaver,
         r.has_eligibility, r.has_client_flag, r.has_involvement,  -- <<< keep in GROUP BY too
         r.first_activity_dttm, r.last_activity_dttm;
';

/* Swap in 3-part prefix once */
DECLARE @sql nvarchar(max) = REPLACE(@tpl, N'__SRC__', @src3);

-- Optional: inspect generated SQL around contacts CTE if needed
-- PRINT LEFT(@sql, 2000);


-- passing just scalar needed
EXEC sp_executesql
    @sql,
    N'@ssd_timeframe_years int',
    @ssd_timeframe_years = @ssd_timeframe_years;

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE INDEX IX_ssd_cohort_has_referral ON ssd_development.ssd_cohort(dim_person_id) WHERE has_referral = 1;
-- CREATE INDEX IX_ssd_cohort_has_involvement ON ssd_development.ssd_cohort(dim_person_id) WHERE has_involvement = 1;



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

/* SSD summary 
Show breakdown of why/source of records included in ssd cohort */
SELECT
  COUNT(*) AS ssd_cohort_rows,
  SUM(CASE WHEN has_contact=1      THEN 1 ELSE 0 END) AS with_contacts,
  SUM(CASE WHEN has_referral=1     THEN 1 ELSE 0 END) AS with_referrals,
  SUM(CASE WHEN has_903=1          THEN 1 ELSE 0 END) AS in_903,
  SUM(CASE WHEN is_care_leaver=1   THEN 1 ELSE 0 END) AS care_leavers,
  SUM(CASE WHEN has_eligibility=1  THEN 1 ELSE 0 END) AS with_eligibility,
  SUM(CASE WHEN has_client_flag=1  THEN 1 ELSE 0 END) AS has_client_flag,
  SUM(CASE WHEN has_involvement=1  THEN 1 ELSE 0 END) AS with_involvement
FROM ssd_development.ssd_cohort;



-- META-END



-- META-CONTAINER: {"type": "table", "name": "ADMIN COHORT VERIFICATION ONLY"}
-- =============================================================================
-- Purpose: Compare orig ssd_person inclusion, ssd_cohort driven inclusion, and API cohort
-- Notes: assumes already declared:
--        @ssd_timeframe_years, @today_date, @ssd_window_start, @ssd_window_end
-- =============================================================================

SET NOCOUNT ON;

-- reset tmp tables
IF OBJECT_ID('tempdb..#ssd_core_cohort')   IS NOT NULL DROP TABLE #ssd_core_cohort;
IF OBJECT_ID('tempdb..#ssd_review_cohort') IS NOT NULL DROP TABLE #ssd_review_cohort;
IF OBJECT_ID('tempdb..#ssd_api_cohort')    IS NOT NULL DROP TABLE #ssd_api_cohort;

-- declare per session
IF OBJECT_ID('tempdb..#ssd_scope_marker') IS NULL
BEGIN
  -- EA or API cohort window variables, separate from core SSD N year window
  DECLARE @ea_months_back    int; -- 24
  DECLARE @ea_fy_start_month int; -- 4/April
  DECLARE @ea_anchor         date;
  DECLARE @ea_fy_start_year  int; -- EA financial year start yr, to build @ea_window_start April 1 in financial year for 24 month EA window
  DECLARE @ea_window_start   date;
  DECLARE @ea_window_end     date;
-- Logic e.g. If @ea_anchor is 02 December 2023, mth 12 is not less than 4, so @ea_fy_start_year = 2023; @ea_window_start becomes 01 April 2023.

  SELECT 1 AS mk INTO #ssd_scope_marker;
END;

-- reinitialise EA or API window each run
SET @ea_months_back    = 24;
SET @ea_fy_start_month = 4;
SET @ea_anchor         = DATEADD(month, -@ea_months_back, @today_date);
SET @ea_fy_start_year  = YEAR(@ea_anchor)
                         - CASE WHEN MONTH(@ea_anchor) < @ea_fy_start_month THEN 1 ELSE 0 END;
SET @ea_window_start   = DATEFROMPARTS(@ea_fy_start_year, @ea_fy_start_month, 1);
SET @ea_window_end     = @today_date;

------------------------------------------------------------
-- A) Core cohort, rebuilds original ssd_person EXISTS logic over HDM
--    anchored on SSD core window @ssd_window_start
------------------------------------------------------------
CREATE TABLE #ssd_core_cohort(dim_person_id nvarchar(48) NOT NULL PRIMARY KEY);

INSERT INTO #ssd_core_cohort(dim_person_id)
SELECT DISTINCT CAST(p.DIM_PERSON_ID AS nvarchar(48))
FROM HDM.Child_Social.DIM_PERSON p
WHERE p.DIM_PERSON_ID IS NOT NULL
  AND p.DIM_PERSON_ID <> -1
  AND (
    p.IS_CLIENT = 'Y'
    OR EXISTS (
          SELECT 1
          FROM HDM.Child_Social.FACT_CONTACTS fc
          WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
            AND fc.CONTACT_DTTM >= @ssd_window_start
        )
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
    OR EXISTS (
          SELECT 1
          FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
          WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
            AND fccl.IN_TOUCH_DTTM >= @ssd_window_start
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
                  fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%'
               OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL
               OR fi.IS_ALLOCATED_CW_FLAG = 'Y'
            )
            AND fi.DIM_WORKER_ID <> '-1'
            AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE())
        )
  );

------------------------------------------------------------
-- B) Review cohort, same inclusion set but via ssd_cohort flags
--    excludes has_903. Keeps to prove flag path equals the heavy EXISTS path
------------------------------------------------------------
CREATE TABLE #ssd_review_cohort(dim_person_id nvarchar(48) NOT NULL PRIMARY KEY);

INSERT INTO #ssd_review_cohort(dim_person_id)
SELECT co.dim_person_id
FROM ssd_development.ssd_cohort co
WHERE co.has_contact      = 1
   OR co.has_referral     = 1
   OR co.is_care_leaver   = 1
   OR co.has_eligibility  = 1
   OR co.has_client       = 1
   OR co.has_involvement  = 1;
-- optional to include 903 in the parity set
--   OR co.has_903          = 1;

------------------------------------------------------------
-- C) API cohort, same rules as payload window
--    uses EA window (@ea_window_start, @ea_window_end) not SSD core window
------------------------------------------------------------
CREATE TABLE #ssd_api_cohort(person_id nvarchar(48) NOT NULL PRIMARY KEY);

;WITH
EligibleBySpec AS (  -- unborn or ever age 25 or below within the EA window, includes deceased
  SELECT TRY_CONVERT(nvarchar(48), p.pers_person_id) AS person_id
  FROM ssd_development.ssd_person p
  WHERE p.pers_expected_dob IS NOT NULL
     OR (
          p.pers_dob IS NOT NULL
      AND DATEADD(year, 26, p.pers_dob) >= @ea_window_start
        )
),
ActiveReferral AS (
  SELECT DISTINCT cine.cine_person_id AS person_id
  FROM ssd_cin_episodes cine
  WHERE cine.cine_referral_date <= @ea_window_end
    AND (cine.cine_close_date IS NULL OR cine.cine_close_date >= @ea_window_start)
    AND (cine.cine_close_date IS NULL OR cine.cine_close_date >  @ea_window_end)
),
WaitingAssessment AS (
  SELECT DISTINCT cine.cine_person_id AS person_id
  FROM ssd_cin_episodes cine
  WHERE cine.cine_close_date IS NULL
    AND NOT EXISTS (
          SELECT 1
          FROM ssd_cin_assessments ca
          WHERE ca.cina_referral_id = cine.cine_referral_id
            AND ca.cina_assessment_start_date IS NOT NULL
    )
),
HasCINPlan AS (
  SELECT DISTINCT cinp.cinp_person_id AS person_id
  FROM ssd_cin_plans cinp
  WHERE cinp.cinp_cin_plan_start_date <= @ea_window_end
    AND (cinp.cinp_cin_plan_end_date IS NULL OR cinp.cinp_cin_plan_end_date >= @ea_window_start)
),
HasCPPlan AS (
  SELECT DISTINCT cppl.cppl_person_id AS person_id
  FROM ssd_cp_plans cppl
  WHERE cppl.cppl_cp_plan_start_date <= @ea_window_end
    AND (cppl.cppl_cp_plan_end_date IS NULL OR cppl.cppl_cp_plan_end_date >= @ea_window_start)
),
HasLAC AS (
  SELECT DISTINCT clae.clae_person_id AS person_id
  FROM ssd_cla_episodes clae
  JOIN ssd_cin_episodes cine
    ON cine.cine_referral_id = clae.clae_referral_id
  WHERE cine.cine_referral_date <= @ea_window_end
    AND (cine.cine_close_date IS NULL OR cine.cine_close_date >= @ea_window_start)

  UNION

  SELECT DISTINCT clae2.clae_person_id AS person_id
  FROM ssd_cla_episodes clae2
  JOIN ssd_cla_placement clap
    ON clap.clap_cla_id = clae2.clae_cla_id
  WHERE clap.clap_cla_placement_start_date <= @ea_window_end
    AND (clap.clap_cla_placement_end_date IS NULL OR clap.clap_cla_placement_end_date >= @ea_window_start)
),
IsCareLeaver16to25 AS (
  SELECT DISTINCT clea.clea_person_id AS person_id
  FROM ssd_care_leavers clea
  JOIN ssd_development.ssd_person p
    ON p.pers_person_id = clea.clea_person_id
  WHERE clea.clea_care_leaver_latest_contact BETWEEN @ea_window_start AND @ea_window_end
    AND (
          (p.pers_dob IS NOT NULL AND DATEDIFF(year, p.pers_dob, @ea_window_end) BETWEEN 16 AND 25)
       OR (p.pers_dob IS NULL AND p.pers_expected_dob IS NOT NULL)
    )
),
IsDisabled AS (
  SELECT DISTINCT d.disa_person_id AS person_id
  FROM ssd_disability d
  WHERE NULLIF(LTRIM(RTRIM(d.disa_disability_code)), '') IS NOT NULL
),
SpecInclusion AS (
  SELECT person_id FROM ActiveReferral
  UNION SELECT person_id FROM WaitingAssessment
  UNION SELECT person_id FROM HasCINPlan
  UNION SELECT person_id FROM HasCPPlan
  UNION SELECT person_id FROM HasLAC
  UNION SELECT person_id FROM IsCareLeaver16to25
  UNION SELECT person_id FROM IsDisabled
),
ApiCohortIDs AS (
  SELECT e.person_id
  FROM EligibleBySpec e
  JOIN SpecInclusion s
    ON s.person_id = e.person_id
)
INSERT INTO #ssd_api_cohort(person_id)
SELECT DISTINCT person_id
FROM ApiCohortIDs;

------------------------------------------------------------
-- D) Headline counts
--   core_count, live recompute from HDM using orig EXISTS path and SSD core window @ssd_window_start
--   ssd_cohort_count, from persisted flag table ssd_development.ssd_cohort
--   api_count, EA cohort window based on @ea_window_start and @ea_window_end
------------------------------------------------------------
SELECT
  c.core_count,
  h.ssd_cohort_count,
  a.api_count
  -- , h903.ssd_cohort_incl903_count  -- include 903 rows
FROM
  (SELECT COUNT(*) AS core_count
   FROM #ssd_core_cohort) AS c
CROSS JOIN
  (SELECT COUNT(*) AS ssd_cohort_count
   FROM ssd_development.ssd_cohort
   WHERE has_contact = 1
      OR has_referral = 1
      OR is_care_leaver = 1
      OR has_eligibility = 1
      OR has_client = 1
      OR has_involvement = 1
      -- OR has_903 = 1  -- uncomment to include 903 rows in counts
  ) AS h
CROSS JOIN
  (SELECT COUNT(*) AS api_count
   FROM #ssd_api_cohort) AS a;
-- optional extra cross join to show include 903 variant alongside default
-- CROSS JOIN
--   (SELECT COUNT(*) AS ssd_cohort_incl903_count
--    FROM ssd_development.ssd_cohort
--    WHERE has_contact = 1
--       OR has_referral = 1
--       OR is_care_leaver = 1
--       OR has_eligibility = 1
--       OR has_client = 1
--       OR has_involvement = 1
--       OR has_903 = 1
--   ) AS h903
;

-- END "ADMIN COHORT VERIFICATION ONLY"

-- META-END






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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_family';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_family', 'U') IS NOT NULL DROP TABLE #ssd_family;

IF OBJECT_ID('ssd_development.ssd_family', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_family)
        TRUNCATE TABLE ssd_development.ssd_family;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_family (
        fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
        fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
        fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )


SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM HDM.Child_Social.FACT_CONTACTS AS fc

WHERE fc.DIM_PERSON_ID <> -1
    AND EXISTS ( -- only ssd relevant records
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT FK_ssd_family_person
-- FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_family_person_id          ON ssd_development.ssd_family(fami_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END



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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_address';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_address', 'U') IS NOT NULL DROP TABLE #ssd_address;

IF OBJECT_ID('ssd_development.ssd_address','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_address)
        TRUNCATE TABLE ssd_development.ssd_address;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_address (
        addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
        addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
        addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
        addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
        addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
        addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
        addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_address (
    addr_table_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start_date, 
    addr_address_end_date, 
    addr_address_postcode, 
    addr_address_json
)

-- #LEGACY-PRE2016 
-- SQL compatible versions <2016
SELECT  
    pa.DIM_PERSON_ADDRESS_ID,
    pa.DIM_PERSON_ID, 
    pa.ADDSS_TYPE_CODE,
    pa.START_DTTM,
    pa.END_DTTM,
    CASE 
        WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', '')))
            THEN ''  -- clear postcode containing all X's
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode'
            THEN ''  -- clear 'nopostcode' strs
        ELSE
            LTRIM(RTRIM(pa.POSTCODE))  -- keep internal space(s)
    END AS CleanedPostcode,
    (
        '{' +
        '"ROOM": "' + ISNULL(TRY_CAST(pa.ROOM_NO AS NVARCHAR(50)), '') + '", ' +
        '"FLOOR": "' + ISNULL(TRY_CAST(pa.FLOOR_NO AS NVARCHAR(50)), '') + '", ' +
        '"FLAT": "' + ISNULL(TRY_CAST(pa.FLAT_NO AS NVARCHAR(50)), '') + '", ' +
        '"BUILDING": "' + ISNULL(pa.BUILDING, '') + '", ' +
        '"HOUSE": "' + ISNULL(TRY_CAST(pa.HOUSE_NO AS NVARCHAR(50)), '') + '", ' +
        '"STREET": "' + ISNULL(pa.STREET, '') + '", ' +
        '"TOWN": "' + ISNULL(pa.TOWN, '') + '", ' +
        '"UPRN": "' + ISNULL(TRY_CAST(pa.UPRN AS NVARCHAR(50)), '') + '", ' +
        '"EASTING": "' + ISNULL(TRY_CAST(pa.EASTING AS NVARCHAR(20)), '') + '", ' +
        '"NORTHING": "' + ISNULL(TRY_CAST(pa.NORTHING AS NVARCHAR(20)), '') + '"' +
        '}'
    ) AS addr_address_json
FROM 
    HDM.Child_Social.DIM_PERSON_ADDRESS AS pa

WHERE pa.DIM_PERSON_ID <> -1
    AND EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID -- #DtoI-1799
    );


-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT 
--     pa.DIM_PERSON_ADDRESS_ID,
--     pa.DIM_PERSON_ID, 
--     pa.ADDSS_TYPE_CODE,
--     pa.START_DTTM,
--     pa.END_DTTM,
--     CASE 
--         WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', '')))
--             THEN ''  -- clear postcode containing all X's
--         WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode'
--             THEN ''  -- clear postcode containing 'nopostcode'
--         ELSE
--             LTRIM(RTRIM(pa.POSTCODE))  -- keep any internal space(s), just trim ends
--     END AS CleanedPostcode,
--     (
    
--     SELECT 
--         -- SSD standard 
--         -- all keys in structure regardless of data presence
--         ISNULL(pa.ROOM_NO, '')    AS ROOM, 
--         ISNULL(pa.FLOOR_NO, '')   AS FLOOR, 
--         ISNULL(pa.FLAT_NO, '')    AS FLAT, 
--         ISNULL(pa.BUILDING, '')   AS BUILDING, 
--         ISNULL(pa.HOUSE_NO, '')   AS HOUSE, 
--         ISNULL(pa.STREET, '')     AS STREET, 
--         ISNULL(pa.TOWN, '')       AS TOWN,
--         ISNULL(pa.UPRN, '')       AS UPRN,
--         ISNULL(pa.EASTING, '')    AS EASTING,
--         ISNULL(pa.NORTHING, '')   AS NORTHING
--     FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS addr_address_json
-- FROM 
--     HDM.Child_Social.DIM_PERSON_ADDRESS AS pa

-- WHERE pa.DIM_PERSON_ID <> -1
--     AND EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_address ADD CONSTRAINT FK_ssd_address_person
-- FOREIGN KEY (addr_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_address_person        ON ssd_development.ssd_address(addr_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_address_start         ON ssd_development.ssd_address(addr_address_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_address_end           ON ssd_development.ssd_address(addr_address_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_ssd_address_postcode  ON ssd_development.ssd_address(addr_address_postcode);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END




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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_disability';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_disability', 'U') IS NOT NULL DROP TABLE #ssd_disability;

IF OBJECT_ID('ssd_development.ssd_disability','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_disability)
        TRUNCATE TABLE ssd_development.ssd_disability;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_disability
    (
        disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
        disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
        disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)
SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id,  -- #TESTING|Debug, bringing NULL values through? 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    HDM.Child_Social.FACT_DISABILITY AS fd

WHERE fd.DIM_PERSON_ID <> -1
AND fd.DIM_LOOKUP_DISAB_CODE IS NOT NULL
    AND EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fd.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_development.ssd_disability ADD CONSTRAINT FK_ssd_disability_person 
-- FOREIGN KEY (disa_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_person_id  ON ssd_development.ssd_disability(disa_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_disability_code       ON ssd_development.ssd_disability(disa_disability_code);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END



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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_immigration_status';
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_immigration_status', 'U') IS NOT NULL DROP TABLE #ssd_immigration_status;

IF OBJECT_ID('ssd_development.ssd_immigration_status','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_immigration_status)
        TRUNCATE TABLE ssd_development.ssd_immigration_status;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_immigration_status (
        immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
        immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
        immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
        immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
        immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC
FROM
    HDM.Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE
    EXISTS
    ( -- only ssd relevant records
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = ims.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_immigration_status ADD CONSTRAINT FK_ssd_immigration_status_person
-- FOREIGN KEY (immi_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_immi_person_id ON ssd_development.ssd_immigration_status(immi_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_start          ON ssd_development.ssd_immigration_status(immi_immigration_status_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_immigration_status_end            ON ssd_development.ssd_immigration_status(immi_immigration_status_end_date);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END






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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cin_episodes';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cin_episodes', 'U') IS NOT NULL DROP TABLE #ssd_cin_episodes;

IF OBJECT_ID('ssd_development.ssd_cin_episodes','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cin_episodes)
        TRUNCATE TABLE ssd_development.ssd_cin_episodes;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cin_episodes
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



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_episodes
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
        '{' +
        '"SINGLE_ASSESSMENT_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG AS NVARCHAR(3)), '') + '", ' +
        -- '"NFA_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' + -- Uncomment if needed
        '"STRATEGY_DISCUSSION_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CLA_REQUEST_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_CLA_REQUEST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NON_AGENCY_ADOPTION_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PRIVATE_FOSTERING_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CP_TRANSFER_IN_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_CP_TRANSFER_IN_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CP_CONFERENCE_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_CP_CONFERENCE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CARE_LEAVER_FLAG": "' + ISNULL(TRY_CAST(fr.OUTCOME_CARE_LEAVER_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(fr.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NUMBER_OF_OUTCOMES": ' + 
            ISNULL(TRY_CAST(CASE 
                WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL
                ELSE fr.TOTAL_NO_OF_OUTCOMES 
            END AS NVARCHAR(4)), 'null') + ', ' +
        '"COMMENTS": "' + ISNULL(TRY_CAST(fr.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
        '}'
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
    FROM ssd_development.ssd_person p
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
--             ISNULL(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')   AS SINGLE_ASSESSMENT_FLAG,
--             -- ISNULL(fr.OUTCOME_NFA_FLAG, '')                 AS NFA_FLAG,
--             ISNULL(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS STRATEGY_DISCUSSION_FLAG,
--             ISNULL(fr.OUTCOME_CLA_REQUEST_FLAG, '')         AS CLA_REQUEST_FLAG,
--             ISNULL(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS NON_AGENCY_ADOPTION_FLAG,
--             ISNULL(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '')   AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '')      AS CP_TRANSFER_IN_FLAG,
--             ISNULL(fr.OUTCOME_CP_CONFERENCE_FLAG, '')       AS CP_CONFERENCE_FLAG,
--             ISNULL(fr.OUTCOME_CARE_LEAVER_FLAG, '')         AS CARE_LEAVER_FLAG,
--             ISNULL(fr.OTHER_OUTCOMES_EXIST_FLAG, '')        AS OTHER_OUTCOMES_EXIST_FLAG,
--             CASE 
--                 WHEN fr.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
--                 ELSE fr.TOTAL_NO_OF_OUTCOMES 
--             END                                             AS NUMBER_OF_OUTCOMES,
--             ISNULL(fr.OUTCOME_COMMENTS, '')                 AS COMMENTS
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
--     FROM ssd_development.ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fr.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
-- FOREIGN KEY (cine_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_episodes_person_id    ON ssd_development.ssd_cin_episodes(cine_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_referral_date             ON ssd_development.ssd_cin_episodes(cine_referral_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_close_date                ON ssd_development.ssd_cin_episodes(cine_close_date);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_mother';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_mother', 'U') IS NOT NULL DROP TABLE #ssd_mother;

IF OBJECT_ID('ssd_development.ssd_mother','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_mother)
        TRUNCATE TABLE ssd_development.ssd_mother;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_mother (
        moth_table_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"MOTH004A"}
        moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
        moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
        moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)
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
 
    AND (
        EXISTS ( -- only ssd relevant records
            SELECT 1
            FROM ssd_development.ssd_person p
            WHERE TRY_CAST(p.pers_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1799
        ) OR EXISTS ( 
            SELECT 1 
            FROM ssd_development.ssd_cin_episodes ce
            WHERE TRY_CAST(ce.cine_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1806
        )
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_ssd_moth_to_person 
-- FOREIGN KEY (moth_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- [TESTING] deployment issues remain
-- ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_ssd_child_to_person 
-- FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- [TESTING] Comment this out until further notice (incl. for ESCC)
-- ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT CHK_ssd_no_self_parenting -- Ensure person cannot be their own mother
-- CHECK (moth_person_id <> moth_childs_person_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_moth_person_id ON ssd_development.ssd_mother(moth_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_childs_person_id ON ssd_development.ssd_mother(moth_childs_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_childs_dob ON ssd_development.ssd_mother(moth_childs_dob);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_legal_status';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_legal_status', 'U') IS NOT NULL DROP TABLE #ssd_legal_status;

IF OBJECT_ID('ssd_development.ssd_legal_status','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_legal_status)
        TRUNCATE TABLE ssd_development.ssd_legal_status;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_legal_status (
        lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LEGA001A"}
        lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
        lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
        lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
        lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)
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

AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fls.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_legal_status ADD CONSTRAINT FK_ssd_legal_status_person
-- FOREIGN KEY (lega_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_lega_person_id   ON ssd_development.ssd_legal_status(lega_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status                  ON ssd_development.ssd_legal_status(lega_legal_status);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_start            ON ssd_development.ssd_legal_status(lega_legal_status_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_legal_status_end              ON ssd_development.ssd_legal_status(lega_legal_status_end_date);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_contacts';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_contacts', 'U') IS NOT NULL DROP TABLE #ssd_contacts;

IF OBJECT_ID('ssd_development.ssd_contacts','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_contacts)
        TRUNCATE TABLE ssd_development.ssd_contacts;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_contacts (
        cont_contact_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CONT001A"}
        cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
        cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
        cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
        cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
        cont_contact_outcome_json       NVARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)

-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC, --4
    (
        -- Manual JSON-like concatenation for cont_contact_outcome_json
        '{' +
        '"NEW_REFERRAL_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_NEW_REFERRAL_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"EXISTING_REFERRAL_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_EXISTING_REFERRAL_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CP_ENQUIRY_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_CP_ENQUIRY_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NFA_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NON_AGENCY_ADOPTION_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PRIVATE_FOSTERING_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"ADVICE_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_ADVICE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"MISSING_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_MISSING_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OLA_CP_FLAG": "' + ISNULL(TRY_CAST(fc.OUTCOME_OLA_CP_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(fc.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NUMBER_OF_OUTCOMES": ' + 
            ISNULL(TRY_CAST(CASE 
                WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL
                ELSE fc.TOTAL_NO_OF_OUTCOMES 
            END AS NVARCHAR(4)), 'null') + ', ' +
        '"COMMENTS": "' + ISNULL(TRY_CAST(fc.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
        '}'
    ) AS cont_contact_outcome_json
FROM 
    HDM.Child_Social.FACT_CONTACTS AS fc
WHERE
    (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
    AND fc.DIM_PERSON_ID <> -1
    AND EXISTS ( -- only ssd relevant records
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID
    );



-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
-- SELECT 
--     fc.FACT_CONTACT_ID,
--     fc.DIM_PERSON_ID, 
--     fc.CONTACT_DTTM,
--     fc.DIM_LOOKUP_CONT_SORC_ID,
--     fc.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 3
--     (   -- Create JSON string for outcomes
--         SELECT 
--             -- SSD standard 
--             -- all keys in structure regardless of data presence
--             ISNULL(fc.OUTCOME_NEW_REFERRAL_FLAG, '')         AS NEW_REFERRAL_FLAG,
--             ISNULL(fc.OUTCOME_EXISTING_REFERRAL_FLAG, '')    AS EXISTING_REFERRAL_FLAG,
--             ISNULL(fc.OUTCOME_CP_ENQUIRY_FLAG, '')           AS CP_ENQUIRY_FLAG,
--             ISNULL(fc.OUTCOME_NFA_FLAG, '')                  AS NFA_FLAG,
--             ISNULL(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '')  AS NON_AGENCY_ADOPTION_FLAG,
--             ISNULL(fc.OUTCOME_PRIVATE_FOSTERING_FLAG, '')    AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fc.OUTCOME_ADVICE_FLAG, '')               AS ADVICE_FLAG,
--             ISNULL(fc.OUTCOME_MISSING_FLAG, '')              AS MISSING_FLAG,
--             ISNULL(fc.OUTCOME_OLA_CP_FLAG, '')               AS OLA_CP_FLAG,
--             ISNULL(fc.OTHER_OUTCOMES_EXIST_FLAG, '')         AS OTHER_OUTCOMES_EXIST_FLAG,
--             CASE 
--                 WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
--                 ELSE fc.TOTAL_NO_OF_OUTCOMES 
--             END                                              AS NUMBER_OF_OUTCOMES,
--             ISNULL(fc.OUTCOME_COMMENTS, '')                  AS COMMENTS
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         ) AS cont_contact_outcome_json
-- FROM 
--     HDM.Child_Social.FACT_CONTACTS AS fc

-- WHERE
--     (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
--     AND fc.DIM_PERSON_ID <> -1
--     AND EXISTS ( -- only ssd relevant records
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID
--     );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_contacts ADD CONSTRAINT FK_ssd_contact_person 
-- FOREIGN KEY (cont_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_person_id     ON ssd_development.ssd_contacts(cont_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_date          ON ssd_development.ssd_contacts(cont_contact_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_source_code   ON ssd_development.ssd_contacts(cont_contact_source_code);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;





-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_early_help_episodes';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_early_help_episodes', 'U') IS NOT NULL DROP TABLE #ssd_early_help_episodes;

IF OBJECT_ID('ssd_development.ssd_early_help_episodes','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_early_help_episodes)
        TRUNCATE TABLE ssd_development.ssd_early_help_episodes;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_early_help_episodes (
        earl_episode_id             NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EARL001A"}
        earl_person_id              NVARCHAR(48),               -- metadata={"item_ref":"EARL002A"}
        earl_episode_start_date     DATETIME,                   -- metadata={"item_ref":"EARL003A"}
        earl_episode_end_date       DATETIME,                   -- metadata={"item_ref":"EARL004A"}
        earl_episode_reason         NVARCHAR(MAX),              -- metadata={"item_ref":"EARL005A"}
        earl_episode_end_reason     NVARCHAR(MAX),              -- metadata={"item_ref":"EARL006A"}
        earl_episode_organisation   NVARCHAR(MAX),              -- metadata={"item_ref":"EARL007A"}
        earl_episode_worker_id      NVARCHAR(100)               -- metadata={"item_ref":"EARL008A", "item_status": "A", "info":"Consider for removal"}
    );
END

 
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_early_help_episodes (
    earl_episode_id,
    earl_person_id,
    earl_episode_start_date,
    earl_episode_end_date,
    earl_episode_reason,
    earl_episode_end_reason,
    earl_episode_organisation,
    earl_episode_worker_id                    
)
 
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

AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cafe.DIM_PERSON_ID -- #DtoI-1799
    );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_early_help_episodes ADD CONSTRAINT FK_ssd_earl_to_person 
-- FOREIGN KEY (earl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_episodes_person_id     ON ssd_development.ssd_early_help_episodes(earl_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_start_date             ON ssd_development.ssd_early_help_episodes(earl_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_early_help_end_date               ON ssd_development.ssd_early_help_episodes(earl_episode_end_date);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cin_assessments';

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_cin_assessments', 'U') IS NOT NULL DROP TABLE #ssd_cin_assessments;

IF OBJECT_ID('ssd_development.ssd_cin_assessments','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cin_assessments)
        TRUNCATE TABLE ssd_development.ssd_cin_assessments;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cin_assessments
    (
        cina_assessment_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINA001A"}
        cina_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
        cina_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
        cina_assessment_start_date      DATETIME,                   -- metadata={"item_ref":"CINA003A"}
        cina_assessment_child_seen      NCHAR(1),                   -- metadata={"item_ref":"CINA004A"}
        cina_assessment_auth_date       DATETIME,                   -- metadata={"item_ref":"CINA005A"}             
        cina_assessment_outcome_json    NVARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
        cina_assessment_outcome_nfa     NCHAR(1),                   -- metadata={"item_ref":"CINA009A"}
        cina_assessment_team            NVARCHAR(48),               -- metadata={"item_ref":"CINA007A"}
        cina_assessment_worker_id       NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
    );
END


-- CTE for the EXISTS
;WITH RelevantPersons AS (
    SELECT p.pers_person_id
    FROM ssd_development.ssd_person p
),
 
-- CTE for the JOIN
FormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER,
        ffa.DIM_ASSESSMENT_TEMPLATE_QUESTION_ID_DESC
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE ffa.ANSWER_NO IN ('seenYN', 'FormEndDate')
),
 
-- CTE for aggregating form answers
AggregatedFormAnswers AS (
    SELECT
        ffa.FACT_FORM_ID,
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'seenYN' THEN ffa.ANSWER ELSE NULL END, ''))                                       AS seenYN, -- [REVIEW] 310524 RH
        MAX(ISNULL(CASE WHEN ffa.ANSWER_NO = 'FormEndDate' THEN TRY_CAST(ffa.ANSWER AS DATETIME) ELSE NULL END, '1900-01-01'))  AS AssessmentAuthorisedDate -- [REVIEW] 310524 RH
    FROM FormAnswers ffa
    GROUP BY ffa.FACT_FORM_ID
) 
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_assessments
(
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date,      
    cina_assessment_outcome_json,
    cina_assessment_outcome_nfa,
    cina_assessment_team,
    cina_assessment_worker_id
)

-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fa.FACT_SINGLE_ASSESSMENT_ID,
    fa.DIM_PERSON_ID,
    fa.FACT_REFERRAL_ID,
    fa.START_DTTM,
    CASE
        WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
        WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
        ELSE NULL
    END AS seenYN,
    afa.AssessmentAuthorisedDate,
    (
        -- Manual JSON-like concatenation for cina_assessment_outcome_json
        '{' +
        '"NFA_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NFA_S47_END_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_NFA_S47_END_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"STRATEGY_DISCUSSION_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CLA_REQUEST_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_CLA_REQUEST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PRIVATE_FOSTERING_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"LEGAL_ACTION_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_LEGAL_ACTION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SERVICES_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SB_CARE_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_PROV_OF_SB_CARE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"SPECIALIST_ASSESSMENT_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"REFERRAL_TO_OTHER_AGENCY_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_ACTIONS_FLAG": "' + ISNULL(TRY_CAST(fa.OUTCOME_OTHER_ACTIONS_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(fa.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"TOTAL_NO_OF_OUTCOMES": ' + ISNULL(TRY_CAST(fa.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(3)), 'null') + ', ' +
        '"COMMENTS": "' + ISNULL(TRY_CAST(fa.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
        '}'
    ) AS cina_assessment_outcome_json,
    fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
    NULLIF(fa.COMPLETED_BY_DEPT_ID, -1)                         AS cina_assessment_team,             -- replace -1 values with NULL _team_id
    NULLIF(fa.COMPLETED_BY_USER_ID, -1)                         AS cina_assessment_worker_id         -- replace -1 values with NULL for _worker_id
 
FROM
    HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
 
LEFT JOIN
    -- access pre-processed data in CTE
    AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
 
WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excludes draft and cancelled assessments
 
AND 
    (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR afa.AssessmentAuthorisedDate IS NULL)

AND EXISTS (
    -- access pre-processed data in CTE
    SELECT 1
    FROM RelevantPersons p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID -- #DtoI-1799
);


-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
-- SELECT
--     fa.FACT_SINGLE_ASSESSMENT_ID,
--     fa.DIM_PERSON_ID,
--     fa.FACT_REFERRAL_ID,
--     fa.START_DTTM,
--     CASE
--         WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
--         WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
--         ELSE NULL
--     END AS seenYN,
--     afa.AssessmentAuthorisedDate,
--     (
--         SELECT
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             ISNULL(fa.OUTCOME_NFA_FLAG, '')                     AS NFA_FLAG,
--             ISNULL(fa.OUTCOME_NFA_S47_END_FLAG, '')             AS NFA_S47_END_FLAG,
--             ISNULL(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '')     AS STRATEGY_DISCUSSION_FLAG,
--             ISNULL(fa.OUTCOME_CLA_REQUEST_FLAG, '')             AS CLA_REQUEST_FLAG,
--             ISNULL(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')       AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fa.OUTCOME_LEGAL_ACTION_FLAG, '')            AS LEGAL_ACTION_FLAG,
--             ISNULL(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')        AS PROV_OF_SERVICES_FLAG,
--             ISNULL(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')         AS PROV_OF_SB_CARE_FLAG,
--             ISNULL(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '')   AS SPECIALIST_ASSESSMENT_FLAG,
--             ISNULL(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS REFERRAL_TO_OTHER_AGENCY_FLAG,
--             ISNULL(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')           AS OTHER_ACTIONS_FLAG,
--             ISNULL(fa.OTHER_OUTCOMES_EXIST_FLAG, '')            AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(fa.TOTAL_NO_OF_OUTCOMES, '')                 AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(fa.OUTCOME_COMMENTS, '')                     AS COMMENTS -- dictates a larger _json size
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         ) AS cina_assessment_outcome_json,
--     fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
--     NULLIF(fa.COMPLETED_BY_DEPT_ID, -1)                         AS cina_assessment_team,             -- replace -1 values with NULL _team_id
--     NULLIF(fa.COMPLETED_BY_USER_ID, -1)                         AS cina_assessment_worker_id         -- replace -1 values with NULL for _worker_id
 
-- FROM
--     HDM.Child_Social.FACT_SINGLE_ASSESSMENT fa
 
-- LEFT JOIN
--     -- access pre-processed data in CTE
--     AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
 
-- WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excludes draft and cancelled assessments
 
-- AND 
--     (afa.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR afa.AssessmentAuthorisedDate IS NULL)

-- AND EXISTS (
--     -- access pre-processed data in CTE
--     SELECT 1
--     FROM RelevantPersons p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID -- #DtoI-1799
-- );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
-- FOREIGN KEY (cina_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_assessments_person_id     ON ssd_development.ssd_cin_assessments(cina_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_assessment_start_date    ON ssd_development.ssd_cin_assessments(cina_assessment_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_assessment_auth_date     ON ssd_development.ssd_cin_assessments(cina_assessment_auth_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cina_referral_id              ON ssd_development.ssd_cin_assessments(cina_referral_id);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.6 Family Assessment filter removal+suggested fix from Coventry/Redcar
--              1.5 Re-factor around string_agg pre-compile issues for pre 2016/2012 SQL 
--              1.4 introduce selection on string_Agg use from sys compatility settings
--              1.3 Changes to fix 8k Lob cap on _json field, applied nvarchar(max)
--              1.2 Handling added for potential empty list into json WHEN LEN(Concat_Result)
--              1.1: ensure only factors with associated cina_assessment_id #DtoI-1769 090724 RH
--              1.0: New alternative structure for assessment_factors_json 250624 RH
-- Status: [R]elease
-- Remarks: This object referrences some large source tables- Instances of 45m+. 
-- Dependencies: 
-- - #ssd_TMP_PRE_assessment_factors (as staged pre-processing)
-- - ssd_cin_assessments
-- - HDM.Child_Social.FACT_SINGLE_ASSESSMENT
-- - HDM.Child_Social.FACT_FORM_ANSWERS
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_assessment_factors';

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors','U') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;
IF OBJECT_ID('tempdb..#ssd_d_codes','U') IS NOT NULL DROP TABLE #ssd_d_codes; -- de-duped + precomputed sort keys

IF OBJECT_ID('ssd_development.ssd_assessment_factors','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_assessment_factors)
        TRUNCATE TABLE ssd_development.ssd_assessment_factors;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_assessment_factors (
        cinf_table_id                nvarchar(48)  NOT NULL,
        cinf_assessment_id           nvarchar(48)  NOT NULL,
        cinf_assessment_factors_json nvarchar(max) NULL,
        CONSTRAINT PK_ssd_assessment_factors PRIMARY KEY CLUSTERED (cinf_table_id, cinf_assessment_id)
    );
END




-- META-ELEMENT: {"type": "insert_data"}
/* ========================================================================
   Assessment factors (dual-path: modern + legacy, with ordered codes table)
   - Shared prep builds filtered temp rows from Single Assessments
   - #ssd_d_codes: de-dup + precomputed sort keys + (optional) clustered index
   - Modern path: STRING_AGG (SQL 2022+/Azure SQL) 
   - Legacy path: FOR XML PATH (SQL Server 2012+)
   ======================================================================== */

SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* -------------------------------------------
       Shared prep (raw filtered rows)
       ------------------------------------------- */
    
    SELECT
        ffa.FACT_FORM_ID,
        ffa.ANSWER_NO,
        ffa.ANSWER
    INTO #ssd_TMP_PRE_assessment_factors
    FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
    INNER JOIN HDM.Child_Social.FACT_FORM_ANSWERS   AS ffa
      ON fsa.FACT_FORM_ID = ffa.FACT_FORM_ID
    WHERE ffa.ANSWER_NO IN (
          '1A','1B','1C'
        ,'2A','2B','2C','3A','3B','3C'
        ,'4A','4B','4C'
        ,'5A','5B','5C'
        ,'6A','6B','6C'
        ,'7A'
        ,'8B','8C','8D','8E','8F'
        ,'9A','10A','11A','12A','13A','14A','15A','16A','17A'
        ,'18A','18B','18C'
        ,'19A','19B','19C'
        ,'20','21'
        ,'22A','23A','24A'
    )
      AND LOWER(ffa.ANSWER) = 'yes'
      AND ffa.FACT_FORM_ID <> -1;

    /* -------------------------------------------
       Compact codes table (de-dup + sort keys)
       ------------------------------------------- */
    
    SELECT DISTINCT
        d.FACT_FORM_ID,
        d.ANSWER_NO,
        d.ANSWER,
        -- sort parts: numeric prefix then alpha suffix (or '' if none)
        TRY_CONVERT(int, LEFT(d.ANSWER_NO,
            CASE WHEN PATINDEX('%[^0-9]%', d.ANSWER_NO) = 0
                 THEN LEN(d.ANSWER_NO)
                 ELSE PATINDEX('%[^0-9]%', d.ANSWER_NO) - 1 END
        )) AS num_part,
        CASE WHEN PATINDEX('%[^0-9]%', d.ANSWER_NO) = 0
             THEN N'' ELSE SUBSTRING(d.ANSWER_NO, PATINDEX('%[^0-9]%', d.ANSWER_NO), 10) END AS alpha_part
    INTO #ssd_d_codes
    FROM #ssd_TMP_PRE_assessment_factors AS d;

    -- Optional index (IF your LA assessments row count is millions)
    -- CREATE CLUSTERED INDEX IX_codes ON #ssd_d_codes(FACT_FORM_ID, num_part, alpha_part, ANSWER_NO) INCLUDE (ANSWER);

    /* -------------------------------------------
       Legacy path: SQL Server 2012+
       Build JSON via FOR XML PATH using ordered #ssd_d_codes
       ------------------------------------------- */
    INSERT INTO ssd_development.ssd_assessment_factors (
        cinf_table_id,
        cinf_assessment_id,
        cinf_assessment_factors_json
    )
    SELECT
        fsa.EXTERNAL_ID AS cinf_table_id,
        fsa.FACT_FORM_ID AS cinf_assessment_id,
        (
            SELECT
                -- KEY-VALUES output {"1B": "Yes", "2B": "Yes", ...}
                '{' +
                STUFF((
                    SELECT
                        ', "' + x.ANSWER_NO + '": ' + QUOTENAME(x.ANSWER, '"')
                    FROM #ssd_d_codes AS x
                    WHERE x.FACT_FORM_ID = fsa.FACT_FORM_ID
                    ORDER BY x.num_part, x.alpha_part
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') +
                '}'

                -- Awaiting LA/DfE approval
                -- KEYS-ONLY alternative (swap with lines above if ["1A","2B",...] needed):
                -- '[' +
                -- STUFF((
                --     SELECT
                --         ', "' + x.ANSWER_NO + '"'
                --     FROM #ssd_d_codes AS x
                --     WHERE x.FACT_FORM_ID = fsa.FACT_FORM_ID
                --     ORDER BY x.num_part, x.alpha_part
                --     FOR XML PATH(''), TYPE
                -- ).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                -- + ']'

        ) AS cinf_assessment_factors_json
    FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
    JOIN (SELECT DISTINCT FACT_FORM_ID FROM #ssd_d_codes) AS d
      ON d.FACT_FORM_ID = fsa.FACT_FORM_ID
    WHERE fsa.EXTERNAL_ID <> -1;
    -- Optional scope:
    -- AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_development.ssd_cin_assessments)

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;  -- handles both 1 and -1 states
    THROW;  -- preserve original error details
END CATCH;

-- Cleanup
IF OBJECT_ID('tempdb..#ssd_d_codes','U') IS NOT NULL DROP TABLE #ssd_d_codes;
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors','U') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;

-- -------------------------------------------------------------------------
-- Modern path: SQL Server 2022 or Azure SQL only
-- enable on modern servers, comment out legacy INSERT above and
-- uncomment this whole block
-- -------------------------------------------------------------------------
-- INSERT INTO ssd_development.ssd_assessment_factors (
--     cinf_table_id,
--     cinf_assessment_id,
--     cinf_assessment_factors_json
-- )
-- SELECT
--     fsa.EXTERNAL_ID AS cinf_table_id,
--     fsa.FACT_FORM_ID AS cinf_assessment_id,
--
--     -- KEY-VALUES output {"1B": "Yes", "2B": "Yes", ...}
--     N'{' + STRING_AGG(
--             CONCAT('"', c.ANSWER_NO, '": ', QUOTENAME(c.ANSWER, '"')),
--             N', '
--          ) WITHIN GROUP (ORDER BY c.num_part, c.alpha_part)
--        + N'}' AS cinf_assessment_factors_json
--
--     -- KEYS-ONLY alternative (swap with lines above if ["1A","2B",...] needed):
--     -- N'[' + STRING_AGG(
--     --         CONCAT('"', c.ANSWER_NO, '"'),
--     --         N', '
--     --      ) WITHIN GROUP (ORDER BY c.num_part, c.alpha_part)
--     --    + N']' AS cinf_assessment_factors_json
--
-- FROM HDM.Child_Social.FACT_SINGLE_ASSESSMENT AS fsa
-- JOIN #ssd_d_codes AS c
--   ON c.FACT_FORM_ID = fsa.FACT_FORM_ID
-- WHERE fsa.EXTERNAL_ID <> -1
-- GROUP BY fsa.EXTERNAL_ID, fsa.FACT_FORM_ID;
-- -- Optional scope:
-- -- AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_development.ssd_cin_assessments)


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_assessment_factors ADD CONSTRAINT FK_ssd_cinf_assessment_id
-- FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_development.ssd_cin_assessments(cina_assessment_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cinf_assessment_id ON ssd_development.ssd_assessment_factors(cinf_assessment_id);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END




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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cin_plans';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;

IF OBJECT_ID('ssd_development.ssd_cin_plans','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cin_plans)
        TRUNCATE TABLE ssd_development.ssd_cin_plans;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cin_plans (
        cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINP001A"}
        cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
        cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
        cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
        cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
        cinp_cin_plan_team          NVARCHAR(48),               -- metadata={"item_ref":"CINP005A"}
        cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT
    cps.FACT_CARE_PLAN_SUMMARY_ID      AS cinp_cin_plan_id,
    cps.FACT_REFERRAL_ID               AS cinp_referral_id,
    cps.DIM_PERSON_ID                  AS cinp_person_id,
    cps.START_DTTM                     AS cinp_cin_plan_start_date,
    cps.END_DTTM                       AS cinp_cin_plan_end_date,
 
    -- (SELECT
    --     MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
    --              THEN ISNULL(fp.DIM_PLAN_COORD_DEPT_ID_DESC, '') END))

    --                                    AS cinp_cin_plan_team_name,

    -- (SELECT
    --     MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
    --              THEN ISNULL(fp.DIM_PLAN_COORD_ID_DESC, '') END))

    --                                    AS cinp_cin_plan_worker_name
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

AND EXISTS
(
    -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cps.DIM_PERSON_ID -- #DtoI-1799
)
 
GROUP BY
    cps.FACT_CARE_PLAN_SUMMARY_ID,
    cps.FACT_REFERRAL_ID,
    cps.DIM_PERSON_ID,
    cps.START_DTTM,
    cps.END_DTTM
    ;



-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_development.ssd_cin_plans ADD CONSTRAINT FK_ssd_cinp_to_person 
-- FOREIGN KEY (cinp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cin_plans_person_id       ON ssd_development.ssd_cin_plans(cinp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_cin_plan_start_date  ON ssd_development.ssd_cin_plans(cinp_cin_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_cin_plan_end_date    ON ssd_development.ssd_cin_plans(cinp_cin_plan_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinp_referral_id          ON ssd_development.ssd_cin_plans(cinp_referral_id);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cin_visits';

 
 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cin_visits', 'U') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
IF OBJECT_ID('ssd_development.ssd_cin_visits','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cin_visits)
        TRUNCATE TABLE ssd_development.ssd_cin_visits;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cin_visits
    (
        cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINV001A"}      
        cinv_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINV007A"}
        cinv_cin_visit_date         DATETIME,                   -- metadata={"item_ref":"CINV003A"}
        cinv_cin_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CINV004A"}
        cinv_cin_visit_seen_alone   NCHAR(1),                   -- metadata={"item_ref":"CINV005A"}
        cinv_cin_visit_bedroom      NCHAR(1)                    -- metadata={"item_ref":"CINV006A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_visits
(
    cinv_cin_visit_id,                  
    cinv_person_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)
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

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cn.DIM_PERSON_ID -- #DtoI-1799
    );
 


-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
-- FOREIGN KEY (cinv_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cinv_person_id        ON ssd_development.ssd_cin_visits(cinv_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cinv_cin_visit_date   ON ssd_development.ssd_cin_visits(cinv_cin_visit_date);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_s47_enquiry';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_s47_enquiry', 'U') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

IF OBJECT_ID('ssd_development.ssd_s47_enquiry','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_s47_enquiry)
        TRUNCATE TABLE ssd_development.ssd_s47_enquiry;
END
-- META-ELEMENT: {"type": "create_table"} 
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_s47_enquiry (
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


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_s47_enquiry(
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
        '{' +
        '"NFA_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"LEGAL_ACTION_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_LEGAL_ACTION_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SERVICES_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"PROV_OF_SB_CARE_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_PROV_OF_SB_CARE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"CP_CONFERENCE_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_CP_CONFERENCE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"NFA_CONTINUE_SINGLE_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"MONITOR_FLAG": "' + ISNULL(TRY_CAST(s47.OUTCOME_MONITOR_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(s47.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
        '"TOTAL_NO_OF_OUTCOMES": ' + ISNULL(TRY_CAST(s47.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(3)), 'null') + ', ' +
        '"OUTCOME_COMMENTS": "' + ISNULL(TRY_CAST(s47.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
        '}'
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
    FROM ssd_development.ssd_person p
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
--             ISNULL(s47.OUTCOME_NFA_FLAG, '')                   AS NFA_FLAG,
--             ISNULL(s47.OUTCOME_LEGAL_ACTION_FLAG, '')          AS LEGAL_ACTION_FLAG,
--             ISNULL(s47.OUTCOME_PROV_OF_SERVICES_FLAG, '')      AS PROV_OF_SERVICES_FLAG,
--             ISNULL(s47.OUTCOME_PROV_OF_SB_CARE_FLAG, '')       AS PROV_OF_SB_CARE_FLAG,
--             ISNULL(s47.OUTCOME_CP_CONFERENCE_FLAG, '')         AS CP_CONFERENCE_FLAG,
--             ISNULL(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG, '')   AS NFA_CONTINUE_SINGLE_FLAG,
--             ISNULL(s47.OUTCOME_MONITOR_FLAG, '')               AS MONITOR_FLAG,
--             ISNULL(s47.OTHER_OUTCOMES_EXIST_FLAG, '')          AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(s47.TOTAL_NO_OF_OUTCOMES, '')               AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(s47.OUTCOME_COMMENTS, '')                   AS OUTCOME_COMMENTS
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
--     FROM ssd_development.ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = s47.DIM_PERSON_ID -- #DtoI-1799
--     ) ;


-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_development.ssd_s47_enquiry ADD CONSTRAINT FK_ssd_s47_person
-- FOREIGN KEY (s47e_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_person_id     ON ssd_development.ssd_s47_enquiry(s47e_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_start_date    ON ssd_development.ssd_s47_enquiry(s47e_s47_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_end_date      ON ssd_development.ssd_s47_enquiry(s47e_s47_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_s47_enquiry_referral_id   ON ssd_development.ssd_s47_enquiry(s47e_referral_id);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



-- META-END


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_initial_cp_conference';

 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference', 'U') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;

IF OBJECT_ID('ssd_development.ssd_initial_cp_conference','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_initial_cp_conference)
        TRUNCATE TABLE ssd_development.ssd_initial_cp_conference;
END
-- META-ELEMENT: {"type": "create_table"} 
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_initial_cp_conference (
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

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_initial_cp_conference(
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
            -- Manual JSON-like concatenation for icpc_icpc_outcome_json
            '{' +
            '"NFA_FLAG": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"REFERRAL_TO_OTHER_AGENCY_FLAG": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"SINGLE_ASSESSMENT_FLAG": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"PROV_OF_SERVICES_FLAG": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"CP_FLAG": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_CP_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"OTHER_OUTCOMES_EXIST_FLAG": "' + ISNULL(TRY_CAST(fcpc.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '') + '", ' +
            '"TOTAL_NO_OF_OUTCOMES": ' + ISNULL(TRY_CAST(fcpc.TOTAL_NO_OF_OUTCOMES AS NVARCHAR(4)), 'null') + ', ' +
            '"COMMENTS": "' + ISNULL(TRY_CAST(fcpc.OUTCOME_COMMENTS AS NVARCHAR(900)), '') + '"' +
            '}'
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
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'
AND
    (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fm.ACTUAL_DTTM IS NULL)
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID -- #DtoI-1799
    ) ;

-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT
--     fcpc.FACT_CP_CONFERENCE_ID,
--     fcpc.FACT_MEETING_ID,
--     CASE 
--         WHEN fcpc.FACT_S47_ID IN ('-1', -1) THEN NULL
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
--             ISNULL(fcpc.OUTCOME_NFA_FLAG, '')                       AS NFA_FLAG,
--             ISNULL(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')  AS REFERRAL_TO_OTHER_AGENCY_FLAG,
--             ISNULL(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')         AS SINGLE_ASSESSMENT_FLAG,
--             ISNULL(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '')          AS PROV_OF_SERVICES_FLAG,
--             ISNULL(fcpc.OUTCOME_CP_FLAG, '')                        AS CP_FLAG,
--             ISNULL(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '')              AS OTHER_OUTCOMES_EXIST_FLAG,
--             ISNULL(fcpc.TOTAL_NO_OF_OUTCOMES, '')                   AS TOTAL_NO_OF_OUTCOMES,
--             ISNULL(fcpc.OUTCOME_COMMENTS, '')                       AS COMMENTS
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
--     fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'
-- AND
--     (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fm.ACTUAL_DTTM IS NULL)
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE TRY_CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID -- #DtoI-1799
--     ) ;


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_person_id
-- FOREIGN KEY (icpc_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- [TESTING] #DtoI-1769 - failing at 160724 RH
-- ALTER TABLE ssd_development.ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_referral_id
-- FOREIGN KEY (icpc_referral_id) REFERENCES ssd_development.ssd_cin_episodes(cine_referral_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_person_id        ON ssd_development.ssd_initial_cp_conference(icpc_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_s47_enquiry_id   ON ssd_development.ssd_initial_cp_conference(icpc_s47_enquiry_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_referral_id      ON ssd_development.ssd_initial_cp_conference(icpc_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_icpc_icpc_date        ON ssd_development.ssd_initial_cp_conference(icpc_icpc_date);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



-- META-END


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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cp_plans';


-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_cp_plans', 'U') IS NOT NULL DROP TABLE #ssd_cp_plans;

IF OBJECT_ID('ssd_development.ssd_cp_plans','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cp_plans)
        TRUNCATE TABLE ssd_development.ssd_cp_plans;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cp_plans (
        cppl_cp_plan_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CPPL001A"}
        cppl_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CPPL007A"}
        cppl_icpc_id                    NVARCHAR(48),               -- metadata={"item_ref":"CPPL008A"}
        cppl_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CPPL002A"}
        cppl_cp_plan_start_date         DATETIME,                   -- metadata={"item_ref":"CPPL003A"}
        cppl_cp_plan_end_date           DATETIME,                   -- metadata={"item_ref":"CPPL004A"}
        cppl_cp_plan_ola                NCHAR(1),                   -- metadata={"item_ref":"CPPL011A"}       
        cppl_cp_plan_initial_category   NVARCHAR(100),              -- metadata={"item_ref":"CPPL009A"}
        cppl_cp_plan_latest_category    NVARCHAR(100),              -- metadata={"item_ref":"CPPL010A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_plans (
    cppl_cp_plan_id,
    cppl_referral_id,
    cppl_icpc_id,
    cppl_person_id,
    cppl_cp_plan_start_date,
    cppl_cp_plan_end_date,
    cppl_cp_plan_ola,
    cppl_cp_plan_initial_category,
    cppl_cp_plan_latest_category
)
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

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cpp.DIM_PERSON_ID -- #DtoI-1799
    );


-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_development.ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_person_id
-- FOREIGN KEY (cppl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);


-- ALTER TABLE ssd_development.ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_icpc_id
-- FOREIGN KEY (cppl_icpc_id) REFERENCES ssd_development.ssd_initial_cp_conference(icpc_icpc_id);

-- -- used to test compatibility with the above constraint
-- SELECT cppl_icpc_id
-- FROM ssd_cp_plans
-- WHERE cppl_icpc_id IS NOT NULL
--   AND cppl_icpc_id NOT IN (SELECT icpc_icpc_id FROM ssd_initial_cp_conference)
--   and cppl_icpc_id <> -1;

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_person_id ON ssd_development.ssd_cp_plans(cppl_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_icpc_id ON ssd_development.ssd_cp_plans(cppl_icpc_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_referral_id ON ssd_development.ssd_cp_plans(cppl_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_start_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cp_plans_end_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_end_date);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;





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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cp_visits';

 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cp_visits', 'U') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
IF OBJECT_ID('ssd_development.ssd_cp_visits','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cp_visits)
        TRUNCATE TABLE ssd_development.ssd_cp_visits;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cp_visits (
        cppv_cp_visit_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPV007A"} 
        cppv_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CPPV008A"}
        cppv_cp_plan_id                 NVARCHAR(48),   -- metadata={"item_ref":"CPPV001A"}
        cppv_cp_visit_date              DATETIME,       -- metadata={"item_ref":"CPPV003A"}
        cppv_cp_visit_seen              NCHAR(1),       -- metadata={"item_ref":"CPPV004A"}
        cppv_cp_visit_seen_alone        NCHAR(1),       -- metadata={"item_ref":"CPPV005A"}
        cppv_cp_visit_bedroom           NCHAR(1)        -- metadata={"item_ref":"CPPV006A"}
    );
END


-- CTE Ensure unique cases only, most recent has priority-- #DtoI-1715 
;WITH UniqueCasenotes AS (
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
)

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_visits (
    cppv_cp_visit_id,
    cppv_person_id,            
    cppv_cp_plan_id,  
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
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





-- META-ELEMENT: {"type": "create_fk"} 
-- [TESTING]
-- ALTER TABLE ssd_development.ssd_cp_visits ADD CONSTRAINT FK_ssd_cppv_to_cppl
-- FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);

-- -- [TESTING] investigating the above constraint failure. (29 IDs not in cP_plans)
-- SELECT cppv_cp_plan_id
-- FROM ssd_development.ssd_cp_visits
-- WHERE cppv_cp_plan_id IS NOT NULL
--   AND cppv_cp_plan_id NOT IN (SELECT cppl_cp_plan_id FROM ssd_development.ssd_cp_plans);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_person_id        ON ssd_development.ssd_cp_visits(cppv_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_cp_plan_id       ON ssd_development.ssd_cp_visits(cppv_cp_plan_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppv_cp_visit_date    ON ssd_development.ssd_cp_visits(cppv_cp_visit_date);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cp_reviews';

 
 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cp_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
IF OBJECT_ID('ssd_development.ssd_cp_reviews','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cp_reviews)
        TRUNCATE TABLE ssd_development.ssd_cp_reviews;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cp_reviews
    (
        cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPR001A"}
        cppr_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CPPR008A"}
        cppr_cp_plan_id                     NVARCHAR(48),               -- metadata={"item_ref":"CPPR002A"}  
        cppr_cp_review_due                  DATETIME NULL,              -- metadata={"item_ref":"CPPR003A"}
        cppr_cp_review_date                 DATETIME NULL,              -- metadata={"item_ref":"CPPR004A"}
        cppr_cp_review_meeting_id           NVARCHAR(48),               -- metadata={"item_ref":"CPPR009A"}      
        cppr_cp_review_outcome_continue_cp  NCHAR(1),                   -- metadata={"item_ref":"CPPR005A"}
        cppr_cp_review_quorate              NVARCHAR(100),              -- metadata={"item_ref":"CPPR006A"}      
        cppr_cp_review_participation        NVARCHAR(100)               -- metadata={"item_ref":"CPPR007A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_reviews
(
    cppr_cp_review_id,
    cppr_cp_plan_id,
    cppr_person_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_meeting_id,
    cppr_cp_review_outcome_continue_cp,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
)
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

AND EXISTS ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = cpr.DIM_PERSON_ID -- #DtoI-1799
)
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




-- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
-- FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_person_id ON ssd_development.ssd_cp_reviews(cppr_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_plan_id ON ssd_development.ssd_cp_reviews(cppr_cp_plan_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_due ON ssd_development.ssd_cp_reviews(cppr_cp_review_due);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_date ON ssd_development.ssd_cp_reviews(cppr_cp_review_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_cppr_cp_review_meeting_id ON ssd_development.ssd_cp_reviews(cppr_cp_review_meeting_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END

-- META-CONTAINER: {"type": "table", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CLA
-- - HDM.Child_Social.FACT_CASENOTES
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_episodes','U') IS NOT NULL DROP TABLE #ssd_cla_episodes;

IF OBJECT_ID('ssd_development.ssd_cla_episodes','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_episodes)
        TRUNCATE TABLE ssd_development.ssd_cla_episodes;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_episodes (
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


-- META-ELEMENT: {"type": "insert_data"}
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
        ISNULL(
            MAX(CASE
                    WHEN cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
                    THEN cn.EVENT_DTTM
                END),
            CAST('19000101' AS datetime)
        )                                         AS clae_cla_last_iro_contact_date,
        fc.START_DTTM                             AS clae_entered_care_date
    FROM HDM.Child_Social.FACT_CARE_EPISODES AS fce
    JOIN HDM.Child_Social.FACT_CLA AS fc
      ON fc.FACT_CLA_ID = fce.FACT_CLA_ID
    LEFT JOIN HDM.Child_Social.FACT_CASENOTES AS cn
      ON cn.DIM_PERSON_ID = fce.DIM_PERSON_ID
    WHERE EXISTS (
              SELECT 1
              FROM ssd_development.ssd_person p
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
INSERT INTO ssd_development.ssd_cla_episodes (
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
-- INSERT INTO ssd_development.ssd_cla_episodes (
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
--     FROM ssd_development.ssd_person p
--      WHERE TRY_CAST(p.pers_person_id AS INT) = fce.DIM_PERSON_ID -- #DtoI-1799
-- )
-- -- WHERE
-- --     fce.DIM_PERSON_ID IN (SELECT pers_person_id FROM ssd_development.ssd_person)

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
-- SELECT DISTINCT clae_person_id FROM ssd_development.ssd_cla_episodes WHERE clae_person_id NOT IN (SELECT pers_person_id FROM ssd_development.ssd_person);





-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_to_person 
-- FOREIGN KEY (clae_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);

-- -- [TESTING]
-- ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_cla_placement_id
-- FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_development.ssd_cla_placements (clap_cla_placement_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_person_id ON ssd_development.ssd_cla_episodes(clae_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_episode_start_date ON ssd_development.ssd_cla_episodes(clae_cla_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_episode_ceased_date ON ssd_development.ssd_cla_episodes(clae_cla_episode_ceased_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_referral_id ON ssd_development.ssd_cla_episodes(clae_referral_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_cla_last_iro_contact_date ON ssd_development.ssd_cla_episodes(clae_cla_last_iro_contact_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clae_cla_placement_id ON ssd_development.ssd_cla_episodes(clae_cla_placement_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_convictions';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;

IF OBJECT_ID('ssd_development.ssd_cla_convictions','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_convictions)
        TRUNCATE TABLE ssd_development.ssd_cla_convictions;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_convictions (
        clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAC001A"}
        clac_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
        clac_cla_conviction_date    DATETIME,                   -- metadata={"item_ref":"CLAC003A"}
        clac_cla_conviction_offence NVARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )
SELECT 
    fo.FACT_OFFENCE_ID,
    fo.DIM_PERSON_ID,
    fo.OFFENCE_DTTM,
    fo.DESCRIPTION
FROM 
    HDM.Child_Social.FACT_OFFENCE as fo

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fo.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_cla_convictions ADD CONSTRAINT FK_ssd_clac_to_person 
-- FOREIGN KEY (clac_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clac_person_id ON ssd_development.ssd_cla_convictions(clac_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clac_conviction_date ON ssd_development.ssd_cla_convictions(clac_cla_conviction_date);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_health';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

IF OBJECT_ID('ssd_development.ssd_cla_health','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_health)
        TRUNCATE TABLE ssd_development.ssd_cla_health;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_health (
        clah_health_check_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAH001A"}
        clah_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
        clah_health_check_type      NVARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
        clah_health_check_date      DATETIME,                   -- metadata={"item_ref":"CLAH004A"}
        clah_health_check_status    NVARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 
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

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fhc.DIM_PERSON_ID -- #DtoI-1799
    );




-- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cla_health ADD CONSTRAINT FK_ssd_clah_to_clae 
-- FOREIGN KEY (clah_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_person_id ON ssd_development.ssd_cla_health (clah_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_health_check_date ON ssd_development.ssd_cla_health(clah_health_check_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clah_health_check_status ON ssd_development.ssd_cla_health(clah_health_check_status);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_immunisations';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_immunisations', 'U') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

IF OBJECT_ID('ssd_development.ssd_cla_immunisations','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_immunisations)
        TRUNCATE TABLE ssd_development.ssd_cla_immunisations;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_immunisations (
        clai_person_id                  NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAI002A"}
        clai_immunisations_status       NCHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
        clai_immunisations_status_date  DATETIME                    -- metadata={"item_ref":"CLAI005A"}
    );
END

-- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)
;WITH RankedImmunisations AS (
    SELECT
        fcla.DIM_PERSON_ID,
        fcla.IMMU_UP_TO_DATE_FLAG,
        fcla.LAST_UPDATED_DTTM,
        ROW_NUMBER() OVER (
            PARTITION BY fcla.DIM_PERSON_ID -- 
            ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
    FROM
        HDM.Child_Social.FACT_CLA AS fcla
    WHERE
        EXISTS ( -- only ssd relevant records be considered for ranking
            SELECT 1 
            FROM ssd_development.ssd_person p
            WHERE TRY_CAST(p.pers_person_id AS INT) = fcla.DIM_PERSON_ID -- #DtoI-1799
        )
)
-- META-ELEMENT: {"type": "insert_data"} 
-- (only most recent/rn==1 records)
INSERT INTO ssd_development.ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)
SELECT
    DIM_PERSON_ID,
    IMMU_UP_TO_DATE_FLAG,
    LAST_UPDATED_DTTM
FROM
    RankedImmunisations
WHERE
    rn = 1; -- pull needed record based on rank==1/most recent record for each DIM_PERSON_ID


-- META-ELEMENT: {"type": "create_fk"}   
-- ALTER TABLE ssd_development.ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
-- FOREIGN KEY (clai_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clai_person_id ON ssd_development.ssd_cla_immunisations(clai_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clai_immunisations_status ON ssd_development.ssd_cla_immunisations(clai_immunisations_status);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_substance_misuse';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse', 'U') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

IF OBJECT_ID('ssd_development.ssd_cla_substance_misuse','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_substance_misuse)
        TRUNCATE TABLE ssd_development.ssd_cla_substance_misuse;
END
-- META-ELEMENT: {"type": "create_table"} 
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_substance_misuse (
        clas_substance_misuse_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAS001A"}
        clas_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
        clas_substance_misuse_date      DATETIME,                   -- metadata={"item_ref":"CLAS003A"}
        clas_substance_misused          NVARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
        clas_intervention_received      NCHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)
SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID               AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID                          AS clas_person_id,
    fsm.START_DTTM                             AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE         AS clas_substance_misused,
    fsm.ACCEPT_FLAG                            AS clas_intervention_received
FROM 
    HDM.Child_Social.FACT_SUBSTANCE_MISUSE AS fsm

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fsm.DIM_PERSON_ID -- #DtoI-1799
    );



-- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
-- FOREIGN KEY (clas_person_id) REFERENCES ssd_development.ssd_cla_episodes (clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clas_person_id ON ssd_development.ssd_cla_substance_misuse (clas_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clas_substance_misuse_date ON ssd_development.ssd_cla_substance_misuse(clas_substance_misuse_date);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_placement';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_placement', 'U') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
IF OBJECT_ID('ssd_development.ssd_cla_placement','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_placement)
        TRUNCATE TABLE ssd_development.ssd_cla_placement;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_placement (
        clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAP001A"}
        clap_cla_id                         NVARCHAR(48),               -- metadata={"item_ref":"CLAP012A"}
        clap_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CLAP013A"}
        clap_cla_placement_start_date       DATETIME,                   -- metadata={"item_ref":"CLAP003A"}
        clap_cla_placement_type             NVARCHAR(100),              -- metadata={"item_ref":"CLAP004A"}
        clap_cla_placement_urn              NVARCHAR(48),               -- metadata={"item_ref":"CLAP005A"}
        clap_cla_placement_distance         FLOAT,                      -- metadata={"item_ref":"CLAP011A"}
        clap_cla_placement_provider         NVARCHAR(48),               -- metadata={"item_ref":"CLAP007A"}
        clap_cla_placement_postcode         NVARCHAR(8),                -- metadata={"item_ref":"CLAP008A"}
        clap_cla_placement_end_date         DATETIME,                   -- metadata={"item_ref":"CLAP009A"}
        clap_cla_placement_change_reason    NVARCHAR(100)               -- metadata={"item_ref":"CLAP010A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_placement (
    clap_cla_placement_id,
    clap_cla_id,
    clap_person_id,
    clap_cla_placement_start_date,
    clap_cla_placement_type,
    clap_cla_placement_urn,
    clap_cla_placement_distance,
    clap_cla_placement_provider,
    clap_cla_placement_postcode,
    clap_cla_placement_end_date,
    clap_cla_placement_change_reason  
)
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



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cla_placement ADD CONSTRAINT FK_ssd_clap_to_clae 
-- FOREIGN KEY (clap_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_cla_placement_urn ON ssd_development.ssd_cla_placement (clap_cla_placement_urn);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_cla_id ON ssd_development.ssd_cla_placement(clap_cla_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_start_date ON ssd_development.ssd_cla_placement(clap_cla_placement_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_end_date ON ssd_development.ssd_cla_placement(clap_cla_placement_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_postcode ON ssd_development.ssd_cla_placement(clap_cla_placement_postcode);
-- CREATE NONCLUSTERED INDEX IX_ssd_clap_placement_type ON ssd_development.ssd_cla_placement(clap_cla_placement_type);






-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_reviews';



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
IF OBJECT_ID('ssd_development.ssd_cla_reviews','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_reviews)
        TRUNCATE TABLE ssd_development.ssd_cla_reviews;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_reviews (
        clar_cla_review_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAR001A"}
        clar_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
        clar_cla_review_due_date        DATETIME,                   -- metadata={"item_ref":"CLAR003A"}
        clar_cla_review_date            DATETIME,                   -- metadata={"item_ref":"CLAR004A"}
        clar_cla_review_cancelled       NCHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
        clar_cla_review_participation   NVARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
) 
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
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fcr.DIM_PERSON_ID -- #DtoI-1799
    )
 
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



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_cla_reviews ADD CONSTRAINT FK_ssd_clar_to_clae 
-- FOREIGN KEY (clar_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_cla_id ON ssd_development.ssd_cla_reviews(clar_cla_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_review_due_date ON ssd_development.ssd_cla_reviews(clar_cla_review_due_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clar_review_date ON ssd_development.ssd_cla_reviews(clar_cla_review_date);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_previous_permanence';

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_previous_permanence') IS NOT NULL DROP TABLE #ssd_TMP_PRE_previous_permanence;
 
-- META-ELEMENT: {"type": "create_table"} 
-- Create TMP structure with filtered answers
SELECT
    ffa.FACT_FORM_ID,
    ffa.FACT_FORM_ANSWER_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
INTO #ssd_TMP_PRE_previous_permanence
FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
WHERE
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'
    AND ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
    AND ffa.ANSWER IS NOT NULL;
 
IF OBJECT_ID('ssd_development.ssd_cla_previous_permanence','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_previous_permanence)
        TRUNCATE TABLE ssd_development.ssd_cla_previous_permanence;
END
-- META-ELEMENT: {"type": "create_table"}     
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_previous_permanence (
        lapp_table_id                               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LAPP001A"}
        lapp_person_id                              NVARCHAR(48),   -- metadata={"item_ref":"LAPP002A"}
        lapp_previous_permanence_option             NVARCHAR(200),  -- metadata={"item_ref":"LAPP003A"}
        lapp_previous_permanence_la                 NVARCHAR(100),  -- metadata={"item_ref":"LAPP004A"}
        lapp_previous_permanence_order_date         NVARCHAR(10)    -- metadata={"item_ref":"LAPP005A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date

           )
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
AND EXISTS (
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
)
GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;



-- -- META-ELEMENT: {"type": "create_fk"}   
-- ALTER TABLE ssd_development.ssd_cla_previous_permanence ADD CONSTRAINT FK_ssd_lapp_person_id
-- FOREIGN KEY (lapp_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_lapp_person_id ON ssd_development.ssd_cla_previous_permanence(lapp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_lapp_previous_permanence_option ON ssd_development.ssd_cla_previous_permanence(lapp_previous_permanence_option);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_care_plan';

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;

IF OBJECT_ID('ssd_development.ssd_pre_cla_care_plan','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_pre_cla_care_plan)
        TRUNCATE TABLE ssd_development.ssd_pre_cla_care_plan;
END
-- META-ELEMENT: {"type": "create_table"}   
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_pre_cla_care_plan (
        FACT_FORM_ID        NVARCHAR(48),
        DIM_PERSON_ID       NVARCHAR(48),
        ANSWER_NO           NVARCHAR(10),
        ANSWER              NVARCHAR(255),
        LatestResponseDate  DATETIME
    );
END

IF OBJECT_ID('ssd_development.ssd_cla_care_plan','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_care_plan)
        TRUNCATE TABLE ssd_development.ssd_cla_care_plan;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_care_plan (
        lacp_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"LACP001A"}
        lacp_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LACP007A"}
        lacp_cla_care_plan_start_date   DATETIME,                   -- metadata={"item_ref":"LACP004A"}
        lacp_cla_care_plan_end_date     DATETIME,                   -- metadata={"item_ref":"LACP005A"}
        lacp_cla_care_plan_json         NVARCHAR(1000)              -- metadata={"item_ref":"LACP003A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"} 
;WITH MostRecentQuestionResponse AS (
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



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)

-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT
    fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
    fcp.DIM_PERSON_ID              AS lacp_person_id,
    fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
    (
        -- Manual JSON-like concatenation for lacp_cla_care_plan_json
        '{' +
        '"REMAINSUP": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"RETURN1M": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"RETURN6M": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"RETURNEV": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"LTRELFR": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"LTFOST18": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"RESPLMT": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"SUPPLIV": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"ADOPTION": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '", ' +
        '"OTHERPLN": "' + ISNULL(TRY_CAST(COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END), '') AS NVARCHAR(50)), '') + '"' +
        '}'
    ) AS lacp_cla_care_plan_json
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp
LEFT JOIN 
    ssd_development.ssd_pre_cla_care_plan tmp_cpl 
    ON tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
WHERE 
    fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
    )
GROUP BY
    fcp.FACT_CARE_PLAN_ID,
    fcp.DIM_PERSON_ID,
    fcp.START_DTTM,
    fcp.END_DTTM;

-- -- #LEGACY-PRE2016 
-- -- SQL compatible versions >=2016+
-- SELECT
--     fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
--     fcp.DIM_PERSON_ID              AS lacp_person_id,
--     fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
--     fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
--     (
--         SELECT  -- Combined _json field with 'ICP' responses
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END, '')), NULL) AS REMAINSUP,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN1M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN6M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURNEV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTRELFR,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTFOST18,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RESPLMT,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END, '')), NULL) AS SUPPLIV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END, '')), NULL) AS ADOPTION,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END, '')), NULL) AS OTHERPLN
--         FROM
--             -- #ssd_TMP_PRE_cla_care_plan tmp_cpl
--             ssd_development.ssd_pre_cla_care_plan tmp_cpl

--         WHERE
--             tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
 
--         GROUP BY tmp_cpl.DIM_PERSON_ID
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS lacp_cla_care_plan_json
 
-- FROM
--     HDM.Child_Social.FACT_CARE_PLANS AS fcp


-- WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
--     AND EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE TRY_CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
--     );


-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_cla_care_plan ADD CONSTRAINT FK_ssd_lacp_person_id
-- FOREIGN KEY (lacp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_person_id ON ssd_development.ssd_cla_care_plan(lacp_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_care_plan_start_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_lacp_care_plan_end_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_end_date);






-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

 
-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_cla_visits';

 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;

IF OBJECT_ID('ssd_development.ssd_cla_visits','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_cla_visits)
        TRUNCATE TABLE ssd_development.ssd_cla_visits;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_cla_visits (
        clav_cla_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAV001A"}
        clav_cla_id                 NVARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
        clav_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
        clav_cla_visit_date         DATETIME,                   -- metadata={"item_ref":"CLAV003A"}
        clav_cla_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
        clav_cla_visit_seen_alone   NCHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 
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

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = clav.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}   
-- ALTER TABLE ssd_development.ssd_cla_visits ADD CONSTRAINT FK_ssd_clav_person_id
-- FOREIGN KEY (clav_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_person_id ON ssd_development.ssd_cla_visits(clav_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_visit_date ON ssd_development.ssd_cla_visits(clav_cla_visit_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_clav_cla_id ON ssd_development.ssd_cla_visits(clav_cla_id);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_sdq_scores';

 
 
 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 
IF OBJECT_ID('ssd_development.ssd_sdq_scores','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_sdq_scores)
        TRUNCATE TABLE ssd_development.ssd_sdq_scores;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_sdq_scores (
        csdq_table_id               NVARCHAR(48),               -- metadata={"item_ref":"CSDQ001A"} --  PRIMARY KEY switched off for ESCC
        csdq_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CSDQ002A"}
        csdq_sdq_completed_date     DATETIME,                   -- metadata={"item_ref":"CSDQ003A"}
        csdq_sdq_score              INT,                        -- metadata={"item_ref":"CSDQ005A"}
        csdq_sdq_reason             NVARCHAR(100)               -- metadata={"item_ref":"CSDQ004A", "item_status":"P"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_sdq_scores (
    csdq_table_id, 
    csdq_person_id, 
    csdq_sdq_completed_date, 
    csdq_sdq_score, 
    csdq_sdq_reason
)
SELECT
    ff.FACT_FORM_ID                         AS csdq_table_id,
    ff.DIM_PERSON_ID                        AS csdq_person_id,

    -- SDQ Completed date
    -- Prefer FormEndDate, or fall back to SDQScore answer time
    COALESCE(fed.FormEndDttm, sdq.SdqDttm)  AS csdq_sdq_completed_date,

    -- Numeric SDQ score for form
    sdq.SdqScoreNumeric                     AS csdq_sdq_score,

    'SSD_PH'                                AS csdq_sdq_reason   -- placeholder / reason [REVIEW]
FROM HDM.Child_Social.FACT_FORMS ff

-- Pull SDQ score (1 per form)
OUTER APPLY (
    SELECT TOP 1
        CASE 
            WHEN ISNUMERIC(ffa.ANSWER) = 1 
                THEN TRY_CAST(ffa.ANSWER AS INT)
            ELSE NULL
        END                        AS SdqScoreNumeric,
        ffa.ANSWERED_DTTM          AS SdqDttm
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa
    WHERE ffa.FACT_FORM_ID = ff.FACT_FORM_ID
      AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
      AND ffa.ANSWER_NO = 'SDQScore'
      AND ffa.ANSWER IS NOT NULL
    ORDER BY ffa.ANSWERED_DTTM DESC   -- if multiple SDQScore answers exist on form, take latest
) sdq

-- FormEndDate for this form if exists
OUTER APPLY (
    SELECT TOP 1
        ffa2.ANSWERED_DTTM AS FormEndDttm
    FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa2
    WHERE ffa2.FACT_FORM_ID = ff.FACT_FORM_ID
      AND ffa2.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
      AND ffa2.ANSWER_NO = 'FormEndDate'
      AND ffa2.ANSWER IS NOT NULL
    ORDER BY ffa2.ANSWERED_DTTM DESC
) fed

-- Limit FACT_FORMS to related to SDQ template
WHERE EXISTS (
    SELECT 1
    FROM HDM.Child_Social.FACT_FORM_ANSWERS fchk
    WHERE fchk.FACT_FORM_ID = ff.FACT_FORM_ID
      AND fchk.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
)
-- only rows with data
AND sdq.SdqScoreNumeric IS NOT NULL
-- apply rolling timeframe based on completed date [align to TAG SSD ver]
AND COALESCE(fed.FormEndDttm, sdq.SdqDttm) >= @ssd_window_start
AND EXISTS (
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
);

-- remove exact dupl SDQ rows
-- keep distinct scores and dates per person and form
;WITH Dedup AS (
    SELECT
        csdq_table_id,
        csdq_person_id,
        csdq_sdq_completed_date,
        csdq_sdq_score,
        csdq_sdq_reason,
        ROW_NUMBER() OVER (
            PARTITION BY 
                csdq_table_id,
                csdq_person_id,
                csdq_sdq_completed_date,
                csdq_sdq_score,
                csdq_sdq_reason
            ORDER BY csdq_table_id
        ) AS rn
    FROM ssd_development.ssd_sdq_scores
)
DELETE s
FROM ssd_development.ssd_sdq_scores s
JOIN Dedup d
  ON s.csdq_table_id           = d.csdq_table_id
 AND s.csdq_person_id          = d.csdq_person_id
 AND s.csdq_sdq_completed_date = d.csdq_sdq_completed_date
 AND s.csdq_sdq_score          = d.csdq_sdq_score
 AND s.csdq_sdq_reason         = d.csdq_sdq_reason
WHERE d.rn > 1;



-- -- META-ELEMENT: {"type": "create_fk"}    
-- ALTER TABLE ssd_development.ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
-- FOREIGN KEY (csdq_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_csdq_person_id ON ssd_development.ssd_sdq_scores(csdq_person_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;





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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_missing';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

IF OBJECT_ID('ssd_development.ssd_missing','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_missing)
        TRUNCATE TABLE ssd_development.ssd_missing;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_missing (
        miss_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"MISS001A"}
        miss_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"MISS002A"}
        miss_missing_episode_start_date DATETIME,                   -- metadata={"item_ref":"MISS003A"}
        miss_missing_episode_type       NVARCHAR(100),              -- metadata={"item_ref":"MISS004A"}
        miss_missing_episode_end_date   DATETIME,                   -- metadata={"item_ref":"MISS005A"}
        miss_missing_rhi_offered        NVARCHAR(2),                -- metadata={"item_ref":"MISS006A", "expected_data":["N","Y","NA", NULL]}                
        miss_missing_rhi_accepted       NVARCHAR(2)                 -- metadata={"item_ref":"MISS007A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"} 
INSERT INTO ssd_development.ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,                   
    miss_missing_rhi_accepted    
)
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

AND EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fmp.DIM_PERSON_ID -- #DtoI-1799
    );



-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_development.ssd_missing ADD CONSTRAINT FK_ssd_missing_to_person
-- FOREIGN KEY (miss_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_person_id        ON ssd_development.ssd_missing(miss_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_episode_start    ON ssd_development.ssd_missing(miss_missing_episode_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_episode_end      ON ssd_development.ssd_missing(miss_missing_episode_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_rhi_offered      ON ssd_development.ssd_missing(miss_missing_rhi_offered);
-- CREATE NONCLUSTERED INDEX IX_ssd_miss_rhi_accepted     ON ssd_development.ssd_missing(miss_missing_rhi_accepted);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_care_leavers';

 
 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_care_leavers', 'U') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
IF OBJECT_ID('ssd_development.ssd_care_leavers','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_care_leavers)
        TRUNCATE TABLE ssd_development.ssd_care_leavers;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_care_leavers
    (
        clea_table_id                           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLEA001A"}
        clea_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"CLEA002A"}
        clea_care_leaver_eligibility            NVARCHAR(100),              -- metadata={"item_ref":"CLEA003A", "info":"LAC for 13wks(since 14yrs)+LAC since 16yrs"}
        clea_care_leaver_in_touch               NVARCHAR(100),              -- metadata={"item_ref":"CLEA004A"}
        clea_care_leaver_latest_contact         DATETIME,                   -- metadata={"item_ref":"CLEA005A"}
        clea_care_leaver_accommodation          NVARCHAR(100),              -- metadata={"item_ref":"CLEA006A"}
        clea_care_leaver_accom_suitable         NVARCHAR(100),              -- metadata={"item_ref":"CLEA007A"}
        clea_care_leaver_activity               NVARCHAR(100),              -- metadata={"item_ref":"CLEA008A"}
        clea_pathway_plan_review_date           DATETIME,                   -- metadata={"item_ref":"CLEA009A"}
        clea_care_leaver_personal_advisor       NVARCHAR(100),              -- metadata={"item_ref":"CLEA010A"}
        clea_care_leaver_allocated_team         NVARCHAR(48),              -- metadata={"item_ref":"CLEA011A"}
        clea_care_leaver_worker_id              NVARCHAR(100)               -- metadata={"item_ref":"CLEA012A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"}  
-- CTE for involvement history incl. worker data
-- aggregate/extract current worker infos, allocated team, and p.advisor ID
;WITH InvolvementHistoryCTE AS (
    SELECT
        fi.DIM_PERSON_ID,
        -- worker, alloc team, and p.advisor dets <<per involvement type>>
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(fi.DIM_WORKER_ID, 0) ELSE NULL END)   AS CurrentWorker,       -- c.w name for the 'CW' inv type
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN NULLIF(NULLIF(fi.FACT_WORKER_HISTORY_DEPARTMENT_ID, -1), 0) ELSE NULL END) AS AllocatedTeam, -- team desc for the 'CW' inv type
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_ID ELSE NULL END)          AS PersonalAdvisor      -- p.a. for the '16PLUS' inv type
        -- was fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC & fi.FACT_WORKER_NAME. fi.DIM_DEPARTMENT_ID also available
    
    FROM (
        SELECT *,
            -- Assign a row number, partition by p + inv type
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
            -- Mark the involvement type ('CW' or '16PLUS')
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE
            -- Filter records to just 'CW' and '16PLUS' inv types
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS')
                                                    -- Switched off in v1.6 [TESTING]
            -- AND END_DTTM IS NULL                 -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
            -- AND DIM_WORKER_ID IS NOT NULL        -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND DIM_WORKER_ID <> -1                 -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
 
            -- where the inv type is 'CW' + flagged as allocated
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
                                                    -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
    ) fi
 
    -- aggregate the result(s)
    GROUP BY
        fi.DIM_PERSON_ID
)
 
INSERT INTO ssd_development.ssd_care_leavers
(
    clea_table_id,
    clea_person_id,
    clea_care_leaver_eligibility,
    clea_care_leaver_in_touch,
    clea_care_leaver_latest_contact,
    clea_care_leaver_accommodation,
    clea_care_leaver_accom_suitable,
    clea_care_leaver_activity,
    clea_pathway_plan_review_date,
    clea_care_leaver_personal_advisor,                  
    clea_care_leaver_allocated_team,
    clea_care_leaver_worker_id            
)
 
SELECT
    NEWID() AS clea_table_id, -- [TESTING] #DtoI-1821 CONCAT(dce.DIM_CLA_ELIGIBILITY_ID, fccl.FACT_CLA_CARE_LEAVERS_ID) AS clea_table_id,
    dce.DIM_PERSON_ID                                       AS clea_person_id,
    CASE WHEN
        dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NULL
        THEN 'No Current Eligibility'
        ELSE dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC END     AS clea_care_leaver_eligibility,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE                      AS clea_care_leaver_in_touch,
    fccl.IN_TOUCH_DTTM                                      AS clea_care_leaver_latest_contact,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC                 AS clea_care_leaver_accommodation,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC             AS clea_care_leaver_accom_suitable,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC                      AS clea_care_leaver_activity,
 
    -- MAX(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
    --     AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH'
    --     THEN fcp.MODIF_DTTM END)                            AS clea_pathway_plan_review_date,

 MAX(ISNULL(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID 
    AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH' 
    THEN fcp.MODIF_DTTM END, '1900-01-01'))                 AS clea_pathway_plan_review_date,

    ih.PersonalAdvisor                                      AS clea_care_leaver_personal_advisor,
    ih.AllocatedTeam                                        AS clea_care_leaver_allocated_team,
    ih.CurrentWorker                                        AS clea_care_leaver_worker_id
 
FROM
    HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
 
LEFT JOIN HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID    -- towards clea_care_leaver_in_touch, _latest_contact, _accommodation, _accom_suitable and _activity
 
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID           -- towards clea_pathway_plan_review_date
               
LEFT JOIN HDM.Child_Social.DIM_PERSON p ON dce.DIM_PERSON_ID = p.DIM_PERSON_ID                        -- towards LEGACY_ID for testing only
 
LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID                     -- connect with CTE aggr data      
 
WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = dce.DIM_PERSON_ID -- #DtoI-1799
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
    ih.AllocatedTeam          
    ;




-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_care_leavers ADD CONSTRAINT FK_ssd_care_leavers_person
-- FOREIGN KEY (clea_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_person_id                    ON ssd_development.ssd_care_leavers(clea_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_care_leaver_latest_contact   ON ssd_development.ssd_care_leavers(clea_care_leaver_latest_contact);
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_pathway_plan_review_date     ON ssd_development.ssd_care_leavers(clea_pathway_plan_review_date);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




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


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_permanence';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

IF OBJECT_ID('ssd_development.ssd_permanence','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_permanence)
        TRUNCATE TABLE ssd_development.ssd_permanence;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_permanence (
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


-- META-ELEMENT: {"type": "insert_data"}  
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
        --     FROM ssd_development.ssd_person p
        --      WHERE TRY_CAST(p.pers_person_id AS INT) = fce.DIM_PERSON_ID -- #DtoI-1799
        -- )

)

INSERT INTO ssd_development.ssd_permanence (
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
    FROM ssd_development.ssd_person p
    WHERE p.pers_person_id = perm_person_id -- this a NVARCHAR(48) equality link
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_permanence ADD CONSTRAINT FK_ssd_perm_person_id
-- FOREIGN KEY (perm_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_person_id            ON ssd_development.ssd_permanence(perm_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_adm_decision_date    ON ssd_development.ssd_permanence(perm_adm_decision_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_perm_order_date           ON ssd_development.ssd_permanence(perm_permanence_order_date);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_professionals';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;

IF OBJECT_ID('ssd_development.ssd_professionals','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_professionals)
        TRUNCATE TABLE ssd_development.ssd_professionals;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_professionals (
        prof_professional_id                NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PROF001A"}
        prof_staff_id                       NVARCHAR(48),               -- metadata={"item_ref":"PROF010A"}
        prof_professional_name              NVARCHAR(300),              -- metadata={"item_ref":"PROF013A"}
        prof_social_worker_registration_no  NVARCHAR(48),               -- metadata={"item_ref":"PROF002A"}
        prof_agency_worker_flag             NCHAR(1),                   -- metadata={"item_ref":"PROF014A", "item_status": "P", "info":"Not available in SSD V1"}
        prof_professional_job_title         NVARCHAR(500),              -- metadata={"item_ref":"PROF007A"}
        prof_professional_caseload          INT,                        -- metadata={"item_ref":"PROF008A", "item_status": "T"}             
        prof_professional_department        NVARCHAR(100),              -- metadata={"item_ref":"PROF012A"}
        prof_full_time_equivalency          FLOAT                       -- metadata={"item_ref":"PROF011A"}
    );
END



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_professionals (
    prof_professional_id, 
    prof_staff_id, 
    prof_professional_name,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)


SELECT 
    dw.DIM_WORKER_ID                        AS prof_professional_id,                -- system based ID for workers
    LTRIM(RTRIM(dw.STAFF_ID))               AS prof_staff_id,                       -- Note that this is trimmed for non-printing chars
    CONCAT(dw.FORENAME, ' ', dw.SURNAME)    AS prof_professional_name,              -- used also as Allocated Worker|Assigned Worker
    dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,  -- Not tied to WORKER_ID, this is the social work reg number IF entered
    NULL                                    AS prof_agency_worker_flag,             -- Not available in SSD Ver/Iteration 1 [TESTING] [PLACEHOLDER_DATA]
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
    AND LTRIM(RTRIM(dw.STAFF_ID)) IS NOT NULL           -- in theory would not occur
    AND LOWER(LTRIM(RTRIM(dw.STAFF_ID))) <> 'unknown';  -- data seen in some LAs





-- -- META-ELEMENT: {"type": "create_fk"}    

-- -- META-ELEMENT: {"type": "create_idx"} 
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_professional_id      ON ssd_development.ssd_professionals (prof_professional_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_staff_id             ON ssd_development.ssd_professionals (prof_staff_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prof_social_worker_reg_no ON ssd_development.ssd_professionals(prof_social_worker_registration_no);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_department';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_department', 'U') IS NOT NULL DROP TABLE #ssd_department;

IF OBJECT_ID('ssd_development.ssd_department','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_department)
        TRUNCATE TABLE ssd_development.ssd_department;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_department (
        dept_team_id           NVARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
        dept_team_name         NVARCHAR(255), -- metadata={"item_ref":"DEPT1002A"}
        dept_team_parent_id    NVARCHAR(48),  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
        dept_team_parent_name  NVARCHAR(255)  -- metadata={"item_ref":"DEPT1004A"}
    );
END



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)
SELECT 
    dpt.DIM_DEPARTMENT_ID       AS dept_team_id,
    dpt.NAME                    AS dept_team_name,
    dpt.DEPT_ID                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name

FROM HDM.Child_Social.DIM_DEPARTMENT dpt

WHERE dpt.dim_department_id <> -1;

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_department ADD CONSTRAINT FK_ssd_dept_team_parent_id 
-- FOREIGN KEY (dept_team_parent_id) REFERENCES ssd_development.ssd_department(dept_team_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE INDEX IX_ssd_dept_team_id ON ssd_development.ssd_department (dept_team_id);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_involvements';

 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
IF OBJECT_ID('ssd_development.ssd_involvements','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_involvements)
        TRUNCATE TABLE ssd_development.ssd_involvements;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_involvements (
        invo_involvements_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"INVO005A"}
        invo_professional_id        NVARCHAR(48),               -- metadata={"item_ref":"INVO006A"}
        invo_professional_role_id   NVARCHAR(200),              -- metadata={"item_ref":"INVO007A"}
        invo_professional_team      NVARCHAR(48),               -- metadata={"item_ref":"INVO009A", "info":"This is a truncated field at 255"}
        invo_person_id              NVARCHAR(48),               -- metadata={"item_ref":"INVO011A"}
        invo_involvement_start_date DATETIME,                   -- metadata={"item_ref":"INVO002A"}
        invo_involvement_end_date   DATETIME,                   -- metadata={"item_ref":"INVO003A"}
        invo_worker_change_reason   NVARCHAR(200),              -- metadata={"item_ref":"INVO004A"}
        invo_referral_id            NVARCHAR(48)                -- metadata={"item_ref":"INVO010A"}
    );
END

 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_involvements (
    invo_involvements_id,
    invo_professional_id,
    invo_professional_role_id,
    invo_professional_team,
    invo_person_id,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)
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


AND EXISTS
    (
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799

    );



-- -- META-ELEMENT: {"type": "create_fk"} 


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_professional_id          ON ssd_development.ssd_involvements(invo_professional_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_person_id                ON ssd_development.ssd_involvements(invo_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_professional_role_id     ON ssd_development.ssd_involvements(invo_professional_role_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_involvement_start_date   ON ssd_development.ssd_involvements(invo_involvement_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_involvement_end_date     ON ssd_development.ssd_involvements(invo_involvement_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_referral_id              ON ssd_development.ssd_involvements(invo_referral_id);

-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_linked_identifiers';

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;


    -- keep existing rows in persistent identifiers table, no truncate, no drop
    -- This is the only SSD table that has manually updated user data - hence 
    -- generic drop|truncate process NOT applicable here. 

-- META-ELEMENT: {"type": "create_table"}
IF OBJECT_ID('ssd_development.ssd_linked_identifiers', 'U') IS NULL
BEGIN
    CREATE TABLE ssd_development.ssd_linked_identifiers (
        link_table_id               NVARCHAR(48) DEFAULT NEWID() PRIMARY KEY,  -- metadata={"item_ref":"LINK001A"}
        link_person_id              NVARCHAR(48),                              -- metadata={"item_ref":"LINK002A"} 
        link_identifier_type        NVARCHAR(100),                             -- metadata={"item_ref":"LINK003A"}
        link_identifier_value       NVARCHAR(100),                             -- metadata={"item_ref":"LINK004A"}
        link_valid_from_date        DATETIME,                                  -- metadata={"item_ref":"LINK005A"}
        link_valid_to_date          DATETIME                                   -- metadata={"item_ref":"LINK006A"}
    );
END;



-- Notes: 
-- By default this object is supplied empty in readiness for manual user input. 
-- Those inserting data must refer to the SSD specification for the standard SSD identifier_types

-- Example entry 1

-- META-ELEMENT: {"type": "insert_data"}
-- link_identifier_type "FORMER_UPN"
INSERT INTO ssd_development.ssd_linked_identifiers (
    link_person_id, 
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date, 
    link_valid_to_date
)
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

 AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );

-- Example entry 2

-- META-ELEMENT: {"type": "insert_data"}
-- link_identifier_type "UPN"
INSERT INTO ssd_development.ssd_linked_identifiers (
    link_person_id, 
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date, 
    link_valid_to_date
)
SELECT
    csp.dim_person_id                   AS link_person_id,
    'Unique Pupil Number'               AS link_identifier_type,
    'SSD_PH'                            AS link_identifier_value,       -- csp.upn [TESTING] Removed for compatibility
    NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
    NULL                                AS link_valid_to_date           -- NULL for valid_to_date
FROM
    HDM.Child_Social.DIM_PERSON csp

-- LEFT JOIN -- csp.upn [TESTING] Removed for compatibility
--     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

WHERE
    csp.upn IS NOT NULL AND
    EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_linked_identifiers ADD CONSTRAINT FK_ssd_link_to_person 
-- FOREIGN KEY (link_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_link_person_id        ON ssd_development.ssd_linked_identifiers(link_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_link_valid_from_date  ON ssd_development.ssd_linked_identifiers(link_valid_from_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_link_valid_to_date    ON ssd_development.ssd_linked_identifiers(link_valid_to_date);





-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


/* END SSD main extract */
/* ********************************************************************************************************** */





/* Start 

         SSDF Other DfE projects (e.g. 1b, 2(a,b) elements extracts 
        
        */


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_s251_finance"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_s251_finance';



-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

IF OBJECT_ID('ssd_development.ssd_s251_finance','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_s251_finance)
        TRUNCATE TABLE ssd_development.ssd_s251_finance;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_s251_finance (
        s251_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S251001A"}
        s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
        s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
        s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
        s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
        s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"} 
-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_development.ssd_s251_finance (
--     -- row id ommitted as ID generated (s251_table_id,)
--     s251_cla_placement_id,
--     s251_placeholder_1,
--     s251_placeholder_2,
--     s251_placeholder_3,
--     s251_placeholder_4
-- )
-- VALUES
--     ('SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH');


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_s251_finance ADD CONSTRAINT FK_ssd_s251_to_cla_placement 
-- FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_development.ssd_cla_placement(clap_cla_placement_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_s251_cla_placement_id ON ssd_development.ssd_s251_finance(s251_cla_placement_id);


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;





-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_voice_of_child"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_voice_of_child';



-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

IF OBJECT_ID('ssd_development.ssd_voice_of_child','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_voice_of_child)
        TRUNCATE TABLE ssd_development.ssd_voice_of_child;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_voice_of_child (
        voch_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"VOCH007A"}
        voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
        voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
        voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
        voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
        voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
        voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
    );
END


-- META-ELEMENT: {"type": "insert_data"} 
-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_development.ssd_voice_of_child (
--     -- row id ommitted as ID generated (voch_table_id,)
--     voch_person_id,
--     voch_explained_worries,
--     voch_story_help_understand,
--     voch_agree_worker,
--     voch_plan_safe,
--     voch_tablet_help_explain
-- )
-- VALUES
--     ('10001', 'Y', 'Y', 'Y', 'Y', 'Y'),
--     ('10002', 'Y', 'Y', 'Y', 'Y', 'Y');


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = source_table.DIM_PERSON_ID
--     );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_voice_of_child ADD CONSTRAINT FK_ssd_voch_to_person 
-- FOREIGN KEY (voch_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_voice_of_child_voch_person_id ON ssd_development.ssd_voice_of_child(voch_person_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_pre_proceedings"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_pre_proceedings';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

IF OBJECT_ID('ssd_development.ssd_pre_proceedings','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_pre_proceedings)
        TRUNCATE TABLE ssd_development.ssd_pre_proceedings;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_pre_proceedings (
        prep_table_id                           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PREP024A"}
        prep_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"PREP001A"}
        prep_plo_family_id                      NVARCHAR(48),               -- metadata={"item_ref":"PREP002A"}
        prep_pre_pro_decision_date              DATETIME,                   -- metadata={"item_ref":"PREP003A"}
        prep_initial_pre_pro_meeting_date       DATETIME,                   -- metadata={"item_ref":"PREP004A"}
        prep_pre_pro_outcome                    NVARCHAR(100),              -- metadata={"item_ref":"PREP005A"}
        prep_agree_stepdown_issue_date          DATETIME,                   -- metadata={"item_ref":"PREP006A"}
        prep_cp_plans_referral_period           INT,                        -- metadata={"item_ref":"PREP007A"}
        prep_legal_gateway_outcome              NVARCHAR(100),              -- metadata={"item_ref":"PREP008A"}
        prep_prev_pre_proc_child                INT,                        -- metadata={"item_ref":"PREP009A"}
        prep_prev_care_proc_child               INT,                        -- metadata={"item_ref":"PREP010A"}
        prep_pre_pro_letter_date                DATETIME,                   -- metadata={"item_ref":"PREP011A"}
        prep_care_pro_letter_date               DATETIME,                   -- metadata={"item_ref":"PREP012A"}
        prep_pre_pro_meetings_num               INT,                        -- metadata={"item_ref":"PREP013A"}
        prep_pre_pro_parents_legal_rep          NCHAR(1),                   -- metadata={"item_ref":"PREP014A"}
        prep_parents_legal_rep_point_of_issue   NCHAR(2),                   -- metadata={"item_ref":"PREP015A"}
        prep_court_reference                    NVARCHAR(48),               -- metadata={"item_ref":"PREP016A"}
        prep_care_proc_court_hearings           INT,                        -- metadata={"item_ref":"PREP017A"}
        prep_care_proc_short_notice             NCHAR(1),                   -- metadata={"item_ref":"PREP018A"}
        prep_proc_short_notice_reason           NVARCHAR(100),              -- metadata={"item_ref":"PREP019A"}
        prep_la_inital_plan_approved            NCHAR(1),                   -- metadata={"item_ref":"PREP020A"}
        prep_la_initial_care_plan               NVARCHAR(100),              -- metadata={"item_ref":"PREP021A"}
        prep_la_final_plan_approved             NCHAR(1),                   -- metadata={"item_ref":"PREP022A"}
        prep_la_final_care_plan                 NVARCHAR(100)               -- metadata={"item_ref":"PREP023A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"} 
-- -- Insert placeholder data
-- INSERT INTO ssd_development.ssd_pre_proceedings (
--     -- row id ommitted as ID generated (prep_table_id,)
--     prep_person_id,
--     prep_plo_family_id,
--     prep_pre_pro_decision_date,
--     prep_initial_pre_pro_meeting_date,
--     prep_pre_pro_outcome,
--     prep_agree_stepdown_issue_date,
--     prep_cp_plans_referral_period,
--     prep_legal_gateway_outcome,
--     prep_prev_pre_proc_child,
--     prep_prev_care_proc_child,
--     prep_pre_pro_letter_date,
--     prep_care_pro_letter_date,
--     prep_pre_pro_meetings_num,
--     prep_pre_pro_parents_legal_rep,
--     prep_parents_legal_rep_point_of_issue,
--     prep_court_reference,
--     prep_care_proc_court_hearings,
--     prep_care_proc_short_notice,
--     prep_proc_short_notice_reason,
--     prep_la_inital_plan_approved,
--     prep_la_initial_care_plan,
--     prep_la_final_plan_approved,
--     prep_la_final_care_plan
-- )
-- VALUES
--     (
--     'SSD_PH', 'PLO_FAMILY1', '1900/01/01', '1900/01/01', 'Outcome1', 
--     '1900/01/01', 3, 'Approved', 2, 1, '1900/01/01', '1900/01/01', 2, 'Y', 
--     'NA', 'COURT_REF_1', 1, 'Y', 'Reason1', 'Y', 'Initial Plan 1', 'Y', 'Final Plan 1'
--     ),
--     (
--     'SSD_PH', 'PLO_FAMILY2', '1900/01/01', '1900/01/01', 'Outcome2',
--     '1900/01/01', 4, 'Denied', 1, 2, '1900/01/01', '1900/01/01', 3, 'Y',
--     'IS', 'COURT_REF_2', 2, 'Y', 'Reason2', 'Y', 'Initial Plan 2', 'Y', 'Final Plan 2'
--     );



-- To switch on once source data defined.
-- WHERE EXISTS 
-- ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = plo_source_data_table.DIM_PERSON_ID
--     );





-- -- META-ELEMENT: {"type": "create_fk"}  
-- ALTER TABLE ssd_development.ssd_pre_proceedings ADD CONSTRAINT FK_ssd_prep_to_person 
-- FOREIGN KEY (prep_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_person_id                ON ssd_development.ssd_pre_proceedings (prep_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_pre_pro_decision_date    ON ssd_development.ssd_pre_proceedings (prep_pre_pro_decision_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_prep_legal_gateway_outcome    ON ssd_development.ssd_pre_proceedings (prep_legal_gateway_outcome);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END



/* End

        SSDF Other projects elements extracts 
        
        */







/* Start 

        Non-Core Liquid Logic elements extracts (E.g. SEND/EH Module data)
        
        */




-- META-CONTAINER: {"type": "table", "name": "ssd_send"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_send';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_send', 'U') IS NOT NULL DROP TABLE #ssd_send;

IF OBJECT_ID('ssd_development.ssd_send','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_send)
        TRUNCATE TABLE ssd_development.ssd_send;
END
-- META-ELEMENT: {"type": "create_table"} 
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_send (
        send_table_id       NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SEND001A"}
        send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
        send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
        send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
        send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );
END

-- META-ELEMENT: {"type": "insert_data"} 
-- for link_identifier_type "FORMER_UPN"
INSERT INTO ssd_development.ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    send_upn_unknown
)
SELECT
    NEWID() AS send_table_id,          -- generate unique id
    csp.dim_person_id AS send_person_id,
    'SSD_PH' AS send_upn,               -- csp.upn # only available with Education schema
    'SSD_PH' AS send_uln,               -- ep.uln # only available with Education schema              
    'SSD_PH' AS send_upn_unknown      
FROM
    HDM.Child_Social.DIM_PERSON csp

-- LEFT JOIN
--     -- we have to switch to Education schema in order to obtain this
--     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

WHERE
    EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );
 


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_send ADD CONSTRAINT FK_send_to_person 
-- FOREIGN KEY (send_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_send_person_id ON ssd_development.ssd_send (send_person_id);


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_sen_need"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_sen_need';

 
 -- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_sen_need', 'U') IS NOT NULL DROP TABLE #ssd_sen_need;
 
IF OBJECT_ID('ssd_development.ssd_sen_need','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_sen_need)
        TRUNCATE TABLE ssd_development.ssd_sen_need;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_sen_need (
        senn_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SENN001A"}
        senn_active_ehcp_id             NVARCHAR(48),               -- metadata={"item_ref":"SENN002A"}
        senn_active_ehcp_need_type      NVARCHAR(100),              -- metadata={"item_ref":"SENN003A"}
        senn_active_ehcp_need_rank      NCHAR(1)                    -- metadata={"item_ref":"SENN004A"}
    );
END


-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
-- FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_development.ssd_ehcp_active_plans(ehcp_active_ehcp_id);


-- META-ELEMENT: {"type": "insert_data"} 
-- INSERT INTO ssd_development.ssd_sen_need (senn_table_id, senn_active_ehcp_id, senn_active_ehcp_need_type, senn_active_ehcp_need_rank)
-- VALUES ('SSD_PH', 'SSD_PH', 'SSD_PH', '0');
 
 

-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;



-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_requests"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_ehcp_requests ';

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_requests ;

IF OBJECT_ID('ssd_development.ssd_ehcp_requests','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_ehcp_requests)
        TRUNCATE TABLE ssd_development.ssd_ehcp_requests;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_ehcp_requests (
        ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCR001A"}
        ehcr_send_table_id              NVARCHAR(48),               -- metadata={"item_ref":"EHCR002A"}
        ehcr_ehcp_req_date              DATETIME,                   -- metadata={"item_ref":"EHCR003A"}
        ehcr_ehcp_req_outcome_date      DATETIME,                   -- metadata={"item_ref":"EHCR004A"}
        ehcr_ehcp_req_outcome           NVARCHAR(100)               -- metadata={"item_ref":"EHCR005A"}
    );
END






-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
-- FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_development.ssd_send(send_table_id);


-- -- META-ELEMENT: {"type": "create_idx"}




-- META-ELEMENT: {"type": "insert_data"} 
-- INSERT INTO ssd_development.ssd_ehcp_requests (ehcr_ehcp_request_id, ehcr_send_table_id, ehcr_ehcp_req_date, ehcr_ehcp_req_outcome_date, ehcr_ehcp_req_outcome)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', '1900/01/01', 'SSD_PH');

-- WHERE
--     (source_to_ehcr_ehcp_req_outcome_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehcr_ehcp_req_outcome_date  IS NULL)


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_assessment"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_ehcp_assessment';



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_assessment ;

IF OBJECT_ID('ssd_development.ssd_ehcp_assessment','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_ehcp_assessment)
        TRUNCATE TABLE ssd_development.ssd_ehcp_assessment;
END
-- META-ELEMENT: {"type": "create_table"} 
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_ehcp_assessment (
        ehca_ehcp_assessment_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCA001A"}
        ehca_ehcp_request_id                    NVARCHAR(48),               -- metadata={"item_ref":"EHCA002A"}
        ehca_ehcp_assessment_outcome_date       DATETIME,                   -- metadata={"item_ref":"EHCA003A"}
        ehca_ehcp_assessment_outcome            NVARCHAR(100),              -- metadata={"item_ref":"EHCA004A"}
        ehca_ehcp_assessment_exceptions         NVARCHAR(100)               -- metadata={"item_ref":"EHCA005A"}
    );
END





-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
-- FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

-- -- META-ELEMENT: {"type": "create_idx"}




-- META-ELEMENT: {"type": "insert_data"}
-- INSERT INTO ssd_development.ssd_ehcp_assessment (ehca_ehcp_assessment_id, ehca_ehcp_request_id, ehca_ehcp_assessment_outcome_date, ehca_ehcp_assessment_outcome, ehca_ehcp_assessment_exceptions)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', 'SSD_PH', 'SSD_PH');

-- WHERE
--     (source_to_ehca_ehcp_assessment_outcome_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehca_ehcp_assessment_outcome_date  IS NULL)




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;






-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_named_plan"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_ehcp_named_plan';



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_named_plan;

IF OBJECT_ID('ssd_development.ssd_ehcp_named_plan','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_ehcp_named_plan)
        TRUNCATE TABLE ssd_development.ssd_ehcp_named_plan;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_ehcp_named_plan (
        ehcn_named_plan_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCN001A"}
        ehcn_ehcp_asmt_id               NVARCHAR(48),               -- metadata={"item_ref":"EHCN002A"}
        ehcn_named_plan_start_date      DATETIME,                   -- metadata={"item_ref":"EHCN003A"}
        ehcn_named_plan_ceased_date     DATETIME,                   -- metadata={"item_ref":"EHCN004A"}     
        ehcn_named_plan_ceased_reason   NVARCHAR(100)               -- metadata={"item_ref":"EHCN005A"}   
    );
END





-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_development.ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
-- FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_development.ssd_ehcp_assessment(ehca_ehcp_assessment_id);

-- -- META-ELEMENT: {"type": "create_idx"}




-- META-ELEMENT: {"type": "insert_data"} 
-- INSERT INTO ssd_development.ssd_ehcp_named_plan (ehcn_named_plan_id, ehcn_ehcp_asmt_id, ehcn_named_plan_start_date, ehcn_named_plan_ceased_date, ehcn_named_plan_ceased_reason)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', '1900/01/01', 'SSD_PH');

-- WHERE
--     (source_to_ehcn_named_plan_ceased_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehcn_named_plan_ceased_date  IS NULL)


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_active_plans"}
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

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_ehcp_active_plans';



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('tempdb..#ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

IF OBJECT_ID('ssd_development.ssd_ehcp_active_plans','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_ehcp_active_plans)
        TRUNCATE TABLE ssd_development.ssd_ehcp_active_plans;
END
-- META-ELEMENT: {"type": "create_table"}
ELSE
BEGIN
    CREATE TABLE ssd_development.ssd_ehcp_active_plans (
        ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCP001A"}
        ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
        ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
    );
END


-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_development.ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
-- FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);


-- -- META-ELEMENT: {"type": "create_idx"}

    


-- META-ELEMENT: {"type": "insert_data"}
-- INSERT INTO ssd_development.ssd_ehcp_active_plans (ehcp_active_ehcp_id, ehcp_ehcp_request_id, ehcp_active_ehcp_last_review_date)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01');

-- WHERE
--     (source_to_ehcp_active_ehcp_last_review_date  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR source_to_ehcp_active_ehcp_last_review_date IS NULL)


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END




/* START
The following STAGING TABLE(S) object definitions are to be manually added into the SSD script from the API release files 
Please take the populate staging table .sql from the most recent release here:
https://github.com/data-to-insight/dfe-csc-api-data-flows/releases
*/


-- META-CONTAINER: {"type": "table", "name": "ssd_api_data_staging"}
-- =============================================================================
-- Description: Table for API payload and logging. For most LA's this is a placeholder structure as source data not common|confirmed
-- Author: D2I
-- =============================================================================



-- META-CONTAINER: {"type": "table", "name": "ssd_api_data_staging_anon"}
-- =============================================================================
-- Description: ssd_api_data_staging (_anon) tables for LIVE|TEST API payload and logging. 
-- Author: D2I
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
-- Console reminder note
PRINT 'If your LA is part of the DfE API Private Dashboard Early Adopters you need to now run the seperate ssd_populate_api_data_staging.sql script ';
PRINT 'https://github.com/data-to-insight/dfe-csc-api-data-flows/releases'


/* END STAGING TABLE(S) object definitions */











/* End

        Non-Core Liquid Logic elements extracts 
        
        */




-- META-ELEMENT: {"type": "test"} -- Get & print run time 
/* ********************************************************************************************************** */
/* Development clean up */

SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */


/* Start

        SSD Object Constraints

        */


 

/* Start

        SSD Extract Logging
        */



-- META-ELEMENT: {"type": "console_output"} 
-- output for ref most recent/current ssd version and last update
SELECT * FROM ssd_development.ssd_version_log WHERE is_current = 1;


-- duplicated from -- META-CONTAINER: {"type": "table", "name": "ADMIN COHORT VERIFICATION ONLY"}
--------------------------------------------------------------------------------------------------------------------------------
-- Headline counts
--   core_count, from HDM using orig EXISTS path and @ssd_cutoff
--   ssd_cohort_count, from persisted flag table ssd_development.ssd_cohort
--     By default flags count has_contact or has_referral or is_care_leaver or has_eligibility or has_client or has_involvement
--     deliberate exclude has_903 here, uncomment below if include
--   api_count, records who pass EligibleBySpec unborn or <= 25 within window and appear in >1+ SpecInclusion group
--------------------------------------------------------------------------------------------------------------------------------
SELECT
  c.core_count,
  h.ssd_cohort_count,
  a.api_count
  -- , h903.ssd_cohort_incl903_count  --  include 903 rows
FROM
  (SELECT COUNT(*) AS core_count
   FROM #ssd_core_cohort) AS c
CROSS JOIN
  (SELECT COUNT(*) AS ssd_cohort_count
   FROM ssd_development.ssd_cohort
   WHERE has_contact = 1
      OR has_referral = 1
      OR is_care_leaver = 1
      OR has_eligibility = 1
      OR has_client = 1
      OR has_involvement = 1
      -- OR has_903 = 1  -- uncomment to include 903 rows in counts
  ) AS h
CROSS JOIN
  (SELECT COUNT(*) AS api_count
   FROM #ssd_api_cohort) AS a
-- optional extra cross join to show include 903 variant alongside default
-- CROSS JOIN
--   (SELECT COUNT(*) AS ssd_cohort_incl903_count
--    FROM ssd_development.ssd_cohort
--    WHERE has_contact = 1
--       OR has_referral = 1
--       OR is_care_leaver = 1
--       OR has_eligibility = 1
--       OR has_client = 1
--       OR has_involvement = 1
--       OR has_903 = 1
--   ) AS h903
;


-- META-END




