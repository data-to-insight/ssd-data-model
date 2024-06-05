with cp_conference_quorate_question_user_codes as (
    select 'question_user_code' question_user_code, 'Was CP conference quorate?' question_text from dual
    /*
    union all
    select ......
    */
),
--
cp_conference_participation_question_user_codes as (
    select 'question_user_code' question_user_code, 'How did child participate in conference?' question_text from dual
    /*
    union all
    select ......
    */
),
--
all_cp_conferences as (
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
)
--
select
	ssd_cp_reviews.workflow_step_id cppr_cp_review_id,
	ssd_cp_reviews.person_id cppr_person_id,
	ssd_cp_reviews.registration_id cppr_cp_plan_id,
	case
        when ssd_cp_reviews.previous_conference_type = 'ICPC' then
            dbo.days_add(ssd_cp_reviews.previous_conference_actual_date,91)
        when ssd_cp_reviews.previous_conference_type = 'RCPC' then
            dbo.days_add(ssd_cp_reviews.previous_conference_actual_date,183)
    end cppr_cp_review_due,
	ssd_cp_reviews.CP_CONFERENCE_ACTUAL_DATE cppr_cp_review_date,
	ssd_cp_reviews.review_outcome cppr_cp_review_outcome_continue_cp,
	ssd_cp_reviews.quorate cppr_cp_review_quorate,
	ssd_cp_reviews.review_participation cppr_cp_review_participation
from
    (
        select
            rev.workflow_step_id,
            rev.person_id,
            rev.registration_id,
            rev.CP_CONFERENCE_ACTUAL_DATE,
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
                inner join cp_conference_quorate_question_user_codes codes
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
                inner join cp_conference_participation_question_user_codes codes
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
            ) review_participation,
            (
                select
                    p.workflow_step_id
                from	
                    all_cp_conferences p
                where
                    p.person_id = rev.person_id
                    and
                    p.registration_id = rev.registration_id
                    and
                    p.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    and
                    p.WEIGHTED_START_DATETIME = (
                        select
                            max(pp.WEIGHTED_START_DATETIME)
                        from
                            all_cp_conferences pp
                        where
                            pp.person_id = rev.person_id
                            and
                            pp.registration_id = rev.registration_id
                            and
                            pp.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    )
            ) previous_conference_workflow_step_id,
            (
                select
                    p.CP_CONFERENCE_ACTUAL_DATE
                from	
                    all_cp_conferences p
                where
                    p.person_id = rev.person_id
                    and
                    p.registration_id = rev.registration_id
                    and
                    p.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    and
                    p.WEIGHTED_START_DATETIME = (
                        select
                            max(pp.WEIGHTED_START_DATETIME)
                        from
                            all_cp_conferences pp
                        where
                            pp.person_id = rev.person_id
                            and
                            pp.registration_id = rev.registration_id
                            and
                            pp.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    )
            ) previous_conference_actual_date,
            (
                select
                    p.conference_type
                from	
                    all_cp_conferences p
                where
                    p.person_id = rev.person_id
                    and
                    p.registration_id = rev.registration_id
                    and
                    p.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    and
                    p.WEIGHTED_START_DATETIME = (
                        select
                            max(pp.WEIGHTED_START_DATETIME)
                        from
                            all_cp_conferences pp
                        where
                            pp.person_id = rev.person_id
                            and
                            pp.registration_id = rev.registration_id
                            and
                            pp.cp_conference_actual_date < rev.CP_CONFERENCE_ACTUAL_DATE
                    )
            ) previous_conference_type            
        from
            all_cp_conferences rev
        where
            rev.conference_type = 'RCPC'
    ) ssd_cp_reviews