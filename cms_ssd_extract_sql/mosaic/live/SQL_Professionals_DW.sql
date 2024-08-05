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
    prof_professional_id INT /*Information not held as a separate field as Worker ID is unique*/,
    prof_staff_id INT,
	prof_professional_name VARCHAR(300), -- [REVIEW]
    --FIRST_NAMES VARCHAR(50),
    --LAST_NAMES VARCHAR(50),
    prof_social_worker_registration_no VARCHAR(20),
    prof_agency_worker_flag VARCHAR(10) /*Field removed from SSDS*/,
    prof_professional_job_title VARCHAR(500),
    prof_professional_caseload INT DEFAULT 0,
    prof_professional_department VARCHAR(100),
    prof_full_time_equivalency DEC (10,2) /*Information not held in Mosaic; held in HR System (I-Trent)*/
)

INSERT #t
(
    prof_professional_id,
    prof_staff_id,
	prof_professional_name, -- [REVIEW] Used null as placholder until source field is identified
    --FIRST_NAMES,
    --LAST_NAMES,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_department,
    prof_full_time_equivalency
)

SELECT
    d.prof_professional_id,
    d.prof_staff_id,
	d.prof_professional_name, -- [REVIEW]
    --d.FIRST_NAMES,
    --d.LAST_NAMES,
    d.prof_social_worker_registration_no,
    d.prof_agency_worker_flag,
    d.prof_professional_job_title,
    d.prof_professional_department,
    d.prof_full_time_equivalency

FROM
(
    SELECT
        NULL prof_professional_id /*Information not held as a separate field as Worker ID is unique*/,
        a.ID prof_staff_id,
		NULL prof_professional_name, --[REVIEW] Used null as placholder until source field is identified
        a.FIRST_NAMES,
        a.LAST_NAMES,
        COALESCE(b.HCPCIdentifier, 'XX' + CAST(a.id as VARCHAR)) prof_social_worker_registration_no,
        NULL prof_agency_worker_flag, /*Field removed from SSDS*/,
        wrt.DESCRIPTION prof_professional_job_title,
        org.NAME prof_professional_department,
        NULL prof_full_time_equivalency, /*Information not held in Mosaic; held in HR System (I-Trent)*/,
        DENSE_RANK() OVER(PARTITION BY a.ID ORDER BY COALESCE(wr.END_DATE, '99991231') DESC, wr.ID DESC) Rnk

    FROM Mosaic.M.WORKERS a
    INNER JOIN Mosaic.M.WORKER_ROLES wr ON a.ID = wr.WORKER_ID
    INNER JOIN Mosaic.M.WORKER_ROLE_TYPES wrt ON wr.ROLE = wrt.ROLE
    INNER JOIN Mosaic.M.ORGANISATIONS org ON wr.ORG_ID = org.ID
    LEFT JOIN Returns.CSCWC.HCPC b ON a.ID = b.WID

    WHERE wrt.DESCRIPTION NOT LIKE '%auth%' /*Authorisor roles which are additional to main role*/
    AND wr.START_DATE <= @STARTTIME
    AND COALESCE(wr.END_DATE,'99991231') > @STARTTIME
    
    AND wr.ORG_ID IN
    /*Get current Teams within 'Children's Social Care' in Mosaic Organisation Hierarchy*/
    (
        SELECT
        d1.OHLevel1ID

        FROM
        (
            SELECT
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
            o6.ID OHLevel6ID,
            o6.Name OHLevel6Name,
            o7.ID OHLevel7ID,
            o7.Name OHLevel7Name

            FROM Mosaic.M.ORGANISATIONS o1
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os1 ON o1.ID = os1.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o2 ON os1.PARENT_ORG_ID = o2.ID
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os2 ON o2.ID = os2.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o3 ON os2.PARENT_ORG_ID = o3.ID
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os3 ON o3.ID = os3.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o4 ON os3.PARENT_ORG_ID = o4.ID
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os4 ON o4.ID = os4.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o5 ON os4.PARENT_ORG_ID = o5.ID
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os5 ON o5.ID = os5.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o6 ON os5.PARENT_ORG_ID = o6.ID
            LEFT JOIN Mosaic.M.ORGANISATION_STRUCTURE os6 ON o6.ID = os6.CHILD_ORG_ID
            LEFT JOIN Mosaic.M.ORGANISATIONS o7 ON os6.PARENT_ORG_ID = o7.ID

            WHERE o1.ID = 1221140 /*Children's Social Care*/
            OR o2.ID = 1221140
            OR o3.ID = 1221140
            OR o4.ID = 1221140
            OR o5.ID = 1221140
            OR o6.ID = 1221140
            OR o7.ID = 1221140
        ) d1
    )
) d

WHERE d.Rnk = 1


/*Number of Open Cases*/
UPDATE #t
SET prof_professional_caseload = d.prof_professional_caseload

FROM #t t
INNER JOIN
(
    SELECT
        pw.WORKER_ID prof_staff_id,
        COUNT(*) prof_professional_caseload

    FROM Mosaic.M.PEOPLE_WORKERS pw

    WHERE pw.START_DATE <= @STARTTIME
    AND COALESCE(pw.END_DATE, '99991231') > @STARTTIME
    AND pw.TYPE IN ('ALLWKR' /*Allocated Worker*/,
                    'AWAKENTEAN' /*Awaken Team*/,
                    'FAMFINDSOC' /*Adoption*/,
                    'FAMPLACEMENTWORK' /*Fostering*/,
                    'PASSW')

    GROUP BY pw.WORKER_ID
) d ON t.prof_staff_id = d.prof_staff_id


/*Output Data*/
SELECT
    t.prof_professional_id,
    t.prof_staff_id,
	t.prof_professional_name, -- [REVIEW]
    --t.FIRST_NAMES,
    --t.LAST_NAMES,
    t.prof_social_worker_registration_no,
    t.prof_agency_worker_flag,
    t.prof_professional_job_title,
    t.prof_professional_caseload,
    t.prof_professional_department,
    t.prof_full_time_equivalency

FROM #t t

ORDER BY t.prof_staff_id
