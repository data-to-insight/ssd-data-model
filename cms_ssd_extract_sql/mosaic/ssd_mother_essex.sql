select
	NEWID() moth_table_id, -- [REVIEW] Gen new GUID, this in-lieu of a known key value (added 290424)
	rel.PERSON_ID moth_person_id,
	rel.PERSON_RELATED_TO_ID moth_childs_person_id,
	(
		select
			per.DATE_OF_BIRTH
		from
			raw.mosaic_fw_dm_persons per
		where
			per.PERSON_ID = rel.PERSON_RELATED_TO_ID
	) moth_childs_dob
from
	SCF.Personal_Relationships rel
where
	rel.[RELATIONSHIP_TYPE: PERSON_ID - OTHER_PERSON_ID] in (
		'Mother : Child',
		'Mother : Daughter',
		'Mother : Son',
		'Parent : Child',
		'Parent : Daughter',
		'Parent : Son'
	)