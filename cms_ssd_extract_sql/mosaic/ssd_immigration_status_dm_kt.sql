/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @immigration_status_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @immigration_status_start_date_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @immigration_status_end_date_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
--Insert the question user codes and question text of questions which are used to record a child's immigration status
insert into @immigration_status_question_user_codes
values
	('acFLDAllAboutMeLeavingImmigrationStatusList', 'Immigration Status')
	,('csn_ina_addsuppfact_immig_status', 'What is your immigration status?')
	,('csn_ina_addsuppfact_immig_status', 'What is the client''s immigration status?')
	,('csn_couns_immigration', 'Immigration status')
	,('uascImmigStat', 'Immigration Status')
	,('csn_ina_addsuppfact_immig_status', 'What is the client''s immigration status?')
	,('62CD0406-2F07-0FF5-512C-A7FA0DBAD602', 'Citizenship/Immigration status')
	,('acFLDAllAboutMeLeavingImmigrationStatusList', 'Immigration Status')
--
insert into @immigration_status_start_date_question_user_codes
values
	('<question_user_code>', '<latest_question_text>')
--
insert into @immigration_status_end_date_question_user_codes
values
	('<question_user_code>', '<latest_question_text value>')
--
if object_id('tempdb..#text_answers') is not null
	drop table #text_answers
--
select
	cfa.form_id,
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
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = cfa.subgroup_id
	and
	sgs.subject_type_code = 'PER'
where
	q.question_user_code in (
		select
			question_user_code
		from
			@immigration_status_question_user_codes
		)
--
if object_id('tempdb..#date_answers') is not null
	drop table #date_answers
--
select
	cfa.form_id,
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
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = cfa.subgroup_id
	and
	sgs.subject_type_code = 'PER'
where
	q.question_user_code in (
		select
			question_user_code
		from
			@immigration_status_start_date_question_user_codes
		union 
		select
			question_user_code
		from
			@immigration_status_end_date_question_user_codes
		)
--
select 
	sub.immi_person_id,
	sub.immi_immigration_status_id,
	sub.immi_immigration_status,
	cast(sub.immi_immigration_status_start_date as date) immi_immigration_status_start_date,
	cast(sub.immi_immigration_status_end_date as date) immi_immigration_status_end_date
from 
	(
	select 
		sgs.subject_compound_id immi_person_id,
		dbo.append2(f.form_id, '.', sgs.subject_compound_id) immi_immigration_status_id,
		lkp.text_answer immi_immigration_status,
		d1.date_answer immi_immigration_status_start_date,
		d2.date_answer immi_immigration_status_end_date,
		row_number() over (partition by sgs.subject_compound_id order by f.created_on desc, f.form_id desc) seq 
	from
		mo_forms f
	inner join mo_subgroup_subjects sgs
	on sgs.subgroup_id = f.subgroup_id
		and
		sgs.subject_type_code = 'PER'
	inner join #text_answers lkp
	on lkp.form_id = f.form_id
		and
		lkp.person_id = sgs.subject_compound_id
	inner join @immigration_status_question_user_codes lkp_q
	on lkp_q.question_user_code = lkp.question_user_code 
	left outer join #date_answers d1
	on d1.form_id = f.form_id
		and
		d1.person_id = sgs.subject_compound_id
		and
		d1.form_answer_row_id = lkp.form_answer_row_id
		and
		d1.question_user_code in 
			(
			select
				question_user_code
			from
				@immigration_status_start_date_question_user_codes
			)
	left outer join #date_answers d2
	on d2.form_id = f.form_id
		and
		d2.person_id = sgs.subject_compound_id
		and
		d2.form_answer_row_id = lkp.form_answer_row_id
		and
		d2.question_user_code in 
			(
			select
				question_user_code
			from
				@immigration_status_start_date_question_user_codes
			)
	) sub
where 
	sub.seq = 1
