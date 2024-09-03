DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
NULL addr_table_id,
CASE 
	when
		LEN
		(
		COALESCE(LTRIM(RTRIM(COALESCE(p.PFlatNumber + ', ' + p.PStreetNumber, p.PStreetNumber, p.PFlatNumber))) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PBuilding)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PStreet)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PTown)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PPostcode)),'')
		) = 0 then NULL

	else
		COALESCE(LTRIM(RTRIM(COALESCE(p.PFlatNumber + ', ' + p.PStreetNumber, p.PStreetNumber, p.PFlatNumber))) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PBuilding)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PStreet)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PTown)) + ', ' ,'')
		+
		COALESCE(LTRIM(RTRIM(p.PPostcode)),'')
END addr_address_json,
--dbo.sfAddress_Full(COALESCE(p.PFlatNumber + ', ' + p.PStreetNumber, p.PStreetNumber, p.PFlatNumber),			
--			p.PBuilding, p.PStreet, p.PTown, p.PPostcode) addr_address_json,
p.PersonID addr_person_id,
NULL addr_address_type,
p.PAddrStartDate addr_address_start_date,
NULL addr_address_end_date,
p.PPostcode addr_address_postcode

from Mosaic.D.PersonData p

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

order by p.PersonID