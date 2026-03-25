-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_address', 'U') IS NOT NULL DROP TABLE #ssd_address;

IF OBJECT_ID('ssd_address', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_address)
        TRUNCATE TABLE ssd_address;
END
ELSE
BEGIN
    CREATE TABLE ssd_address (
        addr_table_id           NVARCHAR(48)  NOT NULL PRIMARY KEY,
        addr_person_id          NVARCHAR(48)  NULL,
        addr_address_type       NVARCHAR(48)  NULL,
        addr_address_start_date DATETIME      NULL,
        addr_address_end_date   DATETIME      NULL,
        addr_address_postcode   NVARCHAR(15)  NULL,
        addr_address_json       NVARCHAR(1000) NULL
    );
END;

INSERT INTO ssd_address (
    addr_table_id,
    addr_person_id,
    addr_address_type,
    addr_address_start_date,
    addr_address_end_date,
    addr_address_postcode,
    addr_address_json
)
SELECT
    CONVERT(NVARCHAR(48), PERSADDRESS.ADDRESSID) AS addr_table_id,
    CONVERT(NVARCHAR(48), PERSADDRESS.PERSONID)  AS addr_person_id,
    CONVERT(NVARCHAR(48), PERSADDRESS.TYPE)      AS addr_address_type,
    CONVERT(DATETIME, PERSADDRESS.STARTDATE)     AS addr_address_start_date,
    CONVERT(DATETIME, PERSADDRESS.ENDDATE)       AS addr_address_end_date,
    REPLACE(CONVERT(NVARCHAR(15), PERSADDRESS.POSTCODE), ' ', '') AS addr_address_postcode,
    CONVERT(NVARCHAR(1000),
        '{'
        + '"ROOM":"'     + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.ROOMDESCRIPTION), ''),  '\', '\\'), '"', '\"') + '",'
        + '"FLOOR":"'    + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.FLOORDESCRIPTION), ''), '\', '\\'), '"', '\"') + '",'
        + '"FLAT":"",'
        + '"BUILDING":"' + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.BUILDINGNAMEORNUMBER), ''), '\', '\\'), '"', '\"') + '",'
        + '"HOUSE":"'    + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.BUILDINGNAMEORNUMBER), ''), '\', '\\'), '"', '\"') + '",'
        + '"STREET":"'   + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.STREETNAME), ''), '\', '\\'), '"', '\"') + '",'
        + '"TOWN":"'     + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), PERSADDRESS.TOWNORCITY), ''), '\', '\\'), '"', '\"') + '",'
        + '"UPRN":'      + CASE
                              WHEN PERSADDRESS.UPRN IS NULL THEN 'null'
                              WHEN LTRIM(RTRIM(CONVERT(NVARCHAR(100), PERSADDRESS.UPRN))) = '' THEN 'null'
                              ELSE '"' + REPLACE(REPLACE(CONVERT(NVARCHAR(100), PERSADDRESS.UPRN), '\', '\\'), '"', '\"') + '"'
                           END + ','
        + '"EASTING":"",'
        + '"NORTHING":""'
        + '}'
    ) AS addr_address_json
FROM ADDRESSPERSONVIEW PERSADDRESS
WHERE EXISTS (
    SELECT 1
    FROM ssd_person SP
    WHERE SP.pers_person_id = CONVERT(NVARCHAR(48), PERSADDRESS.PERSONID)
);