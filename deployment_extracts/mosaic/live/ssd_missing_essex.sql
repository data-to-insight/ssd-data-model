if object_id('tempdb..#lookup_answers') is not null
	drop table #lookup_answers
--
select
	stp.workflow_step_id,
	answ.FORM_ANSWER_ROW_ID,
	q.QUESTION_USER_CODE,
	lkp.ANSWER lookup_answer,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#lookup_answers
from
	raw.mosaic_fw_mo_form_lookup_answers answ
--JOIN: find the form details
inner join raw.mosaic_fw_mo_forms forms
on forms.form_id = answ.form_id
--JOIN: find the template used
inner join raw.mosaic_fw_mo_templates temp
on temp.template_id = forms.template_id
--JOIN: find the question version
inner join raw.mosaic_fw_mo_questions q
on q.question_id = answ.question_id
--JOIN: find the lookup text for the answer
inner join raw.mosaic_fw_mo_question_lookups lkp
on lkp.question_lookup_id = answ.question_lookup_id
--JOIN: Find the step
inner join raw.mosaic_fw_mo_workflow_steps stp
on stp.workflow_step_id = forms.workflow_step_id
inner join raw.mosaic_fw_mo_form_answer_rows r
on r.form_answer_row_id = answ.form_answer_row_id
inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	q.QUESTION_USER_CODE in (
		'missingepisodediscussed'
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		1777
	)
--
if object_id('tempdb..#date_answers') is not null
	drop table #date_answers
--
select
	stp.WORKFLOW_STEP_ID,
	que.QUESTION_USER_CODE,
	dates.DATE_ANSWER,
	r.form_answer_row_id,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#date_answers
from
	raw.mosaic_fw_MO_FORM_DATE_ANSWERS dates
inner join raw.mosaic_fw_MO_QUESTIONS que 
on que.QUESTION_ID = dates.QUESTION_ID
inner join raw.mosaic_fw_MO_FORMS frm
on frm.FORM_ID = dates.FORM_ID
inner join raw.mosaic_fw_MO_WORKFLOW_STEPS stp 
on stp.WORKFLOW_STEP_ID = frm.WORKFLOW_STEP_ID
inner join raw.mosaic_fw_mo_form_answer_rows r
on r.form_answer_row_id = dates.form_answer_row_id
inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	que.QUESTION_USER_CODE in (
		'missinglettersent'
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		1777
	)
--
create index lkp_answers_idx on #lookup_answers (workflow_step_id, person_id, question_user_code);
create index date_answers_idx on #date_answers (workflow_step_id, person_id, question_user_code);
--
select
	miss.WORKFLOW_STEP_ID miss_table_id, -- [REVIEW] was/re-purposed from miss_ missing_ episode_ id
	(
		select
			max(replace(replace(replace(convert(varchar, cla.episode_start_date, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla.person_id as varchar(9)))) + cast(cla.person_id as varchar(9)))
		from
			SCF.Children_In_Care cla
		where
			cla.PERSON_ID = miss.PERSON_ID
			and
			miss.start_date between cla.EPISODE_START_DATE and coalesce(cla.EPISODE_END_DATE,'1 January 2300')
	) miss_cla_episode_id, # could this just become/transition to the correct miss_table_id ? RH [TESTING]
							# we need miss_person_id in here [TESTING]
	miss.start_date miss_missing_episode_start_date,
	miss.missing_category miss_missing_episode_type,
	miss.end_date miss_missing_episode_end_date,
	(
		select
			max(
				case
					when dates.date_answer is not null then
						'Y'
					else
						'N'
				end
			)
		from
			#date_answers dates
		where
			dates.workflow_step_id = miss.workflow_step_id
			and
			dates.person_id = miss.person_id
			and
			dates.question_user_code = 'missinglettersent'
	) miss_missing_rhi_offered,
	(
		select
			max(
				case
					when lkp.lookup_answer = 'Yes' then
						'Y'
					else
						'N'
				end
			)
		from
			#lookup_answers lkp
		where
			lkp.workflow_step_id = miss.workflow_step_id
			and
			lkp.person_id = miss.person_id
			and
			lkp.question_user_code = 'missingepisodediscussed'
	) miss_missing_rhi_accepted
from
	SCF.Missing_Episodes miss