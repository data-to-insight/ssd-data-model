declare @start_date datetime, @end_date datetime
set @start_date = '1 April 2022'
set @end_date = '31 March 2023'
--
declare @cin_plan_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
declare @step_down_to_eh_workflow_step_types table (
	workflow_step_type_id	numeric(9),
	description				varchar(1000)
)
--
--Insert workflow step types which are used to capture cin plans
insert into @cin_plan_workflow_step_types 
values
    (325,'Child or young person in need plan (CSSW)'),
    (369,'Child or young person in need plan (CSSW)'),
    (463, 'Child or young person in need plan (CSSW)')
--
--
IF OBJECT_ID('tempdb..#cin_periods_tmp') IS NOT NULL
    DROP TABLE #cin_periods_tmp
--
exec dbo.log_line @script, @step, 'Create temporary tables'
create table #cin_periods_tmp (
    cin_period_id				int,
    person_id					numeric(9),
    workflow_step_id			numeric(9),
    cin_start_date				datetime,
    cin_end_date				datetime,
    cin_plan_latest_step_id     numeric(9)
)
--
exec dbo.log_line @script, @step, 'Insert all CiN Periods into the temporary table'
insert into #cin_periods_tmp (
    cin_period_id,
    person_id,
    workflow_step_id,
    cin_start_date,
    cin_end_date,
    cin_plan_latest_step_id
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
                        dm_workflow_links l
                    inner join dm_workflow_steps l_ends
                    on l_ends.workflow_step_id = l.target_step_id
                    and
                    l_ends.step_status != 'CANCELLED'
                    inner join @cin_plan_workflow_step_types f
                    on f.workflow_step_type_id = l_ends.workflow_step_type_id
                    inner join dm_SUBGROUP_SUBJECTS l_sgs
                    on l_sgs.SUBGROUP_ID = l_ends.SUBGROUP_ID
                    and
                    l_sgs.SUBJECT_TYPE_CODE = 'PER'
                    where
                        l.source_step_id = s.workflow_step_id
                        and
                        l_sgs.subject_compound_id = sgs.subject_compound_id
                ) 
                and 
                s.step_status = 'COMPLETED' then
                dbo.no_time(s.completed_on)
            else
                (
                    select
                        min(dbo.no_time(ends.completed_on))
                    from
                        dm_workflow_forwards fwd
                    inner join dm_workflow_steps ends
                    on ends.workflow_step_id = fwd.subsequent_workflow_step_id
                    and
                    ends.step_status = 'COMPLETED'
                    inner join @cin_plan_workflow_step_types f
                    on f.workflow_step_type_id = ends.workflow_step_type_id
                    inner join dm_SUBGROUP_SUBJECTS l_sgs
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
                                dm_workflow_links l
                            inner join dm_workflow_steps l_ends
                            on l.target_step_id = l_ends.workflow_step_id
                            and
                            l_ends.step_status != 'CANCELLED'
                            inner join @cin_plan_workflow_step_types sfil
                            on sfil.workflow_step_type_id = l_ends.workflow_step_type_id
                            inner join dm_SUBGROUP_SUBJECTS l_sgs1
                            on l_sgs1.SUBGROUP_ID = l_ends.SUBGROUP_ID
                            and
                            l_sgs.SUBJECT_TYPE_CODE = 'PER'
                            where
                                l.source_step_id = ends.workflow_step_id
                                and
                                l_sgs1.subject_compound_id = sgs.subject_compound_id
                        )
                )
        end
    ) cin_end_date,
    (
        select 
            max(fw_stp.workflow_step_id)
        from 
            dm_workflow_forwards fw 
        inner join dm_workflow_steps_people_vw fw_stp 
        on fw_stp.workflow_step_id = fw.subsequent_workflow_step_id
        and 
        fw_stp.step_status != 'CANCELLED'
        inner join @cin_plan_workflow_step_types fw_t 
        on fw_t.workflow_step_type_id = fw_stp.workflow_step_type_id
        where
            fw.workflow_step_id = s.workflow_step_id
            and 
            fw_stp.person_id = sgs.subject_compound_id
    ) cin_plan_latest_step_id
