select
	ref.workflow_step_id cine_referral_id,
	ref.PERSON_ID cine_person_id,
	ref.REFERRAL_DATE cine_referral_date,
	ref.NEED_CODE cine_cin_primary_need_code,
	ref.referral_source cine_referral_source,
	ref.REFERRAL_NFA cin_referral_nfa,
	ref.REASON_FOR_CLOSURE cine_close_reason,
	ref.CLOSURE_DATE cine_close_date,
	ref.RESPONSIBLE_TEAM_ID cine_referral_team,
	ref.ASSIGNEE_ID cine_referral_worker_id
from
	SCF.Referrals ref