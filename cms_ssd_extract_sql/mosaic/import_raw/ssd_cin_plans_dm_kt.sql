declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @cin_plan_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @step_down_to_eh_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
--Insert workflow step types which are used to capture cin plans
insert into @cin_plan_workflow_step_types 
values
	(1191, 'Child or young person in need plan (CSSW)')
	,(1194, 'Child or young person in need review (CSSW)')
--
--Insert workflow step types which are used to step down to EH
insert into @step_down_to_eh_workflow_step_types 
values
	(1222, 'Step down to Early Help (EH)');
--
with cases as
(
select 
	starts.person_id
	,starts.cin_plan_start_id
	,cast(s1.started_on as date) cin_plan_start_date
	,(
	select max(fw_stp.workflow_step_id)
	from dm_workflow_forwards fw 
	inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
			and fw_stp.step_status != 'CANCELLED'
	inner join @cin_plan_workflow_step_types fw_t on fw_t.workflow_step_type_id = fw_stp.workflow_step_type_id
	where
		fw.workflow_step_id = starts.cin_plan_start_id
		and fw_stp.person_id = starts.person_id
	) cin_plan_latest_step_id
	,(
	select cast(min(poc.start_date) as date)
	from dm_periods_of_care poc 
	where poc.person_id = starts.person_id 
	and poc.start_date > s1.started_on
	) step_up_cla_date
	,(
	select cast(min(r.registration_start_date) as date)
	from dm_registrations r 
	where r.person_id = starts.person_id 
	and r.registration_start_date > s1.started_on
		and r.is_child_protection_plan = 'Y'
		and r.is_temporary_child_protection is null
	) step_up_cpp_date
	,(
	select min(fw_stp.workflow_step_id)
	from dm_workflow_forwards fw
	inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
	inner join @step_down_to_eh_workflow_step_types fw_stp_t on fw_stp_t.workflow_step_type_id = fw_stp.workflow_step_type_id
	where fw.workflow_step_id = starts.cin_plan_start_id
		and fw_stp.person_id = starts.person_id
		and fw_stp.step_status in ('INCOMING', 'STARTED', 'COMPLETED')
	) step_down_eh_id
	,coalesce(
		(
		--Valid case closures
		select max(fw_stp.workflow_step_id)
		from dm_workflow_forwards fw
		inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
		inner join dm_workflow_step_types fw_stp_t on fw_stp_t.workflow_step_type_id = fw_stp.workflow_step_type_id
			and fw_stp_t.is_case_closure = 'Y'
		where fw.workflow_step_id = starts.cin_plan_start_id
			and fw_stp.person_id = starts.person_id
			and fw_stp.step_status = 'COMPLETED'
			and not exists
				(
				select 1
				from dm_workflow_forwards fw1
				inner join dm_workflow_steps_people_vw fw_stp1 on fw_stp1.workflow_step_id = fw1.subsequent_workflow_step_id
				inner join dm_workflow_step_types fw_t1 on fw_t1.workflow_step_type_id = fw_stp1.workflow_step_type_id
				where fw1.workflow_step_id = starts.cin_plan_start_id
					and fw_stp1.person_id = starts.person_id
					and fw_stp1.step_status in ('PROPOSED', 'INCOMING', 'STARTED', 'REOPENED')
				)
		) 
		,(
		--No current active steps, but the case has not been closed down properly
		select max(fw_stp.workflow_step_id)
		from dm_workflow_forwards fw
		inner join dm_workflow_steps_people_vw fw_stp on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
		where fw.workflow_step_id = starts.cin_plan_start_id
			and fw_stp.person_id = starts.person_id
			and fw_stp.step_status ='COMPLETED'
			and not exists
				(
				select 1
				from dm_workflow_forwards fw1
				inner join dm_workflow_steps_people_vw fw_stp1 on fw_stp1.workflow_step_id = fw1.subsequent_workflow_step_id
				where fw1.workflow_step_id = starts.cin_plan_start_id
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
	  inner join @cin_plan_workflow_step_types t on t.workflow_step_type_id = bw_stp.workflow_step_type_id
	  where bw.workflow_step_id = stp.workflow_step_id
		and bw_stp.person_id = stp.person_id
	  ) cin_plan_start_id
	from dm_workflow_steps_people_vw stp
	inner join @cin_plan_workflow_step_types t on t.workflow_step_type_id = stp.workflow_step_type_id
	where
		stp.step_status in ('INCOMING', 'STARTED', 'COMPLETED', 'REOPENED')
	) starts
inner join dm_workflow_steps s1 on s1.workflow_step_id = starts.cin_plan_start_id
)
,output as
(
select 
	c.*
	,(select cast(s.incoming_on as date) from dm_workflow_steps s where s.workflow_step_id = c.step_down_eh_id) step_down_eh_date
	,(select cast(s.completed_on as date) from dm_workflow_steps s where s.workflow_step_id = c.closing_step_id) closing_step_date
	,(
	select max(ref.workflow_step_id)
	from dm_workflow_steps_people_vw ref
	where
		ref.person_id = c.person_id
		and
		ref.started_on <= c.cin_plan_start_date
	) cinp_referral_id
	,s1.assignee_id
	,s1.responsible_team_id
from cases c
inner join dm_workflow_steps s1 on s1.workflow_step_id = coalesce(c.cin_plan_latest_step_id, c.cin_plan_start_id)
)
select 
	sub.cinp_cin_plan_id
	,sub.cinp_referral_id
	,sub.cinp_person_id
	,sub.cinp_cin_plan_start_date
	,sub.cinp_cin_plan_end_date
	,sub.cinp_cin_plan_team
	,sub.cinp_cin_plan_worker_id
from 
	(
	select 
		o.cin_plan_start_id cinp_cin_plan_id
		,o.cinp_referral_id
		,o.person_id cinp_person_id
		,o.cin_plan_start_date cinp_cin_plan_start_date
		,(
		select min(x.cin_plan_end) 
		from output o1
		cross apply (values (o1.step_up_cla_date),(o1.step_up_cpp_date),(o1.step_down_eh_date),(o1.closing_step_date)) x (cin_plan_end)
		where o1.person_id = o.person_id
			and o1.cin_plan_start_id = o.cin_plan_start_id
		) cinp_cin_plan_end_date
		,o.responsible_team_id cinp_cin_plan_team
		,o.assignee_id cinp_cin_plan_worker_id
	from output o
	) sub
where
	dbo.no_time(sub.cinp_cin_plan_start_date) <= @end_date
	and
	dbo.future(dbo.no_time(sub.cinp_cin_plan_end_date)) >= @start_date
