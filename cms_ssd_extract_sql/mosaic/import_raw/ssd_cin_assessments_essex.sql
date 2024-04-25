declare @number_of_years_to_include int
set @number_of_years_to_include = 1
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
select
	a.PERSON_ASSESSMENT_ID cina_assessment_id,
	a.PERSON_ID cina_person_id,
	null cina_referral_id,
	a.DATE_ASSESSMENT_STARTED cina_assessment_start_date,
	a.CHILD_SEEN cina_assessment_child_seen,
	a.ASSESSMENT_AUTHORISED_DATE cina_assessment_auth_date,
	case
		when exists (
				select
					1
				from
					raw.mosaic_fw_mo_workflow_links lnk
				inner join raw.mosaic_fw_MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join raw.mosaic_fw_MO_WORKFLOW_STEPS nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @further_sw_intervention_next_actions inter
				on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
					and
					nsgs.SUBJECT_COMPOUND_ID = a.PERSON_ID
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
					raw.mosaic_fw_MO_WORKFLOW_LINKS lnk
				inner join raw.mosaic_fw_MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join raw.mosaic_fw_MO_WORKFLOW_STEPS nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @nfa_next_actions nfa
				on nfa.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
					and
					nsgs.SUBJECT_COMPOUND_ID = a.PERSON_ID
			)
			and
			not exists (
				select
					1
				from
					raw.mosaic_fw_MO_WORKFLOW_LINKS lnk
				inner join raw.mosaic_fw_MO_WORKFLOW_NEXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join raw.mosaic_fw_MO_WORKFLOW_STEPS nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join @further_sw_intervention_next_actions inter
				on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
					and
					nsgs.SUBJECT_COMPOUND_ID = a.PERSON_ID
			) then
		'Y'
		else
			'N'
	end cina_assessment_outcome_nfa,
	a.RESPONSIBLE_TEAM_ID cina_assessment_team,
	a.ASSIGNEE_ID cina_assessment_worker_id
from
	SCF.Assessments a
where
	a.DATE_ASSESSMENT_STARTED <= cast(cast(getdate() as date) as datetime)
	and
	coalesce(a.ASSESSMENT_AUTHORISED_DATE,'1 January 2300') >= dateadd(yy,-@number_of_years_to_include,cast(cast(getdate() as date) as datetime))