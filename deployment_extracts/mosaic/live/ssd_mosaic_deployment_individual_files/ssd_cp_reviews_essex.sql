select
	rev.WORKFLOW_STEP_ID cppr_cp_review_id,
	rev.person_id cppr_person_id,
	(
		select
			max(cpp.registration_id)
		from
			SCF.Child_Protection_Plans cpp
		where
			cpp.PERSON_ID = rev.PERSON_ID
			and
			rev.ACTUAL_REVIEW_DATE between cpp.CP_START_DATE and coalesce(cpp.cp_end_date,'1 January 2300')
	) cppr_cp_plan_id,
	rev.calculated_due_date cppr_cp_review_due,
	rev.actual_review_date cppr_cp_review_date,
	case
		when exists (
			select
				1
			from
				SCF.Child_Protection_Plans cpp
			where
				cpp.PERSON_ID = rev.PERSON_ID
				and
				rev.ACTUAL_REVIEW_DATE = cpp.cp_end_date
		) then
			'CP Plan to end'
		else
			'CP Plan to continue'
	end cpp_cp_review_outcome
from
	SCF.Reviews rev
where
	rev.review_type = 'CP'
	and
	rev.workflow_step_type not in ('Transfer In Child Protection Conference (Essex)', 'Initial Child Protection Conference (Essex)')
