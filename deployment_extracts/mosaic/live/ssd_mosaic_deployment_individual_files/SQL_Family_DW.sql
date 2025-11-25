DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
d.fami_family_id,
d.fami_person_id
--d.GroupName,
--d.GroupDesc

From

(
	Select
	g.GroupID fami_family_id,
	g.SubjectID fami_person_id,
	--CASE
	--	when g.GroupName is not null then g.GroupName
	--	when g.SubGroupSoleSubject is not null then p.PForename + ' - ' + p.PSurname
	--END GroupName,
	--g.GroupDesc GroupDesc,
	DENSE_RANK() OVER(PARTITION BY g.SubjectID ORDER BY (CASE when g.SubGroupSoleSubject is null then 1 else 2 END), g.GroupID DESC, g.SubGroupID DESC) Rnk

	from Mosaic.D.Groups g
	inner join Mosaic.D.PersonData p on g.SubjectID = p.PersonID

	where COALESCE(g.GroupName,'zzz') not like '%Duplicate%'
	and COALESCE(g.GroupName,'zzz') not like '%Do not use%'
)
d

where d.Rnk = 1
and (EXISTS
(
	/*CIN Period in last x@yrs*/
	Select a.PersonID from ChildrensReports.D.CINPeriods a
	where a.PersonID = d.fami_person_id
	and a.CINPeriodEnd >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
)
or EXISTS
(
	/*Contact in last x@yrs*/
	Select a.PersonID
	from ChildrensReports.ICS.Contacts a
	where a.PersonID = d.fami_person_id
	and a.StartDate >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
))

order by d.fami_family_id, d.fami_person_id