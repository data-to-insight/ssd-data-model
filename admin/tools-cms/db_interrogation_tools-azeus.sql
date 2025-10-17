/* interogate Azeus DB */

-- Obtain available schemas in case tables cross schemas
SELECT DISTINCT OWNER
FROM ALL_OBJECTS
WHERE OWNER IS NOT NULL;


-- v2. 
-- List of tables derived from the stat-returns Azeus spec supplied
DECLARE
    schema_name VARCHAR2(100) := 'AZEUS_PROD';
BEGIN
    -- Assuming you want to process each row returned by the query:
    FOR rec IN (
        WITH TableNames AS (
            SELECT 'ADOPTER_APP' AS TableName FROM DUAL
            UNION ALL
            SELECT 'PLCMT' AS TableName FROM DUAL
            -- Add the rest of your UNION ALL statements here
        )
        SELECT tn.TableName, COLUMN_NAME
        FROM TableNames tn
        JOIN ALL_TAB_COLUMNS tc ON tn.TableName = tc.TABLE_NAME
        WHERE tc.OWNER = schema_name
        ORDER BY tn.TableName, COLUMN_ID
    ) LOOP
        -- Process each record as needed, for example:
        DBMS_OUTPUT.PUT_LINE(rec.TableName || ' - ' || rec.COLUMN_NAME);
    END LOOP;
END;


