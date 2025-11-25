select
	NEWID() moth_table_id, -- Gen new GUID, this in-lieu of a known key value (added 290424)
	pr.PERSON_ID moth_person_id,
	pr.OTHER_PERSON_ID moth_childs_person_id,
	(
		select
			peo.date_of_birth
		from
			dm_persons peo
		where
			peo.PERSON_ID = pr.OTHER_PERSON_ID
	) moth_childs_dob
from
	DM_PERSONAL_RELATIONSHIPS pr
where
	pr.IS_MOTHER = 'Y'