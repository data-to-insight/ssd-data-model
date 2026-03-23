select
	o.offence_id clac_cla_conviction_id
	,o.person_id clac_person_id
    CAST(o.offence_date AS date)     AS clac_cla_conviction_date,
    CAST(NULL AS VARCHAR(1000))      AS clac_cla_conviction_offence

from 
	dm_offences o
where 
	o.is_convicted = 'Y'
