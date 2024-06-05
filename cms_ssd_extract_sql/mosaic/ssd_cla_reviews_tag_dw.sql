with reviews as (
	select
		rev.LAC_REVIEW_CATEGORY,
		rev.step_status,
		rev.CANCELLED_ON,
		rev.WORKFLOW_STEP_ID,
		rev.LAC_REVIEW_DATE,
		rev.LAC_REVIEW_PARTICIPATION_CODE participation_type,
		(
			select
				max(poc.PERIOD_OF_CARE_ID)
			from
				DM_PERIODS_OF_CARE poc
			where
				rev.LAC_REVIEW_DATE between poc.START_DATE and dbo.future(poc.END_DATE)
				and
				poc.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
		) period_of_care_id,
		(
			select
				poc.start_date
			from
				DM_PERIODS_OF_CARE poc
			where
				poc.person_id = sgs.SUBJECT_COMPOUND_ID
				and
				poc.period_of_care_id = (
					select
						max(poc1.period_of_care_id)
					from
						DM_PERIODS_OF_CARE poc1
					where
						poc1.person_id = sgs.SUBJECT_COMPOUND_ID
						and
						rev.LAC_REVIEW_DATE between poc1.start_date and dbo.future(poc1.end_date)
				)
		) date_became_cla,
		sgs.SUBJECT_COMPOUND_ID person_id
	from
		dm_workflow_steps rev
	inner join DM_SUBGROUP_SUBJECTS sgs
	on sgs.SUBGROUP_ID = rev.SUBGROUP_ID
	and
	sgs.SUBJECT_TYPE_CODE = 'PER'
	where
		rev.LAC_REVIEW_CATEGORY is not null
		and
		rev.STEP_STATUS = 'COMPLETED'
),
cancelled_reviews as (
	select
		rev.LAC_REVIEW_CATEGORY,
		rev.CANCELLED_ON,
		rev.WORKFLOW_STEP_ID,
		(
			select
				max(poc.PERIOD_OF_CARE_ID)
			from
				DM_PERIODS_OF_CARE poc
			where
				rev.CANCELLED_ON between poc.START_DATE and dbo.future(poc.END_DATE)
				and
				poc.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
		) period_of_care_id,
		(
			select
				poc.start_date
			from
				DM_PERIODS_OF_CARE poc
			where
				poc.person_id = sgs.SUBJECT_COMPOUND_ID
				and
				poc.period_of_care_id = (
					select
						max(poc1.period_of_care_id)
					from
						DM_PERIODS_OF_CARE poc1
					where
						poc1.person_id = sgs.SUBJECT_COMPOUND_ID
						and
						rev.CANCELLED_ON between poc1.start_date and dbo.future(poc1.end_date)
				)
		) date_became_cla,
		sgs.SUBJECT_COMPOUND_ID person_id
	from
		dm_workflow_steps rev
	inner join DM_SUBGROUP_SUBJECTS sgs
	on sgs.SUBGROUP_ID = rev.SUBGROUP_ID
	and
	sgs.SUBJECT_TYPE_CODE = 'PER'
	where
		rev.LAC_REVIEW_CATEGORY is not null
		and
		rev.STEP_STATUS = 'CANCELLED'
)
--
select
	x.workflow_step_id clar_cla_review_id,
	x.person_id,
	case	
		when x.review_type = 'First CLA Review' then 
			dbo.f_add_working_days(x.date_became_cla,20)
		when x.review_type = 'Second CLA Review' 
			then dateadd(dd,91,x.date_of_prev_review)
		else 
			dateadd(dd,183,x.date_of_prev_review)
	end clar_cla_review_due_date,	
	x.LAC_REVIEW_DATE clar_cla_review_date,
	x.participation_type clar_cla_review_participation,
	x.period_of_care_id clar_cla_id,
	'N' clar_cla_review_cancelled,
	x.person_id clar_cla_person_id
from
	(
		select
			r.person_id,
			r.WORKFLOW_STEP_ID,
			r.LAC_REVIEW_DATE,
			r.period_of_care_id,
			r.date_became_cla,
			(
				select
					p.WORKFLOW_STEP_ID
				from
					reviews p
				where
					p.person_id = r.person_id
					and
					p.period_of_care_id = r.period_of_care_id
					and
					p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					and
					dbo.to_weighted_start(p.LAC_REVIEW_DATE,p.workflow_step_id) = (
						select
							max(dbo.to_weighted_start(p1.LAC_REVIEW_DATE,p1.WORKFLOW_STEP_ID))
						from
							reviews p1
						where
							p1.person_id = r.person_id
							and
							p1.period_of_care_id = r.period_of_care_id
							and
							p1.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					)
			) previous_review_id,
			(
				select
					max(p.LAC_REVIEW_DATE)
				from
					reviews p
				where
					p.person_id = r.person_id
					and
					p.period_of_care_id = r.period_of_care_id
					and
					p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
			) date_of_prev_review,
			case
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					) = 0 then
					'First CLA Review'
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					) = 1 then
					'Second CLA Review'
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					) > 1 then
					'Subsequent CLA Review'
			end review_type,
			r.participation_type
		from
			reviews r
	) x
--
union
--
select
	x.workflow_step_id clar_cla_review_id,
	x.person_id,
	case	
		when x.review_type = 'First CLA Review' then 
			dbo.f_add_working_days(x.date_became_cla,20)
		when x.review_type = 'Second CLA Review' 
			then dateadd(dd,91,x.date_of_prev_review)
		else 
			dateadd(dd,183,x.date_of_prev_review)
	end clar_cla_review_due_date,	
	null clar_cla_review_date,
	null clar_cla_review_participation,
	x.period_of_care_id clar_cla_id,
	'Y' clar_cla_review_cancelled,
	x.person_id clar_cla_person_id
from
	(
		select
			r.person_id,
			r.WORKFLOW_STEP_ID,
			r.period_of_care_id,
			r.date_became_cla,
			(
				select
					p.WORKFLOW_STEP_ID
				from
					reviews p
				where
					p.person_id = r.person_id
					and
					p.period_of_care_id = r.period_of_care_id
					and
					p.LAC_REVIEW_DATE < r.CANCELLED_ON
					and
					dbo.to_weighted_start(p.LAC_REVIEW_DATE,p.workflow_step_id) = (
						select
							max(dbo.to_weighted_start(p1.LAC_REVIEW_DATE,p1.WORKFLOW_STEP_ID))
						from
							reviews p1
						where
							p1.person_id = r.person_id
							and
							p1.period_of_care_id = r.period_of_care_id
							and
							p1.LAC_REVIEW_DATE < r.CANCELLED_ON
					)
			) previous_review_id,
			(
				select
					max(p.LAC_REVIEW_DATE)
				from
					reviews p
				where
					p.person_id = r.person_id
					and
					p.period_of_care_id = r.period_of_care_id
					and
					p.LAC_REVIEW_DATE < r.CANCELLED_ON
			) date_of_prev_review,
			case
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.CANCELLED_ON
					) = 0 then
					'First CLA Review'
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.CANCELLED_ON
					) = 1 then
					'Second CLA Review'
				when (
						select
							count(1)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.CANCELLED_ON
					) > 1 then
					'Subsequent CLA Review'
			end review_type
		from
			cancelled_reviews r
	) x