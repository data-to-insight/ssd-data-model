DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
a.ID lega_legal_status_id,
a.PERSON_ID lega_person_id,
a.LEGAL_STATUS lega_legal_status,
a.START_DATE lega_legal_status_start_date,
a.END_DATE lega_legal_status_end_date

from Mosaic.M.PERSON_LEGAL_STATUSES a

where COALESCE(a.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)

order by a.START_DATE, a.PERSON_ID