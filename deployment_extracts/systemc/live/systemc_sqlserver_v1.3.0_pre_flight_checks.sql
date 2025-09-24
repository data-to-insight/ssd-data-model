-- This is SystemC/LL default. Edit/point to your reporting db
USE HDM_Local;


SET NOCOUNT ON;

--------------------------------------------------------------------------------
-- CONFIG (CMS Data sources)
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
(N'ssd_person: DIM_PERSON',
 N'DIM_PERSON',
 N'LEGACY_ID, DIM_PERSON_ID, FORENAME, SURNAME, GENDER_MAIN_CODE, ETHNICITY_MAIN_CODE, BIRTH_DTTM, DOB_ESTIMATED, DEATH_DTTM, NATNL_CODE, IS_CLIENT, EHM_SEN_FLAG'),
(N'ssd_person: FACT_CONTACTS',
 N'FACT_CONTACTS',
 N'DIM_PERSON_ID, CONTACT_DTTM'),
(N'ssd_person: FACT_REFERRALS',
 N'FACT_REFERRALS',
 N'DIM_PERSON_ID, REFRL_START_DTTM, REFRL_END_DTTM'),
(N'ssd_person: FACT_903_DATA',
 N'FACT_903_DATA',
 N'DIM_PERSON_ID, NO_UPN_CODE'),
(N'ssd_person: FACT_CLA_CARE_LEAVERS',
 N'FACT_CLA_CARE_LEAVERS',
 N'DIM_PERSON_ID, IN_TOUCH_DTTM'),
(N'ssd_person: DIM_CLA_ELIGIBILITY',
 N'DIM_CLA_ELIGIBILITY',
 N'DIM_PERSON_ID, DIM_LOOKUP_ELIGIBILITY_STATUS_DESC');

/* mother/related person lookups (used for mother linkage) */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_mother: FACT_PERSON_RELATION',
 N'FACT_PERSON_RELATION',
 N'FACT_PERSON_RELATION_ID, DIM_PERSON_ID, DIM_RELATED_PERSON_ID, DIM_RELATED_PERSON_DOB, DIM_LOOKUP_RELTN_TYPE_CODE, END_DTTM');

/* addresses in use by ssd_address (no joins required here) */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_address: DIM_PERSON_ADDRESS',
 N'DIM_PERSON_ADDRESS',
 N'DIM_PERSON_ID, START_DTTM, END_DTTM, ROOM_NO, FLOOR_NO, FLAT_NO, BUILDING, HOUSE_NO, STREET, TOWN, POSTCODE, UPRN, EASTING, NORTHING'); -- fields used in ssd_address. :contentReference[oaicite:0]{index=0}


