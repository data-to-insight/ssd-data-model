select
	per.PERSON_ID per_person_id,
	per.GENDER pers_gender,
	per.FULL_ETHNICITY_CODE pers_ethnicity,
	case
		when per.date_of_birth <= convert(datetime, convert(varchar, getdate(), 103), 103)  then
			per.date_of_birth
	end pers_dob,
	per.NHS_ID pers_common_child_id,
	-- per.UPN_ID pers_upn, -- [depreciated] [REVIEW]
	null pers_upn_unknown,
	null pers_send_flag,
	case
		when per.date_of_birth > convert(datetime, convert(varchar, getdate(), 103), 103)  then
			per.date_of_birth
	end pers_expected_dob,
	per.date_of_death,
	case
		when per.GENDER = 'F' then
			(
				select
					max('Y')
				from
					SCF.Personal_Relationships rel
				where
					rel.PERSON_ID = per.PERSON_ID
					and
					rel.[RELATIONSHIP_TYPE: PERSON_ID - OTHER_PERSON_ID] in (
						'Mother : Child',
						'Mother : Daughter',
						'Mother : Son',
						'Parent : Child',
						'Parent : Daughter',
						'Parent : Son'
					)
			)
	end pers_is_mother,
	per.country_of_birth_code,
	(
		select
			rd.REF_DESCRIPTION
		from
			raw.mosaic_fw_reference_data rd
		where
			rd.REF_CODE = per.country_of_birth_code
			and
			rd.REF_DOMAIN = 'COUNTRY'
	) pers_nationality
from
	raw.mosaic_fw_dm_persons per