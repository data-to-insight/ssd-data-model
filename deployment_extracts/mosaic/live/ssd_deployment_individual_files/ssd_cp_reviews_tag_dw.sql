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
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL
	DROP TABLE #ssd_cp_reviews
--
create table #ssd_cp_reviews (
	workflow_step_id						numeric(9),
	person_id								numeric(9),
	registration_id							numeric(9),
	due_date								datetime,
	actual_date								datetime,
	review_outcome							varchar(1000),
	quorate									varchar(64),
	review_participation					varchar(16),
	previous_conference_workflow_step_id	numeric(9),
	previous_conference_date				datetime,
	previous_conference_type				varchar(64),
	primary key (person_id, workflow_step_id)
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
inner join DM_SUBGROUP_SUBJECTS sgs
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
	sgs.subject_compound_id cppr_person_id,
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
inner join DM_SUBGROUP_SUBJECTS sgs
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
insert into #ssd_cp_reviews (
	workflow_step_id,
	person_id,
	registration_id,
	actual_date,
	review_outcome,
	quorate,
	review_participation
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
update #ssd_cp_reviews
set
	previous_conference_workflow_step_id = p.workflow_step_id,
	previous_conference_date = p.cp_conference_actual_date,
	previous_conference_type = p.conference_type,
	due_date =	case
					when p.conference_type = 'ICPC' then
						dateadd(dd,91,p.cp_conference_actual_date)
					when p.conference_type = 'RCPC' then
						dateadd(dd,183,p.cp_conference_actual_date)
				end
from	
	#all_cp_conferences p
where
	p.person_id = #ssd_cp_reviews.person_id
	and
	p.registration_id = #ssd_cp_reviews.registration_id
	and
	p.cp_conference_actual_date < #ssd_cp_reviews.actual_date
	and
	p.WEIGHTED_START_DATETIME = (
		select
			max(pp.WEIGHTED_START_DATETIME)
		from
			#all_cp_conferences pp
		where
			pp.person_id = #ssd_cp_reviews.person_id
			and
			pp.registration_id = #ssd_cp_reviews.registration_id
			and
			pp.cp_conference_actual_date < #ssd_cp_reviews.actual_date
	)
--
select
	r.workflow_step_id cppr_cp_review_id,
	r.person_id cppr_person_id,
	r.registration_id cppr_cp_plan_id,
	r.due_date cppr_cp_review_due,
	r.actual_date cppr_cp_review_date,
	r.review_outcome cppr_cp_review_outcome_continue_cp,
	r.quorate cppr_cp_review_quorate,
	r.review_participation cppr_cp_review_participation
from
	#ssd_cp_reviews r
order by
	actual_date desc