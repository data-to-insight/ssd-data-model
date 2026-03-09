/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
select
	stp.workflow_step_id s47e_s47_enquiry_id,
	(
	select max(ref.workflow_step_id)
	from dm_workflow_steps_people_vw ref
	where
		ref.person_id = stp.person_id
		and
		ref.is_child_referral = 'Y'
		and
		ref.started_on <= stp.started_on
	) s47e_referral_id,
	stp.person_id s47e_person_id,
	stp.started_on s47e_s47_start_date,
	stp.completed_on s47e_s47_end_date,
	case
		when exists (
			select
				1
			from
				dm_workflow_links lnk
			inner join dm_workflow_nxt_action_types ntyp
			on ntyp.workflow_next_action_type_id = lnk.workflow_next_action_type_id
				and
				ntyp.is_no_further_action = 'Y'
			inner join dm_workflow_steps_people_vw nstp
			on nstp.workflow_step_id = lnk.target_step_id
			where
				nstp.step_status not in ('CANCELLED', 'PROPOSED')
				and
				nstp.person_id = stp.person_id
			)
		and
		not exists (
			select
				1
			from
				dm_workflow_links lnk
			inner join dm_workflow_nxt_action_types ntyp
			on ntyp.workflow_next_action_type_id = lnk.workflow_next_action_type_id
				and
				ntyp.is_no_further_action = 'Y'
			inner join dm_workflow_steps_people_vw nstp
			on nstp.workflow_step_id = lnk.target_step_id
			where
				nstp.step_status not in ('CANCELLED', 'PROPOSED')
				and
				nstp.person_id = stp.person_id
			) then 
			'Y'
		else 
			'N'
	end s47e_s47_nfa,
	ltrim(
		stuff(
			(
			select 
				distinct ', ' + case when rt.description is not null then dbo.append2(n.description, ' / ', rt.description) else n.description end
			from 
				dm_workflow_links l
			inner join dm_workflow_steps_people_vw tgt
			on tgt.workflow_step_id = l.target_step_id
				and
				tgt.step_status != 'CANCELLED'
			inner join dm_workflow_nxt_action_types n
			on n.workflow_next_action_type_id = l.workflow_next_action_type_id
			left outer join dm_workflow_reason_types rt
			on rt.workflow_reason_type_id = l.workflow_reason_type_id
			where 
				l.source_step_id = stp.workflow_step_id
				and 
				tgt.person_id = stp.person_id
			order by 1
			for xml path('')),1,len(','),''
			)
		) s47e_s47_outcome_json,
	stp.assignee_id s47e_s47_completed_by_worker_id,
	stp.responsible_team_id s47e_s47_completed_by_team
from
	dm_workflow_steps_people_vw stp
where
	stp.is_section_47_enquiry = 'Y'
	and
	--CRITERIA: Section 47 enquiry was ongoing in the period
	dbo.no_time(stp.started_on) <= @end_date
	and
	dbo.future(dbo.no_time(stp.completed_on)) >= @start_date
	and
	stp.step_status in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
