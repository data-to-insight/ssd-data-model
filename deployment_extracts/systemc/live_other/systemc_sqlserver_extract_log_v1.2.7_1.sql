

/* Start

        SSD Extract Logging
        */





-- META-CONTAINER: {"type": "table", "name": "ssd_extract_log"}
-- =============================================================================
-- Description: Enable LA extract overview logging
-- Author: D2I
-- Version: 0.1
-- Status: [R]elease
-- Remarks: 
-- Dependencies: 
-- - 
-- =============================================================================



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_extract_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_extract_log;
IF OBJECT_ID('tempdb..#ssd_extract_log', 'U') IS NOT NULL DROP TABLE #ssd_extract_log;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_extract_log (
    table_name           NVARCHAR(255) PRIMARY KEY,     
    schema_name          NVARCHAR(255),
    status               NVARCHAR(50), -- status code includes error output + schema.table_name
    rows_inserted        INT,
    table_size_kb        INT,
    has_pk      BIT,
    has_fks     BIT,
    index_count          INT,
    creation_date        DATETIME DEFAULT GETDATE(),
    null_count           INT,          -- New: count of null values for each table
    pk_datatype          NVARCHAR(255),-- New: datatype of the PK field
    additional_detail    NVARCHAR(MAX), -- on hold|future use, e.g. data quality issues detected
    error_message        NVARCHAR(MAX)  -- on hold|future use, e.g. errors encountered during the process
);


-- META-ELEMENT: {"type": "insert_data"} 
-- GO
-- Ensure all variables are declared correctly
DECLARE @row_count          INT;
DECLARE @table_size_kb      INT;
DECLARE @has_pk             BIT;
DECLARE @has_fks            BIT;
DECLARE @index_count        INT;
DECLARE @null_count         INT;
DECLARE @pk_datatype        NVARCHAR(255);
DECLARE @additional_detail  NVARCHAR(MAX);
DECLARE @error_message      NVARCHAR(MAX);
DECLARE @table_name         NVARCHAR(255);
DECLARE @sql                NVARCHAR(MAX) = N'';   


-- Placeholder for table_cursor selection logic
DECLARE table_cursor CURSOR FOR
SELECT 'ssd_development.ssd_version_log'             UNION ALL -- Admin table, not SSD
SELECT 'ssd_development.ssd_person'                  UNION ALL
SELECT 'ssd_development.ssd_family'                  UNION ALL
SELECT 'ssd_development.ssd_address'                 UNION ALL
SELECT 'ssd_development.ssd_disability'              UNION ALL
SELECT 'ssd_development.ssd_immigration_status'      UNION ALL
SELECT 'ssd_development.ssd_mother'                  UNION ALL
SELECT 'ssd_development.ssd_legal_status'            UNION ALL
SELECT 'ssd_development.ssd_contacts'                UNION ALL
SELECT 'ssd_development.ssd_early_help_episodes'     UNION ALL
SELECT 'ssd_development.ssd_cin_episodes'            UNION ALL
SELECT 'ssd_development.ssd_cin_assessments'         UNION ALL
SELECT 'ssd_development.ssd_assessment_factors'      UNION ALL
SELECT 'ssd_development.ssd_cin_plans'               UNION ALL
SELECT 'ssd_development.ssd_cin_visits'              UNION ALL
SELECT 'ssd_development.ssd_s47_enquiry'             UNION ALL
SELECT 'ssd_development.ssd_initial_cp_conference'   UNION ALL
SELECT 'ssd_development.ssd_cp_plans'                UNION ALL
SELECT 'ssd_development.ssd_cp_visits'               UNION ALL
SELECT 'ssd_development.ssd_cp_reviews'              UNION ALL
SELECT 'ssd_development.ssd_cla_episodes'            UNION ALL
SELECT 'ssd_development.ssd_cla_convictions'         UNION ALL
SELECT 'ssd_development.ssd_cla_health'              UNION ALL
SELECT 'ssd_development.ssd_cla_immunisations'       UNION ALL
SELECT 'ssd_development.ssd_cla_substance_misuse'    UNION ALL
SELECT 'ssd_development.ssd_cla_placement'           UNION ALL
SELECT 'ssd_development.ssd_cla_reviews'             UNION ALL
SELECT 'ssd_development.ssd_cla_previous_permanence' UNION ALL
SELECT 'ssd_development.ssd_cla_care_plan'           UNION ALL
SELECT 'ssd_development.ssd_cla_visits'              UNION ALL
SELECT 'ssd_development.ssd_sdq_scores'              UNION ALL
SELECT 'ssd_development.ssd_missing'                 UNION ALL
SELECT 'ssd_development.ssd_care_leavers'            UNION ALL
SELECT 'ssd_development.ssd_permanence'              UNION ALL
SELECT 'ssd_development.ssd_professionals'           UNION ALL
SELECT 'ssd_development.ssd_department'              UNION ALL
SELECT 'ssd_development.ssd_involvements'            UNION ALL
SELECT 'ssd_development.ssd_linked_identifiers'      UNION ALL
SELECT 'ssd_development.ssd_s251_finance'            UNION ALL
SELECT 'ssd_development.ssd_voice_of_child'          UNION ALL
SELECT 'ssd_development.ssd_pre_proceedings'         UNION ALL
SELECT 'ssd_development.ssd_send'                    UNION ALL
SELECT 'ssd_development.ssd_sen_need'                UNION ALL
SELECT 'ssd_development.ssd_ehcp_requests'           UNION ALL
SELECT 'ssd_development.ssd_ehcp_assessment'         UNION ALL
SELECT 'ssd_development.ssd_ehcp_named_plan'         UNION ALL
SELECT 'ssd_development.ssd_ehcp_active_plans';

