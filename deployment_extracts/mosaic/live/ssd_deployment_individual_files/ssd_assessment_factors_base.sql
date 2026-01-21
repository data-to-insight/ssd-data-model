/* Standalone test harness 

-- Ref: orchestrator includes. Re-include here if running script stand-alone
    DECLARE @number_of_years_to_include 		INT = 1,
    DECLARE @start_date 						DATETIME= '20220401';
    DECLARE @end_date   						DATETIME = '20231231';

*/




--
declare @assessment_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @assessment_factor_question_user_codes table (
	question_user_code				varchar(128),
	factor_code						varchar(1000)
)
--
--
--
--
--
--
--
--
--
--
--Insert workflow step types which are used to capture assessments
insert into @assessment_workflow_step_types 
values
	(1186, 'C+F Assessment')
	--,(<additional value>, <additional value>)
--
insert into @assessment_factor_question_user_codes
values
	('REP_CIN_cinCOLRisksIdentifiedSRSFLDA1','1A'),
	('REP_CIN_cinCOLRisksIdentifiedSRSFLDA2','2A'),
	('REP_CIN_cinCOLRisksIdentifiedSRSFLDA3','3A'),
	('REP_CIN_cinCOLRisksIdentifiedSRSFLDA4','4A'),
	('REP_CIN_cinCOLRisksIdentifiedSRSFLDA5','5A')
	--,(<additional value>, <additional value>)
--
--
--
--
--
--
--
--
--
--
IF OBJECT_ID('tempdb..#boolean_answers') IS NOT NULL
	DROP TABLE #boolean_answers
--
select
	stp.WORKFLOW_STEP_ID assessment_workflow_step_id,
	que.QUESTION_USER_CODE,
	bool.BOOLEAN_ANSWER,
	r.handler_row_identifier person_id
	into
	#boolean_answers
from
	MO_FORM_BOOLEAN_ANSWERS bool
inner join dbo.MO_QUESTIONS que 
on que.QUESTION_ID = bool.QUESTION_ID
inner join dbo.MO_FORMS frm
on frm.FORM_ID = bool.FORM_ID
inner join MO_WORKFLOW_STEPS stp 
on stp.WORKFLOW_STEP_ID = frm.WORKFLOW_STEP_ID
inner join mo_form_answer_rows r
on r.form_answer_row_id = bool.form_answer_row_id
inner join @assessment_workflow_step_types typ
on typ.workflow_step_type_id = stp.workflow_step_type_id
where
	que.QUESTION_USER_CODE in (
		select q.question_user_code from @assessment_factor_question_user_codes q
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		select s.workflow_step_type_id from @assessment_workflow_step_types s
	)
--
--
--
--
--
--
--
--
--
--
;WITH RawFactors AS (
    SELECT
        CONCAT(CAST(sgs.subject_compound_id AS INT), CAST(stp.WORKFLOW_STEP_ID AS INT)) AS cinf_assessment_id,
        NULLIF(LTRIM(RTRIM(fct.factor_code)), '') AS factor_code
    FROM MO_WORKFLOW_STEPS stp
    INNER JOIN MO_SUBGROUP_SUBJECTS sgs
        ON sgs.subgroup_id = stp.SUBGROUP_ID
        AND sgs.SUBJECT_TYPE_CODE = 'PER'
    INNER JOIN @assessment_workflow_step_types atyp
        ON atyp.workflow_step_type_id = stp.WORKFLOW_STEP_TYPE_ID
    INNER JOIN #boolean_answers bool
        ON bool.assessment_workflow_step_id = stp.workflow_step_id
        AND bool.person_id = sgs.subject_compound_id
        AND bool.BOOLEAN_ANSWER = 'Y'
    INNER JOIN @assessment_factor_question_user_codes fct
        ON fct.question_user_code = bool.QUESTION_USER_CODE
    WHERE
        dbo.no_time(stp.started_on) <= @end_date
        AND dbo.future(dbo.no_time(stp.completed_on)) >= @start_date
        AND stp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
),
Parsed AS (
    SELECT DISTINCT
        r.cinf_assessment_id,
        r.factor_code,
        TRY_CONVERT(int, LEFT(r.factor_code, CASE
            WHEN PATINDEX('%[^0-9]%', r.factor_code) = 0 THEN LEN(r.factor_code)
            ELSE PATINDEX('%[^0-9]%', r.factor_code) - 1
        END)) AS num_part,
        CASE
            WHEN PATINDEX('%[^0-9]%', r.factor_code) = 0 THEN ''
            ELSE SUBSTRING(r.factor_code, PATINDEX('%[^0-9]%', r.factor_code), 10)
        END AS alpha_part
    FROM RawFactors r
    WHERE r.factor_code IS NOT NULL
)
SELECT
    NULL AS cinf_table_id, -- [REVIEW] null here not ideal. Mosaic LA feedback welcomed.
    p.cinf_assessment_id,
    N'[' +
    STUFF((
        SELECT N', ' + QUOTENAME(x.factor_code, '"')
        FROM Parsed x
        WHERE x.cinf_assessment_id = p.cinf_assessment_id
        ORDER BY x.num_part, x.alpha_part, x.factor_code
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')
    + N']' AS cinf_assessment_factors_json
FROM Parsed p
GROUP BY p.cinf_assessment_id;
