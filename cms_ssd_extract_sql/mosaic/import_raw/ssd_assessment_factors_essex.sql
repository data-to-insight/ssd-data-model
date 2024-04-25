declare @number_of_years_to_include int
set @number_of_years_to_include = 1
--
select
	asst.PERSON_ASSESSMENT_ID cinf_assessment_id,
	af.ASSESSMENT_FACTOR_CODE cinf_assessment_factors_json
from
	SCF.Assessment_Factors af
inner join SCF.Assessments asst
on asst.PERSON_ASSESSMENT_ID = af.PERSON_ASSESSMENT_ID
where
	asst.DATE_ASSESSMENT_STARTED <= cast(cast(getdate() as date) as datetime)
	and
	coalesce(asst.ASSESSMENT_AUTHORISED_DATE,'1 January 2300') >= dateadd(yy,-@number_of_years_to_include,cast(cast(getdate() as date) as datetime))