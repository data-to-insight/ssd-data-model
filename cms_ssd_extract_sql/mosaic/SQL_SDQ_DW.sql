DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


/*Form Data*/
Select
a.FormID sdq_sdq_id, -- [REVIEW] should this be csdq_sdq_id - which has subsequently changed to csdq_table_id 
a.PersonID sdq_person_id,
CAST(a.DateOfAssessment as date) sdq_sdq_completed_date,
NULL sdq_sdq_reason,
a.TotalScore sdq_sdq_score

from Mosaic.F.SDQ a

where CAST(a.DateOfAssessment as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
and a.TotalScore is not null

UNION

/*Health Assessments Screen*/
Select
a.PERSON_HEALTH_INTERVENTION_ID sdq_sdq_id,
b.PERSON_ID sdq_person_id,
CAST(b.INTERVENTION_DATE as date) sdq_sdq_completed_date,
CASE
	when a.REASON = 'INVALID_AGE' then 'SDQ1'
	when a.REASON = 'CARER_REFUS_QUES' then 'SDQ2'
	when a.REASON = 'SEV_CHILD_DISAB' then 'SDQ3'
	when a.REASON = 'OTHER' then 'SDQ4'
	when a.REASON = 'COYRA' then 'SDQ5'
END sdq_sdq_reason,
a.SCORE sdq_sdq_score

from Mosaic.M.PERSON_HEALTH_INTERVENTION_SDQ a
inner join Mosaic.M.PERSON_HEALTH_INTERVENTIONS b on a.PERSON_HEALTH_INTERVENTION_ID = b.ID

where CAST(b.INTERVENTION_DATE as date) between DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME) and @STARTTIME

order by 2, 3