DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
d.addr_table_id,
d.addr_address_json,
d.addr_person_id,
d.addr_address_type,
d.addr_address_start_date,
d.addr_address_end_date,
d.addr_address_postcode

from
(
	Select
	ap.ADDRESS_ID addr_table_id,
	CASE 
		when
			LEN
			(
			COALESCE(LTRIM(RTRIM(COALESCE(a.FLAT_NUMBER + ', ' + a.STREET_NUMBER, a.STREET_NUMBER, a.FLAT_NUMBER))) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.BUILDING)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.STREET)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.TOWN)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.POST_CODE)),'')
			) = 0 then NULL

		else
			COALESCE(LTRIM(RTRIM(COALESCE(a.FLAT_NUMBER + ', ' + a.STREET_NUMBER, a.STREET_NUMBER, a.FLAT_NUMBER))) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.BUILDING)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.STREET)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.TOWN)) + ', ' ,'')
			+
			COALESCE(LTRIM(RTRIM(a.POST_CODE)),'')
	END addr_address_json,
	p.PersonID addr_person_id,
	ap.ADDRESS_TYPE addr_address_type,
	CAST(ap.START_DATE as date) addr_address_start_date,
	CAST(ap.END_DATE as date) addr_address_end_date,
	a.POST_CODE addr_address_postcode,
	ap.CONTACT_ADDRESS,
	ap.DISPLAY_ADDRESS,
	DENSE_RANK() OVER(PARTITION BY p.PersonID ORDER BY ap.CONTACT_ADDRESS DESC, ap.DISPLAY_ADDRESS desc, ap.START_DATE DESC, COALESCE(ap.END_DATE, '99991231') DESC, ap.ID DESC) Rnk

	from Mosaic.D.PersonData p
	left join Mosaic.M.ADDRESSES_PEOPLE ap on p.PersonID = ap.PERSON_ID
		and ap.ADDRESS_TYPE IN('MAIN','PLACEMENT')
	left join Mosaic.M.ADDRESSES a on ap.ADDRESS_ID = a.ID
		and	COALESCE(a.Street,'') NOT IN('NOT FOUND','UNKNOWN','NO FIXED ABODE')

	where (EXISTS
	(
		/*Contact in last x@yrs*/
		Select a.PersonID
		from ChildrensReports.ICS.Contacts a
		where a.PersonID = p.PersonID
		and a.StartDate >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
	)
	or EXISTS
	(
		/*LAC Legal Status in last x@yrs*/
		Select a.PERSON_ID from Mosaic.M.PERSON_LEGAL_STATUSES a
		where a.PERSON_ID = p.PersonID
		and COALESCE(a.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
	)
	or EXISTS
	(
		/*CIN Period in last x@yrs*/
		Select a.PersonID from ChildrensReports.D.CINPeriods a
		where a.PersonID = p.PersonID
		and a.CINPeriodEnd >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
	)
	)
)
d

where d.Rnk = 1

order by d.addr_person_id