/* ---- ssd_professionals sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_professionals: DIM_WORKER',
 N'DIM_WORKER',
 N'DIM_WORKER_ID, STAFF_ID, FORENAME, SURNAME, WORKER_ID_CODE, JOB_TITLE, DEPARTMENT_NAME, FULL_TIME_EQUIVALENCY'),
(N'ssd_professionals: FACT_REFERRALS (caseload)',
 N'FACT_REFERRALS',
 N'DIM_WORKER_ID, REFRL_START_DTTM, REFRL_END_DTTM');


/* ---- ssd_involvements sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_involvements: FACT_INVOLVEMENTS',
 N'FACT_INVOLVEMENTS',
 N'DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, IS_ALLOCATED_CW_FLAG, START_DTTM, END_DTTM, DIM_WORKER_ID');


/* ---- ssd_permanence / cla-episodes sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cla_episodes: FACT_CARE_EPISODES',
 N'FACT_CARE_EPISODES',
 N'FACT_CARE_EPISODES_ID, DIM_PERSON_ID, FACT_CLA_PLACEMENT_ID, CARE_START_DATE, CARE_REASON_DESC, CIN_903_CODE, CARE_END_DATE, CARE_REASON_END_DESC'),
(N'ssd_permanence: FACT_ADOPTION',
 N'FACT_ADOPTION',
 N'DIM_PERSON_ID, DECISION_DTTM, SIBLING_GROUP, NUMBER_TOGETHER, NUMBER_APART, PLACEMENT_ORDER_DTTM, MATCHING_DTTM, '
 + N'DIM_LOOKUP_ADOPTER_GENDER_CODE, DIM_LOOKUP_ADOPTER_LEGAL_STATUS_CODE, NO_OF_ADOPTERS, FOSTER_TO_ADOPT_DTTM, '
 + N'NO_LONGER_PLACED_DTTM, DIM_LOOKUP_ADOP_REASON_CEASED_CODE, ADOPTION_SOCIAL_WORKER_ID'),
(N'ssd_permanence: FACT_CLA_PLACEMENT',
 N'FACT_CLA_PLACEMENT',
 N'FACT_CLA_PLACEMENT_ID, FFA_IS_PLAN_DATE, DIM_LOOKUP_PLACEMENT_TYPE_CODE'),
(N'ssd_cla_episodes: FACT_CLA',
 N'FACT_CLA',
 N'FACT_CLA_ID, FACT_REFERRAL_ID, START_DTTM');

/* ---- ssd_cla_reviews sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cla_reviews: FACT_CLA_REVIEW', N'FACT_CLA_REVIEW',
 N'FACT_CLA_REVIEW_ID, FACT_CLA_ID, DUE_DTTM, MEETING_DTTM, FACT_MEETING_ID'),
(N'ssd_cla_reviews: FACT_MEETINGS', N'FACT_MEETINGS',
 N'FACT_MEETING_ID, ACTUAL_DTTM'),
(N'ssd_cla_reviews: FACT_MEETING_SUBJECTS', N'FACT_MEETING_SUBJECTS',
 N'FACT_MEETINGS_ID, DIM_PERSON_ID, DIM_LOOKUP_PARTICIPATION_CODE_DESC');


/* ---- ssd_cp_visits sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cp_visits: FACT_CASENOTES',
 N'FACT_CASENOTES',
 N'FACT_CASENOTE_ID, DIM_PERSON_ID, DIM_LOOKUP_CASNT_TYPE_ID_CODE, EVENT_DTTM, SEEN_FLAG, SEEN_ALONE_FLAG, SEEN_BEDROOM_FLAG'),
(N'ssd_cp_visits: FACT_CP_VISIT',
 N'FACT_CP_VISIT',
 N'FACT_CP_VISIT_ID, DIM_PERSON_ID, FACT_CASENOTE_ID, FACT_CP_PLAN_ID, VISIT_DTTM');


/* ---- ssd_assessment_factors & ssd_cin_assessments sources ---- */
/* Form answers used for 'seen'/auth dates/factor codes */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cin_assessments: FACT_FORM_ANSWERS',
 N'FACT_FORM_ANSWERS',
 N'FACT_FORM_ID, ANSWER_NO, ANSWER, DIM_ASSESSMENT_TEMPLATE_ID_DESC, DIM_ASSESSMENT_TEMPLATE_QUESTION_ID_DESC'),
(N'ssd_assessment_factors: FACT_FORM_ANSWERS',
 N'FACT_FORM_ANSWERS',
 N'FACT_FORM_ID, ANSWER_NO, ANSWER, DIM_ASSESSMENT_TEMPLATE_ID_DESC');

/* Single assessment linkers (authorised/seen derivations) */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_assessment_factors: FACT_SINGLE_ASSESSMENT',
 N'FACT_SINGLE_ASSESSMENT',
 N'EXTERNAL_ID, FACT_FORM_ID'),
(N'ssd_cin_assessments: FACT_SINGLE_ASSESSMENT',
 N'FACT_SINGLE_ASSESSMENT',
 N'FACT_SINGLE_ASSESSMENT_ID, DIM_PERSON_ID, FACT_REFERRAL_ID, START_DTTM, FACT_FORM_ID, EXTERNAL_ID, DIM_LOOKUP_STEP_SUBSTATUS_CODE, '
 + N'OUTCOME_NFA_FLAG, OUTCOME_NFA_S47_END_FLAG, OUTCOME_STRATEGY_DISCUSSION_FLAG, OUTCOME_CLA_REQUEST_FLAG, OUTCOME_PRIVATE_FOSTERING_FLAG, '
 + N'OUTCOME_LEGAL_ACTION_FLAG, OUTCOME_PROV_OF_SERVICES_FLAG, OUTCOME_PROV_OF_SB_CARE_FLAG, OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '
 + N'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, OUTCOME_OTHER_ACTIONS_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS, '
 + N'COMPLETED_BY_DEPT_ID, COMPLETED_BY_USER_ID');


