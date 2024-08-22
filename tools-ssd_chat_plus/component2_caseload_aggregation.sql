
Use HDM_Local;

/* Caseload count by Team only */
SELECT
    ISNULL(d.dept_team_name, 'Unassigned') AS TeamName,             -- NULL Team vals become unassigned
    ISNULL(d.dept_team_parent_name, 'No Parent') AS TeamParentName, -- Similar handling for NULL PArent Teams
    COUNT(*) AS CaseloadCount
FROM
    ssd_development.ssd_involvements AS i
LEFT JOIN
    ssd_development.ssd_department AS d ON i.invo_professional_team = d.dept_team_id
WHERE
    UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'    -- filter on Case Workers only
    AND i.invo_involvement_end_date IS NULL                         -- open cases only
GROUP BY
    d.dept_team_name,
    d.dept_team_parent_name
ORDER BY
    CaseloadCount DESC;



/* Team caseloads but as sub-caseload breakdown by Team Member/Professional */
SELECT
    ISNULL(d.dept_team_name, 'Unassigned')          AS TeamName,            -- NULL Team vals become unassigned
    ISNULL(d.dept_team_parent_name, 'No Parent')    AS TeamParentName,      -- Similar handling for NULL PArent Teams
    i.invo_professional_id                          AS TeamMemberID,
    p.prof_professional_name                        AS TeamMemberName,
    p.prof_social_worker_registration_no            AS SocialWorkerRegistrationNo,
    p.prof_agency_worker_flag                       AS AgencyWorkerFlag,     
    p.prof_professional_job_title                   AS JobTitle,             -- Current Role Title (might not have been applicable at time of case?)
    p.prof_professional_caseload                    AS CurrentCaseload,
    COUNT(*)                                        AS TotalCaseloadSSD      -- Takes the existing SSD total caseload count from ssd_professionals 
FROM
    ssd_development.ssd_involvements AS i

LEFT JOIN
    ssd_development.ssd_department AS d ON i.invo_professional_team = d.dept_team_id
LEFT JOIN
    ssd_development.ssd_professionals AS p ON i.invo_professional_id = p.prof_professional_id
WHERE
    UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'
    AND i.invo_involvement_end_date IS NULL
GROUP BY
    d.dept_team_name,
    d.dept_team_parent_name,
    i.invo_professional_id,
    p.prof_professional_name,
    p.prof_social_worker_registration_no,
    p.prof_agency_worker_flag,
    p.prof_professional_job_title,
    p.prof_professional_caseload
ORDER BY
    TeamName,
    TeamParentName,
    TotalCaseloadSSD DESC;



