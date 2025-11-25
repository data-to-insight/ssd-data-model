select
	'DT' + cast(dent.person_id as varchar(9)) + replace(replace(replace(convert(varchar, dent.DENTAL_CHECK_DATE, 120), '-', ''), ' ', ''), ':', '') clah_health_check_id,
	dent.PERSON_ID clah_person_id,
	'Dental Check' clah_health_check_type,
	dent.DENTAL_CHECK_DATE clah_health_check_date
from
	SCF.CIC_Health_Assessments dent
where
	dent.DENTAL_CHECK_DATE is not null
union all

select
	'HA' + cast(asst.person_id as varchar(9)) + replace(replace(replace(convert(varchar, asst.ASSESSMENT_DATE, 120), '-', ''), ' ', ''), ':', '') clah_health_check_id,
	asst.PERSON_ID clah_person_id,
	'Health Assessment' clah_health_check_type,
	asst.ASSESSMENT_DATE clah_health_check_date
from
	SCF.CIC_Health_Assessments asst
where
	asst.ASSESSMENT_DATE is not null
union all
select
	'HC' + cast(chk.person_id as varchar(9)) + replace(replace(replace(convert(varchar, chk.HEALTH_CHECK_DATE, 120), '-', ''), ' ', ''), ':', '') clah_health_check_id,
	chk.PERSON_ID clah_person_id,
	'Health Check' clah_health_check_type,
	chk.ASSESSMENT_DATE clah_health_check_date
from
	SCF.CIC_Health_Assessments chk
where
	chk.HEALTH_CHECK_DATE is not null