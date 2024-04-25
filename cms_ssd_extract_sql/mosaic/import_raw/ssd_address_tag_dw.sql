select
	addr.REF_ADDRESSES_PEOPLE_ID addr_table_id,
	addr.ADDRESS addr_address_json,
	addr.PERSON_ID addr_person_id,
	addr.ADDRESS_TYPE addr_address_type,
	addr.START_DATE addr_address_start_date,
	addr.END_DATE addr_address_end_date,
	addr.POST_CODE addr_address_postcode
from
	DM_ADDRESSES addr