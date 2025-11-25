select
	con.WORKFLOW_STEP_ID cont_contact_id,
	sgs.SUBJECT_COMPOUND_ID cont_person_id,
	con.STARTED_ON,
	(
		select
			grp.category_code
		from
			DM_STEP_SOURCE_DETAILS ssd
		inner join child_group_embedded_codes_vw grp
		on grp.mapped_value = ssd.source_type_id
		and
		grp.group_name = 'Child CIN Referral Source'
		where
			ssd.WORKFLOW_STEP_ID = con.WORKFLOW_STEP_ID
	) cont_contact_source_code,
	(
		select
			styp.DESCRIPTION
		from
			DM_STEP_SOURCE_DETAILS ssd
		inner join DM_STEP_SOURCE_TYPES styp
		on styp.SOURCE_TYPE_ID = ssd.SOURCE_TYPE_ID
		where
			ssd.WORKFLOW_STEP_ID = con.WORKFLOW_STEP_ID
	) cont_contact_source_desc,
	(
		select
			reports_aggregates.string_aggregate(distinct ntyp.DESCRIPTION)
		from
			dm_workflow_links lnk
		inner join DM_WORKFLOW_NXT_ACTION_TYPES ntyp
		on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
		inner join dm_workflow_steps nstp
		on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
		inner join DM_SUBGROUP_SUBJECTS nsgs
		on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
		and
		nsgs.SUBJECT_TYPE_CODE = 'PER'
		and
		nstp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
		where
			lnk.SOURCE_STEP_ID = con.WORKFLOW_STEP_ID
			and
			nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
	) details
from
	dm_workflow_steps con
inner join DM_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = con.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	con.IS_CHILD_CONTACT = 'Y'