/* ---- ssd_cin_plans sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_cin_plans: FACT_CARE_PLAN_SUMMARY',
 N'FACT_CARE_PLAN_SUMMARY',
 N'FACT_CARE_PLAN_SUMMARY_ID, FACT_REFERRAL_ID, DIM_PERSON_ID, START_DTTM, END_DTTM, DIM_LOOKUP_PLAN_TYPE_CODE, DIM_LOOKUP_PLAN_STATUS_ID_CODE'),
(N'ssd_cin_plans: FACT_CARE_PLANS',
 N'FACT_CARE_PLANS',
 N'FACT_CARE_PLAN_SUMMARY_ID, DIM_PLAN_COORD_DEPT_ID, DIM_PLAN_COORD_ID');


/* ---- ssd_initial_cp_conference sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_initial_cp_conference: FACT_CP_CONFERENCE', N'FACT_CP_CONFERENCE',
 N'FACT_CP_CONFERENCE_ID, FACT_MEETING_ID, FACT_S47_ID, DIM_PERSON_ID, FACT_REFERRAL_ID, TRANSFER_IN_FLAG, DUE_DTTM, ' +
 N'OUTCOME_NFA_FLAG, OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, OUTCOME_SINGLE_ASSESSMENT_FLAG, OUTCOME_PROV_OF_SERVICES_FLAG, ' +
 N'OUTCOME_CP_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS'),
(N'ssd_initial_cp_conference: FACT_MEETINGS', N'FACT_MEETINGS',
 N'FACT_MEETING_ID, ACTUAL_DTTM, DIM_LOOKUP_MTG_TYPE_ID_CODE'),
(N'ssd_initial_cp_conference: FACT_CP_PLAN', N'FACT_CP_PLAN',
 N'FACT_CP_PLAN_ID, FACT_INITIAL_CP_CONFERENCE_ID');



-- ---- ssd_s47_enquiry sources ----
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_s47_enquiry: FACT_S47', N'FACT_S47',
 N'FACT_S47_ID, DIM_PERSON_ID, FACT_REFERRAL_ID, START_DTTM, END_DTTM, ' +
 N'OUTCOME_NFA_FLAG, OUTCOME_CP_CONFERENCE_FLAG, OUTCOME_NFA_CONTINUE_SINGLE_FLAG, ' +
 N'OUTCOME_LEGAL_ACTION_FLAG, OUTCOME_PROV_OF_SERVICES_FLAG, OUTCOME_PROV_OF_SB_CARE_FLAG, ' +
 N'OUTCOME_MONITOR_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS, ' +
 N'COMPLETED_BY_DEPT_ID, COMPLETED_BY_USER_STAFF_ID');

/* ---- ssd_sdq_scores sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_sdq_scores: FACT_FORMS',
 N'FACT_FORMS',
 N'FACT_FORM_ID, DIM_PERSON_ID'),
(N'ssd_sdq_scores: FACT_FORM_ANSWERS',
 N'FACT_FORM_ANSWERS',
 N'FACT_FORM_ID, ANSWER_NO, ANSWER, DIM_ASSESSMENT_TEMPLATE_ID_DESC');


/* ---- ssd_department sources ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_department: DIM_DEPARTMENT',
 N'DIM_DEPARTMENT',
 N'DIM_DEPARTMENT_ID, NAME, DEPT_ID, DEPT_TYPE_DESCRIPTION'); -- used to build ssd_department. :contentReference[oaicite:5]{index=5}


/* ---- (optional) extra checks used elsewhere in SSD ---- */
INSERT @Checks(check_label, table_name, column_list) VALUES
(N'ssd_contacts: FACT_CONTACTS',
 N'FACT_CONTACTS',
 N'FACT_CONTACT_ID, DIM_PERSON_ID, CONTACT_DTTM, DIM_LOOKUP_CONT_SORC_ID, DIM_LOOKUP_CONT_SORC_ID_DESC, OUTCOME_NEW_REFERRAL_FLAG, OUTCOME_EXISTING_REFERRAL_FLAG, OUTCOME_CP_ENQUIRY_FLAG, OUTCOME_NFA_FLAG, OUTCOME_NON_AGENCY_ADOPTION_FLAG, OUTCOME_PRIVATE_FOSTERING_FLAG, OUTCOME_ADVICE_FLAG, OUTCOME_MISSING_FLAG, OUTCOME_OLA_CP_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS'),
