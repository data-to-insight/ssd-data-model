select
	x.clar_cla_review_id,
	x.clar_cla_person_id,
	x.clar_cla_episode_id,
	x.clar_cla_review_due_date,
	x.clar_cla_review_date,
	x.clar_cla_review_participation,
	x.clar_cla_id
	-- ,
	-- ( -- [REVIEW] depreciated, removed and added clae_cla_last_iro_contact_date to cla_episodes table
	-- 	select 
	-- 		cast(max(ans.date_answer) as date)
	-- 	from 
	-- 		raw.mosaic_fw_mo_forms fm 
	-- 	inner join raw.mosaic_fw_mo_form_date_answers ans
	-- 	on fm.form_id = ans.form_id
	-- 	inner join raw.mosaic_fw_mo_subgroup_subjects sub 
	-- 	on fm.subgroup_id = sub.subgroup_id
	-- 	and
	-- 	sub.subject_type_code = 'PER'
	-- 	where
	-- 		ans.question_id = 98808
	-- 		and
	-- 		ans.date_answer between x.period_of_care_start_date and x.clar_cla_review_date
	-- 		and
	-- 		sub.subject_compound_id = x.clar_cla_person_id
	-- ) clar_cla_review_last_iro_contact_date
from
	(
		select
			rev.WORKFLOW_STEP_ID clar_cla_review_id,
			rev.person_id clar_cla_person_id,
			(
				select
					max(replace(replace(replace(convert(varchar, cla.episode_start_date, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla.person_id as varchar(9)))) + cast(cla.person_id as varchar(9)))
				from
					SCF.Children_In_Care cla
				where
					cla.PERSON_ID = rev.PERSON_ID
					and
					rev.ACTUAL_REVIEW_DATE between cla.EPISODE_START_DATE and coalesce(cla.EPISODE_END_DATE,'1 January 2300')
			) clar_cla_episode_id,
			rev.CALCULATED_DUE_DATE clar_cla_review_due_date,
			rev.ACTUAL_REVIEW_DATE clar_cla_review_date,
			rev.PARTICIPATION_CODE clar_cla_review_participation,
			(
				select
					max(cla.PERIOD_OF_CARE_ID)
				from
					SCF.Children_In_Care cla
				where
					cla.PERSON_ID = rev.PERSON_ID
					and
					rev.ACTUAL_REVIEW_DATE between cla.POC_START and coalesce(cla.poc_end,'1 January 2300')
					and
					replace(replace(replace(convert(varchar, cla.poc_start, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla.period_of_care_id as varchar(9)))) + cast(cla.period_of_care_id as varchar(9)) = (
						select
							max(replace(replace(replace(convert(varchar, cla1.poc_start, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla1.period_of_care_id as varchar(9)))) + cast(cla1.period_of_care_id as varchar(9)))
						from
							SCF.Children_In_Care cla1
						where
							cla1.PERSON_ID = rev.PERSON_ID
							and
							rev.ACTUAL_REVIEW_DATE between cla1.POC_START and coalesce(cla1.poc_end,'1 January 2300')
					)
			) clar_cla_id
			-- ,
			-- ( -- [REVIEW] depreciated, removed and added clae_cla_last_iro_contact_date to cla_episodes table
			-- 	select
			-- 		max(cla.poc_start)
			-- 	from
			-- 		SCF.Children_In_Care cla
			-- 	where
			-- 		cla.PERSON_ID = rev.PERSON_ID
			-- 		and
			-- 		rev.ACTUAL_REVIEW_DATE between cla.POC_START and coalesce(cla.poc_end,'1 January 2300')
			-- 		and
			-- 		replace(replace(replace(convert(varchar, cla.poc_start, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla.period_of_care_id as varchar(9)))) + cast(cla.period_of_care_id as varchar(9)) = (
			-- 			select
			-- 				max(replace(replace(replace(convert(varchar, cla1.poc_start, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla1.period_of_care_id as varchar(9)))) + cast(cla1.period_of_care_id as varchar(9)))
			-- 			from
			-- 				SCF.Children_In_Care cla1
			-- 			where
			-- 				cla1.PERSON_ID = rev.PERSON_ID
			-- 				and
			-- 				rev.ACTUAL_REVIEW_DATE between cla1.POC_START and coalesce(cla1.poc_end,'1 January 2300')
			-- 		)
			-- ) period_of_care_start_date
		from
			SCF.Reviews rev
		where
			rev.review_type = 'CIC'
	) x
order by
	x.clar_cla_review_date desc

