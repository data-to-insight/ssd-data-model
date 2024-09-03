if object_id('tempdb..##populate_ssd_early_help_episodes') is not null
	drop procedure ##populate_ssd_early_help_episodes
go
--
create procedure ##populate_ssd_early_help_episodes (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_early_help_episodes

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_CACHED_FORM_ANS

- dm_workflow_forwards

- dm_workflow_steps_people_vw

- dm_workflow_backwards

- report_days

- dm_worker_roles

- DM_PROF_RELATIONSHIPS
=============================================================================

*/
	begin try
		--
		declare @eh_step_types table (
			workflow_step_type_id			numeric(9),
			workflow_step_type_description	varchar(500)
		)
		--
		insert into @eh_step_types values
			(1208, 'Early Help Referral Decision (EH)'),
			(1211, 'Early Help Engagement and Exploration (EH)'),
			(1212, 'Early Help Family Assessment (EH)'),
			(1214, 'Early Help Team Around The Family (TAF) Review(EH)'),
			(1217, 'Early Help Family Closure (EH))')
		--
		declare @reason_for_eh_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @reason_for_eh_question_user_codes values
			('reason_for_eh_episode')
		--
		declare @reason_for_eh_closure_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @reason_for_eh_closure_question_user_codes values
			('e04ea8d8-e6c0-465c-87c1-10c4ad1e18c7')
		--
		declare @early_help_worker_prof_rel_types table (
			prof_rel_type_code	varchar(20),
			description			varchar(80)
		)
		--
		insert into @early_help_worker_prof_rel_types values
			('REL.IEYSF', 'IEYS Family Worker')
		--
		if object_id('tempdb..##ssd_early_help_episodes') is not null
			drop table ##ssd_early_help_episodes
		--
		create table ##ssd_early_help_episodes (
			earl_episode_id				varchar(48),
			earl_person_id				varchar(48),
			earl_episode_start_date		datetime,
			earl_episode_end_date		datetime,
			earl_episode_reason			varchar(100),
			earl_episode_end_reason		varchar(100),
			earl_episode_organisation	varchar(100),
			earl_episode_worker_id		varchar(48)
		)
		--
		if object_id('tempdb..#early_help_cohort') is not null
			drop table #early_help_cohort
		--
		create table #early_help_cohort (
			tmp_period_id					numeric(9),
			person_id						numeric(9),
			eh_referral_workflow_step_id	numeric(9),
			eh_start_date					datetime,
			eh_start_reason					varchar(500),
			eh_closure_step_id				numeric(9),
			eh_closure_weighted_end			varchar(64),
			eh_end_date						datetime,
			eh_end_reason					varchar(500)
		)
		--
		--Insert all EH Periods into the temporary table
		insert into #early_help_cohort (
			tmp_period_id,
			person_id,
			eh_referral_workflow_step_id,
			eh_start_date,
			eh_start_reason,
			eh_closure_weighted_end
		)
		select
			row_number() over (order by s.person_id, s.workflow_step_id) tmp_period_id,
			s.person_id,
			s.workflow_step_id eh_referral_workflow_step_id,
			case
				when s.started_on < s.INCOMING_ON then 
					dbo.no_time(s.started_on)
				else
					dbo.no_time(s.incoming_on)
			end eh_start_date,
			(
				select
					max(cfa.text_answer)
				from
					DM_CACHED_FORM_ANS cfa
				inner join @reason_for_eh_question_user_codes t
				on t.question_user_code = cfa.question_user_code
				where
					cfa.workflow_step_id = s.workflow_step_id
					and
					case 
						when cfa.subject_person_id <= 0 then 
							s.person_id
						else 
							cfa.subject_person_id
					end = s.person_id
			) eh_start_reason,
			case
				when not exists (
						select
							1
						from
							dm_workflow_forwards fwd
						inner join dm_workflow_steps_people_vw l_ends
						on l_ends.workflow_step_id = fwd.SUBSEQUENT_WORKFLOW_STEP_ID
						and
						l_ends.step_status != 'CANCELLED'
						inner join @eh_step_types y
						on y.workflow_step_type_id = l_ends.WORKFLOW_STEP_TYPE_ID
						where
							fwd.WORKFLOW_STEP_ID = s.workflow_step_id
							and
							l_ends.person_id = s.person_id
					) and s.step_status = 'COMPLETED' then
					dbo.to_weighted_start(s.completed_on,s.workflow_step_id)
				else
					(
						select
							min(dbo.to_weighted_start(ends.completed_on,ends.workflow_step_id))
						from
							dm_workflow_forwards fwd
						inner join dm_workflow_steps_people_vw ends
						on ends.workflow_step_id = fwd.subsequent_workflow_step_id
						and
						ends.step_status = 'COMPLETED'
						inner join @eh_step_types y
						on y.workflow_step_type_id = ends.WORKFLOW_STEP_TYPE_ID
						where
							fwd.workflow_step_id = s.workflow_step_id
							and
							ends.person_id = s.person_id
							and
							not exists (
								select
									1
								from
									dm_workflow_forwards fwd
								inner join dm_workflow_steps_people_vw l_ends
								on l_ends.workflow_step_id = fwd.subsequent_workflow_step_id
								and
								l_ends.step_status != 'CANCELLED'
								inner join @eh_step_types y
								on y.workflow_step_type_id = l_ends.WORKFLOW_STEP_TYPE_ID
								where
									fwd.WORKFLOW_STEP_ID = ends.workflow_step_id
									and
									fwd.ADJACENT = 'Y'
									and
									l_ends.person_id = ends.person_id							
							)
					)
			end eh_closure_weighted_end
		from
			dm_workflow_steps_people_vw s
		inner join @eh_step_types t
		on t.workflow_step_type_id = s.WORKFLOW_STEP_TYPE_ID
		where
			s.step_status not in ('CANCELLED', 'PROPOSED')
			and
			--CRITERIA: This EH Step did not come from another EH Step
			not exists (
				select
					1
				from
					dm_workflow_backwards bwd
				inner join dm_workflow_steps_people_vw p_stp
				on p_stp.workflow_step_id = bwd.preceding_workflow_step_id
				and
				p_stp.step_status != 'CANCELLED'
				inner join @eh_step_types x
				on x.workflow_step_type_id = p_stp.WORKFLOW_STEP_TYPE_ID 
				where
					bwd.workflow_step_id = s.workflow_step_id
					and
					bwd.adjacent = 'Y'
			)
		--
		--Set EH Closure Step ID
		update #early_help_cohort
		set
			eh_closure_step_id = (
					select
						stp.WORKFLOW_STEP_ID
					from
						dm_workflow_steps_people_vw stp
					where
						stp.person_id = #early_help_cohort.person_id
						and
						dbo.to_weighted_start(stp.completed_on,stp.workflow_step_id) = #early_help_cohort.eh_closure_weighted_end
				)
		where
			#early_help_cohort.eh_closure_weighted_end is not null
		--
		--Set Closure reason and date
		update #early_help_cohort
		set
			eh_end_date = (
					select
						dbo.no_time(stp.COMPLETED_ON)
					from
						dm_workflow_steps_people_vw stp
					where
						stp.WORKFLOW_STEP_ID = eh_closure_step_id
						and
						stp.person_id = #early_help_cohort.person_id
				),
			eh_end_reason = (
				select
					max(cfa.text_answer)
				from
					DM_CACHED_FORM_ANS cfa
				inner join @reason_for_eh_closure_question_user_codes t
				on t.question_user_code = cfa.question_user_code
				where
					cfa.workflow_step_id = #early_help_cohort.eh_closure_step_id
					and
					case 
						when cfa.subject_person_id <= 0 then 
							#early_help_cohort.person_id
						else 
							cfa.subject_person_id
					end = #early_help_cohort.person_id
				)
		where
			#early_help_cohort.eh_closure_weighted_end is not null
		--
		--Where EH Plan B starts in the middle EH Plan A, change end date of EH Plan A to match EH Plan B
		update #early_help_cohort
		set
			eh_end_date = (
							select
								(
									select
										min(rd.curr_day) -1
									from
										report_days rd
									where
										rd.curr_day > #early_help_cohort.eh_start_date
										and
										not exists (
											select
												1
											from
												#early_help_cohort x
											where
												x.person_id = #early_help_cohort.person_id
												and
												rd.curr_day between x.eh_start_date and dbo.future(x.eh_end_date)
										)
								)
						)
		from
			#early_help_cohort
		where
			exists (
				select
					1
				from
					#early_help_cohort t
				where
					t.person_id = #early_help_cohort.person_id
					and
					t.eh_start_date between #early_help_cohort.eh_start_date and dbo.future(#early_help_cohort.eh_end_date)
					and
					dbo.future(t.eh_end_date) > coalesce(#early_help_cohort.eh_end_date,'1 January 1900')
					and
					t.tmp_period_id != #early_help_cohort.tmp_period_id
			)
			--
		--Delete completely overlapped EH Plans
		delete from #early_help_cohort
		where
			exists (
				select
					1
				from
					#early_help_cohort z
				where
					z.person_id = #early_help_cohort.person_id
					and
					z.eh_start_date <= #early_help_cohort.eh_start_date
					and
					dbo.future(z.eh_end_date) >= dbo.future(#early_help_cohort.eh_end_date)
					and
					dbo.to_weighted_start(z.eh_start_date,z.tmp_period_id) < dbo.to_weighted_start(#early_help_cohort.eh_start_date,#early_help_cohort.tmp_period_id)
			)
		--
		--Insert into final table...
		insert into ##ssd_early_help_episodes (
			earl_episode_id,
			earl_person_id,
			earl_episode_start_date,
			earl_episode_end_date,
			earl_episode_reason,
			earl_episode_end_reason,
			earl_episode_organisation,
			earl_episode_worker_id
		)
		select
			cht.eh_referral_workflow_step_id earl_episode_id,
			cht.person_id,
			cht.eh_start_date,
			cht.eh_end_date,
			cht.eh_start_reason earl_episode_reason,
			cht.eh_end_reason earl_episode_end_reason,
			(
				select
					(
						select
							max(wro.ORGANISATION_ID)
						from
							dm_worker_roles wro
						where
							wro.WORKER_ID = prel.WORKER_ID
							and
							coalesce(case when dbo.future(prel.END_DATE) < dbo.future(cht.eh_end_date) then prel.end_date end,cht.eh_end_date,dbo.today()) between wro.START_DATE and dbo.future(wro.END_DATE)
							and
							wro.PRIMARY_ROLE = 'Y'
					)
				from
					DM_PROF_RELATIONSHIPS prel
				inner join @early_help_worker_prof_rel_types ptyp
				on ptyp.prof_rel_type_code = prel.PROF_REL_TYPE_CODE
				where
					prel.PERSON_ID = cht.person_id
					and
					prel.START_DATE <= dbo.future(cht.eh_end_date)
					and
					dbo.future(prel.END_DATE) >= cht.eh_start_date
					and
					dbo.to_weighted_start(prel.START_DATE,prel.PROF_RELATIONSHIP_ID) = (
						select
							max(dbo.to_weighted_start(prel1.START_DATE,prel1.PROF_RELATIONSHIP_ID))
						from
							DM_PROF_RELATIONSHIPS prel1
						inner join @early_help_worker_prof_rel_types ptyp1
						on ptyp1.prof_rel_type_code = prel1.PROF_REL_TYPE_CODE
						where
							prel1.PERSON_ID = cht.person_id
							and
							prel1.START_DATE <= dbo.future(cht.eh_end_date)
							and
							dbo.future(prel.END_DATE) >= cht.eh_start_date
					)
			) earl_episode_organisation,
			(
				select
					prel.WORKER_ID
				from
					DM_PROF_RELATIONSHIPS prel
				inner join @early_help_worker_prof_rel_types ptyp
				on ptyp.prof_rel_type_code = prel.PROF_REL_TYPE_CODE
				where
					prel.PERSON_ID = cht.person_id
					and
					prel.START_DATE <= dbo.future(cht.eh_end_date)
					and
					dbo.future(prel.END_DATE) >= cht.eh_start_date
					and
					dbo.to_weighted_start(prel.START_DATE,prel.PROF_RELATIONSHIP_ID) = (
						select
							max(dbo.to_weighted_start(prel1.START_DATE,prel1.PROF_RELATIONSHIP_ID))
						from
							DM_PROF_RELATIONSHIPS prel1
						inner join @early_help_worker_prof_rel_types ptyp1
						on ptyp1.prof_rel_type_code = prel1.PROF_REL_TYPE_CODE
						where
							prel1.PERSON_ID = cht.person_id
							and
							prel1.START_DATE <= dbo.future(cht.eh_end_date)
							and
							dbo.future(prel.END_DATE) >= cht.eh_start_date
					)
			) earl_episode_worker_id
		from
			#early_help_cohort cht
		where
			cht.eh_start_date <= @end_date
			and
			dbo.future(cht.eh_end_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cin_visits') is not null
	drop procedure ##populate_ssd_cin_visits
go
--
create procedure ##populate_ssd_cin_visits (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ##ssd_cin_visits

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_cin_referrals

- DM_CACHED_FORM_ANSWERS

- dm_visits

- dm_visit_types
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cin_visits') IS NOT NULL
			DROP TABLE ##ssd_cin_visits
		--
		create table ##ssd_cin_visits (
			cinv_cin_visit_id				varchar(48),
			cinv_cin_plan_id				varchar(48),
			cinv_cin_visit_date				datetime,
			cinv_cin_visit_seen				varchar(1),
			cinv_cin_visit_seen_alone		varchar(1),
			cinv_cin_visit_bedroom			varchar(1)
		)
		--
		declare @cin_visit_types table (
			visit_type_code			varchar(20),
			visit_type_description	varchar(88)
		)
		--
		insert into @cin_visit_types values
			('STP.1189', 'Step Child in need visit (CSSW)'),
			('VIS.CIN', 'Visit Children in need')
		--
		declare @bedroom_seen_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @bedroom_seen_question_user_codes values
			('seen_bedroom')
		--
		declare @child_seen_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @child_seen_question_user_codes values
			('child_seen')
		--
		insert into ##ssd_cin_visits (
			cinv_cin_visit_id,
			cinv_cin_plan_id,
			cinv_cin_visit_date,
			cinv_cin_visit_seen,
			cinv_cin_visit_seen_alone,
			cinv_cin_visit_bedroom
		)
		select
			vis.VISIT_ID cinv_cin_visit_id,
			(
				select
					max(ref.REFERRAL_ID)
				from
					dm_cin_referrals ref
				where
					ref.PERSON_ID = vis.PERSON_ID
					and
					vis.ACTUAL_DATE between ref.REFERRAL_DATE and dbo.future(ref.CLOSURE_DATE)
			) cinv_cin_plan_id,
			vis.ACTUAL_DATE cinv_cin_visit_date,
			coalesce(
				case
					when vtyp.VISIT_SOURCE = 'Mos Step' then
						(
							select
								max(cfa.text_answer)
							from
								DM_CACHED_FORM_ANSWERS cfa
							inner join @child_seen_question_user_codes t
							on t.question_user_code = cfa.question_user_code
							where
								cfa.workflow_step_id = vis.VISIT_ID
								and
								case 
									when cfa.subject_person_id <= 0 then 
										vis.person_id
									else 
										cfa.subject_person_id
								end = vis.person_id
						) 
				end,
				vis.SEEN_ALONE_FLAG
			) cinv_cin_visit_seen,
			vis.SEEN_ALONE_FLAG cinv_cin_visit_seen_alone,
			case
				when vtyp.VISIT_SOURCE = 'Mos Step' then
					(
						select
							max(cfa.text_answer)
						from
							DM_CACHED_FORM_ANSWERS cfa
						inner join @bedroom_seen_question_user_codes t
						on t.question_user_code = cfa.question_user_code
						where
							cfa.workflow_step_id = vis.VISIT_ID
							and
							case 
								when cfa.subject_person_id <= 0 then 
									vis.person_id
								else 
									cfa.subject_person_id
							end = vis.person_id
					) 
			end cinv_cin_visit_bedroom
		from
			dm_visits vis
		inner join @cin_visit_types typ
		on typ.visit_type_code = vis.VISIT_TYPE
		inner join dm_visit_types vtyp
		on vtyp.VISIT_TYPE = vis.VISIT_TYPE
		where
			vis.ACTUAL_DATE between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_visits') is not null
	drop procedure ##populate_ssd_cla_visits
go
--
create procedure ##populate_ssd_cla_visits (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_visits

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_PERIODS_OF_CARE

- DM_CACHED_FORM_ANSWERS

- dm_visits

- dm_visit_types
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cla_visits') IS NOT NULL
			DROP TABLE ##ssd_cla_visits
		--
		create table ##ssd_cla_visits (
			clav_cla_id						varchar(48),
			clav_cla_visit_id				varchar(48),
			clav_cla_visit_date				datetime,
			clav_cla_visit_seen				varchar(1),
			clav_cla_visit_seen_alone		varchar(1),
			clav_person_id					varchar(48)
		)
		--
		declare @cla_visit_types table (
			visit_type_code			varchar(20),
			visit_type_description	varchar(88)
		)
		--
		insert into @cla_visit_types values
			('STP.1193', 'Step Looked after visit (CSSW)'),
			('VIS.CLA', 'Visit Child looked after')
		--
		declare @child_seen_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @child_seen_question_user_codes values
			('child_seen')
		--
		insert into ##ssd_cla_visits (
			clav_cla_id,
			clav_cla_visit_id,
			clav_cla_visit_date,
			clav_cla_visit_seen,
			clav_cla_visit_seen_alone,
			clav_person_id
		)
		select
			(
				select
					poc.PERIOD_OF_CARE_ID
				from
					DM_PERIODS_OF_CARE poc
				where
					poc.person_id = vis.person_id
					and
					vis.ACTUAL_DATE between poc.START_DATE and dbo.future(poc.END_DATE)
			) clav_cla_id,
			vis.VISIT_ID clav_cla_visit_id,
			vis.ACTUAL_DATE clav_cla_visit_date,
			coalesce(
				case
					when vtyp.VISIT_SOURCE = 'Mos Step' then
						(
							select
								max(cfa.text_answer)
							from
								DM_CACHED_FORM_ANSWERS cfa
							inner join @child_seen_question_user_codes t
							on t.question_user_code = cfa.question_user_code
							where
								cfa.workflow_step_id = vis.VISIT_ID
								and
								case 
									when cfa.subject_person_id <= 0 then 
										vis.person_id
									else 
										cfa.subject_person_id
								end = vis.person_id
						) 
				end,
				vis.SEEN_ALONE_FLAG
			) clav_cla_visit_seen,
			vis.SEEN_ALONE_FLAG clav_cla_visit_seen_alone,
			vis.PERSON_ID clav_person_id
		from
			dm_visits vis
		inner join @cla_visit_types typ
		on typ.visit_type_code = vis.VISIT_TYPE
		inner join dm_visit_types vtyp
		on vtyp.VISIT_TYPE = vis.VISIT_TYPE
		where
			vis.ACTUAL_DATE between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_care_plan') is not null
	drop procedure ##populate_ssd_cla_care_plan
