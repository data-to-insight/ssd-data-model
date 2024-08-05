DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
NEWID() moth_table_id, -- [REVIEW] Gen new GUID, this in-lieu of a known key value (added 290424)
p.PersonID moth_person_id,
r.RelTargetPerson moth_childs_person_id,
p2.PDoB moth_childs_dob

from Mosaic.D.PersonData p
left join Mosaic.D.Relationships r on p.PersonID = r.RelSourcePerson /*PW - will return any 'Mother - Child Relationship, may need to add criterea to show if child born while LAC or open to CSC*/
	and r.RelRelationship = 'is the mother of'
	and r.RelTo is null
left join Mosaic.D.PersonData p2 on r.RelTargetPerson = p2.PersonID

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

order by p.PersonID, p2.PersonID