-- Master deploy runner for SSD table procs
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    PRINT 'Running ssd_setup';
    EXEC ssd_setup;

    DECLARE @schema_name sysname = (SELECT TOP 1 src_schema FROM ##ssd_runtime_settings);
    DECLARE @p nvarchar(514), @pc nvarchar(514), @sql nvarchar(max);

    -- proc_ssd_person
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_person';
        SET @pc = N'proc_ssd_person_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_person';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cohort
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cohort';
        SET @pc = N'proc_ssd_cohort_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cohort';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_family
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_family';
        SET @pc = N'proc_ssd_family_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_family';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_address
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_address';
        SET @pc = N'proc_ssd_address_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_address';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_disability
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_disability';
        SET @pc = N'proc_ssd_disability_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_disability';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_immigration_status
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_immigration_status';
        SET @pc = N'proc_ssd_immigration_status_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_immigration_status';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cin_episodes
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cin_episodes';
        SET @pc = N'proc_ssd_cin_episodes_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cin_episodes';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_mother
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_mother';
        SET @pc = N'proc_ssd_mother_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_mother';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_legal_status
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_legal_status';
        SET @pc = N'proc_ssd_legal_status_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_legal_status';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_contacts
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_contacts';
        SET @pc = N'proc_ssd_contacts_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_contacts';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_early_help_episodes
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_early_help_episodes';
        SET @pc = N'proc_ssd_early_help_episodes_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_early_help_episodes';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cin_assessments
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cin_assessments';
        SET @pc = N'proc_ssd_cin_assessments_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cin_assessments';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_assessment_factors
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_assessment_factors';
        SET @pc = N'proc_ssd_assessment_factors_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_assessment_factors';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cin_plans
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cin_plans';
        SET @pc = N'proc_ssd_cin_plans_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cin_plans';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cin_visits
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cin_visits';
        SET @pc = N'proc_ssd_cin_visits_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cin_visits';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_s47_enquiry
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_s47_enquiry';
        SET @pc = N'proc_ssd_s47_enquiry_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_s47_enquiry';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_initial_cp_conference
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_initial_cp_conference';
        SET @pc = N'proc_ssd_initial_cp_conference_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_initial_cp_conference';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cp_plans
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cp_plans';
        SET @pc = N'proc_ssd_cp_plans_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cp_plans';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cp_visits
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cp_visits';
        SET @pc = N'proc_ssd_cp_visits_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cp_visits';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cp_reviews
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cp_reviews';
        SET @pc = N'proc_ssd_cp_reviews_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cp_reviews';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_episodes
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_episodes';
        SET @pc = N'proc_ssd_cla_episodes_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_episodes';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_convictions
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_convictions';
        SET @pc = N'proc_ssd_cla_convictions_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_convictions';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_health
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_health';
        SET @pc = N'proc_ssd_cla_health_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_health';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_immunisations
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_immunisations';
        SET @pc = N'proc_ssd_cla_immunisations_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_immunisations';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_substance_misuse
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_substance_misuse';
        SET @pc = N'proc_ssd_cla_substance_misuse_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_substance_misuse';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_placement
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_placement';
        SET @pc = N'proc_ssd_cla_placement_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_placement';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_reviews
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_reviews';
        SET @pc = N'proc_ssd_cla_reviews_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_reviews';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_previous_permanence
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_previous_permanence';
        SET @pc = N'proc_ssd_cla_previous_permanence_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_previous_permanence';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_pre_cla_care_plan
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_pre_cla_care_plan';
        SET @pc = N'proc_ssd_pre_cla_care_plan_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_pre_cla_care_plan';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_cla_visits
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_cla_visits';
        SET @pc = N'proc_ssd_cla_visits_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_cla_visits';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_sdq_scores
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_sdq_scores';
        SET @pc = N'proc_ssd_sdq_scores_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_sdq_scores';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_missing
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_missing';
        SET @pc = N'proc_ssd_missing_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_missing';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_care_leavers
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_care_leavers';
        SET @pc = N'proc_ssd_care_leavers_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_care_leavers';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_permanence
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_permanence';
        SET @pc = N'proc_ssd_permanence_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_permanence';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_professionals
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_professionals';
        SET @pc = N'proc_ssd_professionals_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_professionals';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_department
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_department';
        SET @pc = N'proc_ssd_department_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_department';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_involvements
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_involvements';
        SET @pc = N'proc_ssd_involvements_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_involvements';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_linked_identifiers
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_linked_identifiers';
        SET @pc = N'proc_ssd_linked_identifiers_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_linked_identifiers';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_s251_finance
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_s251_finance';
        SET @pc = N'proc_ssd_s251_finance_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_s251_finance';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_voice_of_child
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_voice_of_child';
        SET @pc = N'proc_ssd_voice_of_child_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_voice_of_child';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_pre_proceedings
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_pre_proceedings';
        SET @pc = N'proc_ssd_pre_proceedings_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_pre_proceedings';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_send
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_send';
        SET @pc = N'proc_ssd_send_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_send';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_sen_need
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_sen_need';
        SET @pc = N'proc_ssd_sen_need_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_sen_need';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_ehcp_requests
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_ehcp_requests';
        SET @pc = N'proc_ssd_ehcp_requests_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_requests';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_ehcp_assessment
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_ehcp_assessment';
        SET @pc = N'proc_ssd_ehcp_assessment_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_assessment';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_ehcp_named_plan
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_ehcp_named_plan';
        SET @pc = N'proc_ssd_ehcp_named_plan_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_named_plan';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    -- proc_ssd_ehcp_active_plans
    IF NULLIF(@schema_name, N'') IS NULL
    BEGIN
        SET @p  = N'proc_ssd_ehcp_active_plans';
        SET @pc = N'proc_ssd_ehcp_active_plans_custom';
    END
    ELSE
    BEGIN
        SET @p  = QUOTENAME(@schema_name) + N'.proc_ssd_ehcp_active_plans';
        SET @pc = @p + N'_custom';
    END
    IF OBJECT_ID(@pc, N'P') IS NOT NULL
        SET @sql = N'EXEC ' + @pc;
    ELSE
        SET @sql = N'EXEC ' + @p;
    PRINT @sql;
    EXEC(@sql);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
