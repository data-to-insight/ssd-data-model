/* 
Reductive views extract SQL - Caseload counts/aggr by Team
#DtoI-
#Requires ssd_development.ssd_ tables
*/

Use HDM_Local;



/* BREAKDOWN 220824 - in progress - Caseload count by Team only * Attempt 2 */
WITH
-- involvements filter open cases with 'ALLOCATED CASE WORKER' role
FilteredInvolvements AS (
    SELECT
        i.invo_involvements_id,
        i.invo_professional_team,
        i.invo_referral_id
    FROM
        ssd_involvements AS i
    WHERE
        UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'
        AND i.invo_involvement_end_date IS NULL
),
-- get the department details
DepartmentDetails AS (
    SELECT
        d.dept_team_id,
        ISNULL(d.dept_team_name, 'Unassigned') AS TeamName,
        ISNULL(d.dept_team_parent_name, 'No Parent') AS TeamParentName
    FROM
        ssd_department AS d
),
--get count of open CP plans
OpenCPPlans AS (
    SELECT
        i.invo_professional_team,
        COUNT(*) AS OpenCPPlanCount
    FROM
        FilteredInvolvements AS i
    LEFT JOIN
        ssd_cp_plans AS cp ON i.invo_referral_id = cp.cppl_referral_id
        AND cp.cppl_cp_plan_end_date IS NULL
    WHERE
        cp.cppl_cp_plan_id IS NOT NULL
    GROUP BY
        i.invo_professional_team
),
-- get count of CiN episodes with no plan
CiNWithoutPlans AS (
    SELECT
        i.invo_professional_team,
        COUNT(*) AS CiNWithoutPlanCount
    FROM
        FilteredInvolvements AS i
    LEFT JOIN
        ssd_cin_episodes AS cine ON i.invo_referral_id = cine.cine_referral_id
    LEFT JOIN
        ssd_cin_assessments AS cina ON cine.cine_referral_id = cina.cina_referral_id
    WHERE
        cine.cine_referral_id IS NOT NULL
        AND cina.cina_referral_id IS NULL
    GROUP BY
        i.invo_professional_team
),
-- get count of active (with NULL cine_close_date) ssd_cin_episodes
OpenCINEpisodes AS (
    SELECT
        cine.cine_referral_team,
        COUNT(DISTINCT cine.cine_person_id) AS OpenCINEpisodeCount
    FROM
        ssd_cin_episodes AS cine
    WHERE
        cine.cine_close_date IS NULL
    GROUP BY
        cine.cine_referral_team
),
-- get count of care leavers by team, only incl.those with open CIN episode
CareLeavers AS ( 
    SELECT
        cl.clea_care_leaver_allocated_team,
        COUNT(DISTINCT cl.clea_person_id) AS CareLeaverCount
    FROM
        ssd_care_leavers AS cl
    JOIN
        ssd_cin_episodes AS cine ON cl.clea_person_id = cine.cine_person_id
    WHERE
        cine.cine_close_date IS NULL  -- Only include care leavers with open CIN episode
    GROUP BY
        cl.clea_care_leaver_allocated_team
)
SELECT
    dd.TeamName,
    dd.TeamParentName,
    COUNT(fi.invo_involvements_id) AS CaseloadCount,             -- Total involvements (cases) for each team
    COALESCE(cp.OpenCPPlanCount, 0) AS OpenCPPlanCount,          -- Cnt open Child Protection plans, defaults to 0 if no open plans are found
    COALESCE(cn.CiNWithoutPlanCount, 0) AS CiNWithoutPlan,       -- Cnt Child in Need episodes without a plan, defaults to 0 if none are found
    COALESCE(oc.OpenCINEpisodeCount, 0) AS OpenCINEpisodeCount,  -- Cnt unique open CIN episodes by team
    COALESCE(cl.CareLeaverCount, 0) AS CareLeaverCount           -- Cnt care leavers by team
FROM
    FilteredInvolvements AS fi
LEFT JOIN
    DepartmentDetails AS dd ON fi.invo_professional_team = dd.dept_team_id
LEFT JOIN
    OpenCPPlans AS cp ON fi.invo_professional_team = cp.invo_professional_team
LEFT JOIN
    CiNWithoutPlans AS cn ON fi.invo_professional_team = cn.invo_professional_team
LEFT JOIN
    OpenCINEpisodes AS oc ON dd.dept_team_id = oc.cine_referral_team -- Join to get open CIN episodes count by team
LEFT JOIN
    CareLeavers AS cl ON dd.dept_team_id = cl.clea_care_leaver_allocated_team -- Join to get care leaver count by team
GROUP BY
    dd.TeamName,
    dd.TeamParentName,
    cp.OpenCPPlanCount,
    cn.CiNWithoutPlanCount,
    oc.OpenCINEpisodeCount,
    cl.CareLeaverCount
HAVING
    COALESCE(cp.OpenCPPlanCount, 0) > 0 OR                      -- Include teams with at least one open CP plan
    COALESCE(cn.CiNWithoutPlanCount, 0) > 0 OR                  -- Or include teams with at least one CiN episode without a plan
    COALESCE(oc.OpenCINEpisodeCount, 0) > 0 OR                  -- Or include teams with at least one open CIN episode
    COALESCE(cl.CareLeaverCount, 0) > 0                         -- Or include teams with at least one care leaver
ORDER BY
    CaseloadCount DESC;




/* BASIC - Caseload count by Team only * Attempt 1 */
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



