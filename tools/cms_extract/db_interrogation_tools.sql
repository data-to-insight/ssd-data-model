
-- Get basic table infos ref
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME, 
    COLUMN_NAME 
FROM 
    INFORMATION_SCHEMA.COLUMNS 
WHERE 
    COLUMN_NAME LIKE '%FACT_......%' 
    --AND TABLE_NAME LIKE '%%'
    AND TABLE_SCHEMA = 'Child_Social';


--  Key/relations details
SELECT
    fk.name as FK_name,
    tp.name as Parent_table,
    cp.name as Parent_column,
    tr.name as Ref_table,
    cr.name as Ref_column
FROM 
    sys.foreign_keys fk
INNER JOIN 
    sys.tables tp ON fk.parent_object_id = tp.object_id
INNER JOIN 
    sys.tables tr ON fk.referenced_object_id = tr.object_id
INNER JOIN 
    sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
INNER JOIN 
    sys.columns cp ON fkc.parent_column_id = cp.column_id AND fkc.parent_object_id = cp.object_id
INNER JOIN 
    sys.columns cr ON fkc.referenced_column_id = cr.column_id AND fkc.referenced_object_id = cr.object_id
WHERE 
    tp.name IN ('FACT_CP_REVIEW', 'FACT_CASE_PATHWAY_STEP', 'FACT_FORMS', 'FACT_FORM_ANSWERS')
    AND tr.name IN ('FACT_CP_REVIEW', 'FACT_CASE_PATHWAY_STEP', 'FACT_FORMS', 'FACT_FORM_ANSWERS')
    AND tp.schema_id = SCHEMA_ID('Child_Social');


