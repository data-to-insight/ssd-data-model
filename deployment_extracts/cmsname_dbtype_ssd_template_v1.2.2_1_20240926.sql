
-- META-CONTAINER: {"type": "header", "name": "extract_settings"}
-- META-ELEMENT: {"type": "header"}


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
    - Replace all instances of 'ssd_development.' with '#'
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
-- Developers pls leave blank 

-- META-ELEMENT: {"type": "dev_set_up"}
-- e.g. 
-- GO 
-- SET NOCOUNT ON;


-- META-ELEMENT: {"type": "ssd_timeframe"}
-- postgress version
DO $$ 
DECLARE 
    ssd_timeframe_years INT := 6; -- ssd extract time-frame (YRS)
    ssd_sub1_range_years INT := 1;
    CaseloadLastSept30th DATE;
    CaseloadTimeframeStartDate DATE;
BEGIN
    -- CASELOAD count Date (Currently: September 30th)
    CaseloadLastSept30th := CASE 
        WHEN CURRENT_DATE > MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 9, 30)
        THEN MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 9, 30)
        ELSE MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1, 9, 30)
    END;

    -- Start Date for Caseload Timeframe
    CaseloadTimeframeStartDate := CaseloadLastSept30th - INTERVAL '6 years';

    RAISE NOTICE 'CaseloadLastSept30th: %, CaseloadTimeframeStartDate: %', CaseloadLastSept30th, CaseloadTimeframeStartDate;
END $$;


-- META-ELEMENT: {"type": "dbschema"}
-- Postgress example for review
-- Set the schema search path if needed (SSD tables created here)
SET search_path TO 'ssd_development'; -- replace 'ssd_development' with the desired schema name

DO $$ 
DECLARE 
    schema_name VARCHAR(128) := 'ssd_development';  -- set schema name here OR leave empty for default behavior
BEGIN
    RAISE NOTICE 'Schema Name: %', schema_name;
END $$;

-- META-ELEMENT: {"type": "test"}
DO $$ 
DECLARE 
    TableName VARCHAR(128) := 'table_name_placeholder'; -- replace placeholder with the actual table name
BEGIN
    RAISE NOTICE 'Table Name: %', TableName;
END $$;


-- -- META-ELEMENT: {"type": "dbschema"}
-- -- SQL Server variant for review
-- -- Point to DB/TABLE_CATALOG if required (SSD tables created here)
-- USE HDM_Local;                           -- used in logging (and seperate clean-up script(s))
-- DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- set your schema name here OR leave empty for default behaviour. Used towards ssd_extract_log

-- -- META-ELEMENT: {"type": "test"}
-- DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder'; -- Note: also/seperately use of @table_name in non-test|live elements of script. 



-- META-END



/* ********************************************************************************************************** */
-- META-CONTAINER: {"type": "settings", "name": "testing"}
/* Towards simplistic TEST run outputs and logging  (to be removed from live v2+) */
-- Devs can ignore this block. 
-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_version_log"}
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: This is a non-core SSD item, populated with the hard-coded data given
--          In most cases this will require only syntax changes for each DB type
--          SSD extract metadata enabling version consistency across LAs. 
-- Dependencies: 
-- - None
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
DROP TABLE IF EXISTS ssd_development.ssd_version_log;
DROP TABLE IF EXISTS temp_table.ssd_version_log; -- Note: PostgreSQL uses specific schema names for temp tables

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_version_log (
    version_number      VARCHAR(10) PRIMARY KEY,          -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                    -- date of version release
    description         VARCHAR(100),                     -- brief description of version
    is_current          BOOLEAN NOT NULL DEFAULT FALSE,   -- flag to indicate if this is the current version
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- timestamp when record was created
    created_by          VARCHAR(10),                      -- which user created the record
    impact_description  VARCHAR(255)                      -- additional notes on the impact of the release
);

-- META-ELEMENT: {"type": "insert_data"}
-- Insert & update for the current version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_development.ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.2', CURRENT_TIMESTAMP, '#DtoI-1826, META+YML restructure incl. remove opt blocks', TRUE, 'admin', 'feat/bespoke LA extracts');

-- Insert historic versioning log data
INSERT INTO ssd_development.ssd_version_log (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.0.0', '2023-01-01', 'Initial alpha release (Phase 1 end)', FALSE, 'admin', ''),
    ('1.1.1', '2024-06-26', 'Minor updates with revised assessment_factors', FALSE, 'admin', 'Revised JSON Array structure implemented for CiN'),
    ('1.1.2', '2024-06-26', 'ssd_version_log obj added and minor patch fixes', FALSE, 'admin', 'Provide mech for extract ver visibility'),
    ('1.1.3', '2024-06-27', 'Revised filtering on ssd_person', FALSE, 'admin', 'Check IS_CLIENT flag first'),
    ('1.1.4', '2024-07-01', 'ssd_department obj added', FALSE, 'admin', 'Increased separation between professionals and departments enabling history'),
    ('1.1.5', '2024-07-09', 'ssd_person involvements history', FALSE, 'admin', 'Improved consistency on _json fields, clean-up involvements_history_json'),
    ('1.1.6', '2024-07-12', 'FK fixes for #DtoI-1769', FALSE, 'admin', 'non-unique/FK issues addressed: #DtoI-1769, #DtoI-1601'),
    ('1.1.7', '2024-07-15', 'Non-core ssd_person records added', FALSE, 'admin', 'Fix required for #DtoI-1802'),
    ('1.1.8', '2024-07-17', 'admin table creation logging process defined', FALSE, 'admin', ''),
    ('1.1.9', '2024-07-29', 'Applied CAST(person_id) + minor fixes', FALSE, 'admin', 'impacts all tables using where exists'),
    ('1.2.0', '2024-08-13', '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', FALSE, 'admin', 'impacts all _team fields, AAL7 outputs'),
    ('1.2.1', '2024-08-20', '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', FALSE, 'admin', 'priority patch fix');

-- META-END








/* ********************************************************************************************************** */

/* START SSD main extract */

/* ********************************************************************************************************** */




-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. This the most connected & central star node in the SSD.
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
    -- /*SSD Person filter (notes): - Implemented*/
    -- [done]contact in last 6yrs - HDM.Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
    -- [done] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
    -- [picked up within the referral] active plan or has been active in 6yrs 
-- Dependencies:
-- - 
-- =============================================================================



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_person') IS NOT NULL DROP TABLE ssd_development.ssd_person;
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}   
    pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A", "item_status":"P", "info":"If additional status to Gender is held, otherwise dup of pers_gender"}    
    pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"R", "expected_data":["unknown","NULL","F","U","M","I"]}       
    pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"} 
    pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
    pers_common_child_id    NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
    pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
    pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
    pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        NVARCHAR(48),               -- metadata={"item_ref":"PERS012A"} 
    ssd_flag                INT                         -- Non-core data flag for D2I filter testing [TESTING]
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,       -- sex and gender currently extracted as one
    pers_gender,    -- 
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,                               
    pers_upn_unknown,                                  
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality,
    ssd_flag
)


-- SELECT...

-- Dev notes: i have left a near-full SELECT example here as ssd_person requires some additional understanding as to what data might be expected, also as is so central to other tables. 
-- i expect devs might have further queries on some of the WHERE filtering here, so feel free to contact etc. 

--     p.LEGACY_ID,
--     CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
--     'SSD_PH' AS pers_sex,                   -- Placeholder for those LAs that store sex and gender independently
--     p.GENDER_MAIN_CODE,                     -- Gender as used in stat-returns
--     p.ETHNICITY_MAIN_CODE,
--     CASE WHEN (p.DOB_ESTIMATED) = 'N'              
--         THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
--         ELSE NULL 
--     END, -- or NULL
--     NULL AS pers_common_child_id, -- Set to NULL as default(dev) / or set to NHS num
--     COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
--     p.EHM_SEN_FLAG,
--     CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
--         THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
--         ELSE NULL 
--     END, -- or NULL
--     p.DEATH_DTTM,
--     CASE
--         WHEN p.GENDER_MAIN_CODE <> 'M' AND -- Assumption that if male is not mother
--              EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
--                      WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
--                            fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI') -- check for child relation only
--         THEN 'Y'
--         ELSE NULL -- No child relation found
--     END,
--     p.NATNL_CODE,
--     1 AS ssd_flag -- Non-core data flag for D2I filter testing [TESTING]
-- FROM
--     HDM.Child_Social.DIM_PERSON AS p

-- -- <snip>

-- WHERE 
--     p.DIM_PERSON_ID IS NOT NULL
--     AND p.DIM_PERSON_ID <> -1
--     -- AND YEAR(p.BIRTH_DTTM) != 1900 
--     AND (p.IS_CLIENT = 'Y'
--         OR (
--             EXISTS (
--                 SELECT 1 
--                 FROM HDM.Child_Social.FACT_CONTACTS fc
--                 WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
--                 AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
--             )
--             OR EXISTS (
--                 SELECT 1 
--                 FROM HDM.Child_Social.FACT_REFERRALS fr
--                 WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
--                 AND (
--                     fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--                     OR fr.REFRL_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--                     OR fr.REFRL_END_DTTM IS NULL
--                 )
--             )
--             OR EXISTS (
--                 SELECT 1 FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
--                 WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
--                 AND fccl.IN_TOUCH_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
--             )
--             OR EXISTS (
--                 SELECT 1 FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY dce
--                 WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
--                 AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
--             )
--             OR EXISTS (
--                 SELECT 1 FROM HDM.Child_Social.FACT_INVOLVEMENTS fi
--                 WHERE (fi.DIM_PERSON_ID = p.DIM_PERSON_ID
--                 AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' --Key Agencies (External)
-- 				OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL OR fi.IS_ALLOCATED_CW_FLAG = 'Y')
-- 				AND START_DTTM > '2009-12-04 00:54:49.947' -- was trying to cut off from 2010 but when I changed the date it threw up an erro
-- 				AND DIM_WORKER_ID <> '-1' 
--                 AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE()))
--             )
--         )
--     )
--     ;




-- META-ELEMENT: {"type": "create_fk"}
-- Not required

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_dob               ON ssd_development.ssd_person(pers_dob);
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_common_child_id   ON ssd_development.ssd_person(pers_common_child_id);
CREATE NONCLUSTERED INDEX idx_ssd_person_ethnicity_gender       ON ssd_development.ssd_person(pers_ethnicity, pers_gender);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_family"}
-- =============================================================================
-- Description: Contains the family connections for each person
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
-- Dependencies: 
-- - 
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_family') IS NOT NULL DROP TABLE ssd_development.ssd_family;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )



