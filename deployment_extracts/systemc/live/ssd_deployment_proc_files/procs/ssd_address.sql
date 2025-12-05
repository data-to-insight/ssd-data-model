IF OBJECT_ID(N'proc_ssd_address', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_address AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_address
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
-- Description: Contains full address details for every person 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]
--          Need to verify json obj structure on pre-2014 SQL server instances
--          Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.DIM_PERSON_ADDRESS
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_address', 'U') IS NOT NULL DROP TABLE #ssd_address;

IF OBJECT_ID('ssd_address','U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_address)
        TRUNCATE TABLE ssd_address;
END

ELSE
BEGIN
    CREATE TABLE ssd_address (
        addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
        addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
        addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
        addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
        addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
        addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
        addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
    );
END

INSERT INTO ssd_address (
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
    FROM ssd_person p
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
--     FROM ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = pa.DIM_PERSON_ID -- #DtoI-1799
--     );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_address ADD CONSTRAINT FK_ssd_address_person
-- FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_address_person        ON ssd_address(addr_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_address_start         ON ssd_address(addr_address_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_address_end           ON ssd_address(addr_address_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_ssd_address_postcode  ON ssd_address(addr_address_postcode);

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