go
--
create procedure ##populate_ssd_cla_care_plan (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_care_plan

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_CACHED_FORM_ANSWERS

- dm_workflow_steps

- DM_SUBGROUP_SUBJECTS
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cla_care_plan') IS NOT NULL
			DROP TABLE ##ssd_cla_care_plan
		--
		create table ##ssd_cla_care_plan (
			lacp_cla_care_plan_id				varchar(48),
			lacp_cla_care_plan_start_date		datetime,
			lacp_cla_care_plan_end_date			datetime,
			lacp_cla_care_plan_json				varchar(100),			-- [REVIEW] changed from lacp_ cla_ care_ plan 	(spaced here to avoiding name being picked up by other processes)
			lacp_person_id						varchar(48)
		)
		--
		declare @cla_plan_step_types table (
			workflow_step_type_id			numeric(9),
			description						varchar(62)
		)
		--
		insert into @cla_plan_step_types values
			(1242, 'First CLA review (CSSW)'),
			(1237, 'Second CLA review (CSSW)'),
			(1234, 'Subsequent CLA review (CSSW)'),
			(496, 'Initial Pathway Plan Review'),
			(500, 'Pathway Plan Review'),
			(1262, 'First LAC Review'),
			(1263, 'Second LAC Review'),
			(1264, 'Subsequent LAC Review'),
			(1295, 'Initial Under 18 pathway plan (CSSW)'),
			(1297, 'Review under 18 pathway plan (CSSW)')
		--
		declare @permanence_plan_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @permanence_plan_question_user_codes values
			('lac.perm.plan'),
			('pwpc.permanenceplan')
		--
		declare @permanence_plan_categories table (
			question_answer			varchar(500),
			permanence_plan_type	varchar(500)
		)
		--
		insert into @permanence_plan_categories values
			('Return to birth family', 'A) Return to Family'),
			('Adoption', 'B) Adoption'),
			('Long term placement friends / family','C) SGO/CAO'),
			('Independent living/supported living in the community (Pathways or other)', 'D) Supported Living in the Community'),
			('Residential', 'E) Long-Term Residential Placement'),
			('Long term fostering', 'F) Long-Term Fostering'),
			('Other (please specify)', 'G) Other')
		--
		insert into ##ssd_cla_care_plan (
			lacp_cla_care_plan_id,
			lacp_cla_care_plan_start_date,
			lacp_cla_care_plan_end_date,
			lacp_cla_care_plan_json,
			lacp_person_id
		)
		select
			stp.WORKFLOW_STEP_ID lacp_cla_care_plan_id,
			stp.STARTED_ON lacp_cla_care_plan_start_date,
			stp.COMPLETED_ON lacp_cla_care_plan_end_date,
			(
				select
					max(cat.permanence_plan_type)
				from
					DM_CACHED_FORM_ANSWERS cfa
				inner join @permanence_plan_question_user_codes t
				on t.question_user_code = cfa.question_user_code
				inner join @permanence_plan_categories cat
				on cat.question_answer = cfa.text_answer
				where
					cfa.workflow_step_id = stp.WORKFLOW_STEP_ID
					and
					case 
						when cfa.subject_person_id <= 0 then 
							sgs.SUBJECT_COMPOUND_ID
						else 
							cfa.subject_person_id
					end = sgs.SUBJECT_COMPOUND_ID
			) lacp_cla_care_plan_json,
			sgs.SUBJECT_COMPOUND_ID lacp_person_id
		from
			dm_workflow_steps stp
		inner join @cla_plan_step_types t
		on t.workflow_step_type_id = stp.workflow_step_type_id
		inner join DM_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			stp.COMPLETED_ON >= @start_date
			and
			stp.STARTED_ON <= @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_immigration_status') is not null
	drop procedure ##populate_ssd_immigration_status
go
--
create procedure ##populate_ssd_immigration_status as
begin
/*

=============================================================================

Object Name: ssd_immigration_status

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_cached_form_answers

- dm_cached_form_questions

- dm_subgroup_subjects

- mo_forms

- mo_subgroup_subjects
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_immigration_status') IS NOT NULL
			DROP TABLE ##ssd_immigration_status
		--
		create table ##ssd_immigration_status (
			immi_person_id							varchar(48),
			immi_immigration_status_id				varchar(48),
			immi_immigration_status					varchar(48),
			immi_immigration_status_start_date		datetime,
			immi_immigration_status_end_date		datetime
		)
		--
		declare @immigration_status_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @immigration_status_start_date_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @immigration_status_end_date_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		--Insert the question user codes and question text of questions which are used to record a child's immigration status
		insert into @immigration_status_question_user_codes
		values
			('acFLDAllAboutMeLeavingImmigrationStatusList', 'Immigration Status')
			,('csn_ina_addsuppfact_immig_status', 'What is your immigration status?')
			,('csn_ina_addsuppfact_immig_status', 'What is the client''s immigration status?')
			,('csn_couns_immigration', 'Immigration status')
			,('uascImmigStat', 'Immigration Status')
			,('csn_ina_addsuppfact_immig_status', 'What is the client''s immigration status?')
			,('62CD0406-2F07-0FF5-512C-A7FA0DBAD602', 'Citizenship/Immigration status')
			,('acFLDAllAboutMeLeavingImmigrationStatusList', 'Immigration Status')
		--
		insert into @immigration_status_start_date_question_user_codes
		values
			('<question_user_code>', '<latest_question_text>')
		--
		insert into @immigration_status_end_date_question_user_codes
		values
			('<question_user_code>', '<latest_question_text value>')
		--
		if object_id('tempdb..#text_answers') is not null
			drop table #text_answers
		--
		select
			cfa.form_id,
			cfa.form_answer_row_id,
			cfa.question_user_code,
			cfa.text_answer,
			case 
				when cfa.subject_person_id > 0 then 
					cfa.subject_person_id
				else
					sgs.subject_compound_id
			end person_id
		into
			#text_answers
		from 
			dm_cached_form_answers cfa
		inner join dm_cached_form_questions q
		on q.mapping_id = cfa.mapping_id
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = cfa.subgroup_id
			and
			sgs.subject_type_code = 'PER'
		where
			q.question_user_code in (
				select
					question_user_code
				from
					@immigration_status_question_user_codes
				)
		--
		if object_id('tempdb..#date_answers') is not null
			drop table #date_answers
		--
		select
			cfa.form_id,
			cfa.form_answer_row_id,
			cfa.question_user_code,
			cfa.date_answer,
			case 
				when cfa.subject_person_id > 0 then 
					cfa.subject_person_id
				else
					sgs.subject_compound_id
			end person_id
		into
			#date_answers
		from 
			dm_cached_form_answers cfa
		inner join dm_cached_form_questions q
		on q.mapping_id = cfa.mapping_id
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = cfa.subgroup_id
			and
			sgs.subject_type_code = 'PER'
		where
			q.question_user_code in (
				select
					question_user_code
				from
					@immigration_status_start_date_question_user_codes
				union 
				select
					question_user_code
				from
					@immigration_status_end_date_question_user_codes
				)
		--
		insert into ##ssd_immigration_status (
			immi_person_id,
			immi_immigration_status_id,
			immi_immigration_status,
			immi_immigration_status_start_date,
			immi_immigration_status_end_date
		)
		select 
			sub.immi_person_id,
			sub.immi_immigration_status_id,
			sub.immi_immigration_status,
			dbo.no_time(sub.immi_immigration_status_start_date) immi_immigration_status_start_date,
			dbo.no_time(sub.immi_immigration_status_end_date) immi_immigration_status_end_date
		from 
			(
				select 
					sgs.subject_compound_id immi_person_id,
					dbo.append2(f.form_id, '.', sgs.subject_compound_id) immi_immigration_status_id,
					lkp.text_answer immi_immigration_status,
					d1.date_answer immi_immigration_status_start_date,
					d2.date_answer immi_immigration_status_end_date,
					row_number() over (partition by sgs.subject_compound_id order by f.created_on desc, f.form_id desc) seq 
				from
					mo_forms f
				inner join mo_subgroup_subjects sgs
				on sgs.subgroup_id = f.subgroup_id
				and
				sgs.subject_type_code = 'PER'
				inner join #text_answers lkp
				on lkp.form_id = f.form_id
				and
				lkp.person_id = sgs.subject_compound_id
				inner join @immigration_status_question_user_codes lkp_q
				on lkp_q.question_user_code = lkp.question_user_code 
				left outer join #date_answers d1
				on d1.form_id = f.form_id
				and
				d1.person_id = sgs.subject_compound_id
				and
				d1.form_answer_row_id = lkp.form_answer_row_id
				and
				d1.question_user_code in (
					select
						question_user_code
					from
						@immigration_status_start_date_question_user_codes
				)
				left outer join #date_answers d2
				on d2.form_id = f.form_id
				and
				d2.person_id = sgs.subject_compound_id
				and
				d2.form_answer_row_id = lkp.form_answer_row_id
				and
				d2.question_user_code in (
					select
						question_user_code
					from
						@immigration_status_start_date_question_user_codes
				)
			) sub
		where 
			sub.seq = 1
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cp_visits') is not null
	drop procedure ##populate_ssd_cp_visits
go
--
create procedure ##populate_ssd_cp_visits (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cp_visits

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_registrations

- DM_CACHED_FORM_ANSWERS

- dm_visits

- dm_visit_types
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cp_visits') IS NOT NULL
			DROP TABLE ##ssd_cp_visits
		--
		create table ##ssd_cp_visits (
			cppv_cp_visit_id				varchar(48),
			cppv_cp_plan_id					varchar(48),
			cppv_cp_visit_id				varchar(48),
			cppv_cp_visit_date				datetime,
			cppv_cp_visit_seen				varchar(1),
			cppv_cp_visit_seen_alone		varchar(1),
			cppv_cp_visit_bedroom			varchar(1)
		)
		--
		declare @cpp_visit_types table (
			visit_type_code			varchar(20),
			visit_type_description	varchar(88)
		)
		--
		insert into @cpp_visit_types values
			('VIS.CP', 'Visit Child protection'),
			('STP.1187', 'Step Child protection visit (CSSW)')
		--
		declare @bedroom_seen_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @bedroom_seen_question_user_codes values
			('seen bedroom')
		--
		declare @child_seen_question_user_codes table (
			question_user_code	varchar(128)
		)
		--
		insert into @child_seen_question_user_codes values
			('child_seen')
		--
		insert into ##ssd_cp_visits (
			cppv_cp_visit_id,
			cppv_cp_plan_id,
			cppv_cp_visit_id,
			cppv_cp_visit_date,
			cppv_cp_visit_seen,
			cppv_cp_visit_seen_alone,
			cppv_cp_visit_bedroom
		)
		select
			null cppv_cp_visit_id,
			(
				select
					max(cpp.registration_id)
				from
					dm_registrations cpp
				where
					cpp.PERSON_ID = vis.PERSON_ID
					and
					cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(cpp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					vis.ACTUAL_DATE between cpp.REGISTRATION_START_DATE and dbo.future(cpp.DEREGISTRATION_DATE)
			) cppv_cp_plan_id,
			vis.VISIT_ID cppv_cp_visit_id,
			vis.ACTUAL_DATE cppv_cp_visit_date,
			coalesce(
				case
					when vtyp.VISIT_SOURCE = 'Mos Step' then
						(
							select
								max(cfa.text_answer)
							from
								DM_CACHED_FORM_ANSWERS cfa
							inner join @child_seen_question_user_codes t
							on t.question_user_code = cfa.question_user_code
							where
								cfa.workflow_step_id = vis.VISIT_ID
								and
								case 
									when cfa.subject_person_id <= 0 then 
										vis.person_id
									else 
										cfa.subject_person_id
								end = vis.person_id
						) 
				end,
				vis.SEEN_ALONE_FLAG
			) cppv_cp_visit_seen,
			vis.SEEN_ALONE_FLAG cppv_cp_visit_seen_alone,
			case
				when vtyp.VISIT_SOURCE = 'Mos Step' then
					(
						select
							max(cfa.text_answer)
						from
							DM_CACHED_FORM_ANSWERS cfa
						inner join @bedroom_seen_question_user_codes t
						on t.question_user_code = cfa.question_user_code
						where
							cfa.workflow_step_id = vis.VISIT_ID
							and
							case 
								when cfa.subject_person_id <= 0 then 
									vis.person_id
								else 
									cfa.subject_person_id
							end = vis.person_id
					) 
			end cppv_cp_visit_bedroom
		from
			dm_visits vis
		inner join @cpp_visit_types typ
		on typ.visit_type_code = vis.VISIT_TYPE
		inner join dm_visit_types vtyp
		on vtyp.VISIT_TYPE = vis.VISIT_TYPE
		where
			vis.ACTUAL_DATE between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_substance_misuse') is not null
	drop procedure ##populate_ssd_cla_substance_misuse
go
--
create procedure ##populate_ssd_cla_substance_misuse as
begin
/*

=============================================================================

Object Name: ssd_cla_substance_misuse

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

dm_cached_form_answers

dm_cached_form_questions

dm_subgroup_subjects
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cla_substance_misuse') IS NOT NULL
			DROP TABLE ##ssd_cla_substance_misuse
		--
		create table ##ssd_cla_substance_misuse (
			clas_substance_misuse_id			varchar(48),
			clas_person_id						varchar(48),
			clas_substance_misuse_date			datetime,
			clas_substance_misused				varchar(100),
			clas_intervention_received			varchar(1)
		)
		--
		declare @substance_misuse_type_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @substance_misuse_date_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @substance_misuse_intervention_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @substance_misuse_intervention_answers table (
			answer					varchar(1000)
		)
		--Insert the question user codes and question text of questions which are used to record the type of substance that is being abused
		insert into @substance_misuse_type_question_user_codes
		values
			('question_user_code', 'latest_question_text')
		--
		--Insert the question user codes and question text of questions which are used to record the date that the substance misuse is recorded
		insert into @substance_misuse_date_question_user_codes
		values
			('question_user_code', 'latest_question_text')
		--
		--Insert the question user codes and question text of questions which are used to record that child received an intervention for substance misuse problem
		insert into @substance_misuse_intervention_question_user_codes
		values
			('question_user_code', 'latest_question_text')
		--
		--Insert the exact wording of answers which indicate that an intervention was received
		insert into @substance_misuse_intervention_answers
		values
			('Yes')
		--
		if object_id('tempdb..#text_answers') is not null
			drop table #text_answers
		--
		select
			cfa.form_id,
			cfa.form_answer_row_id,
			cfa.question_user_code,
			cfa.text_answer,
			case 
				when cfa.subject_person_id > 0 then 
					cfa.subject_person_id
				else
					sgs.subject_compound_id
			end person_id
		into
			#text_answers
		from 
			dm_cached_form_answers cfa
		inner join dm_cached_form_questions q
		on q.mapping_id = cfa.mapping_id
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = cfa.subgroup_id
			and
			sgs.subject_type_code = 'PER'
		where
			q.question_user_code in (
				select
					question_user_code
				from
					@substance_misuse_type_question_user_codes
				union 
				select
					question_user_code
				from
					@substance_misuse_intervention_question_user_codes
				)
		--
		if object_id('tempdb..#date_answers') is not null
			drop table #date_answers
		--
		select
			cfa.form_id,
			cfa.form_answer_row_id,
			cfa.question_user_code,
			cfa.date_answer,
			case 
				when cfa.subject_person_id > 0 then 
					cfa.subject_person_id
				else
					sgs.subject_compound_id
			end person_id
		into
			#date_answers
		from 
			dm_cached_form_answers cfa
		inner join dm_cached_form_questions q
		on q.mapping_id = cfa.mapping_id
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = cfa.subgroup_id
			and
			sgs.subject_type_code = 'PER'
		where
			q.question_user_code in (
				select
					question_user_code
				from
					@substance_misuse_date_question_user_codes
				)
		--
		insert into ##ssd_cla_substance_misuse (
			clas_substance_misuse_id,
			clas_person_id,
			clas_substance_misuse_date,
			clas_substance_misused,
			clas_intervention_received
		)
		select 
			sta.form_answer_row_id clas_substance_misuse_id,
			sta.person_id clas_person_id,
			(
				select	d.date_answer 
				from 
					#date_answers d 
				where 
					d.form_id = sta.form_id 
					and 
					d.form_answer_row_id = sta.form_answer_row_id
			) clas_substance_misuse_date,
			sta.text_answer clas_substance_misused,
			(
				select 
					la.text_answer
				from 
					#text_answers la 
				inner join @substance_misuse_intervention_question_user_codes quc
				on quc.question_user_code = la.question_user_code
				where 
					la.form_id = sta.form_id 
					and 
					la.form_answer_row_id = sta.form_answer_row_id
			) clas_intervention_received
		from 
			#text_answers sta
		inner join @substance_misuse_type_question_user_codes smt
		on smt.question_user_code = sta.question_user_code
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_immunisations') is not null
	drop procedure ##populate_ssd_cla_immunisations
go
--
create procedure ##populate_ssd_cla_immunisations as
begin
/*

=============================================================================

Object Name: ssd_cla_immunisations

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_cached_form_answers

- dm_cached_form_questions

- dm_workflow_steps

- dm_subgroup_subjects

- mo_workflow_steps

- mo_subgroup_subjects
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cla_immunisations') IS NOT NULL
			DROP TABLE ##ssd_cla_immunisations
		--
		create table ##ssd_cla_immunisations (
			--clai_table_id					varchar(48), -- [REVIEW] re-purposed from -- clai_immunisations_id
			clai_person_id					varchar(48),
			clai_immunisations_status		varchar(1)
			-- clai_immunisations_status_date datetime -- [REVIEW] is currently missing added here for ref
		)
		--
		declare @immunisation_workflow_step_types table (
			workflow_step_type_id	numeric(9),
			description				varchar(1000)
		)
		--
		declare @immunisations_up_to_date_question_user_codes table (
			question_user_code		varchar(128),
			question_text			varchar(1000)
		)
		--
		declare @immunisations_up_to_date_answers table (
			answer					varchar(1000)
		)
		--
		--Insert workflow step types which are used to capture that immunisations are up to date
		insert into @immunisation_workflow_step_types 
		values
			(406, 'LAC Health Assessment')
			,(1239, 'Health assessment (CSSW)')
		--
		--Insert the question user codes and question text of questions which are used to record that immunisations are up to date
		insert into @immunisations_up_to_date_question_user_codes
		values
			('lac.ihr09.immsuptodate', 'Immunisations up to date?')
			,('lac.ihr10.immsuptodate', 'Immunisations up to date?')
			,('lacFLDPartCHealthRecommImmunisations', 'Immunisations up to date?')
		--
		--Insert the exact wording of answers which indicate that immunisations are up to date
		insert into @immunisations_up_to_date_answers
		values
			('Yes')
		--
		if object_id('tempdb..#text_answers') is not null
			drop table #text_answers
		--
		select
			cfa.workflow_step_id,
			cfa.form_answer_row_id,
			cfa.question_user_code,
			cfa.text_answer,
			case 
				when cfa.subject_person_id > 0 then 
					cfa.subject_person_id
				else
					sgs.subject_compound_id
			end person_id
		into
			#text_answers
		from 
			dm_cached_form_answers cfa
		inner join dm_cached_form_questions q
		on q.mapping_id = cfa.mapping_id
		inner join dm_workflow_steps stp 
		on stp.workflow_step_id = cfa.workflow_step_id
		inner join @immunisation_workflow_step_types atyp
		on atyp.workflow_step_type_id = stp.workflow_step_type_id
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = stp.subgroup_id
			and
			sgs.subject_type_code = 'PER'
		where
			q.question_user_code in (
				select
					question_user_code
				from
					@immunisations_up_to_date_question_user_codes
				)
		--
		insert into ##ssd_cla_immunisations (
			--clai_table_id, -- [REVIEW] depreciated 310524 re-purposed from -- clai_immunisations_id
			clai_person_id,
			clai_immunisations_status
		)
		select 
    		--sub.clai_table_id, -- [REVIEW] depreciated 310524 re-purposed from -- clai_immunisations_id
			sub.clai_person_id,
			sub.clai_immunisations_status
		from 
			(
			select 
				sgs.subject_compound_id clai_person_id,
				--dbo.append2(stp.workflow_step_id, '.', sgs.subject_compound_id) clai_table_id, -- [REVIEW] depreciated 310524 

				case
					when exists (
						select
							1
						from
							@immunisations_up_to_date_answers a
						where 
							a.answer = lkp.text_answer
						)
					then
						'Y'
					else
						'N'
				end clai_immunisations_status,
				row_number() over (partition by sgs.subject_compound_id order by stp.started_on desc, stp.workflow_step_id desc) seq 
			from
				mo_workflow_steps stp
			inner join mo_subgroup_subjects sgs
			on sgs.subgroup_id = stp.subgroup_id
				and
				sgs.subject_type_code = 'PER'
			inner join @immunisation_workflow_step_types typ
			on typ.workflow_step_type_id = stp.workflow_step_type_id

			inner join #text_answers lkp
			on lkp.workflow_step_id = stp.workflow_step_id
				and
				lkp.person_id = sgs.subject_compound_id

			inner join @immunisations_up_to_date_question_user_codes quc
			on quc.question_user_code = lkp.question_user_code

			where
				stp.step_status in ('STARTED', 'REOPENED', 'COMPLETED')
			) sub
		where 
			sub.seq = 1
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_convictions') is not null
	drop procedure ##populate_ssd_cla_convictions
go
--
create procedure ##populate_ssd_cla_convictions (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_convictions

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_offences
=============================================================================

*/
	begin try
		--
		IF OBJECT_ID('tempdb..##ssd_cla_convictions') IS NOT NULL
			DROP TABLE ##ssd_cla_convictions
		--
		create table ##ssd_cla_convictions (
			clac_cla_conviction_id			varchar(48),
			clac_person_id					varchar(48),
			clac_cla_conviction_date		datetime
		)
		--
		insert into ##ssd_cla_convictions (
			clac_cla_conviction_id,
			clac_person_id,
			clac_cla_conviction_date
		)
		select
			o.offence_id clac_cla_conviction_id,
			o.person_id clac_person_id,
			dbo.no_time(o.offence_date) clac_cla_conviction_date
		from 
			dm_offences o
		where 
			o.is_convicted = 'Y'
			and
			dbo.no_time(o.offence_date) between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_address') is not null
	drop procedure ##populate_ssd_address
