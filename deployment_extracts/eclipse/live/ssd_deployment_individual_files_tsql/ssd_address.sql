-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies: 
-- ADDRESSPERSONVIEW
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_address', 'U') IS NOT NULL DROP TABLE #ssd_address;

IF OBJECT_ID('ssd_address', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_address])
        TRUNCATE TABLE [ssd_address];
END
ELSE
BEGIN
    CREATE TABLE [ssd_address] (
        addr_table_id           NVARCHAR(48)   NOT NULL PRIMARY KEY,
        addr_person_id          NVARCHAR(48)   NULL,
        addr_address_type       NVARCHAR(48)   NULL,
        addr_address_start_date DATETIME       NULL,
        addr_address_end_date   DATETIME       NULL,
        addr_address_postcode   NVARCHAR(15)   NULL,
        addr_address_json       NVARCHAR(1000) NULL
    );
END;


-- rank addresses for most recent (per person)
;WITH ADDRESS_RANKED AS (
    SELECT
        PERSADDRESS.*,
        ROW_NUMBER() OVER (
            PARTITION BY PERSADDRESS.PERSONID
            ORDER BY 
                CASE WHEN PERSADDRESS.ENDDATE IS NULL THEN 0 ELSE 1 END,
                PERSADDRESS.ENDDATE DESC,
                PERSADDRESS.STARTDATE DESC
        ) AS RN
    FROM [eclipseDelta].[dbo].[ADDRESSPERSONVIEW] PERSADDRESS
)


INSERT INTO [ssd_address] (
    addr_table_id,
    addr_person_id,
    addr_address_type,
    addr_address_start_date,
    addr_address_end_date,
    addr_address_postcode,
    addr_address_json
)
SELECT
    CONVERT(NVARCHAR(48), A.ADDRESSID),
    CONVERT(NVARCHAR(48), A.PERSONID),
    CONVERT(NVARCHAR(48), A.TYPE),
    CONVERT(DATETIME, A.STARTDATE),
    CONVERT(DATETIME, A.ENDDATE),
    REPLACE(CONVERT(NVARCHAR(15), A.POSTCODE), ' ', ''),
    CONVERT(NVARCHAR(1000),
        '{'
        + '"ROOM":"'     
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.ROOMDESCRIPTION), ''),  '\', '\\'), '"', '\"')
            + '",'
        + '"FLOOR":"'    
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.FLOORDESCRIPTION), ''), '\', '\\'), '"', '\"')
            + '",'
        + '"FLAT":"",'
        + '"BUILDING":"' 
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.BUILDINGNAMEORNUMBER), ''), '\', '\\'), '"', '\"')
            + '",'
        + '"HOUSE":"'    
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.BUILDINGNAMEORNUMBER), ''), '\', '\\'), '"', '\"')
            + '",'
        + '"STREET":"'   
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.STREETNAME), ''), '\', '\\'), '"', '\"')
            + '",'
        + '"TOWN":"'     
            + REPLACE(REPLACE(ISNULL(CONVERT(NVARCHAR(200), A.TOWNORCITY), ''), '\', '\\'), '"', '\"')
            + '",'
        + '"UPRN":'
            + CASE
                  WHEN A.UPRN IS NULL
                       OR LTRIM(RTRIM(CONVERT(NVARCHAR(100), A.UPRN))) = ''
                      THEN 'null'
                  ELSE '"' 
                       + REPLACE(REPLACE(CONVERT(NVARCHAR(100), A.UPRN), '\', '\\'), '"', '\"')
                       + '"'
              END
            + ','
        + '"EASTING":"",'
        + '"NORTHING":""'
        + '}'
    )
FROM ADDRESS_RANKED A
WHERE 
    A.RN = 1  -- only most recent addr
    AND EXISTS (
        SELECT 1
        FROM [ssd_person] SP
        WHERE SP.pers_person_id = CONVERT(NVARCHAR(48), A.PERSONID)
    );
