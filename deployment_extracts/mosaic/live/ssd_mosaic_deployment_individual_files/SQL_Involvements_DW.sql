DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
pw.ID invo_involvements_id,
pw.PERSON_ID PersonID,
pw.WORKER_ID invo_professional_id, /*PW - Do we want HCPC Identifier where available? (available in Blackpool Data Warehouse but not in Live Mosaic Database*/
prt.DESCRIPTION invo_professional_role_id, /*PW - Allocation Description Provided, should this be Worker Role Description as per Professionals Table?*/
org.NAME invo_professional_team,
NULL invo_referral_id,
CAST(pw.START_DATE as date) invo_involvement_start_date,
CAST(pw.END_DATE as date) invo_involvement_end_date,
pw.START_DATE_REASON invo_worker_change_reason

from Mosaic.M.PEOPLE_WORKERS pw
inner join Mosaic.M.PROF_RELATIONSHIP_TYPES prt on pw.TYPE = prt.REL_TYPE
inner join Mosaic.M.WORKER_ROLES wr on pw.WORKER_ID = wr.WORKER_ID
	and wr.PRIMARY_JOB = 'Y'
	and wr.START_DATE <= pw.START_DATE
	and COALESCE(wr.END_DATE, '99991231') >= pw.START_DATE
	and COALESCE(pw.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
inner join Mosaic.M.ORGANISATIONS org on wr.ORG_ID = org.ID

where pw.TYPE = 'ALLWKR'
and COALESCE(CAST(pw.START_DATE as date),'99991231') <> COALESCE(CAST(pw.END_DATE as date),'99991231')
and wr.ORG_ID in
/*Get current Teams within 'Children's Social Care' in Mosaic Organisation Hierarchy
	PW - Issue that this doesn't pick up some archived teams*/
(
	Select d.OHLevel1ID

	from
	(
		Select
		o1.ID OHLevel1ID,
		o1.NAME OHLevel1Name,
		o2.ID OHLevel2ID,
		o2.NAME OHLevel2Name,
		o3.ID OHLevel3ID,
		o3.NAME OHLevel3Name,
		o4.ID OHLevel4ID,
		o4.NAME OHLevel4Name,
		o5.ID OHLevel5ID,
		o5.NAME OHLevel5Name,
		o6.id OHLevel6ID,
		o6.Name OHLevel6Name,
		o7.id OHLevel7ID,
		o7.Name OHLevel7Name

		from Mosaic.M.ORGANISATIONS o1
		left join Mosaic.M.ORGANISATION_STRUCTURE os1 on o1.id = os1.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o2 on os1.PARENT_ORG_ID = o2.id
		left join Mosaic.M.ORGANISATION_STRUCTURE os2 on o2.id = os2.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o3 on os2.PARENT_ORG_ID = o3.id
		left join Mosaic.M.ORGANISATION_STRUCTURE os3 on o3.id = os3.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o4 on os3.PARENT_ORG_ID = o4.id
		left join Mosaic.M.ORGANISATION_STRUCTURE os4 on o4.id = os4.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o5 on os4.PARENT_ORG_ID = o5.id
		left join Mosaic.M.ORGANISATION_STRUCTURE os5 on o5.id = os5.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o6 on os5.PARENT_ORG_ID = o6.id
		left join Mosaic.M.ORGANISATION_STRUCTURE os6 on o6.id = os6.CHILD_ORG_ID
		left join Mosaic.M.ORGANISATIONS o7 on os6.PARENT_ORG_ID = o7.id

		where o1.ID = 1221140 /*Children's Social Care*/
		or o2.ID = 1221140
		or o3.ID = 1221140
		or o4.ID = 1221140
		or o5.ID = 1221140
		or o6.ID = 1221140
		or o7.ID = 1221140
	) d
)

order by pw.PERSON_ID, pw.START_DATE, pw.ID