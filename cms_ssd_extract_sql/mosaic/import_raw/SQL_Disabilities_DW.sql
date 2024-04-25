DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
p.PersonID disa_person_id,
d.ID disa_table_id,
COALESCE(x.CINCODE,'NONE') disa_disability_code

from Mosaic.D.PersonData p
left join Mosaic.M.PERSON_CONDITIONS_DISABILITIES d on p.PersonID = d.PERSON_ID
left join RETURNS.CIN.LkupDisabilityXref x on d.CODE = x.DisCode
	and x.CINCode <> 'NONE'

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

/*Remove spurious 'NONE'*/	/*PW - would run quicker if deleting from a temporary table*/
and not 
(
	p.PersonID in
	(
		Select
		d.PERSON_ID

		from
		(
			Select
			d.PERSON_ID,
			COALESCE(x.CINCODE,'NONE') CINCode

			from Mosaic.M.PERSON_CONDITIONS_DISABILITIES d
			left join RETURNS.CIN.LkupDisabilityXref x on d.CODE = x.DisCode
				and x.CINCode <> 'NONE'
		)
		d

		group by d.PERSON_ID

		having SUM(CASE WHEN CINCode <> 'NONE' THEN 1 ELSE 0 END) >= 1
		and SUM(CASE WHEN CINCode = 'NONE' THEN 1 ELSE 0 END) >= 1
	)
	and COALESCE(x.CINCODE,'NONE') = 'NONE'
)

order by p.PersonID