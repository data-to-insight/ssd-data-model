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
	p.PERSON_ID addr_person_id,
	ap.ADDRESS_TYPE addr_address_type,
	CAST(ap.START_DATE as date) addr_address_start_date,
	CAST(ap.END_DATE as date) addr_address_end_date,
	a.POST_CODE addr_address_postcode,
	ap.CONTACT_ADDRESS,
	ap.DISPLAY_ADDRESS,
	DENSE_RANK() OVER(PARTITION BY p.PERSON_ID ORDER BY ap.CONTACT_ADDRESS DESC, ap.DISPLAY_ADDRESS desc, ap.START_DATE DESC, COALESCE(ap.END_DATE, '99991231') DESC, ap.ID DESC) Rnk

	from moLive.dbo.MO_PERSONS p
	left join moLive.dbo.ADDRESSES_PEOPLE ap on p.PERSON_ID = ap.PERSON_ID
		and ap.ADDRESS_TYPE IN('MAIN','PLACEMENT')
	left join moLive.dbo.ADDRESSES a on ap.ADDRESS_ID = a.ID
		and	COALESCE(a.Street,'') NOT IN('NOT FOUND','UNKNOWN','NO FIXED ABODE')

	where (EXISTS
	(
		/*Contact in last x@yrs*/
		Select s.SUBJECT_COMPOUND_ID 
		from MoLive.dbo.MO_WORKFLOW_STEPS ws
		inner join moLive.dbo.MO_SUBGROUP_SUBJECTS s on ws.SUBGROUP_ID = s.SUBGROUP_ID
		inner join moLive.dbo.MO_FORMS f on ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
		inner join moLive.dbo.MO_FORM_DATE_ANSWERS fa on f.FORM_ID = fa.FORM_ID
		where s.SUBJECT_COMPOUND_ID = p.PERSON_ID
		and ws.WORKFLOW_STEP_TYPE_ID in (335,344) /*335 - Contact/Referral; 344 - EDT Contact/Referral*/
		and CAST(fa.DATE_ANSWER as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
	)
	or EXISTS
	(
		/*LAC Legal Status in last x@yrs*/
		Select a.PERSON_ID from moLive.dbo.PERSON_LEGAL_STATUSES a
		where a.PERSON_ID = p.PERSON_ID
		and COALESCE(a.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
	)
	)
)
d

where d.Rnk = 1

order by d.addr_person_id