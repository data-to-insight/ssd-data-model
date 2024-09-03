USE PLACEHOLDER_DB_NAME;


SELECT person_eastsussex.la_person_id,
       person_eastsussex.person_sex_eastsussex,
       person_eastsussex.person_gender_eastsussex,
       person_eastsussex.person_ethnicity,
       person_eastsussex.person_dob,
       person_eastsussex.person_upn,
       person_eastsussex.person_upn_unknown,
       person_eastsussex.person_send,
       person_eastsussex.person_expected_dob,
       person_eastsussex.person_death_date,
       person_eastsussex.person_is_mother,
       person_eastsussex.person_nationality,
       family.family_id,
       family.la_person_id,
       address_eastsussex.address,
       address_eastsussex.la_person_id,
       address_eastsussex.address_type_eastsussex,
       address_eastsussex.address_start,
       address_eastsussex.address_end,
       address_eastsussex.address_postcode_eastsussex,
       disability.la_person_id,
       disability.person_disability
FROM person
INNER JOIN family ON person.la_person_id = family.la_person_id
INNER JOIN address ON person.la_person_id = address.la_person_id
INNER JOIN disability ON person.la_person_id = disability.la_person_id
WHERE entry_date >= DATEADD(YEAR, -6, GETDATE());