DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select distinct
p.PersonID pers_person_id,
p.Sex pers_sex,
p.pGender pers_gender,
COALESCE(ec.CINCode,'NOBT') pers_ethnicity,
p.PDoB pers_dob,
p.PNHSNumber pers_common_child_id,
-- p.PUniquePupilNumber pers_upn, -- [depreciated] [REVIEW]
NULL pers_upn_unknown,
CASE when ehcp.PersonID is not null then 'Y' END pers_send_flag,
p.PDoBEstimated pers_expected_dob,
p.PDoD pers_death_date,
Case when r.RelSourcePerson is not null then 'Y' END pers_is_mother,
NULL pers_nationality

from Mosaic.D.PersonData p
left join Mosaic.DS.EthnicityConversion ec on p.pEthnicityCode = ec.SubEthnicityCode
left join EMS.D.INVOLVEMENTS_EHCP ehcp on p.PEMSNumber = ehcp.PersonID
	and EHCPCompleteDate is not null /*PW - Will give EHCP / SEN Statement ever, may need to add date criteria to show current or within reporting period*/
left join Mosaic.D.Relationships r on p.PersonID = r.RelSourcePerson /*PW - will return 'Y' if any 'Mother - Child Relationship, may need to add criterea to show if child born while LAC or open to CSC*/
	and r.RelRelationship = 'is the mother of'
	and r.RelTo is null

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