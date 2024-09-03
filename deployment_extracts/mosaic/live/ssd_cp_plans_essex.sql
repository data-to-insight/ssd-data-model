if object_id('tempdb..#referrals') is not null
	drop table #referrals
--
SELECT
	RG.PERSON_ID, 
	RG.REGISTRATION_ID,
	MAX(REF.WORKFLOW_STEP_ID) LAST_REFERRAL_ID,
	MAX(REF.REFERRAL_DATE) REFERRAL_DATE
into
	#referrals
FROM 
	RAW.MOSAIC_FW_DM_REGISTRATIONS RG
inner join SCF.REFERRALS REF 
ON RG.PERSON_ID = REF.PERSON_ID
AND 
REF.REFERRAL_DATE <= RG.REGISTRATION_START_DATE
AND 
REF.REFERRAL_NFA IS NULL 
AND 
(REF.CLOSURE_DATE IS NULL OR REF.CLOSURE_DATE > RG.REGISTRATION_START_DATE)
AND 
REF.STEP_STATUS <> 'CANCELLED'
GROUP BY 
	RG.PERSON_ID, 
	RG.REGISTRATION_ID
--
if object_id('tempdb..#workers') is not null
	drop table #workers
--
select
	*
into
	#workers
from
	--In-line view to supress rogue duplicate data
	(
		select
			pw.PERSON_ID,
			pw.worker_id,
			pw.start_date,
			pw.end_date,
			pw.id people_workers_id,
			replace(replace(replace(convert(varchar, pw.START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(pw.id as varchar(9)))) + cast(pw.id as varchar(9)) weighted_start,
			row_number() over(partition by pw.person_id, pw.start_date, pw.id order by pw.person_id, pw.start_date, pw.id) row_num
		from
			raw.mosaic_fw_people_workers pw
		where
			pw.TYPE in ( 'ALLWORK', 'ALLWORKCF')
			and
			exists (
				select
					1
				from
					raw.mosaic_fw_dm_registrations reg
				where
					reg.PERSON_ID = pw.PERSON_ID
					and
					reg.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(reg.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
			)
	) x
where
	x.row_num = 1
--
create clustered index people_workers_pers_idx on #workers (person_id, start_date, end_date)
create index people_workers_weighted_start_idx on #workers (weighted_start)
create index people_workers_wkr_idx on #workers (worker_id)
--
if object_id('tempdb..#registration_categories') is not null
	drop table #registration_categories
--
select
	prc.*,
	rct.category_description
into
	#registration_categories
from
	raw.mosaic_fw_dm_registration_categories prc
inner join raw.mosaic_fw_dm_regist_category_types rct
on rct.CATEGORY_ID = prc.CATEGORY_ID
where
	prc.IS_CHILD_PROTECTION_PLAN = 'Y'
--
create clustered index people_workers_pers_idx on #registration_categories (REGISTRATION_ID, category_start_date, category_end_date)
--
select
	cpp.REGISTRATION_ID cppl_cp_plan_id,
	(
		select
			ref.LAST_REFERRAL_ID
		from
			#referrals ref
		where
			ref.REGISTRATION_ID = cpp.REGISTRATION_ID
	) cppl_referral_id,
	cpp.REGISTRATION_STEP_ID cppl_icpc_id, -- [REVIEW] from cppl_ initial_ cp_ conference_ id 290424 RH 
	cpp.person_id cppl_person_id,
	cpp.REGISTRATION_START_DATE cppl_cp_plan_start_date,
	cpp.DEREGISTRATION_DATE cppl_cp_plan_end_date,
	(
		select
			(
				select
					max(wro.org_id)
				from
					raw.mosaic_fw_worker_roles wro
				where
					wro.WORKER_ID = pw.WORKER_ID
					and
					wro.primary_job = 'Y'
					and
					coalesce(cpp.deregistration_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between wro.START_DATE and coalesce(wro.end_date,'1 January 2300')
			)
		from
			#workers pw
		where
			pw.PERSON_ID = cpp.PERSON_ID
			and
			coalesce(cpp.deregistration_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw.START_DATE and coalesce(pw.end_date,'1 January 2300')
			and
			pw.weighted_start = (
				select
					max(pw1.weighted_start)
				from
					#workers pw1
				where
					pw1.PERSON_ID = cpp.PERSON_ID
					and
					coalesce(cpp.deregistration_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw1.START_DATE and coalesce(pw1.end_date,'1 January 2300')
			)
	) cppl_cp_plan_team,
	(
		select
			pw.WORKER_ID
		from
			#workers pw
		where
			pw.PERSON_ID = cpp.PERSON_ID
			and
			coalesce(cpp.deregistration_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw.START_DATE and coalesce(pw.end_date,'1 January 2300')
			and
			pw.weighted_start = (
				select
					max(pw1.weighted_start)
				from
					#workers pw1
				where
					pw1.PERSON_ID = cpp.PERSON_ID
					and
					coalesce(cpp.deregistration_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw1.START_DATE and coalesce(pw1.end_date,'1 January 2300')
			)
	) cppl_cp_plan_worker_id,
	case
		when (
				select
					count(1)
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, prc.CATEGORY_START_DATE, 103), 103) = convert(datetime, convert(varchar, cpp.REGISTRATION_START_DATE, 103), 103)
			) > 1 
			or
			exists (
				select
					1
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, prc.CATEGORY_START_DATE, 103), 103) = convert(datetime, convert(varchar, cpp.REGISTRATION_START_DATE, 103), 103)
					and
					prc.CATEGORY_DESCRIPTION = 'Multiple (includes category not recorded)'
			) then
			'Multiple Categories of Abuse'
		else (
				select
					prc.CATEGORY_DESCRIPTION
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, prc.CATEGORY_START_DATE, 103), 103) = convert(datetime, convert(varchar, cpp.REGISTRATION_START_DATE, 103), 103)
			) 
	end cppl_cp_plan_initial_category,
	case
		when (
				select
					count(1)
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, coalesce(prc.CATEGORY_END_DATE,getdate()), 103), 103) between prc.CATEGORY_START_DATE and coalesce(prc.CATEGORY_END_DATE,'1 January 2300')
			) > 1 
			or
			exists (
				select
					1
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, coalesce(prc.CATEGORY_END_DATE,getdate()), 103), 103) between prc.CATEGORY_START_DATE and coalesce(prc.CATEGORY_END_DATE,'1 January 2300')
					and
					prc.CATEGORY_DESCRIPTION = 'Multiple (includes category not recorded)'
			) then
			'Multiple Categories of Abuse'
		else (
				select
					prc.CATEGORY_DESCRIPTION
				from
					#registration_categories prc
				where
					prc.REGISTRATION_ID = cpp.REGISTRATION_ID
					and
					convert(datetime, convert(varchar, coalesce(prc.CATEGORY_END_DATE,getdate()), 103), 103) between prc.CATEGORY_START_DATE and coalesce(prc.CATEGORY_END_DATE,'1 January 2300')
			) 
	end cppl_cp_plan_initial_category
from
	raw.mosaic_fw_dm_registrations cpp
where
	cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
	and
	coalesce(cpp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
order by
	5 desc