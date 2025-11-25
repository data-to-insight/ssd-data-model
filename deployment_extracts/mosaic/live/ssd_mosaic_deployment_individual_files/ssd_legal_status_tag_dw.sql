select
	leg.LEGAL_STATUS_ID lega_legal_status_id,
	leg.PERSON_ID lega_person_id,
	leg.LEGAL_STATUS lega_legal_status,
	leg.START_DATE lega_legal_status_start_date,
	leg.END_DATE lega_legal_status_end_date
from
	DM_LEGAL_STATUSES leg