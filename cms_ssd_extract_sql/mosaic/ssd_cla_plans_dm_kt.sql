/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @cla_plan_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @permanence_plan_question_user_codes table (
	question_user_code		varchar(128),
	question_text			varchar(1000)
)
--
--Insert workflow step types which are used to capture cla plans
insert into @cla_plan_workflow_step_types 
values
	(1232, 'CLA Chairs Update child or young person''s care plan (CSSW)')
	,(1242,	'First CLA review (CSSW)')
	,(1237,	'Second CLA review (CSSW)')
	,(1234,	'Subsequent CLA review (CSSW)')
	,(496,	'Initial Pathway Plan Review')
	,(500,	'Pathway Plan Review')
	,(1262,	'First LAC Review')
	,(1263,	'Second LAC Review')
	,(1264,	'Subsequent LAC Review')
	,(1295,	'Initial Under 18 pathway plan (CSSW)')
	,(1297,	'Review under 18 pathway plan (CSSW)')
--
insert into @permanence_plan_question_user_codes
values
	('lac.perm.plan', 'Child''s permanence plan')
--
--
if object_id('tempdb..#text_answers') is not null
	drop table #text_answers
--
select 
	sub.workflow_step_id,
	sub.form_answer_row_id,
	sub.question_user_code,
	sub.text_answer,
	sub.person_id
into
	#text_answers
from 
	(
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
		end person_id,
		rank() over (
			partition by 
				case 
					when cfa.subject_person_id > 0 then 
						cfa.subject_person_id
					else
						sgs.subject_compound_id
				end
				,cfa.workflow_step_id
			order by 
				cfa.form_id desc
			) seq
	from 
		dm_cached_form_answers cfa
	inner join dm_cached_form_questions q
	on q.mapping_id = cfa.mapping_id
	inner join dm_workflow_steps stp 
	on stp.workflow_step_id = cfa.workflow_step_id
	inner join @cla_plan_workflow_step_types atyp
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
				@permanence_plan_question_user_codes
			)
	) sub
where 
	sub.seq = 1;

--		
with cases as
(
select 
	starts.person_id
	,starts.lacp_cla_care_plan_id
	,cast(s1.started_on as date) lacp_cla_care_plan_start_date
	,coalesce(
		(
		--Valid case closures
		select max(fw_stp.workflow_step_id)
		from dm_workflow_forwards fw
		inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
		inner join dm_workflow_step_types fw_stp_t on fw_stp_t.workflow_step_type_id = fw_stp.workflow_step_type_id
			and fw_stp_t.is_case_closure = 'Y'
		where fw.workflow_step_id = starts.lacp_cla_care_plan_id
			and fw_stp.person_id = starts.person_id
			and fw_stp.step_status = 'COMPLETED'
			and not exists
				(
				select 1
				from dm_workflow_forwards fw1
				inner join dm_workflow_steps_people_vw fw_stp1 on fw_stp1.workflow_step_id = fw1.subsequent_workflow_step_id
				inner join dm_workflow_step_types fw_t1 on fw_t1.workflow_step_type_id = fw_stp1.workflow_step_type_id
				where fw1.workflow_step_id = starts.lacp_cla_care_plan_id
					and fw_stp1.person_id = starts.person_id
					and fw_stp1.step_status in ('PROPOSED', 'INCOMING', 'STARTED', 'REOPENED')
				)
		) 
		,(
		--No current active steps, but the case has not been closed down properly
		select max(fw_stp.workflow_step_id)
		from dm_workflow_forwards fw
		inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
		where fw.workflow_step_id = starts.lacp_cla_care_plan_id
			and fw_stp.person_id = starts.person_id
			and fw_stp.step_status ='COMPLETED'
			and not exists
				(
				select 1
				from dm_workflow_forwards fw1
				inner join dm_workflow_steps_people_vw fw_stp1 on fw_stp1.workflow_step_id = fw1.subsequent_workflow_step_id
				where fw1.workflow_step_id = starts.lacp_cla_care_plan_id
					and fw_stp1.person_id = starts.person_id
					and fw_stp1.step_status in ('PROPOSED', 'INCOMING', 'STARTED', 'REOPENED')
				)
		) 
	) closing_step_id
from 
	(
	select
	  distinct
	  stp.person_id
	  ,(
	  select min(bw.preceding_workflow_step_id)
	  from dm_workflow_backwards bw
	  inner join dm_workflow_steps_people_vw bw_stp on bw_stp.workflow_step_id = bw.preceding_workflow_step_id
	  inner join @cla_plan_workflow_step_types t on t.workflow_step_type_id = bw_stp.workflow_step_type_id
	  where bw.workflow_step_id = stp.workflow_step_id
		and bw_stp.person_id = stp.person_id
	  ) lacp_cla_care_plan_id
	from dm_workflow_steps_people_vw stp
	inner join @cla_plan_workflow_step_types t on t.workflow_step_type_id = stp.workflow_step_type_id
	where
		stp.step_status in ('INCOMING', 'STARTED', 'COMPLETED', 'REOPENED')
	) starts
inner join dm_workflow_steps s1 on s1.workflow_step_id = starts.lacp_cla_care_plan_id
)
,output as
(
select 
	c.*
	,(select cast(s.completed_on as date) from dm_workflow_steps s where s.workflow_step_id = c.closing_step_id) closing_step_date
from cases c
)
select 
	sub.lacp_cla_care_plan_id
	,sub.lacp_cla_care_plan_start_date
	,sub.lacp_cla_care_plan_end_date
	,sub.lacp_cla_care_plan_json
	,sub.lacp_person_id
from 
	(
	select 
		o.lacp_cla_care_plan_id 
		,o.person_id lacp_person_id
		,o.lacp_cla_care_plan_start_date 
		,(
		select lkp.text_answer
		from #text_answers lkp
		inner join @permanence_plan_question_user_codes quc
		on quc.question_user_code = lkp.question_user_code
		where
			lkp.workflow_step_id = o.lacp_cla_care_plan_id
			and
			lkp.person_id = o.person_id
		) lacp_cla_care_plan_json
		,(
		select min(o1.closing_step_date) 
		from output o1
		where o1.person_id = o.person_id
			and o1.lacp_cla_care_plan_id = o.lacp_cla_care_plan_id
		) lacp_cla_care_plan_end_date
	from output o
	) sub
where
	dbo.no_time(sub.lacp_cla_care_plan_start_date) <= @end_date
	and
	dbo.future(dbo.no_time(sub.lacp_cla_care_plan_end_date)) >= @start_date

order by 
	2 desc
