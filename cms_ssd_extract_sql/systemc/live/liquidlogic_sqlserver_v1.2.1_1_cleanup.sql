USE HDM_Local;  -- Ensure the correct database is being used

DECLARE @sql NVARCHAR(MAX) = N'';                           -- used in both clean-up and logging
DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- Set your schema name here

/* ********************************************************************************************************** */
/* START SSD pre-extract clean up (remove all previous SSD objects) */

/* persistent|perm SSD tables */
PRINT CHAR(13) + CHAR(10) + 'Removing SSD persistent tables, prefixed as ssd_' + CHAR(13) + CHAR(10);

-- ensure schema name is provided
IF @schema_name = N'' OR @schema_name IS NULL
BEGIN
    RAISERROR('Schema name must be provided and cannot be empty.', 16, 1);
    RETURN;
END

-- generate DROP FK commands
SET @sql = N'';
SELECT @sql += '
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = ' + QUOTENAME(fk.name, '''') + ')
    BEGIN
        ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';
    END;'
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS t ON fk.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = @schema_name
AND t.name LIKE 'ssd_%';  -- Filter for tables prefixed with 'ssd_'

-- execute drop FK
EXEC sp_executesql @sql;

-- reset var
SET @sql = N'';

-- generate DROP TABLE commands for tables in schema prefixed with 'ssd_'
SELECT @sql += '
IF OBJECT_ID(''' + @schema_name + '.' + t.name + ''', ''U'') IS NOT NULL
BEGIN
    DROP TABLE ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(t.name) + ';
END;
'
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = @schema_name
AND t.name LIKE 'ssd_%';  -- Filter for tables prefixed with 'ssd_'

-- execute drop tables
EXEC sp_executesql @sql;

-- reset var
SET @sql = N'';

/* END SSD pre-extract clean up (remove all previous SSD objects) */
/* ********************************************************************************************************** */
