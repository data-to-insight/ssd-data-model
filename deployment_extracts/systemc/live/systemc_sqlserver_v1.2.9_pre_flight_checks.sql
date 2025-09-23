USE HDM_Local;


SET NOCOUNT ON;

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
DECLARE @src_db        sysname  = N'HDM';           -- source DB to inspect
DECLARE @src_schema    sysname  = N'Child_Social';  -- schema to inspect
DECLARE @fail_on_error bit      = 0;               -- 1=raise at end, 0=just show results

--------------------------------------------------------------------------------
-- RESULTS BUCKET 
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#ssd_preflight_issues') IS NOT NULL
  DROP TABLE #ssd_preflight_issues;

CREATE TABLE #ssd_preflight_issues(
  check_label nvarchar(200),
  details     nvarchar(max),
  sql_text    nvarchar(max)
);

--------------------------------------------------------------------------------
-- FATAL FLAGS (record issues, don't crash)
--------------------------------------------------------------------------------
DECLARE @fatal bit = 0;

--------------------------------------------------------------------------------
-- CHECK: db exists?
--------------------------------------------------------------------------------
IF DB_ID(@src_db) IS NULL
BEGIN
  INSERT #ssd_preflight_issues(check_label, details, sql_text)
  VALUES (N'Environment', N'Db not found: ' + QUOTENAME(@src_db), NULL);
  SET @fatal = 1;
END;

--------------------------------------------------------------------------------
-- CHECK: schema exists in target DB? (record error instead of throwing)
--------------------------------------------------------------------------------
IF @fatal = 0
BEGIN
  DECLARE @schema_check_sql nvarchar(max) =
  N'IF NOT EXISTS (SELECT 1 FROM ' + QUOTENAME(@src_db) + N'.sys.schemas WHERE name = @s)
      RAISERROR(''Schema not found: %s.%s'',16,1, @db, @s);';

  BEGIN TRY
    EXEC sp_executesql @schema_check_sql, N'@s sysname, @db sysname', @src_schema, @src_db;
  END TRY
  BEGIN CATCH
    INSERT #ssd_preflight_issues(check_label, details, sql_text)
    VALUES (N'Environment', ERROR_MESSAGE(), NULL);
    SET @fatal = 1;
  END CATCH;
END;

--------------------------------------------------------------------------------
-- ONLY PROCEED TO TABLE/COLUMN CHECKS IF DB+SCHEMA LOOK OK
--------------------------------------------------------------------------------
IF @fatal = 0
BEGIN
  ------------------------------------------------------------------------------
  -- Checklist of required source tables/cols
  ------------------------------------------------------------------------------
  DECLARE @Checks TABLE(
    id int identity(1,1),
    check_label nvarchar(200),
    table_name  sysname,
    column_list nvarchar(max)
  );

/* ---- ssd_person sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_person: DIM_PERSON',         N'DIM_PERSON',
 N'LEGACY_ID, DIM_PERSON_ID, FORENAME, SURNAME, GENDER_MAIN_CODE, ETHNICITY_MAIN_CODE, BIRTH_DTTM, DOB_ESTIMATED, DEATH_DTTM, NATNL_CODE, EHM_SEN_FLAG, IS_CLIENT'),
(N'ssd_person: FACT_CONTACTS',      N'FACT_CONTACTS',
 N'DIM_PERSON_ID, CONTACT_DTTM'),
(N'ssd_person: FACT_REFERRALS',     N'FACT_REFERRALS',
 N'DIM_PERSON_ID, REFRL_START_DTTM, REFRL_END_DTTM'),
(N'ssd_person: FACT_903_DATA',      N'FACT_903_DATA',
 N'DIM_PERSON_ID, NO_UPN_CODE'),
(N'ssd_person: FACT_CLA_CARE_LEAVERS', N'FACT_CLA_CARE_LEAVERS',
 N'DIM_PERSON_ID, IN_TOUCH_DTTM'),
(N'ssd_person: DIM_CLA_ELIGIBILITY', N'DIM_CLA_ELIGIBILITY',
 N'DIM_PERSON_ID, DIM_LOOKUP_ELIGIBILITY_STATUS_DESC'),
(N'ssd_person: FACT_PERSON_RELATION', N'FACT_PERSON_RELATION',
 N'DIM_PERSON_ID, DIM_PERSON_ID_REL, DIM_LOOKUP_RELTN_TYPE_CODE');

/* ---- ssd_professionals sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_professionals: DIM_WORKER',  N'DIM_WORKER',
 N'DIM_WORKER_ID, STAFF_ID, FORENAME, SURNAME, WORKER_ID_CODE, JOB_TITLE, DEPARTMENT_NAME, FULL_TIME_EQUIVALENCY'),
(N'ssd_professionals: FACT_REFERRALS (caseload)', N'FACT_REFERRALS',
 N'DIM_WORKER_ID, REFRL_START_DTTM, REFRL_END_DTTM');

/* ---- ssd_involvements sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_involvements: FACT_INVOLVEMENTS', N'FACT_INVOLVEMENTS',
 N'DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, IS_ALLOCATED_CW_FLAG, START_DTTM, END_DTTM, DIM_WORKER_ID');

/* ---- ssd_permanence sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_permanence: FACT_CARE_EPISODES', N'FACT_CARE_EPISODES',
 N'FACT_CARE_EPISODES_ID, DIM_PERSON_ID, FACT_CLA_PLACEMENT_ID, FACT_CLA_ID, CARE_REASON_END_CODE, PLACEND'),
(N'ssd_permanence: FACT_ADOPTION', N'FACT_ADOPTION',
 N'DIM_PERSON_ID, START_DTTM, ADOPTION_ORDER_DATE, ADOPTER_SEX, ADOPTER_NUMBER, ADOPTION_DECISION_DATE'),
(N'ssd_permanence: FACT_CLA_PLACEMENT', N'FACT_CLA_PLACEMENT',
 N'FACT_CLA_PLACEMENT_ID, FFA_IS_PLAN_DATE, DIM_LOOKUP_PLACEMENT_TYPE_CODE'),
(N'ssd_permanence: FACT_CLA', N'FACT_CLA',
 N'FACT_CLA_ID, ENTERED_CARE_DATE');

/* ---- ssd_cp_visits sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cp_visits: FACT_CASENOTES', N'FACT_CASENOTES',
 N'FACT_CASENOTE_ID, DIM_PERSON_ID, DIM_LOOKUP_CASNT_TYPE_ID_CODE, EVENT_DTTM, SEEN_FLAG, SEEN_ALONE_FLAG, SEEN_BEDROOM_FLAG'),
(N'ssd_cp_visits: FACT_CP_VISIT',  N'FACT_CP_VISIT',
 N'FACT_CASENOTE_ID, FACT_CP_PLAN_ID');

/* ---- ssd_assessment_factors sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_assessment_factors: FACT_SINGLE_ASSESSMENT', N'FACT_SINGLE_ASSESSMENT',
 N'FACT_SINGLE_ASSESSMENT_ID, DIM_PERSON_ID, FACT_REFERRAL_ID, START_DTTM, FACT_FORM_ID, EXTERNAL_ID'),
(N'ssd_assessment_factors: FACT_FORM_ANSWERS', N'FACT_FORM_ANSWERS',
 N'FACT_FORM_ID, ANSWER_NO, ANSWER, DIM_ASSESSMENT_TEMPLATE_ID_DESC'),
(N'ssd_assessment_factors: FACT_FORMS', N'FACT_FORMS',
 N'FACT_FORM_ID, DIM_PERSON_ID');

/* ---- ssd_department sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_department: DIM_DEPARTMENT', N'DIM_DEPARTMENT',
 N'DIM_DEPARTMENT_ID, NAME, DEPT_ID, DEPT_TYPE_DESCRIPTION');

/* ---- (optional) extra checks used elsewhere in ssd ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_contacts: FACT_CONTACTS', N'FACT_CONTACTS',
 N'FACT_CONTACT_ID, DIM_PERSON_ID, CONTACT_DTTM, DIM_LOOKUP_CONT_SORC_ID, DIM_LOOKUP_CONT_SORC_ID_DESC, OUTCOME_NEW_REFERRAL_FLAG, OUTCOME_EXISTING_REFERRAL_FLAG, OUTCOME_CP_ENQUIRY_FLAG, OUTCOME_NFA_FLAG, OUTCOME_NON_AGENCY_ADOPTION_FLAG, OUTCOME_PRIVATE_FOSTERING_FLAG, OUTCOME_ADVICE_FLAG, OUTCOME_MISSING_FLAG, OUTCOME_OLA_CP_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS'),
(N'ssd_cin_episodes: FACT_REFERRALS', N'FACT_REFERRALS',
 N'FACT_REFERRAL_ID, DIM_PERSON_ID, REFRL_START_DTTM, REFRL_END_DTTM, DIM_LOOKUP_CATEGORY_OF_NEED_CODE, DIM_LOOKUP_CONT_SORC_ID, DIM_LOOKUP_CONT_SORC_ID_DESC, OUTCOME_SINGLE_ASSESSMENT_FLAG, OUTCOME_NFA_FLAG, OUTCOME_STRATEGY_DISCUSSION_FLAG, OUTCOME_CLA_REQUEST_FLAG, OUTCOME_NON_AGENCY_ADOPTION_FLAG, OUTCOME_PRIVATE_FOSTERING_FLAG, OUTCOME_CP_TRANSFER_IN_FLAG, OUTCOME_CP_CONFERENCE_FLAG, OUTCOME_CARE_LEAVER_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS, DIM_DEPARTMENT_ID, DIM_WORKER_ID_DESC'),
(N'ssd_cp_plans: FACT_CP_PLAN', N'FACT_CP_PLAN',
 N'FACT_CP_PLAN_ID, FACT_REFERRAL_ID, FACT_INITIAL_CP_CONFERENCE_ID, DIM_PERSON_ID, START_DTTM, END_DTTM, IS_OLA, INIT_CATEGORY_DESC, CP_CATEGORY_DESC');


  ------------------------------------------------------------------------------
  -- Loop: table exists? then list missing columns (metadata-only; no data reads)
  ------------------------------------------------------------------------------
  DECLARE
    @i int = 1, @n int = (SELECT COUNT(*) FROM @Checks),
    @label nvarchar(200), @tbl sysname, @cols nvarchar(max), @dsql nvarchar(max),
    @nonce char(36) = CONVERT(char(36), NEWID());

  WHILE @i <= @n
  BEGIN
    SELECT @label = check_label, @tbl = table_name, @cols = column_list
    FROM @Checks WHERE id = @i;

    SET @dsql = N'
IF NOT EXISTS (
  SELECT 1
  FROM ' + QUOTENAME(@src_db) + N'.sys.tables t
  JOIN ' + QUOTENAME(@src_db) + N'.sys.schemas s ON s.schema_id = t.schema_id
  WHERE s.name = @sch AND t.name = @tbl
)
BEGIN
  INSERT #ssd_preflight_issues(check_label, details, sql_text)
  VALUES (
    @label,
    N''Table not found: '' + QUOTENAME(@db) + N''.'' + QUOTENAME(@sch) + N''.'' + QUOTENAME(@tbl),
    NULL
  );
END
ELSE
BEGIN
  -- Split comma-separated @cols into rows via XML (trim spaces)
  DECLARE @xml xml =
    CONVERT(xml, N''<c><i>'' + REPLACE(@cols, N'','', N''</i><i>'') + N''</i></c>'');

  ;WITH want AS (
    SELECT CAST(LTRIM(RTRIM(T.c.value(''.'', ''nvarchar(4000)''))) AS sysname) AS col
    FROM @xml.nodes(''/c/i'') AS T(c)
  ),
  have AS (
    SELECT c.name AS col
    FROM ' + QUOTENAME(@src_db) + N'.sys.columns c
    JOIN ' + QUOTENAME(@src_db) + N'.sys.tables  t ON t.object_id = c.object_id
    JOIN ' + QUOTENAME(@src_db) + N'.sys.schemas s ON s.schema_id  = t.schema_id
    WHERE s.name = @sch AND t.name = @tbl
  )
  INSERT #ssd_preflight_issues(check_label, details, sql_text)
  SELECT
    @label,
    N''Missing column: '' + w.col,
    N''SELECT '' + @cols + N'' FROM '' + QUOTENAME(@db) + N''.'' + QUOTENAME(@sch) + N''.'' + QUOTENAME(@tbl) + N'' WHERE 1=0;''
  FROM want w
  LEFT JOIN have h ON h.col = w.col
  WHERE h.col IS NULL
  OPTION (RECOMPILE);
END';

    -- make text unique per run to avoid stale cached plans
    SET @dsql = @dsql + N' -- ' + @nonce;

    EXEC sp_executesql
         @dsql,
         N'@sch sysname, @tbl sysname, @cols nvarchar(max), @label nvarchar(200), @db sysname',
         @src_schema, @tbl, @cols, @label, @src_db;

    SET @i += 1;
  END
END; -- end of @fatal=0 guard

--------------------------------------------------------------------------------
-- REPORT (always SELECT details; opt: raise to fail run)
--------------------------------------------------------------------------------
DECLARE @issue_count int = (SELECT COUNT(*) FROM #ssd_preflight_issues);

IF @issue_count > 0
BEGIN
  -- if we found any col/table absence issues, show them
  SELECT check_label, details, sql_text
  FROM #ssd_preflight_issues
  ORDER BY check_label, details;

  IF @fail_on_error = 1
    RAISERROR('Pre-flight failed: %d issue(s) found. See result set above.', 16, 1, @issue_count);
  ELSE
    PRINT 'Pre-flight completed with issues. See result set above.';
END
ELSE
BEGIN
  PRINT 'Pre-flight OK: all required ssd source tables/columns were found.';
END


