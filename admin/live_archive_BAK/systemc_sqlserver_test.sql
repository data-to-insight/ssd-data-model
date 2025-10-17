
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

-- META-ELEMENT: {"type": "deployment_status_note"}
/*
******************************************
****************************************************************
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

-- META-ELEMENT: {"type": "dev_setup"}
GO 
SET NOCOUNT ON;

-- META-ELEMENT: {"type": "ssd_timeframe"}
DECLARE @ssd_timeframe_years INT = 6; -- ssd extract time-frame (YRS)
DECLARE @ssd_sub1_range_years INT = 1;

-- CASELOAD count Date (Currently: September 30th)
DECLARE @CaseloadLastSept30th DATE; 
SET @CaseloadLastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;


DECLARE @CaseloadTimeframeStartDate DATE = DATEADD(YEAR, -@ssd_timeframe_years, @CaseloadLastSept30th);
-- Example resultant dates into @CaseloadTimeframeStartDate
                                -- With 
                                -- @CaseloadLastSept30th = 30th September 2023
                                -- @CaseloadTimeframeStartDate = 30th September 2017




-- META-ELEMENT: {"type": "persistent_ssd"}
-- Run SSD into Temporary OR Persistent structure
-- 1==Single use SSD extract uses tempdb..# | 0==Persistent SSD table set up
-- This flag enables/disables running such as FK constraints that don't apply to tempdb..# implementation
DECLARE @Run_SSD_As_Temporary_Tables BIT;   
SET     @Run_SSD_As_Temporary_Tables = 0;   
                                            


-- META-ELEMENT: {"type": "dbschema"}
-- Point to DB/TABLE_CATALOG if required (SSD tables created here)
USE HDM_Local;                           -- used in logging (and seperate clean-up script(s))
DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- set your schema name here OR leave empty for default behaviour. Used towards ssd_extract_log
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder'; -- Note: also/seperately use of @table_name in non-test|live elements of script. 


-- META-ELEMENT: {"type": "settings"}
DECLARE @sql NVARCHAR(MAX) = N''; 

/* ********************************************************************************************************** */
-- META-CONTAINER: {"type": "settings", "name": "testing"}
/* Towards simplistic TEST run outputs and logging  (to be removed from live v2+) */

-- META-ELEMENT: {"type": "test"}
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Script start time





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
IF OBJECT_ID('ssd_development.ssd_version_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_version_log;
IF OBJECT_ID('tempdb..#ssd_version_log', 'U') IS NOT NULL DROP TABLE #ssd_version_log;

-- META-ELEMENT: {"type": "create_table"}
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

-- META-ELEMENT: {"type": "insert_data"}
-- insert & update for CURRENT version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_development.ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.1', GETDATE(), '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', 1, 'admin', 'priority patch fix');


-- HISTORIC versioning log data
INSERT INTO ssd_version_log (version_number, release_date, description, is_current, created_by, impact_description)
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
    ('1.2.0', '2024-08-13', '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', 0, 'admin', 'impacts all _team fields, AAL7 outputs');


-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;




/* ********************************************************************************************************** */
/* START SSD main extract */



-- META-CONTAINER: {"type": "table", "name": "ssd_family"}
-- =============================================================================
-- Description: Contains the family connections for each person
-- Author: D2I
-- Version: 1.0
-- Status: [R]elease
-- Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
-- Dependencies: 
-- - FACT_CONTACTS
-- - ssd_person
-- =============================================================================


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_family';


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
SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM HDM.Child_Social.FACT_CONTACTS AS fc
WHERE EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );



-- META-ELEMENT: {"type": "create_pk"}
ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT PK_ssd_family PRIMARY KEY (fami_table_id);

-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT TEST_FK_ssd_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_family_person_id          ON ssd_development.ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);




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
-- Dependencies: 
-- - ssd_person
-- - DIM_PERSON_ADDRESS
-- =============================================================================


