select
	null prof_professional_id,
	wkr.WORKER_ID prof_staff_id, -- [REVIEW]
	null prof_professional_name, -- [REVIEW]
	null prof_social_worker_registration_no,
	null prof_agency_worker_flag,
	null prof_professional_job_title,
	(
		select
			count(distinct alc.person_id)
		from
			DM_ALLOCATED_WORKERS alc
		where
			alc.worker_id = wkr.WORKER_ID
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between alc.START_DATE and coalesce(alc.end_date,'1 January 2300')
	) prof_professional_caseload,
	(
		select
			max(org.name)
		from
			DM_WORKER_ROLES wro
		inner join dm_organisations org
		on org.ORGANISATION_ID = wro.ORGANISATION_ID
		where
			wro.WORKER_ID = wkr.worker_id
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between wro.START_DATE and coalesce(wro.end_date,'1 January 2300')
	) prof_professional_department,
	null prof_full_time_equivalency
from
	dm_workers wkr
where
	exists (
		select
			1
		from
			DM_ALLOCATED_WORKERS alc
		where
			alc.worker_id = wkr.WORKER_ID
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between alc.START_DATE and coalesce(alc.end_date,'1 January 2300')
	)