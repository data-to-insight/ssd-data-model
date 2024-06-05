select
	replace(replace(replace(convert(varchar, sdq.SDQ_DATE, 120), '-', ''), ' ', ''), ':', '') + '.' + replicate('0', 9 - len(cast(sdq.person_id as varchar(9)))) + cast(sdq.person_id as varchar(9)) csdq_table_id,
	sdq.PERSON_ID csdq_person_id,
	sdq.SDQ_DATE csdq_sdq_completed_date,
	sdq.SDQ_REASON csdq_sdq_reason,
	sdq.SDQ_SCORE csdq_sdq_score
from
	SCF.CIC_Health_Assessments sdq
where
	sdq.SDQ_DATE is not null