go
--
create procedure ##populate_ssd_address as
begin
/*

=============================================================================

Object Name: ssd_address

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_ADDRESSES
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_address') IS NOT NULL
			DROP TABLE ##ssd_address
		--
		create table ##ssd_address (
			addr_table_id				varchar(48),		
			addr_address_json			varchar(1000),
			addr_person_id				varchar(48),
			addr_address_type			varchar(48),
			addr_address_start_date		datetime,
			addr_address_end_date		datetime,
			addr_address_postcode				varchar(15)
		)
		--
		insert into ##ssd_address (
			addr_table_id,
			addr_address_json,
			addr_person_id,
			addr_address_type,
			addr_address_start_date,
			addr_address_end_date,
			addr_address_postcode
		)
		select
			addr.REF_ADDRESSES_PEOPLE_ID addr_table_id,
			addr.ADDRESS addr_address_json,
			addr.PERSON_ID addr_person_id,
			addr.ADDRESS_TYPE addr_address_type,
			addr.START_DATE addr_address_start_date,
			addr.END_DATE addr_address_end_date,
			addr.POST_CODE addr_address_postcode
		from
			dm_ADDRESSES addr
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_sdq_scores') is not null
	drop procedure ##populate_ssd_sdq_scores
go
--
create procedure ##populate_ssd_sdq_scores (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_sdq_scores

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_HEALTH_ASSESSMENTS
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_sdq_scores') IS NOT NULL
			DROP TABLE ##ssd_sdq_scores
		--
		create table ##ssd_sdq_scores (
			csdq_table_id				varchar(48), -- [REVIEW] was csdq_sdq_id
			csdq_person_id				varchar(48),
			csdq_sdq_completed_date		datetime,
			csdq_sdq_reason				varchar(100),
			csdq_sdq_score				varchar(100)
		)
		--
		insert into ##ssd_sdq_scores (
			csdq_table_id,
			csdq_person_id,
			csdq_sdq_completed_date,
			csdq_sdq_reason,
			csdq_sdq_score
		)
		select
			hlth.HEALTH_ID csdq_table_id,
			hlth.PERSON_ID csdq_person_id,
			hlth.HEALTH_ASSESSMENT_DATE csdq_sdq_completed_date,
			hlth.SDQ_REASON csdq_sdq_reason,
			hlth.SDQ_SCORE
		from
			dm_HEALTH_ASSESSMENTS hlth
		where
			(
				hlth.SDQ_COMPLETED = 'Y'
				or
				hlth.sdq_reason is not null
			)
			and
			hlth.HEALTH_ASSESSMENT_DATE between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_professionals') is not null
	drop procedure ##populate_ssd_professionals
go
--
create procedure ##populate_ssd_professionals as
begin
/*

=============================================================================

Object Name: ssd_professionals

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_ALLOCATED_WORKERS

- dm_WORKER_ROLES

- dm_organisations

- dm_workers
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_professionals') IS NOT NULL
			DROP TABLE ##ssd_professionals
		--
		create table ##ssd_professionals (
			prof_professional_id					varchar(48),
			prof_staff_id							varchar(48),
			prof_social_worker_registration_no		varchar(48),
			prof_agency_worker_flag					varchar(100),
			prof_professional_job_title				varchar(500),
			prof_professional_caseload				int,
			prof_professional_department			varchar(100),
			prof_full_time_equivalency				decimal(6,2)
		)
		--
		insert into ##ssd_professionals (
			prof_professional_id,
			prof_staff_id,
			prof_social_worker_registration_no,
			prof_agency_worker_flag,
			prof_professional_job_title,
			prof_professional_caseload,
			prof_professional_department,
			prof_full_time_equivalency
		)
		select
			null prof_professional_id,
			wkr.WORKER_ID prof_staff_id,
			null prof_social_worker_registration_no,
			null prof_agency_worker_flag,
			null prof_professional_job_title,
			(
				select
					count(distinct alc.person_id)
				from
					dm_ALLOCATED_WORKERS alc
				where
					alc.worker_id = wkr.WORKER_ID
					and
					convert(datetime, convert(varchar, getdate(), 103), 103) between alc.START_DATE and coalesce(alc.end_date,'1 January 2300')
			) prof_professional_caseload,
			(
				select
					max(org.name)
				from
					dm_WORKER_ROLES wro
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
					dm_ALLOCATED_WORKERS alc
				where
					alc.worker_id = wkr.WORKER_ID
					and
					convert(datetime, convert(varchar, getdate(), 103), 103) between alc.START_DATE and coalesce(alc.end_date,'1 January 2300')
			)
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_previous_permanence') is not null
	drop procedure ##populate_ssd_cla_previous_permanence
go
--
create procedure ##populate_ssd_cla_previous_permanence as
begin
/*

=============================================================================

Object Name: ssd_cla_previous_permanence

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_FILTER_FORM_ANSWERS

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS

- dm_MAPPING_GROUPS
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cla_previous_permanence') IS NOT NULL
			DROP TABLE ##ssd_cla_previous_permanence
		--
		create table ##ssd_cla_previous_permanence (
			lapp_table_id							varchar(48), -- [REVIEW] -- re-purposed from lapp_ previous_ permanence_ id
			lapp_person_id							varchar(48),
			lapp_previous_permanence_order_date		varchar(10),
			lapp_previous_permanence_option			varchar(100),
			lapp_previous_permanence_la				varchar(100)
		)
		--
		insert into ##ssd_cla_previous_permanence (
			lapp_table_id,
			lapp_person_id,
			lapp_previous_permanence_order_date,
			lapp_previous_permanence_option,
			lapp_previous_permanence_la
		)
		select
			dbo.to_weighted_start(ffa.date_answer,ffa.form_id) lapp_table_id,
			sgs.SUBJECT_COMPOUND_ID lapp_person_id,
			dbo.unmake_date(ffa.date_answer) lapp_previous_permanence_order_date,
			(
				select
					max(opt.text_answer)
				from
					dm_FILTER_FORM_ANSWERS opt
				inner join dm_workflow_steps ostp
				on ostp.WORKFLOW_STEP_ID = opt.workflow_step_id
				inner join dm_SUBGROUP_SUBJECTS osgs
				on osgs.SUBGROUP_ID = ostp.SUBGROUP_ID
				and
				osgs.SUBJECT_TYPE_CODE = 'PER'
				inner join dm_MAPPING_GROUPS grp
				on grp.mapped_value = cast(checksum(opt.text_answer) as varchar(11))
				and
				grp.group_name = 'Child Previous Permanence Option'
				where
					opt.filter_name = 'Child Previous Permanence Option (Document)'
					and
					opt.workflow_step_id = ffa.workflow_step_id
					and
					case 
						when opt.subject_person_id <= 0 then 
							sgs.SUBJECT_COMPOUND_ID
						else 
							opt.subject_person_id
					end = sgs.SUBJECT_COMPOUND_ID
			) lapp_previous_permanence_option,
			(
				select
					max(opt.text_answer)
				from
					dm_FILTER_FORM_ANSWERS opt
				inner join dm_workflow_steps ostp
				on ostp.WORKFLOW_STEP_ID = opt.workflow_step_id
				inner join dm_SUBGROUP_SUBJECTS osgs
				on osgs.SUBGROUP_ID = ostp.SUBGROUP_ID
				and
				osgs.SUBJECT_TYPE_CODE = 'PER'
				inner join dm_MAPPING_GROUPS grp
				on grp.mapped_value = cast(checksum(opt.text_answer) as varchar(11))
				and
				grp.group_name = 'Child Previous Permanence LA'
				where
					opt.filter_name = 'Child Previous Permanence LA (Document)'
					and
					opt.workflow_step_id = ffa.workflow_step_id
					and
					case 
						when opt.subject_person_id <= 0 then 
							sgs.SUBJECT_COMPOUND_ID
						else 
							opt.subject_person_id
					end = sgs.SUBJECT_COMPOUND_ID
			) lapp_previous_permanence_la
		from
			dm_filter_form_answers ffa
		inner join dm_workflow_steps stp
		on stp.WORKFLOW_STEP_ID = ffa.workflow_step_id
		inner join dm_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			ffa.filter_name = 'Child Previous Permanence Option Date (Document)'
			and
			dbo.to_weighted_start(ffa.date_answer,ffa.form_id) = (
				select
					max(dbo.to_weighted_start(ffa1.date_answer,ffa1.form_id))
				from
					dm_filter_form_answers ffa1
				inner join dm_workflow_steps stp1
				on stp1.WORKFLOW_STEP_ID = ffa1.workflow_step_id
				inner join dm_SUBGROUP_SUBJECTS sgs1
				on sgs1.SUBGROUP_ID = stp1.SUBGROUP_ID
				and
				sgs1.SUBJECT_TYPE_CODE = 'PER'
				where
					ffa1.filter_name = 'Child Previous Permanence Option Date (Document)'
					and
					sgs1.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
			)
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_placement') is not null
	drop procedure ##populate_ssd_cla_placement
go
--
create procedure ##populate_ssd_cla_placement (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_placement

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_CLA_SUMMARIES

- dm_PLACEMENT_DETAILS

- dm_PLACEMENTS
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cla_placement') IS NOT NULL
			DROP TABLE ##ssd_cla_placement
		--
		create table ##ssd_cla_placement (
			clap_cla_placement_id				varchar(48),
			clap_cla_placement_start_date		datetime,
			clap_cla_placement_type				varchar(100),
			clap_cla_placement_urn				varchar(48),
			clap_cla_placement_distance			decimal(7,2),
			clap_cla_id							varchar(48),
			clap_cla_placement_provider			varchar(48),
			clap_cla_placement_postcode			varchar(8),
			clap_cla_placement_end_date			datetime,
			clap_cla_placement_change_reason	varchar(100)
		)
		--
		insert into ##ssd_cla_placement (
			clap_cla_placement_id,
			clap_cla_placement_start_date,
			clap_cla_placement_type,
			clap_cla_placement_urn,
			clap_cla_placement_distance,
			clap_cla_id,
			clap_cla_placement_provider,
			clap_cla_placement_postcode,
			clap_cla_placement_end_date,
			clap_cla_placement_change_reason
		)
		select
			pla.PLACEMENT_ID clap_cla_placement_id,
			pla.START_DATE clap_cla_placement_start_date,
			pla.PLACEMENT_TYPE clap_cla_placement_type,
			(
				select
					max(pld.OFSTED_URN)
				from
					dm_CLA_SUMMARIES cla
				inner join dm_PLACEMENT_DETAILS pld
				on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
				and
				pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
				where
					cla.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					and
					dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
						select
							max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
						from
							dm_CLA_SUMMARIES cla1
						inner join dm_PLACEMENT_DETAILS pld1
						on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
						and
						pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
						where
							cla1.PLACEMENT_ID = pla.PLACEMENT_ID
							and
							cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					)
			) clap_cla_placement_urn,
			null clap_cla_placement_distance,
			pla.PERIOD_OF_CARE_ID clap_cla_id,
			(
				select
					max(pld.CIN_PROVIDER_CATEGORY_CODE)
				from
					dm_CLA_SUMMARIES cla
				inner join dm_PLACEMENT_DETAILS pld
				on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
				and
				pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
				where
					cla.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					and
					dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
						select
							max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
						from
							dm_CLA_SUMMARIES cla1
						inner join dm_PLACEMENT_DETAILS pld1
						on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
						and
						pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
						where
							cla1.PLACEMENT_ID = pla.PLACEMENT_ID
							and
							cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					)
			) clap_cla_placement_provider,
			(
				select
					max(ca.POST_CODE)
				from
					dm_CLA_SUMMARIES cla
				inner join dm_PLACEMENT_DETAILS pld
				on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
				and
				pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
				inner join dm_PLACEMENT_CARER_ADDRESSES ca
				on ca.CARER_ID = pld.CARER_ID
				and
				coalesce(pla.end_date,dbo.today()) between ca.START_DATE and dbo.future(ca.END_DATE)
				where
					cla.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					and
					dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
						select
							max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
						from
							dm_CLA_SUMMARIES cla1
						inner join dm_PLACEMENT_DETAILS pld1
						on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
						and
						pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
						where
							cla1.PLACEMENT_ID = pla.PLACEMENT_ID
							and
							cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					)
			) clap_cla_placement_postcode,
			pla.END_DATE clap_cla_placement_end_date,
			pla.REASON_FOR_PLACEMENT_CHANGE clap_cla_placement_change_reason
		from
			dm_PLACEMENTS pla
		where
			pla.SPLIT_NUMBER = (
				select
					max(pla1.split_number)
				from
					dm_placements pla1
				where
					pla1.PLACEMENT_ID = pla.PLACEMENT_ID
			)
			and
			pla.start_date <= @end_date
			and
			dbo.future(pla.end_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_person') is not null
	drop procedure ##populate_ssd_person
go
--
create procedure ##populate_ssd_person as
begin
/*

=============================================================================

Object Name: ssd_person

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- reference_data

- mo_person_gender_identities

- dm_ETHNICITIES

- dm_PERSONAL_RELATIONSHIPS

- dm_COUNTRIES_OF_BIRTH

- dm_persons
=============================================================================

*/
	begin try
		--set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_person') IS NOT NULL
			DROP TABLE ##ssd_person
		--
		create table ##ssd_person (
			pers_person_id					varchar(48),
			pers_sex						varchar(48),
			pers_gender						varchar(48),
			pers_ethnicity					varchar(48),
			pers_dob						datetime,
			pers_common_child_id			varchar(48),
			-- pers_upn						varchar(48), -- [depreciated] [REVIEW]
			pers_upn_unknown				varchar(20),
			pers_send_flag					varchar(1),
			pers_expected_dob				datetime,
			pers_death_date					datetime,
			pers_is_mother					varchar(1),
			pers_nationality				varchar(48)
		)
		--
		insert into ##ssd_person (
			pers_person_id,
			pers_sex,
			pers_gender,
			pers_ethnicity,
			pers_dob,
			pers_common_child_id,
			-- pers_upn,
			pers_upn_unknown,
			pers_send_flag,
			pers_expected_dob,
			pers_death_date,
			pers_is_mother,
			pers_nationality
		)
		select
			per.PERSON_ID pers_person_id,
			(
				select
					rd.ref_description
				from
					reference_data rd
				where
					rd.ref_domain = 'GENDER'
					and
					rd.ref_code = per.gender
			) pers_sex,
			(
				select
					rd.ref_description
				from
					mo_person_gender_identities gen
				inner join reference_data rd
				on rd.ref_code = gen.gender_code
				and
				rd.ref_domain = 'GENDER_IDENTITY'
				where
					gen.person_id = per.person_id
					and
					dbo.today() between gen.start_date and dbo.future(gen.end_date)
			) pers_gender,
			(
				select
					eth.ETHNICITY_DESCRIPTION
				from
					dm_ETHNICITIES eth
				where
					eth.ETHNICITY_CODE = per.FULL_ETHNICITY_CODE
			) pers_ethnicity,
			case
				when per.DATE_OF_BIRTH <= dbo.today() then
					per.DATE_OF_BIRTH
			end pers_dob,
			per.nhs_id pers_common_child_id,
			-- per.UPN_ID pers_upn, -- [depreciated] [REVIEW]
			null pers_upn_unknown,
			null pers_send_flag,
			case
				when per.DATE_OF_BIRTH > dbo.today() then
					per.DATE_OF_BIRTH
			end pers_expected_dob,
			per.DATE_OF_DEATH pers_death_date,
			case
				when per.GENDER = 'F' then
					(
						select
							max('Y')
						from
							dm_PERSONAL_RELATIONSHIPS rel
						where
							rel.PERSON_ID = per.PERSON_ID
							and
							rel.is_mother = 'Y'
							and
							dbo.today() between rel.START_DATE and dbo.future(rel.END_DATE)
					)
			end pers_is_mother,
			(
				select
					birt.DESCRIPTION
				from
					dm_COUNTRIES_OF_BIRTH birt
				where
					per.COUNTRY_OF_BIRTH_CODE = birt.COUNTRY_OF_BIRTH_CODE
			) pers_nationality
		from
			dm_persons per
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_permanence') is not null
	drop procedure ##populate_ssd_permanence
