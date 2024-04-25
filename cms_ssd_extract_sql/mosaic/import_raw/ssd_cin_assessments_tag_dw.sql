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
--Insert assessment next actions that represent no further action
insert into @nfa_next_actions 
values
	(3988, 'Closure Record'),
	(3987, 'Progress to early help - Children''s social care case closure)'),
	(3953, 'Step down to Early Help'),
	(4440, 'Step down to Early Help (EH)')
--
--Insert assessment next actions that represent further social work intervention
insert into @further_sw_intervention_next_actions 
values
	(3941, 'CYPDS - Take to First Short Breaks Panel'),
	(4130, 'Decision to seek accommodation (CSSW)'),
	(3992, 'Develop or update child or young person in need plan'),
	(3942, 'Initial Core Offer Short Breaks Plan'),
	(4468, 'Initial CYPDS Short Breaks/Preparing for Adulthood Assessment and Plan (CSSW)'),
	(3950, 'Ongoing CP Investigation / Plan'),
	(3951, 'Ongoing LAC work'),
	(3944, 'Refer to Care Pathways Panel'),
	(4122, 'Strategy discussion (CSSW)'),
	(3943, 'UASC Age Assessment')
--
select
	CONCAT(CAST(sgs.subject_compound_id AS INT), CAST(STP.WORKFLOW_STEP_ID AS INT)) cina_assessment_id,
	sgs.SUBJECT_COMPOUND_ID cina_person_id,
	(
		select
			min(reff.referral_id)
		from
			DM_CIN_REFERRALS reff
		where
			reff.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
			and
			dbo.future(stp.COMPLETED_ON) >= reff.REFERRAL_DATE
			and
			coalesce(stp.started_on, stp.incoming_on) <= dbo.future(reff.CLOSURE_DATE)
	) cina_referral_id,
	coalesce(stp.STARTED_ON, stp.incoming_on) cina_assessment_start_date,
	(              
		select 
			max(case when grp.category_value = 'Yes' then 'Y' when grp.category_value = 'No' then 'N' end)
		from              
			dm_filter_form_answers ffa              
		inner join dm_mapping_groups grp              
		on grp.mapped_value = dbo.to_hash_code(ffa.text_answer)          
		and    
		grp.group_name = 'Child Seen During Assessment'              
		where              
		ffa.workflow_step_id = stp.workflow_step_id 
		and                 
		ffa.filter_name =  'Child Seen During Event (Lookup)'              
		and 
		case 
			when ffa.subject_person_id = 0 then 
				sgs.subject_compound_id 
			else 
				ffa.subject_person_id 
		end = sgs.subject_compound_id
	) cina_assessment_child_seen,
	stp.COMPLETED_ON cina_assessment_auth_date,
	case
		when exists (
				select
					1
				from
					DM_WORKFLOW_LINKS lnk
				inner join DM_WORKFLOW_NXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join DM_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @further_sw_intervention_next_actions inter
				on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
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
					DM_WORKFLOW_LINKS lnk
				inner join DM_WORKFLOW_NXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join DM_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @nfa_next_actions nfa
				on nfa.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
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
					DM_WORKFLOW_LINKS lnk
				inner join DM_WORKFLOW_NXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join DM_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @further_sw_intervention_next_actions inter
				on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
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
	dm_workflow_steps stp
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	stp.IS_CONTINUOUS_ASSESSMENT = 'Y'
	and
	--CRITERIA: Assessment was ongoing in the period
	coalesce(stp.STARTED_ON, stp.incoming_on) <= @end_date
	and
	dbo.future(stp.completed_on) >= @start_date
	and
	stp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')