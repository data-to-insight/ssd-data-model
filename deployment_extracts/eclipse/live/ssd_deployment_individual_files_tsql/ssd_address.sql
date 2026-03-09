-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description: Contains full address details for every person
-- Author: D2I
-- Version: 0.2 Fixed run order and ; use 
--          0.1: new RH
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
--          JSON built via string concat for legacy SQL Server compatibility
--          Requires #LEGACY-PRE2016 changes if wider script assumes newer JSON funcs
-- Dependencies:
-- - ssd_person
-- - PERSONVIEW
-- - ADDRESSPERSONVIEW
-- =============================================================================


/* META-ELEMENT: {"type": "drop_table"} */
IF OBJECT_ID('tempdb..#ssd_address', 'U') IS NOT NULL DROP TABLE #ssd_address;

IF OBJECT_ID('ssd_development.ssd_address', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_development.ssd_address)
        TRUNCATE TABLE ssd_development.ssd_address;
END
ELSE
BEGIN
    /* META-ELEMENT: {"type": "create_table"} */
    CREATE TABLE ssd_development.ssd_address (
        addr_table_id           NVARCHAR(48)  NOT NULL PRIMARY KEY,  -- metadata={"item_ref":"ADDR007A"}
        addr_person_id          NVARCHAR(48)  NULL,                  -- metadata={"item_ref":"ADDR002A"}
        addr_address_type       NVARCHAR(48)  NULL,                  -- metadata={"item_ref":"ADDR003A"}
        addr_address_start_date DATETIME      NULL,                  -- metadata={"item_ref":"ADDR004A"}
        addr_address_end_date   DATETIME      NULL,                  -- metadata={"item_ref":"ADDR005A"}
        addr_address_postcode   NVARCHAR(15)  NULL,                  -- metadata={"item_ref":"ADDR006A"}
        addr_address_json       NVARCHAR(1000) NULL                  -- metadata={"item_ref":"ADDR001A"}
    );
END


/* META-ELEMENT: {"type": "insert_data"} */
;WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
    WHERE
        PV.PERSONID IN (1,2,3,4,5,6) -- hard filter admin,test,duplicate records on system
        OR ISNULL(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME)  LIKE '%DUPLICATE%'
)
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
    CONVERT(NVARCHAR(48), PERSADDRESS.ADDRESSID) AS addr_table_id,              -- metadata={"item_ref":"ADDR007A"}
    CONVERT(NVARCHAR(48), PERSADDRESS.PERSONID)  AS addr_person_id,             -- metadata={"item_ref":"ADDR002A"}
    CONVERT(NVARCHAR(48), PERSADDRESS.TYPE)      AS addr_address_type,          -- metadata={"item_ref":"ADDR003A"}
    CONVERT(DATETIME, PERSADDRESS.STARTDATE)     AS addr_address_start_date,    -- metadata={"item_ref":"ADDR004A"}
    CONVERT(DATETIME, PERSADDRESS.ENDDATE)       AS addr_address_end_date,      -- metadata={"item_ref":"ADDR005A"}
    REPLACE(CONVERT(NVARCHAR(15), PERSADDRESS.POSTCODE), ' ', '') AS addr_address_postcode, -- metadata={"item_ref":"ADDR006A"}

    /* JSON_BUILD_OBJECT(...)::TEXT replacement, legacy-safe string build */
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
    ) AS addr_address_json                                                -- metadata={"item_ref":"ADDR001A"}
FROM ADDRESSPERSONVIEW PERSADDRESS
WHERE NOT EXISTS (
    SELECT 1
    FROM EXCLUSIONS E
    WHERE E.PERSONID = PERSADDRESS.PERSONID
);