go
--
create procedure ##populate_ssd_permanence as
begin
/*

=============================================================================

Object Name: ssd_permanence

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_LEGAL_STATUSES

- dm_placements

- dm_placement_types

- dm_CLA_SUMMARIES

- dm_PLACEMENT_DETAILS

- dm_workflow_steps_people_vw

- dm_CACHED_FORM_ANSWERS

- dm_PERIODS_OF_CARE

- dm_PERSONAL_RELATIONSHIPS

- dm_NON_LA_LEGAL_STATUSES

- dm_NON_LA_LEGAL_STATUS_TYPES
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_permanence') IS NOT NULL
			DROP TABLE ##ssd_permanence
		--
		create table ##ssd_permanence (
			perm_table_id						varchar(48), -- [REVIEW] -- re-purposed from perm_ permanence_ id
			perm_person_id						varchar(48),
			perm_adm_decision_date				datetime,
			perm_ffa_cp_decision_date			datetime,
			perm_placement_order_date			datetime,
			perm_placed_for_adoption_date		datetime,
			perm_matched_date					datetime,
			perm_placed_ffa_cp_date				datetime,
			perm_decision_reversed_date			datetime,
			perm_placed_foster_carer_date		datetime,
			perm_part_of_sibling_group			varchar(1),
			perm_siblings_placed_together		int,
			perm_siblings_placed_apart			int,
			perm_placement_provider_urn			varchar(48),
			perm_decision_reversed_reason		varchar(100),
			perm_permanence_order_date			datetime,
			perm_permanence_order_type			varchar(100),
			perm_adopted_by_carer_flag			varchar(1),
			perm_cla_id							varchar(48),
			perm_adoption_worker_id				varchar(48),
			perm_adopter_sex					varchar(48),
			perm_adopter_legal_status			varchar(100),
			perm_number_of_adopters				varchar(3)
			--, -- [REVIEW] depreciated
			--perm_allocated_worker				varchar(48)
		)
		--
		declare @ffa_cp_decision_date_question_user_codes table (
			question_user_code	varchar(128),
			question_text		varchar(500)
		)
		--
		insert into @ffa_cp_decision_date_question_user_codes values
			('f4jf0f4f-jf203cc2-jc239c32c', 'FFP CP Decision Date');
		--
		declare @siblings_placed_together_question_user_codes table (
			question_user_code	varchar(128),
			question_text		varchar(500)
		)
		--
		insert into @siblings_placed_together_question_user_codes values
			('<insert quc>', 'Question text');
		--
		declare @siblings_placed_apart_question_user_codes table (
			question_user_code	varchar(128),
			question_text		varchar(500)
		)
		--
		insert into @siblings_placed_apart_question_user_codes values
			('<insert quc>', 'Question text');
		--
		with adoption_journeys as (
			select
				x.person_id,
				x.bid_workflow_step_id,
				x.PERIOD_OF_CARE_ID,
				x.period_of_care_start_date,
				x.period_of_care_end_date,
				x.adoption_best_interest_date adoption_journey_start,
				coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption) adoption_journey_end,
				(
					select
						min(leg.start_date)
					from
						dm_LEGAL_STATUSES leg
					where
						leg.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
						and
						leg.PERSON_ID = x.person_id
						and
						leg.LEGAL_STATUS = 'E1'
						and
						leg.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
				) date_po_granted,
				(
					select
						pla.start_date
					from
						dm_placements pla
					where
						pla.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
						and
						pla.PERSON_ID = x.person_id
						and
						pla.PLACEMENT_TYPE in ('A3', 'A4', 'A5', 'A6')
						and
						pla.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
						and
						dbo.to_weighted_start(pla.START_DATE,pla.PLACEMENT_ID) = (
							select
								min(dbo.to_weighted_start(pla1.START_DATE,pla1.PLACEMENT_ID))
							from
								dm_placements pla1
							where
								pla1.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
								and
								pla1.PERSON_ID = x.person_id
								and
								pla1.PLACEMENT_TYPE in ('A3', 'A4', 'A5', 'A6')
								and
								pla1.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
						)
				) date_placed_for_adoption,
				(
					select
						pla.start_date
					from
						dm_placements pla
					where
						pla.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
						and
						pla.PERSON_ID = x.person_id
						and
						pla.PLACEMENT_TYPE in (
							'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
							'U5'	--Placement with other foster carer who is also an approved adopter- FFA
						)
						and
						pla.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
						and
						dbo.to_weighted_start(pla.START_DATE,pla.PLACEMENT_ID) = (
							select
								min(dbo.to_weighted_start(pla1.START_DATE,pla1.PLACEMENT_ID))
							from
								dm_placements pla1
							where
								pla1.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
								and
								pla1.PERSON_ID = x.person_id
								and
								pla1.PLACEMENT_TYPE in (
									'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
									'U5'	--Placement with other foster carer who is also an approved adopter- FFA
								)
								and
								pla1.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
						)
				) date_placed_in_ffa_placement,
				x.date_adoption_no_longer_plan,
				x.reason_adoption_no_longer_plan,
				x.date_matched_with_adopters,
				x.date_of_adoption,
				x.placement_type_at_adoption,
				x.date_of_ffa_cp_decision,
				case
					--Adopted by current foster carer
					when x.placement_type_at_adoption in ('A3', 'A5') then
						(
							--Find the earliest starting placement which is provided by the eventual adopter which is Fostering but not FFA
							select
								min(pla.START_DATE)
							from
								dm_placements pla
							inner join dm_placement_types ptyp
							on ptyp.PLACEMENT_TYPE = pla.PLACEMENT_TYPE
							inner join dm_CLA_SUMMARIES cla
							on cla.PLACEMENT_ID = pla.PLACEMENT_ID
							and
							cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
							and
							cla.START_DATE = pla.START_DATE
							inner join dm_PLACEMENT_DETAILS pld
							on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
							and
							pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
							where
								pla.PERSON_ID = x.person_id
								and
								pla.PERIOD_OF_CARE_ID = x.period_of_care_id
								and
								ptyp.IS_PLACED_WITH_FOSTER_CARERS = 'Y'
								and
								pld.CARER_ID = x.carer_id_at_adoption
								and
								pla.PLACEMENT_TYPE not in (
									'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
									'U5'	--Placement with other foster carer who is also an approved adopter- FFA
								)
								and
								--The child is not subsequently FFA with carer who later adopts them
								not exists (
									select
										1
									from
										dm_placements pla1
									inner join dm_placement_types ptyp1
									on ptyp1.PLACEMENT_TYPE = pla1.PLACEMENT_TYPE
									inner join dm_CLA_SUMMARIES cla1
									on cla1.PLACEMENT_ID = pla1.PLACEMENT_ID
									and
									cla1.PLACEMENT_SPLIT_NUMBER = pla1.SPLIT_NUMBER
									and
									cla1.START_DATE = pla1.START_DATE
									inner join dm_PLACEMENT_DETAILS pld1
									on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
									and
									pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
									where
										pla1.PERSON_ID = x.person_id
										and
										pla1.PERIOD_OF_CARE_ID = x.period_of_care_id
										and
										ptyp1.IS_PLACED_WITH_FOSTER_CARERS = 'Y'
										and
										pld1.CARER_ID = x.carer_id_at_adoption
										and
										pla1.PLACEMENT_TYPE in (
											'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
											'U5'	--Placement with other foster carer who is also an approved adopter- FFA
										)
										and
										pla1.START_DATE > pla.START_DATE
								)
						)
				end date_child_originally_placed_with_fc_who_adopted
			from
				(
					select
						bid.person_id,
						bid.WORKFLOW_STEP_ID bid_workflow_step_id,
						poc.PERIOD_OF_CARE_ID,
						poc.START_DATE period_of_care_start_date,
						poc.end_date period_of_care_end_date,
						bid.ADOPTION_BEST_INTEREST_DATE,
						(
							select
								min(nlp.adoption_plan_date_ceased)
							from
								dm_workflow_steps_people_vw nlp
							where
								nlp.person_id = bid.person_id
								and
								nlp.adoption_plan_date_ceased is not null
								and
								nlp.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
								and
								nlp.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
								and
								dbo.to_weighted_start(nlp.ADOPTION_PLAN_DATE_CEASED,nlp.WORKFLOW_STEP_ID) = (
									select
										min(dbo.to_weighted_start(nlp1.ADOPTION_PLAN_DATE_CEASED,nlp1.workflow_step_id))
									from
										dm_workflow_steps_people_vw nlp1
									where
										nlp1.person_id = bid.person_id
										and
										nlp1.adoption_plan_date_ceased is not null
										and
										nlp1.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
										and
										nlp1.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
								)
						) date_adoption_no_longer_plan,
						(
							select
								min(nlp.ADOPTION_PLAN_REASON_CAT_CODE)
							from
								dm_workflow_steps_people_vw nlp
							where
								nlp.person_id = bid.person_id
								and
								nlp.adoption_plan_date_ceased is not null
								and
								nlp.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
								and
								nlp.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
								and
								dbo.to_weighted_start(nlp.ADOPTION_PLAN_DATE_CEASED,nlp.WORKFLOW_STEP_ID) = (
									select
										min(dbo.to_weighted_start(nlp1.ADOPTION_PLAN_DATE_CEASED,nlp1.workflow_step_id))
									from
										dm_workflow_steps_people_vw nlp1
									where
										nlp1.person_id = bid.person_id
										and
										nlp1.adoption_plan_date_ceased is not null
										and
										nlp1.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
										and
										nlp1.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
								)
						) reason_adoption_no_longer_plan,
						(
							select
								min(nlp.adoption_match_date)
							from
								dm_workflow_steps_people_vw nlp
							where
								nlp.person_id = bid.person_id
								and
								nlp.adoption_match_date is not null
								and
								nlp.adoption_match_date between poc.start_date and dbo.future(poc.end_date)
								and
								nlp.adoption_match_date > bid.ADOPTION_BEST_INTEREST_DATE
						) date_matched_with_adopters,
						case
							when poc.end_date is not null then
								(
									select
										pla.END_DATE
									from
										dm_CLA_SUMMARIES cla
									inner join dm_PLACEMENTS pla
									on pla.PLACEMENT_ID = cla.PLACEMENT_ID
									and
									pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
									and
									pla.IS_ADOPTED = 'Y'
									where
										cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
										and
										cla.PERSON_ID = poc.PERSON_ID
										and
										cla.END_DATE = poc.END_DATE
								)
						end date_of_adoption,
						case
							when poc.end_date is not null then
								(
									select
										pla.PLACEMENT_TYPE
									from
										dm_CLA_SUMMARIES cla
									inner join dm_PLACEMENTS pla
									on pla.PLACEMENT_ID = cla.PLACEMENT_ID
									and
									pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
									and
									pla.IS_ADOPTED = 'Y'
									where
										cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
										and
										cla.PERSON_ID = poc.PERSON_ID
										and
										cla.END_DATE = poc.END_DATE
								)
						end placement_type_at_adoption,
						(
							select
								min(cfa.date_answer)
							from
								dm_workflow_steps_people_vw ffa_cp
							inner join dm_CACHED_FORM_ANSWERS cfa
							on cfa.workflow_step_id = ffa_cp.WORKFLOW_STEP_ID
							and
							case 
								when cfa.subject_person_id <= 0 then 
									ffa_cp.person_id
								else 
									cfa.subject_person_id
							end = ffa_cp.person_id
							inner join @ffa_cp_decision_date_question_user_codes quc
							on quc.question_user_code = cfa.question_user_code
							where
								ffa_cp.person_id = bid.person_id
								and
								cfa.date_answer between poc.start_date and dbo.future(poc.end_date)
								and
								cfa.date_answer > bid.ADOPTION_BEST_INTEREST_DATE
								and
								dbo.to_weighted_start(cfa.date_answer,ffa_cp.WORKFLOW_STEP_ID) = (
									select
										min(dbo.to_weighted_start(cfa1.date_answer,ffa_cp1.WORKFLOW_STEP_ID))
									from
										dm_workflow_steps_people_vw ffa_cp1
									inner join dm_CACHED_FORM_ANSWERS cfa1
									on cfa1.workflow_step_id = ffa_cp1.WORKFLOW_STEP_ID
									and
									case 
										when cfa1.subject_person_id <= 0 then 
											ffa_cp1.person_id
										else 
											cfa1.subject_person_id
									end = ffa_cp1.person_id
									inner join @ffa_cp_decision_date_question_user_codes quc1
									on quc1.question_user_code = cfa1.question_user_code
									where
										ffa_cp1.person_id = bid.person_id
										and
										ffa_cp1.adoption_plan_date_ceased is not null
										and
										cfa1.date_answer between poc.start_date and dbo.future(poc.end_date)
										and
										cfa1.date_answer > bid.ADOPTION_BEST_INTEREST_DATE
								)
						) date_of_ffa_cp_decision,
						case
							when poc.end_date is not null then
								(
									select
										max(pld.CARER_ID)
									from
										dm_CLA_SUMMARIES cla
									inner join dm_PLACEMENT_DETAILS pld
									on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
									and
									pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
									inner join dm_placements pla
									on pla.PLACEMENT_ID = cla.PLACEMENT_ID
									and
									pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
									and
									pla.IS_ADOPTED = 'Y'
									where
										cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
										and
										cla.PERSON_ID = poc.PERSON_ID
										and
										cla.END_DATE = poc.END_DATE
								)
						end carer_id_at_adoption
					from
						dm_workflow_steps_people_vw bid
					inner join dm_PERIODS_OF_CARE poc
					on poc.PERSON_ID = bid.person_id
					and
					bid.ADOPTION_BEST_INTEREST_DATE between poc.START_DATE and dbo.future(poc.END_DATE)
					where
						bid.ADOPTION_BEST_INTEREST_DATE is not null
				) x		
		)
		--
		insert into ##ssd_permanence (
			perm_table_id,
			perm_person_id,
			perm_adm_decision_date,
			perm_ffa_cp_decision_date,
			perm_placement_order_date,
			perm_placed_for_adoption_date,
			perm_matched_date,
			perm_placed_ffa_cp_date,
			perm_decision_reversed_date,
			perm_placed_foster_carer_date,
			perm_part_of_sibling_group,
			perm_siblings_placed_together,
			perm_siblings_placed_apart,
			perm_placement_provider_urn,
			perm_decision_reversed_reason,
			perm_permanence_order_date,
			perm_permanence_order_type,
			perm_adopted_by_carer_flag,
			perm_cla_id,
			perm_adoption_worker_id,
			perm_adopter_sex,
			perm_adopter_legal_status,
			perm_number_of_adopters
			-- , -- [REVIEW] depreciated
			-- perm_allocated_worker
		)
		select
			'ADP' + '.' + cast(aj.bid_workflow_step_id as varchar(9)) perm_table_id,
			aj.person_id perm_person_id,
			aj.adoption_journey_start perm_adm_decision_date,
			aj.date_of_ffa_cp_decision perm_ffa_cp_decision_date,
			aj.date_po_granted perm_placement_order_date,
			aj.date_placed_for_adoption perm_placed_for_adoption_date,
			aj.date_matched_with_adopters perm_matched_date,
			aj.date_placed_in_ffa_placement perm_placed_ffa_cp_date,
			aj.date_adoption_no_longer_plan perm_decision_reversed_date,
			aj.date_child_originally_placed_with_fc_who_adopted perm_placed_foster_carer_date,
			case
				when exists (
						select
							1
						from
							dm_PERSONAL_RELATIONSHIPS rel
						inner join adoption_journeys oaj
						on oaj.person_id = rel.other_person_id
						and
						oaj.adoption_journey_start <= dbo.future(aj.adoption_journey_end)
						and
						dbo.future(oaj.adoption_journey_end) >= aj.adoption_journey_start
						where
							rel.person_id = per.person_id
							and
							rel.family_category = 'Child''s Siblings'
					) then	
					1
				else
					0
			end perm_part_of_sibling_group,
			(
				select
					min(coalesce(cfa.text_answer,cast(cfa.number_answer as varchar(9))))
				from
					dm_workflow_steps_people_vw tog_stp
				inner join dm_CACHED_FORM_ANSWERS cfa
				on cfa.workflow_step_id = tog_stp.WORKFLOW_STEP_ID
				and
				case 
					when cfa.subject_person_id <= 0 then 
						tog_stp.person_id
					else 
						cfa.subject_person_id
				end = tog_stp.person_id
				inner join @siblings_placed_together_question_user_codes quc
				on quc.question_user_code = cfa.question_user_code
				where
					tog_stp.person_id = aj.person_id
					and
					tog_stp.COMPLETED_ON between aj.adoption_journey_start and aj.adoption_journey_end
					and
					tog_stp.STEP_STATUS = 'COMPLETED'
					and
					dbo.to_weighted_start(tog_stp.COMPLETED_ON,tog_stp.WORKFLOW_STEP_ID) = (
						select
							min(dbo.to_weighted_start(tog_stp1.COMPLETED_ON,tog_stp1.WORKFLOW_STEP_ID))
						from
							dm_workflow_steps_people_vw tog_stp1
						inner join dm_CACHED_FORM_ANSWERS cfa1
						on cfa1.workflow_step_id = tog_stp1.WORKFLOW_STEP_ID
						and
						case 
							when cfa1.subject_person_id <= 0 then 
								tog_stp1.person_id
							else 
								cfa1.subject_person_id
						end = tog_stp1.person_id
						inner join @siblings_placed_together_question_user_codes quc1
						on quc1.question_user_code = cfa1.question_user_code
						where
							tog_stp1.person_id = aj.person_id
							and
							tog_stp1.COMPLETED_ON between aj.adoption_journey_start and aj.adoption_journey_end
							and
							tog_stp1.STEP_STATUS = 'COMPLETED'
					)
			) perm_siblings_placed_together,
			(
				select
					min(coalesce(cfa.text_answer,cast(cfa.number_answer as varchar(9))))
				from
					dm_workflow_steps_people_vw tog_stp
				inner join dm_CACHED_FORM_ANSWERS cfa
				on cfa.workflow_step_id = tog_stp.WORKFLOW_STEP_ID
				and
				case 
					when cfa.subject_person_id <= 0 then 
						tog_stp.person_id
					else 
						cfa.subject_person_id
				end = tog_stp.person_id
				inner join @siblings_placed_apart_question_user_codes quc
				on quc.question_user_code = cfa.question_user_code
				where
					tog_stp.person_id = aj.person_id
					and
					tog_stp.COMPLETED_ON between aj.adoption_journey_start and aj.adoption_journey_end
					and
					tog_stp.STEP_STATUS = 'COMPLETED'
					and
					dbo.to_weighted_start(tog_stp.COMPLETED_ON,tog_stp.WORKFLOW_STEP_ID)= (
						select
							min(dbo.to_weighted_start(tog_stp1.COMPLETED_ON,tog_stp1.WORKFLOW_STEP_ID))
						from
							dm_workflow_steps_people_vw tog_stp1
						inner join dm_CACHED_FORM_ANSWERS cfa1
						on cfa1.workflow_step_id = tog_stp1.WORKFLOW_STEP_ID
						and
						case 
							when cfa1.subject_person_id <= 0 then 
								tog_stp1.person_id
							else 
								cfa1.subject_person_id
						end = tog_stp1.person_id
						inner join @siblings_placed_apart_question_user_codes quc1
						on quc1.question_user_code = cfa1.question_user_code
						where
							tog_stp1.person_id = aj.person_id
							and
							tog_stp1.COMPLETED_ON between aj.adoption_journey_start and aj.adoption_journey_end
							and
							tog_stp1.STEP_STATUS = 'COMPLETED'
					)
			) perm_siblings_placed_apart,
			(
				select
					max(pld.ofsted_urn)
				from
					dm_CLA_SUMMARIES cla
				inner join dm_PLACEMENT_DETAILS pld
				on pld.element_detail_id = cla.element_detail_id
				and
				pld.split_number = cla.service_split_number
				where
					cla.person_id = aj.person_id
					and
					dbo.future(aj.adoption_journey_end) between cla.start_date and dbo.future(cla.end_date)
			) perm_placement_provider_urn,
			aj.reason_adoption_no_longer_plan perm_decision_reversed_reason,
			aj.date_of_adoption perm_permanence_order_date,
			aj.placement_type_at_adoption perm_permanence_order_type,
			null perm_adopted_by_carer_flag,
			aj.PERIOD_OF_CARE_ID perm_cla_id,
			null perm_adoption_worker_id,
			null perm_adopter_sex,
			null perm_adopter_legal_status,
			null perm_number_of_adopters
			--, -- [REVIEW] depreciated
			--null perm_allocated_worker
		from
			adoption_journeys aj
		inner join dm_persons per
		on per.PERSON_ID = aj.person_id
		union all
		select 
			'SGO' + '.' + cast(nleg.LEGAL_STATUS_ID as varchar(9)) perm_table_id,
			nleg.PERSON_ID perm_person_id,
			null perm_adm_decision_date,
			null perm_ffa_cp_decision_date,
			null perm_placement_order_date,
			null perm_placed_for_adoption_date,
			null perm_matched_date,
			null perm_placed_ffa_cp_date,
			null perm_decision_reversed_date,
			null perm_placed_foster_carer_date,
			null perm_part_of_sibling_group,
			null perm_siblings_placed_together,
			null perm_siblings_placed_apart,
			(
				select
					max(pld.ofsted_urn)
				from
					dm_CLA_SUMMARIES cla
				inner join dm_PLACEMENT_DETAILS pld
				on pld.element_detail_id = cla.element_detail_id
				and
				pld.split_number = cla.service_split_number
				where
					cla.person_id = poc.person_id
					and
					dbo.future(poc.END_DATE) between cla.start_date and dbo.future(cla.end_date)
			) perm_placement_provider_urn,
			null perm_decision_reversed_reason,
			null perm_permanence_order_date,
			null perm_permanence_order_type,
			null perm_adopted_by_carer_flag,
			poc.period_of_care_id perm_cla_id,
			null perm_adoption_worker_id,
			null perm_adopter_sex,
			null perm_adopter_legal_status,
			null perm_number_of_adopters
			-- , -- [REVIEW] depreciated
			-- null perm_allocated_worker
		from 
			dm_NON_LA_LEGAL_STATUSES nleg
		inner join dm_NON_LA_LEGAL_STATUS_TYPES ntyp
		on ntyp.LEGAL_STATUS_TYPE = nleg.LEGAL_STATUS_TYPE
		inner join dm_PERIODS_OF_CARE poc
		on poc.PERSON_ID = nleg.PERSON_ID
		and
		poc.start_date <= dbo.future(nleg.END_DATE)
		and
		dbo.future(poc.END_DATE) >= nleg.START_DATE
		where
			ntyp.IS_SPECIAL_GUARDIANSHIP_ORDER = 'Y'
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_mother') is not null
	drop procedure ##populate_ssd_mother
go
--
create procedure ##populate_ssd_mother as
begin
/*

=============================================================================

Object Name: ssd_mother

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_persons

- DM_PERSONAL_RELATIONSHIPS
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_mother') IS NOT NULL
			DROP TABLE ##ssd_mother
		--
		create table ##ssd_mother (
			moth_table_id				varchar(48),
			moth_person_id				varchar(48),
			moth_childs_person_id		varchar(48),
			moth_childs_dob				datetime
		)
		--
		insert into ##ssd_mother (
			moth_table_id,
			moth_person_id,
			moth_childs_person_id,
			moth_childs_dob
		)
		select
			NEWID() moth_table_id, -- [REVIEW] Gen new GUID, in-lieu of a known key value (added 290424)
			pr.PERSON_ID moth_person_id,
			pr.OTHER_PERSON_ID moth_childs_person_id,
			(
				select
					peo.date_of_birth
				from
					dm_persons peo
				where
					peo.PERSON_ID = pr.OTHER_PERSON_ID
			) moth_childs_dob
		from
			DM_PERSONAL_RELATIONSHIPS pr
		where
			pr.IS_MOTHER = 'Y'
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_missing') is not null
	drop procedure ##populate_ssd_missing
go
--
create procedure ##populate_ssd_missing (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_missing

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_filter_form_answers

- dm_MAPPING_GROUPS

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_missing') IS NOT NULL
			DROP TABLE ##ssd_missing
		--
		create table ##ssd_missing (
			miss_table_id					varchar(48),
			miss_person_id					varchar(48),
			miss_missing_episode_start_date		datetime,
			miss_missing_episode_type		varchar(100),
			miss_missing_episode_end_date		datetime,
			miss_missing_rhi_offered		varchar(1),
			miss_missing_rhi_accepted		varchar(1)
		)
		--
		insert into ##ssd_missing (
			miss_table_id,
			miss_person_id,
			miss_missing_episode_start_date,
			miss_missing_episode_type,
			miss_missing_episode_end_date,
			miss_missing_rhi_offered,
			miss_missing_rhi_accepted
		)
		 select 
			stp.workflow_step_id miss_table_id,
			sgs.SUBJECT_COMPOUND_ID miss_person_id,
			stp.started_on miss_missing_episode_start_date,
			(
				select
					--Should be only one per episode, but max() just in case
					max(
						case
							when ffa.text_answer = 'Missing' then
								'M'
							when ffa.text_answer = 'Absent' then
								'A'
						end
					)
				from
					dm_filter_form_answers ffa
				where
					ffa.workflow_step_id = stp.workflow_step_id
					and 
					ffa.filter_name = 'Child Absent or Missing (Document)'
					and
					case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
			) miss_missing_episode_type,
			stp.completed_on miss_missing_episode_end_date,
			(
				select
					max(
						case
							when grp.category_value = 'Yes' then
								'Y'
							when grp.category_value = 'No' then
								'N'
						end
					)
				from
					dm_filter_form_answers ffa
				inner join dm_MAPPING_GROUPS grp
				on grp.mapped_value = cast(checksum(ffa.text_answer) as varchar(11))
				and
				grp.group_name = 'Child Offered Return Interview Types'
				where
					ffa.workflow_step_id = stp.workflow_step_id
					and 
					ffa.filter_name = 'Child Offered Return Interview'
					and
					case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
			) miss_missing_rhi_offered,
			(
				select
					max(
						case
							when grp.category_value = 'Yes' then
								'Y'
							when grp.category_value = 'No' then
								'N'
						end
					)
				from
					dm_filter_form_answers ffa
				inner join dm_MAPPING_GROUPS grp
				on grp.mapped_value = cast(checksum(ffa.text_answer) as varchar(11))
				and
				grp.group_name = 'Child Accepted Return Interview Types'
				where
					ffa.workflow_step_id = stp.workflow_step_id
					and 
					ffa.filter_name = 'Child Accepted Return Interview'
					and
					case when ffa.subject_person_id <= 0 then sgs.SUBJECT_COMPOUND_ID else ffa.subject_person_id end = sgs.SUBJECT_COMPOUND_ID
			) miss_missing_rhi_accepted
		from
			dm_workflow_steps stp
		inner join dm_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			stp.is_missing_or_absent = 'Y'
			and
			stp.started_on <= @end_date
			and
			dbo.future(stp.completed_on) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_linked_identifiers') is not null
	drop procedure ##populate_ssd_linked_identifiers
go
--
create procedure ##populate_ssd_linked_identifiers as
begin
/*

=============================================================================

Object Name: ssd_linked_identifiers

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks: The list of allowed identifier_type codes are:
            ['Case Number', 
            'Unique Pupil Number', 
            'NHS Number', 
            'Home Office Registration', 
            'National Insurance Number', 
            'YOT Number', 
            'Court Case Number', 
            'RAA ID', 
            'Incident ID']
            To have any further codes agreed into the standard, issue a change request

Dependencies:

- dm_person_references
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_linked_identifiers') IS NOT NULL
			DROP TABLE ##ssd_linked_identifiers
		--
		create table ##ssd_linked_identifiers (
			link_table_id				varchar(48), -- [REVIEW] 
			link_person_id				varchar(48),
			link_identifier_type		varchar(20),
			link_identifier_value		varchar(20),
			link_valid_from_date		datetime,
			link_valid_to_date			datetime
		)
		--
		insert into ##ssd_linked_identifiers (
			link_table_id,
			link_person_id,
			link_identifier_type,
			link_identifier_value,
			link_valid_from_date,
			link_valid_to_date
		)
		select
			pref.REFERENCE_ID link_table_id,
			pref.PERSON_ID link_person_id,
			pref.REFERENCE_TYPE link_identifier_type,
			pref.REFERENCE link_identifier_value,
			null link_valid_from_date,
			null link_valid_to_date
		from
			dm_person_references pref
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_legal_status') is not null
	drop procedure ##populate_ssd_legal_status
go
--
create procedure ##populate_ssd_legal_status (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_legal_status

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_LEGAL_STATUSES
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_legal_status') IS NOT NULL
			DROP TABLE ##ssd_legal_status
		--
		create table ##ssd_legal_status (
			lega_legal_status_id				varchar(48),
			lega_person_id						varchar(48),
			lega_legal_status					varchar(100),
			lega_legal_status_start_date		datetime,
			lega_legal_status_end_date			datetime
		)
		--
		insert into ##ssd_legal_status (
			lega_legal_status_id,
			lega_person_id,
			lega_legal_status,
			lega_legal_status_start_date,
			lega_legal_status_end_date
		)
		select
			leg.LEGAL_STATUS_ID lega_legal_status_id,
			leg.PERSON_ID lega_person_id,
			leg.LEGAL_STATUS lega_legal_status,
			leg.START_DATE lega_legal_status_start_date,
			leg.END_DATE lega_legal_status_end_date
		from
			DM_LEGAL_STATUSES leg
		where
			leg.start_date <= @end_date
			and
			dbo.future(leg.end_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_involvements') is not null
	drop procedure ##populate_ssd_involvements
go
--
create procedure ##populate_ssd_involvements (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_involvements

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_worker_roles

- dm_CIN_REFERRALS

- reference_data

- dm_prof_relationships
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_involvements') IS NOT NULL
			DROP TABLE ##ssd_involvements
		--
		create table ##ssd_involvements (
			invo_involvements_id			varchar(48),
			invo_professional_id			varchar(48),
			invo_professional_role_id		varchar(48),
			invo_professional_team			varchar(255),
			invo_referral_id				varchar(48),
			invo_involvement_start_date		datetime,
			invo_involvement_end_date		datetime,
			invo_worker_change_reason		varchar(200)
		)
		--
		insert into ##ssd_involvements (
			invo_involvements_id,
			invo_professional_id,
			invo_professional_role_id,
			invo_professional_team,
			invo_referral_id,
			invo_involvement_start_date,
			invo_involvement_end_date,
			invo_worker_change_reason
		)
		select
			prof.PROF_RELATIONSHIP_ID invo_involvements_id,
			prof.WORKER_ID invo_professional_id,
			prof.PROF_REL_TYPE_CODE invo_professional_role_id,
			(
				select
					top 1
					wro.ORGANISATION_ID
				from
					dm_worker_roles wro
				where
					wro.worker_id = prof.WORKER_ID
					and
					prof.START_DATE between wro.START_DATE and coalesce(wro.END_DATE,'1 January 2300')
			) invo_professional_team,
			(
				select
					max(ref.referral_id)
				from
					dm_CIN_REFERRALS ref
				where
					ref.PERSON_ID = prof.PERSON_ID
					and
					ref.REFERRAL_DATE <= dbo.future(prof.end_date)
					and
					dbo.future(ref.CLOSURE_DATE)>= prof.start_date
			) invo_referral_id,
			prof.START_DATE invo_involvement_start_date,
			prof.END_DATE invo_involvement_end_date,
			(
				select
					rd.REF_DESCRIPTION
				from
					reference_data rd
				where
					rd.ref_code = prof.END_DATE_REASON
					and
					rd.REF_DOMAIN = 'WORKER_END_DATE_REASON'
			)
		from
			dm_prof_relationships prof
		where
			prof.start_date <= @end_date
			and
			dbo.future(prof.end_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_initial_cp_conference') is not null
	drop procedure ##populate_ssd_initial_cp_conference
go
--
create procedure ##populate_ssd_initial_cp_conference (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_initial_cp_conference

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_workflow_steps

- dm_subgroup_subjects

- dm_workflow_backwards

- dm_REGISTRATIONS

- dm_CIN_REFERRALS

- dm_MAPPING_FILTERS

- dm_workflow_links

- dm_WORKFLOW_NXT_ACTION_TYPES
=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_initial_cp_conference') IS NOT NULL
			DROP TABLE ##ssd_initial_cp_conference
		--
		create table ##ssd_initial_cp_conference (
			icpc_icpc_id					varchar(48),
			icpc_icpc_meeting_id			varchar(48),
			icpc_s47_enquiry_id				varchar(48),
			icpc_person_id					varchar(48),
			icpc_cp_plan_id					varchar(48),
			icpc_referral_id				varchar(48),
			icpc_icpc_transfer_in			varchar(1),
			icpc_icpc_target_date			datetime,
			icpc_icpc_date					datetime,
			icpc_icpc_outcome_cp_flag		varchar(1),
			icpc_icpc_outcome_json			varchar(500),
			icpc_icpc_team					varchar(48),
			icpc_icpc_worker_id				varchar(48)
		)
		--
		insert into ##ssd_initial_cp_conference (
			icpc_icpc_id,
			icpc_icpc_meeting_id,
			icpc_s47_enquiry_id,
			icpc_person_id,
			icpc_cp_plan_id,
			icpc_referral_id,
			icpc_icpc_transfer_in,
			icpc_icpc_target_date,
			icpc_icpc_date,
			icpc_icpc_outcome_cp_flag,
			icpc_icpc_outcome_json,
			icpc_icpc_team,
			icpc_icpc_worker_id
		)
		select
			x.icpc_icpc_id,
			x.icpc_icpc_meeting_id,
			x.icpc_s47_enquiry_id,
			x.icpc_person_id,
			x.icpc_cp_plan_id,
			x.icpc_referral_id,
			x.icpc_icpc_transfer_in,
			dbo.f_add_working_days(x.strategy_discussion_date,15) icpc_icpc_target_date,
			x.icpc_date icpc_icpc_date,
			case
				when icpc_cp_plan_id is not null then
					'Y'
				else
					'N'
			end icpc_icpc_outcome_cp_flag,
			x.icpc_next_actions icpc_icpc_outcome_json,
			x.RESPONSIBLE_TEAM_ID icpc_icpc_team,
			x.ASSIGNEE_ID icpc_icpc_worker_id
		from
			(
				select
					icpc.WORKFLOW_STEP_ID icpc_icpc_id,
					null icpc_icpc_meeting_id,
					(
						select
							x.STRATEGY_DISCUSSION_DATE
						from
							dm_workflow_steps x
						inner join dm_subgroup_subjects y
						on y.SUBGROUP_ID = x.SUBGROUP_ID
						and
						y.SUBJECT_TYPE_CODE = 'PER'
						where
							x.STRATEGY_DISCUSSION_DATE is not null
							and
							y.SUBJECT_COMPOUND_ID = sgs.subject_compound_id
							and
							x.WEIGHTED_START_DATETIME = (
								select
									max(sd.WEIGHTED_START_DATETIME)
								from
									dm_workflow_backwards bwd
								inner join dm_workflow_steps sd
								on sd.WORKFLOW_STEP_ID = bwd.PRECEDING_WORKFLOW_STEP_ID
								and
								sd.STRATEGY_DISCUSSION_DATE is not null
								inner join dm_subgroup_subjects sd_sgs
								on sd_sgs.SUBGROUP_ID = sd.SUBGROUP_ID
								and
								sd_sgs.SUBJECT_TYPE_CODE = 'PER'
								where
									bwd.WORKFLOW_STEP_ID = icpc.WORKFLOW_STEP_ID
									and
									sd_sgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
							)
					) strategy_discussion_date,
					(
						select
							x.WORKFLOW_STEP_ID
						from
							dm_workflow_steps x
						inner join dm_subgroup_subjects y
						on y.SUBGROUP_ID = x.SUBGROUP_ID
						and
						y.SUBJECT_TYPE_CODE = 'PER'
						where
							x.IS_SECTION_47_ENQUIRY = 'Y'
							and
							y.SUBJECT_COMPOUND_ID = sgs.subject_compound_id
							and
							x.WEIGHTED_START_DATETIME = (
								select
									max(s47.WEIGHTED_START_DATETIME)
								from
									dm_workflow_backwards bwd
								inner join dm_workflow_steps s47
								on s47.WORKFLOW_STEP_ID = bwd.PRECEDING_WORKFLOW_STEP_ID
								and
								s47.IS_SECTION_47_ENQUIRY = 'Y'
								inner join dm_subgroup_subjects s47_sgs
								on s47_sgs.SUBGROUP_ID = s47.SUBGROUP_ID
								and
								s47_sgs.SUBJECT_TYPE_CODE = 'PER'
								where
									bwd.WORKFLOW_STEP_ID = icpc.WORKFLOW_STEP_ID
									and
									s47_sgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
							)
					) icpc_s47_enquiry_id,
					sgs.SUBJECT_COMPOUND_ID icpc_person_id,
					(
						select
							reg.REGISTRATION_ID
						from
							dm_REGISTRATIONS reg
						where
							reg.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
							and
							reg.IS_CHILD_PROTECTION_PLAN = 'Y'
							and
							coalesce(reg.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
							and
							dbo.no_time(reg.REGISTRATION_START_DATE) = icpc.CP_CONFERENCE_ACTUAL_DATE
					) icpc_cp_plan_id,
					(
						select
							max(ref.referral_id)
						from
							dm_CIN_REFERRALS ref
						where
							ref.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
							and
							icpc.CP_CONFERENCE_ACTUAL_DATE between ref.REFERRAL_DATE and dbo.future(ref.CLOSURE_DATE)
					
					) icpc_referral_id,
					(
						select
							max('Y')
						from
							dm_MAPPING_FILTERS fil
						where
							fil.FILTER_NAME = 'Child CIN Transfer In Conferences'
							and
							fil.MAPPED_VALUE = icpc.WORKFLOW_STEP_TYPE_ID
					) icpc_icpc_transfer_in,
					icpc.CP_CONFERENCE_ACTUAL_DATE icpc_date,
					ltrim(stuff((
						select
							distinct ', ' + nat.description
						from
							dm_workflow_links lnk
						inner join dm_workflow_steps nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						and
						nstp.STEP_STATUS not in ('PROPOSED', 'CANCELLED')
						inner join dm_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join dm_WORKFLOW_NXT_ACTION_TYPES nat
						on nat.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = icpc.WORKFLOW_STEP_ID
					for xml path('')),1,len(','),''
					)) icpc_next_actions,
					icpc.RESPONSIBLE_TEAM_ID,
					icpc.ASSIGNEE_ID
				from
					dm_workflow_steps icpc
				inner join dm_SUBGROUP_SUBJECTS sgs
				on sgs.SUBGROUP_ID = icpc.SUBGROUP_ID
				and
				sgs.SUBJECT_TYPE_CODE = 'PER'
				where
					icpc.CP_CONFERENCE_CATEGORY = 'Initial'
					and
					icpc.STEP_STATUS = 'COMPLETED'
					and
					icpc.CP_CONFERENCE_ACTUAL_DATE between @start_date and @end_date
			) x
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_disability') is not null
	drop procedure ##populate_ssd_disability
go
--
create procedure ##populate_ssd_disability as
begin
/*

=============================================================================

Object Name: ssd_disability

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

DM_DISABILITIES

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_disability') IS NOT NULL
			DROP TABLE ##ssd_disability
		--
		create table ##ssd_disability (
			disa_person_id				varchar(48),
			disa_table_id				varchar(48),
			disa_disability_code		varchar(48)
		)
		--
		insert into ##ssd_disability (
			disa_person_id,
			disa_table_id,
			disa_disability_code
		)
		select
			dis.PERSON_ID disa_person_id,
			dis.DISABILITY_ID disa_table_id,
			dis.CIN_DISABILITY_CATEGORY_CODE disa_disability_code
		from
			DM_DISABILITIES dis
		where
			dis.CIN_DISABILITY_CATEGORY_CODE is not null
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cp_reviews') is not null
	drop procedure ##populate_ssd_cp_reviews
go
--
create procedure ##populate_ssd_cp_reviews (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cp_reviews

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_registrations

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS

- dm_cached_form_answers

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		declare @cp_conference_quorate_question_user_codes table (
			question_user_code				varchar(128),
			question_text					varchar(1000)
		)
		--
		declare @cp_conference_participation_question_user_codes table (
			question_user_code				varchar(128),
			question_text					varchar(1000)
		)
		--
		insert into @cp_conference_quorate_question_user_codes
		values
			('question_user_code','Was CP conference quorate?')
		--
		insert into @cp_conference_participation_question_user_codes
		values
			('question_user_code','How did child participate in conference?')
		--
		IF OBJECT_ID('tempdb..##ssd_cp_reviews') IS NOT NULL
			DROP TABLE ##ssd_cp_reviews
		--
		create table ##ssd_cp_reviews (
			cppr_cp_review_id						numeric(9),
			cppr_cp_plan_id							numeric(9),
			cppr_cp_review_due						datetime,
			cppr_cp_review_date						datetime,
			cppr_cp_review_outcome_continue_cp		varchar(1000), -- [REVIEW]
			cppr_cp_review_quorate					varchar(64),
			cppr_cp_review_participation			varchar(16)
		)
		--
		IF OBJECT_ID('tempdb..#cp_reviews') IS NOT NULL
			DROP TABLE #cp_reviews
		--
		create table #cp_reviews (
			cppr_cp_review_id						numeric(9),
			person_id								numeric(9),
			cppr_cp_plan_id							numeric(9),
			cppr_cp_review_due						datetime,
			cppr_cp_review_date						datetime,
			cppr_cp_review_outcome_continue_cp		varchar(1000),
			cppr_cp_review_quorate					varchar(64),
			cppr_cp_review_participation			varchar(16),
			previous_conference_workflow_step_id	numeric(9),
			previous_conference_date				datetime,
			previous_conference_type				varchar(64),
			primary key (person_id, cppr_cp_review_id)
		)
		--
		IF OBJECT_ID('tempdb..#all_cp_conferences') IS NOT NULL
			DROP TABLE #all_cp_conferences
		--
		select
			icpc.WORKFLOW_STEP_ID,
			sgs.subject_compound_id person_id,
			(
				select
					max(cpp.registration_id)
				from
					dm_registrations cpp
				where
					cpp.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
					and
					cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(cpp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					icpc.CP_CONFERENCE_ACTUAL_DATE between cpp.REGISTRATION_START_DATE and dbo.future(cpp.DEREGISTRATION_DATE)
			) registration_id,
			dbo.no_time(icpc.CP_CONFERENCE_ACTUAL_DATE) CP_CONFERENCE_ACTUAL_DATE,
			icpc.WEIGHTED_START_DATETIME,
			'ICPC' conference_type
		into
			#all_cp_conferences
		from
			dm_workflow_steps icpc
		inner join dm_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = icpc.SUBGROUP_ID
		and
		sgs.subject_type_code = 'PER'
		where
			icpc.CP_CONFERENCE_CATEGORY = 'Initial'
			and
			icpc.CP_CONFERENCE_ACTUAL_DATE is not null
			and
			icpc.STEP_STATUS = 'COMPLETED'
		union all
		select
			rev.WORKFLOW_STEP_ID cppr_cp_review_id,
			sgs.subject_compound_id person_id,
			(
				select
					max(cpp.registration_id)
				from
					dm_registrations cpp
				where
					cpp.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
					and
					cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(cpp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					rev.CP_CONFERENCE_ACTUAL_DATE between cpp.REGISTRATION_START_DATE and dbo.future(cpp.DEREGISTRATION_DATE)
			) cppr_cp_plan_id,
			dbo.no_time(rev.CP_CONFERENCE_ACTUAL_DATE) CP_CONFERENCE_ACTUAL_DATE,
			rev.WEIGHTED_START_DATETIME,
			'RCPC' conference_type
		from
			dm_workflow_steps rev
		inner join dm_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = rev.SUBGROUP_ID
		and
		sgs.subject_type_code = 'PER'
		where
			rev.CP_CONFERENCE_CATEGORY = 'Review'
			and
			rev.CP_CONFERENCE_ACTUAL_DATE is not null
			and
			rev.STEP_STATUS = 'COMPLETED'
		--
		insert into #cp_reviews (
			cppr_cp_review_id,
			person_id,
			cppr_cp_plan_id,
			cppr_cp_review_date,
			cppr_cp_review_outcome_continue_cp,
			cppr_cp_review_quorate,
			cppr_cp_review_participation
		)
		select
			rev.workflow_step_id,
			rev.person_id,
			rev.registration_id,
			rev.cp_conference_actual_date,
			case
				when rev.CP_CONFERENCE_ACTUAL_DATE = (
						select
							dbo.no_time(reg.DEREGISTRATION_DATE)
						from
							dm_registrations reg
						where
							reg.PERSON_ID = rev.person_id
							and
							reg.REGISTRATION_ID = rev.registration_id
					) then
					'N'
				else
					'Y'
			end review_outcome,
			(
				select
					max(cfa.text_answer)
				from 
					dm_cached_form_answers cfa
				inner join @cp_conference_quorate_question_user_codes codes
				on codes.question_user_code = cfa.question_user_code
				where 
					cfa.workflow_step_id = rev.workflow_step_id 
					and 
					case 
						when cfa.subject_person_id > 0 then 
							cfa.subject_person_id 
						else 
							rev.person_id 
					end = rev.person_id
			) quorate,
			(
				select
					max(cfa.text_answer)
				from 
					dm_cached_form_answers cfa
				inner join @cp_conference_participation_question_user_codes codes
				on codes.question_user_code = cfa.question_user_code
				where 
					cfa.workflow_step_id = rev.workflow_step_id 
					and 
					case 
						when cfa.subject_person_id > 0 then 
							cfa.subject_person_id 
						else 
							rev.person_id 
					end = rev.person_id
			) review_participation
		from
			#all_cp_conferences rev
		where
			rev.conference_type = 'RCPC'
		--
		update #cp_reviews
		set
			previous_conference_workflow_step_id = p.workflow_step_id,
			previous_conference_date = p.cp_conference_actual_date,
			previous_conference_type = p.conference_type,
			cppr_cp_review_due =	case
							when p.conference_type = 'ICPC' then
								dateadd(dd,91,p.cp_conference_actual_date)
							when p.conference_type = 'RCPC' then
								dateadd(dd,183,p.cp_conference_actual_date)
						end
		from	
			#all_cp_conferences p
		where
			p.person_id = #cp_reviews.person_id
			and
			p.registration_id = #cp_reviews.cppr_cp_plan_id
			and
			p.cp_conference_actual_date < #cp_reviews.cppr_cp_review_date
			and
			p.WEIGHTED_START_DATETIME = (
				select
					max(pp.WEIGHTED_START_DATETIME)
				from
					#all_cp_conferences pp
				where
					pp.person_id = #cp_reviews.person_id
					and
					pp.registration_id = #cp_reviews.cppr_cp_plan_id
					and
					pp.cp_conference_actual_date < #cp_reviews.cppr_cp_review_date
			)
		--
		insert into ##ssd_cp_reviews (
			cppr_cp_review_id,
			cppr_cp_plan_id,
			cppr_cp_review_due,
			cppr_cp_review_date,
			cppr_cp_review_outcome_continue_cp,
			cppr_cp_review_quorate,
			cppr_cp_review_participation
		)
		select
			rev.cppr_cp_review_id,
			rev.cppr_cp_plan_id,
			rev.cppr_cp_review_due,
			rev.cppr_cp_review_date,
			rev.cppr_cp_review_outcome_continue_cp,
			rev.cppr_cp_review_quorate,
			rev.cppr_cp_review_participation
		from
			#cp_reviews rev
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cp_plans') is not null
	drop procedure ##populate_ssd_cp_plans
go
--
create procedure ##populate_ssd_cp_plans (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cp_plans

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_CIN_REFERRALS

- DM_REGISTRATION_CATEGORIES

- DM_REGISTRATIONS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cp_plans') IS NOT NULL
			DROP TABLE ##ssd_cp_plans;
		--
		create table ##ssd_cp_plans (
			cppl_cp_plan_id						varchar(48),
			cppl_referral_id					varchar(48),
			cppl_icpc_id						varchar(48),
			cppl_person_id						varchar(48),
			cppl_cp_plan_start_date				datetime,
			cppl_cp_plan_end_date				datetime,
			cppl_cp_plan_initial_category		varchar(100),
			cppl_cp_plan_latest_category		varchar(100)
		);
		--
		insert into ##ssd_cp_plans (
			cppl_cp_plan_id,
			cppl_referral_id,
			cppl_icpc_id,
			cppl_person_id,
			cppl_cp_plan_start_date,
			cppl_cp_plan_end_date,
			cppl_cp_plan_initial_category,
			cppl_cp_plan_latest_category
		)
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
			cpp.REGISTRATION_STEP_ID cppl_icpc_id,
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
			and
			cpp.registration_start_date <= @end_date
			and
			dbo.future(cpp.deregistration_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_contacts') is not null
	drop procedure ##populate_ssd_contacts
go
--
create procedure ##populate_ssd_contacts (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_contacts

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_STEP_SOURCE_DETAILS

- DM_STEP_SOURCE_TYPES

- dm_workflow_links

- DM_WORKFLOW_NXT_ACTION_TYPES

- dm_workflow_steps

- DM_SUBGROUP_SUBJECTS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_contacts') IS NOT NULL
			DROP TABLE ##ssd_contacts;
		--
		create table ##ssd_contacts (
			cont_contact_id						varchar(48),
			cont_person_id						varchar(48),
			cont_contact_date					datetime,
			cont_contact_source_desc			varchar(255),
			cont_contact_outcome_json			varchar(500)
		);
		--
		insert into ##ssd_contacts (
			cont_contact_id,
			cont_person_id,
			cont_contact_date,
			cont_contact_source_desc,
			cont_contact_outcome_json
		)
		select
			con.WORKFLOW_STEP_ID cont_contact_id,
			sgs.SUBJECT_COMPOUND_ID cont_person_id,
			con.STARTED_ON cont_contact_date,
			(
				select
					styp.DESCRIPTION
				from
					DM_STEP_SOURCE_DETAILS ssd
				inner join DM_STEP_SOURCE_TYPES styp
				on styp.SOURCE_TYPE_ID = ssd.SOURCE_TYPE_ID
				where
					ssd.WORKFLOW_STEP_ID = con.WORKFLOW_STEP_ID
			) cont_contact_source_desc,
			ltrim(stuff((
				select
					distinct  ', ' + ntyp.DESCRIPTION
				from
					dm_workflow_links lnk
				inner join DM_WORKFLOW_NXT_ACTION_TYPES ntyp
				on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join DM_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				and
				nstp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
				where
					lnk.SOURCE_STEP_ID = con.WORKFLOW_STEP_ID
					and
					nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
				for xml path('')),1,len(','),''
			)) cont_contact_outcome_json
		from
			dm_workflow_steps con
		inner join DM_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = con.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			con.IS_CHILD_CONTACT = 'Y'
			and
			con.started_on between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_reviews') is not null
	drop procedure ##populate_ssd_cla_reviews
go
--
create procedure ##populate_ssd_cla_reviews (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_reviews

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_PERIODS_OF_CARE

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cla_reviews') IS NOT NULL
			DROP TABLE ##ssd_cla_reviews;
		--
		create table ##ssd_cla_reviews (
			clar_cla_review_id						varchar(48),
			clar_cla_review_due_date				datetime,
			clar_cla_review_date					datetime,
			clar_cla_review_participation			varchar(100),
			clar_cla_id								varchar(48),
			clar_cla_review_cancelled				varchar(1),
			clar_cla_person_id						varchar(48)
		);
		--
		with reviews as (
			select
				rev.LAC_REVIEW_CATEGORY,
				rev.step_status,
				rev.CANCELLED_ON,
				rev.WORKFLOW_STEP_ID,
				rev.LAC_REVIEW_DATE,
				rev.LAC_REVIEW_PARTICIPATION_CODE participation_type,
				(
					select
						max(poc.PERIOD_OF_CARE_ID)
					from
						dm_PERIODS_OF_CARE poc
					where
						rev.LAC_REVIEW_DATE between poc.START_DATE and dbo.future(poc.END_DATE)
						and
						poc.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
				) period_of_care_id,
				(
					select
						poc.start_date
					from
						dm_PERIODS_OF_CARE poc
					where
						poc.person_id = sgs.SUBJECT_COMPOUND_ID
						and
						poc.period_of_care_id = (
							select
								max(poc1.period_of_care_id)
							from
								dm_PERIODS_OF_CARE poc1
							where
								poc1.person_id = sgs.SUBJECT_COMPOUND_ID
								and
								rev.LAC_REVIEW_DATE between poc1.start_date and dbo.future(poc1.end_date)
						)
				) date_became_cla,
				sgs.SUBJECT_COMPOUND_ID person_id
			from
				dm_workflow_steps rev
			inner join dm_SUBGROUP_SUBJECTS sgs
			on sgs.SUBGROUP_ID = rev.SUBGROUP_ID
			and
			sgs.SUBJECT_TYPE_CODE = 'PER'
			where
				rev.LAC_REVIEW_CATEGORY is not null
				and
				rev.STEP_STATUS = 'COMPLETED'
		),
		cancelled_reviews as (
			select
				rev.LAC_REVIEW_CATEGORY,
				rev.CANCELLED_ON,
				rev.WORKFLOW_STEP_ID,
				(
					select
						max(poc.PERIOD_OF_CARE_ID)
					from
						dm_PERIODS_OF_CARE poc
					where
						rev.CANCELLED_ON between poc.START_DATE and dbo.future(poc.END_DATE)
						and
						poc.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
				) period_of_care_id,
				(
					select
						poc.start_date
					from
						dm_PERIODS_OF_CARE poc
					where
						poc.person_id = sgs.SUBJECT_COMPOUND_ID
						and
						poc.period_of_care_id = (
							select
								max(poc1.period_of_care_id)
							from
								dm_PERIODS_OF_CARE poc1
							where
								poc1.person_id = sgs.SUBJECT_COMPOUND_ID
								and
								rev.CANCELLED_ON between poc1.start_date and dbo.future(poc1.end_date)
						)
				) date_became_cla,
				sgs.SUBJECT_COMPOUND_ID person_id
			from
				dm_workflow_steps rev
			inner join dm_SUBGROUP_SUBJECTS sgs
			on sgs.SUBGROUP_ID = rev.SUBGROUP_ID
			and
			sgs.SUBJECT_TYPE_CODE = 'PER'
			where
				rev.LAC_REVIEW_CATEGORY is not null
				and
				rev.STEP_STATUS = 'CANCELLED'
		)
		--
		--Populate table
		insert into ##ssd_cla_reviews (
			clar_cla_review_id,
			clar_cla_review_due_date,
			clar_cla_review_date,
			clar_cla_review_participation,
			clar_cla_id,
			clar_cla_review_cancelled,
			clar_cla_person_id
		)
		select
			x.workflow_step_id clar_cla_review_id,
			case	
				when x.review_type = 'First CLA Review' then 
					dbo.f_add_working_days(x.date_became_cla,20)
				when x.review_type = 'Second CLA Review' 
					then dateadd(dd,91,x.date_of_prev_review)
				else 
					dateadd(dd,183,x.date_of_prev_review)
			end clar_cla_review_due_date,	
			x.LAC_REVIEW_DATE clar_cla_review_date,
			x.participation_type clar_cla_review_participation,
			x.period_of_care_id clar_cla_id,
			'N' clar_cla_review_cancelled,
			x.person_id clar_cla_person_id
		from
			(
				select
					r.person_id,
					r.WORKFLOW_STEP_ID,
					r.LAC_REVIEW_DATE,
					r.period_of_care_id,
					r.date_became_cla,
					(
						select
							p.WORKFLOW_STEP_ID
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
							and
							dbo.to_weighted_start(p.LAC_REVIEW_DATE,p.workflow_step_id) = (
								select
									max(dbo.to_weighted_start(p1.LAC_REVIEW_DATE,p1.WORKFLOW_STEP_ID))
								from
									reviews p1
								where
									p1.person_id = r.person_id
									and
									p1.period_of_care_id = r.period_of_care_id
									and
									p1.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
							)
					) previous_review_id,
					(
						select
							max(p.LAC_REVIEW_DATE)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
					) date_of_prev_review,
					case
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
							) = 0 then
							'First CLA Review'
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
							) = 1 then
							'Second CLA Review'
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.LAC_REVIEW_DATE
							) > 1 then
							'Subsequent CLA Review'
					end review_type,
					r.participation_type
				from
					reviews r
			) x
		where
			x.LAC_REVIEW_DATE between @start_date and @end_date
		--
		union
		--
		select
			x.workflow_step_id clar_cla_review_id,
			case	
				when x.review_type = 'First CLA Review' then 
					dbo.f_add_working_days(x.date_became_cla,20)
				when x.review_type = 'Second CLA Review' 
					then dateadd(dd,91,x.date_of_prev_review)
				else 
					dateadd(dd,183,x.date_of_prev_review)
			end clar_cla_review_due_date,	
			null clar_cla_review_date,
			null clar_cla_review_participation,
			x.period_of_care_id clar_cla_id,
			'Y' clar_cla_review_cancelled,
			x.person_id clar_cla_person_id
		from
			(
				select
					r.person_id,
					r.WORKFLOW_STEP_ID,
					r.period_of_care_id,
					r.date_became_cla,
					(
						select
							p.WORKFLOW_STEP_ID
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.CANCELLED_ON
							and
							dbo.to_weighted_start(p.LAC_REVIEW_DATE,p.workflow_step_id) = (
								select
									max(dbo.to_weighted_start(p1.LAC_REVIEW_DATE,p1.WORKFLOW_STEP_ID))
								from
									reviews p1
								where
									p1.person_id = r.person_id
									and
									p1.period_of_care_id = r.period_of_care_id
									and
									p1.LAC_REVIEW_DATE < r.CANCELLED_ON
							)
					) previous_review_id,
					(
						select
							max(p.LAC_REVIEW_DATE)
						from
							reviews p
						where
							p.person_id = r.person_id
							and
							p.period_of_care_id = r.period_of_care_id
							and
							p.LAC_REVIEW_DATE < r.CANCELLED_ON
					) date_of_prev_review,
					case
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.CANCELLED_ON
							) = 0 then
							'First CLA Review'
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.CANCELLED_ON
							) = 1 then
							'Second CLA Review'
						when (
								select
									count(1)
								from
									reviews p
								where
									p.person_id = r.person_id
									and
									p.period_of_care_id = r.period_of_care_id
									and
									p.LAC_REVIEW_DATE < r.CANCELLED_ON
							) > 1 then
							'Subsequent CLA Review'
					end review_type,
					r.cancelled_on
				from
					cancelled_reviews r
			) x
		where
			x.cancelled_on between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_health') is not null
	drop procedure ##populate_ssd_cla_health
go
--
create procedure ##populate_ssd_cla_health (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_health

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_DENTAL_CHECKS

- DM_HEALTH_ASSESSMENTS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cla_health') IS NOT NULL
			DROP TABLE ##ssd_cla_health;
		--
		create table ##ssd_cla_health (
			clah_health_check_id					varchar(48),
			clah_person_id							varchar(48),
			clah_health_check_type					varchar(500),
			clah_health_check_date					datetime,
			clah_health_check_status				varchar(48)
		)
		--
		insert into ##ssd_cla_health (
			clah_health_check_id,
			clah_person_id,
			clah_health_check_type,
			clah_health_check_date,
			clah_health_check_status
		)
		select
			'DT' + cast(dent.person_id as varchar(9)) +cast(dent.DENTAL_ID as varchar(9)) clah_health_check_id,
			dent.PERSON_ID clah_person_id,
			'Dental Check' clah_health_check_type,
			dent.DENTAL_CHECK_DATE clah_health_check_date,
			null clah_health_check_status
		from
			DM_DENTAL_CHECKS dent
		where
			dent.DENTAL_CHECK_DATE between @start_date and @end_date
		--
		union all
		--
		select
			'HA' + cast(asst.person_id as varchar(9)) + cast(asst.HEALTH_ID as varchar(9)) clah_health_check_id,
			asst.PERSON_ID clah_person_id,
			'Health Assessment' clah_health_check_type,
			asst.HEALTH_ASSESSMENT_DATE clah_health_check_date,
			null clah_health_check_status
		from
			DM_HEALTH_ASSESSMENTS asst
		where
			asst.HEALTH_ASSESSMENT_DATE between @start_date and @end_date
			and
			asst.SDQ_COMPLETED = 'N'
		--
		union all
		--
		select
			'HC' + cast(chk.person_id as varchar(9)) + cast(chk.HEALTH_CHECK_ID as varchar(9)) clah_health_check_id,
			chk.PERSON_ID clah_person_id,
			'Health Check' clah_health_check_type,
			chk.HEALTH_CHECK_DATE clah_health_check_date,
			null clah_health_check_status
		from
			DM_HEALTH_CHECKS chk
		where
			chk.HEALTH_CHECK_DATE between @start_date and @end_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cla_episodes') is not null
	drop procedure ##populate_ssd_cla_episodes
go
--
create procedure ##populate_ssd_cla_episodes (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cla_episodes

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_CIN_REFERRALS

- dm_filter_form_ans

- report_filters

- dm_workflow_steps

- dm_subgroup_subjects

- dm_cla_summaries

- dm_PERIODS_OF_CARE

- dm_LEGAL_STATUSES

- dm_PLACEMENTS

- dm_PLACEMENT_DETAILS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cla_episodes') IS NOT NULL
			DROP TABLE ##ssd_cla_episodes;
		--
		create table ##ssd_cla_episodes (
			clae_cla_episode_id						varchar(48),
			clae_person_id							varchar(48),
			clae_cla_episode_start_date				datetime,
			clae_cla_episode_start_reason			varchar(100),
			clae_cla_primary_need_code				varchar(100),
			clae_cla_id								varchar(48),
			clae_referral_id						varchar(48),
			clae_cla_last_iro_contact_date			datetime,
			clae_cla_episode_ceased					datetime,
			clae_cla_placement_id					varchar(48),
			clae_entered_care_date					datetime,
			clae_cla_episode_ceased_reason			varchar(255)
		)
		insert into ##ssd_cla_episodes (
			clae_cla_episode_id,
			clae_person_id,
			clae_cla_episode_start_date,
			clae_cla_episode_start_reason,
			clae_cla_primary_need_code,
			clae_cla_id,
			clae_referral_id,
			clae_cla_last_iro_contact_date,
			clae_cla_episode_ceased,
			clae_cla_placement_id,
			clae_entered_care_date,
			clae_cla_episode_ceased_reason
		)
		select
			dbo.to_weighted_start(cla.START_DATE,cla.PERSON_ID) clae_cla_episode_id,
			cla.PERSON_ID clae_person_id,
			cla.START_DATE clae_cla_episode_start_date,
			case
				when pla.start_date = poc.start_date
				and  leg.start_date = poc.start_date then 
								'S'
				when leg.start_date > pla.start_date then
								'L'
				when leg.start_date < pla.start_date then
					case
						when prev_episode.carer_id = pld.carer_id 
						and  prev_episode.legal_status = leg.legal_status
						and  prev_episode.placement_type != pla.placement_type
							then 'T'
							else 'P'
					end
				else
					case
						when prev_episode.carer_id = pld.carer_id
							then 'U'
							else 'B'
					end 					
			end clae_cla_episode_start_reason,
			pla.CATEGORY_OF_NEED clae_cla_primary_need_code,
			cla.PERIOD_OF_CARE_ID clae_cla_id,
			(
				select
					max(ref.REFERRAL_ID)
				from
					dm_CIN_REFERRALS ref
				where
					ref.PERSON_ID = cla.PERSON_ID
					and
					ref.REFERRAL_DATE <= dbo.future(cla.END_DATE)
					and
					dbo.future(ref.CLOSURE_DATE) >= cla.START_DATE
			) clae_referral_id,
			(
				select
					max(ffa.date_answer)
				from
					dm_filter_form_ans ffa
				inner join report_filters fil
				on fil.id = ffa.filter_id
				and
				fil.name = 'Child IRO Visit Date'
				inner join dm_workflow_steps x
				on x.workflow_step_id = ffa.workflow_step_id
				inner join dm_subgroup_subjects y
				on y.subgroup_id = x.subgroup_id
				and
				y.subject_type_code = 'PER'
				where
					case 
						when ffa.subject_person_id = 0 then 
							y.subject_compound_id
						else 
							ffa.subject_person_id 
					end = cla.person_id  
					and
					ffa.date_answer <= dbo.future(cla.end_date)
			) clae_cla_last_iro_contact_date,
			cla.END_DATE clae_cla_episode_ceased,
			cla.placement_id clae_cla_placement_id,
			poc.start_date clae_entered_care_date,
			pla.REASON_EPISODE_CEASED clae_cla_episode_ceased_reason
		from
			dm_cla_summaries cla
		inner join dm_PERIODS_OF_CARE poc
		on poc.PERIOD_OF_CARE_ID = cla.PERIOD_OF_CARE_ID
		inner join dm_LEGAL_STATUSES leg
		on leg.LEGAL_STATUS_ID = cla.LEGAL_STATUS_ID
		inner join dm_PLACEMENTS pla
		on pla.PLACEMENT_ID = cla.PLACEMENT_ID
		and
		pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
		inner join dm_PLACEMENT_DETAILS pld
		on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
		and
		pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
		left outer join (
				select
					prev_csm.period_of_care_id,
					prev_csm.end_date,
					prev_pla.reason_episode_ceased,
					prev_csm.placement_id,
					prev_pld.carer_id,
					ls.legal_status,
					prev_pla.placement_type
				from
					dm_cla_summaries prev_csm
				inner join dm_placements prev_pla
				on	prev_pla.placement_id = prev_csm.placement_id
				and prev_pla.split_number = prev_csm.placement_split_number
				inner join dm_legal_statuses ls
				on ls.legal_status_id = prev_csm.legal_status_id
				--
				left join dm_placement_details prev_pld
				on	prev_pld.element_detail_id = prev_csm.element_detail_id
				and prev_pld.split_number = prev_csm.service_split_number
		) prev_episode
		on	prev_episode.period_of_care_id = cla.period_of_care_id
		and prev_episode.end_date = dateadd(dd,-1,cla.start_date)
		and prev_episode.reason_episode_ceased = 'X1'
		and prev_episode.placement_id != cla.placement_id
		where
			cla.START_DATE <= @end_date
			and
			dbo.future(cla.end_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cin_episodes') is not null
	drop procedure ##populate_ssd_cin_episodes
go
--
create procedure ##populate_ssd_cin_episodes (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cin_episodes

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- DM_SERVICE_USER_GROUPS

- DM_SERV_USER_GROUP_TYPES

- child_group_embedded_codes_vw

- dm_workflow_links

- dm_workflow_steps

- dm_subgroup_subjects

- dm_workflow_step_types

- dm_cin_referrals

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cin_episodes') IS NOT NULL
			DROP TABLE ##ssd_cin_episodes;
		--
		create table ##ssd_cin_episodes (
			cine_referral_id						int,
			cine_person_id							varchar(48),
			cine_referral_date						datetime,
			cine_cin_primary_need_code				varchar(16),
			cine_referral_source_code				varchar(48),
			cine_referral_source_desc				varchar(255),
			cine_referral_outcome_json				varchar(500),
			cine_referral_nfa						varchar(1),
			cine_close_reason						varchar(100),
			cine_close_date							datetime,
			cine_referral_team						varchar(100),
			cine_referral_worker_id					varchar(48)
		)
		--
		--Populate table
		insert into ##ssd_cin_episodes (
			cine_referral_id,
			cine_person_id,
			cine_referral_date,
			cine_cin_primary_need_code,
			cine_referral_source_code,
			cine_referral_source_desc,
			cine_referral_outcome_json,
			cine_referral_nfa,
			cine_close_reason,
			cine_close_date,
			cine_referral_team,
			cine_referral_worker_id
		)
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
			ref.SOURCE_OF_REFERRAL cine_referral_source_code,
			(
				select
					d.category_description
				from
					child_group_embedded_codes_vw d
				where
					d.group_name = 'Child CIN Referral Source'
					and
					d.category_code = ref.source_of_referral
			) cine_referral_source_desc,
			ltrim(stuff((
				select
					distinct ', ' + ntyp.description
				from
					dm_workflow_links lnk
				inner join dm_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				and
				nstp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
				inner join dm_subgroup_subjects nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join dm_workflow_step_types ntyp
				on ntyp.WORKFLOW_STEP_TYPE_ID = nstp.workflow_step_type_id
				where
					lnk.SOURCE_STEP_ID = ref.referral_id
					and
					nsgs.SUBJECT_COMPOUND_ID = ref.person_id
				order by 1
				for xml path('')),1,len(','),''
			)) cine_referral_outcome_json,
			case
				when ref.NFA_DATE is null then
					'N'
				else
					'Y'
			end cin_referral_nfa,
			ref.CLOSURE_REASON cine_close_reason,
			ref.closure_date cine_close_date,
			stp.RESPONSIBLE_TEAM_ID cine_referral_team,
			stp.ASSIGNEE_ID cine_referral_worker_id
		from
			dm_cin_referrals ref
		inner join DM_WORKFLOW_STEPS stp
		on ref.REFERRAL_ID = stp.WORKFLOW_STEP_ID
		where
			ref.referral_date <= @end_date
			and
			dbo.future(ref.closure_date) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_cin_assessments') is not null
	drop procedure ##populate_ssd_cin_assessments
go
--
create procedure ##populate_ssd_cin_assessments (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_cin_assessments

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_CIN_REFERRALS

- dm_filter_form_answers

- dm_mapping_groups

- dm_WORKFLOW_LINKS

- dm_WORKFLOW_NXT_ACTION_TYPES

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_cin_assessments') IS NOT NULL
			DROP TABLE ##ssd_cin_assessments;
		--
		create table ##ssd_cin_assessments (
			cina_assessment_id						varchar(48),
			cina_person_id							varchar(48),
			cina_referral_id						varchar(48),
			cina_assessment_start_date				datetime,
			cina_assessment_child_seen				varchar(1),
			cina_assessment_auth_date				datetime,
			cina_assessment_outcome_json			varchar(1000),
			cina_assessment_outcome_nfa				varchar(1),
			cina_assessment_team					varchar(100),
			cina_assessment_worker_id				varchar(48)
		)
		--
		declare @nfa_next_actions table (
			workflow_next_action_type_id	numeric(9),
			description						varchar(1000)
		)
		--
		declare @further_sw_intervention_next_actions table (
			workflow_next_action_type_id	numeric(9),
			description						varchar(1000)
		)
		--
		--Insert assessment next actions that represent no further action
		insert into @nfa_next_actions 
		values
			(3988, 'Closure Record'),
			(3987, 'Progress to early help - Children''s social care case closure)'),
			(3953, 'Step down to Early Help'),
			(4440, 'Step down to Early Help (EH)')
		--
		--Insert assessment next actions that represent further social work intervention
		insert into @further_sw_intervention_next_actions 
		values
			(3941, 'CYPDS - Take to First Short Breaks Panel'),
			(4130, 'Decision to seek accommodation (CSSW)'),
			(3992, 'Develop or update child or young person in need plan'),
			(3942, 'Initial Core Offer Short Breaks Plan'),
			(4468, 'Initial CYPDS Short Breaks/Preparing for Adulthood Assessment and Plan (CSSW)'),
			(3950, 'Ongoing CP Investigation / Plan'),
			(3951, 'Ongoing LAC work'),
			(3944, 'Refer to Care Pathways Panel'),
			(4122, 'Strategy discussion (CSSW)'),
			(3943, 'UASC Age Assessment')
		--
		--Populate table
		insert into ##ssd_cin_assessments (
			cina_assessment_id,
			cina_person_id,
			cina_referral_id,
			cina_assessment_start_date,
			cina_assessment_child_seen,
			cina_assessment_auth_date,
			cina_assessment_outcome_json,
			cina_assessment_outcome_nfa,
			cina_assessment_team,
			cina_assessment_worker_id
		)
		select
			CONCAT(CAST(sgs.subject_compound_id AS INT), CAST(STP.WORKFLOW_STEP_ID AS INT)) cina_assessment_id,
			sgs.SUBJECT_COMPOUND_ID cina_person_id,
			(
				select
					min(reff.referral_id)
				from
					dm_CIN_REFERRALS reff
				where
					reff.PERSON_ID = sgs.SUBJECT_COMPOUND_ID
					and
					dbo.future(stp.COMPLETED_ON) >= reff.REFERRAL_DATE
					and
					coalesce(stp.started_on, stp.incoming_on) <= dbo.future(reff.CLOSURE_DATE)
			) cina_referral_id,
			coalesce(stp.STARTED_ON, stp.incoming_on) cina_assessment_start_date,
			(              
				select 
					max(case when grp.category_value = 'Yes' then 'Y' when grp.category_value = 'No' then 'N' end)
				from              
					dm_filter_form_answers ffa              
				inner join dm_mapping_groups grp
				on grp.mapped_value = cast(checksum(ffa.text_answer) as varchar(11))
				and    
				grp.group_name = 'Child Seen During Assessment'              
				where              
				ffa.workflow_step_id = stp.workflow_step_id 
				and                 
				ffa.filter_name =  'Child Seen During Event (Lookup)'              
				and 
				case 
					when ffa.subject_person_id = 0 then 
						sgs.subject_compound_id 
					else 
						ffa.subject_person_id 
				end = sgs.subject_compound_id
			) cina_assessment_child_seen,
			stp.COMPLETED_ON cina_assessment_auth_date,
			case
				when exists (
						select
							1
						from
							dm_WORKFLOW_LINKS lnk
						inner join dm_WORKFLOW_NXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join dm_workflow_steps nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join dm_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @further_sw_intervention_next_actions inter
						on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					) then
					'Y'
				else
					'N'
			end cina_assessment_outcome_further_intervention,
			case
				when exists (
						select
							1
						from
							dm_WORKFLOW_LINKS lnk
						inner join dm_WORKFLOW_NXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join dm_workflow_steps nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join dm_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @nfa_next_actions nfa
						on nfa.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					)
					and
					not exists (
						select
							1
						from
							dm_WORKFLOW_LINKS lnk
						inner join dm_WORKFLOW_NXT_ACTION_TYPES ntyp
						on ntyp.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						inner join dm_workflow_steps nstp
						on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
						inner join dm_SUBGROUP_SUBJECTS nsgs
						on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
						and
						nsgs.SUBJECT_TYPE_CODE = 'PER'
						inner join @further_sw_intervention_next_actions inter
						on inter.workflow_next_action_type_id = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
						where
							lnk.SOURCE_STEP_ID = stp.WORKFLOW_STEP_ID
							and
							nstp.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
							and
							nsgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
					) then
				'Y'
				else
					'N'
			end cina_assessment_outcome_nfa,
			stp.RESPONSIBLE_TEAM_ID cina_assessment_team,
			stp.ASSIGNEE_ID cina_assessment_worker_id
		from
			dm_workflow_steps stp
		inner join dm_subgroup_subjects sgs
		on sgs.subgroup_id = stp.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		where
			stp.IS_CONTINUOUS_ASSESSMENT = 'Y'
			and
			--CRITERIA: Assessment was ongoing in the period
			coalesce(stp.STARTED_ON, stp.incoming_on) <= @end_date
			and
			dbo.future(stp.completed_on) >= @start_date
			and
			stp.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_assessment_factors') is not null
	drop procedure ##populate_ssd_assessment_factors
go
--
create procedure ##populate_ssd_assessment_factors (@start_date datetime, @end_date datetime) as
begin
/*

=============================================================================

Object Name: ssd_assessment_factors

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_cin_assess_factors

- dm_workflow_steps

=============================================================================

*/
	begin try
		--
		set nocount on
		--
		IF OBJECT_ID('tempdb..##ssd_assessment_factors') IS NOT NULL
			DROP TABLE ##ssd_assessment_factors;
		--
		create table ##ssd_assessment_factors (
			cinf_table_id						varchar(48),
			cinf_assessment_id					varchar(48),
			cinf_assessment_factors_json		varchar(1000)
		)
		--
		insert into ##ssd_assessment_factors (
			cinf_table_id,
			cinf_assessment_id,
			cinf_assessment_factors_json
		)
		select
			null cinf_table_id,
			fact.ASSESSMENT_ID cinf_assessment_id,
			fact.FACTOR_VALUE cinf_assessment_factors_json
		from
			dm_cin_assess_factors fact
		inner join dm_workflow_steps stp
		on stp.workflow_step_id = fact.assessment_id
		where
			--CRITERIA: Assessment was ongoing in the period
			coalesce(stp.STARTED_ON, stp.incoming_on) <= @end_date
			and
			dbo.future(stp.completed_on) >= @start_date
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
--
if object_id('tempdb..##populate_ssd_care_leavers') is not null
	drop procedure ##populate_ssd_care_leavers
