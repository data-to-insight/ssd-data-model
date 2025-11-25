/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 December 2023'
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
inner join .MO_QUESTIONS que 
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
select
	CONCAT(CAST(sgs.subject_compound_id AS INT), CAST(STP.WORKFLOW_STEP_ID AS INT)) cina_assessment_id,
	fct.factor_code cinf_assessment_factors_json
from
	MO_WORKFLOW_STEPS stp
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.subgroup_id = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
inner join @assessment_workflow_step_types atyp
on atyp.workflow_step_type_id = stp.WORKFLOW_STEP_TYPE_ID
inner join #boolean_answers bool
on bool.assessment_workflow_step_id = stp.workflow_step_id
and
bool.person_id = sgs.subject_compound_id
and
bool.BOOLEAN_ANSWER = 'Y'
inner join @assessment_factor_question_user_codes fct
on fct.question_user_code = bool.QUESTION_USER_CODE
where
	--CRITERIA: Assessment was ongoing in the period
	dbo.no_time(stp.started_on) <= @end_date
	and
	dbo.future(dbo.no_time(stp.completed_on)) >= @start_date
	and
	stp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')