-- Define placeholder tables
DECLARE @ssd_placeholder_tables TABLE (table_name NVARCHAR(255));
INSERT INTO @ssd_placeholder_tables (table_name)
VALUES
    ('ssd_development.ssd_send'),
    ('ssd_development.ssd_sen_need'),
    ('ssd_development.ssd_ehcp_requests'),
    ('ssd_development.ssd_ehcp_assessment'),
    ('ssd_development.ssd_ehcp_named_plan'),
    ('ssd_development.ssd_ehcp_active_plans');

DECLARE @dfe_project_placeholder_tables TABLE (table_name NVARCHAR(255));
INSERT INTO @dfe_project_placeholder_tables (table_name)
VALUES
    ('ssd_development.ssd_s251_finance'),
    ('ssd_development.ssd_voice_of_child'),
    ('ssd_development.ssd_pre_proceedings');

-- Open table cursor
OPEN table_cursor;

-- Fetch next table name from the list
FETCH NEXT FROM table_cursor INTO @table_name;

-- Iterate table names listed above
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        -- Generate the schema-qualified table name
        DECLARE @full_table_name NVARCHAR(511);
        SET @full_table_name = CASE WHEN @schema_name = '' THEN @table_name ELSE @schema_name + '.' + @table_name END;

        -- Check if table exists
        SET @sql = N'SELECT @table_exists = COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name';
        DECLARE @table_exists INT;
        EXEC sp_executesql @sql, N'@table_exists INT OUTPUT, @schema_name NVARCHAR(255), @table_name NVARCHAR(255)', @table_exists OUTPUT, @schema_name, @table_name;

        IF @table_exists = 0
        BEGIN
            THROW 50001, 'Table does not exist', 1;
        END
        
        -- get row count
        SET @sql = N'SELECT @row_count = COUNT(*) FROM ' + @full_table_name;
        EXEC sp_executesql @sql, N'@row_count INT OUTPUT', @row_count OUTPUT;

        -- get table size in KB
        SET @sql = N'SELECT @table_size_kb = SUM(reserved_page_count) * 8 FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
        EXEC sp_executesql @sql, N'@table_size_kb INT OUTPUT', @table_size_kb OUTPUT;

        -- check for primary key (flag field)
        SET @sql = N'
            SELECT @has_pk = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.indexes i
                WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(''' + @full_table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_pk BIT OUTPUT', @has_pk OUTPUT;

        -- check for foreign key(s) (flag field)
        SET @sql = N'
            SELECT @has_fks = CASE WHEN EXISTS (
                SELECT 1 
                FROM sys.foreign_keys fk
                WHERE fk.parent_object_id = OBJECT_ID(''' + @full_table_name + ''')
            ) THEN 1 ELSE 0 END';
        EXEC sp_executesql @sql, N'@has_fks BIT OUTPUT', @has_fks OUTPUT;

        -- count index(es)
        SET @sql = N'
            SELECT @index_count = COUNT(*)
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
        EXEC sp_executesql @sql, N'@index_count INT OUTPUT', @index_count OUTPUT;

        -- Get null values count (~overview of data sparcity)
        DECLARE @col NVARCHAR(255);
        DECLARE @total_nulls INT;
        SET @total_nulls = 0;

        DECLARE column_cursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name;

        OPEN column_cursor;
        FETCH NEXT FROM column_cursor INTO @col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'SELECT @total_nulls = @total_nulls + (SELECT COUNT(*) FROM ' + @full_table_name + ' WHERE ' + @col + ' IS NULL)';
            EXEC sp_executesql @sql, N'@total_nulls INT OUTPUT', @total_nulls OUTPUT;
            FETCH NEXT FROM column_cursor INTO @col;
        END
        CLOSE column_cursor;
        DEALLOCATE column_cursor;

        SET @null_count = @total_nulls;

        -- get datatype of the primary key
        SET @sql = N'
            SELECT TOP 1 @pk_datatype = c.DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS c
            JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON c.COLUMN_NAME = kcu.COLUMN_NAME AND c.TABLE_NAME = kcu.TABLE_NAME AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
            JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
            WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
            AND kcu.TABLE_NAME = @table_name
            AND kcu.TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END';
        EXEC sp_executesql @sql, N'@pk_datatype NVARCHAR(255) OUTPUT, @table_name NVARCHAR(255), @schema_name NVARCHAR(255)', @pk_datatype OUTPUT, @table_name, @schema_name;

        -- set additional_detail comment to make sense|add detail to expected 
        -- empty/placholder tables incl. future DfE projects
        SET @additional_detail = NULL;

        IF EXISTS (SELECT 1 FROM @ssd_placeholder_tables WHERE table_name = @table_name)
        BEGIN
            SET @additional_detail = 'ssd placeholder table';
        END
        ELSE IF EXISTS (SELECT 1 FROM @dfe_project_placeholder_tables WHERE table_name = @table_name)
        BEGIN
            SET @additional_detail = 'DfE project placeholder table';
        END

        -- insert log entry 
        INSERT INTO ssd_development.ssd_extract_log (
            table_name, 
            schema_name, 
            status, 
            rows_inserted, 
            table_size_kb, 
            has_pk, 
            has_fks, 
            index_count, 
            null_count, 
            pk_datatype, 
            additional_detail
            )
        VALUES (@table_name, @schema_name, 'Success', @row_count, @table_size_kb, @has_pk, @has_fks, @index_count, @null_count, @pk_datatype, @additional_detail);
    END TRY
    BEGIN CATCH
        -- log any error (this only an indicator of possible issue)
        -- tricky 
        SET @error_message = ERROR_MESSAGE();
        INSERT INTO ssd_development.ssd_extract_log (
            table_name, 
            schema_name, 
            status, 
            rows_inserted, 
            table_size_kb, 
            has_pk, 
            has_fks, 
            index_count, 
            null_count, 
            pk_datatype, 
            additional_detail, 
            error_message
            )
        VALUES (@table_name, @schema_name, 'Error', 0, NULL, 0, 0, 0, 0, NULL, @additional_detail, @error_message);
    END CATCH;

    -- Fetch next table name
    FETCH NEXT FROM table_cursor INTO @table_name;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

SET @sql = N'';





-- META-ELEMENT: {"type": "console_output"}
-- Forming part of the extract admin results output
SELECT * FROM ssd_development.ssd_extract_log ORDER BY rows_inserted DESC;