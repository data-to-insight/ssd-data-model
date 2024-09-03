declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @immunisation_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @immunisations_up_to_date_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @immunisations_up_to_date_answers table (
	answer					varchar(1000)
)
--
--Insert workflow step types which are used to capture that immunisations are up to date
insert into @immunisation_workflow_step_types 
values
	(406, 'LAC Health Assessment')
	,(1239, 'Health assessment (CSSW)')
--
--Insert the question user codes and question text of questions which are used to record that immunisations are up to date
insert into @immunisations_up_to_date_question_user_codes
values
	('lac.ihr09.immsuptodate', 'Immunisations up to date?')
	,('lac.ihr10.immsuptodate', 'Immunisations up to date?')
	,('lacFLDPartCHealthRecommImmunisations', 'Immunisations up to date?')
--
--Insert the exact wording of answers which indicate that immunisations are up to date
insert into @immunisations_up_to_date_answers
values
	('Yes')
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
inner join @immunisation_workflow_step_types atyp
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
			@immunisations_up_to_date_question_user_codes
		)
--
select 
	sub.clai_person_id,
	sub.clai_immunisations_status
from 
	(
	select 
		sgs.subject_compound_id clai_person_id,
		case
			when exists (
				select
					1
				from
					@immunisations_up_to_date_answers a
				where 
					a.answer = lkp.text_answer
				)
			then
				'Y'
			else
				'N'
		end clai_immunisations_status,
		row_number() over (partition by sgs.subject_compound_id order by stp.started_on desc, stp.workflow_step_id desc) seq 
	from
		mo_workflow_steps stp
	inner join mo_subgroup_subjects sgs
	on sgs.subgroup_id = stp.subgroup_id
		and
		sgs.subject_type_code = 'PER'
	inner join @immunisation_workflow_step_types typ
	on typ.workflow_step_type_id = stp.workflow_step_type_id

	inner join #text_answers lkp
	on lkp.workflow_step_id = stp.workflow_step_id
		and
		lkp.person_id = sgs.subject_compound_id

	inner join @immunisations_up_to_date_question_user_codes quc
	on quc.question_user_code = lkp.question_user_code

	where
		stp.step_status in ('STARTED', 'REOPENED', 'COMPLETED')
	) sub
where 
	sub.seq = 1



