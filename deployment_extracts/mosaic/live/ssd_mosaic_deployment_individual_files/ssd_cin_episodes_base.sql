/******DECLARE VARIABLES******/
declare @number_of_years_to_include int
set @number_of_years_to_include = 1
--
--Visits
declare @visit_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @visit_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
--S17 Assessments
declare @assessment_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @assessment_start_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @assessment_end_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
--Initial CP Conferences
declare @icpc_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @icpc_conf_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
--S47 Enquiries
declare @s47_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @s47_start_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @s47_end_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
--Strategy Discussions
declare @strategy_discussion_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @strategy_discussion_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @child_in_need_plan_review_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
--Contacts and Referrals
declare @contact_referral_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @contact_referral_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @contact_referral_accepted_next_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
--Closures
declare @closure_workflow_step_types table (
	workflow_step_type_id			numeric(9),
	description						varchar(1000)
)
--
declare @closure_date_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @closure_reason_question_user_codes table (
	question_user_code				varchar(128),
	question_text					varchar(1000)
)
--
declare @closure_reason_categories table (
	closure_reason				varchar(128),
	closure_reason_category		varchar(1000)
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
/******CONFIGURE SCRIPT FOR LOCAL BUILD******/
--Insert the exact wording of answers which indicate the child was seen during assessment
insert into @visit_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Date of visit')
	--,(<additional value>, <additional value>)
--
--Insert the exact wording of answers which indicate the child was seen during assessment
insert into @visit_workflow_step_types
values
	(3, 'Visit')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture assessments
insert into @assessment_workflow_step_types 
values
	(3, 'C+F Assessment')
	--,(<additional value>, <additional value>)
--
insert into @assessment_start_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment start date')
	--,(<additional value>, <additional value>)
--
insert into @assessment_end_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment end date')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture assessments
insert into @icpc_workflow_step_types 
values
	(3, 'ICPC')
	--,(<additional value>, <additional value>)
--
insert into @icpc_conf_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Date of ICPC')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture assessments
insert into @s47_workflow_step_types 
values
	(3, 'C+F Assessment')
	--,(<additional value>, <additional value>)
--
insert into @s47_start_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment start date')
	--,(<additional value>, <additional value>)
--
insert into @s47_end_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Assessment end date')
	--,(<additional value>, <additional value>)
--
--Insert workflow step types which are used to capture assessments
insert into @strategy_discussion_workflow_step_types 
values
	(3, 'Strategy Discussion')
	--,(<additional value>, <additional value>)
--
insert into @strategy_discussion_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Date of Strategy Discussion')
	--,(<additional value>, <additional value>)
--
insert into @child_in_need_plan_review_workflow_step_types 
values 
	(3, 'Child in Need Plan')
	--,(<additional value>, <additional value>)
--
--Contacts and Referrals
insert into @contact_referral_workflow_step_types 
values
	(3, 'Contact + Referral')
	--,(<additional value>, <additional value>)
--
insert into @contact_referral_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Date of Contact')
	--,(<additional value>, <additional value>)
--
insert into @contact_referral_accepted_next_workflow_step_types
values
	(3, 'Child and Family Assessment')
	--,(<additional value>, <additional value>)
--
insert into @closure_workflow_step_types
values
	(3, 'Closure')
	--,(<additional value>, <additional value>)
--
insert into @closure_date_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Closure Date')
	--,(<additional value>, <additional value>)
--
insert into @closure_reason_question_user_codes
values
	('df65gv4dfg-54dfgd54g-dgdf4g5d','Reason for closure')
	--,(<additional value>, <additional value>)
--
insert into @closure_reason_categories
values
	('Adopted', 'RC1 - Adopted'),
	('Died', 'RC2 - Died'),
	('Child arrangement order', 'RC3 - Child arrangements order'),
	('RC3 - Residence Order', 'RC3 - Child arrangements order'),
	('Special Guardianship order', 'RC4 - Special Guardianship Order'),
	('Transferred to services of another LA', 'RC5 - Transferred to services of another LA'),
	('Transferred to adult social services', 'RC6 - Transferred to Adult Social Services'),
	('Services ceased for any other reason, including child no longer in need', 'RC7 - Services ceased for any other reason, including child no longer in need'),
	('Case closed after assessment, no further action', 'RC8 - Case closed after assessment, no further action'),
	('RC9 - Case closed after assessment, referred to early help', 'RC9 - Case closed after assessment, referred to early help')
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
	MO_FORM_DATE_ANSWERS dates
inner join dbo.MO_QUESTIONS que 
on que.QUESTION_ID = dates.QUESTION_ID
inner join MO_FORMS frm
on frm.FORM_ID = dates.FORM_ID
inner join MO_WORKFLOW_STEPS stp 
on stp.WORKFLOW_STEP_ID = frm.WORKFLOW_STEP_ID
inner join mo_form_answer_rows r
on r.form_answer_row_id = dates.form_answer_row_id
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	que.QUESTION_USER_CODE in (
		select q.question_user_code from @visit_date_question_user_codes q
		union
		select q.question_user_code from @assessment_start_date_question_user_codes q
		union
		select q.question_user_code from @assessment_end_date_question_user_codes q
		union
		select q.question_user_code from @icpc_conf_date_question_user_codes q
		union
		select q.question_user_code from @s47_start_date_question_user_codes q
		union
		select q.question_user_code from @s47_end_date_question_user_codes q
		union
		select q.question_user_code from @strategy_discussion_date_question_user_codes q
		union
		select q.question_user_code from @contact_referral_date_question_user_codes q
		union
		select q.question_user_code from @closure_reason_question_user_codes q
	)

	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		select s.workflow_step_type_id from @visit_workflow_step_types s
		union
		select s.workflow_step_type_id from @assessment_workflow_step_types s
		union
		select s.workflow_step_type_id from @icpc_workflow_step_types s
		union
		select s.workflow_step_type_id from @s47_workflow_step_types s
		union
		select s.workflow_step_type_id from @strategy_discussion_workflow_step_types s		
		union
		select s.workflow_step_type_id from @contact_referral_workflow_step_types s
		union
		select s.workflow_step_type_id from @closure_workflow_step_types s		
	)
