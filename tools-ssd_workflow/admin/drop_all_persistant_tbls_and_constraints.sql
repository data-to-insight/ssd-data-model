USE HDM_Local;  -- Make sure in the right database

DECLARE @sql NVARCHAR(MAX) = N'';

-- Generate commands to drop foreign key constraints
SELECT @sql += 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) 
               + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + '; '
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS t ON fk.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = N'ssd_development';

-- Execute the generated commands to drop the foreign keys
EXEC sp_executesql @sql;

--------------------------------------------------------------

USE HDM_Local;

DECLARE @sql NVARCHAR(MAX) = N'';

-- Generate DROP TABLE commands for each table in the specified schema
SELECT @sql += 'DROP TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + '; '
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = N'ssd_development';

-- Execute the dynamic SQL to drop the tables
EXEC sp_executesql @sql;
