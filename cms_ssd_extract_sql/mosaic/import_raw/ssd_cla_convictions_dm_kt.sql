select
	o.offence_id clac_cla_conviction_id
	,o.person_id clac_person_id
	,cast(o.offence_date as date) clac_cla_conviction_date
from 
	dm_offences o
where 
	o.is_convicted = 'Y'
