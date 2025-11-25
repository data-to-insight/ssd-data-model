select
	hlth.HEALTH_ID csdq_sdq_id,
	hlth.PERSON_ID csdq_person_id,
	hlth.HEALTH_ASSESSMENT_DATE csdq_sdq_completed_date,
	hlth.SDQ_REASON csdq_sdq_reason,
	hlth.SDQ_SCORE
from
	DM_HEALTH_ASSESSMENTS hlth
where
	hlth.SDQ_COMPLETED = 'Y'
	or
	hlth.sdq_reason is not null