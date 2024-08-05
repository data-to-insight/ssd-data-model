select
	distinct
	cla.LEGAL_STATUS_ID lega_legal_status_id,
	cla.PERSON_ID lega_person_id,
	cla.LEGAL_STATUS lega_legal_status,
	cla.LEGAL_STATUS_START lega_legal_status_start_date,
	cla.LEGAL_STATUS_END lega_legal_status_end_date
from
	SCF.Children_In_Care cla