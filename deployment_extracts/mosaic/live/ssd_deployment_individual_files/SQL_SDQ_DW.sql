DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


/*Form Data*/
/* naming standardised RH 241125 to avoid confusion/brittle future refactors */
select
    a.FormID                         as csdq_table_id,
    a.PersonID                       as csdq_person_id,
    cast(a.DateOfAssessment as date) as csdq_sdq_completed_date,
    null                             as csdq_sdq_reason,
    a.TotalScore                     as csdq_sdq_score

from Mosaic.F.SDQ a

where CAST(a.DateOfAssessment as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
and a.TotalScore is not null

UNION

/*Health Assessments Screen*/
Select
a.PERSON_HEALTH_INTERVENTION_ID csdq_table_id,
b.PERSON_ID csdq_person_id,
CAST(b.INTERVENTION_DATE as date) csdq_sdq_completed_date,
CASE
	when a.REASON = 'INVALID_AGE' then 'SDQ1'
	when a.REASON = 'CARER_REFUS_QUES' then 'SDQ2'
	when a.REASON = 'SEV_CHILD_DISAB' then 'SDQ3'
	when a.REASON = 'OTHER' then 'SDQ4'
	when a.REASON = 'COYRA' then 'SDQ5'
END csdq_sdq_reason,
a.SCORE csdq_sdq_score

from Mosaic.M.PERSON_HEALTH_INTERVENTION_SDQ a
inner join Mosaic.M.PERSON_HEALTH_INTERVENTIONS b on a.PERSON_HEALTH_INTERVENTION_ID = b.ID

where CAST(b.INTERVENTION_DATE as date) between DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME) and @STARTTIME

order by 2, 3