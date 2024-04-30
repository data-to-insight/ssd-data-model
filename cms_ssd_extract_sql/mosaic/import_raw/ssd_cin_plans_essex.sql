select
	cin.cin_plan_id,
	cin.Referral_Id cinp_referral_id,
	cin.Person_ID cinp_person_id,
	cin.CIN_Plan_Start_Date cinp_cin_plan_start_date,
	cin.CIN_Plan_End_Date cinp_cin_plan_end_date,
	(
		select
			max(wro.ORG_ID)
		from
			raw.mosaic_fw_dm_prof_rel_types pret
		inner join raw.mosaic_fw_dm_prof_relationships prof
		on prof.PROF_REL_TYPE_CODE = pret.PROF_REL_TYPE_CODE
		and
		pret.DESCRIPTION in ('C&F Allocated Worker', 'Allocated Worker')
		inner join raw.mosaic_fw_worker_roles wro
		on wro.WORKER_ID = prof.WORKER_ID
		and
		coalesce(cin.CIN_Plan_End_Date,cast(getdate() as date)) between wro.START_DATE and coalesce(wro.END_DATE,'1 January 2300')
		and
		wro.PRIMARY_JOB = 'Y'
		where
			prof.PERSON_ID = cin.Person_ID
			and
			coalesce(cin.CIN_Plan_End_Date,cast(getdate() as date)) between prof.START_DATE and coalesce(prof.END_DATE,'1 January 2300')
			and
			replace(replace(replace(convert(varchar, prof.START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(prof.PROF_RELATIONSHIP_ID as varchar(9)))) + cast(prof.PROF_RELATIONSHIP_ID as varchar(9)) = (
				select
					max(replace(replace(replace(convert(varchar, prof1.START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(prof1.PROF_RELATIONSHIP_ID as varchar(9)))) + cast(prof1.PROF_RELATIONSHIP_ID as varchar(9)))
				from
					raw.mosaic_fw_dm_prof_rel_types pret1
				inner join raw.mosaic_fw_dm_prof_relationships prof1
				on prof1.PROF_REL_TYPE_CODE = pret1.PROF_REL_TYPE_CODE
				and
				pret1.DESCRIPTION in ('C&F Allocated Worker', 'Allocated Worker')
				where
					prof1.PERSON_ID = cin.Person_ID
					and
					coalesce(cin.CIN_Plan_End_Date,cast(getdate() as date)) between prof1.START_DATE and coalesce(prof1.END_DATE,'1 January 2300')
			)
	) cinp_cin_plan_team,
	(
		select
			max(prof.WORKER_ID)
		from
			raw.mosaic_fw_dm_prof_rel_types pret
		inner join raw.mosaic_fw_dm_prof_relationships prof
		on prof.PROF_REL_TYPE_CODE = pret.PROF_REL_TYPE_CODE
		and
		pret.DESCRIPTION in ('C&F Allocated Worker', 'Allocated Worker')
		where
			prof.PERSON_ID = cin.Person_ID
			and
			coalesce(cin.CIN_Plan_End_Date,cast(getdate() as date)) between prof.START_DATE and coalesce(prof.END_DATE,'1 January 2300')
			and
			replace(replace(replace(convert(varchar, prof.START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(prof.PROF_RELATIONSHIP_ID as varchar(9)))) + cast(prof.PROF_RELATIONSHIP_ID as varchar(9)) = (
				select
					max(replace(replace(replace(convert(varchar, prof1.START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(prof1.PROF_RELATIONSHIP_ID as varchar(9)))) + cast(prof1.PROF_RELATIONSHIP_ID as varchar(9)))
				from
					raw.mosaic_fw_dm_prof_rel_types pret1
				inner join raw.mosaic_fw_dm_prof_relationships prof1
				on prof1.PROF_REL_TYPE_CODE = pret1.PROF_REL_TYPE_CODE
				and
				pret1.DESCRIPTION in ('C&F Allocated Worker', 'Allocated Worker')
				where
					prof1.PERSON_ID = cin.Person_ID
					and
					coalesce(cin.CIN_Plan_End_Date,cast(getdate() as date)) between prof1.START_DATE and coalesce(prof1.END_DATE,'1 January 2300')
			)
	) cinp_cin_plan_worker_id
from
	SCF.CIN_Plans cin