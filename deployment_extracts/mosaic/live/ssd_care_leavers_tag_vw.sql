declare @personal_advisor_rel_type_codes table (
	PROF_REL_TYPE_CODE			varchar(128),
	description					varchar(1000)
)
--
declare @pathway_plan_step_types table (
	workflow_step_type_id		numeric(9),
	description					varchar(1000)
)
--
insert into @pathway_plan_step_types values
	(498, 'Pathway Plan'),
	(500, 'Pathway Plan Review')
--
insert into @personal_advisor_rel_type_codes values
	('REL.PERSONALADVISOR', 'Personal Advisor')
--
declare @snapshot_date datetime
--
select 
	@snapshot_date = dbo.today();
--
IF OBJECT_ID('tempdb..#care_leavers_tmp') IS NOT NULL
	DROP TABLE #care_leavers_tmp;
--
with days_looked_after as ( 
	select
		cla.person_id,
		dbo.days_diff(
			case
				when coalesce(cla.end_date,dbo.future(null)) > @snapshot_date then
					cast(@snapshot_date as date)
				else
					cla.end_date
				end,
				case
					when cla.start_date < dbo.month_add(per.date_of_birth,12*14) then
						dbo.month_add(per.date_of_birth,12*14)
					else
						cla.start_date
				end
		) + 1 days_looked_after
	from
		dm_cla_summaries cla
	inner join dm_legal_statuses leg
	on leg.legal_status_id = cla.legal_status_id
	inner join dm_persons per
	on per.person_id = cla.person_id
	where
		--CRITERIA: Period of being looked after was between today
		cla.start_date <= @snapshot_date
		and
		--CRITERIA: ...and their 14th birthday
		dbo.future(cla.end_date) >= dbo.month_add(per.date_of_birth,12*14)
		and
		coalesce(leg.is_respite_care,'N') = 'N'
	group by 
		cla.person_id, 
		cla.start_date, 
		cla.end_date, 
		per.date_of_birth
)
select 
	p.person_id,
	case
		when (
				select 
					sum(doc.days_looked_after)
				from
					days_looked_after doc
				where
					doc.person_id = p.person_id
			) >= 91 then
			/****CLA for more than 13 weeks after 14th birthday****/
			case
				when dbo.f_person_age(p.DATE_OF_BIRTH,@snapshot_date) between 16 and 17 then
					case
						when exists (
								select
									1
								from
									DM_PERIODS_OF_CARE poc
								where
									poc.person_id = p.person_id
									and
									@snapshot_date between poc.START_DATE and dbo.future(poc.END_DATE)
							) then 
							'd) Eligible'
						else 
							'a) Relevant child'
					end
				when dbo.f_person_age(p.DATE_OF_BIRTH,@snapshot_date) between 18 and 21 then
					'b) Former relevant child'
				when dbo.f_person_age(p.DATE_OF_BIRTH,@snapshot_date) between 22 and 25 then
					case
						when exists (
								select
									1
								from
									DM_ALLOCATED_WORKERS awkr
								where
									awkr.PERSON_ID = p.PERSON_ID
									and
									@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
								union
								select
									1
								from
									DM_PROF_RELATIONSHIPS pr
								inner join @personal_advisor_rel_type_codes typ
								on typ.PROF_REL_TYPE_CODE = pr.PROF_REL_TYPE_CODE
								where
									pr.PERSON_ID = p.PERSON_ID
									and
									@snapshot_date between pr.START_DATE and dbo.future(pr.END_DATE)
							) then
							'b) Former relevant child'
					end
			end
		else
			/****CLA for less than 13 weeks after 14th birthday****/
			case
				when not exists (
						select
							1
						from
							DM_PERIODS_OF_CARE poc
						where
							poc.person_id = p.person_id
							and
							@snapshot_date between poc.START_DATE and dbo.future(poc.END_DATE)								
					) then
					case
						when dbo.f_person_age(p.DATE_OF_BIRTH,@snapshot_date) between 16 and 21 then
							'c) Qualifying care leaver'
						when dbo.f_person_age(p.DATE_OF_BIRTH,@snapshot_date) between 21 and 25 then
							case
								when exists (
									select
										1
									from
										DM_ALLOCATED_WORKERS awkr
									where
										awkr.PERSON_ID = p.PERSON_ID
										and
										@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
									union
									select
										1
									from
										DM_PROF_RELATIONSHIPS pr
									inner join @personal_advisor_rel_type_codes typ
									on typ.PROF_REL_TYPE_CODE = pr.PROF_REL_TYPE_CODE
									where
										pr.PERSON_ID = p.PERSON_ID
										and
										@snapshot_date between pr.START_DATE and dbo.future(pr.END_DATE)
								) then
									'c) Qualifying care leaver'
							end
					end
			end
	end eligibility