from
    dm_workflow_steps s
inner join DM_SUBGROUP_SUBJECTS sgs
on sgs.SUBGROUP_ID = s.SUBGROUP_ID
and
sgs.SUBJECT_TYPE_CODE = 'PER'
inner join @cin_plan_workflow_step_types fil
on fil.workflow_step_type_id = s.workflow_step_type_id
where
    s.step_status not in ('CANCELLED', 'PROPOSED')
    and
    --CRITERIA: This CiN Plan did not come from another CiN Plan
    not exists (
        select
            1
        from
            dm_workflow_backwards bwd
        inner join dm_workflow_steps p_stp
        on p_stp.workflow_step_id = bwd.preceding_workflow_step_id
        and
        p_stp.step_status != 'CANCELLED'
        inner join @cin_plan_workflow_step_types pfil
        on pfil.workflow_step_type_id = p_stp.workflow_step_type_id
        where
            bwd.workflow_step_id = p_stp.workflow_step_id
            and
            bwd.adjacent = 'Y'
    )
--
exec dbo.log_line @script, @step, 'Where CiN Plan B starts in the middle CiN Plan A, change end date of CiN Plan A to match CiN Plan B'
update #cin_periods_tmp
set
    cin_end_date = (
                    select
                        (
                            select
                                min(rd.curr_day) -1
                            from
                                report_days rd
                            where
                                rd.curr_day > #cin_periods_tmp.cin_start_date
                                and
                                not exists (
                                    select
                                        1
                                    from
                                        #cin_periods_tmp x
                                    where
                                        x.person_id = #cin_periods_tmp.person_id
                                        and
                                        rd.curr_day between x.cin_start_date and dbo.future(x.cin_end_date)
                                )
                        )
                )
from
    #cin_periods_tmp
where
    exists (
        select
            1
        from
            #cin_periods_tmp t
        where
            t.person_id = #cin_periods_tmp.person_id
            and
            t.cin_start_date between #cin_periods_tmp.cin_start_date and dbo.future(#cin_periods_tmp.cin_end_date)
            and
            dbo.future(t.cin_end_date) > coalesce(#cin_periods_tmp.cin_end_date,'1 January 1900')
            and
            t.cin_period_id != #cin_periods_tmp.cin_period_id
    )
    --
--exec dbo.log_line @script, @step, 'Delete completely overlapped CiN Plans'
delete from #cin_periods_tmp
where
    exists (
        select
            1
        from
            #cin_periods_tmp z
        where
            z.person_id = #cin_periods_tmp.person_id
            and
            z.cin_start_date <= #cin_periods_tmp.cin_start_date
            and
            dbo.future(z.cin_end_date) >= dbo.future(#cin_periods_tmp.cin_end_date)
            and
            dbo.to_weighted_start(z.cin_start_date,z.cin_period_id) < dbo.to_weighted_start(#cin_periods_tmp.cin_start_date,#cin_periods_tmp.cin_period_id)
    )
SELECT
    x.cin_period_id cinp_cin_plan_id,
    (
        select
            max(ref.referral_id)
        from
            dm_CIN_REFERRALS ref
        where
            ref.PERSON_ID = x.PERSON_ID
            and
            ref.REFERRAL_DATE <= dbo.future(x.cin_end_date)
            and
            dbo.future(ref.CLOSURE_DATE) >= x.cin_start_date
    ) cinp_referral_id,
    x.person_id cinp_person_id,
    cin_start_date cinp_cin_plan_start_date,
    cin_end_date cinp_cin_plan_end_date,
    (
        SELECT
            s.responsible_team_id
        FROM
            dm_workflow_steps s
        WHERE
            s.workflow_step_id = x.cin_plan_latest_step_id
    ) cinp_cin_plan_team,
    (
        SELECT
            s.assignee_id
        FROM
            dm_workflow_steps s
        WHERE
            s.workflow_step_id = x.cin_plan_latest_step_id
    ) cinp_cin_plan_worker_id
FROM
    #cin_periods_tmp x