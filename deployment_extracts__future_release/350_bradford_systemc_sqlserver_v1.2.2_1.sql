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
Bespoke SSD extract script for Bradford (350).
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


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_version_log', 'U') IS NOT NULL DROP TABLE ssd_version_log;
IF OBJECT_ID('tempdb..#ssd_version_log', 'U') IS NOT NULL DROP TABLE #ssd_version_log;

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


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_family') IS NOT NULL DROP TABLE ssd_family;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);