--
if object_id('tempdb..#lookup_answers') is not null
	drop table #lookup_answers
--
select
	stp.workflow_step_id,
	answ.FORM_ANSWER_ROW_ID,
	q.QUESTION_USER_CODE,
	lkp.ANSWER lookup_answer,
	case
		when r.handler_row_identifier is not null and r.handler_row_identifier != '' then
			r.HANDLER_ROW_IDENTIFIER
		else
			sgs.SUBJECT_COMPOUND_ID
	end person_id
into
	#lookup_answers
from
	mo_form_lookup_answers answ
--JOIN: find the form details
inner join mo_forms forms
on forms.form_id = answ.form_id
--JOIN: find the template used
inner join mo_templates temp
on temp.template_id = forms.template_id
--JOIN: find the question version
inner join mo_questions q
on q.question_id = answ.question_id
--JOIN: find the lookup text for the answer
inner join mo_question_lookups lkp
on lkp.question_lookup_id = answ.question_lookup_id
--JOIN: Find the step
inner join mo_workflow_steps stp
on stp.workflow_step_id = forms.workflow_step_id
inner join mo_form_answer_rows r
on r.form_answer_row_id = answ.form_answer_row_id
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = stp.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
where
	q.QUESTION_USER_CODE in (
		select q.question_user_code from @closure_reason_question_user_codes q
	)
	and
	stp.WORKFLOW_STEP_TYPE_ID in (
		select s.workflow_step_type_id from @closure_workflow_step_types s
	)
--
if object_id('tempdb..#visits') is not null
	drop table #visits
--
select
	sgs.subject_compound_id person_id,
	vis.WORKFLOW_STEP_ID,
	dbo.no_time(coalesce(
		(
			select
				max(ans.date_answer)
			from
				#date_answers ans
			inner join @visit_date_question_user_codes q
			on q.question_user_code = ans.question_user_code
			where
				ans.workflow_step_id = vis.workflow_step_id
				and
				ans.person_id = sgs.subject_compound_id
		),
		vis.started_on
	)) visit_date
into
	#visits
from
	mo_workflow_steps vis
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = vis.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
inner join @visit_workflow_step_types t
on t.workflow_step_type_id = vis.workflow_step_type_id
where
	vis.STEP_STATUS = 'COMPLETED'
--
--'Populate assessments table'
if object_id('tempdb..#assessments') is not null
	drop table #assessments
--
select
	*
into
	#assessments	
from
	(
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			asst.WORKFLOW_STEP_ID,
			asst.workflow_step_type_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @assessment_start_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = asst.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when asst.step_status in ('STARTED', 'REOPENED', 'COMPLETED') then
						dbo.no_time(asst.started_on)
				end,
				case
					when asst.step_status = 'INCOMING' then
						dbo.no_time(asst.incoming_on)
				end
			) assessment_start_date,
			case
				when asst.step_status = 'COMPLETED' then
					coalesce(
						(
							select
								max(ans.date_answer)
							from
								#date_answers ans
							inner join @assessment_end_date_question_user_codes q
							on q.question_user_code = ans.question_user_code
							where
								ans.workflow_step_id = asst.workflow_step_id
								and
								ans.person_id = sgs.subject_compound_id
						),
						dbo.no_time(asst.completed_on)
					)
			end assessment_end_date,
			asst.step_status,
			case
				when asst.STEP_STATUS = 'INCOMING' then
					'Y'
				else
					'N'
			end is_incoming,
			case
				when asst.STEP_STATUS in ('STARTED', 'REOPENED') then
					'Y'
				else
					'N'
			end is_open,
			case
				when asst.STEP_STATUS = 'COMPLETED' then
					'Y'
				else
					'N'
			end is_completed
		from
			mo_workflow_steps asst
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.subgroup_id = asst.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @assessment_workflow_step_types t
		on t.workflow_step_type_id = asst.workflow_step_type_id
		where
			asst.STEP_STATUS not in ('CANCELLED', 'PROPOSED')
	) x
where
	x.STEP_STATUS in ('INCOMING', 'STARTED', 'REOPENED')
	or
	(
		x.assessment_end_date >= dateadd(yy,-@number_of_years_to_include,dbo.today()) 
		and
		x.assessment_start_date <= dbo.today() 
	)
--
--'Populate ICPCs table'
if object_id('tempdb..#initial_cp_conferences') is not null
	drop table #initial_cp_conferences
--
select
	*
into
	#initial_cp_conferences
