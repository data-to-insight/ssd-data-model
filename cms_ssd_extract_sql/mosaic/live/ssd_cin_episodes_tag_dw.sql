select
	ref.REFERRAL_ID cine_referral_id,
	ref.PERSON_ID cine_person_id,
	ref.REFERRAL_DATE cine_referral_date,
	(
		select
			max(sugt.NEED_CODE_CATEGORY_CODE)
		from
			DM_SERVICE_USER_GROUPS sug
		inner join DM_SERV_USER_GROUP_TYPES sugt
		on sugt.GROUP_TYPE = sug.FULL_GROUP_TYPE
		where
			sug.PERSON_ID = ref.PERSON_ID
			and
			ref.REFERRAL_DATE between sug.START_DATE and dbo.future(sug.END_DATE)
	) cine_cin_primary_need_code,
	ref.SOURCE_OF_REFERRAL cine_referral_source,
	case
		when ref.NFA_DATE is null then
			'N'
		else
			'Y'
	end cin_referral_nfa,
	ref.CLOSURE_REASON cine_close_reason,
	stp.RESPONSIBLE_TEAM_ID cine_referral_team,
	stp.ASSIGNEE_ID cine_referral_worker_id
from
	dm_cin_referrals ref
inner join DM_WORKFLOW_STEPS stp
on ref.REFERRAL_ID = stp.WORKFLOW_STEP_ID
order by
	ref.REFERRAL_DATE desc