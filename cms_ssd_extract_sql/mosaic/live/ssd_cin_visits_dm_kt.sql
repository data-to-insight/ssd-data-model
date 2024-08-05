declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @visit_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @cin_plan_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @visit_date_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @child_seen_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @child_seen_alone_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @child_bedroom_seen_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @child_seen_answers table (
	answer					varchar(1000)
)
--
declare @child_seen_alone_answers table (
	answer					varchar(1000)
)
--
declare @child_bedroom_seen_answers table (
	answer					varchar(1000)
)
--
--Insert workflow step types which are used to capture cin visits
insert into @visit_workflow_step_types 
values
	(1189, 'Child in need visit (CSSW)')
--
--Insert workflow step types which are used to capture cin plans
insert into @cin_plan_workflow_step_types 
values
	(1191, 'Child or young person in need plan (CSSW)')
--
--Insert the question user codes and question text of questions which are used to record the date of visit
insert into @visit_date_question_user_codes
values
	('cinFLDDateOfThisVisit', 'Actual date and time of visit') 
--
insert into @child_seen_question_user_codes
values
	('cinCOLSubjectsFLDChildOrYPSeen', 'Child or young person seen?') 
--
--Insert the exact wording of answers which indicate the child was seen 
insert into @child_seen_answers
values
	('Yes')
--
insert into @child_seen_alone_question_user_codes
values
	('REP_ANXA_cinCOLSubjectsFLDChildOrAlone', 'If yes, child or young person seen alone?') 
--
--Insert the exact wording of answers which indicate the child was seen alone
insert into @child_seen_alone_answers
values
	('Yes')
--
insert into @child_bedroom_seen_question_user_codes
values
	('question_user_code', 'latest_question_text') 
--
insert into @child_bedroom_seen_answers
values
	('answer') 
--
if object_id('tempdb..#text_answers') is not null
	drop table #text_answers
--
select
	cfa.workflow_step_id,
	cfa.form_answer_row_id,
	cfa.question_user_code,
	cfa.text_answer,
	case 
		when cfa.subject_person_id > 0 then 
			cfa.subject_person_id
		else
			sgs.subject_compound_id
	end person_id
into
	#text_answers
from 
	dm_cached_form_answers cfa
inner join dm_cached_form_questions q
on q.mapping_id = cfa.mapping_id
inner join dm_workflow_steps stp 
on stp.workflow_step_id = cfa.workflow_step_id
inner join @visit_workflow_step_types atyp
on atyp.workflow_step_type_id = stp.workflow_step_type_id
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = stp.subgroup_id
	and
	sgs.subject_type_code = 'PER'
where
	q.question_user_code in (
		select
			question_user_code
		from
			@child_seen_question_user_codes
		union 
		select
			question_user_code
		from
			@child_seen_alone_question_user_codes
		union 
		select
			question_user_code
		from
			@child_bedroom_seen_question_user_codes
		)
--
if object_id('tempdb..#date_answers') is not null
	drop table #date_answers
--
select
	cfa.workflow_step_id,
	cfa.form_answer_row_id,
	cfa.question_user_code,
	cfa.date_answer,
	case 
		when cfa.subject_person_id > 0 then 
			cfa.subject_person_id
		else
			sgs.subject_compound_id
	end person_id
into
	#date_answers
from 
	dm_cached_form_answers cfa
inner join dm_cached_form_questions q
on q.mapping_id = cfa.mapping_id
inner join dm_workflow_steps stp 
on stp.workflow_step_id = cfa.workflow_step_id
inner join @visit_workflow_step_types atyp
on atyp.workflow_step_type_id = stp.workflow_step_type_id
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = stp.subgroup_id
	and
	sgs.subject_type_code = 'PER'
where
	q.question_user_code in (
		select
			question_user_code
		from
			@visit_date_question_user_codes
		)
--
select
	sub.cinv_cin_visit_id,
	(
	select 
		cin.workflow_step_id
	from 
		(
		select 
			stp.person_id
			,stp.workflow_step_id
			,stp.started_on
			,stp.completed_on
			,row_number() over (partition by stp.person_id order by stp.started_on desc, stp.workflow_step_id desc) seq 
		from dm_workflow_steps_people_vw stp
		inner join @visit_workflow_step_types atyp
		on atyp.workflow_step_type_id = stp.workflow_step_type_id
		where stp.person_id = sub.person_id
			and stp.step_status in ('STARTED', 'COMPLETED', 'REOPENED')
			and stp.started_on < sub.cinv_cin_visit_date
		) cin
	where
		cin.seq = 1
	) cinv_cin_plan_id,
	sub.cinv_cin_visit_date,
	sub.cinv_cin_visit_seen,
	sub.cinv_cin_visit_seen_alone,
	sub.cinv_cin_visit_bedroom
from
	(
	select 
		stp.person_id,
		dbo.append2(stp.workflow_step_id, '.', stp.person_id) cinv_cin_visit_id,
		coalesce(
			(
			select
				d.date_answer
			from
				#date_answers d
			inner join @visit_date_question_user_codes quc
			on quc.question_user_code = d.question_user_code
			where
				d.workflow_step_id = stp.workflow_step_id
				and
				d.person_id = sgs.subject_compound_id
			), 
			stp.completed_on
			) cinv_cin_visit_date,
		case
			when exists (
				select
					1
				from
					#text_answers lkp
				inner join @child_seen_question_user_codes quc
				on quc.question_user_code = lkp.question_user_code
				inner join @child_seen_answers a
				on a.answer = lkp.text_answer
				where
					lkp.workflow_step_id = stp.workflow_step_id
					and
					lkp.person_id = stp.person_id
				) then
					'Y'
			else
				'N'
		end cinv_cin_visit_seen,
		case
			when exists (
				select
					1
				from
					#text_answers lkp
				inner join @child_seen_alone_question_user_codes quc
				on quc.question_user_code = lkp.question_user_code
				inner join @child_seen_alone_answers a
				on a.answer = lkp.text_answer
				where
					lkp.workflow_step_id = stp.workflow_step_id
					and
					lkp.person_id = stp.person_id
				) then
					'Y'
			else
				'N'
		end cinv_cin_visit_seen_alone,
		case
			when exists (
				select
					1
				from
					#text_answers lkp
				inner join @child_bedroom_seen_question_user_codes quc
				on quc.question_user_code = lkp.question_user_code
				inner join @child_bedroom_seen_answers a
				on a.answer = lkp.text_answer
				where
					lkp.workflow_step_id = stp.workflow_step_id
					and
					lkp.person_id = stp.person_id
				) then
					' Y'
			else
				'N'
		end cinv_cin_visit_bedroom
	from
		dm_workflow_steps_people_vw stp
	inner join @visit_workflow_step_types typ
	on typ.workflow_step_type_id = stp.workflow_step_type_id
	where
		--CRITERIA: Visit was ongoing in the period
		dbo.no_time(stp.started_on) <= @end_date
		and
		dbo.future(dbo.no_time(stp.completed_on)) >= @start_date
		and
		stp.step_status in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
	) sub