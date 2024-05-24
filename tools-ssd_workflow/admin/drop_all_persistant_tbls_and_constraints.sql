USE HDM_Local;  -- Check its the right database!

DECLARE @sql NVARCHAR(MAX) = N'';

-- Generate commands to drop FK constraints
SELECT @sql += '
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = ' + QUOTENAME(fk.name, '''') + ')
BEGIN
    ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(fk.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';
END;
'
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS t ON fk.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = N'ssd_development';

-- Execute drop FK
EXEC sp_executesql @sql;

-- Clear the SQL variable
SET @sql = N'';

-- Generate DROP TABLE for each table in the schema
SELECT @sql += '
IF OBJECT_ID(''' + s.name + '.' + t.name + ''', ''U'') IS NOT NULL
BEGIN
    DROP TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';
END;
'
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = N'ssd_development';

-- Execute drop tables
EXEC sp_executesql @sql;



--------------------------------------------------------------

-- SELECT *
-- FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
-- WHERE CONSTRAINT_NAME = 'FK_family_person'
-- AND TABLE_SCHEMA = 'ssd_development';  -


-- ALTER TABLE ssd_development.ssd_family DROP CONSTRAINT FK_family_person;

-- -- -- Recreate constraint
-- -- ALTER TABLE ssd_development.ssd_family
-- -- ADD CONSTRAINT FK_family_person
-- -- FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- -- -- attempt to drop it again
-- -- ALTER TABLE ssd_development.ssd_family DROP CONSTRAINT FK_family_person;
