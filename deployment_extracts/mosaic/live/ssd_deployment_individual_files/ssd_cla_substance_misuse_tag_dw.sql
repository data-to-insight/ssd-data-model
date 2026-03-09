declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @substance_misuse_type_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @substance_misuse_date_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @substance_misuse_intervention_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
declare @substance_misuse_intervention_answers table (
	answer					varchar(1000)
)
--Insert the question user codes and question text of questions which are used to record the type of substance that is being abused
insert into @substance_misuse_type_question_user_codes
values
	('question_user_code', 'latest_question_text')
--
--Insert the question user codes and question text of questions which are used to record the date that the substance misuse is recorded
insert into @substance_misuse_date_question_user_codes
values
	('question_user_code', 'latest_question_text')
--
--Insert the question user codes and question text of questions which are used to record that child received an intervention for substance misuse problem
insert into @substance_misuse_intervention_question_user_codes
values
	('question_user_code', 'latest_question_text')
--
--Insert the exact wording of answers which indicate that an intervention was received
insert into @substance_misuse_intervention_answers
values
	('Yes')
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
			@substance_misuse_type_question_user_codes
		union 
		select
			question_user_code
		from
			@substance_misuse_intervention_question_user_codes
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
			@substance_misuse_date_question_user_codes
		)
--
select 
	sta.form_answer_row_id clas_substance_misuse_id
	,sta.person_id clas_person_id
	,(
	select d.date_answer 
	from #date_answers d 
	where d.form_id = sta.form_id 
		and 
		d.form_answer_row_id = sta.form_answer_row_id
	) clas_substance_misuse_date
	,sta.text_answer clas_substance_misused
	,(
	select la.text_answer 
	from #text_answers la 
	inner join @substance_misuse_intervention_question_user_codes quc
	on quc.question_user_code = la.question_user_code
	where la.form_id = sta.form_id 
		and la.form_answer_row_id = sta.form_answer_row_id
	) clas_intervention_received
from #text_answers sta
inner join @substance_misuse_type_question_user_codes smt
on smt.question_user_code = sta.question_user_code
			

