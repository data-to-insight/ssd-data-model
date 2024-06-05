select
	per.PERSON_ID pers_person_id,
	(
		select
			rd.ref_description
		from
			reference_data rd
		where
			rd.ref_domain = 'GENDER'
			and
			rd.ref_code = per.gender
	) pers_sex,
	(
		select
			rd.ref_description
		from
			mo_person_gender_identities gen
		inner join reference_data rd
		on rd.ref_code = gen.gender_code
		and
		rd.ref_domain = 'GENDER_IDENTITY'
		where
			gen.person_id = per.person_id
			and
			dbo.today() between gen.start_date and dbo.future(gen.end_date)
	) pers_gender,
	(
		select
			eth.ETHNICITY_DESCRIPTION
		from
			DM_ETHNICITIES eth
		where
			eth.ETHNICITY_CODE = per.FULL_ETHNICITY_CODE
	) pers_ethnicity,
	case
		when per.DATE_OF_BIRTH <= dbo.today() then
			per.DATE_OF_BIRTH
	end pers_dob,
	per.nhs_id pers_common_child_id,
	-- per.UPN_ID pers_upn, -- [depreciated] [REVIEW]
	null pers_upn_unknown,
	null pers_send_flag,
	case
		when per.DATE_OF_BIRTH > dbo.today() then
			per.DATE_OF_BIRTH
	end pers_expected_dob,
	per.DATE_OF_DEATH pers_death_date,
	case
		when per.GENDER = 'F' then
			(
				select
					max('Y')
				from
					DM_PERSONAL_RELATIONSHIPS rel
				where
					rel.PERSON_ID = per.PERSON_ID
					and
					rel.is_mother = 'Y'
					and
					dbo.today() between rel.START_DATE and dbo.future(rel.END_DATE)
			)
	end pers_is_mother,
	(
		select
			birt.DESCRIPTION
		from
			DM_COUNTRIES_OF_BIRTH birt
		where
			per.COUNTRY_OF_BIRTH_CODE = birt.COUNTRY_OF_BIRTH_CODE
	) pers_nationality
from
	dm_persons per