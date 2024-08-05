select
	dbo.to_weighted_start(ffa.date_answer,ffa.form_id) lapp_table_id, -- [REVIEW] -- re-purposed from lapp_ previous_ permanence_ id
	sgs.SUBJECT_COMPOUND_ID lapp_person_id,
	ffa.date_answer lapp_previous_permanence_order_date,
	(
		select
			max(opt.text_answer)
		from
			DM_FILTER_FORM_ANSWERS opt
		inner join dm_workflow_steps ostp
		on ostp.WORKFLOW_STEP_ID = opt.workflow_step_id
		inner join DM_SUBGROUP_SUBJECTS osgs
		on osgs.SUBGROUP_ID = ostp.SUBGROUP_ID
		and
		osgs.SUBJECT_TYPE_CODE = 'PER'
		inner join DM_MAPPING_GROUPS grp
		on grp.mapped_value = dbo.to_hash_code(opt.text_answer)
		and
		grp.group_name = 'Child Previous Permanence Option'
		where
			opt.filter_name = 'Child Previous Permanence Option (Document)'
			and
			opt.workflow_step_id = ffa.workflow_step_id
			and
			case 
				when opt.subject_person_id <= 0 then 
					sgs.SUBJECT_COMPOUND_ID
				else 
					opt.subject_person_id
			end = sgs.SUBJECT_COMPOUND_ID
	) lapp_previous_permanence_option,
	(
		select
			max(opt.text_answer)
		from
			DM_FILTER_FORM_ANSWERS opt
		inner join dm_workflow_steps ostp
		on ostp.WORKFLOW_STEP_ID = opt.workflow_step_id
		inner join DM_SUBGROUP_SUBJECTS osgs
		on osgs.SUBGROUP_ID = ostp.SUBGROUP_ID
		and
		osgs.SUBJECT_TYPE_CODE = 'PER'
		inner join DM_MAPPING_GROUPS grp
		on grp.mapped_value = dbo.to_hash_code(opt.text_answer)
		and
		grp.group_name = 'Child Previous Permanence LA'
		where
			opt.filter_name = 'Child Previous Permanence LA (Document)'
			and
			opt.workflow_step_id = ffa.workflow_step_id
			and
			case 
				when opt.subject_person_id <= 0 then 
					sgs.SUBJECT_COMPOUND_ID
				else 
					opt.subject_person_id
			end = sgs.SUBJECT_COMPOUND_ID
	) lapp_previous_permanence_la
from
	dm_filter_form_answers ffa
inner join dm_workflow_steps stp
on stp.WORKFLOW_STEP_ID = ffa.workflow_step_id
inner join DM_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	ffa.filter_name = 'Child Previous Permanence Option Date (Document)'
	and
	dbo.to_weighted_start(ffa.date_answer,ffa.form_id) = (
		select
			max(dbo.to_weighted_start(ffa1.date_answer,ffa1.form_id))
		from
			dm_filter_form_answers ffa1
		inner join dm_workflow_steps stp1
		on stp1.WORKFLOW_STEP_ID = ffa1.workflow_step_id
		inner join DM_SUBGROUP_SUBJECTS sgs1
		on sgs1.SUBGROUP_ID = stp1.SUBGROUP_ID
		and
		sgs1.SUBJECT_TYPE_CODE = 'PER'
		where
			ffa1.filter_name = 'Child Previous Permanence Option Date (Document)'
			and
			sgs1.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
	)
	