from
	(
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			icpc.WORKFLOW_STEP_ID,
			icpc.workflow_step_type_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @icpc_conf_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = icpc.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when icpc.step_status = 'COMPLETED' then
						dbo.no_time(icpc.completed_on)
				end
			) conference_date,
			icpc.STEP_STATUS,
			case
				when icpc.STEP_STATUS = 'INCOMING' then
					'Y'
				else
					'N'
			end is_incoming,
			case
				when icpc.STEP_STATUS in ('STARTED', 'REOPENED') then
					'Y'
				else
					'N'
			end is_open,
			case
				when icpc.STEP_STATUS = 'COMPLETED' then
					'Y'
				else
					'N'
			end is_completed
		from
			mo_workflow_steps icpc
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.subgroup_id = icpc.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @icpc_workflow_step_types t
		on t.workflow_step_type_id = icpc.WORKFLOW_STEP_TYPE_ID
		where
			icpc.STEP_STATUS != 'CANCELLED'
	) x
where
	x.step_status in ('INCOMING', 'STARTED', 'REOPENED')
	or
	(
		x.conference_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
	)
--
--'Populate S47 table'
if object_id('tempdb..#section_47_enquiries') is not null
	drop table #section_47_enquiries
--
select
	*
into
	#section_47_enquiries
from
	(
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			s47.WORKFLOW_STEP_ID,
			s47.workflow_step_type_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @s47_start_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = s47.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when s47.step_status in ('STARTED', 'REOPENED', 'COMPLETED') then
						dbo.no_time(s47.started_on)
				end
			) section_47_start_date,
			coalesce((
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @s47_end_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = s47.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when s47.step_status = 'COMPLETED' then
						dbo.no_time(s47.completed_on)
				end
			) section_47_end_date,
			s47.STEP_STATUS,
			case
				when s47.STEP_STATUS = 'INCOMING' then
					'Y'
				else
					'N'
			end is_incoming,
			case
				when s47.STEP_STATUS in ('STARTED', 'REOPENED') then
					'Y'
				else
					'N'
			end is_open,
			case
				when s47.STEP_STATUS = 'COMPLETED' then
					'Y'
				else
					'N'
			end is_completed
		from
			mo_workflow_steps s47
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.subgroup_id = s47.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @s47_workflow_step_types t
		on t.workflow_step_type_id = s47.WORKFLOW_STEP_TYPE_ID
		where
			s47.STEP_STATUS != 'CANCELLED'
	) x
where
	x.step_status in ('INCOMING', 'STARTED', 'REOPENED')
	or
	(
		x.section_47_end_date >= dateadd(yy,-@number_of_years_to_include,dbo.today()) 
		and
		x.section_47_start_date <= dbo.today() 
	)
--
--'Populate Strategy Discussions table'
if object_id('tempdb..#strategy_discussions') is not null
	drop table #strategy_discussions
--
select
	*
into
	#strategy_discussions
from
	(
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			sd.WORKFLOW_STEP_ID,
			sd.workflow_step_type_id,
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
				case
					when sd.step_status = 'COMPLETED' then
						dbo.no_time(sd.completed_on)
				end
			) strategy_discussion_date,
			sd.STEP_STATUS,
			case
				when sd.STEP_STATUS = 'INCOMING' then
					'Y'
				else
					'N'
			end is_incoming,
			case
				when sd.STEP_STATUS in ('STARTED', 'REOPENED') then
					'Y'
				else
					'N'
			end is_open,
			case
				when sd.STEP_STATUS = 'COMPLETED' then
					'Y'
				else
					'N'
			end is_completed
		from
			mo_workflow_steps sd
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.subgroup_id = sd.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @strategy_discussion_workflow_step_types t
		on t.workflow_step_type_id = sd.WORKFLOW_STEP_TYPE_ID
		where
			sd.STEP_STATUS != 'CANCELLED'
	) x
where
	x.step_status in ('INCOMING', 'STARTED', 'REOPENED')
	or
	(
		x.strategy_discussion_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today())
--
if object_id('tempdb..#cin_periods') is not null
	drop table #cin_periods
