IF OBJECT_ID(N'proc_ssd_version_log', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_version_log AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_version_log
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: SSD extract metadata enabling version consistency across LAs. 
-- Dependencies: 
-- - None
-- =============================================================================

IF OBJECT_ID(''ssd_version_log'', ''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_version_log)
        TRUNCATE TABLE ssd_version_log;
END
ELSE
BEGIN

    -- create versioning information object
    CREATE TABLE ssd_version_log (
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
UPDATE ssd_version_log SET is_current = 0 WHERE is_current = 1;

INSERT INTO ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    -- CURRENT version (using MAJOR.MINOR.PATCH)
    (''1.3.7'', ''2025-12-03'', ''date fix on ssd_person'', 1, ''admin'', ''apply @ssd_window_start as core ssd_person timeframe anchor'');


-- HISTORIC versioning log data
INSERT INTO ssd_version_log (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    (''1.0.0'', ''2023-01-01'', ''Initial alpha release (Phase 1 end)'', 0, ''admin'', ''''),
    (''1.1.1'', ''2024-06-26'', ''Minor updates with revised assessment_factors'', 0, ''admin'', ''Revised JSON Array structure implemented for CiN''),
    (''1.1.2'', ''2024-06-26'', ''ssd_version_log obj added and minor patch fixes'', 0, ''admin'', ''Provide mech for extract ver visibility''),
    (''1.1.3'', ''2024-06-27'', ''Revised filtering on ssd_person'', 0, ''admin'', ''Check IS_CLIENT flag first''),
    (''1.1.4'', ''2024-07-01'', ''ssd_department obj added'', 0, ''admin'', ''Increased seperation btw professionals and depts enabling history''),
    (''1.1.5'', ''2024-07-09'', ''ssd_person involvements history'', 0, ''admin'', ''Improved consistency on _json fields, clean-up involvements_history_json''),
    (''1.1.6'', ''2024-07-12'', ''FK fixes for #DtoI-1769'', 0, ''admin'', ''non-unique/FK issues addressed: #DtoI-1769, #DtoI-1601''),
    (''1.1.7'', ''2024-07-15'', ''Non-core ssd_person records added'', 0, ''admin'', ''Fix requ towards #DtoI-1802''),
    (''1.1.8'', ''2024-07-17'', ''admin table creation logging process defined'', 0, ''admin'', ''''),
    (''1.1.9'', ''2024-07-29'', ''Applied CAST(person_id) + minor fixes'', 0, ''admin'', ''impacts all tables using where exists''),
    (''1.2.0'', ''2024-08-13'', ''#DtoI-1762, #DtoI-1810, improved 0/-1 handling'', 0, ''admin'', ''impacts all _team fields, AAL7 outputs''),
    (''1.2.1'', ''2024-08-20'', ''#DtoI-1820, removed destructive pre-clean-up incl .dbo refs'', 0, ''admin'', ''priority patch fix''),
    (''1.2.2'', ''2024-11-06'', ''#DtoI-1826, META+YML restructure incl. remove opt blocks'', 0, ''admin'', ''feat/bespoke LA extracts''),
    (''1.2.3'', ''2024-11-20'', ''non-core ssd_flag field removal'', 0, ''admin'', ''no wider impact''),
    (''1.2.4'', ''2025-09-10'', ''legacy support for json fields #LEGACY-PRE2016 tags'', 0, ''admin'', ''all json field alternative sql''),
    (''1.2.6'', ''2025-09-10'', ''Disable FK definitions by default'', 0, ''admin'', ''improve deployment compatiblity''),
    (''1.2.7'', ''2025-09-10'', ''remove ssd_api_data_staging - now part of api release'', 0, ''admin'', ''patch fix''),
    (''1.2.8'', ''2025-09-13'', ''assessment_factors & cla_episodes refactor'', 0, ''admin'', ''early adopters suggested patch fix''),
    (''1.2.9'', ''2025-09-22'', ''assessment_factors refactor now with pre-aggr, fix pre-compile issue SQL <2016'', 0, ''admin'', ''improved run time perf, ease of opt A/B toggle''),
    (''1.3.0'', ''2025-09-24'', ''New ssd_cohort for cohort visibility/monitoring'', 0, ''admin'', ''provides breakdown of cohort origins - later use to ease current EXISTS backchecks on ssd_person''),
    (''1.3.1'', ''2025-10-03'', ''Coventry suggested on ssd_assessment_factors'', 0, ''admin'', ''adjmts provided by Coventry to provide more robust pulling of assessment factor data where filter might not align with prev-family assessments-''),
    (''1.3.2'', ''2025-11-10'', ''Block out string_agg on ssd_assessment_factors'', 0, ''admin'', ''fix needed to prevent legacy sql failing on string_agg in modern selection block''),
    (''1.3.3'', ''2025-11-13'', ''s-colon pre CTE bug fix'', 0, ''admin'', ''non-recognised s-colon pre CTEs + introduced commented hard filter on child ids for LA use''),
    (''1.3.4'', ''2025-11-20'', ''sdq scores history, score date and timeframe fix'', 0, ''admin'', ''patch missing sdq scores history, incorrect hard-coded sdq date field''),
    (''1.3.5'', ''2025-11-21'', ''new pre-computed window_start filter added'', 0, ''admin'', ''Initially applied to sdq scores as timeframe filter. Will be applied throughout''),
    (''1.3.6'', ''2025-12-03'', ''drop use of ssd_cutoff, correction in cohort verification'', 1, ''admin'', ''drop @ssd_cutoff, reuse @ssd_window_start as core timeframe anchor'');

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