into
	#care_leavers_tmp
from 
	dm_persons p
where
	--CRITERIA: Looked after at some point in the period between 16th birthday and today
	exists (
		select
			1
		from
			DM_PERIODS_OF_CARE poc
		where
			poc.person_id = p.person_id
			and
			( 
				poc.START_DATE <= @snapshot_date
				and
				dbo.future(poc.END_DATE) >= dbo.month_add(p.date_of_birth,12*16)
			)
	);
--
with care_leaver_status_info as (
	select
		q.person_id,
		q.date_of_situation,
		(
			select
				case
					when g.category_value in ('YES', 'NO', 'DIED', 'REFU', 'NREQ', 'RHOM') then
						g.category_value
					else
						itt.description
				end
			from
				dm_former_in_touch_types itt
			inner join 	dm_mapping_groups g
			on g.mapped_value = itt.in_touch_type
			and
			g.group_name = 'SSDA903 In Touch Type'
			where
				itt.in_touch_type = q.in_touch_type
		) in_touch_type,
		(
			select
				case
					when g.category_value in (
							'B', 'C', 'D', 'E', 'G', 'H', 'K', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
						) then
						g.category_value
					else
						acc.description
				end
			from
				dm_former_accom_types acc
			inner join dm_mapping_groups g
			on g.mapped_value = acc.accomodation_type
			and
			g.group_name = 'SSDA903 Accommodation Type'
			where
				acc.accomodation_type = q.accomodation_type
		) accommodation_type,
		q.accomodation_suitable,
		(
			select
				case
					when g.category_value in ('F1', 'P1', 'F2', 'P2', 'F4', 'P4', 'F5', 'P5', 'G4', 'G5', 'G6') then
						g.category_value
					else
						act.description
				end
			from
				 dm_former_activity_types act
			inner join dm_mapping_groups g
			on g.mapped_value = act.activity_type
			and
			g.group_name = 'SSDA903 Activity Type'
			where
				act.activity_type = q.activity_type
		) activity_status,
		dbo.to_weighted_start(q.date_of_situation,q.future_prospect_id) weighted_start
	from
		dm_former_looked_after q
)
--
select
	null clea_care_table_id, -- [REVIEW]
	clc.person_id clea_person_id,
	clc.eligibility clea_care_leaver_eligibility,
	(
		select
			info.in_touch_type
		from
			care_leaver_status_info info
		where
			info.person_id = clc.person_id
			and
			info.weighted_start = (
				select
					max(info1.weighted_start)
				from
					care_leaver_status_info info1
				where
					info1.person_id = clc.person_id
					and
					info1.DATE_OF_SITUATION <= @snapshot_date
			)
	) clea_care_leaver_in_touch,
	(
		select
			info.date_of_situation
		from
			care_leaver_status_info info
		where
			info.person_id = clc.person_id
			and
			info.weighted_start = (
				select
					max(info1.weighted_start)
				from
					care_leaver_status_info info1
				where
					info1.person_id = clc.person_id
					and
					info1.DATE_OF_SITUATION <= @snapshot_date
			)
	) clea_care_leaver_latest_contact,
	(
		select
			info.accommodation_type
		from
			care_leaver_status_info info
		where
			info.person_id = clc.person_id
			and
			info.weighted_start = (
				select
					max(info1.weighted_start)
				from
					care_leaver_status_info info1
				where
					info1.person_id = clc.person_id
					and
					info1.DATE_OF_SITUATION <= @snapshot_date
			)
	) clea_care_leaver_accommodation,
	(
		select
			info.accomodation_suitable
		from
			care_leaver_status_info info
		where
			info.person_id = clc.person_id
			and
			info.weighted_start = (
				select
					max(info1.weighted_start)
				from
					care_leaver_status_info info1
				where
					info1.person_id = clc.person_id
					and
					info1.DATE_OF_SITUATION <= @snapshot_date
			)
	) clea_care_leaver_accom_suitable,
	(
		select
			info.activity_status
		from
			care_leaver_status_info info
		where
			info.person_id = clc.person_id
			and
			info.weighted_start = (
				select
					max(info1.weighted_start)
				from
					care_leaver_status_info info1
				where
					info1.person_id = clc.person_id
					and
					info1.DATE_OF_SITUATION <= @snapshot_date
			)
	) clea_care_leaver_activity,
	(
		select
			max(pwp.completed_on)
		from
			dm_workflow_steps pwp
		inner join DM_SUBGROUP_SUBJECTS psgs
		on psgs.SUBGROUP_ID = pwp.SUBGROUP_ID
		and
		psgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @pathway_plan_step_types ptyp
		on ptyp.workflow_step_type_id = pwp.WORKFLOW_STEP_TYPE_ID
		where
			psgs.SUBJECT_COMPOUND_ID = clc.person_id
			and
			pwp.completed_on <= @snapshot_date
	) clea_pathway_plan_review_date,
	(
		select
			max(wkr.FULL_NAME)
		from
			DM_PROF_RELATIONSHIPS pr
		inner join @personal_advisor_rel_type_codes typ
		on typ.PROF_REL_TYPE_CODE = pr.PROF_REL_TYPE_CODE
		inner join dm_workers wkr
		on wkr.WORKER_ID = pr.WORKER_ID
		where
			pr.PERSON_ID = clc.person_id
			and 
			@snapshot_date between pr.START_DATE and dbo.future(pr.END_DATE)
	) clea_care_leaver_personal_advisor,
	(
		select
			org.NAME
		from
			DM_ALLOCATED_WORKERS awkr
		inner join DM_WORKER_ROLES wro
		on wro.WORKER_ID = awkr.WORKER_ID
		and
		@snapshot_date between wro.START_DATE and dbo.future(wro.END_DATE)
		inner join DM_ORGANISATIONS org
		on org.ORGANISATION_ID = wro.ORGANISATION_ID
		where
			awkr.PERSON_ID = clc.person_id
			and
			@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
			and
			dbo.to_weighted_start(awkr.START_DATE,awkr.ALLOCATION_ID) = (
				select
					max(dbo.to_weighted_start(awkr1.START_DATE,awkr1.ALLOCATION_ID))
				from
					DM_ALLOCATED_WORKERS awkr1
				where
					awkr1.PERSON_ID = clc.person_id
					and
					@snapshot_date between awkr1.START_DATE and dbo.future(awkr1.END_DATE)
			)
			and
			dbo.to_weighted_start(wro.START_DATE,wro.WORKER_ROLE_ID) = (
				select
					max(dbo.to_weighted_start(wro1.START_DATE,wro1.WORKER_ROLE_ID))
				from
					DM_WORKER_ROLES wro1
				where
					wro1.WORKER_ID = awkr.WORKER_ID
					and
					@snapshot_date between wro1.START_DATE and dbo.future(wro1.END_DATE)
			)
	) clea_care_leaver_allocated_team,
	(
		select
			awkr.WORKER_ID
		from
			DM_ALLOCATED_WORKERS awkr
		where
			awkr.PERSON_ID = clc.person_id
			and
			@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
			and
			dbo.to_weighted_start(awkr.START_DATE,awkr.ALLOCATION_ID) = (
				select
					max(dbo.to_weighted_start(awkr1.START_DATE,awkr1.ALLOCATION_ID))
				from
					DM_ALLOCATED_WORKERS awkr1
				where
					awkr1.PERSON_ID = clc.person_id
					and
					@snapshot_date between awkr1.START_DATE and dbo.future(awkr1.END_DATE)
			)
	) clea_care_leaver_worker_id
from
	#care_leavers_tmp clc
where
	clc.eligibility is not null