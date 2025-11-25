select
	dbo.append2('DT', cast(dent.person_id as varchar(9)), cast(dent.DENTAL_ID as varchar(9))) clah_health_check_id,
	dent.PERSON_ID clah_person_id,
	'Dental Check' clah_health_check_type,
	dent.DENTAL_CHECK_DATE clah_health_check_date
from
	DM_DENTAL_CHECKS dent
where
	dent.DENTAL_CHECK_DATE is not null

union all

select
	dbo.append2('HA' , cast(asst.person_id as varchar(9)) , cast(asst.HEALTH_ID as varchar(9))) clah_health_check_id,
	asst.PERSON_ID clah_person_id,
	'Health Assessment' clah_health_check_type,
	asst.HEALTH_ASSESSMENT_DATE clah_health_check_date
from
	DM_HEALTH_ASSESSMENTS asst
where
	asst.HEALTH_ASSESSMENT_DATE is not null
	and
	asst.SDQ_COMPLETED = 'N'
union all
select
	dbo.append2('HC', cast(chk.person_id as varchar(9)), cast(chk.HEALTH_CHECK_ID as varchar(9))) clah_health_check_id,
	chk.PERSON_ID clah_person_id,
	'Health Check' clah_health_check_type,
	chk.HEALTH_CHECK_DATE clah_health_check_date
from
	DM_HEALTH_CHECKS chk
where
	chk.HEALTH_CHECK_DATE is not null