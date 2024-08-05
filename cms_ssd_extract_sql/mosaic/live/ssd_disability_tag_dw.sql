select
	dis.PERSON_ID disa_person_id,
	dis.DISABILITY_ID disa_table_id,
	dis.CIN_DISABILITY_CATEGORY_CODE disa_disability_code
from
	DM_DISABILITIES dis
where
	dis.CIN_DISABILITY_CATEGORY_CODE is not null