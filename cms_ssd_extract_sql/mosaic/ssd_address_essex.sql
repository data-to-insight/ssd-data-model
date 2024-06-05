select
	addr.REF_ADDRESSES_PEOPLE_ID addr_table_id,
	addr.address addr_address_json,
	addr.PERSON_ID add_person_id,
	addr.ADDRESS_TYPE addr_address_type,
	addr.START_DATE addr_address_start_date,
	addr.END_DATE addr_address_end_date,
	addr.post_code addr_address_postcode -- [REVIEW]
from
	raw.mosaic_fw_dm_addresses addr