go
--
create procedure ##populate_ssd_care_leavers as
begin
/*

=============================================================================

Object Name: ssd_care_leavers

Description:

Author: D2I

Version: 1.0

Status: AwaitingReview

Remarks:

Dependencies:

- dm_cla_summaries

- dm_legal_statuses

- dm_persons

- dm_PERIODS_OF_CARE

- dm_ALLOCATED_WORKERS

- dm_PROF_RELATIONSHIPS

- dm_former_in_touch_types

- dm_mapping_groups

- dm_former_accom_types

- dm_former_activity_types

- dm_former_looked_after

- dm_workflow_steps

- dm_SUBGROUP_SUBJECTS

- dm_workers

- dm_WORKER_ROLES

- dm_ORGANISATIONS

=============================================================================

*/
	begin try
		--
		set nocount on
		--
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
		IF OBJECT_ID('tempdb..##ssd_care_leavers') IS NOT NULL
			DROP TABLE ##ssd_care_leavers;
		--
		create table #ssd_care_leavers (
			clea_table_id							varchar(48), -- [REVIEW]
			clea_person_id							varchar(48),
			clea_care_leaver_eligibility			varchar(100),
			clea_care_leaver_in_touch				varchar(100),
			clea_care_leaver_latest_contact			datetime,
			clea_care_leaver_accommodation			varchar(100),
			clea_care_leaver_accom_suitable			varchar(100),
			clea_care_leaver_activity				varchar(100),
			clea_pathway_plan_review_date			datetime,
			clea_care_leaver_personal_advisor		varchar(100),
			clea_care_leaver_allocated_team			varchar(48),
			clea_care_leaver_worker_id				varchar(48)
		);
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
											dm_PERIODS_OF_CARE poc
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
											dm_ALLOCATED_WORKERS awkr
										where
											awkr.PERSON_ID = p.PERSON_ID
											and
											@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
										union
										select
											1
										from
											dm_PROF_RELATIONSHIPS pr
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
									dm_PERIODS_OF_CARE poc
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
												dm_ALLOCATED_WORKERS awkr
											where
												awkr.PERSON_ID = p.PERSON_ID
												and
												@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
											union
											select
												1
											from
												dm_PROF_RELATIONSHIPS pr
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
					dm_PERIODS_OF_CARE poc
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
		--Populate the table
		insert into #ssd_care_leavers (
			clea_table_id,
			clea_person_id,
			clea_care_leaver_eligibility,
			clea_care_leaver_in_touch,
			clea_care_leaver_latest_contact,
			clea_care_leaver_accommodation,
			clea_care_leaver_accom_suitable,
			clea_care_leaver_activity,
			clea_pathway_plan_review_date,
			clea_care_leaver_personal_advisor,
			clea_care_leaver_allocated_team,
			clea_care_leaver_worker_id
		)
		select
			null clea_table_id, -- [REVIEW]
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
				inner join dm_SUBGROUP_SUBJECTS psgs
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
					dm_PROF_RELATIONSHIPS pr
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
					org.ORGANISATION_ID
				from
					dm_ALLOCATED_WORKERS awkr
				inner join dm_WORKER_ROLES wro
				on wro.WORKER_ID = awkr.WORKER_ID
				and
				@snapshot_date between wro.START_DATE and dbo.future(wro.END_DATE)
				inner join dm_ORGANISATIONS org
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
							dm_ALLOCATED_WORKERS awkr1
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
							dm_WORKER_ROLES wro1
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
					dm_ALLOCATED_WORKERS awkr
				where
					awkr.PERSON_ID = clc.person_id
					and
					@snapshot_date between awkr.START_DATE and dbo.future(awkr.END_DATE)
					and
					dbo.to_weighted_start(awkr.START_DATE,awkr.ALLOCATION_ID) = (
						select
							max(dbo.to_weighted_start(awkr1.START_DATE,awkr1.ALLOCATION_ID))
						from
							dm_ALLOCATED_WORKERS awkr1
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
		--
		return 0
	end try
	begin catch
		-- Record error details in log
		declare	@v_error_number		int,
				@v_error_message	nvarchar(4000)
		select
			@v_error_number = error_number(),
			@v_error_message = error_message()
		--
		return @v_error_number
	end catch
end
go
-- 




-- [REVIEW] added RH 290424
if object_id('tempdb..##populate_ssd_s251_finance') is not null
	drop procedure ##populate_ssd_s251_finance
go
--
create procedure ##populate_ssd_s251_finance as
begin
/*
=============================================================================
Object Name: ssd_s251_finance
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_s251_finance') IS NOT NULL
        DROP TABLE ##ssd_s251_finance
    --
    create table ##ssd_s251_finance (
        s251_table_id           nvarchar(48) primary key default NEWID(),
        s251_cla_placement_id   nvarchar(48),
        s251_placeholder_1      nvarchar(48),
        s251_placeholder_2      nvarchar(48),
        s251_placeholder_3      nvarchar(48),
        s251_placeholder_4      nvarchar(48)
    )
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--


--[REVIEW] added RH 290424
if object_id('tempdb..##populate_ssd_voice_of_child') is not null
    drop procedure ##populate_ssd_voice_of_child
go
--
create procedure ##populate_ssd_voice_of_child
begin
/*
=============================================================================
Object Name: ssd_voice_of_child
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: AwaitingReview|[REVIEW]
Remarks:
Dependencies:
- Yet to be defined
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_voice_of_child') IS NOT NULL
        DROP TABLE ##ssd_voice_of_child
    --
    create table ##ssd_voice_of_child (
        voch_table_id               nvarchar(48) primary key,
        voch_person_id              nvarchar(48),
        voch_explained_worries      nchar(1),
        voch_story_help_understand  nchar(1),
        voch_agree_worker           nchar(1),
        voch_plan_safe              nchar(1),
        voch_tablet_help_explain    nchar(1)
    )
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
-- 


--[REVIEW] added RH 290424
if object_id('tempdb..##populate_ssd_pre_proceedings') is not null
    drop procedure ##populate_ssd_pre_proceedings
go
--
create procedure ##populate_ssd_pre_proceedings
begin
/*
=============================================================================
Object Name: ssd_pre_proceedings
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
Status: AwaitingReview|[REVIEW]
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_pre_proceedings') IS NOT NULL
        DROP TABLE ##ssd_pre_proceedings
    --
    create table ##ssd_pre_proceedings (
        prep_table_id                           nvarchar(48) primary key default NEWID(),
        prep_person_id                          nvarchar(48),
        prep_plo_family_id                      nvarchar(48),
        prep_pre_pro_decision_date              datetime,
        prep_initial_pre_pro_meeting_date       datetime,
        prep_pre_pro_outcome                    nvarchar(100),
        prep_agree_stepdown_issue_date          datetime,
        prep_cp_plans_referral_period           int, -- count cp plans the child has been subject within referral period (cin episode)
        prep_legal_gateway_outcome              nvarchar(100),
        prep_prev_pre_proc_child                int,
        prep_prev_care_proc_child               int,
        prep_pre_pro_letter_date                datetime,
        prep_care_pro_letter_date               datetime,
        prep_pre_pro_meetings_num               int,
        prep_pre_pro_parents_legal_rep          nchar(1), 
        prep_parents_legal_rep_point_of_issue   nchar(2),
        prep_court_reference                    nvarchar(48),
        prep_care_proc_court_hearings           int,
        prep_care_proc_short_notice             nchar(1), 
        prep_proc_short_notice_reason           nvarchar(100),
        prep_la_inital_plan_approved            nchar(1), 
        prep_la_initial_care_plan               nvarchar(100),
        prep_la_final_plan_approved             nchar(1), 
        prep_la_final_care_plan                 nvarchar(100)
    )
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--

--[REVIEW] added RH 290424
if object_id('tempdb..##populate_ssd_send') is not null
    drop procedure ##populate_ssd_send
go
--
create procedure ##populate_ssd_send
begin
/*
=============================================================================
Object Name: ssd_send
Description: 
Author: D2I
Version: 1.0
Status: Testing
Remarks: 
Dependencies: 
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_send') IS NOT NULL
        DROP TABLE ##ssd_send
    --
    create table ##ssd_send (
        send_table_id       nvarchar(48) primary key,
        send_person_id      nvarchar(48),
        send_upn            nvarchar(48),
        send_uln            nvarchar(48),
        send_upn_unknown    nvarchar(48)
    )
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
-- 

--[REVIEW] added RH 290424
if object_id('tempdb..##populate_ssd_sen_need') is not null
    drop procedure ##populate_ssd_sen_need
go
--
create procedure ##populate_ssd_sen_need
begin
/*
=============================================================================
Object Name: ssd_sen_need
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_sen_need') IS NOT NULL
        DROP TABLE ##ssd_sen_need
    --
    create table ##ssd_sen_need (
        senn_table_id                       nvarchar(48) primary key,
        senn_active_ehcp_id                 nvarchar(48),
        senn_active_ehcp_need_type          nvarchar(100),
        senn_active_ehcp_need_rank          nchar(1)
    )
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--

--[REVIEW] added RH 300424
if object_id('tempdb..##populate_ssd_ehcp_requests') is not null
    drop procedure ##populate_ssd_ehcp_requests
go
--
create procedure ##populate_ssd_ehcp_requests
begin
/*
=============================================================================
Object Name: ssd_ehcp_requests
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_ehcp_requests') IS NOT NULL
        DROP TABLE ##ssd_ehcp_requests
    --

	create table ##ssd_ehcp_requests (
		ehcr_ehcp_request_id            NVARCHAR(48) primary key,
		ehcr_send_table_id              NVARCHAR(48),
		ehcr_ehcp_req_date              DATETIME,
		ehcr_ehcp_req_outcome_date      DATETIME,
		ehcr_ehcp_req_outcome           NVARCHAR(100)
	)

    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--

--[REVIEW] added RH 300424
if object_id('tempdb..##populate_ssd_ehcp_assessment') is not null
    drop procedure ##populate_ssd_ehcp_assessment
go
--
create procedure ##populate_ssd_ehcp_assessment
begin
/*
=============================================================================
Object Name: ssd_ehcp_assessment
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_ehcp_assessment') IS NOT NULL
        DROP TABLE ##ssd_ehcp_assessment
    --
    create table ##ssd_ehcp_assessment (
		ehca_ehcp_assessment_id             NVARCHAR(48) primary key,
		ehca_ehcp_request_id                NVARCHAR(48),
		ehca_ehcp_assessment_outcome_date   DATETIME,
		ehca_ehcp_assessment_outcome        NVARCHAR(100),
		ehca_ehcp_assessment_exceptions     NVARCHAR(100)
	)
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--

--[REVIEW] added RH 300424
if object_id('tempdb..##populate_ssd_ehcp_named_plan') is not null
    drop procedure ##populate_ssd_ehcp_named_plan
go
--
create procedure ##populate_ssd_ehcp_named_plan
begin
/*
=============================================================================
Object Name: ssd_ehcp_named_plan
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_ehcp_named_plan') IS NOT NULL
        DROP TABLE ##ssd_ehcp_named_plan
    --
    create table ##ssd_ehcp_named_plan (
		ehcn_named_plan_id              NVARCHAR(48) primary key,
		ehcn_ehcp_asmt_id               NVARCHAR(48),
		ehcn_named_plan_start_date      DATETIME,
		ehcn_named_plan_ceased_date      DATETIME,
		ehcn_named_plan_ceased_reason    NVARCHAR(100)
	)
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--


--[REVIEW] added RH 300424
if object_id('tempdb..##populate_ssd_ehcp_active_plans') is not null
    drop procedure ##populate_ssd_ehcp_active_plans
go
--
create procedure ##populate_ssd_ehcp_active_plans
begin
/*
=============================================================================
Object Name: ssd_ehcp_active_plans
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
Status: Testing
Remarks:
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_ehcp_active_plans') IS NOT NULL
        DROP TABLE ##ssd_ehcp_active_plans
    --
    create table ##ssd_ehcp_active_plans (
		ehcp_active_ehcp_id                 NVARCHAR(48) primary key,
		ehcp_ehcp_request_id                NVARCHAR(48),
		ehcp_active_ehcp_last_review_date   DATETIME
	)
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--

--[REVIEW] added RH 100624
if object_id('tempdb..##populate_ssd_department') is not null
    drop procedure ##populate_ssd_department
go
--
create procedure ##populate_ssd_department
begin
/*
=============================================================================
Object Name: ssd_department
Description: In progress/To be developed
Author: D2I
Version: 0.1
Status: Development
Remarks: New object - source data to be confirmed
Dependencies:
- Yet to be defined
-
=============================================================================
*/
begin try
    --set nocount on
    --
    IF OBJECT_ID('tempdb..##ssd_department') IS NOT NULL
        DROP TABLE ##ssd_department
    --
    create table ##ssd_department (
		dept_team_id                 	NVARCHAR(48) primary key,
		dept_team_name               	NVARCHAR(255),
		dept_team_parent_id   			NVARCHAR(48),
		dept_team_parent_name 			NVARCHAR(255)
	)
    --
    return 0
