select
	null prof_professional_id,
	wkr.WORKER_ID prof_staff_id, -- [REVIEW]
	null prof_professional_name, -- [REVIEW]
	(
		select
			sw_no.REFERENCE
		from
			SCF.Workers_SW_Numbers sw_no
		where
			sw_no.WORKER_ID = wkr.WORKER_ID
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between sw_no.START_DATE and coalesce(sw_no.end_date,'1 January 2300')
	) prof_social_worker_registration_no,
	null prof_agency_worker_flag,
	null prof_professional_job_title,
	(
		select
			count(prel.person_id)
		from
			raw.mosaic_fw_dm_prof_relationships prel
		where
			prel.worker_id = wkr.WORKER_ID
			and
			prel.PROF_REL_TYPE_CODE in (
				'REL.ALLWORK',
				'REL.ALLWORKCF'
			)
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between prel.START_DATE and coalesce(prel.end_date,'1 January 2300')
	) prof_professional_caseload,
	(
		select
			max(wro.ORG_ID)
		from
			raw.mosaic_fw_worker_roles wro
		inner join raw.mosaic_fw_organisations org
		on org.ID = wro.ORG_ID
		where
			wro.WORKER_ID = wkr.worker_id
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between wro.START_DATE and coalesce(wro.end_date,'1 January 2300')
	) prof_professional_department,
	null prof_full_time_equivalency
from
	raw.mosaic_fw_dm_workers wkr
where
	exists (
		select
			1
		from
			raw.mosaic_fw_dm_prof_relationships prel
		where
			prel.worker_id = wkr.WORKER_ID
			and
			prel.PROF_REL_TYPE_CODE in (
				'REL.ALLWORK',
				'REL.ALLWORKCF'
			)
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between prel.START_DATE and coalesce(prel.end_date,'1 January 2300')
	)