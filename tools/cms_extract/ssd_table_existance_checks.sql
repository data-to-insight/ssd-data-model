USE HDM;

/*
Start of table checks 
*/

DECLARE @missingTables NVARCHAR(MAX) = ''
DECLARE @tableName NVARCHAR(255)

-- Table names that we want to check
DECLARE tableCursor CURSOR FOR
SELECT tableName FROM 
(VALUES
/* Add all expected tables for ssd in here */
    ('DIM_PERSON'),
    ('FACT_CPIS_UPLOAD'),
    ('DIM_TF_FAMILY'),
    ('DIM_PERSON_ADDRESS'),
    ('FACT_DISABILITY'),
    ('FACT_IMMIGRATION_STATUS'),
    ('FACT_CONTACT'),
    ('FACT_S47'),
    ('FACT_SUBSTANCE_MISUSE'),
    ('FACT_CP_CONFERENCE'),
    ('FACT_CLA_REVIEW'),
    ('FACT_903_DATA'),
    ('FACT_LEGAL_STATUS')
) AS t(tableName)

OPEN tableCursor
FETCH NEXT FROM tableCursor INTO @tableName

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @tableName)
    BEGIN
        SET @missingTables = @missingTables + @tableName + ', '
    END
    
    FETCH NEXT FROM tableCursor INTO @tableName
END

CLOSE tableCursor
DEALLOCATE tableCursor

IF LEN(@missingTables) > 0
BEGIN
    -- Removing the last comma and space
    SET @missingTables = LEFT(@missingTables, LEN(@missingTables) - 2)
    PRINT 'The following tables are missing: ' + @missingTables
END
ELSE
BEGIN
    PRINT 'All tables are present.'
END




/* 
Alternative approach in case the above can't run
Start of single line/individual table checks
*/

-- Check existence for DM_PERSON
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DM_PERSON')
    PRINT 'Table DM_PERSON does not exist in the current schema.'

-- Check existence for FACT_CPIS_UPLOAD
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_CPIS_UPLOAD')
    PRINT 'Table FACT_CPIS_UPLOAD does not exist in the current schema.'

-- Check existence for DIM_TF_FAMILY
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DIM_TF_FAMILY')
    PRINT 'Table DIM_TF_FAMILY does not exist in the current schema.'

-- Check existence for DIM_PERSON_ADDRESS
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'DIM_PERSON_ADDRESS')
    PRINT 'Table DIM_PERSON_ADDRESS does not exist in the current schema.'

-- Check existence for FACT_DISABILITY
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_DISABILITY')
    PRINT 'Table FACT_DISABILITY does not exist in the current schema.'

-- Check existence for FACT_IMMIGRATION_STATUS
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_IMMIGRATION_STATUS')
    PRINT 'Table FACT_IMMIGRATION_STATUS does not exist in the current schema.'

-- Check existence for FACT_CONTACT
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_CONTACT')
    PRINT 'Table FACT_CONTACT does not exist in the current schema.'

-- Check existence for FACT_S47
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_S47')
    PRINT 'Table FACT_S47 does not exist in the current schema.'

-- Check existence for FACT_SUBSTANCE_MISUSE
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_SUBSTANCE_MISUSE')
    PRINT 'Table FACT_SUBSTANCE_MISUSE does not exist in the current schema.'

-- Check existence for FACT_CP_CONFERENCE
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_CP_CONFERENCE')
    PRINT 'Table FACT_CP_CONFERENCE does not exist in the current schema.'

-- Check existence for FACT_CLA_REVIEW
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_CLA_REVIEW')
    PRINT 'Table FACT_CLA_REVIEW does not exist in the current schema.'

-- Check existence for FACT_903_DATA
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_903_DATA')
    PRINT 'Table FACT_903_DATA does not exist in the current schema.'

-- Check existence for FACT_LEGAL_STATUS
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'FACT_LEGAL_STATUS')
    PRINT 'Table FACT_LEGAL_STATUS does not exist in the current schema.'


/* end of table checks */