(N'ssd_cin_episodes: FACT_REFERRALS',
 N'FACT_REFERRALS',
 N'FACT_REFERRAL_ID, DIM_PERSON_ID, REFRL_START_DTTM, REFRL_END_DTTM, DIM_LOOKUP_CATEGORY_OF_NEED_CODE, DIM_LOOKUP_CONT_SORC_ID, DIM_LOOKUP_CONT_SORC_ID_DESC, OUTCOME_SINGLE_ASSESSMENT_FLAG, OUTCOME_NFA_FLAG, OUTCOME_STRATEGY_DISCUSSION_FLAG, OUTCOME_CLA_REQUEST_FLAG, OUTCOME_NON_AGENCY_ADOPTION_FLAG, OUTCOME_PRIVATE_FOSTERING_FLAG, OUTCOME_CP_TRANSFER_IN_FLAG, OUTCOME_CP_CONFERENCE_FLAG, OUTCOME_CARE_LEAVER_FLAG, OTHER_OUTCOMES_EXIST_FLAG, TOTAL_NO_OF_OUTCOMES, OUTCOME_COMMENTS, DIM_DEPARTMENT_ID, DIM_WORKER_ID_DESC'),
(N'ssd_cp_plans: FACT_CP_PLAN',
 N'FACT_CP_PLAN',
 N'FACT_CP_PLAN_ID, FACT_REFERRAL_ID, FACT_INITIAL_CP_CONFERENCE_ID, DIM_PERSON_ID, START_DTTM, END_DTTM, IS_OLA, INIT_CATEGORY_DESC, CP_CATEGORY_DESC'),

/* CLA substance misuse (used by ssd_cla_substance_misuse) */
(N'ssd_cla_substance_misuse: FACT_SUBSTANCE_MISUSE',
 N'FACT_SUBSTANCE_MISUSE',
 N'FACT_SUBSTANCE_MISUSE_ID, DIM_PERSON_ID, START_DTTM, DIM_LOOKUP_SUBSTANCE_TYPE_CODE, ACCEPT_FLAG'); -- fields used by insert. :contentReference[oaicite:6]{index=6}

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






-- /* Fuzzy finder for cols similar to missing names (SQL Server 2016+) */
-- SET NOCOUNT ON;

-- DECLARE @src_db     sysname = N'HDM';
-- DECLARE @src_schema sysname = N'Child_Social';  -- set NULL to search all schemas

-- -- Build col catalog (tables + views) from @src_db / optional @src_schema
-- IF OBJECT_ID('tempdb..#col_catalog') IS NOT NULL DROP TABLE #col_catalog;
-- CREATE TABLE #col_catalog(
--   schema_name sysname,
--   table_name  sysname,
--   column_name sysname,
--   object_type char(2)  -- 'U' table, 'V' view
-- );

-- DECLARE @sql nvarchar(max);
-- SET @sql = N'
-- SELECT s.name AS schema_name, o.name AS table_name, c.name AS column_name, o.type AS object_type
-- FROM ' + QUOTENAME(@src_db) + N'.sys.columns AS c
-- JOIN ' + QUOTENAME(@src_db) + N'.sys.objects AS o ON o.object_id = c.object_id
-- JOIN ' + QUOTENAME(@src_db) + N'.sys.schemas AS s ON s.schema_id = o.schema_id
-- WHERE o.type IN (''U'',''V'') AND o.is_ms_shipped = 0'
-- + CASE WHEN @src_schema IS NULL THEN N'' ELSE N' AND s.name = @s' END + N';';

-- EXEC sp_executesql @sql, N'@s sysname', @src_schema;

-- -- -- Optional sanity
-- -- SELECT TOP 5 * FROM #col_catalog ORDER BY schema_name, table_name, column_name;

-- -- needles (trying to locate)
-- DECLARE @Needles TABLE(
--   expected_table  sysname,
--   missing_column  sysname
-- );

-- INSERT @Needles(expected_table, missing_column) VALUES
-- (N'FACT_ADOPTION',        N'ADOPTER_NUMBER'),
-- (N'FACT_ADOPTION',        N'ADOPTER_SEX'),
-- (N'FACT_ADOPTION',        N'ADOPTION_DECISION_DATE'),
-- (N'FACT_ADOPTION',        N'ADOPTION_ORDER_DATE'),
-- (N'FACT_CLA',             N'ENTERED_CARE_DATE'),
-- (N'FACT_PERSON_RELATION', N'DIM_PERSON_ID_REL');

