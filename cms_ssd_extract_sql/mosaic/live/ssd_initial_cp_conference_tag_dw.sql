select
	x.icpc_icpc_id,
	x.icpc_icpc_meeting_id,
	x.icpc_s47_enquiry_id,
	x.icpc_person_id,
	x.icpc_cp_plan_id,
	x.icpc_referral_id,
	x.icpc_icpc_transfer_in,
	dbo.f_add_working_days(x.strategy_discussion_date,15) icpc_icpc_target_date,
	x.icpc_date icpc_icpc_date,
	case
		when icpc_cp_plan_id is not null then
			'Y'
		else
			'N'
	end icpc_icpc_outcome_cp_flag,
	x.icpc_next_actions,
	x.RESPONSIBLE_TEAM_ID icpc_icpc_team,
	x.ASSIGNEE_ID icpc_icpc_worker_id
from
	(
		select
			icpc.WORKFLOW_STEP_ID icpc_icpc_id,
			null icpc_icpc_meeting_id,
			(
				select
					x.STRATEGY_DISCUSSION_DATE
				from
					dm_workflow_steps x
				inner join dm_subgroup_subjects y
				on y.SUBGROUP_ID = x.SUBGROUP_ID
				and
				y.SUBJECT_TYPE_CODE = 'PER'
				where
					x.STRATEGY_DISCUSSION_DATE is not null
					and
					y.SUBJECT_COMPOUND_ID = sgs.subject_compound_id
					and
					x.WEIGHTED_START_DATETIME = (
						select
							max(sd.WEIGHTED_START_DATETIME)
						from
							dm_workflow_backwards bwd
						inner join dm_workflow_steps sd
						on sd.WORKFLOW_STEP_ID = bwd.PRECEDING_WORKFLOW_STEP_ID
						and
						sd.STRATEGY_DISCUSSION_DATE is not null
						inner join dm_subgroup_subjects sd_sgs
						on sd_sgs.SUBGROUP_ID = sd.SUBGROUP_ID
						and
						sd_sgs.SUBJECT_TYPE_CODE = 'PER'
						where
							bwd.WORKFLOW_STEP_ID = icpc.WORKFLOW_STEP_ID
							and
							sd_sgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					)
			) strategy_discussion_date,
			(
				select
					x.WORKFLOW_STEP_ID
				from
					dm_workflow_steps x
				inner join dm_subgroup_subjects y
				on y.SUBGROUP_ID = x.SUBGROUP_ID
				and
				y.SUBJECT_TYPE_CODE = 'PER'
				where
					x.IS_SECTION_47_ENQUIRY = 'Y'
					and
					y.SUBJECT_COMPOUND_ID = sgs.subject_compound_id
					and
					x.WEIGHTED_START_DATETIME = (
						select
							max(s47.WEIGHTED_START_DATETIME)
						from
							dm_workflow_backwards bwd
						inner join dm_workflow_steps s47
						on s47.WORKFLOW_STEP_ID = bwd.PRECEDING_WORKFLOW_STEP_ID
						and
						s47.IS_SECTION_47_ENQUIRY = 'Y'
						inner join dm_subgroup_subjects s47_sgs
						on s47_sgs.SUBGROUP_ID = s47.SUBGROUP_ID
						and
						s47_sgs.SUBJECT_TYPE_CODE = 'PER'
						where
							bwd.WORKFLOW_STEP_ID = icpc.WORKFLOW_STEP_ID
							and
							s47_sgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					)
			) icpc_s47_enquiry_id,
			sgs.SUBJECT_COMPOUND_ID icpc_person_id,
			(
				select
					reg.REGISTRATION_ID
				from
					DM_REGISTRATIONS reg
				where
					reg.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
					and
					reg.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(reg.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					dbo.no_time(reg.REGISTRATION_START_DATE) = icpc.CP_CONFERENCE_ACTUAL_DATE
			) icpc_cp_plan_id,
			(
				select
					max(ref.referral_id)
				from
					DM_CIN_REFERRALS ref
				where
					ref.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
					and
					icpc.CP_CONFERENCE_ACTUAL_DATE between ref.REFERRAL_DATE and dbo.future(ref.CLOSURE_DATE)
					
			) icpc_referral_id,
			(
				select
					max('Y')
				from
					DM_MAPPING_FILTERS fil
				where
					fil.FILTER_NAME = 'Child CIN Transfer In Conferences'
					and
					fil.MAPPED_VALUE = icpc.WORKFLOW_STEP_TYPE_ID
			) icpc_icpc_transfer_in,
			icpc.CP_CONFERENCE_ACTUAL_DATE icpc_date,
			(
				select
					reports_aggregates.string_aggregate(distinct nat.description)
				from
					dm_workflow_links lnk
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				and
				nstp.STEP_STATUS not in ('PROPOSED', 'CANCELLED')
				inner join DM_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join DM_WORKFLOW_NXT_ACTION_TYPES nat
				on nat.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = icpc.WORKFLOW_STEP_ID
            ) icpc_next_actions,
			icpc.RESPONSIBLE_TEAM_ID,
			icpc.ASSIGNEE_ID
		from
			dm_workflow_steps icpc
		inner join DM_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = icpc.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			icpc.CP_CONFERENCE_CATEGORY = 'Initial'
			and
			icpc.STEP_STATUS = 'COMPLETED'
	) x
order by
	x.icpc_date desc		