IF OBJECT_ID(N'proc_ssd_linked_identifiers', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_linked_identifiers AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_linked_identifiers
    @src_db sysname = NULL,
    @src_schema sysname = NULL,
    @ssd_timeframe_years int = NULL,
    @ssd_sub1_range_years int = NULL,
    @today_date date = NULL,
    @today_dt datetime = NULL,
    @ssd_window_start date = NULL,
    @ssd_window_end date = NULL,
    @CaseloadLastSept30th date = NULL,
    @CaseloadTimeframeStartDate date = NULL

AS
BEGIN
    SET NOCOUNT ON;
    -- normalise defaults if not provided
    IF @src_db IS NULL SET @src_db = DB_NAME();
    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();
    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;
    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;
    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());
    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);
    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;
    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);
    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE
        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;
    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE] 
--              Have temporarily disabled populating UPN & ULN as these access non-core
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

IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;


    -- keep existing rows in persistent identifiers table, no truncate, no drop
    -- This is the only SSD table that has manually updated user data - hence 
    -- generic drop|truncate process NOT applicable here. 

IF OBJECT_ID('ssd_linked_identifiers', 'U') IS NULL
BEGIN
    CREATE TABLE ssd_linked_identifiers (
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

-- link_identifier_type "FORMER_UPN"
INSERT INTO ssd_linked_identifiers (
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
        FROM ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );

-- Example entry 2

-- link_identifier_type "UPN"
INSERT INTO ssd_linked_identifiers (
    link_person_id, 
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date, 
    link_valid_to_date
)
SELECT
    csp.dim_person_id                   AS link_person_id,
    'Unique Pupil Number'               AS link_identifier_type,        -- [REVIEW]
    NULL                                AS link_identifier_value,       -- csp.upn [TESTING] Removed for compatibility [REVIEW]
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
        FROM ssd_person p
        WHERE p.pers_person_id = csp.dim_person_id
    );



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_ssd_link_to_person 
-- FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_link_person_id        ON ssd_linked_identifiers(link_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_link_valid_from_date  ON ssd_linked_identifiers(link_valid_from_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_link_valid_to_date    ON ssd_linked_identifiers(link_valid_to_date);







/* END SSD main extract */
/* ********************************************************************************************************** */





/* Start 

         SSDF Other DfE projects (e.g. 1b, 2(a,b) elements extracts 
        
        */

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