end try
begin catch
    -- Record error details in log
    declare @v_error_number        int,
            @v_error_message    nvarchar(4000)
    select
        @v_error_number = error_number(),
        @v_error_message = error_message()
    --
    return @v_error_number
end catch
go
--




--
if object_id('tempdb..##populate_ssd_main') is not null
	drop procedure ##populate_ssd_main
go
--
create procedure ##populate_ssd_main (@years_to_include int) as
begin
	--
	set nocount on
	--
	--No. or financial years to include, including the current one
	declare @number_of_years_to_include int, @start_date varchar(32), @end_date varchar(32)
	--
	set @number_of_years_to_include = @years_to_include - 1
	--
	select
		@start_date = dateadd(yy,-@number_of_years_to_include,rd.financial_year_start),
		@end_date = rd.curr_day
	from
		report_days rd
	where
		rd.curr_day = dbo.today()
	--


	-- placeholder tables, incl. Non-core cms or SSDF Other DfE projects (1b, 2(a,b) [REVIEW]

	exec ##populate_ssd_s251_finance;		-- Testing [REVIEW] added RH 290424
	exec ##ssd_voice_of_child;				-- Testing [REVIEW] added RH 290424
	exec ##ssd_pre_proceedings;				-- Testing [REVIEW] added RH 290424
	exec ##ssd_send;						-- Testing [REVIEW] added RH 290424
	exec ##ssd_sen_need;					-- Testing [REVIEW] added RH 290424
	exec ##ssd_ehcp_requests;				-- Testing [REVIEW] added RH 290424
	exec ##ssd_ehcp_assessment;				-- Testing [REVIEW] added RH 290424
	exec ##ssd_ehcp_named_plan;				-- Testing [REVIEW] added RH 290424
	exec ##ssd_ehcp_active_plans;			-- Testing [REVIEW] added RH 290424

	-- end placeholder tables

	exec ##ssd_department;			-- NEW/Development [REVIEW] added RH 100624 (source data not yet set up)

	exec ##populate_ssd_care_leavers;
	exec ##populate_ssd_assessment_factors @start_date, @end_date;
	exec ##populate_ssd_cin_assessments @start_date, @end_date;
	exec ##populate_ssd_cin_episodes @start_date, @end_date;
	exec ##populate_ssd_cla_episodes @start_date, @end_date;
	exec ##populate_ssd_cla_health @start_date, @end_date;
	exec ##populate_ssd_cla_reviews @start_date, @end_date;
	exec ##populate_ssd_contacts @start_date, @end_date;
	exec ##populate_ssd_cp_plans @start_date, @end_date;
	exec ##populate_ssd_cp_reviews @start_date, @end_date;
	exec ##populate_ssd_disability;
	exec ##populate_ssd_initial_cp_conference @start_date, @end_date;
	exec ##populate_ssd_involvements @start_date, @end_date;
	exec ##populate_ssd_legal_status @start_date, @end_date;
	exec ##populate_ssd_linked_identifiers; 
	exec ##populate_ssd_missing @start_date, @end_date;
	exec ##populate_ssd_mother;
	exec ##populate_ssd_permanence;
	exec ##populate_ssd_person;
	exec ##populate_ssd_cla_placement @start_date, @end_date;
	exec ##populate_ssd_cla_previous_permanence;
	exec ##populate_ssd_professionals;
	exec ##populate_ssd_sdq_scores @start_date, @end_date;
	exec ##populate_ssd_address;
	exec ##populate_ssd_cla_convictions @start_date, @end_date;
	exec ##populate_ssd_cla_immunisations;
	exec ##populate_ssd_cla_substance_misuse;
	exec ##populate_ssd_cp_visits @start_date, @end_date;
	exec ##populate_ssd_immigration_status;
	exec ##populate_ssd_cla_care_plan @start_date, @end_date;
	exec ##populate_ssd_cla_visits @start_date, @end_date;
	exec ##populate_ssd_cin_visits @start_date, @end_date;
	exec ##populate_ssd_early_help_episodes @start_date, @end_date;
	--
end
go