--
create table #cin_periods (
	cin_period_id				int,
	person_id					numeric(9),
	workflow_step_id			numeric(9),
	cin_start_date				datetime,
	cin_end_date				datetime
)
--
--'Insert all CiN Periods into the temporary table'
insert into #cin_periods (
	cin_period_id,
	person_id,
	workflow_step_id,
	cin_start_date,
	cin_end_date
)
select
	row_number() over (order by sgs.SUBJECT_COMPOUND_ID, s.workflow_step_id) cin_period_id,
	sgs.SUBJECT_COMPOUND_ID person_id,
	s.workflow_step_id,
	case
		when s.started_on < s.INCOMING_ON then 
			dbo.no_time(s.started_on)
		else
			dbo.no_time(s.incoming_on)
	end cin_start_date,
	dbo.no_time(
		case
			when not exists (
					select
						1
					from
						dm_workflow_forwards fwd
					inner join mo_workflow_steps l_ends
					on l_ends.workflow_step_id = fwd.SUBSEQUENT_WORKFLOW_STEP_ID
					and
					l_ends.step_status != 'CANCELLED'
					inner join @child_in_need_plan_review_workflow_step_types lt
					on lt.workflow_step_type_id = l_ends.WORKFLOW_STEP_TYPE_ID
					inner join MO_SUBGROUP_SUBJECTS l_sgs
					on l_sgs.SUBGROUP_ID = l_ends.SUBGROUP_ID
					and
					l_sgs.SUBJECT_TYPE_CODE = 'PER'
					where
						fwd.WORKFLOW_STEP_ID = s.workflow_step_id
						and
						l_sgs.subject_compound_id = sgs.subject_compound_id
				) and s.step_status = 'COMPLETED' then
				dbo.no_time(s.completed_on)
			else
				(
					select
						min(dbo.no_time(ends.completed_on))
					from
						dm_workflow_forwards fwd
					inner join mo_workflow_steps ends
					on ends.workflow_step_id = fwd.subsequent_workflow_step_id
					and
					ends.step_status = 'COMPLETED'
					inner join @child_in_need_plan_review_workflow_step_types et
					on et.workflow_step_type_id = ends.WORKFLOW_STEP_TYPE_ID
					inner join MO_SUBGROUP_SUBJECTS l_sgs
					on l_sgs.SUBGROUP_ID = ends.SUBGROUP_ID
					and
					l_sgs.SUBJECT_TYPE_CODE = 'PER'
					where
						fwd.workflow_step_id = s.workflow_step_id
						and
						l_sgs.subject_compound_id = sgs.subject_compound_id
						and
						not exists (
							select
								1
							from
								dm_workflow_forwards fwd
							inner join mo_workflow_steps l_ends
							on l_ends.workflow_step_id = fwd.subsequent_workflow_step_id
							and
							l_ends.step_status != 'CANCELLED'
							inner join @child_in_need_plan_review_workflow_step_types lt
							on lt.workflow_step_type_id = l_ends.WORKFLOW_STEP_TYPE_ID
							inner join MO_SUBGROUP_SUBJECTS l_sgs1
							on l_sgs1.SUBGROUP_ID = l_ends.SUBGROUP_ID
							and
							l_sgs.SUBJECT_TYPE_CODE = 'PER'
							where
								fwd.WORKFLOW_STEP_ID = ends.workflow_step_id
								and
								l_sgs1.subject_compound_id = sgs.subject_compound_id
								and
								fwd.adjacent = 'Y'							
						)
				)
		end
	) cin_end_date
from
	mo_workflow_steps s
inner join MO_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = s.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
inner join @child_in_need_plan_review_workflow_step_types t
on t.workflow_step_type_id = s.WORKFLOW_STEP_TYPE_ID
where
	s.step_status not in ('CANCELLED', 'PROPOSED')
	and
	--CRITERIA: This CiN Plan Review did not come from another CiN Plan Review
	not exists (
		select
			1
		from
			dm_workflow_backwards bwd
		inner join mo_workflow_steps p_stp
		on p_stp.workflow_step_id = bwd.preceding_workflow_step_id
		and
		p_stp.step_status != 'CANCELLED'
		inner join @child_in_need_plan_review_workflow_step_types pt
		on pt.workflow_step_type_id = s.WORKFLOW_STEP_TYPE_ID
		where
			bwd.workflow_step_id = s.workflow_step_id
			and
			bwd.adjacent = 'Y'
	)
--
--'Where CiN Plan B starts in the middle CiN Plan A, change end date of CiN Plan A to match CiN Plan B'
update #cin_periods
set
	cin_end_date = (
					select
						(
							select
								min(rd.curr_day) -1
							from
								report_days rd
							where
								rd.curr_day > #cin_periods.cin_start_date
								and
								not exists (
									select
										1
									from
										#cin_periods x
									where
										x.person_id = #cin_periods.person_id
										and
										rd.curr_day between x.cin_start_date and dbo.future(x.cin_end_date)
								)
						)
				)
from
	#cin_periods
