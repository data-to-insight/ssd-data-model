/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @nfa_next_actions table (
	workflow_next_action_type_id	numeric(9),
	description						varchar(1000)
)
--
declare @further_sw_intervention_next_actions table (
	workflow_next_action_type_id	numeric(9),
	description						varchar(1000)
)
--
declare @assessment_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @child_seen_during_assessment_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @child_seen_answers table (
	answer						varchar(1000)
)
--
declare @assessment_start_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @assessment_end_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
/******CONFIGURE SCRIPT FOR LOCAL BUILD******/
--Insert assessment next actions that represent no further action
insert into @nfa_next_actions 
values
	(1, 'NFA')
	--,(<additional value>, <additional value>)
--
--Insert assessment next actions that represent further social work intervention
insert into @further_sw_intervention_next_actions 
values
	(2, 'Further Intervention')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture assessments
insert into @assessment_workflow_step_types 
values
	(3, 'C+F Assessment')
	--,(<additional value>, <additional value>)
--
--Insert the question user codes and question text of questions which indicate whether or not the child was seen during assessment
insert into @child_seen_during_assessment_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Was the child seen during the assessment?')
	--,(<additional value>, <additional value>)
--
insert into @assessment_start_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment start date')
	--,(<additional value>, <additional value>)
--
insert into @assessment_end_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment end date')
	--,(<additional value>, <additional value>)
--
--Insert the exact wording of answers which indicate the child was seen during assessment
insert into @child_seen_answers
values
	('Child seen')
	--,(<additional value>)
--
/******EXECUTE CODE******/
if object_id('tempdb..#date_answers') is not null
	drop table #date_answers
--
select
	stp.WORKFLOW_STEP_ID,
	que.QUESTION_USER_CODE,
	dates.DATE_ANSWER,
	r.form_answer_row_id,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#date_answers
from
	MO_FORM_DATE_ANSWERS dates
inner join dbo.MO_QUESTIONS que 
on que.QUESTION_ID = dates.QUESTION_ID
inner join MO_FORMS frm
on frm.FORM_ID = dates.FORM_ID
inner join MO_WORKFLOW_STEPS stp 
on stp.WORKFLOW_STEP_ID = frm.WORKFLOW_STEP_ID
inner join mo_form_answer_rows r
on r.form_answer_row_id = dates.form_answer_row_id
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	que.QUESTION_USER_CODE in (
		select q.question_user_code from @assessment_start_date_question_user_codes q
		union
		select q.question_user_code from @assessment_end_date_question_user_codes q
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		select s.workflow_step_type_id from @assessment_workflow_step_types s
	)
--
if object_id('tempdb..#lookup_answers') is not null
	drop table #lookup_answers
--
select
	stp.workflow_step_id,
	answ.FORM_ANSWER_ROW_ID,
	q.QUESTION_USER_CODE,
	lkp.ANSWER lookup_answer,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#lookup_answers
from
	mo_form_lookup_answers answ
--JOIN: find the form details
inner join mo_forms forms
on forms.form_id = answ.form_id
--JOIN: find the template used
inner join mo_templates temp
on temp.template_id = forms.template_id
--JOIN: find the question version
inner join mo_questions q
on q.question_id = answ.question_id
--JOIN: find the lookup text for the answer
inner join mo_question_lookups lkp
on lkp.question_lookup_id = answ.question_lookup_id
--JOIN: Find the step
inner join mo_workflow_steps stp
on stp.workflow_step_id = forms.workflow_step_id
inner join mo_form_answer_rows r
on r.form_answer_row_id = answ.form_answer_row_id
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
inner join @assessment_workflow_step_types atyp
on atyp.workflow_step_type_id = stp.WORKFLOW_STEP_TYPE_ID
where
	q.QUESTION_USER_CODE in (
		select q.question_user_code from @child_seen_during_assessment_question_user_codes q
	)
--
select
	*
from
	(
		select
			CONCAT(CAST(sgs.subject_compound_id AS INT), CAST(STP.WORKFLOW_STEP_ID AS INT)) cina_assessment_id,
			sgs.SUBJECT_COMPOUND_ID cina_person_id,
			null cina_referral_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @assessment_start_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = stp.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when stp.step_status in ('STARTED', 'REOPENED', 'COMPLETED') then
						dbo.no_time(stp.started_on)
				end,
				case
					when stp.step_status = 'INCOMING' then
						dbo.no_time(stp.incoming_on)
				end
			) cina_assessment_start_date,
			case
				when stp.step_status = 'COMPLETED' then
					coalesce(
						(
							select
								max(ans.date_answer)
							from
								#date_answers ans
							inner join @assessment_end_date_question_user_codes q
							on q.question_user_code = ans.question_user_code
							where
								ans.workflow_step_id = stp.workflow_step_id
								and
								ans.person_id = sgs.subject_compound_id
						),
						dbo.no_time(stp.completed_on)
					)
			end cina_assessment_auth_date,
			case
				when exists (
						select
							1
						from
							#lookup_answers lkp
						inner join @child_seen_during_assessment_question_user_codes quc
						on quc.question_user_code = lkp.QUESTION_USER_CODE
						inner join @child_seen_answers seen
						on seen.answer = lkp.lookup_answer
						where
							lkp.WORKFLOW_STEP_ID = stp.WORKFLOW_STEP_ID
							and
							lkp.person_id = sgs.SUBJECT_COMPOUND_ID
					) then
					' Y'
				else
					'N'
			end cina_assessment_child_seen,
			case
				when exists (
						select
							1
						from
							MO_WORKFLOW_LINKS lnk
						inner join MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join MO_WORKFLOW_STEPS nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join MO_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @further_sw_intervention_next_actions inter
						on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.workflow_step_id
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					) then
					'Y'
				else
					'N'
			end cina_assessment_outcome_further_intervention,
			case
				when exists (
						select
							1
						from
							MO_WORKFLOW_LINKS lnk
						inner join MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join MO_WORKFLOW_STEPS nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join MO_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @nfa_next_actions nfa
						on nfa.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.workflow_step_id
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					)
					and
					not exists (
						select
							1
						from
							MO_WORKFLOW_LINKS lnk
						inner join MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join MO_WORKFLOW_STEPS nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join MO_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @further_sw_intervention_next_actions inter
						on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.workflow_step_id
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					) then
				'Y'
				else
					'N'
			end cina_assessment_outcome_nfa,
			stp.RESPONSIBLE_TEAM_ID cina_assessment_team,
			stp.ASSIGNEE_ID cina_assessment_worker_id
		from
			MO_WORKFLOW_STEPS stp
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.subgroup_id = stp.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @assessment_workflow_step_types atyp
		on atyp.workflow_step_type_id = stp.WORKFLOW_STEP_TYPE_ID
		where
			--CRITERIA: Assessment was ongoing in the period
			dbo.no_time(stp.started_on) <= @end_date
			and
			dbo.future(dbo.no_time(stp.completed_on)) >= @start_date
			and
			stp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
	) x
where
	x.cina_assessment_auth_date >= @start_date
	and
	x.cina_assessment_start_date <= @end_date