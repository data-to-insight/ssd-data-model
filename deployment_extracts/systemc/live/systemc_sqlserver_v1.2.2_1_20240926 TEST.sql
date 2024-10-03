
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
-- Optional notes from la config file 

-- META-ELEMENT: {"type": "dev_set_up"}
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



-- META-ELEMENT: {"type": "dbschema"}
-- Point to DB/TABLE_CATALOG if required (SSD tables created here)
USE HDM_Local;                           -- used in logging (and seperate clean-up script(s))
DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- set your schema name here OR leave empty for default behaviour. Used towards ssd_extract_log
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
IF OBJECT_ID('ssd_development.ssd_version_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_version_log;
IF OBJECT_ID('tempdb..#ssd_version_log', 'U') IS NOT NULL DROP TABLE #ssd_version_log;

-- META-ELEMENT: {"type": "create_table"}
-- create versioning information object
CREATE TABLE ssd_development.ssd_version_log (
    version_number      NVARCHAR(10) PRIMARY KEY,                   -- version num (e.g., "1.0.0")
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
    ('1.2.2', GETDATE(), '#DtoI-1826, META+YML restructure incl. remove opt blocks', 1, 'admin', 'feat/bespoke LA extracts');


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
    ('1.2.1', '2024-08-20', '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', 0, 'admin', 'priority patch fix');

-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;


-- META-END



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
    fami_table_id   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"FAMI003A"} 
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



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT FK_ssd_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_family_person_id          ON ssd_development.ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);




-- META-ELEMENT: {"type": "test"}
PRINT 'Table created: ' + @TableName;

-- META-END

