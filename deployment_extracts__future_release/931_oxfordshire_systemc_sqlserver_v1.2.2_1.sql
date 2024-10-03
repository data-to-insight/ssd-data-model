-- META-CONTAINER: {"type": "header", "name": "extract_settings"}
-- META-ELEMENT: {"type": "header"}



/*
*********************************************************************************************************
STANDARD SAFEGUARDING DATASET EXTRACT
https://data-to-insight.github.io/ssd-data-model/
We strongly recommend that initial pilot/trials of SSD scripts occur in a development|test environment.
The SQL script is non-destructive. SSD clean-up scripts are available seperately, these are destructive.
*********************************************************************************************************
*/


-- META-ELEMENT: {"type": "deployment_system"}
/*
Bespoke SSD extract script for Oxfordshire (931).
Expected deployment system: SystemC | SQLServer.
*********************************************************************************************************
*/


-- META-ELEMENT: {"type": "config_metadata"}
/*
Config metadata last updated on 2024-09-25 (version 1.0) by rharrison.
Change description: None
Project and submit change request link: https://data-to-insight.github.io/ssd-data-model
*********************************************************************************************************
*/
-- META-ELEMENT: {"type": "dev_set_up"}
GO 
SET NOCOUNT ON;

-- META-ELEMENT: {"type": "ssd_timeframe"}
DECLARE @ssd_timeframe_years INT = 5;
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



-- META-CONTAINER: {"type": "settings", "name": "testing"}
/* Towards simplistic TEST run outputs and logging  (to be removed from live v2+) */

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


-- META-ELEMENT: {"type": "create_table"}
-- create versioning information object
CREATE TABLE ssd_version_log (
    version_number      NVARCHAR(10) PRIMARY KEY,                   -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                  -- date of version release
    description         NVARCHAR(100),                  -- brief description of version
    is_current          BIT NOT NULL DEFAULT 0,         -- flag to indicate if this is the current version
    created_at          DATETIME DEFAULT GETDATE(),     -- timestamp when record was created
    created_by          NVARCHAR(10),                   -- which user created the record
    impact_description  NVARCHAR(255)                   -- additional notes on the impact of the release
); 



-- ensure any previous current-version flag is set to 0 (not current), before adding new current version
UPDATE ssd_version_log SET is_current = 0 WHERE is_current = 1;

-- META-ELEMENT: {"type": "insert_data"}
-- insert & update for CURRENT version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.2', GETDATE(), '#DtoI-1826, META+YML restructure incl. remove opt blocks', 1, 'admin', 'feat/bespoke LA extracts');


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
    ('1.2.0', '2024-08-13', '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', 0, 'admin', 'impacts all _team fields, AAL7 outputs'),
    ('1.2.1', '2024-08-20', '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', 0, 'admin', 'priority patch fix');

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


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_family (
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
    FROM ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID -- #DtoI-1799
    );



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_family ADD CONSTRAINT FK_ssd_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_family_person_id          ON ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_family(fami_family_id);