-- -- Fuzzy match / ranking
-- ;WITH N AS (
--   SELECT expected_table,
--          missing_column,
--          UPPER(missing_column) AS mc,
--          REPLACE(UPPER(missing_column), N'_', N'') AS mc_clean
--   FROM @Needles
-- ),
-- C AS (
--     -- normalised candidate list of cols from catalog so fuzzy matcher can compare names
--   SELECT schema_name, table_name, column_name,
--          UPPER(column_name) AS cn,
--          REPLACE(UPPER(column_name), N'_', N'') AS cn_clean
--   FROM #col_catalog
-- ),
-- Tok AS (
--   -- tokenise missing name on underscores (keep tokens >= 3 chars)
--   SELECT n.expected_table, n.missing_column,
--          UPPER(LTRIM(RTRIM(T.i.value('.', 'nvarchar(4000)')))) AS token
--   FROM N
--   CROSS APPLY (VALUES (CONVERT(xml, N'<c><i>' + REPLACE(n.missing_column, N'_', N'</i><i>') + N'</i></c>'))) X(x)
--   CROSS APPLY X.x.nodes('/c/i') AS T(i)
--   WHERE LEN(UPPER(LTRIM(RTRIM(T.i.value('.', 'nvarchar(4000)'))))) >= 3
-- ),
-- Hits AS (
--   -- LEFT JOIN C == keep one row per needle even if catalog empty
--   SELECT
--     N.expected_table,
--     N.missing_column,
--     C.schema_name,
--     C.table_name,
--     C.column_name,
--     CASE WHEN C.cn       = N.mc       THEN 1 ELSE 0 END AS exact_match,
--     CASE WHEN C.cn_clean = N.mc_clean THEN 1 ELSE 0 END AS exact_nounder,
--     SUM(CASE WHEN C.cn LIKE N'%' + Tok.token + N'%' THEN 1 ELSE 0 END) AS token_hits,
--     COUNT(Tok.token) AS tokens_total,
--     CASE WHEN C.cn IS NULL THEN 999 ELSE ABS(LEN(C.cn) - LEN(N.mc)) END AS len_delta,
--     CASE WHEN C.cn IS NOT NULL
--               AND (C.cn_clean LIKE N'%' + N.mc_clean + N'%'
--                    OR N.mc_clean LIKE N'%' + C.cn_clean + N'%')
--          THEN 1 ELSE 0 END AS contains_clean
--   FROM N
--   LEFT JOIN C ON 1 = 1
--   LEFT JOIN Tok
--     ON Tok.expected_table = N.expected_table
--    AND Tok.missing_column = N.missing_column
--   GROUP BY
--     N.expected_table, N.missing_column,
--     C.schema_name, C.table_name, C.column_name,
--     C.cn, N.mc, C.cn_clean, N.mc_clean
-- ),
-- Ranked AS (
--   SELECT *,
--          (exact_match*100) + (exact_nounder*90) + (contains_clean*20)
--          + (COALESCE(token_hits,0)*10) - (CASE WHEN len_delta>0 THEN len_delta ELSE 0 END) AS score,
--          ROW_NUMBER() OVER (
--            PARTITION BY expected_table, missing_column
--            ORDER BY
--              exact_match DESC,
--              exact_nounder DESC,
--              contains_clean DESC,
--              token_hits DESC,
--              len_delta ASC,
--              schema_name, table_name, column_name
--          ) AS rn
--   FROM Hits
-- )
-- -- Always return up to 10 rows per needle (or single NULL-candidate row if none)
-- SELECT
--   n.expected_table,
--   n.missing_column,
--   r.schema_name     AS candidate_schema,
--   r.table_name      AS candidate_table,
--   r.column_name     AS candidate_column,
--   r.score,
--   r.exact_match,
--   r.exact_nounder,
--   r.token_hits,
--   r.tokens_total,
--   r.len_delta,
--   r.contains_clean
-- FROM (SELECT DISTINCT expected_table, missing_column FROM @Needles) AS n
-- LEFT JOIN Ranked AS r
--   ON r.expected_table = n.expected_table
--  AND r.missing_column = n.missing_column
--  AND r.rn <= 10
-- ORDER BY
--   n.expected_table,
--   n.missing_column,
--   r.score DESC,
--   r.schema_name,      
--   r.table_name,      
--   r.column_name;   
