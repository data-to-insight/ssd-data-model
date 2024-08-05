 select 
	stp.workflow_step_id miss_table_id,
	sgs.SUBJECT_COMPOUND_ID miss_person_id,
	stp.started_on miss_missing_episode_start_date,
	(
		select
			--Should be only one per episode, but max() just in case
			max(
				case
					when ffa.text_answer = 'Missing' then
						'M'
					when ffa.text_answer = 'Absent' then
						'A'
				end
			)
		from
			dm_filter_form_answers ffa
		where
			ffa.workflow_step_id = stp.workflow_step_id
			and 
			ffa.filter_name = 'Child Absent or Missing (Document)'
			and
			case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
	) miss_missing_episode_type,
	stp.completed_on miss_missing_episode_end_date,
	(
		select
			max(
				case
					when grp.category_value = 'Yes' then
						'Y'
					when grp.category_value = 'No' then
						'N'
				end
			)
		from
			dm_filter_form_answers ffa
		inner join DM_MAPPING_GROUPS grp
		on grp.mapped_value = dbo.to_hash_code(ffa.text_answer)
		and
		grp.group_name = 'Child Offered Return Interview Types'
		where
			ffa.workflow_step_id = stp.workflow_step_id
			and 
			ffa.filter_name = 'Child Offered Return Interview'
			and
			case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
	) miss_missing_rhi_offered,
	(
		select
			max(
				case
					when grp.category_value = 'Yes' then
						'Y'
					when grp.category_value = 'No' then
						'N'
				end
			)
		from
			dm_filter_form_answers ffa
		inner join DM_MAPPING_GROUPS grp
		on grp.mapped_value = dbo.to_hash_code(ffa.text_answer)
		and
		grp.group_name = 'Child Accepted Return Interview Types'
		where
			ffa.workflow_step_id = stp.workflow_step_id
			and 
			ffa.filter_name = 'Child Accepted Return Interview'
			and
			case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
	) miss_missing_rhi_accepted
from
	dm_workflow_steps stp
inner join DM_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	stp.is_missing_or_absent = 'Y'