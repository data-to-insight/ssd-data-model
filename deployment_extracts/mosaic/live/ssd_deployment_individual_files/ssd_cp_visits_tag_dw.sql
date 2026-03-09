declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @visit_workflow_step_types table (
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
--Insert workflow step types which are used to capture assessments
insert into @visit_workflow_step_types 
values
	(1187, 'Child protection visit (CSSW)')
--
--Insert the question user codes and question text of questions which are used to record the date of visit
insert into @visit_date_question_user_codes
values
	('cpFLDDateAndTimeOfVisit', 'Actual date and time of visit')
--
insert into @child_seen_question_user_codes
values
	('cpCOLSubjectsFLDChildYPSeen', 'Child or young person seen?')
--
--Insert the exact wording of answers which indicate the child was seen 
insert into @child_seen_answers
values
	('Yes')
--
insert into @child_seen_alone_question_user_codes
values
	('REP_ANXA_cpCOLSubjectsFLDChildYPSeenAlone', 'If yes, child or young person seen alone?')
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
	('question_user_code', 'latest_question_text')
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
	sub.cppv_cp_visit_id,
	(
	select 
		reg.registration_id
	from 
		(
		select 
			mpr.person_id
			,mpr.registration_id
			,mpr.registration_start_date
			,mpr.deregistration_date
			,row_number() over (partition by mpr.person_id order by mpr.registration_start_date desc) seq 
		from dm_registrations mpr
		where mpr.person_id = sub.person_id
			and mpr.is_child_protection_plan = 'Y'
			and mpr.is_temporary_child_protection is null
			and mpr.registration_start_date < sub.cppv_cp_visit_date
		) reg
	where
		reg.seq = 1
	) cppv_cp_plan_id,
	sub.cppv_cp_visit_id,
	sub.cppv_cp_visit_date,
	sub.cppv_cp_visit_seen,
	sub.cppv_cp_visit_seen_alone,
	sub.cppv_cp_visit_bedroom

from
	(
	select 
		stp.person_id,
		-- dbo.append2(stp.workflow_step_id, '.', stp.person_id) cppv_ visit_ id, -- [REVIEW] replaced by below... re-test and remove this line
		dbo.append2(stp.workflow_step_id, '.', stp.person_id) cppv_cp_visit_id,
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
				d.person_id = stp.person_id
			), 
			stp.completed_on
			) cppv_cp_visit_date,
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
		end cppv_cp_visit_seen,
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
		end cppv_cp_visit_seen_alone,
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
					'Y'
			else
				'N'
		end cppv_cp_visit_bedroom
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