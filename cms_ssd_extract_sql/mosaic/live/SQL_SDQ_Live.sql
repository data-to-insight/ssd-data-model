DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


/*Form Data*/
Select
a.FORM_ID sdq_sdq_id, -- [REVIEW] should this be csdq_sdq_id - which has subsequently changed to csdq_table_id 
sg.ONLY_SUBJECT_COMPOUND_ID sdq_person_id,
CAST(fda.DATE_ANSWER as date) sdq_sdq_completed_date,
NULL sdq_sdq_reason,
fsta.SHORT_TEXT_ANSWER sdq_sdq_score

from moLive.dbo.MO_FORMS a
inner join moLive.dbo.MO_SUBGROUPS sg on a.SUBGROUP_ID = sg.SUBGROUP_ID
inner join moLive.dbo.MO_FORM_DATE_ANSWERS fda on a.FORM_ID = fda.FORM_ID
inner join moLive.dbo.MO_QUESTIONS q1 on fda.QUESTION_ID = q1.QUESTION_ID
	and q1.QUESTION_USER_CODE = 'lacFLDDateOfAssessment' /*QUESTION_ID - 40777*/
inner join moLive.dbo.MO_FORM_SHORT_TEXT_ANSWERS fsta on a.FORM_ID = fsta.FORM_ID
inner join moLive.dbo.MO_QUESTIONS q2 on fsta.QUESTION_ID = q2.QUESTION_ID
	and q2.QUESTION_USER_CODE = 'AllScore' /*QUESTION_ID - 40825*/

where CAST(fda.DATE_ANSWER as date) between DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME) and @STARTTIME

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

from moLive.dbo.PERSON_HEALTH_INTERVENTION_SDQ a
inner join moLive.dbo.PERSON_HEALTH_INTERVENTIONS b on a.PERSON_HEALTH_INTERVENTION_ID = b.ID

where CAST(b.INTERVENTION_DATE as date) between DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME) and @STARTTIME

order by 2, 3