-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_address';


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

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID -- #DtoI-1799
    );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_address ADD CONSTRAINT FK_ssd_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_address_person        ON ssd_development.ssd_address(addr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_address_start         ON ssd_development.ssd_address(addr_address_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_address_end           ON ssd_development.ssd_address(addr_address_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_ssd_address_postcode  ON ssd_development.ssd_address(addr_address_postcode);



-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END




-- META-ELEMENT: {"type": "console_output"} 
-- output for ref most recent/current ssd version and last update
SELECT * FROM ssd_development.ssd_version_log WHERE is_current = 1;



-- META-ELEMENT: {"type": "test"} -- Get & print run time 
/* ********************************************************************************************************** */
/* Development clean up */

SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */


/* Start

        SSD Object Constraints

        */



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_development.ssd_ehcp_active_plans(ehcp_active_ehcp_id);

ALTER TABLE ssd_development.ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

ALTER TABLE ssd_development.ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_development.ssd_ehcp_assessment(ehca_ehcp_assessment_id);

ALTER TABLE ssd_development.ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

ALTER TABLE ssd_development.ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_development.ssd_send(send_table_id);



/* Start

        SSD Extract Logging
        */


-- META-CONTAINER: {"type": "table", "name": "ssd_extract_log"}
-- =============================================================================
-- Description: Enable LA extract overview logging
-- Author: D2I
-- Version: 0.1
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - 
-- =============================================================================



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_extract_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_extract_log;
IF OBJECT_ID('tempdb..#ssd_extract_log', 'U') IS NOT NULL DROP TABLE #ssd_extract_log;

-- META-ELEMENT: {"type": "create_table"}
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


-- META-ELEMENT: {"type": "insert_data"} 
-- GO
-- Ensure all variables are declared correctly
DECLARE @row_count          INT;
DECLARE @table_size_kb      INT;
DECLARE @has_pk             BIT;
DECLARE @has_fks            BIT;
DECLARE @index_count        INT;
DECLARE @null_count         INT;
DECLARE @pk_datatype        NVARCHAR(255);
DECLARE @additional_detail  NVARCHAR(MAX);
DECLARE @error_message      NVARCHAR(MAX);
DECLARE @table_name         NVARCHAR(255);
-- DECLARE @schema_name        NVARCHAR(255) = N'';                 -- Placeholder  schema name for all tables <OR> empty string



-- Placeholder for table_cursor selection logic
DECLARE table_cursor CURSOR FOR
SELECT 'ssd_development.ssd_version_log'             UNION ALL -- Admin table, not SSD
SELECT 'ssd_development.ssd_person'                  UNION ALL
SELECT 'ssd_development.ssd_family'                  UNION ALL
SELECT 'ssd_development.ssd_address'                 UNION ALL
SELECT 'ssd_development.ssd_disability'              UNION ALL
SELECT 'ssd_development.ssd_immigration_status'      UNION ALL
SELECT 'ssd_development.ssd_mother'                  UNION ALL
SELECT 'ssd_development.ssd_legal_status'            UNION ALL
SELECT 'ssd_development.ssd_contacts'                UNION ALL
SELECT 'ssd_development.ssd_early_help_episodes'     UNION ALL
SELECT 'ssd_development.ssd_cin_episodes'            UNION ALL
SELECT 'ssd_development.ssd_cin_assessments'         UNION ALL
SELECT 'ssd_development.ssd_assessment_factors'      UNION ALL
SELECT 'ssd_development.ssd_cin_plans'               UNION ALL
SELECT 'ssd_development.ssd_cin_visits'              UNION ALL
SELECT 'ssd_development.ssd_s47_enquiry'             UNION ALL
SELECT 'ssd_development.ssd_initial_cp_conference'   UNION ALL
SELECT 'ssd_development.ssd_cp_plans'                UNION ALL
SELECT 'ssd_development.ssd_cp_visits'               UNION ALL
SELECT 'ssd_development.ssd_cp_reviews'              UNION ALL
SELECT 'ssd_development.ssd_cla_episodes'            UNION ALL
SELECT 'ssd_development.ssd_cla_convictions'         UNION ALL
SELECT 'ssd_development.ssd_cla_health'              UNION ALL
SELECT 'ssd_development.ssd_cla_immunisations'       UNION ALL
SELECT 'ssd_development.ssd_cla_substance_misuse'    UNION ALL
SELECT 'ssd_development.ssd_cla_placement'           UNION ALL
SELECT 'ssd_development.ssd_cla_reviews'             UNION ALL
SELECT 'ssd_development.ssd_cla_previous_permanence' UNION ALL
SELECT 'ssd_development.ssd_cla_care_plan'           UNION ALL
SELECT 'ssd_development.ssd_cla_visits'              UNION ALL
SELECT 'ssd_development.ssd_sdq_scores'              UNION ALL
SELECT 'ssd_development.ssd_missing'                 UNION ALL
SELECT 'ssd_development.ssd_care_leavers'            UNION ALL
SELECT 'ssd_development.ssd_permanence'              UNION ALL
SELECT 'ssd_development.ssd_professionals'           UNION ALL
SELECT 'ssd_development.ssd_department'              UNION ALL
SELECT 'ssd_development.ssd_involvements'            UNION ALL
SELECT 'ssd_development.ssd_linked_identifiers'      UNION ALL
SELECT 'ssd_development.ssd_s251_finance'            UNION ALL
SELECT 'ssd_development.ssd_voice_of_child'          UNION ALL
SELECT 'ssd_development.ssd_pre_proceedings'         UNION ALL
SELECT 'ssd_development.ssd_send'                    UNION ALL
SELECT 'ssd_development.ssd_sen_need'                UNION ALL
SELECT 'ssd_development.ssd_ehcp_requests'           UNION ALL
SELECT 'ssd_development.ssd_ehcp_assessment'         UNION ALL
SELECT 'ssd_development.ssd_ehcp_named_plan'         UNION ALL
SELECT 'ssd_development.ssd_ehcp_active_plans';

-- Define placeholder tables
DECLARE @ssd_placeholder_tables TABLE (table_name NVARCHAR(255));
INSERT INTO @ssd_placeholder_tables (table_name)
VALUES
    ('ssd_development.ssd_send'),
    ('ssd_development.ssd_sen_need'),
    ('ssd_development.ssd_ehcp_requests'),
    ('ssd_development.ssd_ehcp_assessment'),
    ('ssd_development.ssd_ehcp_named_plan'),
    ('ssd_development.ssd_ehcp_active_plans');

DECLARE @dfe_project_placeholder_tables TABLE (table_name NVARCHAR(255));
INSERT INTO @dfe_project_placeholder_tables (table_name)
VALUES
    ('ssd_development.ssd_s251_finance'),
    ('ssd_development.ssd_voice_of_child'),
    ('ssd_development.ssd_pre_proceedings');

-- Open table cursor
OPEN table_cursor;

-- Fetch next table name from the list
FETCH NEXT FROM table_cursor INTO @table_name;

-- Iterate table names listed above
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- Generate the schema-qualified table name
        DECLARE @full_table_name NVARCHAR(511);
        SET @full_table_name = CASE WHEN @schema_name = '' THEN @table_name ELSE @schema_name + '.' + @table_name END;

        -- Check if table exists
        SET @sql = N'SELECT @table_exists = COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name';
        DECLARE @table_exists INT;
        EXEC sp_executesql @sql, N'@table_exists INT OUTPUT, @schema_name NVARCHAR(255), @table_name NVARCHAR(255)', @table_exists OUTPUT, @schema_name, @table_name;

        IF @table_exists = 0
        BEGIN
            THROW 50001, 'Table does not exist', 1;
        END
        
        -- get row count
        SET @sql = N'SELECT @row_count = COUNT(*) FROM ' + @full_table_name;
        EXEC sp_executesql @sql, N'@row_count INT OUTPUT', @row_count OUTPUT;

        -- get table size in KB
        SET @sql = N'SELECT @table_size_kb = SUM(reserved_page_count) * 8 FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
        EXEC sp_executesql @sql, N'@table_size_kb INT OUTPUT', @table_size_kb OUTPUT;

        -- check for primary key (flag field)
        SET @sql = N'
            SELECT @has_pk = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.indexes i
                WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(''' + @full_table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_pk BIT OUTPUT', @has_pk OUTPUT;

        -- check for foreign key(s) (flag field)
        SET @sql = N'
            SELECT @has_fks = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.foreign_keys fk
                WHERE fk.parent_object_id = OBJECT_ID(''' + @full_table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_fks BIT OUTPUT', @has_fks OUTPUT;

        -- count index(es)
        SET @sql = N'
            SELECT @index_count = COUNT(*)
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
        EXEC sp_executesql @sql, N'@index_count INT OUTPUT', @index_count OUTPUT;

        -- Get null values count (~overview of data sparcity)
        DECLARE @col NVARCHAR(255);
        DECLARE @total_nulls INT;
        SET @total_nulls = 0;

        DECLARE column_cursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name;

        OPEN column_cursor;
        FETCH NEXT FROM column_cursor INTO @col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'SELECT @total_nulls = @total_nulls + (SELECT COUNT(*) FROM ' + @full_table_name + ' WHERE ' + @col + ' IS NULL)';
            EXEC sp_executesql @sql, N'@total_nulls INT OUTPUT', @total_nulls OUTPUT;
            FETCH NEXT FROM column_cursor INTO @col;
        END
        CLOSE column_cursor;
        DEALLOCATE column_cursor;

        SET @null_count = @total_nulls;

        -- get datatype of the primary key
        SET @sql = N'
            SELECT TOP 1 @pk_datatype = c.DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS c
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON c.COLUMN_NAME = kcu.COLUMN_NAME AND c.TABLE_NAME = kcu.TABLE_NAME AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
            JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
            WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
            AND kcu.TABLE_NAME = @table_name
            AND kcu.TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END';
        EXEC sp_executesql @sql, N'@pk_datatype NVARCHAR(255) OUTPUT, @table_name NVARCHAR(255), @schema_name NVARCHAR(255)', @pk_datatype OUTPUT, @table_name, @schema_name;

        -- set additional_detail comment to make sense|add detail to expected 
        -- empty/placholder tables incl. future DfE projects
        SET @additional_detail = NULL;

        IF EXISTS (SELECT 1 FROM @ssd_placeholder_tables WHERE table_name = @table_name)
        BEGIN
            SET @additional_detail = 'ssd placeholder table';
        END
        ELSE IF EXISTS (SELECT 1 FROM @dfe_project_placeholder_tables WHERE table_name = @table_name)
        BEGIN
            SET @additional_detail = 'DfE project placeholder table';
        END

        -- insert log entry 
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
        VALUES (@table_name, @schema_name, 'Success', @row_count, @table_size_kb, @has_pk, @has_fks, @index_count, @null_count, @pk_datatype, @additional_detail);
    END TRY
    BEGIN CATCH
        -- log any error (this only an indicator of possible issue)
        -- tricky 
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
        VALUES (@table_name, @schema_name, 'Error', 0, NULL, 0, 0, 0, 0, NULL, @additional_detail, @error_message);
    END CATCH;

    -- Fetch next table name
    FETCH NEXT FROM table_cursor INTO @table_name;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

SET @sql = N'';


-- META-ELEMENT: {"type": "console_output"}
-- Forming part of the extract admin results output
SELECT * FROM ssd_development.ssd_extract_log ORDER BY rows_inserted DESC;





/* Start

        Non-SDD Bespoke extract mods
        
        Examples of how to build on the ssd with bespoke additional fields. These can be 
        refreshed|incl. within the rebuild script and rebuilt at the same time as the SSD
        Changes should be limited to additional, non-destructive enhancements that do not
        alter the core structure of the SSD. 
        */




-- META-CONTAINER: {"type": "ssd_non_core_modification", "name": "involvements_history"}
-- =============================================================================
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
-- - FACT_INVOLVEMENTS
-- - ssd_person
-- =============================================================================

-- -- META-ELEMENT: {"type": "test"}
-- SET @TableName = N' Involvement History';
-- PRINT 'Adding MOD: ' + @TableName;


-- META-ELEMENT: {"type": "insert_data"} 
-- ALTER TABLE ssd_development.ssd_person
-- ADD pers_involvement_history_json NVARCHAR(max),  -- Adjust data type as needed
--     pers_involvement_type_story NVARCHAR(1000);   -- Adjust data type as needed

-- GO -- ensure new cols ALTER TABLE completed prior to onward processing
-- -- All variables now reset, will require redeclaring if testing below in isolation

-- -- CTE for involvement history incl. worker data
-- WITH InvolvementHistoryCTE AS (
--     SELECT 
--         fi.DIM_PERSON_ID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.DIM_WORKER_ID END)                          AS CurrentWorkerID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END)    AS AllocatedTeam,
--         MAX(CASE WHEN fi.RecentInvolvement = '16PLUS'   THEN fi.DIM_WORKER_ID END)                          AS PersonalAdvisorID,

--         JSON_QUERY((
--             -- structure of the main|complete invovements history json 
--             SELECT 
--                 ISNULL(fi2.FACT_INVOLVEMENTS_ID, '')              AS INVOLVEMENT_ID,
--                 ISNULL(fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '')  AS INVOLVEMENT_TYPE_CODE,
--                 ISNULL(fi2.START_DTTM, '')                        AS START_DATE, 
--                 ISNULL(fi2.END_DTTM, '')                          AS END_DATE, 
--                 ISNULL(fi2.DIM_WORKER_ID, '')                     AS WORKER_ID, 
--                 ISNULL(fi2.DIM_DEPARTMENT_ID, '')                 AS DEPARTMENT_ID
--             FROM 
--                 HDM.Child_Social.FACT_INVOLVEMENTS fi2
--             WHERE 
--                 fi2.DIM_PERSON_ID = fi.DIM_PERSON_ID

--             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--             -- rem WITHOUT_ARRAY_WRAPPER if restricting FULL contact history in _json (involvement_history_json)
--         )) AS involvement_history
--     FROM (

--         -- commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
--         SELECT *,
--             -- ROW_NUMBER() OVER (
--             --     PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
--             --     ORDER BY FACT_INVOLVEMENTS_ID DESC
--             -- ) AS rn,
--             -- only applied if the following fi.rn = 1 is uncommented

--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
--         FROM HDM.Child_Social.FACT_INVOLVEMENTS
--         WHERE 
--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
--             -- AND END_DTTM IS NULL -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
--             AND DIM_WORKER_ID IS NOT NULL       -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND DIM_WORKER_ID <> -1             -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
--                                                 -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
--     ) fi

-- WHERE 
--     -- -- Commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
--     -- fi.rn = 1
--     -- AND

--     EXISTS (    -- Remove filter IF wishing to extract records beyond scope of SSD timeframe
--         SELECT 1 FROM ssd_development.ssd_person p
--          WHERE CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799

--     )

--     GROUP BY 
--         fi.DIM_PERSON_ID
-- ),
-- -- CTE for involvement type story
-- InvolvementTypeStoryCTE AS (
--     SELECT 
--         fi.DIM_PERSON_ID,
--         STUFF((
--             -- Concat involvement type codes into string
--             -- cannot use STRING AGG as appears to not work (Needs v2017+)
--             SELECT CONCAT(',', '"', fi3.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '"')
--             FROM HDM.Child_Social.FACT_INVOLVEMENTS fi3
--             WHERE fi3.DIM_PERSON_ID = fi.DIM_PERSON_ID

--             AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
--                 SELECT 1 FROM ssd_development.ssd_person p
--              WHERE CAST(p.pers_person_id AS INT) = fi3.DIM_PERSON_ID -- #DtoI-1799

--             )

--             ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
--             FOR XML PATH('')
--         ), 1, 1, '') AS InvolvementTypeStory
--     FROM 
--         HDM.Child_Social.FACT_INVOLVEMENTS fi
    
--     WHERE 
--         EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
--             SELECT 1 FROM ssd_development.ssd_person p
--              WHERE CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799
             
--         )
--     GROUP BY 
--         fi.DIM_PERSON_ID
-- )


-- -- Update
-- UPDATE p
-- SET
--     p.pers_involvement_history_json = ih.involvement_history,
--     p.pers_involvement_type_story = CONCAT('[', its.InvolvementTypeStory, ']')
-- FROM ssd_development.ssd_person p
-- LEFT JOIN InvolvementHistoryCTE ih ON CAST(p.pers_person_id AS INT) = ih.DIM_PERSON_ID -- #DtoI-1799
-- LEFT JOIN InvolvementTypeStoryCTE its ON CAST(p.pers_person_id AS INT) = its.DIM_PERSON_ID; -- #DtoI-1799

