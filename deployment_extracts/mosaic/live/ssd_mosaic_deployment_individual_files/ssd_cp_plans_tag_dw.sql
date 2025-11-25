select
	cpp.REGISTRATION_ID cppl_cp_plan_id,
	(
		select
			max(ref.referral_id)
		from
			DM_CIN_REFERRALS ref
		where
			ref.PERSON_ID = cpp.PERSON_ID
			and
			ref.REFERRAL_DATE <= dbo.future(cpp.DEREGISTRATION_DATE)
			and
			dbo.future(ref.CLOSURE_DATE)>= cpp.REGISTRATION_START_DATE
	) cppl_referral_id,
	cpp.REGISTRATION_STEP_ID cppl_icpc_id, -- [REVIEW] from cppl_ initial_ cp_ conference_ id 290424 RH
	cpp.PERSON_ID cppl_person_id,
	cpp.REGISTRATION_START_DATE cppl_cp_plan_start_date,
	cpp.DEREGISTRATION_DATE cppl_cp_plan_end_date,
	case
		when (
				select
					count(1)
				from
					DM_REGISTRATION_CATEGORIES cat
				where
					cat.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					dbo.no_time(cat.CATEGORY_START_DATE) = dbo.no_time(cpp.REGISTRATION_START_DATE)
			) > 1 then
			'MUL'
		else
			(
				select
					cat.CIN_ABUSE_CATEGORY_CODE
				from
					DM_REGISTRATION_CATEGORIES cat
				where
					cat.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					dbo.no_time(cat.CATEGORY_START_DATE) = dbo.no_time(cpp.REGISTRATION_START_DATE)
			)			
	end cppl_cp_plan_initial_category,
	case
		when (
				select
					count(1)
				from
					DM_REGISTRATION_CATEGORIES cat
				where
					cat.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					coalesce(cpp.DEREGISTRATION_DATE,dbo.today()) between cat.CATEGORY_START_DATE and dbo.future(cat.CATEGORY_END_DATE)
			) > 1 then
			'MUL'
		else
			(
				select
					cat.CIN_ABUSE_CATEGORY_CODE
				from
					DM_REGISTRATION_CATEGORIES cat
				where
					cat.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					coalesce(cpp.DEREGISTRATION_DATE,dbo.today()) between cat.CATEGORY_START_DATE and dbo.future(cat.CATEGORY_END_DATE)
			)			
	end cppl_cp_plan_latest_category
from
	DM_REGISTRATIONS cpp
where
	cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
	and
	coalesce(cpp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
order by
	cpp.REGISTRATION_START_DATE desc