select
	fact.ASSESSMENT_ID cinf_assessment_id,
	fact.FACTOR_VALUE cinf_assessment_factors_json
from
	dm_cin_assess_factors fact