where
	exists (
		select
			1
		from
			#cin_periods t
		where
			t.person_id = #cin_periods.person_id
			and
			t.cin_start_date between #cin_periods.cin_start_date and dbo.future(#cin_periods.cin_end_date)
			and
			dbo.future(t.cin_end_date) > coalesce(#cin_periods.cin_end_date,'1 January 1900')
			and
			t.cin_period_id != #cin_periods.cin_period_id
	)
	--
--'Delete completely overlapped CiN Plans'
delete from #cin_periods
where
	exists (
		select
			1
		from
			#cin_periods z
		where
			z.person_id = #cin_periods.person_id
			and
			z.cin_start_date <= #cin_periods.cin_start_date
			and
			dbo.future(z.cin_end_date) >= dbo.future(#cin_periods.cin_end_date)
			and
			dbo.to_weighted_start(z.cin_start_date,z.cin_period_id) < dbo.to_weighted_start(#cin_periods.cin_start_date,#cin_periods.cin_period_id)
	)
--
if object_id('tempdb..#contact_referral_processes') is not null
	drop table #contact_referral_processes
--
--Insert all referrals to temp table
select
	x.person_id,
	x.contact_workflow_step_id,
	x.referral_date,
	dbo.to_weighted_start(x.referral_date,x.contact_workflow_step_id) weighted_start
into
	#contact_referral_processes
from
	(
		--Recorded using workflow after go live
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			ref.WORKFLOW_STEP_ID contact_workflow_step_id,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @contact_referral_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = ref.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when ref.step_status = 'COMPLETED' then
						dbo.no_time(ref.completed_on)
				end
			) referral_date
		from
			mo_workflow_steps ref
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = ref.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @contact_referral_workflow_step_types t
		on t.workflow_step_type_id = ref.WORKFLOW_STEP_TYPE_ID
		where
			exists (
				select
					1
				from
					mo_workflow_links lnk
				inner join mo_workflow_steps n_stp
				on n_stp.WORKFLOW_STEP_ID = lnk.TARGET_STEP_ID
				inner join MO_SUBGROUP_SUBJECTS n_sgs
				on n_sgs.SUBGROUP_ID = n_stp.SUBGROUP_ID
				and
				n_sgs.SUBJECT_TYPE_CODE = 'PER'
				and
				n_stp.STEP_STATUS != 'CANCELLED'
				inner join @contact_referral_accepted_next_workflow_step_types t
				on t.workflow_step_type_id = n_stp.WORKFLOW_STEP_TYPE_ID
				where
					lnk.SOURCE_STEP_ID = ref.WORKFLOW_STEP_ID
					and
					n_sgs.SUBJECT_COMPOUND_ID = sgs.SUBJECT_COMPOUND_ID
			)
	) x
--
if object_id('tempdb..#closures') is not null
	drop table #closures
--
--Insert closures into temporary table
select
	x.person_id,
	x.closure_workflow_step_id,
	x.closure_date,
	x.closure_reason closure_reason_ungrouped,
	(
		select
			reas.closure_reason_category
		from
			@closure_reason_categories reas
		where
			reas.closure_reason = x.closure_reason
	) closure_reason,
	dbo.to_weighted_start(x.closure_date,x.closure_workflow_step_id) weighted_start,
	x.STEP_STATUS,
	case
		when x.STEP_STATUS = 'INCOMING' then
			'Y'
		else
			'N'
	end is_incoming,
	case
		when x.STEP_STATUS in ('STARTED', 'REOPENED') then
			'Y'
		else
			'N'
	end is_open,
	case
		when x.STEP_STATUS = 'COMPLETED' then
			'Y'
		else
			'N'
	end is_completed
into
	#closures
from
	(
		select
			sgs.SUBJECT_COMPOUND_ID person_id,
			clo.WORKFLOW_STEP_ID closure_workflow_step_id,
			clo.step_status,
			coalesce(
				(
					select
						max(ans.date_answer)
					from
						#date_answers ans
					inner join @closure_date_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = clo.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
				),
				case
					when clo.step_status = 'COMPLETED' then
						dbo.no_time(clo.completed_on)
				end
			) closure_date,
			(
					select
						max(ans.lookup_answer)
					from
						#lookup_answers ans
					inner join @closure_reason_question_user_codes q
					on q.question_user_code = ans.question_user_code
					where
						ans.workflow_step_id = clo.workflow_step_id
						and
						ans.person_id = sgs.subject_compound_id
			) closure_reason
		from
			mo_workflow_steps clo
		inner join MO_SUBGROUP_SUBJECTS sgs
		on sgs.SUBGROUP_ID = clo.SUBGROUP_ID
		and
		sgs.SUBJECT_TYPE_CODE = 'PER'
		inner join @closure_workflow_step_types t
		on t.workflow_step_type_id = clo.WORKFLOW_STEP_TYPE_ID
	) x
--
--'Create temporary table for cohort';
IF OBJECT_ID('tempdb..#cohort_tmp') IS NOT NULL
	DROP TABLE #cohort_tmp
--
create table #cohort_tmp (
	person_id							numeric(9),
	referral_date						datetime,
	referral_workflow_step_id			numeric(9),
	case_status							varchar(64),
	latest_relevant_activity_date		datetime,
	closure_date						datetime,
	closure_workflow_step_id			numeric(9),
	closure_reason						varchar(500)
)
--
--'Populate temporary table with cohort';
insert into #cohort_tmp (
	person_id,
	case_status
)
select
	peo.person_id,
	case
		when exists (
				select
					1
				from
					DM_PERIODS_OF_CARE cla
				where
					cla.person_id = peo.person_id
					and
					dbo.today() between cla.START_DATE and dbo.future(cla.end_date)
			) then
			'a) Looked after child'
		when exists (
				select
					1
				from
					DM_REGISTRATIONS cp
				where
					cp.person_id = peo.person_id	
					and
					cp.IS_CHILD_PROTECTION_PLAN = 'Y'
					and
					coalesce(cp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					and
					dbo.today() between cp.REGISTRATION_START_DATE and dbo.future(cp.DEREGISTRATION_DATE)
			) then
			'b) Child Protection plan'
		when exists (
				select
					1
				from
					#cin_periods cin
				where
					cin.person_id = peo.person_id
					and
					dbo.today() between cin.cin_start_date and dbo.future(cin.cin_end_date)
			) then
			'c) Child in need plan'
		when exists (
				select
					1
				from
					#closures clos
				where
					'Y' in (clos.is_open, clos.is_incoming)
					and
					clos.person_id = peo.person_id
			) then
			'c) Child in need plan'
		when exists (
				select
					1
				from
					#assessments asst
				where
					'Y' in (asst.is_open, asst.is_incoming)
					and
					asst.person_id = peo.person_id
				union all
				select
					1
				from 
					#initial_cp_conferences icpc 
				where 
					'Y' in (icpc.is_open, icpc.is_incoming)
					and
					icpc.person_id = peo.person_id
				union all
				select
					1
				from
					#section_47_enquiries asst
				where			
					'Y' in (asst.is_open, asst.is_incoming)
					and
					asst.person_id = peo.person_id
				union all
				select
					1
				from
					#strategy_discussions sd
				where
					'Y' in (sd.is_open, sd.is_incoming)
					and
					sd.person_id = peo.person_id
			) then
			'd) Open assessment'
		else
			'e) Closed episode'
	end case_status
from 
	dm_persons peo
where
	exists (
		--CLA
		select
			1
		from
			DM_PERIODS_OF_CARE cla
		where
			cla.person_id = peo.person_id
			and
			cla.start_date <= dbo.today()
			and
			dbo.future(cla.end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
		union all
		--CP
		select
			1
		from
			DM_REGISTRATIONS cp
		where
			cp.person_id = peo.person_id	
			and
			cp.REGISTRATION_START_DATE <= dbo.today()
			and
			dbo.future(cp.DEREGISTRATION_DATE) >= dateadd(yy,-@number_of_years_to_include,dbo.today()) 
			and
			cp.IS_CHILD_PROTECTION_PLAN = 'Y'
			and
			coalesce(cp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
		union all
		--Local CiN definition
		select 
			1
		from
			#cin_periods cin
		WHERE  
			cin.person_id = peo.person_id
			and
			cin.cin_start_date <= dbo.today()
			and
			dbo.future(cin.cin_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
		union all
		--open assessment
		select
			1
		from
			#assessments asst
		where
			'Y' in (asst.is_open, asst.is_incoming)
			and
			asst.person_id = peo.person_id
		union all
		--completed assessment
		select
			1
		from
			#assessments asst
		where
			asst.is_completed = 'Y'
			and
			asst.assessment_end_date >= dateadd(yy,-@number_of_years_to_include,dbo.today())
			and
			asst.assessment_start_date <= dbo.today() 
			and
			asst.person_id = peo.person_id
		union all
		--Open ICPC
		select
			1
		from 
			#initial_cp_conferences icpc 
		where 
			'Y' in (icpc.is_open, icpc.is_incoming)
			and
			icpc.person_id = peo.person_id
		union all
		--Completed ICPC
		select
			1
		from 
			#initial_cp_conferences icpc 
		where 
			icpc.is_completed = 'Y'
			and
			icpc.person_id = peo.person_id
			and
			icpc.conference_date >= dateadd(yy,-@number_of_years_to_include,dbo.today())
			and
			icpc.conference_date <= dbo.today() 
		union all
		--Open S47 assessment
		select
			1
		from
			#section_47_enquiries asst
		where			
			'Y' in (asst.is_open, asst.is_incoming)
			and
			asst.person_id = peo.person_id
		union all
		--Completed S47 assessment
		select
			1
		from
			#section_47_enquiries asst
		where		
			asst.is_completed = 'Y'
			and
			asst.section_47_end_date >= dateadd(yy,-@number_of_years_to_include,dbo.today())
			and
			asst.section_47_start_date <= dbo.today() 
			and
			asst.person_id = peo.person_id
		union all
		--Active Strategy Discussion
		select
			1
		from
			#strategy_discussions sd
		where
			'Y' in (sd.is_open, sd.is_incoming)
			and
			sd.person_id = peo.person_id
		union all
		--Completed Strategy Discussion
		select
			1
		from
			#strategy_discussions sd
		where
			sd.person_id = peo.person_id
			and
			sd.strategy_discussion_date >= dateadd(yy,-@number_of_years_to_include,dbo.today()) 
			and
			sd.strategy_discussion_date <= dbo.today() 
	)
		--
		--'Set latest relevant activity date field';
		update #cohort_tmp
		set latest_relevant_activity_date = (
			select
				max(x.end_date)
			from
				(
					select
						dbo.future(cla.end_date) end_date
					from
						dm_periods_of_care cla
					where
						cla.person_id = #cohort_tmp.person_id
						and
						cla.start_date <= dbo.today()
						and
						dbo.future(cla.end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					--CP
					select
						dbo.future(cp.DEREGISTRATION_DATE)
					from
						DM_REGISTRATIONS cp
					where
						cp.person_id = #cohort_tmp.person_id
						and	
						cp.REGISTRATION_START_DATE <= dbo.today()
						and
						dbo.future(cp.DEREGISTRATION_DATE) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
						and
						cp.IS_CHILD_PROTECTION_PLAN = 'Y'
						and
						coalesce(cp.IS_TEMPORARY_CHILD_PROTECTION,'N') = 'N'
					union all
					select
						dbo.future(cin.cin_end_date) end_date
					from
						#cin_periods cin
					where
						cin.person_id = #cohort_tmp.person_id
						and
						cin.cin_start_date <= dbo.today()
						and
						dbo.future(cin.cin_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						dbo.future(ast.assessment_end_date) end_date
					from
						#assessments ast
					where
						ast.person_id = #cohort_tmp.person_id
						and
						ast.assessment_start_date <= dbo.today()
						and
						dbo.future(ast.assessment_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						icpc.conference_date end_date
					from
						#initial_cp_conferences icpc
					where
						icpc.person_id = #cohort_tmp.person_id
						and
						icpc.conference_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
					union all
					select
						dbo.future(s47.section_47_end_date) end_date
					from
						#section_47_enquiries s47
					where
						s47.person_id = #cohort_tmp.person_id
						and
						s47.section_47_start_date <= dbo.today()
						and
						dbo.future(s47.section_47_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						sd.strategy_discussion_date end_date
					from
						#strategy_discussions sd
					where
						sd.person_id = #cohort_tmp.person_id
						and
						sd.strategy_discussion_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
				) x
		)
		--
		--'Set referral date in temporary table, from real referrals';
		update #cohort_tmp
		set
			referral_date = (
					select
						dbo.no_time(con.referral_date)
					from
						#contact_referral_processes con
					where
						con.person_id = #cohort_tmp.person_id
						and
						con.referral_date <= dbo.today()
						and
						not exists (
							select
								1
							from
								#closures clo
							where
								clo.person_id = #cohort_tmp.person_id
								and
								clo.closure_date >= dbo.no_time(con.referral_date) 
								and 
								clo.closure_date < #cohort_tmp.latest_relevant_activity_date
						)
						and
						dbo.to_weighted_start(con.referral_date,con.contact_workflow_step_id) = (
							select
								max(dbo.to_weighted_start(lcon.referral_date,lcon.contact_workflow_step_id))
							from
								#contact_referral_processes lcon
							where
								lcon.person_id = #cohort_tmp.person_id
								and
								lcon.referral_date <= dbo.today()
								and
								not exists (
									select
										1
									from
										#closures lclo
									where
										lclo.person_id = #cohort_tmp.person_id
										and
										lclo.closure_date >= dbo.no_time(con.referral_date) 
										and 
										lclo.closure_date < #cohort_tmp.latest_relevant_activity_date
								)
						)
				),
			referral_workflow_step_id = (
					select
						con.contact_workflow_step_id
					from
						#contact_referral_processes con
					where
						con.person_id = #cohort_tmp.person_id
						and
						con.referral_date <= dbo.today()
						and
						not exists (
							select
								1
							from
								#closures clo
							where
								clo.person_id = #cohort_tmp.person_id
								and
								clo.closure_date >= dbo.no_time(con.referral_date) 
								and 
								clo.closure_date < #cohort_tmp.latest_relevant_activity_date
						)
						and
						dbo.to_weighted_start(con.referral_date,con.contact_workflow_step_id) = (
							select
								max(dbo.to_weighted_start(lcon.referral_date,lcon.contact_workflow_step_id))
							from
								#contact_referral_processes lcon
							where
								lcon.person_id = #cohort_tmp.person_id
								and
								lcon.referral_date <= dbo.today()
								and
								not exists (
									select
										1
									from
										#closures lclo
									where
										lclo.person_id = #cohort_tmp.person_id
										and
										lclo.closure_date >= dbo.no_time(con.referral_date) 
										and 
										lclo.closure_date < #cohort_tmp.latest_relevant_activity_date
								)
						)
				)
		--
		--'Set referral date in temporary table, based on events in the period, where a real referral is missing';
		update #cohort_tmp
		set referral_date = (
			select
				min(x.start_date)
			from
				(
					select
						cla.start_date
					from
						dm_periods_of_care cla
					where
						cla.person_id = #cohort_tmp.person_id
						and
						cla.start_date <= dbo.today()
						and
						dbo.future(cla.end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						cpp.REGISTRATION_START_DATE
					from
						DM_REGISTRATIONS cpp
					where
						cpp.person_id = #cohort_tmp.person_id
						and
						cpp.IS_CHILD_PROTECTION_PLAN = 'Y'
						and
						coalesce(cpp.is_temporary_child_protection,'N') = 'N'
						and
						cpp.REGISTRATION_START_DATE <= dbo.today()
						and
						dbo.future(cpp.DEREGISTRATION_DATE) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						cin.cin_start_date
					from
						#cin_periods cin
					where
						cin.person_id = #cohort_tmp.person_id
						and
						cin.cin_start_date <= dbo.today()
						and
						dbo.future(cin.cin_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						ast.assessment_start_date
					from
						#assessments ast
					where
						ast.person_id = #cohort_tmp.person_id
						and
						ast.assessment_start_date <= dbo.today()
						and
						dbo.future(ast.assessment_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						icpc.conference_date
					from
						#initial_cp_conferences icpc
					where
						icpc.person_id = #cohort_tmp.person_id
						and
						icpc.conference_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
					union all
					select
						s47.section_47_start_date
					from
						#section_47_enquiries s47
					where
						s47.person_id = #cohort_tmp.person_id
						and
						s47.section_47_start_date <= dbo.today()
						and
						dbo.future(s47.section_47_end_date) >= dateadd(yy,-@number_of_years_to_include,dbo.today())
					union all
					select
						sd.strategy_discussion_date
					from
						#strategy_discussions sd
					where
						sd.person_id = #cohort_tmp.person_id
						and
						sd.strategy_discussion_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
				) x
		)
		where
			referral_date is null
		--
		--'Set closure details in temporary table from real closures';
		update #cohort_tmp
		set	closure_date = 	(
				select
					dbo.no_time(clo.closure_date)
				from
					#closures clo
				where
					clo.person_id = #cohort_tmp.person_id
					and
					clo.closure_date >= #cohort_tmp.referral_date
					and
					--CRITERIA: We know that there was some activity in the period, so if there is no longer activity the closure could ONLY have occurred in the last period
					clo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
					and
					dbo.to_weighted_start(clo.closure_date,clo.closure_workflow_step_id) = (
						select
							min(dbo.to_weighted_start(lclo.closure_date,lclo.closure_workflow_step_id))
						from
							#closures lclo
						where
							lclo.person_id = #cohort_tmp.person_id
							and
							lclo.closure_date >= #cohort_tmp.referral_date
							and
							lclo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
					)
			),
			closure_workflow_step_id = 
						(
							select
								clo.closure_workflow_step_id
							from
								#closures clo
							where
								clo.person_id = #cohort_tmp.person_id
								and
								clo.closure_date >= #cohort_tmp.referral_date
								and
								clo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
								and
								dbo.to_weighted_start(clo.closure_date,clo.closure_workflow_step_id) = (
									select
										min(dbo.to_weighted_start(lclo.closure_date,lclo.closure_workflow_step_id))
									from
										#closures lclo
									where
										lclo.person_id = #cohort_tmp.person_id
										and
										lclo.closure_date >= #cohort_tmp.referral_date
										and
										lclo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
								)
						),
			closure_reason = 
						(
							select
								clo.closure_reason
							from
								#closures clo
							where
								clo.person_id = #cohort_tmp.person_id
								and
								clo.closure_date >= #cohort_tmp.referral_date
								and
								clo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
								and
								dbo.to_weighted_start(clo.closure_date,clo.closure_workflow_step_id) = (
									select
										max(dbo.to_weighted_start(lclo.closure_date,lclo.closure_workflow_step_id))
									from
										#closures lclo
									where
										lclo.person_id = #cohort_tmp.person_id
										and
										lclo.closure_date >= #cohort_tmp.referral_date
										and
										lclo.closure_date between dateadd(yy,-@number_of_years_to_include,dbo.today()) and dbo.today()
								)
						)
		where
			#cohort_tmp.case_status = 'e) Closed episode'
		--
		--'Where episode is closed, but no closure has been found, use the end date of the last plan/assessment in the episode';
		update #cohort_tmp
		set	closure_date = coalesce((
			select
				max(dbo.no_time(c.end_date))
			from
				(
					--CLA
					select
						lcla.end_date end_date
					from
						dm_periods_of_care lcla
					where
						lcla.person_id = #cohort_tmp.person_id
						and
						lcla.end_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
					union all
					--CP
					select
						lcp.deregistration_date end_date
					from
						dm_registrations lcp
					where
						lcp.person_id = #cohort_tmp.person_id
						and
						lcp.is_child_protection_plan = 'Y'
						and
						coalesce(lcp.is_temporary_child_protection,'N') = 'N'
						and
						lcp.deregistration_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
					union all
					--CiN
					select 
						l_local_cin.cin_end_date
					from
						#cin_periods l_local_cin
					where 
						#cohort_tmp.person_id = l_local_cin.person_id
						and
						l_local_cin.cin_end_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
					union all
					--Assessments
					select
						s17.assessment_end_date
					from
						#assessments s17
					where
						s17.person_id = #cohort_tmp.person_id
						and
						s17.is_completed = 'Y'
						and
						s17.assessment_end_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
					union all
					select
						s47.section_47_end_date
					from
						#section_47_enquiries s47
					where
						s47.person_id = #cohort_tmp.person_id
						and
						s47.is_completed = 'Y'
						and
						s47.section_47_end_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
					union all
					select
						sd.strategy_discussion_date
					from
						#strategy_discussions sd
					where
						sd.person_id = #cohort_tmp.person_id
						and
						sd.strategy_discussion_date between #cohort_tmp.referral_date and coalesce(
							(
								select
									min(con.referral_date)
								from
									#contact_referral_processes con
								where
									con.person_id = #cohort_tmp.person_id
									and
									dbo.no_time(con.referral_date) > dbo.no_time(#cohort_tmp.referral_date)
							),
							dbo.today()
						)
				) c
			),#cohort_tmp.referral_date)
		where
			#cohort_tmp.closure_date is null
			and
			#cohort_tmp.case_status = 'e) Closed episode'
		--
		--'Where an episode is open, but the person has turned 18, set the 18th birthday as the end date';
		update #cohort_tmp
		set closure_date = (
				select 
					dateadd(yy,18,px.date_of_birth) calc_end_date 
				from 
					dm_persons px
				where 
					px.person_id = #cohort_tmp.person_id
			),
			case_status = 'e) Closed episode'
		where
			--CRITERIA: The case is open
			case_status != 'e) Closed episode'
			and
			--CRITERIA: The person has turned 18
			(
				select 
					dateadd(yy,18,px.date_of_birth) calc_end_date 
				from 
					DM_PERSONS px 
				where 
					px.person_id = #cohort_tmp.person_id
			) <= dbo.today()
		--
		--'Where a plan has ended but after 18th birthday, set 18th birthday as end date';
		update #cohort_tmp
		set closure_date = (select dateadd(yy,18,coalesce(px.date_of_birth,'1 January 2300')) calc_end_date from DM_PERSONS px where px.person_id = #cohort_tmp.person_id)
		where
			closure_date is not null
			and
			closure_date > (select dateadd(yy,18,coalesce(px.date_of_birth,'1 January 2300')) calc_end_date from DM_PERSONS px where px.person_id = #cohort_tmp.person_id);
		--
		--'Where closure dates have been updated, remove those that now do not fall in the period';
		delete from #cohort_tmp
		where
			closure_date is not null
			and 
			closure_date < dateadd(yy,-1,dbo.today());
		--
		--'Where person''s referral started after their 18th birthday, remove it';
		delete from #cohort_tmp
		where
			referral_date >= (select dateadd(yy,18,coalesce(px.date_of_birth,'1 January 2300')) calc_end_date from DM_PERSONS px where px.person_id = #cohort_tmp.person_id);
		--
		--'Set closure reason to ''Other'' where it is blank'
		update #cohort_tmp
		set 
			closure_reason = 'RC7 - Services ceased for any other reason, including child no longer in need'
		where
			closure_date is not null
			and
			closure_reason is null
		--
		select
			t.person_id,
			dbo.f_get_person_name(t.person_id) full_name,
			t.referral_date,
			t.closure_date,
			t.case_status,
			t.closure_reason
		from
			#cohort_tmp t