-- SELECT...

-- WHERE EXISTS 
--     ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
--     );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT FK_ssd_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_family_person_id          ON ssd_development.ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);

-- META-END






-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description: Contains full address details for every person 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_address') IS NOT NULL DROP TABLE ssd_development.ssd_address;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
    addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
    addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
    addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
    addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
    addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
    addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
);


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



-- SELECT...

-- -- including

--     CASE 
--     -- Some clean-up based on known data
--         WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', ''))) THEN '' -- clear pcode of containing all X's
--         WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''                                -- clear pcode of containing nopostcode
--         ELSE REPLACE(pa.POSTCODE, ' ', '')                                                              -- remove all spaces for consistency
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




-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = PERSON_ADDRESS_TABLE.DIM_PERSON_ID 
--     );




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_address ADD CONSTRAINT FK_ssd_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_address_person        ON ssd_development.ssd_address(addr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_address_start         ON ssd_development.ssd_address(addr_address_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_address_end           ON ssd_development.ssd_address(addr_address_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_ssd_address_postcode  ON ssd_development.ssd_address(addr_address_postcode);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_disability"}
-- =============================================================================
-- Description: Contains the Y/N flag for persons with disability
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_disability') IS NOT NULL DROP TABLE ssd_development.ssd_disability;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)


-- SELECT...

-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = DISABILITY_TABLE.DIM_PERSON_ID 
--     );



-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_disability ADD CONSTRAINT FK_ssd_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_disability_person_id  ON ssd_development.ssd_disability(disa_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_disability_code       ON ssd_development.ssd_disability(disa_disability_code);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_immigration_status"}
-- =============================================================================
-- Description: (UASC)
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_immigration_status') IS NOT NULL DROP TABLE ssd_development.ssd_immigration_status;
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_immigration_status (
    immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
    immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
    immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
    immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
    immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)



-- SELECT...
 
-- WHERE
--     EXISTS
--     ( -- only ssd relevant records
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE CAST(p.pers_person_id AS INT) = IMMIGRATION_STATUS_TABLE.DIM_PERSON_ID 
--     );




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_immigration_status ADD CONSTRAINT FK_ssd_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_immi_person_id ON ssd_development.ssd_immigration_status(immi_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_start          ON ssd_development.ssd_immigration_status(immi_immigration_status_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_end            ON ssd_development.ssd_immigration_status(immi_immigration_status_end_date);

-- META-END






-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - @ssd_timeframe_years
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_cin_episodes;
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(4000), -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team              NVARCHAR(48),   -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
); 


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



-- SELECT...

-- -- including 
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


 
-- WHERE
--     (REFERRALS_TABLE.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())  
--     OR REFERRALS_TABLE.REFRL_END_DTTM IS NULL)

-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = REFERRALS_TABLE.DIM_PERSON_ID
--     );

    


-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_episodes_person_id    ON ssd_development.ssd_cin_episodes(cine_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cin_referral_date             ON ssd_development.ssd_cin_episodes(cine_referral_date);
CREATE NONCLUSTERED INDEX idx_ssd_cin_close_date                ON ssd_development.ssd_cin_episodes(cine_close_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_mother"}
-- =============================================================================
-- Description: Contains parent-child relations between mother-child 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_mother;
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_mother (
    moth_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)


-- SELECT..

-- WHERE
--     p.GENDER_MAIN_CODE <> 'M'
--     AND
--     PERSON_RELATIONS_TABLE.RELATION_TYPE_CODE = 'CHI' -- only interested in parent/child relations
--     AND
--     PERSON_RELATIONS_TABLE.END_DATE IS NULL
 
--     AND (
--         EXISTS ( -- only ssd relevant records
--             SELECT 1
--             FROM ssd_development.ssd_person p
--             WHERE CAST(p.pers_person_id AS INT) = PERSON_RELATIONS_TABLE.DIM_PERSON_ID 
--         ) OR EXISTS ( 
--             SELECT 1 
--             FROM ssd_development.ssd_cin_episodes ce
--             WHERE CAST(ce.cine_person_id AS INT) = PERSON_RELATIONS_TABLE.DIM_PERSON_ID 
--         )
--     );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_ssd_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_mother_moth_person_id ON ssd_development.ssd_mother(moth_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_person_id ON ssd_development.ssd_mother(moth_childs_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_dob ON ssd_development.ssd_mother(moth_childs_dob);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_legal_status"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_legal_status') IS NOT NULL DROP TABLE ssd_development.ssd_legal_status;
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_legal_status (
    lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"LEGA001A"}
    lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
    lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
    lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
    lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)

-- SELECT...


-- WHERE 
--     (legal_status_table.END_DATE >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--     OR legal_status_table.END_DATE IS NULL)

-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = legal_status_table.DIM_PERSON_ID 
--     );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_legal_status ADD CONSTRAINT FK_ssd_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_lega_person_id   ON ssd_development.ssd_legal_status(lega_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status                  ON ssd_development.ssd_legal_status(lega_legal_status);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_start            ON ssd_development.ssd_legal_status(lega_legal_status_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_end              ON ssd_development.ssd_legal_status(lega_legal_status_end_date);
-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_contacts"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:Inclusion in contacts might differ between LAs. 
--         Baseline definition:
--         Contains safeguarding and referral to early help data.
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_contacts') IS NOT NULL DROP TABLE ssd_development.ssd_contacts;
IF OBJECT_ID('tempdb..#ssd_contacts') IS NOT NULL DROP TABLE #ssd_contacts;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_contacts (
    cont_contact_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CONT001A"}
    cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
    cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
    cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
    cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
    cont_contact_outcome_json       NVARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)


-- SELECT... 

-- <snip>

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


-- WHERE 
--     (CONTACTS_TABLE.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()))

-- AND EXISTS
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
--     );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_contacts ADD CONSTRAINT FK_ssd_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_contact_person_id     ON ssd_development.ssd_contacts(cont_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_contact_date          ON ssd_development.ssd_contacts(cont_contact_date);
CREATE NONCLUSTERED INDEX idx_ssd_contact_source_code   ON ssd_development.ssd_contacts(cont_contact_source_code);




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_early_help_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_early_help_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_early_help_episodes;
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;


-- META-ELEMENT: {"type": "create_table"}
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
 
-- SELECT...
 
-- WHERE 
--     (EH_EPISODES_TABLE.EPISODE_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--     OR EH_EPISODES_TABLE.EPISODE_END_DTTM IS NULL)

-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = EH_EPISODES_TABLE.DIM_PERSON_ID 
--     );




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_early_help_episodes ADD CONSTRAINT FK_ssd_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_early_help_episodes_person_id     ON ssd_development.ssd_early_help_episodes(earl_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_early_help_start_date             ON ssd_development.ssd_early_help_episodes(earl_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_early_help_end_date               ON ssd_development.ssd_early_help_episodes(earl_episode_end_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cin_assessments"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_development.ssd_cin_assessments;
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;


-- META-ELEMENT: {"type": "create_table"}
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


-- SELECT...
  
  
        WHEN UPPER(afa.seenYN) = 'YES'  THEN 'Y'
        WHEN UPPER(afa.seenYN) = 'NO'   THEN 'N'
        ELSE NULL
    END AS seenYN,


    (
        SELECT
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
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
            ISNULL(fa.OUTCOME_COMMENTS, '')                     AS COMMENTS -- dictates a larger _json size
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS cina_assessment_outcome_json,


 
-- WHERE ASSESSMENTS_TABLE.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excluded draft and cancelled assessments
 
-- AND 
--     (ASSESSMENTS_TABLE.AssessmentAuthorisedDate >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--     OR ASSESSMENTS_TABLE.AssessmentAuthorisedDate IS NULL)

-- AND EXISTS (
--     -- access pre-processed data in CTE
--     SELECT 1
--     FROM RelevantPersons p
--     WHERE CAST(p.pers_person_id AS INT) = ASSESSMENTS_TABLE.DIM_PERSON_ID -- #DtoI-1799
-- );


-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_assessments_person_id     ON ssd_development.ssd_cin_assessments(cina_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cina_assessment_start_date    ON ssd_development.ssd_cin_assessments(cina_assessment_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cina_assessment_auth_date     ON ssd_development.ssd_cin_assessments(cina_assessment_auth_date);
CREATE NONCLUSTERED INDEX idx_ssd_cina_referral_id              ON ssd_development.ssd_cin_assessments(cina_referral_id);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: This object referrences some large source tables- Instances of 45m+. 
-- Dependencies: 
-- - 
-- - ssd_cin_assessments
-- -
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_assessment_factors') IS NOT NULL DROP TABLE ssd_development.ssd_assessment_factors;
IF OBJECT_ID('tempdb..#ssd_assessment_factors') IS NOT NULL DROP TABLE #ssd_assessment_factors;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_assessment_factors (
    cinf_table_id                   NVARCHAR(48) PRIMARY KEY,                   -- metadata={"item_ref":"CINF003A"}
    cinf_assessment_id              NVARCHAR(48),                   -- metadata={"item_ref":"CINF001A"}
    cinf_assessment_factors_json    NVARCHAR(1000)                  -- metadata={"item_ref":"CINF002A"}
);

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


-- META-ELEMENT: {"type": "insert_data"} 
-- into the final table
INSERT INTO ssd_development.ssd_assessment_factors (
               cinf_table_id, 
               cinf_assessment_id, 
               cinf_assessment_factors_json
           )


-- -- Opt1: (current implementation for backward compatibility)
-- -- create field structure of flattened Key only json-like array structure 
-- -- ["1A","2B","3A", ...]           
-- SELECT...


-- <snip>
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
--     AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_development.ssd_cin_assessments);


-- -- -- Opt2: (commented implementation ready for forward compatibility)
-- -- -- create field structure of flattened Key-Value pair json structure 
-- -- -- {"1A": "Yes","2B": "No","3A": "Yes", ...}           
-- -- SELECT 
-- --     fsa.EXTERNAL_ID AS cinf_table_id,
-- --     fsa.FACT_FORM_ID AS cinf_assessment_id,
-- --     (
-- --         SELECT 
-- --             -- create flattened Key-Value pair json structure {"1A": "Yes","2B": "No","3A": "Yes", ...}
-- --             '{' + STRING_AGG('"' + tmp_af.ANSWER_NO + '": "' + tmp_af.ANSWER + '"', ', ') + '}' 
-- --         FROM 
-- --             #ssd_TMP_PRE_assessment_factors tmp_af
-- --         WHERE 
-- --             tmp_af.FACT_FORM_ID = fsa.FACT_FORM_ID
-- --     ) AS cinf_assessment_factors_json
-- -- FROM 
-- --     HDM.Child_Social.FACT_SINGLE_ASSESSMENT fsa
-- -- WHERE 
-- --     fsa.EXTERNAL_ID <> -1
-- --      AND fsa.FACT_FORM_ID IN (SELECT cina_assessment_id FROM ssd_development.ssd_cin_assessments);




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_assessment_factors ADD CONSTRAINT FK_ssd_cinf_assessment_id
FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_development.ssd_cin_assessments(cina_assessment_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cinf_assessment_id ON ssd_development.ssd_assessment_factors(cinf_assessment_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cin_plans"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cin_plans;
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team          NVARCHAR(48),               -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
);
 
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

-- SELECT...

--     (SELECT
--         MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
--                 THEN fp.DIM_PLAN_COORD_DEPT_ID END, '')))                                   -- was fp.DIM_PLAN_COORD_DEPT_ID_DESC
--                                             AS cinp_cin_plan_team,

--     (SELECT
--         MAX(ISNULL(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID   -- [REVIEW] 310524 RH
--                 THEN fp.DIM_PLAN_COORD_ID END, '')))                                        -- was fp.DIM_PLAN_COORD_ID_DESC
--                                             AS cinp_cin_plan_worker_id

-- FROM HDM.Child_Social.FACT_CARE_PLAN_SUMMARY cps  
 

-- LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS fp ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
 
-- WHERE DIM_LOOKUP_PLAN_TYPE_CODE = 'FP' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
 
-- AND
--     (cps.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR cps.END_DTTM IS NULL)

-- AND EXISTS
-- (
--     -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = cps.DIM_PERSON_ID -- #DtoI-1799
-- )
 
-- GROUP BY
--     cps.FACT_CARE_PLAN_SUMMARY_ID,
--     cps.FACT_REFERRAL_ID,
--     cps.DIM_PERSON_ID,
--     cps.START_DTTM,
--     cps.END_DTTM
--     ;



-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cin_plans ADD CONSTRAINT FK_ssd_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_plans_person_id       ON ssd_development.ssd_cin_plans(cinp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_cin_plan_start_date  ON ssd_development.ssd_cin_plans(cinp_cin_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_cin_plan_end_date    ON ssd_development.ssd_cin_plans(cinp_cin_plan_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_referral_id          ON ssd_development.ssd_cin_plans(cinp_referral_id);

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cin_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_visits') IS NOT NULL DROP TABLE ssd_development.ssd_cin_visits;
IF OBJECT_ID('tempdb..#ssd_cin_visits') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_visits
(
    cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINV001A"}      
    cinv_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINV007A"}
    cinv_cin_visit_date         DATETIME,                   -- metadata={"item_ref":"CINV003A"}
    cinv_cin_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CINV004A"}
    cinv_cin_visit_seen_alone   NCHAR(1),                   -- metadata={"item_ref":"CINV005A"}
    cinv_cin_visit_bedroom      NCHAR(1)                    -- metadata={"item_ref":"CINV006A"}
);
 
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


-- SELECT...

 
-- WHERE
--     cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO',
--     'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID')

-- AND
--     (cn.EVENT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR cn.EVENT_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = cn.DIM_PERSON_ID -- #DtoI-1799
--     );
 


-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
FOREIGN KEY (cinv_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cinv_person_id        ON ssd_development.ssd_cin_visits(cinv_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cinv_cin_visit_date   ON ssd_development.ssd_cin_visits(cinv_cin_visit_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_s47_enquiry"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_s47_enquiry';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_s47_enquiry') IS NOT NULL DROP TABLE ssd_development.ssd_s47_enquiry;
IF OBJECT_ID('tempdb..#ssd_s47_enquiry') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

-- META-ELEMENT: {"type": "create_table"} 
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


-- SELECT...

-- <snip>
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


-- WHERE
--     (s47.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--     OR s47.END_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = s47.DIM_PERSON_ID 
--     ) ;



-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_s47_enquiry ADD CONSTRAINT FK_ssd_s47_person
FOREIGN KEY (s47e_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_person_id     ON ssd_development.ssd_s47_enquiry(s47e_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_start_date    ON ssd_development.ssd_s47_enquiry(s47e_s47_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_end_date      ON ssd_development.ssd_s47_enquiry(s47e_s47_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_referral_id   ON ssd_development.ssd_s47_enquiry(s47e_referral_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_initial_cp_conference"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_initial_cp_conference') IS NOT NULL DROP TABLE ssd_development.ssd_initial_cp_conference;
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;
 

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_initial_cp_conference (
    icpc_icpc_id                NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"ICPC001A"}
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
 
-- SELECT...

-- <snip>
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

-- AND
--     (fm.ACTUAL_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
--     OR fm.ACTUAL_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fcpc.DIM_PERSON_ID 
--     ) ;


-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_person_id
FOREIGN KEY (icpc_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_icpc_person_id        ON ssd_development.ssd_initial_cp_conference(icpc_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_s47_enquiry_id   ON ssd_development.ssd_initial_cp_conference(icpc_s47_enquiry_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_referral_id      ON ssd_development.ssd_initial_cp_conference(icpc_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_icpc_date        ON ssd_development.ssd_initial_cp_conference(icpc_icpc_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cp_plans"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - ssd_initial_cp_conference
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.ssd_cp_plans') IS NOT NULL DROP TABLE ssd_development.ssd_cp_plans;
IF OBJECT_ID('tempdb..#ssd_cp_plans') IS NOT NULL DROP TABLE #ssd_cp_plans;

-- META-ELEMENT: {"type": "create_table"}
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


-- SELECT...

 
-- WHERE
--     (cpp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR cpp.END_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = cpp.DIM_PERSON_ID -- #DtoI-1799
--     );


-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_person_id
FOREIGN KEY (cppl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_person_id ON ssd_development.ssd_cp_plans(cppl_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_icpc_id ON ssd_development.ssd_cp_plans(cppl_icpc_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_referral_id ON ssd_development.ssd_cp_plans(cppl_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_start_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_end_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_end_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cp_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
--          using casenote ID as PK and linking to CP Visit where available.
--          Will have to use Person ID to link object to Person table
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================
 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cp_visits') IS NOT NULL DROP TABLE ssd_development.ssd_cp_visits;
IF OBJECT_ID('tempdb..#ssd_cp_visits') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cp_visits (
    cppv_cp_visit_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPV007A"} 
    cppv_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CPPV008A"}
    cppv_cp_plan_id                 NVARCHAR(48),   -- metadata={"item_ref":"CPPV001A"}
    cppv_cp_visit_date              DATETIME,       -- metadata={"item_ref":"CPPV003A"}
    cppv_cp_visit_seen              NCHAR(1),       -- metadata={"item_ref":"CPPV004A"}
    cppv_cp_visit_seen_alone        NCHAR(1),       -- metadata={"item_ref":"CPPV005A"}
    cppv_cp_visit_bedroom           NCHAR(1)        -- metadata={"item_ref":"CPPV006A"}
);

-- CTE Ensure unique cases only, most recent has priority-- #DtoI-1715 



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


-- SELECT...




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cp_visits ADD CONSTRAINT FK_ssd_cppv_to_cppl
FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cppv_person_id        ON ssd_development.ssd_cp_visits(cppv_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_plan_id       ON ssd_development.ssd_cp_visits(cppv_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_visit_date    ON ssd_development.ssd_cp_visits(cppv_cp_visit_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cp_reviews"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:    
-- Dependencies:
-- - ssd_person
-- - ssd_cp_plans
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_development.ssd_cp_reviews;
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
 
-- META-ELEMENT: {"type": "create_table"}
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


-- SELECT...

-- -- <snip>
--     (CASE WHEN ffa.ANSWER_NO = 'WasConf'
--         AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
--         THEN ffa.ANSWER END)                    AS cppr_cp_review_quorate,    
--     'SSD_PH'                                    AS cppr_cp_review_participation
 
-- FROM
--     HDM.Child_Social.FACT_CP_REVIEW as cpr
 
-- LEFT JOIN
--     HDM.Child_Social.FACT_MEETINGS fm               ON cpr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
-- LEFT JOIN
--     HDM.Child_Social.FACT_MEETING_SUBJECTS fms      ON cpr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
--     AND cpr.DIM_PERSON_ID = fms.DIM_PERSON_ID
 
-- LEFT JOIN    
--     HDM.Child_Social.FACT_FORM_ANSWERS ffa          ON fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
--     AND ffa.ANSWER_NO = 'WasConf'
--     AND fms.FACT_OUTCM_FORM_ID IS NOT NULL
--     AND fms.FACT_OUTCM_FORM_ID <> '-1'
 
-- LEFT JOIN
--     HDM.Child_Social.DIM_PERSON p ON cpr.DIM_PERSON_ID = p.DIM_PERSON_ID

-- WHERE
--     (cpr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR cpr.MEETING_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = cpr.DIM_PERSON_ID -- #DtoI-1799
-- )
-- GROUP BY cpr.FACT_CP_REVIEW_ID,
--     cpr.FACT_CP_PLAN_ID,
--     cpr.DIM_PERSON_ID,
--     cpr.DUE_DTTM,
--     cpr.MEETING_DTTM,
--     fm.FACT_MEETING_ID,
--     cpr.OUTCOME_CONTINUE_CP_FLAG,
--     fms.FACT_OUTCM_FORM_ID,
--     ffa.ANSWER_NO,
--     ffa.FACT_FORM_ID,
--     ffa.ANSWER;




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cppr_person_id ON ssd_development.ssd_cp_reviews(cppr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_plan_id ON ssd_development.ssd_cp_reviews(cppr_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_due ON ssd_development.ssd_cp_reviews(cppr_cp_review_due);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_date ON ssd_development.ssd_cp_reviews(cppr_cp_review_date);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_meeting_id ON ssd_development.ssd_cp_reviews(cppr_cp_review_meeting_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_involvements
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}   
IF OBJECT_ID('ssd_development.ssd_cla_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_cla_episodes;
IF OBJECT_ID('tempdb..#ssd_cla_episodes') IS NOT NULL DROP TABLE #ssd_cla_episodes;

 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_episodes (
    clae_cla_episode_id             NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAE001A"}
    clae_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAE002A"}
    clae_cla_placement_id           NVARCHAR(48),               -- metadata={"item_ref":"CLAE013A"} 
    clae_cla_episode_start_date     DATETIME,                   -- metadata={"item_ref":"CLAE003A"}
    clae_cla_episode_start_reason   NVARCHAR(100),              -- metadata={"item_ref":"CLAE004A"}
    clae_cla_primary_need_code      NVARCHAR(3),                -- metadata={"item_ref":"CLAE009A", "info":"Expecting codes N0-N9"} 
    clae_cla_episode_ceased         DATETIME,                   -- metadata={"item_ref":"CLAE005A"}
    clae_cla_episode_ceased_reason  NVARCHAR(255),              -- metadata={"item_ref":"CLAE006A"}
    clae_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAE010A"}
    clae_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CLAE011A"}
    clae_cla_last_iro_contact_date  DATETIME,                   -- metadata={"item_ref":"CLAE012A"} 
    clae_entered_care_date          DATETIME                    -- metadata={"item_ref":"CLAE014A"}
);



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_episodes (
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
)



-- SELECT...

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
--      WHERE CAST(p.pers_person_id AS INT) = fce.DIM_PERSON_ID 
-- )
-- -- WHERE
-- --     fce.DIM_PERSON_ID IN (SELECT pers_person_id FROM ssd_development.ssd_person)




-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_to_person 
FOREIGN KEY (clae_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);

-- ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_cla_placement_id
-- FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_development.ssd_cla_placements (clap_cla_placement_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clae_person_id ON ssd_development.ssd_cla_episodes(clae_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_start_date ON ssd_development.ssd_cla_episodes(clae_cla_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_ceased ON ssd_development.ssd_cla_episodes(clae_cla_episode_ceased);
CREATE NONCLUSTERED INDEX idx_ssd_clae_referral_id ON ssd_development.ssd_cla_episodes(clae_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_cla_last_iro_contact_date ON ssd_development.ssd_cla_episodes(clae_cla_last_iro_contact_date);
CREATE NONCLUSTERED INDEX idx_ssd_clae_cla_placement_id ON ssd_development.ssd_cla_episodes(clae_cla_placement_id);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_convictions"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_OFFENCE
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_convictions;
IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAC001A"}
    clac_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
    clac_cla_conviction_date    DATETIME,                   -- metadata={"item_ref":"CLAC003A"}
    clac_cla_conviction_offence NVARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )



-- SELECT ...


-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fo.DIM_PERSON_ID 
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_convictions ADD CONSTRAINT FK_ssd_clac_to_person 
FOREIGN KEY (clac_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clac_person_id ON ssd_development.ssd_cla_convictions(clac_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clac_conviction_date ON ssd_development.ssd_cla_convictions(clac_cla_conviction_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cla_health"}
-- =============================================================================
-- Object Name: ssd_cla_health
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_health', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_health;
IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_health (
    clah_health_check_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAH001A"}
    clah_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
    clah_health_check_type      NVARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
    clah_health_check_date      DATETIME,                   -- metadata={"item_ref":"CLAH004A"}
    clah_health_check_status    NVARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 


-- SELECT...

-- WHERE
--     (fhc.START_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
--     OR fhc.START_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fhc.DIM_PERSON_ID 
--     );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_health ADD CONSTRAINT FK_ssd_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clah_person_id ON ssd_development.ssd_cla_health (clah_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_date ON ssd_development.ssd_cla_health(clah_health_check_date);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_status ON ssd_development.ssd_cla_health(clah_health_check_status);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_immunisations"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_development.ssd_cla_immunisations;
IF OBJECT_ID('tempdb..#ssd_cla_immunisations') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_immunisations (
    clai_person_id                  NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAI002A"}
    clai_immunisations_status       NCHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
    clai_immunisations_status_date  DATETIME                    -- metadata={"item_ref":"CLAI005A"}
);

-- -- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)
-- ;WITH RankedImmunisations AS (
--     SELECT
--         fcla.DIM_PERSON_ID,
--         fcla.IMMU_UP_TO_DATE_FLAG,
--         fcla.LAST_UPDATED_DTTM,
--         ROW_NUMBER() OVER (
--             PARTITION BY fcla.DIM_PERSON_ID -- 
--             ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
--     FROM
--         HDM.Child_Social.FACT_CLA AS fcla
--     WHERE
--         EXISTS ( -- only ssd relevant records be considered for ranking
--             SELECT 1 
--             FROM ssd_development.ssd_person p
--             WHERE CAST(p.pers_person_id AS INT) = fcla.DIM_PERSON_ID -- #DtoI-1799
--         )
-- )


-- META-ELEMENT: {"type": "insert_data"} 
-- (only most recent/rn==1 records)
INSERT INTO ssd_development.ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)



-- SELECTUP
--     DIM_PERSON_ID,
--     IMMU__TO_DATE_FLAG,
--     LAST_UPDATED_DTTM
-- FROM
--     RankedImmunisations
-- WHERE
--     rn = 1; -- pull needed record based on rank==1/most recent record for each DIM_PERSON_ID


-- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clai_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clai_person_id ON ssd_development.ssd_cla_immunisations(clai_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clai_immunisations_status ON ssd_development.ssd_cla_immunisations(clai_immunisations_status);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_substance_misuse"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_development.ssd_cla_substance_misuse;
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAS001A"}
    clas_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
    clas_substance_misuse_date      DATETIME,                   -- metadata={"item_ref":"CLAS003A"}
    clas_substance_misused          NVARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
    clas_intervention_received      NCHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)


-- SELECT...


-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fsm.DIM_PERSON_ID -- #DtoI-1799
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_development.ssd_cla_episodes (clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clas_person_id ON ssd_development.ssd_cla_substance_misuse (clas_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clas_substance_misuse_date ON ssd_development.ssd_cla_substance_misuse(clas_substance_misuse_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_placement"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0 
-- Status: [D]ev
-- Remarks: DEV: filtering for OFSTED_URN LIKE 'SC%'
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_placement', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_placement;
IF OBJECT_ID('tempdb..#ssd_cla_placement', 'U') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAP001A"}
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



-- SELECT...

-- <snip>
    -- (
    --     SELECT
    --         TOP(1) fce.OFSTED_URN
    --         FROM   HDM.Child_Social.FACT_CARE_EPISODES fce
    --         WHERE  fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
    --         AND    fce.OFSTED_URN LIKE 'SC%'
    --         AND fce.OFSTED_URN IS NOT NULL        
    -- )                                           AS clap_cla_placement_urn,
 
    -- TRY_CAST(fcp.DISTANCE_FROM_HOME AS FLOAT)   AS clap_cla_placement_distance,                         -- convert to FLOAT (source col is nvarchar, also holds nulls/ints)
    -- fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
 
    -- CASE -- removal of common/invalid placeholder data i.e ZZZ, XX
    --     WHEN LEN(LTRIM(RTRIM(fcp.POSTCODE))) <= 4 THEN NULL
    --     ELSE LTRIM(RTRIM(fcp.POSTCODE))        -- simplistic clean-up
    -- END                                         AS clap_cla_placement_postcode,

-- <snip>
 
-- WHERE fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
--                                             'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
--                                             'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')

-- AND
--     (fcp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fcp.END_DTTM IS NULL);



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_placement ADD CONSTRAINT FK_ssd_clap_to_clae 
FOREIGN KEY (clap_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clap_cla_placement_urn ON ssd_development.ssd_cla_placement (clap_cla_placement_urn);
CREATE NONCLUSTERED INDEX idx_ssd_clap_cla_id ON ssd_development.ssd_cla_placement(clap_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_start_date ON ssd_development.ssd_cla_placement(clap_cla_placement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_end_date ON ssd_development.ssd_cla_placement(clap_cla_placement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_postcode ON ssd_development.ssd_cla_placement(clap_cla_placement_postcode);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_type ON ssd_development.ssd_cla_placement(clap_cla_placement_type);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_reviews"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - ssd_cla_episodes
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_reviews;
IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_reviews (
    clar_cla_review_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAR001A"}
    clar_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
    clar_cla_review_due_date        DATETIME,                   -- metadata={"item_ref":"CLAR003A"}
    clar_cla_review_date            DATETIME,                   -- metadata={"item_ref":"CLAR004A"}
    clar_cla_review_cancelled       NCHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
    clar_cla_review_participation   NVARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
    );
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
) 


-- SELECT...


-- <snip>
 
    (SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
        AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
        THEN ISNULL(fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC, '') END)) 
                                                    AS clar_cla_review_participation
-- <snip>
 
-- WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'

-- AND
--     (fcr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fcr.MEETING_DTTM IS NULL)
 
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fcr.DIM_PERSON_ID -- #DtoI-1799
--     )    ;



-- -- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_reviews ADD CONSTRAINT FK_ssd_clar_to_clae 
FOREIGN KEY (clar_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clar_cla_id ON ssd_development.ssd_cla_reviews(clar_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_due_date ON ssd_development.ssd_cla_reviews(clar_cla_review_due_date);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_date ON ssd_development.ssd_cla_reviews(clar_cla_review_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_previous_permanence"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_previous_permanence') IS NOT NULL DROP TABLE ssd_development.ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;



-- META-ELEMENT: {"type": "create_table"}     
CREATE TABLE ssd_development.ssd_cla_previous_permanence (
    lapp_table_id                               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LAPP001A"}
    lapp_person_id                              NVARCHAR(48),   -- metadata={"item_ref":"LAPP002A"}
    lapp_previous_permanence_option             NVARCHAR(200),  -- metadata={"item_ref":"LAPP003A"}
    lapp_previous_permanence_la                 NVARCHAR(100),  -- metadata={"item_ref":"LAPP004A"}
    lapp_previous_permanence_order_date         NVARCHAR(10)    -- metadata={"item_ref":"LAPP005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date

           )


-- SELECT...

-- -- <snip>
--     COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_option,
--     COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG' THEN ISNULL(tmp_ffa.ANSWER, '') END), '') AS lapp_previous_permanence_la,
--     CASE 
--         WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '')) = 0 AND 
--              CAST(ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '0') AS INT) BETWEEN 1 AND 31 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END), '') 
--         ELSE 'zz' 
--     END + '/' + 
--     CASE 
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('January', 'Jan')  THEN '01'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('February', 'Feb') THEN '02'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('March', 'Mar')    THEN '03'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('April', 'Apr')    THEN '04'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('May')             THEN '05'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('June', 'Jun')     THEN '06'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('July', 'Jul')     THEN '07'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('August', 'Aug')   THEN '08'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('September', 'Sep') THEN '09'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') 
--         IN ('October', 'Oct')  THEN '10'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('November', 'Nov') THEN '11'
--         WHEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END), '') IN ('December', 'Dec') THEN '12'
--         ELSE 'zz' 
--     END + '/' + 
--     CASE 
--         WHEN PATINDEX('%[^0-9]%', ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '')) = 0 THEN ISNULL(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END), '') 
--         ELSE 'zzzz' 
--     END
--     AS lapp_previous_permanence_order_date
-- FROM
--     #ssd_TMP_PRE_previous_permanence tmp_ffa
-- JOIN
--     HDM.Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID
-- AND EXISTS (
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID 
-- )
-- GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;



-- -- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_previous_permanence ADD CONSTRAINT FK_ssd_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_lapp_person_id ON ssd_development.ssd_cla_previous_permanence(lapp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lapp_previous_permanence_option ON ssd_development.ssd_cla_previous_permanence(lapp_previous_permanence_option);


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_care_plan"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:   
-- Dependencies:
-- - ssd_person
-- - #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_pre_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;


 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_care_plan (
    lacp_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"LACP001A"}
    lacp_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LACP007A"}
    lacp_cla_care_plan_start_date   DATETIME,                   -- metadata={"item_ref":"LACP004A"}
    lacp_cla_care_plan_end_date     DATETIME,                   -- metadata={"item_ref":"LACP005A"}
    lacp_cla_care_plan_json         NVARCHAR(1000)              -- metadata={"item_ref":"LACP003A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)


-- SELECT...

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
--         WHERE CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
--     );
 



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_care_plan ADD CONSTRAINT FK_ssd_lacp_person_id
FOREIGN KEY (lacp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_lacp_person_id ON ssd_development.ssd_cla_care_plan(lacp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_start_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_end_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_end_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_visits', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_visits;
IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_visits (
    clav_cla_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAV001A"}
    clav_cla_id                 NVARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
    clav_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
    clav_cla_visit_date         DATETIME,                   -- metadata={"item_ref":"CLAV003A"}
    clav_cla_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
    clav_cla_visit_seen_alone   NCHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 
-- SELECT...


 
-- LEFT JOIN
--     HDM.Child_Social.FACT_CASENOTES AS cn ON  clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
--     AND clav.DIM_PERSON_ID = cn.DIM_PERSON_ID
 
-- LEFT JOIN
--     HDM.Child_Social.DIM_PERSON p ON   clav.DIM_PERSON_ID = p.DIM_PERSON_ID
 
-- WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVL')

-- AND
--     (cn.EVENT_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR cn.EVENT_DTTM IS NULL)

-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = clav.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_visits ADD CONSTRAINT FK_ssd_clav_person_id
FOREIGN KEY (clav_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clav_person_id ON ssd_development.ssd_cla_visits(clav_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clav_visit_date ON ssd_development.ssd_cla_visits(clav_cla_visit_date);
CREATE NONCLUSTERED INDEX idx_ssd_clav_cla_id ON ssd_development.ssd_cla_visits(clav_cla_id);

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_sdq_scores"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_sdq_scores;
IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CSDQ001A"} 
    csdq_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CSDQ002A"}
    csdq_sdq_completed_date     DATETIME,                   -- metadata={"item_ref":"CSDQ003A"}
    csdq_sdq_score              INT,                        -- metadata={"item_ref":"CSDQ005A"}
    csdq_sdq_reason             NVARCHAR(100)               -- metadata={"item_ref":"CSDQ004A", "item_status":"P"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_sdq_scores (
    csdq_table_id, 
    csdq_person_id, 
    csdq_sdq_completed_date, 
    csdq_sdq_score, 
    csdq_sdq_reason
)

-- SELECT
--     ff.FACT_FORM_ID                     AS csdq_table_id,
--     ff.DIM_PERSON_ID                    AS csdq_person_id,
--     CAST('1900-01-01' AS DATETIME)      AS csdq_sdq_completed_date,
--     (
--         SELECT TOP 1
--             CASE
--                 WHEN ISNUMERIC(ffa_inner.ANSWER) = 1 THEN CAST(ffa_inner.ANSWER AS INT)
--                 ELSE NULL
--             END
--         FROM HDM.Child_Social.FACT_FORM_ANSWERS ffa_inner
--         WHERE ffa_inner.FACT_FORM_ID = ff.FACT_FORM_ID
--             AND ffa_inner.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
--             AND ffa_inner.ANSWER_NO = 'SDQScore'
--             AND ffa_inner.ANSWER IS NOT NULL
--         ORDER BY ffa_inner.ANSWER DESC
--     )                                   AS csdq_sdq_score,
--     'SSD_PH'                            AS csdq_sdq_reason
-- FROM
--     HDM.Child_Social.FACT_FORMS ff
-- JOIN
--     HDM.Child_Social.FACT_FORM_ANSWERS ffa ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
--     AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
--     AND ffa.ANSWER_NO IN ('FormEndDate', 'SDQScore')
--     AND ffa.ANSWER IS NOT NULL
-- WHERE EXISTS (
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = ff.DIM_PERSON_ID -- #DtoI-1799
-- );

-- -- Rank the records within the main table
-- ;WITH RankedSDQScores AS (
--     SELECT
--         csdq_table_id,
--         csdq_person_id,
--         csdq_sdq_completed_date,
--         csdq_sdq_score,
--         csdq_sdq_reason,
--         -- Assign unique row nums <within each partition> of csdq_person_id,
--         -- the most recent csdq _form_ id/csdq_table_id will have a row number of 1.
--         ROW_NUMBER() OVER (PARTITION BY csdq_person_id ORDER BY csdq_table_id DESC) AS rn
--     FROM ssd_development.ssd_sdq_scores
-- )

-- -- delete all records from the ssd_sdq_scores table where row number(rn) > 1
-- -- i.e. keep only the most recent
-- DELETE FROM ssd_development.ssd_sdq_scores
-- WHERE csdq_table_id IN (
--     SELECT csdq_table_id
--     FROM RankedSDQScores
--     WHERE rn > 1
-- );

-- -- Identify and remove exact duplicates
-- ;WITH DuplicateSDQScores AS (
--     SELECT
--         csdq_table_id,
--         csdq_person_id,
--         csdq_sdq_completed_date,
--         csdq_sdq_score,
--         csdq_sdq_reason,
--         -- Assign row num to each set of dups,
--         -- partitioned by all columns that could potentially make a row unique
--         ROW_NUMBER() OVER (PARTITION BY csdq_table_id, csdq_person_id ORDER BY csdq_table_id) AS row_num
--     FROM ssd_development.ssd_sdq_scores
-- )
-- DELETE FROM ssd_development.ssd_sdq_scores
-- WHERE csdq_table_id IN (
--     SELECT csdq_table_id
--     FROM DuplicateSDQScores
--     WHERE row_num > 1
-- );


-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
FOREIGN KEY (csdq_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_csdq_person_id ON ssd_development.ssd_sdq_scores(csdq_person_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_missing"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_missing', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_missing;
IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_missing (
    miss_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"MISS001A"}
    miss_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"MISS002A"}
    miss_missing_episode_start_date DATETIME,                   -- metadata={"item_ref":"MISS003A"}
    miss_missing_episode_type       NVARCHAR(100),              -- metadata={"item_ref":"MISS004A"}
    miss_missing_episode_end_date   DATETIME,                   -- metadata={"item_ref":"MISS005A"}
    miss_missing_rhi_offered        NVARCHAR(2),                -- metadata={"item_ref":"MISS006A", "expected_data":["N","Y","NA", NULL]}                
    miss_missing_rhi_accepted       NVARCHAR(2)                 -- metadata={"item_ref":"MISS007A"}
);


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



-- SELECT 
--     fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
--     fmp.DIM_PERSON_ID                   AS miss_person_id,
--     fmp.START_DTTM                      AS miss_missing_episode_start_date,
--     fmp.MISSING_STATUS                  AS miss_missing_episode_type,
--     fmp.END_DTTM                        AS miss_missing_episode_end_date,
--     CASE 
--         WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'YES' THEN 'Y'
--         WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NO' THEN 'N'
--         WHEN UPPER(fmp.RETURN_INTERVIEW_OFFERED) = 'NA' THEN 'NA' -- #DtoI-1617
--         WHEN fmp.RETURN_INTERVIEW_OFFERED = '' THEN NULL
--         ELSE NULL
--     END AS miss_missing_rhi_offered,
--     CASE 
--         WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'YES' THEN 'Y'
--         WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NO' THEN 'N'
--         WHEN UPPER(fmp.RETURN_INTERVIEW_ACCEPTED) = 'NA' THEN 'NA' -- #DtoI-1617
--         WHEN fmp.RETURN_INTERVIEW_ACCEPTED = '' THEN NULL
--         ELSE NULL
--     END AS miss_missing_rhi_accepted

-- FROM 
--     HDM.Child_Social.FACT_MISSING_PERSON AS fmp

-- WHERE
--     (fmp.END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fmp.END_DTTM IS NULL)

-- AND EXISTS 
--     ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fmp.DIM_PERSON_ID -- #DtoI-1799
--     );



-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_missing ADD CONSTRAINT FK_ssd_missing_to_person
FOREIGN KEY (miss_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_miss_person_id        ON ssd_development.ssd_missing(miss_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_start    ON ssd_development.ssd_missing(miss_missing_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_end      ON ssd_development.ssd_missing(miss_missing_episode_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_offered      ON ssd_development.ssd_missing(miss_missing_rhi_offered);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_accepted     ON ssd_development.ssd_missing(miss_missing_rhi_accepted);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_care_leavers"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:   
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

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_care_leavers', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_care_leavers;
IF OBJECT_ID('tempdb..#ssd_care_leavers', 'U') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
 
-- META-ELEMENT: {"type": "create_table"}
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



-- META-ELEMENT: {"type": "insert_data"}  
-- IF using a CTE/Pre-processing TMP table add this in here


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
 
-- SELECT
--     NEWID() AS clea_table_id, 
--     dce.DIM_PERSON_ID                                       AS clea_person_id,
--     CASE WHEN
--         dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NULL
--         THEN 'No Current Eligibility'
--         ELSE dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC END     AS clea_care_leaver_eligibility,
--     fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE                      AS clea_care_leaver_in_touch,
--     fccl.IN_TOUCH_DTTM                                      AS clea_care_leaver_latest_contact,
--     fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC                 AS clea_care_leaver_accommodation,
--     fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC             AS clea_care_leaver_accom_suitable,
--     fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC                      AS clea_care_leaver_activity,

--  MAX(ISNULL(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID 
--     AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH' 
--     THEN fcp.MODIF_DTTM END, '1900-01-01'))                 AS clea_pathway_plan_review_date,

--     ih.PersonalAdvisor                                      AS clea_care_leaver_personal_advisor,
--     ih.AllocatedTeam                                        AS clea_care_leaver_allocated_team,
--     ih.CurrentWorker                                        AS clea_care_leaver_worker_id
 
-- FROM
--     HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
 
-- LEFT JOIN HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID    -- towards clea_care_leaver_in_touch, _latest_contact, _accommodation, _accom_suitable and _activity
 
-- LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID           -- towards clea_pathway_plan_review_date
               
-- LEFT JOIN HDM.Child_Social.DIM_PERSON p ON dce.DIM_PERSON_ID = p.DIM_PERSON_ID                        -- towards LEGACY_ID for testing only
 
-- LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID                     -- connect with CTE aggr data      
 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = dce.DIM_PERSON_ID -- #DtoI-1799
--     )
 
-- GROUP BY
--     dce.DIM_CLA_ELIGIBILITY_ID,
--     fccl.FACT_CLA_CARE_LEAVERS_ID,
--     p.LEGACY_ID,  
--     dce.DIM_PERSON_ID,
--     dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC,
--     fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE,
--     fccl.IN_TOUCH_DTTM,
--     fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC,
--     fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
--     fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC,
--     ih.PersonalAdvisor,
--     ih.CurrentWorker,
--     ih.AllocatedTeam          
--     ;




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_care_leavers ADD CONSTRAINT FK_ssd_care_leavers_person
FOREIGN KEY (clea_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clea_person_id                    ON ssd_development.ssd_care_leavers(clea_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clea_care_leaver_latest_contact   ON ssd_development.ssd_care_leavers(clea_care_leaver_latest_contact);
CREATE NONCLUSTERED INDEX idx_ssd_clea_pathway_plan_review_date     ON ssd_development.ssd_care_leavers(clea_pathway_plan_review_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_permanence"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
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


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_permanence', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_permanence;
IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

-- META-ELEMENT: {"type": "create_table"}
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

-- META-ELEMENT: {"type": "insert_data"}  
-- CTE to rank permanence rows for each person


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


-- SELECT...

-- WHERE rn = 1
-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = perm_person_id -- this a NVARCHAR(48) equality link
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_permanence ADD CONSTRAINT FK_ssd_perm_person_id
FOREIGN KEY (perm_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_perm_person_id            ON ssd_development.ssd_permanence(perm_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_perm_adm_decision_date    ON ssd_development.ssd_permanence(perm_adm_decision_date);
CREATE NONCLUSTERED INDEX idx_ssd_perm_order_date           ON ssd_development.ssd_permanence(perm_permanence_order_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_professionals"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - @CaseloadLastSept30th
-- - @CaseloadTimeframeStartDate
-- - @ssd_timeframe_years
-- - HDM.Child_Social.DIM_WORKER
-- - HDM.Child_Social.FACT_REFERRALS
-- - ssd_cin_episodes (if counting caseloads within SSD timeframe)
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_professionals', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_professionals;
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;


-- META-ELEMENT: {"type": "create_table"}
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

-- SELECT 
--     dw.DIM_WORKER_ID                        AS prof_professional_id,                -- system based ID for workers
--     TRIM(dw.STAFF_ID)                       AS prof_staff_id,                       -- Note that this is trimmed for non-printing chars
--     CONCAT(dw.FORENAME, ' ', dw.SURNAME)    AS prof_professional_name,              -- used also as Allocated Worker|Assigned Worker
--     dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,  -- Not tied to WORKER_ID, this is the social work reg number IF entered
--     ''                                      AS prof_agency_worker_flag,             -- Not available in SSD Ver/Iteration 1 [TESTING] [PLACEHOLDER_DATA]
--     dw.JOB_TITLE                            AS prof_professional_job_title,
--     ISNULL(rc.OpenCases, 0)                 AS prof_professional_caseload,          -- 0 when no open cases on given date.
--     dw.DEPARTMENT_NAME                      AS prof_professional_department,
--     dw.FULL_TIME_EQUIVALENCY                AS prof_full_time_equivalency
-- FROM 
--     HDM.Child_Social.DIM_WORKER AS dw

-- LEFT JOIN (
--     SELECT 
--         -- Calculate CASELOAD 
--         -- [REVIEW][TESTING] count within restricted ssd timeframe only
--         DIM_WORKER_ID,
--         COUNT(*) AS OpenCases
--     FROM 
--         HDM.Child_Social.FACT_REFERRALS

--     WHERE 
--         REFRL_START_DTTM <= @CaseloadLastSept30th AND 
--         (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM >= @CaseloadLastSept30th) AND
--         REFRL_START_DTTM >= @CaseloadTimeframeStartDate  -- ssd timeframe constraint
--     GROUP BY 
--         DIM_WORKER_ID
-- ) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID
-- WHERE 
--     dw.DIM_WORKER_ID <> -1
--     AND TRIM(dw.STAFF_ID) IS NOT NULL           -- in theory would not occur
--     AND LOWER(TRIM(dw.STAFF_ID)) <> 'unknown';  -- data seen in some LAs





-- META-ELEMENT: {"type": "create_fk"}    
-- tbc

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_prof_staff_id             ON ssd_development.ssd_professionals (prof_staff_id);
CREATE NONCLUSTERED INDEX idx_ssd_prof_social_worker_reg_no ON ssd_development.ssd_professionals(prof_social_worker_registration_no);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_department"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1:
--             1.0: 
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - HDM.Child_Social.DIM_DEPARTMENT
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_department', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_department;
IF OBJECT_ID('tempdb..#ssd_department', 'U') IS NOT NULL DROP TABLE #ssd_department;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_department (
    dept_team_id           NVARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
    dept_team_name         NVARCHAR(255), -- metadata={"item_ref":"DEPT1002A"}
    dept_team_parent_id    NVARCHAR(48),  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
    dept_team_parent_name  NVARCHAR(255)  -- metadata={"item_ref":"DEPT1004A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)



-- SELECT ...

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_department ADD CONSTRAINT FK_ssd_dept_team_parent_id 
FOREIGN KEY (dept_team_parent_id) REFERENCES ssd_development.ssd_department(dept_team_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE INDEX idx_ssd_dept_team_id ON ssd_development.ssd_department (dept_team_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_involvements"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
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

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_involvements', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_involvements;
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
-- META-ELEMENT: {"type": "create_table"}
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



-- SELECT...

-- WHERE
--     (fi.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fi.END_DTTM  IS NULL)
-- AND EXISTS
--     (
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799

--     );



-- META-ELEMENT: {"type": "create_fk"} 
-- tbc

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_invo_person_id                ON ssd_development.ssd_involvements(invo_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_invo_professional_role_id     ON ssd_development.ssd_involvements(invo_professional_role_id);
CREATE NONCLUSTERED INDEX idx_ssd_invo_involvement_start_date   ON ssd_development.ssd_involvements(invo_involvement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_involvement_end_date     ON ssd_development.ssd_involvements(invo_involvement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_referral_id              ON ssd_development.ssd_involvements(invo_referral_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_linked_identifiers"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled on a localised basis. 

-- Dependencies: 
-- - Will be LA specific depending on systems/data being linked
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.linked_identifiers', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_linked_identifiers;
IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_linked_identifiers (
    link_table_id               NVARCHAR(48) DEFAULT NEWID() PRIMARY KEY,               -- metadata={"item_ref":"LINK001A"}
    link_person_id              NVARCHAR(48),                               -- metadata={"item_ref":"LINK002A"} 
    link_identifier_type        NVARCHAR(100),                              -- metadata={"item_ref":"LINK003A"}
    link_identifier_value       NVARCHAR(100),                              -- metadata={"item_ref":"LINK004A"}
    link_valid_from_date        DATETIME,                                   -- metadata={"item_ref":"LINK005A"}
    link_valid_to_date          DATETIME                                    -- metadata={"item_ref":"LINK006A"}
);


-- Notes: 
-- By default this object is supplied empty in readiness for manual user input. 
-- Those inserting data must refer to the SSD specification for the standard SSD identifier_types




-- -- Example entry 1

-- -- META-ELEMENT: {"type": "insert_data"}
-- -- link_identifier_type "FORMER_UPN"
-- INSERT INTO ssd_development.ssd_linked_identifiers (
--     link_person_id, 
--     link_identifier_type,
--     link_identifier_value,
--     link_valid_from_date, 
--     link_valid_to_date
-- )
-- SELECT
--     csp.dim_person_id                   AS link_person_id,
--     'Former Unique Pupil Number'        AS link_identifier_type,
--     'SSD_PH'                            AS link_identifier_value,       -- csp.former_upn [TESTING] Removed for compatibility
--     NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
--     NULL                                AS link_valid_to_date           -- NULL for valid_to_date
-- FROM
--     HDM.Child_Social.DIM_PERSON csp
-- WHERE
--     csp.former_upn IS NOT NULL

-- -- AND (link_valid_to_date IS NULL OR link_valid_to_date > GETDATE()) -- We can't yet apply this until source(s) defined. 
-- -- Filter shown here for future reference #DtoI-1806

--  AND EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );

-- -- Example entry 2

-- -- META-ELEMENT: {"type": "insert_data"}
-- -- link_identifier_type "UPN"
-- INSERT INTO ssd_development.ssd_linked_identifiers (
--     link_person_id, 
--     link_identifier_type,
--     link_identifier_value,
--     link_valid_from_date, 
--     link_valid_to_date
-- )
-- SELECT
--     csp.dim_person_id                   AS link_person_id,
--     'Unique Pupil Number'               AS link_identifier_type,
--     'SSD_PH'                            AS link_identifier_value,       -- csp.upn [TESTING] Removed for compatibility
--     NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
--     NULL                                AS link_valid_to_date           -- NULL for valid_to_date
-- FROM
--     HDM.Child_Social.DIM_PERSON csp

-- -- LEFT JOIN -- csp.upn [TESTING] Removed for compatibility
-- --     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

-- WHERE
--     csp.upn IS NOT NULL AND
--     EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_linked_identifiers ADD CONSTRAINT FK_ssd_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_link_person_id        ON ssd_development.ssd_linked_identifiers(link_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_from_date  ON ssd_development.ssd_linked_identifiers(link_valid_from_date);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_to_date    ON ssd_development.ssd_linked_identifiers(link_valid_to_date);


/* END SSD main extract */
/* ********************************************************************************************************** */





/* Start 

        NON-CORE Objects 
        Incl.
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

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.s251_finance', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_s251_finance;
IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_s251_finance (
    s251_table_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"S251001A"}
    s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
    s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
    s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
    s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
    s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
);




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_s251_finance ADD CONSTRAINT FK_ssd_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_development.ssd_cla_placement(clap_cla_placement_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_s251_cla_placement_id ON ssd_development.ssd_s251_finance(s251_cla_placement_id);

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

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.voice_of_child', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_voice_of_child;
IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"VOCH007A"}
    voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
    voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
    voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
    voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
    voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
    voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
);


-- SELECT...


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = source_table.DIM_PERSON_ID
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_voice_of_child ADD CONSTRAINT FK_ssd_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_voice_of_child_voch_person_id ON ssd_development.ssd_voice_of_child(voch_person_id);


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


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.pre_proceedings', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_pre_proceedings;
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_pre_proceedings (
    prep_table_id                           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PREP024A"}
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



-- SELECT...


-- To switch on once source data defined.
-- WHERE EXISTS 
-- ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = plo_source_data_table.DIM_PERSON_ID
--     );





-- META-ELEMENT: {"type": "create_fk"}  
-- #DtoI-1769
ALTER TABLE ssd_development.ssd_pre_proceedings ADD CONSTRAINT FK_ssd_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_prep_person_id                ON ssd_development.ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_prep_pre_pro_decision_date    ON ssd_development.ssd_pre_proceedings (prep_pre_pro_decision_date);
CREATE NONCLUSTERED INDEX idx_ssd_prep_legal_gateway_outcome    ON ssd_development.ssd_pre_proceedings (prep_legal_gateway_outcome);

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
-- Status: [P]laceholder
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled on a localised basis. 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_send') IS NOT NULL DROP TABLE ssd_development.ssd_send;
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL DROP TABLE #ssd_send;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_send (
    send_table_id       NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"SEND001A"}
    send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
    send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
    send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
    send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );

-- META-ELEMENT: {"type": "insert_data"} 
-- for link_identifier_type "FORMER_UPN"
INSERT INTO ssd_development.ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    send_upn_unknown
)



-- SELECT
--     NEWID() AS send_table_id,          -- generate unique id
--     csp.dim_person_id AS send_person_id,
--     'SSD_PH' AS send_upn,               -- csp.upn # only available with Education schema
--     'SSD_PH' AS send_uln,               -- ep.uln # only available with Education schema              
--     'SSD_PH' AS send_upn_unknown      
-- FROM
--     HDM.Child_Social.DIM_PERSON csp

-- -- -- temporarily disabled populating UPN & ULN as these access non-core
-- -- LEFT JOIN
-- --     -- we have to switch to Education schema in order to obtain this
-- --     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

-- WHERE
--     EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );
 


-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_send_person_id ON ssd_development.ssd_send (send_person_id);

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

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_sen_need', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_sen_need  ;
IF OBJECT_ID('tempdb..#ssd_sen_need', 'U') IS NOT NULL DROP TABLE #ssd_sen_need  ;
 
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_sen_need (
    senn_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"SENN001A"}
    senn_active_ehcp_id             NVARCHAR(48),               -- metadata={"item_ref":"SENN002A"}
    senn_active_ehcp_need_type      NVARCHAR(100),              -- metadata={"item_ref":"SENN003A"}
    senn_active_ehcp_need_rank      NCHAR(1)                    -- metadata={"item_ref":"SENN004A"}
);
 

-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_development.ssd_ehcp_active_plans(ehcp_active_ehcp_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

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
IF OBJECT_ID('ssd_development.ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_requests ;
IF OBJECT_ID('tempdb..#ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_requests ;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_requests (
    ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCR001A"}
    ehcr_send_table_id              NVARCHAR(48),               -- metadata={"item_ref":"EHCR002A"}
    ehcr_ehcp_req_date              DATETIME,                   -- metadata={"item_ref":"EHCR003A"}
    ehcr_ehcp_req_outcome_date      DATETIME,                   -- metadata={"item_ref":"EHCR004A"}
    ehcr_ehcp_req_outcome           NVARCHAR(100)               -- metadata={"item_ref":"EHCR005A"}
);



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_development.ssd_send(send_table_id);


-- META-ELEMENT: {"type": "create_idx"}
-- tbc

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

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_assessment ;
IF OBJECT_ID('tempdb..#ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_assessment ;


-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_ehcp_assessment (
    ehca_ehcp_assessment_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCA001A"}
    ehca_ehcp_request_id                    NVARCHAR(48),               -- metadata={"item_ref":"EHCA002A"}
    ehca_ehcp_assessment_outcome_date       DATETIME,                   -- metadata={"item_ref":"EHCA003A"}
    ehca_ehcp_assessment_outcome            NVARCHAR(100),              -- metadata={"item_ref":"EHCA004A"}
    ehca_ehcp_assessment_exceptions         NVARCHAR(100)               -- metadata={"item_ref":"EHCA005A"}
);




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

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

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_named_plan;
IF OBJECT_ID('tempdb..#ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_named_plan;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_named_plan (
    ehcn_named_plan_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCN001A"}
    ehcn_ehcp_asmt_id               NVARCHAR(48),               -- metadata={"item_ref":"EHCN002A"}
    ehcn_named_plan_start_date      DATETIME,                   -- metadata={"item_ref":"EHCN003A"}
    ehcn_named_plan_ceased_date     DATETIME,                   -- metadata={"item_ref":"EHCN004A"}     
    ehcn_named_plan_ceased_reason   NVARCHAR(100)               -- metadata={"item_ref":"EHCN005A"}   
);



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_development.ssd_ehcp_assessment(ehca_ehcp_assessment_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

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

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_active_plans  ;
IF OBJECT_ID('tempdb..#ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_active_plans (
    ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCP001A"}
    ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
    ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
);



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc
    

-- META-END


/* End

        Non-Core Liquid Logic elements extracts 
        
        */





/* Start

        SSD Extract Logging
        */







-- -- META-CONTAINER: {"type": "table", "name": "ssd_extract_log"}
-- -- =============================================================================
-- -- Description: Enable LA extract overview logging
-- -- Author: D2I
-- -- Version: 0.1
-- -- Status: [B]acklog
-- -- Remarks: Not core SSD / Not essential / low priority
-- -- Dependencies: 
-- -- - 
-- -- =============================================================================


-- -- META-ELEMENT: {"type": "drop_table"}
-- IF OBJECT_ID('ssd_development.ssd_extract_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_extract_log;
-- IF OBJECT_ID('tempdb..#ssd_extract_log', 'U') IS NOT NULL DROP TABLE #ssd_extract_log;

-- -- META-ELEMENT: {"type": "create_table"}
-- CREATE TABLE ssd_development.ssd_extract_log (
--     table_name           NVARCHAR(255) PRIMARY KEY,     
--     schema_name          NVARCHAR(255),
--     status               NVARCHAR(50), -- status code includes error output + schema.table_name
--     rows_inserted        INT,
--     table_size_kb        INT,
--     has_pk      BIT,
--     has_fks     BIT,
--     index_count          INT,
--     creation_date        DATETIME DEFAULT GETDATE(),
--     null_count           INT,          -- New: count of null values for each table
--     pk_datatype          NVARCHAR(255),-- New: datatype of the PK field
--     additional_detail    NVARCHAR(MAX), -- on hold|future use, e.g. data quality issues detected
--     error_message        NVARCHAR(MAX)  -- on hold|future use, e.g. errors encountered during the process
-- );


-- -- META-ELEMENT: {"type": "insert_data"} 
-- -- GO
-- -- Ensure all variables are declared correctly
-- DECLARE @row_count          INT;
-- DECLARE @table_size_kb      INT;
-- DECLARE @has_pk             BIT;
-- DECLARE @has_fks            BIT;
-- DECLARE @index_count        INT;
-- DECLARE @null_count         INT;
-- DECLARE @pk_datatype        NVARCHAR(255);
-- DECLARE @additional_detail  NVARCHAR(MAX);
-- DECLARE @error_message      NVARCHAR(MAX);
-- DECLARE @table_name         NVARCHAR(255);
-- DECLARE @sql                NVARCHAR(MAX) = N'';   


-- -- Placeholder for table_cursor selection logic
-- DECLARE table_cursor CURSOR FOR
-- SELECT 'ssd_development.ssd_version_log'             UNION ALL -- Admin table, not SSD
-- SELECT 'ssd_development.ssd_person'                  UNION ALL
-- SELECT 'ssd_development.ssd_family'                  UNION ALL
-- SELECT 'ssd_development.ssd_address'                 UNION ALL
-- SELECT 'ssd_development.ssd_disability'              UNION ALL
-- SELECT 'ssd_development.ssd_immigration_status'      UNION ALL
-- SELECT 'ssd_development.ssd_mother'                  UNION ALL
-- SELECT 'ssd_development.ssd_legal_status'            UNION ALL
-- SELECT 'ssd_development.ssd_contacts'                UNION ALL
-- SELECT 'ssd_development.ssd_early_help_episodes'     UNION ALL
-- SELECT 'ssd_development.ssd_cin_episodes'            UNION ALL
-- SELECT 'ssd_development.ssd_cin_assessments'         UNION ALL
-- SELECT 'ssd_development.ssd_assessment_factors'      UNION ALL
-- SELECT 'ssd_development.ssd_cin_plans'               UNION ALL
-- SELECT 'ssd_development.ssd_cin_visits'              UNION ALL
-- SELECT 'ssd_development.ssd_s47_enquiry'             UNION ALL
-- SELECT 'ssd_development.ssd_initial_cp_conference'   UNION ALL
-- SELECT 'ssd_development.ssd_cp_plans'                UNION ALL
-- SELECT 'ssd_development.ssd_cp_visits'               UNION ALL
-- SELECT 'ssd_development.ssd_cp_reviews'              UNION ALL
-- SELECT 'ssd_development.ssd_cla_episodes'            UNION ALL
-- SELECT 'ssd_development.ssd_cla_convictions'         UNION ALL
-- SELECT 'ssd_development.ssd_cla_health'              UNION ALL
-- SELECT 'ssd_development.ssd_cla_immunisations'       UNION ALL
-- SELECT 'ssd_development.ssd_cla_substance_misuse'    UNION ALL
-- SELECT 'ssd_development.ssd_cla_placement'           UNION ALL
-- SELECT 'ssd_development.ssd_cla_reviews'             UNION ALL
-- SELECT 'ssd_development.ssd_cla_previous_permanence' UNION ALL
-- SELECT 'ssd_development.ssd_cla_care_plan'           UNION ALL
-- SELECT 'ssd_development.ssd_cla_visits'              UNION ALL
-- SELECT 'ssd_development.ssd_sdq_scores'              UNION ALL
-- SELECT 'ssd_development.ssd_missing'                 UNION ALL
-- SELECT 'ssd_development.ssd_care_leavers'            UNION ALL
-- SELECT 'ssd_development.ssd_permanence'              UNION ALL
-- SELECT 'ssd_development.ssd_professionals'           UNION ALL
-- SELECT 'ssd_development.ssd_department'              UNION ALL
-- SELECT 'ssd_development.ssd_involvements'            UNION ALL
-- SELECT 'ssd_development.ssd_linked_identifiers'      UNION ALL
-- SELECT 'ssd_development.ssd_s251_finance'            UNION ALL
-- SELECT 'ssd_development.ssd_voice_of_child'          UNION ALL
-- SELECT 'ssd_development.ssd_pre_proceedings'         UNION ALL
-- SELECT 'ssd_development.ssd_send'                    UNION ALL
-- SELECT 'ssd_development.ssd_sen_need'                UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_requests'           UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_assessment'         UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_named_plan'         UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_active_plans';

-- -- Define placeholder tables
-- DECLARE @ssd_placeholder_tables TABLE (table_name NVARCHAR(255));
-- INSERT INTO @ssd_placeholder_tables (table_name)
-- VALUES
--     ('ssd_development.ssd_send'),
--     ('ssd_development.ssd_sen_need'),
--     ('ssd_development.ssd_ehcp_requests'),
--     ('ssd_development.ssd_ehcp_assessment'),
--     ('ssd_development.ssd_ehcp_named_plan'),
--     ('ssd_development.ssd_ehcp_active_plans');

-- DECLARE @dfe_project_placeholder_tables TABLE (table_name NVARCHAR(255));
-- INSERT INTO @dfe_project_placeholder_tables (table_name)
-- VALUES
--     ('ssd_development.ssd_s251_finance'),
--     ('ssd_development.ssd_voice_of_child'),
--     ('ssd_development.ssd_pre_proceedings');

-- -- Open table cursor
-- OPEN table_cursor;

-- -- Fetch next table name from the list
-- FETCH NEXT FROM table_cursor INTO @table_name;

-- -- Iterate table names listed above
-- WHILE @@FETCH_STATUS = 0
-- BEGIN
--     BEGIN TRY
--         -- Generate the schema-qualified table name
--         DECLARE @full_table_name NVARCHAR(511);
--         SET @full_table_name = CASE WHEN @schema_name = '' THEN @table_name ELSE @schema_name + '.' + @table_name END;

--         -- Check if table exists
--         SET @sql = N'SELECT @table_exists = COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name';
--         DECLARE @table_exists INT;
--         EXEC sp_executesql @sql, N'@table_exists INT OUTPUT, @schema_name NVARCHAR(255), @table_name NVARCHAR(255)', @table_exists OUTPUT, @schema_name, @table_name;

--         IF @table_exists = 0
--         BEGIN
--             THROW 50001, 'Table does not exist', 1;
--         END
        
--         -- get row count
--         SET @sql = N'SELECT @row_count = COUNT(*) FROM ' + @full_table_name;
--         EXEC sp_executesql @sql, N'@row_count INT OUTPUT', @row_count OUTPUT;

--         -- get table size in KB
--         SET @sql = N'SELECT @table_size_kb = SUM(reserved_page_count) * 8 FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
--         EXEC sp_executesql @sql, N'@table_size_kb INT OUTPUT', @table_size_kb OUTPUT;

--         -- check for primary key (flag field)
--         SET @sql = N'
--             SELECT @has_pk = CASE WHEN EXISTS (
--                 SELECT 1 
--                 FROM sys.indexes i
--                 WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(''' + @full_table_name + ''')
--             ) THEN 1 ELSE 0 END';
--         EXEC sp_executesql @sql, N'@has_pk BIT OUTPUT', @has_pk OUTPUT;

--         -- check for foreign key(s) (flag field)
--         SET @sql = N'
--             SELECT @has_fks = CASE WHEN EXISTS (
--                 SELECT 1 
--                 FROM sys.foreign_keys fk
--                 WHERE fk.parent_object_id = OBJECT_ID(''' + @full_table_name + ''')
--             ) THEN 1 ELSE 0 END';
--         EXEC sp_executesql @sql, N'@has_fks BIT OUTPUT', @has_fks OUTPUT;

--         -- count index(es)
--         SET @sql = N'
--             SELECT @index_count = COUNT(*)
--             FROM sys.indexes
--             WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
--         EXEC sp_executesql @sql, N'@index_count INT OUTPUT', @index_count OUTPUT;

--         -- Get null values count (~overview of data sparcity)
--         DECLARE @col NVARCHAR(255);
--         DECLARE @total_nulls INT;
--         SET @total_nulls = 0;

--         DECLARE column_cursor CURSOR FOR
--         SELECT COLUMN_NAME
--         FROM INFORMATION_SCHEMA.COLUMNS
--         WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name;

--         OPEN column_cursor;
--         FETCH NEXT FROM column_cursor INTO @col;
--         WHILE @@FETCH_STATUS = 0
--         BEGIN
--             SET @sql = N'SELECT @total_nulls = @total_nulls + (SELECT COUNT(*) FROM ' + @full_table_name + ' WHERE ' + @col + ' IS NULL)';
--             EXEC sp_executesql @sql, N'@total_nulls INT OUTPUT', @total_nulls OUTPUT;
--             FETCH NEXT FROM column_cursor INTO @col;
--         END
--         CLOSE column_cursor;
--         DEALLOCATE column_cursor;

--         SET @null_count = @total_nulls;

--         -- get datatype of the primary key
--         SET @sql = N'
--             SELECT TOP 1 @pk_datatype = c.DATA_TYPE
--             FROM INFORMATION_SCHEMA.COLUMNS c
--             JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON c.COLUMN_NAME = kcu.COLUMN_NAME AND c.TABLE_NAME = kcu.TABLE_NAME AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
--             JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
--             WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
--             AND kcu.TABLE_NAME = @table_name
--             AND kcu.TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END';
--         EXEC sp_executesql @sql, N'@pk_datatype NVARCHAR(255) OUTPUT, @table_name NVARCHAR(255), @schema_name NVARCHAR(255)', @pk_datatype OUTPUT, @table_name, @schema_name;

--         -- set additional_detail comment to make sense|add detail to expected 
--         -- empty/placholder tables incl. future DfE projects
--         SET @additional_detail = NULL;

--         IF EXISTS (SELECT 1 FROM @ssd_placeholder_tables WHERE table_name = @table_name)
--         BEGIN
--             SET @additional_detail = 'ssd placeholder table';
--         END
--         ELSE IF EXISTS (SELECT 1 FROM @dfe_project_placeholder_tables WHERE table_name = @table_name)
--         BEGIN
--             SET @additional_detail = 'DfE project placeholder table';
--         END

--         -- insert log entry 
--         INSERT INTO ssd_development.ssd_extract_log (
--             table_name, 
--             schema_name, 
--             status, 
--             rows_inserted, 
--             table_size_kb, 
--             has_pk, 
--             has_fks, 
--             index_count, 
--             null_count, 
--             pk_datatype, 
--             additional_detail
--             )
--         VALUES (@table_name, @schema_name, 'Success', @row_count, @table_size_kb, @has_pk, @has_fks, @index_count, @null_count, @pk_datatype, @additional_detail);
--     END TRY
--     BEGIN CATCH
--         -- log any error (this only an indicator of possible issue)
--         -- tricky 
--         SET @error_message = ERROR_MESSAGE();
--         INSERT INTO ssd_development.ssd_extract_log (
--             table_name, 
--             schema_name, 
--             status, 
--             rows_inserted, 
--             table_size_kb, 
--             has_pk, 
--             has_fks, 
--             index_count, 
--             null_count, 
--             pk_datatype, 
--             additional_detail, 
--             error_message
--             )
--         VALUES (@table_name, @schema_name, 'Error', 0, NULL, 0, 0, 0, 0, NULL, @additional_detail, @error_message);
--     END CATCH;

--     -- Fetch next table name
--     FETCH NEXT FROM table_cursor INTO @table_name;
-- END;

-- CLOSE table_cursor;
-- DEALLOCATE table_cursor;

-- SET @sql = N'';



-- -- META-ELEMENT: {"type": "console_output"}
-- -- Forming part of the extract admin results output
-- SELECT * FROM ssd_development.ssd_extract_log ORDER BY rows_inserted DESC;


-- META-ELEMENT: {"type": "console_output"} 
-- output for ref most recent/current ssd version and last update
SELECT * FROM ssd_development.ssd_version_log WHERE is_current = 1;


-- -- META-END


