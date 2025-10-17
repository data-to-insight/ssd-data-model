
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



-- Declare the table variable to hold the table names and the corresponding person_id column names
DECLARE @tempTableNames TABLE (tableName NVARCHAR(MAX), columnName NVARCHAR(MAX))




-- Insert the table names and the corresponding person_id column names into the table variable
INSERT INTO @tempTableNames (tableName, columnName)
VALUES
('ssd_person', 'pers_person_id'),
('ssd_family', 'fami_person_id'),
('ssd_address', 'addr_person_id'),
('ssd_disability', 'disa_person_id'),
('ssd_immigration_status', 'immi_person_id'),
('ssd_mother', 'moth_person_id'),
('ssd_mother', 'moth_childs_person_id'), -- Note: this appears twice, for two different columns
('ssd_legal_status', 'lega_person_id'),
('ssd_contacts', 'cont_person_id'),
('ssd_early_help_episodes', 'earl_person_id'),
('ssd_cin_episodes', 'cine_person_id'),
('ssd_cin_assessments', 'cina_person_id'),
('ssd_cin_plans', 'cinp_person_id'),
('ssd_s47_enquiry', 's47e_person_id'),
('ssd_initial_cp_conference', 'icpc_person_id'),
('ssd_cp_plans', 'cppl_person_id'),
('ssd_cla_episodes', 'clae_person_id'),
('ssd_cla_convictions', 'clac_person_id'),
('ssd_cla_health', 'clah_person_id'),
('ssd_cla_immunisations', 'clai_person_id'),
('ssd_cla_substance_misuse', 'clas_person_id'),
('ssd_cla_visits', 'clav_person_id'),
('ssd_cla_previous_permanence', 'lapp_person_id'),
('ssd_cla_care_plan', 'lacp_person_id'),
('ssd_sdq_scores', 'csdq_person_id'),
('ssd_missing', 'miss_person_id'),
('ssd_care_leavers', 'clea_person_id'),
('ssd_permanence', 'perm_person_id'),
('ssd_send', 'send_person_id'),
('ssd_pre_proceedings', 'prep_person_id'),
('ssd_voice_of_child', 'voch_person_id'),
('ssd_linked_identifiers', 'link_person_id');
