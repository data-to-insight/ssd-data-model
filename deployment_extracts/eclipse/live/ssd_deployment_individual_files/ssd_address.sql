-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_address;

-- =============================================================================
-- META-ELEMENT: {"type": "create_table"}
-- Description: Create ssd_address if it does not already exist
-- Postgres version of the original NVARCHAR and DATETIME schema
-- =============================================================================

CREATE TABLE IF NOT EXISTS ssd_address (
    addr_table_id           VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"ADDR007A"}
    addr_person_id          VARCHAR(48),              -- metadata={"item_ref":"ADDR002A"} 
    addr_address_type       VARCHAR(48),              -- metadata={"item_ref":"ADDR003A"}
    addr_address_start_date TIMESTAMP,                -- metadata={"item_ref":"ADDR004A"}
    addr_address_end_date   TIMESTAMP,                -- metadata={"item_ref":"ADDR005A"}
    addr_address_postcode   VARCHAR(15),              -- metadata={"item_ref":"ADDR006A"}
    addr_address_json       VARCHAR(1000)             -- metadata={"item_ref":"ADDR001A"}
);

-- =============================================================================
-- Truncate before reload 
-- =============================================================================
TRUNCATE TABLE ssd_address;

-- =============================================================================
-- Load data into ssd_address
-- =============================================================================

INSERT INTO ssd_address (
    addr_table_id,
    addr_person_id,
    addr_address_type,
    addr_address_start_date,
    addr_address_end_date,
    addr_address_postcode,
    addr_address_json
)
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
        OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)

SELECT
    PERSADDRESS.ADDRESSID              AS addr_table_id,           -- metadata={"item_ref:"ADDR007A"}
    PERSADDRESS.PERSONID               AS addr_person_id,          -- metadata={"item_ref:"ADDR002A"}
    PERSADDRESS.TYPE                   AS addr_address_type,       -- metadata={"item_ref:"ADDR003A"}
    PERSADDRESS.STARTDATE              AS addr_address_start_date, -- metadata={"item_ref:"ADDR004A"}
    PERSADDRESS.ENDDATE                AS addr_address_end_date,   -- metadata={"item_ref:"ADDR005A"}
    REPLACE(PERSADDRESS.POSTCODE, ' ', '') AS addr_address_postcode, -- metadata={"item_ref:"ADDR006A"}
    JSON_BUILD_OBJECT( 
        'ROOM'    , COALESCE(PERSADDRESS.ROOMDESCRIPTION, ''),
        'FLOOR'   , COALESCE(PERSADDRESS.FLOORDESCRIPTION, ''), 
        'FLAT'    , '',
        'BUILDING', COALESCE(PERSADDRESS.BUILDINGNAMEORNUMBER, ''), 
        'HOUSE'   , COALESCE(PERSADDRESS.BUILDINGNAMEORNUMBER, ''), 
        'STREET'  , COALESCE(PERSADDRESS.STREETNAME, ''), 
        'TOWN'    , COALESCE(PERSADDRESS.TOWNORCITY, ''),
        'UPRN'    , COALESCE(PERSADDRESS.UPRN, NULL),
        'EASTING' , '',
        'NORTHING', ''
    )::TEXT                           AS addr_address_json         -- metadata={"item_ref:"ADDR001A"}
FROM ADDRESSPERSONVIEW PERSADDRESS
WHERE PERSADDRESS.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;
