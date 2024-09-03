if object_id('tempdb..#referrals') is not null
	drop table #referrals
--
SELECT
	cla.PERSON_ID, 
	cla.PERIOD_OF_CARE_ID,
	MAX(REF.WORKFLOW_STEP_ID) LAST_REFERRAL_ID,
	MAX(REF.REFERRAL_DATE) REFERRAL_DATE
into
	#referrals
FROM 
	SCF.Children_In_Care cla
inner join SCF.REFERRALS REF 
ON cla.PERSON_ID = REF.PERSON_ID
AND 
REF.REFERRAL_DATE <= cla.poc_start
AND 
REF.REFERRAL_NFA IS NULL 
AND 
(REF.CLOSURE_DATE IS NULL OR REF.CLOSURE_DATE > cla.poc_end)
AND 
REF.STEP_STATUS <> 'CANCELLED'
GROUP BY 
	cla.PERSON_ID, 
	cla.PERIOD_OF_CARE_ID
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
					SCF.Children_In_Care cla
				where
					cla.PERSON_ID = pw.PERSON_ID
			)
	) x
where
	x.row_num = 1
--
select
	replace(replace(replace(convert(varchar, cla.EPISODE_START_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cla.PERSON_ID as varchar(9)))) + cast(cla.PERSON_ID as varchar(9)) clae_cla_episode_id,
	cla.PERSON_ID clae_person_id,
	cla.episode_start_date clae_cla_episode_start_date, -- [REVIEW] 290424 RH
	cla.reason_for_new_episode clae_cla_episode_start_reason,
	cla.CATEGORY_OF_NEED clae_cla_primary_need,
	cla.PERIOD_OF_CARE_ID clae_cla_id,
	(
		select
			ref.LAST_REFERRAL_ID
		from
			#referrals ref
		where
			ref.PERIOD_OF_CARE_ID = cla.PERIOD_OF_CARE_ID
	) clae_referral_id,
	cla.EPISODE_END_DATE clae_cla_episode_ceased, -- [REVIEW] 290424 RH
	cla.REASON_CEASED_DESCRIPTION clae_cla_episode_ceased_reason, -- [REVIEW] 290424 RH
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
					coalesce(cla.episode_end_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between wro.START_DATE and coalesce(wro.end_date,'1 January 2300')
			)
		from
			#workers pw
		where
			pw.PERSON_ID = cla.PERSON_ID
			and
			coalesce(cla.episode_end_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw.START_DATE and coalesce(pw.end_date,'1 January 2300')
			and
			pw.weighted_start = (
				select
					max(pw1.weighted_start)
				from
					#workers pw1
				where
					pw1.PERSON_ID = cla.PERSON_ID
					and
					coalesce(cla.episode_end_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw1.START_DATE and coalesce(pw1.end_date,'1 January 2300')
			)
	) cppl_cp_plan_team,
	(
		select
			pw.WORKER_ID
		from
			#workers pw
		where
			pw.PERSON_ID = cla.PERSON_ID
			and
			coalesce(cla.episode_end_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw.START_DATE and coalesce(pw.end_date,'1 January 2300')
			and
			pw.weighted_start = (
				select
					max(pw1.weighted_start)
				from
					#workers pw1
				where
					pw1.PERSON_ID = cla.PERSON_ID
					and
					coalesce(cla.episode_end_date,convert(datetime, convert(varchar, getdate(), 103), 103)) between pw1.START_DATE and coalesce(pw1.end_date,'1 January 2300')
			)
	) cppl_cp_plan_worker_id
from
	SCF.Children_In_Care cla