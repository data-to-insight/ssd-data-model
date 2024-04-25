/*
PW - Need to clarify which workers to include
		e.g. Is it current workers, workers with current cases, workers appearing in other lists etc
	Then add appropriate selection criteria

	Currently includes workers with current active role in a tean within 'Children Social Care' in Mosaic Organisation Hierarchy
		This still picks up non-case holders (could remove workers with zero cases but this would then exclude Team Managers etc)
*/


DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


IF OBJECT_ID('Tempdb..#t','u') IS NOT NULL
BEGIN
DROP TABLE #t
END
CREATE TABLE #t
(
prof_table_id INT /*Information not held as a separate field as Worker ID is unique*/,
prof_professional_id INT,
--FIRST_NAMES VARCHAR(50),
--LAST_NAMES VARCHAR(50),
prof_social_worker_registration_no VARCHAR(20),
prof_agency_worker_flag VARCHAR(10) /*Field removed from SSDS*/,
prof_professional_job_title VARCHAR(100),
prof_professional_caseload INT DEFAULT 0,
prof_professional_department VARCHAR(100),
prof_full_time_equivalency DEC (10,2) /*Information not held in Mosaic; held in HR System (I-Trent)*/
)

INSERT #t
(
prof_table_id,
prof_professional_id,
--FIRST_NAMES,
--LAST_NAMES,
prof_social_worker_registration_no,
prof_agency_worker_flag,
prof_professional_job_title,
prof_professional_department,
prof_full_time_equivalency
)

Select
d.prof_table_id,
d.prof_professional_id,
--d.FIRST_NAMES,
--d.LAST_NAMES,
d.prof_social_worker_registration_no,
d.prof_agency_worker_flag,
d.prof_professional_job_title,
d.prof_professional_department,
d.prof_full_time_equivalency

from
(
	Select
	NULL prof_table_id /*Information not held as a separate field as Worker ID is unique*/,
	a.ID prof_professional_id,
	a.FIRST_NAMES,
	a.LAST_NAMES,
	COALESCE(b.HCPCIdentifier, 'XX' + CAST(a.id as VARCHAR)) prof_social_worker_registration_no,
	NULL prof_agency_worker_flag, /*Field removed from SSDS*/
	wrt.DESCRIPTION prof_professional_job_title,
	org.NAME prof_professional_department,
	NULL prof_full_time_equivalency, /*Information not held in Mosaic; held in HR System (I-Trent)*/
	DENSE_RANK() OVER(PARTITION BY a.ID ORDER BY COALESCE(wr.END_DATE, '99991231') DESC, wr.ID DESC) Rnk

	from Mosaic.M.WORKERS a
	inner join Mosaic.M.WORKER_ROLES wr on a.ID = wr.WORKER_ID
	inner join Mosaic.M.WORKER_ROLE_TYPES wrt on wr.ROLE = wrt.ROLE
	inner join Mosaic.M.ORGANISATIONS org on wr.ORG_ID = org.ID
	left join Returns.CSCWC.HCPC b on a.ID = b.WID

	where wrt.DESCRIPTION not like '%auth%' /*Authorisor roles which are additional to main role*/
	and wr.START_DATE <= @STARTTIME
	and COALESCE(wr.END_DATE,'99991231') > @STARTTIME
	
	and wr.ORG_ID in
	/*Get current Teams within 'Children's Social Care' in Mosaic Organisation Hierarchy*/
	(
		Select
		d1.OHLevel1ID

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
		)
		d1
	)
)
d

where d.Rnk = 1


/*Number of Open Cases*/
UPDATE #t
SET prof_professional_caseload = d.prof_professional_caseload

from #t t
inner join
(
	Select
	pw.WORKER_ID prof_professional_id,
	COUNT(*) prof_professional_caseload

	from Mosaic.M.PEOPLE_WORKERS pw

	where pw.START_DATE <= @STARTTIME
	and COALESCE(pw.END_DATE, '99991231') > @STARTTIME
	and pw.TYPE in ('ALLWKR' /*Allocated Worker*/,
					'AWAKENTEAN' /*Awaken Team*/,
					'FAMFINDSOC' /*Adoption*/,
					'FAMPLACEMENTWORK' /*Fostering*/,
					'PASSW')

	group by pw.WORKER_ID
)
d on t.prof_professional_id = d.prof_professional_id


/*Output Data*/
Select
t.prof_table_id,
t.prof_professional_id,
--t.FIRST_NAMES,
--t.LAST_NAMES,
t.prof_social_worker_registration_no,
t.prof_agency_worker_flag,
t.prof_professional_job_title,
t.prof_professional_caseload,
t.prof_professional_department,
t.prof_full_time_equivalency

from #t t

order by t.prof_professional_id