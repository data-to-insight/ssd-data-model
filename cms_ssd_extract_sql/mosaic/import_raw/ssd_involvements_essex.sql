select
	prof.PROF_RELATIONSHIP_ID invo_involvements_id,
	prof.WORKER_ID invo_professional_id,
	prof.PROF_REL_TYPE_CODE invo_professional_role_id,
	(
		select
			top 1
			wro.ORG_ID
		from
			raw.mosaic_fw_worker_roles wro
		where
			wro.worker_id = prof.WORKER_ID
			and
			wro.PRIMARY_JOB = 'Y'
			and
			prof.START_DATE between wro.START_DATE and coalesce(wro.END_DATE,'1 January 2300')
	) invo_professional_team,
	(
		select
			min(ref.PERSON_REFERRAL_ID)
		from
			SCF.Referrals ref
		where
			ref.PERSON_ID = prof.PERSON_ID
			and
			prof.START_DATE between ref.REFERRAL_DATE and coalesce(ref.closure_date,'1 January 2300')
	) invo_referral_id,
	prof.START_DATE invo_involvement_start_date,
	prof.END_DATE invo_involvement_end_date,
	(
		select
			rd.REF_DESCRIPTION
		from
			raw.mosaic_fw_reference_data rd
		where
			rd.ref_code = prof.END_DATE_REASON
			and
			rd.REF_DOMAIN = 'WORKER_END_DATE_REASON'
	)
from
	raw.mosaic_fw_dm_prof_relationships prof