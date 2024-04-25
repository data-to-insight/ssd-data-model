/******DECLARE VARIABLES******/
declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 December 2023'
--
declare @icpc_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @icpc_date_question_user_codes table (
	question_user_code				varchar(128),
	factor_code						varchar(1000)
)
--
declare @strat_disc_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @strategy_discussion_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @section_47_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @section_47_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
--
--
--
--
--
--
--
--
--
--Insert workflow step types which are used to capture ICPCs
insert into @icpc_workflow_step_types 
values
	(1860,	'Initial Child Protection Conference (Essex)')
	--,(<additional value>, <additional value>)
--
insert into @icpc_date_question_user_codes
values
	('childProtectionPlanDecisionDate','Actual date of conference')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture Strategy Discussions
insert into @strat_disc_workflow_step_types 
values
	(8107, 'Further Strategy Discussion'),
	(1897, 'Strategy Discussion (Essex)')
	--,(<additional value>, <additional value>)
--
insert into @strategy_discussion_date_question_user_codes
values
	('date_of_strategy','Actual date')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture Strategy Discussions
insert into @section_47_workflow_step_types 
values
	(1918, 'Section 47 Enquiry (Essex)')
	--,(<additional value>, <additional value>)
--
insert into @section_47_date_question_user_codes
values
	('s47_end_date','Date Outcome of S47 Enquiries completed')
	--,(<additional value>, <additional value>)
--
--
--
--
--
--
--
--
--
--
--
/******EXECUTE CODE******/
if object_id('tempdb..#date_answers') is not null
	drop table #date_answers
--
select
	stp.WORKFLOW_STEP_ID,
	que.QUESTION_USER_CODE,
	dates.DATE_ANSWER,
	r.form_answer_row_id,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#date_answers
from
	raw.mosaic_fw_MO_FORM_DATE_ANSWERS dates
inner join raw.mosaic_fw_MO_QUESTIONS que 
on que.QUESTION_ID = dates.QUESTION_ID
inner join raw.mosaic_fw_MO_FORMS frm
on frm.FORM_ID = dates.FORM_ID
inner join raw.mosaic_fw_MO_WORKFLOW_STEPS stp 
on stp.WORKFLOW_STEP_ID = frm.WORKFLOW_STEP_ID
inner join raw.mosaic_fw_mo_form_answer_rows r
on r.form_answer_row_id = dates.form_answer_row_id
inner join raw.mosaic_fw_MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	que.QUESTION_USER_CODE in (
		select q.question_user_code from @strategy_discussion_date_question_user_codes q
		union
		select q.question_user_code from @section_47_date_question_user_codes q
		union
		select q.question_user_code from @icpc_date_question_user_codes q
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		select s.workflow_step_type_id from @strat_disc_workflow_step_types s
		union
		select s.workflow_step_type_id from @section_47_workflow_step_types s
		union
		select s.workflow_step_type_id from @icpc_workflow_step_types s
	)
--
if object_id('tempdb..#strategy_discussions') is not null
	drop table #strategy_discussions
--
select
	x.*,
	replace(replace(replace(convert(varchar, x.strategy_discussion_date, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)))) + cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)) weighted_start
into
	#strategy_discussions
from
	(
		select
			sgs.subject_compound_id person_id,
			sd.workflow_step_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @strategy_discussion_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = sd.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				coalesce(sd.completed_on, sd.started_on, sd.incoming_on)
			) strategy_discussion_date
		from
			raw.mosaic_fw_mo_workflow_steps sd
		inner join raw.mosaic_fw_mo_subgroup_subjects sgs
		on sgs.SUBGROUP_ID = sd.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @strat_disc_workflow_step_types sd_typ
		on sd_typ.workflow_step_type_id = sd.WORKFLOW_STEP_TYPE_ID
		where
			sd.step_status in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
	) x
--
create index strat_people_idx on #strategy_discussions (person_id)
--
if object_id('tempdb..#section_47_enquiries') is not null
	drop table #section_47_enquiries
--
select
	x.*,
	replace(replace(replace(convert(varchar, x.section_47_enquiry_date, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)))) + cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)) weighted_start
into
	#section_47_enquiries
from
	(
		select
			sgs.subject_compound_id person_id,
			sd.workflow_step_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @section_47_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = sd.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				coalesce(sd.completed_on, sd.started_on, sd.incoming_on)
			) section_47_enquiry_date
		from
			raw.mosaic_fw_mo_workflow_steps sd
		inner join raw.mosaic_fw_mo_subgroup_subjects sgs
		on sgs.SUBGROUP_ID = sd.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @section_47_workflow_step_types sd_typ
		on sd_typ.workflow_step_type_id = sd.WORKFLOW_STEP_TYPE_ID
		where
			sd.step_status in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
	) x
--
create index s47_people_idx on #section_47_enquiries (person_id)
--
if object_id('tempdb..#initial_cp_conferences') is not null
	drop table #initial_cp_conferences
--
select
	x.person_id,
	x.workflow_step_id,
	x.WORKFLOW_STEP_TYPE_ID,
	convert(datetime, convert(varchar, x.conference_date, 103), 103) conference_date,
	x.assignee_id,
	x.responsible_team_id,
	replace(replace(replace(convert(varchar, x.conference_date, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)))) + cast(cast(x.WORKFLOW_STEP_ID as numeric(9)) as varchar(9)) weighted_start
into
	#initial_cp_conferences
