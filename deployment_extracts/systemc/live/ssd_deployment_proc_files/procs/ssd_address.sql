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


-- #LEGACY-PRE2016
-- SQL compatible versions <2016
;WITH Addresses AS
(
    SELECT
        pa.*,

        -- protected address is one marked as either:
        --   CONFIDENTIAL = 'Y'
        --   IS_RESTRICTED_FLAG = 'Y'
        --
        -- Protected addresses must not expose address detail
        -- postcode replaced with 'CON' and all address
        -- components in the JSON payload blanked out
        CASE
            WHEN UPPER(ISNULL(pa.CONFIDENTIAL, 'N')) = 'Y'
              OR UPPER(ISNULL(pa.IS_RESTRICTED_FLAG, 'N')) = 'Y'
            THEN 1
            ELSE 0
        END AS IsProtected,

        -- Postcode cleanse rules:
        --   * Protected addresses -> 'CON' 
        --   * All-X postcodes -> ''
        --   * 'nopostcode' -> ''
        --   * Otherwise retain trimmed postcode
        CASE
            WHEN UPPER(ISNULL(pa.CONFIDENTIAL, 'N')) = 'Y'
              OR UPPER(ISNULL(pa.IS_RESTRICTED_FLAG, 'N')) = 'Y'
                THEN 'CON' -- confidential/restricted mask
            WHEN REPLACE(pa.POSTCODE, ' ', '') =
                 REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', '')))
                THEN ''
            WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode'
                THEN ''
            ELSE LTRIM(RTRIM(pa.POSTCODE))
        END AS CleanedPostcode

    FROM HDM.Child_Social.DIM_PERSON_ADDRESS pa
)

INSERT INTO ssd_address
(
    addr_table_id,
    addr_person_id,
    addr_address_type,
    addr_address_start_date,
    addr_address_end_date,
    addr_address_postcode,
    addr_address_json
)

SELECT
    a.DIM_PERSON_ADDRESS_ID,
    a.DIM_PERSON_ID,
    a.ADDSS_TYPE_CODE,
    a.START_DTTM,
    a.END_DTTM,
    a.CleanedPostcode,

    CASE
        -- Protected addresses:
        -- retain address entry, but suppress ALL address detail.
        -- JSON structure retained but prevent disclosure of confidential address infos.
        WHEN a.IsProtected = 1
        THEN
            (
                '{' +
                '"ROOM": "", ' +
                '"FLOOR": "", ' +
                '"FLAT": "", ' +
                '"BUILDING": "", ' +
                '"HOUSE": "", ' +
                '"STREET": "", ' +
                '"TOWN": "", ' +
                '"UPRN": "", ' +
                '"EASTING": "", ' +
                '"NORTHING": "", ' +
                '"POSTCODE": "con"' +
                '}'
            )

        ELSE
        -- address/record is not confidential or restricted
            (
                '{' +
                '"ROOM": "' + ISNULL(TRY_CAST(a.ROOM_NO AS NVARCHAR(50)), '') + '", ' +
                '"FLOOR": "' + ISNULL(TRY_CAST(a.FLOOR_NO AS NVARCHAR(50)), '') + '", ' +
                '"FLAT": "' + ISNULL(TRY_CAST(a.FLAT_NO AS NVARCHAR(50)), '') + '", ' +
                '"BUILDING": "' + ISNULL(a.BUILDING, '') + '", ' +
                '"HOUSE": "' + ISNULL(TRY_CAST(a.HOUSE_NO AS NVARCHAR(50)), '') + '", ' +
                '"STREET": "' + ISNULL(a.STREET, '') + '", ' +
                '"TOWN": "' + ISNULL(a.TOWN, '') + '", ' +
                '"UPRN": "' + ISNULL(TRY_CAST(a.UPRN AS NVARCHAR(50)), '') + '", ' +
                '"EASTING": "' + ISNULL(TRY_CAST(a.EASTING AS NVARCHAR(20)), '') + '", ' +
                '"NORTHING": "' + ISNULL(TRY_CAST(a.NORTHING AS NVARCHAR(20)), '') + '", ' +
                '"POSTCODE": "' + ISNULL(a.CleanedPostcode, '') + '"' +
                '}'
            )
    END AS addr_address_json

FROM Addresses a

WHERE a.DIM_PERSON_ID <> -1
AND EXISTS
(
    SELECT 1
    FROM ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = a.DIM_PERSON_ID
);




-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
--
-- ;WITH Addresses AS
-- (
--     SELECT
--         pa.*,
--
--         -- protected address is one marked as either:
--         --   CONFIDENTIAL = 'Y'
--         --   IS_RESTRICTED_FLAG = 'Y'
--         --
--         -- Protected addresses must not expose address detail
--         -- postcode replaced with 'CON' and all address
--         -- components in the JSON payload blanked out
--         CASE
--             WHEN UPPER(ISNULL(pa.CONFIDENTIAL, 'N')) = 'Y'
--               OR UPPER(ISNULL(pa.IS_RESTRICTED_FLAG, 'N')) = 'Y'
--             THEN 1
--             ELSE 0
--         END AS IsProtected,
--
--         -- Postcode cleanse rules:
--         --   * Protected addresses -> 'CON'
--         --   * All-X postcodes -> ''
--         --   * 'nopostcode' -> ''
--         --   * Otherwise retain trimmed postcode
--         CASE
--             WHEN UPPER(ISNULL(pa.CONFIDENTIAL, 'N')) = 'Y'
--               OR UPPER(ISNULL(pa.IS_RESTRICTED_FLAG, 'N')) = 'Y'
--                 THEN 'CON'
--             WHEN REPLACE(pa.POSTCODE, ' ', '') =
--                  REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', '')))
--                 THEN ''
--             WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode'
--                 THEN ''
--             ELSE LTRIM(RTRIM(pa.POSTCODE))
--         END AS CleanedPostcode
--
--     FROM HDM.Child_Social.DIM_PERSON_ADDRESS pa
-- )
--
-- SELECT
--     a.DIM_PERSON_ADDRESS_ID,
--     a.DIM_PERSON_ID,
--     a.ADDSS_TYPE_CODE,
--     a.START_DTTM,
--     a.END_DTTM,
--     a.CleanedPostcode,
--
--     (
--         SELECT
--             -- Protected addresses:
--             -- retain address entry, but suppress ALL address detail.
--             -- JSON structure retained but prevent disclosure of confidential address infos.
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.ROOM_NO, '') END AS ROOM,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.FLOOR_NO, '') END AS FLOOR,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.FLAT_NO, '') END AS FLAT,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.BUILDING, '') END AS BUILDING,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.HOUSE_NO, '') END AS HOUSE,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.STREET, '') END AS STREET,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.TOWN, '') END AS TOWN,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.UPRN, '') END AS UPRN,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.EASTING, '') END AS EASTING,
--             CASE WHEN a.IsProtected = 1 THEN '' ELSE ISNULL(a.NORTHING, '') END AS NORTHING,
--             a.CleanedPostcode AS POSTCODE
--
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS addr_address_json
--
-- FROM Addresses a
--
-- WHERE a.DIM_PERSON_ID <> -1
-- AND EXISTS
-- (
--     SELECT 1
--     FROM ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = a.DIM_PERSON_ID -- #DtoI-1799
-- );


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
