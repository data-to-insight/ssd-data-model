

-- Run SSD into Temporary OR Persistent extract structure
-- 
DECLARE @Run_SSD_As_Temporary_Tables BIT;
SET     @Run_SSD_As_Temporary_Tables = 0;   -- 1==Single use SSD extract uses tempdb..# | 0==Persistent SSD table set up
                                            -- This flag enables/disables running such as FK constraints that don't apply to tempdb..# implementation

DECLARE @sql NVARCHAR(MAX) = N'';                           -- used in both clean-up and logging
DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- Set your schema name here OR leave empty for default behaviour
DECLARE @default_schema NVARCHAR(128) = N'dbo';             -- Default schema if none provided


/* ********************************************************************************************************** */
/* START SSD pre-extract clean up (remove all previous SSD objects) */


-- extracting into persistent|perm tables
-- some potential clean-up needed from any previous implementations/testing
PRINT CHAR(13) + CHAR(10) + 'Removing SSD persistant tables, prefixed as ssd_' + CHAR(13) + CHAR(10);

/*
START drop all ssd_development. schema constraints */

-- pre-emptively avoid any run-time conflicts from left-behind FK constraints

-- Set schema name to default if not provided
IF @schema_name = N'' OR @schema_name IS NULL
BEGIN
    SET @schema_name = @default_schema;
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

-- Clear SQL var
SET @sql = N'';

-- generate DROP TABLE for each table in schema prefixed with 'ssd_'
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

-- Execute drop tables
EXEC sp_executesql @sql;

-- Clear SQL var
SET @sql = N'';


/* END SSD pre-extract clean up (remove all previous SSD objects) */
/* ********************************************************************************************************** */
