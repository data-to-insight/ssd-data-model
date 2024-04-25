select
	pref.REFERENCE_ID link_link_id,
	pref.PERSON_ID link_person_id,
	pref.REFERENCE_TYPE link_identifier_type,
	pref.REFERENCE link_identifier_value,
	null link_valid_from_date,
	null link_valid_to_date

from
	dm_person_references pref