from
	(
		select
			sgs.subject_compound_id person_id,
			icpc.workflow_step_id,
			icpc.WORKFLOW_STEP_TYPE_ID,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @icpc_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = icpc.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				coalesce(icpc.completed_on, icpc.started_on, icpc.incoming_on)
			) conference_date,
			icpc.assignee_id,
			icpc.responsible_team_id
		from
			raw.mosaic_fw_mo_workflow_steps icpc
		inner join raw.mosaic_fw_mo_subgroup_subjects sgs
		on sgs.SUBGROUP_ID = icpc.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @icpc_workflow_step_types icpc_typ
		on icpc_typ.workflow_step_type_id = icpc.WORKFLOW_STEP_TYPE_ID
		where
			icpc.step_status in ('INCOMING', 'STARTED', 'REOPENED', 'COMPLETED')
	) x;
--
create index icpc_people_idx on #initial_cp_conferences (person_id);
--
if object_id('tempdb..#dates') is not null
	drop table #dates
--
select
	dates.THEDATE,
	coalesce(dates.NONWORKDAY,'N') is_non_working_day,
	case
		when coalesce(dates.NONWORKDAY,'N') = 'N' then
			count(dates.thedate) over (partition by dates.nonworkday order by dates.thedate)
	end running_working_day_number
into
	#dates
from
	raw.Mapping_Dates dates
--
create index dates_idx on #dates (thedate);
--
select
	x.icpc_icpc_id,
	x.icpc_icpc_meeting_id,
	x.icpc_s47_enquiry_id,
	x.person_id icpc_person_id,
	x.icpc_cp_plan_id,
	null icpc_referral_id,
	x.icpc_icpc_transfer_in,
	x.icpc_icpc_target_date,
	x.conference_date icpc_icpc_date,
	case
		when x.icpc_cp_plan_id is not null then
			'Y'
		else
			'N'
	end icpc_icpc_outcome_cp_flag,
	x.RESPONSIBLE_TEAM_ID,
	x.ASSIGNEE_ID
from
	(
		select
			icpc.person_id,
			icpc.WORKFLOW_STEP_ID icpc_icpc_id,
			null icpc_icpc_meeting_id,
			(
				select
					max(sd.strategy_discussion_date)
				from
					#strategy_discussions sd
				where
					sd.person_id = icpc.person_id
					and
					sd.strategy_discussion_date <= icpc.conference_date
					and
					sd.weighted_start = (
						select
							max(sd1.weighted_start)
						from
							#strategy_discussions sd1
						where
							sd1.person_id = icpc.person_id
							and
							sd1.strategy_discussion_date <= icpc.conference_date
					)
			) strategy_discussion_date,
			(
				select
					max(s47.WORKFLOW_STEP_ID)
				from
					#section_47_enquiries s47
				where
					s47.person_id = icpc.person_id
					and
					s47.section_47_enquiry_date <= icpc.conference_date
					and
					s47.weighted_start = (
						select
							max(t.weighted_start)
						from
							#section_47_enquiries t
						where
							t.person_id = icpc.person_id
							and
							t.section_47_enquiry_date <= icpc.conference_date
					)
			) icpc_s47_enquiry_id,
			(
				select
					reg.REGISTRATION_ID
				from
					raw.mosaic_fw_DM_REGISTRATIONS reg
				where
					reg.PERSON_ID = icpc.person_id
					and
					reg.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(reg.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					convert(datetime, convert(varchar, reg.REGISTRATION_START_DATE, 103), 103) = icpc.conference_date
			) icpc_cp_plan_id,
			(
				select
					--max('Y')
					rfm.mapped_value
				from
					raw.mosaic_fw_report_filters rf
				inner join raw.mosaic_fw_report_filter_mappings rfm
				on rfm.REPORT_FILTER_ID = rf.id
				where
					rf.NAME = 'Child CIN Transfer In Conferences'
					and
					rfm.MAPPED_VALUE = cast(icpc.WORKFLOW_STEP_TYPE_ID as varchar(9))
			) icpc_icpc_transfer_in,
			(
				select
					(
						select
							min(t.thedate)
						from
							#dates t
						where
							t.running_working_day_number >= z.running_working_day_number + 15
					)
				from
					#dates z
				where
					z.THEDATE = icpc.conference_date
			) icpc_icpc_target_date,
			icpc.conference_date,
			ltrim(stuff((
				select
					distinct ', ' + nat.description
				from
					raw.mosaic_fw_mo_workflow_links lnk
				inner join raw.mosaic_fw_mo_workflow_steps nstp
				on nstp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				and
				nstp.STEP_STATUS not in ('PROPOSED', 'CANCELLED')
				inner join raw.mosaic_fw_mo_SUBGROUP_SUBJECTS nsgs
				on nsgs.SUBGROUP_ID = nstp.SUBGROUP_ID
				and
				nsgs.SUBJECT_TYPE_CODE = 'PER'
				inner join raw.mosaic_fw_mo_workflow_next_action_types nat
				on nat.WORKFLOW_NEXT_ACTION_TYPE_ID = lnk.WORKFLOW_NEXT_ACTION_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = icpc.WORKFLOW_STEP_ID
				order by 1
				for xml path('')),1,len(','),''
				)) icpc_next_actions,
			icpc.RESPONSIBLE_TEAM_ID,
			icpc.ASSIGNEE_ID
		from
			#initial_cp_conferences icpc
	) x
order by
	x.conference_date desc