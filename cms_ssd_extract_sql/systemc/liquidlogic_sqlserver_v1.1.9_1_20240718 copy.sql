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

-- Run SSD into Temporary OR Persistent extract structure
-- 
GO 

DECLARE @sql NVARCHAR(MAX) = N'';

DECLARE @Run_SSD_As_Temporary_Tables BIT;
SET     @Run_SSD_As_Temporary_Tables = 0;  -- 1==Single use SSD extract uses tempdb..# | 0==Persistent SSD table set up



-- Point to correct DB/TABLE_CATALOG if required
USE HDM_Local; 
-- ALTER USER user_name WITH DEFAULT_SCHEMA = ssd_development; -- Commented due to permissions issues



/* [TESTING] 
Set up (to be removed from live v2+)
*/
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder';

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time
/* END [TESTING] 
*/



IF @Run_SSD_As_Temporary_Tables = 1
BEGIN
    -- extracting into non-persistent temp tables
    -- no constraint clean-up required

    PRINT  CHAR(13) + CHAR(10) + 'Establishing SSD in temporary db namespace, prefixed as #ssd_' + CHAR(13) + CHAR(10);
END
ELSE
BEGIN
    -- extracting into persistent|perm tables
    -- therefore some potential clean-up need from any previous implementations

    PRINT CHAR(13) + CHAR(10) + 'Establishing SSD as persistant tables, prefixed as ssd_' + CHAR(13) + CHAR(10);

    /* START drop all ssd_development. schema constraints */

    -- pre-emptively avoid any run-time conflicts from left-behind FK constraints

    -- generate DROP FK commands
    SELECT @sql += '
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = ' + QUOTENAME(fk.name, '''') + ')
        BEGIN
            ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';
        END;'
    FROM sys.foreign_keys AS fk
    INNER JOIN sys.tables AS t ON fk.parent_object_id = t.object_id
    INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
    WHERE s.name = N'ssd_development';

    -- execute drop FK
    EXEC sp_executesql @sql;

    -- Clear SQL var
    SET @sql = N'';

    -- generate DROP TABLE for each table in schema
    SELECT @sql += '
    IF OBJECT_ID(''' + s.name + '.' + t.name + ''', ''U'') IS NOT NULL
    BEGIN
        DROP TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';
    END;
    '
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
    WHERE s.name = N'ssd_development';

    -- Execute drop tables
    EXEC sp_executesql @sql;

    /* END Drop all ssd_development. schema constraints */
END




/* ********************************************************************************************************** */
/* SSD extract set up */

-- ssd extract time-frame (YRS)
DECLARE @ssd_timeframe_years INT = 6;
DECLARE @ssd_sub1_range_years INT = 1;

-- store date on which CASELOAD count required. Currently : Most recent past Sept30th
DECLARE @LastSept30th DATE; 

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
SET @TableName = N'ssd_version_log';


-- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_version_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_version_log;
IF OBJECT_ID('tempdb..#ssd_version_log', 'U') IS NOT NULL DROP TABLE #ssd_version_log;

-- create versioning information object
CREATE TABLE ssd_development.ssd_version_log (
    version_number      NVARCHAR(10) NOT NULL,          -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                  -- date of version release
    description         NVARCHAR(100),                  -- brief description of version
    is_current          BIT NOT NULL DEFAULT 0,         -- flag to indicate if this is the current version
    created_at          DATETIME DEFAULT GETDATE(),     -- timestamp when record was created
    created_by          NVARCHAR(10),                   -- which user created the record
    impact_description  NVARCHAR(255)                   -- additional notes on the impact of the release
);

-- ensure any previous current-version flag is set to 0 (not current), before adding new current version
UPDATE ssd_development.ssd_version_log SET is_current = 0 WHERE is_current = 1;


-- insert & update current version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_development.ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.1.9', GETDATE(), 'Applied CAST(person_id) + minor fixes', 1, 'admin', 'impacts all tables using where exists');


-- historic versioning log data
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
    ('1.1.8', '2024-07-17', 'admin table creation logging process defined', 0, 'admin', '');


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;



/* ********************************************************************************************************** */
/* SSD main extract start */


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
- Child_Social.DIM_PERSON
- Child_Social.FACT_REFERRALS
- Child_Social.FACT_CONTACTS
- Child_Social.FACT_903_DATA
- Child_Social.FACT_CLA_CARE_LEAVERS
- Child_Social.DIM_CLA_ELIGIBILITY
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_person';



-- check exists & drop
IF OBJECT_ID('ssd_development.ssd_person') IS NOT NULL DROP TABLE ssd_development.ssd_person;
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;


-- Create structure
CREATE TABLE ssd_development.ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}   
    pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A"} 
    pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"T", "expected_data":["unknown","NULL", "F", "U", "M", "I"]}       
    pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"} 
    pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
    pers_common_child_id    NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
    pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
    pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
    pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        NVARCHAR(48),                -- metadata={"item_ref":"PERS012A"} 
    ssd_flag INT
);


-- CTE to get a no_upn_code 
-- (assumption here is that all codes will be the same/current)
WITH f903_data_CTE AS (
    SELECT 
        -- get the most recent no_upn_code if exists
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        Child_Social.fact_903_data
)
-- Insert data
INSERT INTO ssd_development.ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,
    pers_gender,
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
SELECT
    p.LEGACY_ID,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),              -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    p.GENDER_MAIN_CODE,
    p.NHS_NUMBER,                                       
    p.ETHNICITY_MAIN_CODE,
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM                               -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL 
    END,                                                --  or NULL
    NULL AS pers_common_child_id,                       -- Set to NULL as default(dev) / or set to NHS num
    COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
    p.EHM_SEN_FLAG,
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM                               -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL 
    END,                                                --  or NULL
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND              -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI')  -- check for child relation only
        THEN 'Y'
        ELSE NULL -- No child relation found
    END,
    p.NATNL_CODE,
    1
   
FROM
    Child_Social.DIM_PERSON AS p
 
-- [TESTING][PLACEHOLDER] 903 table refresh only in reporting period?
LEFT JOIN (
    -- no other accessible location for UPN data
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
    -- AND (p.IS_CLIENT = 'Y'
    --     OR (
    --         EXISTS (
    --             SELECT 1 
    --             FROM Child_Social.FACT_CONTACTS fc
    --             WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
    --             AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    --         )
    --         OR EXISTS (
    --             SELECT 1 
    --             FROM Child_Social.FACT_REFERRALS fr
    --             WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
    --             AND (
    --                 fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
    --                 OR fr.REFRL_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) 
    --                 OR fr.REFRL_END_DTTM IS NULL
    --             )
    --         )
    --         OR EXISTS (
    --             SELECT 1 FROM Child_Social.FACT_CLA_CARE_LEAVERS fccl
    --             WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
    --             AND fccl.IN_TOUCH_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    --         )
    --         OR EXISTS (
    --             SELECT 1 FROM Child_Social.DIM_CLA_ELIGIBILITY dce
    --             WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
    --             AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
    --         )
    --         OR EXISTS (
    --             SELECT 1 FROM Child_Social.FACT_INVOLVEMENTS fi
    --             WHERE (fi.DIM_PERSON_ID = p.DIM_PERSON_ID
    --             AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' --Key Agencies (External)
	-- 			OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL OR fi.IS_ALLOCATED_CW_FLAG = 'Y')
	-- 			AND START_DTTM > '2009-12-04 00:54:49.947' -- was trying to cut off from 2010 but when I changed the date it threw up an erro
	-- 			AND DIM_WORKER_ID <> '-1' 
    --             AND (fi.END_DTTM IS NULL OR fi.END_DTTM > GETDATE()))
    --         )
    --     )
    -- )
    ;


IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_person_pers_dob               ON ssd_development.ssd_person(pers_dob);
    CREATE NONCLUSTERED INDEX idx_ssd_person_pers_common_child_id   ON ssd_development.ssd_person(pers_common_child_id);
    CREATE NONCLUSTERED INDEX idx_ssd_person_ethnicity_gender       ON ssd_development.ssd_person(pers_ethnicity, pers_gender);
END





-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;



/*SSD Person filter (notes): - Implemented*/
-- [done]contact in last 6yrs - Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
-- [done] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
-- [picked up within the referral] active plan or has been active in 6yrs 

/*SSD Person filter (notes): - ON HOLD/Not included in SSD Ver/Iteration 1*/
--1
-- ehcp request in last 6yrs - Child_Social.FACT_EHCP_EPISODE.REQUEST_DTTM ; [perhaps not in iteration|version 1]
    -- OR EXISTS (
    --     -- ehcp request in last x@yrs
    --     SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
    --     WHERE fe.DIM_PERSON_ID = p.DIM_PERSON_ID
    --     AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    -- )
    
--2 (Uncertainty re access EH)
-- Has eh_referral open in last 6yrs - 

--3 (Uncertainty re access SEN)
-- Has a record in send - Child_Social.FACT_SEN, DIM_LOOKUP_SEN, DIM_LOOKUP_SEN_TYPE ? 





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
-- [TESTING] Create marker
SET @TableName = N'ssd_family';



-- check exists & drop
IF OBJECT_ID('ssd_development.ssd_family') IS NOT NULL DROP TABLE ssd_development.ssd_family;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;


-- Create structure
CREATE TABLE ssd_development.ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);

-- Insert data 
INSERT INTO ssd_development.ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )
SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM Child_Social.FACT_CONTACTS AS fc
WHERE EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );


IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT FK_family_person
    FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_family_person_id              ON ssd_development.ssd_family(fami_person_id);
    CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);

END






-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;



/* 
=============================================================================
Object Name: ssd_address
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
-- [TESTING] Create marker
SET @TableName = N'ssd_address';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_address') IS NOT NULL DROP TABLE ssd_development.ssd_address;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;


-- Create structure
CREATE TABLE ssd_development.ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
    addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
    addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
    addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
    addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
    addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
    addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
);


-- insert data
INSERT INTO ssd_development.ssd_address (
    addr_table_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start_date, 
    addr_address_end_date, 
    addr_address_postcode, 
    addr_address_json
)
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
    Child_Social.DIM_PERSON_ADDRESS AS pa

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID -- #DtoI-1799
    );

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_address ADD CONSTRAINT FK_address_person
    FOREIGN KEY (addr_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_address_person        ON ssd_development.ssd_address(addr_person_id);
    CREATE NONCLUSTERED INDEX idx_address_start         ON ssd_development.ssd_address(addr_address_start_date);
    CREATE NONCLUSTERED INDEX idx_address_end           ON ssd_development.ssd_address(addr_address_end_date);
    CREATE NONCLUSTERED INDEX idx_ssd_address_postcode  ON ssd_development.ssd_address(addr_address_postcode);
END


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;





/* 
=============================================================================
Object Name: ssd_disability
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
-- [TESTING] Create marker
SET @TableName = N'ssd_disability';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_disability') IS NOT NULL DROP TABLE ssd_development.ssd_disability;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

-- Create the structure
CREATE TABLE ssd_development.ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);


-- Insert data
INSERT INTO ssd_development.ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)
SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id, 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    Child_Social.FACT_DISABILITY AS fd

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fd.DIM_PERSON_ID -- #DtoI-1799
    );

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_disability ADD CONSTRAINT FK_disability_person 
    FOREIGN KEY (disa_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);
        
    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_disability_person_id ON ssd_development.ssd_disability(disa_person_id);
    CREATE NONCLUSTERED INDEX idx_ssd_disability_code ON ssd_development.ssd_disability(disa_disability_code);
END



-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;






/* 
=============================================================================
Object Name: ssd_immigration_status (UASC)
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
-- [TESTING] Create marker
SET @TableName = N'ssd_immigration_status';

 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_immigration_status') IS NOT NULL DROP TABLE ssd_development.ssd_immigration_status;
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;


-- Create structure
CREATE TABLE ssd_development.ssd_immigration_status (
    immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
    immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
    immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
    immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
    immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
);
 
 
-- insert data
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
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE
    EXISTS
    ( -- only ssd relevant records
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE CAST(p.pers_person_id AS INT) = ims.DIM_PERSON_ID -- #DtoI-1799
    );


IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
    FOREIGN KEY (immi_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_immigration_status_immi_person_id ON ssd_development.ssd_immigration_status(immi_person_id);
    CREATE NONCLUSTERED INDEX idx_immigration_status_start          ON ssd_development.ssd_immigration_status(immi_immigration_status_start_date);
    CREATE NONCLUSTERED INDEX idx_immigration_status_end            ON ssd_development.ssd_immigration_status(immi_immigration_status_end_date);
END


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;




/* 
=============================================================================
Object Name: ssd_mother
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
-- [TESTING] Create marker
SET @TableName = N'ssd_mother';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_mother;
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;


-- Create structure
CREATE TABLE ssd_development.ssd_mother (
    moth_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
);
 
-- Insert data
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
    Child_Social.FACT_PERSON_RELATION AS fpr
JOIN
    Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> 'M'
    AND
    fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND
    fpr.END_DTTM IS NULL
 
AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1799
    );

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_moth_to_person 
    FOREIGN KEY (moth_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- -- [TESTING] deployment issues remain
    -- ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_child_to_person 
    -- FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- -- [TESTING] Comment this out for ESCC until further notice
    -- ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT CHK_no_self_parenting -- Ensure person cannot be their own mother
    -- CHECK (moth_person_id <> moth_childs_person_id);


    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_mother_moth_person_id ON ssd_development.ssd_mother(moth_person_id);
    CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_person_id ON ssd_development.ssd_mother(moth_childs_person_id);
    CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_dob ON ssd_development.ssd_mother(moth_childs_dob);
END


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;




/* 
=============================================================================
Object Name: ssd_legal_status
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
-- [TESTING] Create marker
SET @TableName = N'ssd_legal_status';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_legal_status') IS NOT NULL DROP TABLE ssd_development.ssd_legal_status;
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- Create structure
CREATE TABLE ssd_development.ssd_legal_status (
    lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LEGA001A"}
    lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
    lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
    lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
    lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
);
 
-- Insert data
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
    Child_Social.FACT_LEGAL_STATUS AS fls
WHERE EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fls.DIM_PERSON_ID -- #DtoI-1799
    );

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_legal_status ADD CONSTRAINT FK_legal_status_person
    FOREIGN KEY (lega_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_legal_status_lega_person_id   ON ssd_development.ssd_legal_status(lega_person_id);
    CREATE NONCLUSTERED INDEX idx_ssd_legal_status                  ON ssd_development.ssd_legal_status(lega_legal_status);
    CREATE NONCLUSTERED INDEX idx_ssd_legal_status_start            ON ssd_development.ssd_legal_status(lega_legal_status_start_date);
    CREATE NONCLUSTERED INDEX idx_ssd_legal_status_end              ON ssd_development.ssd_legal_status(lega_legal_status_end_date);
END


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;





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
-- [TESTING] Create marker
SET @TableName = N'ssd_contacts';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_contacts') IS NOT NULL DROP TABLE ssd_development.ssd_contacts;
IF OBJECT_ID('tempdb..#ssd_contacts') IS NOT NULL DROP TABLE #ssd_contacts;


-- Create structure
CREATE TABLE ssd_development.ssd_contacts (
    cont_contact_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CONT001A"}
    cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
    cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
    cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
    cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
    cont_contact_outcome_json       NVARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
);

-- Insert data
INSERT INTO ssd_development.ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC,
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
    Child_Social.FACT_CONTACTS AS fc
    
WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_contacts ADD CONSTRAINT FK_contact_person 
    FOREIGN KEY (cont_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_contact_person_id     ON ssd_development.ssd_contacts(cont_person_id);
    CREATE NONCLUSTERED INDEX idx_contact_date          ON ssd_development.ssd_contacts(cont_contact_date);
    CREATE NONCLUSTERED INDEX idx_contact_source_code   ON ssd_development.ssd_contacts(cont_contact_source_code);
END



-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;






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
-- [TESTING] Create marker
SET @TableName = N'ssd_early_help_episodes';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_early_help_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_early_help_episodes;
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;


-- Create structure
CREATE TABLE ssd_development.ssd_early_help_episodes (
    earl_episode_id             NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EARL001A"}
    earl_person_id              NVARCHAR(48),               -- metadata={"item_ref":"EARL002A"}
    earl_episode_start_date     DATETIME,                   -- metadata={"item_ref":"EARL003A"}
    earl_episode_end_date       DATETIME,                   -- metadata={"item_ref":"EARL004A"}
    earl_episode_reason         NVARCHAR(MAX),              -- metadata={"item_ref":"EARL005A"}
    earl_episode_end_reason     NVARCHAR(MAX),              -- metadata={"item_ref":"EARL006A"}
    earl_episode_organisation   NVARCHAR(MAX),              -- metadata={"item_ref":"EARL007A"}
    earl_episode_worker_id      NVARCHAR(100)               -- metadata={"item_ref":"EARL008A", "item_status": "A", "info":"Consider for removal"}
);
 
 
-- Insert data
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
    Child_Social.FACT_CAF_EPISODE AS cafe
 
WHERE EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = cafe.DIM_PERSON_ID -- #DtoI-1799
    );


IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
    FOREIGN KEY (earl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_early_help_episodes_person_id ON ssd_development.ssd_early_help_episodes(earl_person_id);
    CREATE NONCLUSTERED INDEX idx_early_help_start_date             ON ssd_development.ssd_early_help_episodes(earl_episode_start_date);
    CREATE NONCLUSTERED INDEX idx_early_help_end_date               ON ssd_development.ssd_early_help_episodes(earl_episode_end_date);
END




-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;



/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Version: 1.3
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
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_episodes';



-- Check if exists & drop
IF OBJECT_ID('ssd_development.ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_cin_episodes;
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- Create structure
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                NVARCHAR(48) PRIMARY KEY NOT NULL,-- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(4000),  -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team              NVARCHAR(255),  -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
);
 
-- Insert data
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
SELECT
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
    fr.DIM_LOOKUP_CONT_SORC_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC,
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
    fr.DIM_DEPARTMENT_ID_DESC,
    fr.DIM_WORKER_ID_DESC
FROM
    Child_Social.FACT_REFERRALS AS fr
 
WHERE
    fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())    
    OR fr.REFRL_END_DTTM IS NULL

AND
    DIM_PERSON_ID <> -1  -- Exclude rows with -1

AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fr.DIM_PERSON_ID -- #DtoI-1799
    );

    
IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
    FOREIGN KEY (cine_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_cin_episodes_person_id    ON ssd_development.ssd_cin_episodes(cine_person_id);
    CREATE NONCLUSTERED INDEX idx_cin_referral_date             ON ssd_development.ssd_cin_episodes(cine_referral_date);
    CREATE NONCLUSTERED INDEX idx_cin_close_date                ON ssd_development.ssd_cin_episodes(cine_close_date);
END



-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;





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
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_assessments';



-- Check if exists, & drop 
IF OBJECT_ID('ssd_development.ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_development.ssd_cin_assessments;
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;


-- Create structure
CREATE TABLE ssd_development.ssd_cin_assessments
(
    cina_assessment_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINA001A"}
    cina_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
    cina_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
    cina_assessment_start_date      DATETIME,                   -- metadata={"item_ref":"CINA003A"}
    cina_assessment_child_seen      NCHAR(1),                   -- metadata={"item_ref":"CINA004A"}
    cina_assessment_auth_date       DATETIME,                   -- metadata={"item_ref":"CINA005A"}             
    cina_assessment_outcome_json    NVARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
    cina_assessment_outcome_nfa     NCHAR(1),                   -- metadata={"item_ref":"CINA009A"}
    cina_assessment_team            NVARCHAR(255),              -- metadata={"item_ref":"CINA007A"}
    cina_assessment_worker_id       NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
);

-- CTE for the EXISTS
WITH RelevantPersons AS (
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
    FROM Child_Social.FACT_FORM_ANSWERS ffa
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
 
-- Insert data
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
    fa.OUTCOME_NFA_FLAG                                         AS cina_assessment_outcome_nfa,
    fa.COMPLETED_BY_DEPT_ID                                     AS cina_assessment_team,        -- fa.COMPLETED_BY_DEPT_NAME also available
    fa.COMPLETED_BY_USER_STAFF_ID                               AS cina_assessment_worker_id    -- fa.COMPLETED_BY_USER_NAME also available
 
FROM
    Child_Social.FACT_SINGLE_ASSESSMENT fa
 
LEFT JOIN
    -- access pre-processed data in CTE
    AggregatedFormAnswers afa ON fa.FACT_FORM_ID = afa.FACT_FORM_ID
 
WHERE fa.DIM_LOOKUP_STEP_SUBSTATUS_CODE NOT IN ('X','D')        --Excludes draft and cancelled assessments
 
AND EXISTS (
    -- access pre-processed data in CTE
    SELECT 1
    FROM RelevantPersons p
    WHERE CAST(p.pers_person_id AS INT) = fa.DIM_PERSON_ID -- #DtoI-1799
);

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
    FOREIGN KEY (cina_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)
    CREATE NONCLUSTERED INDEX idx_ssd_cin_assessments_person_id ON ssd_development.ssd_cin_assessments(cina_person_id);
    CREATE NONCLUSTERED INDEX idx_cina_assessment_start_date    ON ssd_development.ssd_cin_assessments(cina_assessment_start_date);
    CREATE NONCLUSTERED INDEX idx_cina_assessment_auth_date     ON ssd_development.ssd_cin_assessments(cina_assessment_auth_date);
    CREATE NONCLUSTERED INDEX idx_cina_referral_id              ON ssd_development.ssd_cin_assessments(cina_referral_id);
END




-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;




/* 
=============================================================================
Object Name: ssd_send
Description: 
Author: D2I
Version: 1.0
            0.1: upn _unknown size change in line with DfE to 4 160524 RH
Status: [P]laceholder
Remarks: 
Dependencies: 
- FACT_903_DATA
- ssd_person
- Education.DIM_PERSON
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_send';




-- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_send') IS NOT NULL DROP TABLE ssd_development.ssd_send;
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL DROP TABLE #ssd_send;

-- Create structure 
CREATE TABLE ssd_development.ssd_send (
    send_table_id       NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SEND001A"}
    send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
    send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
    send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
    send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );

-- Insert data for link_identifier_type "FORMER_UPN"
INSERT INTO ssd_development.ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    send_upn_unknown
)
SELECT
    NEWID() AS send_table_id,          -- generate unique id
    cs.dim_person_id AS send_person_id,
    cs.upn AS send_upn,
    ed.uln AS send_uln,                
    'SSD_PH' AS send_upn_unknown      
FROM
    HDM_Local.Child_Social.dim_person cs
LEFT JOIN
    -- we have to switch to Education schema in order to obtain this
    HDM_Local.Education.dim_person ed ON cs.dim_person_id = ed.dim_person_id
WHERE
    EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person sp
        WHERE sp.pers_person_id = cs.dim_person_id
    );
 
 
IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s) -- #DtoI-1769
    ALTER TABLE ssd_development.ssd_send ADD CONSTRAINT FK_send_to_person 
    FOREIGN KEY (send_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

    -- Create index(es)

END


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;




/* 
=============================================================================
Object Name: ssd_ehcp_active_plans
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
-- [TESTING] Create marker
SET @TableName = N'ssd_ehcp_active_plans';



-- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_active_plans  ;
IF OBJECT_ID('tempdb..#ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

-- Create structure
CREATE TABLE ssd_development.ssd_ehcp_active_plans (
    ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCP001A"}
    ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
    ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
);

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    PRINT ''
    -- Add constraint(s)
    -- Applied post-object creation/end of extract 

    -- Create index(es)

END


-- -- Insert placeholder data
-- INSERT INTO ssd_development.ssd_ehcp_active_plans (ehcp_active_ehcp_id, ehcp_ehcp_request_id, ehcp_active_ehcp_last_review_date)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01');


-- [TESTING] Table added
PRINT 'Table created: ' + @TableName;




/* End

        Non-Core Liquid Logic elements extracts 
        
        */



-- output for ref most recent/current ssd version and last update
SELECT * FROM ssd_development.ssd_version_log WHERE is_current = 1;



/* ********************************************************************************************************** */
/* Development clean up */

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */


/* Start

        SSD Object Contraints

        */

IF @Run_SSD_As_Temporary_Tables = 0
BEGIN
    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
    FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_development.ssd_ehcp_active_plans(ehcp_active_ehcp_id);

    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
    FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
    FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_development.ssd_ehcp_assessment(ehca_ehcp_assessment_id);

    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
    FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

    -- Add constraint(s)
    ALTER TABLE ssd_development.ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
    FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_development.ssd_send(send_table_id);
END



/* Start

        SSD Extract Logging
        */


-- Check if exists, & drop
IF OBJECT_ID('ssd_development.ssd_extract_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_extract_log;
IF OBJECT_ID('tempdb..#ssd_extract_log', 'U') IS NOT NULL DROP TABLE #ssd_extract_log;

-- Create logging structure
CREATE TABLE ssd_development.ssd_extract_log (
    table_name           NVARCHAR(255),
    schema_name          NVARCHAR(255),
    status               NVARCHAR(50), -- status code includes error output + schema.table_name
    rows_inserted        INT,
    table_size_kb        INT,
    has_pk      BIT,
    has_fks     BIT,
    index_count          INT,
    creation_date        DATETIME DEFAULT GETDATE(),
    null_count           INT,          -- New: count of null values for each table
    pk_datatype          NVARCHAR(255),-- New: datatype of the PK field
    additional_detail    NVARCHAR(MAX), -- on hold|future use, e.g. data quality issues detected
    error_message        NVARCHAR(MAX)  -- on hold|future use, e.g. errors encountered during the process
);

-- GO

-- Ensure all variables are declared correctly
-- Note that if running in #tempdb/non-persistent tables some of the below are not picked up
DECLARE @row_count          INT;
DECLARE @table_size_kb      INT;                --                                          -- not for #tempdb/non-persistent
DECLARE @has_pk             BIT;                -- 1|0 flag                                 -- not for #tempdb/non-persistent
DECLARE @has_fks            BIT;                -- 1|0 flag                                 -- not for #tempdb/non-persistent
DECLARE @index_count        INT;                -- count                                    -- not for #tempdb/non-persistent
DECLARE @null_count         INT;                -- count of null values                     -- not for #tempdb/non-persistent
DECLARE @pk_datatype        NVARCHAR(255);      -- New: datatype of the PK field            -- not for #tempdb/non-persistent
DECLARE @additional_detail  NVARCHAR(MAX);
DECLARE @error_message      NVARCHAR(MAX);
DECLARE @table_name         NVARCHAR(255);
DECLARE @schema_name        NVARCHAR(255) = N'ssd_development'; -- Placeholder schema name for all tables

-- Placeholder for table_cursor selection logic
-- tables in the order they were created. 
DECLARE table_cursor CURSOR FOR
SELECT 'ssd_version_log'             UNION ALL -- Admin table, not SSD
SELECT 'ssd_person'                  UNION ALL
SELECT 'ssd_family'                  UNION ALL
SELECT 'ssd_address'                 UNION ALL
SELECT 'ssd_disability'              UNION ALL
SELECT 'ssd_immigration_status'      UNION ALL
SELECT 'ssd_mother'                  UNION ALL
SELECT 'ssd_legal_status'            UNION ALL
SELECT 'ssd_contacts'                 UNION ALL
SELECT 'ssd_early_help_episodes'     UNION ALL
SELECT 'ssd_cin_episodes'            UNION ALL
SELECT 'ssd_cin_assessments'         UNION ALL
SELECT 'ssd_assessment_factors'      UNION ALL
SELECT 'ssd_cin_plans'               UNION ALL
SELECT 'ssd_cin_visits'              UNION ALL
SELECT 'ssd_s47_enquiry'             UNION ALL
SELECT 'ssd_initial_cp_conference'   UNION ALL
SELECT 'ssd_cp_plans'                UNION ALL
SELECT 'ssd_cp_visits'               UNION ALL
SELECT 'ssd_cp_reviews'              UNION ALL
SELECT 'ssd_cla_episodes'            UNION ALL
SELECT 'ssd_cla_convictions'         UNION ALL
SELECT 'ssd_cla_health'              UNION ALL
SELECT 'ssd_cla_immunisations'       UNION ALL
SELECT 'ssd_cla_substance_misuse'    UNION ALL
SELECT 'ssd_cla_placement'           UNION ALL
SELECT 'ssd_cla_reviews'             UNION ALL
SELECT 'ssd_cla_previous_permanence' UNION ALL
SELECT 'ssd_cla_care_plan'           UNION ALL
SELECT 'ssd_cla_visits'              UNION ALL
SELECT 'ssd_sdq_scores'              UNION ALL
SELECT 'ssd_missing'                 UNION ALL
SELECT 'ssd_care_leavers'            UNION ALL
SELECT 'ssd_permanence'              UNION ALL
SELECT 'ssd_professionals'           UNION ALL
SELECT 'ssd_department'              UNION ALL
SELECT 'ssd_involvements'            UNION ALL
SELECT 'ssd_linked_identifiers'      UNION ALL
SELECT 'ssd_s251_finance'            UNION ALL
SELECT 'ssd_voice_of_child'          UNION ALL
SELECT 'ssd_pre_proceedings'         UNION ALL
SELECT 'ssd_send'                    UNION ALL
SELECT 'ssd_sen_need'                UNION ALL
SELECT 'ssd_ehcp_requests'           UNION ALL
SELECT 'ssd_ehcp_assessment'         UNION ALL
SELECT 'ssd_ehcp_named_plan'         UNION ALL
SELECT 'ssd_ehcp_active_plans';

OPEN table_cursor;

-- next table name from above list
FETCH NEXT FROM table_cursor INTO @table_name;

-- iterate table names listed above
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- Get row count
        SET @sql = N'SELECT @row_count = COUNT(*) FROM ' + @schema_name + '.' + @table_name;
        EXEC sp_executesql @sql, N'@row_count INT OUTPUT', @row_count OUTPUT;
        --

        -- Get table size in KB
        SET @sql = N'SELECT @table_size_kb = SUM(reserved_page_count) * 8 FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID(''' + @schema_name + '.' + @table_name + ''')';
        EXEC sp_executesql @sql, N'@table_size_kb INT OUTPUT', @table_size_kb OUTPUT;
        --

        -- Check for primary key
        SET @sql = N'
            SELECT @has_pk = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.indexes i
                WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(''' + @schema_name + '.' + @table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_pk BIT OUTPUT', @has_pk OUTPUT;
        --

        -- Check for foreign key(s)
        SET @sql = N'
            SELECT @has_fks = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.foreign_keys fk
                WHERE fk.parent_object_id = OBJECT_ID(''' + @schema_name + '.' + @table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_fks BIT OUTPUT', @has_fks OUTPUT;
        --

        -- Get index count
        SET @sql = N'
            SELECT @index_count = COUNT(*)
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(''' + @schema_name + '.' + @table_name + ''')';
        EXEC sp_executesql @sql, N'@index_count INT OUTPUT', @index_count OUTPUT;

        -- Get count of null values
        DECLARE @col NVARCHAR(255);
        DECLARE @total_nulls INT;
        SET @total_nulls = 0;

        DECLARE column_cursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = @schema_name AND TABLE_NAME = @table_name;

        OPEN column_cursor;
        FETCH NEXT FROM column_cursor INTO @col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'SELECT @total_nulls = @total_nulls + (SELECT COUNT(*) FROM ' + @schema_name + '.' + @table_name + ' WHERE ' + @col + ' IS NULL)';
            EXEC sp_executesql @sql, N'@total_nulls INT OUTPUT', @total_nulls OUTPUT;
            FETCH NEXT FROM column_cursor INTO @col;
        END
        CLOSE column_cursor;
        DEALLOCATE column_cursor;

        SET @null_count = @total_nulls;

        -- Get datatype of the primary key
        SET @sql = N'
            SELECT TOP 1 @pk_datatype = c.DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS c
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON c.COLUMN_NAME = kcu.COLUMN_NAME AND c.TABLE_NAME = kcu.TABLE_NAME AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
            JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
            WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
            AND kcu.TABLE_NAME = @table_name
            AND kcu.TABLE_SCHEMA = @schema_name';
        EXEC sp_executesql @sql, N'@pk_datatype NVARCHAR(255) OUTPUT, @table_name NVARCHAR(255), @schema_name NVARCHAR(255)', @pk_datatype OUTPUT, @table_name, @schema_name;
        --

        -- Insert log entry 
        INSERT INTO ssd_development.ssd_extract_log (
            table_name, 
            schema_name, 
            status, 
            rows_inserted, 
            table_size_kb, 
            has_pk, 
            has_fks, 
            index_count, 
            null_count, 
            pk_datatype, 
            additional_detail
            )
        VALUES (@table_name, @schema_name, 'Success', @row_count, @table_size_kb, @has_pk, @has_fks, @index_count, @null_count, @pk_datatype, NULL);
    END TRY
    BEGIN CATCH
        -- Log error 
        SET @error_message = ERROR_MESSAGE();
        INSERT INTO ssd_development.ssd_extract_log (
            table_name, 
            schema_name, 
            status, 
            rows_inserted, 
            table_size_kb, 
            has_pk, 
            has_fks, 
            index_count, 
            null_count, 
            pk_datatype, 
            additional_detail, 
            error_message
            )
        VALUES (@table_name, @schema_name, 'Error', 0, NULL, 0, 0, 0, 0, NULL, NULL, @error_message);
    END CATCH;

    -- Fetch next table name
    FETCH NEXT FROM table_cursor INTO @table_name;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

SET @sql = N'';


-- Forming part of the extract admin results output
SELECT * FROM ssd_development.ssd_extract_log ORDER BY rows_inserted DESC;


