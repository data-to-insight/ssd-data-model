SELECT person_Lambeth.la_person_id,
       person_Lambeth.person_sex_Lambeth,
       person_Lambeth.person_gender_Lambeth,
       person_Lambeth.person_ethnicity,
       person_Lambeth.person_dob,
       person_Lambeth.person_upn,
       person_Lambeth.person_upn_unknown,
       person_Lambeth.person_send,
       person_Lambeth.person_expected_dob,
       person_Lambeth.person_death_date,
       person_Lambeth.person_is_mother,
       person_Lambeth.person_nationality,
       family.family_id,
       family.la_person_id,
       address_Lambeth.address,
       address_Lambeth.la_person_id,
       address_Lambeth.address_type_Lambeth,
       address_Lambeth.address_start,
       address_Lambeth.address_end,
       address_Lambeth.address_postcode_Lambeth,
       disability.la_person_id,
       disability.person_disability
FROM person
INNER JOIN family ON person.la_person_id = family.la_person_id
INNER JOIN address ON person.la_person_id = address.la_person_id
INNER JOIN disability ON person.la_person_id = disability.la_person_id
WHERE entry_date >= ADD_MONTHS(SYSDATE, -6*12);