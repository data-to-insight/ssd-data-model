/* 
Reductive views extract SQL - Caseload counts/aggr by Team
#DtoI-
#Requires ssd_development.ssd_ tables
*/

Use HDM_Local;


/* 
Reductive views extract SQL - Caseload counts/aggr by Team
#DtoI-
#Requires ssd_development.ssd_ tables
*/

WITH
/* involvements filter active cases with 'ALLOCATED CASE WORKER' role */
InvolvementCounts AS (
    SELECT
        i.invo_professional_team,                           -- grouping by team
        COUNT(DISTINCT cla.clae_person_id) AS InvolvementCaseload -- count person_id for each team with active CLA episode
    FROM
        ssd_involvements AS i
    INNER JOIN
        ssd_cla_episodes AS cla ON i.invo_referral_id = cla.clae_referral_id -- link involvements with CLA episodes 
    WHERE
        UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'  -- filter by role 'ALLOCATED CASE WORKER'
        AND i.invo_involvement_end_date IS NULL                       -- filter for active cases in involvements
    GROUP BY
        i.invo_professional_team
),

/* get count of active CLA episodes (where clae_cla_episode_ceased is NULL) */
OpenCLAEpisodes AS (
    SELECT
        i.invo_professional_team,                                 -- grouping by team via involvements
        COUNT(DISTINCT cla.clae_person_id) AS OpenCLAEpisodeCount     -- count person_id with active CLA episodes by team
    FROM
        ssd_cla_episodes AS cla
    LEFT JOIN
        ssd_involvements AS i ON cla.clae_referral_id = i.invo_referral_id -- link with involvements for team dets
    WHERE
        UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'  -- filter by role 'ALLOCATED CASE WORKER'
        AND cla.clae_cla_episode_ceased IS NULL                       -- ensure the CLA episode is still open
    GROUP BY
        i.invo_professional_team
),

/* get count of active CLA episodes that also have an active CP plan */
OpenCPAndLAC AS (
    SELECT
        i.invo_professional_team,                                 -- grouping by team via involvements
        COUNT(DISTINCT cp.cppl_person_id) AS CPAndLACCount                -- active CLA episodes with an active CP plan
    FROM
        ssd_cp_plans AS cp
    LEFT JOIN
        ssd_cla_episodes AS cla ON cp.cppl_person_id = cla.clae_person_id
    LEFT JOIN
        ssd_involvements AS i ON cp.cppl_referral_id = i.invo_referral_id -- link with involvements for team dets
    WHERE
        cla.clae_cla_episode_ceased IS NULL                       -- filter for active CLA episodes
        AND cp.cppl_cp_plan_end_date IS NULL                      -- filter for active CP plans
    GROUP BY
        i.invo_professional_team
),

/* get count of active CP plans with no related active CLA episode */
ActiveCPWithoutCLA AS (
    SELECT
        i.invo_professional_team,                                 -- grouping by team via involvements
        COUNT(DISTINCT cp.cppl_person_id) AS CPnoLAC                      -- active CP plans without a related CLA episode
    FROM
        ssd_cp_plans AS cp
    LEFT JOIN
        ssd_cla_episodes AS cla ON cp.cppl_referral_id = cla.clae_referral_id
    LEFT JOIN
        ssd_involvements AS i ON cp.cppl_referral_id = i.invo_referral_id -- link with involvements for team dets
    WHERE
        cp.cppl_cp_plan_end_date IS NULL                                    -- filter for active CP plans
        AND cla.clae_cla_episode_ceased IS NULL                             -- ensure no related CLA episode
    GROUP BY
        i.invo_professional_team
),

/* count care leavers without related active involvement or CLA episode */
CareLeaversWithoutInvolvementOrCLA AS (
    SELECT
        -- cl.clea_care_leaver_allocated_team,                       -- grouping by care leaver team
        i.invo_professional_team,                                   -- grouping by involvements team
        COUNT(DISTINCT cl.clea_person_id) AS CareLeaversNoInvolvementOrCLA -- care leavers without active involvement or CLA episode
    FROM
        ssd_care_leavers AS cl
    LEFT JOIN
        ssd_involvements AS i ON cl.clea_person_id = i.invo_person_id AND i.invo_involvement_end_date IS NULL
    LEFT JOIN
        ssd_cla_episodes AS cla ON cl.clea_person_id = cla.clae_person_id AND cla.clae_cla_episode_ceased IS NULL

    WHERE
        i.invo_involvement_end_date IS NULL                             -- no active involvement
        AND cla.clae_cla_episode_ceased IS NULL                         -- no active CLA episode
    GROUP BY
        -- cl.clea_care_leaver_allocated_team                               -- 1)[TESTING] group by care leaver team from care_leavers
        i.invo_professional_team                                         -- 2)[TESTING] group by professional team from involvements
)

/* main select, combine all counts */
SELECT
    ISNULL(dd.dept_team_name, 'Unassigned')         AS TeamName,              -- from department dets (if None/NULL placeholder used)
    ISNULL(dd.dept_team_parent_name, 'No Parent')   AS TeamParentName,        -- from department dets (if None/NULL placeholder used)
    -- Summary counts (by team)
    COALESCE(ic.InvolvementCaseload, 0)             AS InvolvementCaseload,   -- total involvements/caseload (else 0)
    COALESCE(ocla.OpenCLAEpisodeCount, 0)           AS OpenCLAEpisodeCount,   -- active CLA episode (else 0)
    COALESCE(cp_lac.CPAndLACCount, 0)               AS LACwithCP,             -- active CLA episode with an active CP plan (else 0)
    COALESCE(acp.CPnoLAC, 0)                        AS LACnoCP,               -- active CLA episode without active plan (else 0)
    COALESCE(cl_no_involvement_or_cla.CareLeaversNoInvolvementOrCLA, 0) 
                                                    AS CareLeaversNoInvolvementOrCLA -- care leavers without active involvement or CLA episode (else 0)
FROM
    ssd_department AS dd

LEFT JOIN
    InvolvementCounts AS ic ON dd.dept_team_id = ic.invo_professional_team
LEFT JOIN
    OpenCLAEpisodes AS ocla ON dd.dept_team_id = ocla.invo_professional_team
LEFT JOIN
    OpenCPAndLAC AS cp_lac ON dd.dept_team_id = cp_lac.invo_professional_team 
LEFT JOIN
    ActiveCPWithoutCLA AS acp ON dd.dept_team_id = acp.invo_professional_team 
LEFT JOIN
    -- CareLeaversWithoutInvolvementOrCLA AS cl_no_involvement_or_cla ON dd.dept_team_id = cl_no_involvement_or_cla.clea_care_leaver_allocated_team 
    CareLeaversWithoutInvolvementOrCLA AS cl_no_involvement_or_cla ON dd.dept_team_id = cl_no_involvement_or_cla.invo_professional_team  

WHERE
    COALESCE(ic.InvolvementCaseload, 0)     > 0 OR                          -- include teams with at least one involvement case
    COALESCE(ocla.OpenCLAEpisodeCount, 0)   > 0 OR                          -- include teams with at least one active CLA episode
    COALESCE(cp_lac.CPAndLACCount, 0)       > 0 OR                          -- include teams with at least one active CLA episode with a CP plan
    COALESCE(acp.CPnoLAC, 0)                > 0 OR                          -- include teams with at least one active CP plan with no related CLA episode
    COALESCE(cl_no_involvement_or_cla.CareLeaversNoInvolvementOrCLA, 0) > 0 -- include teams with care leavers having no active involvement or CLA episode

ORDER BY
    InvolvementCaseload DESC;




--- start of previous version BAK

-- WITH
-- -- involvements filter active cases with 'ALLOCATED CASE WORKER' role
-- FilteredInvolvements AS (
--     SELECT
--         i.invo_involvements_id,
--         i.invo_professional_team,
--         i.invo_referral_id
--     FROM
--         ssd_involvements AS i
--     WHERE
--         UPPER(i.invo_professional_role_id) = 'ALLOCATED CASE WORKER'
--         AND i.invo_involvement_end_date IS NULL
-- ),
-- -- get the department details
-- DepartmentDetails AS (
--     SELECT
--         d.dept_team_id,
--         ISNULL(d.dept_team_name, 'Unassigned') AS TeamName,
--         ISNULL(d.dept_team_parent_name, 'No Parent') AS TeamParentName
--     FROM
--         ssd_department AS d
-- ),

-- -- get count of active CP plans
-- OpenCPPlans AS (
--     /*
--     count number of active Child Protection (CP) plans associated with each team
--     filters for active CP plans linked to ongoing involvements with an 'ALLOCATED CASE WORKER'
--     count is valid, active CP plans grouped by involvement team
--     */
--     SELECT
--         i.invo_professional_team,                   -- grp by involvement team 
--         COUNT(*) AS OpenCPPlanCount                 -- count active CP plans for each team
--     FROM
--         FilteredInvolvements AS i
--     LEFT JOIN
--         ssd_cp_plans AS cp ON i.invo_referral_id = cp.cppl_referral_id
--         AND cp.cppl_cp_plan_end_date IS NULL        -- only consider CP plans that are still active (no end date)
--     WHERE
--         cp.cppl_cp_plan_id IS NOT NULL              -- exclude involvements without associated CP plan
--     GROUP BY
--         i.invo_professional_team                    -- aggregate count of active CP plans by team
-- ),


-- -- get count of CiN episodes with no plan
-- CiNWithoutPlans AS (
--     /*
--     count number of Child in Need (CiN) episodes that have no associated plan
--     filters for involvements linked to CiN episodes where no assessment plan exists
--     count is grouped by involvement team
--     */
--     SELECT
--         i.invo_professional_team,                   -- grp by involvement team 
--         COUNT(*) AS CiNWithoutPlanCount             -- count CiN episodes without plan for each team
--     FROM
--         FilteredInvolvements AS i
--     LEFT JOIN
--         ssd_cin_episodes AS cine ON i.invo_referral_id = cine.cine_referral_id
--     LEFT JOIN
--         ssd_cin_assessments AS cina ON cine.cine_referral_id = cina.cina_referral_id
--     WHERE
--         cine.cine_referral_id IS NOT NULL           -- ensure involvement has linked CiN episode
--         AND cina.cina_referral_id IS NULL           -- exclude cases where an assessment plan exists
--     GROUP BY
--         i.invo_professional_team                    -- aggregate count of CiN episodes without plan by team
-- ),



-- -- get count of active (with NULL cine_close_date) ssd_cin_episodes
-- OpenCINEpisodes AS (
--     /*
--     count active Child in Need (CiN) episodes where close date is NULL
--     identifies episodes still ongoing
--     count is grouped by referral team
--     */
--     SELECT
--         cine.cine_referral_team,                       -- grp by referral team responsible for CiN episode
--         COUNT(DISTINCT cine.cine_person_id) AS OpenCINEpisodeCount -- count distinct persons with active CIN episode
--     FROM
--         ssd_cin_episodes AS cine
--     WHERE
--         cine.cine_close_date IS NULL                   -- only include episodes with no close date (still active)
--     GROUP BY
--         cine.cine_referral_team                        -- aggregate count of active CiN episodes by team
-- ),

-- -- get count of care leavers by team, only incl.those with active CIN episode
-- CareLeavers AS ( 
--     /*
--     count number of care leavers by team, includes only those with active CIN episode
--     filters out care leavers without an active CIN case
--     count is grouped by team assigned to care leaver
--     */
--     SELECT
--         cl.clea_care_leaver_allocated_team,            -- grp by team assigned to care leaver
--         COUNT(DISTINCT cl.clea_person_id) AS CareLeaverCount -- count distinct care leavers with active CIN episode
--     FROM
--         ssd_care_leavers AS cl
--     JOIN
--         ssd_cin_episodes AS cine ON cl.clea_person_id = cine.cine_person_id
--     WHERE
--         cine.cine_close_date IS NULL                   -- only include care leavers with active CIN episode
--     GROUP BY
--         cl.clea_care_leaver_allocated_team             -- aggregate count of care leavers by team
-- )

-- SELECT
--     dd.TeamName,
--     dd.TeamParentName,
--     COUNT(fi.invo_involvements_id) AS CaseloadCount,             -- Total involvements (cases) for each team
--     COALESCE(cp.OpenCPPlanCount, 0) +                            -- Calculation for testCount: Sum of all other counts
--     COALESCE(cn.CiNWithoutPlanCount, 0) + 
--     COALESCE(oc.OpenCINEpisodeCount, 0) + 
--     COALESCE(cl.CareLeaverCount, 0) AS TestCount,                -- testCount used as [TESTING] comparison against CaseloadCount
--     COALESCE(cp.OpenCPPlanCount, 0) AS OpenCPPlanCount,          -- Cnt active Child Protection plans, defaults to 0 if no active plans are found
--     COALESCE(cn.CiNWithoutPlanCount, 0) AS CiNWithoutPlan,       -- Cnt Child in Need episodes without a plan, defaults to 0 if none are found
--     COALESCE(oc.OpenCINEpisodeCount, 0) AS OpenCINEpisodeCount,  -- Cnt unique active CIN episodes by team
--     COALESCE(cl.CareLeaverCount, 0) AS CareLeaverCount           -- Cnt care leavers by team
-- FROM
--     FilteredInvolvements AS fi
-- LEFT JOIN
--     DepartmentDetails AS dd ON fi.invo_professional_team = dd.dept_team_id
-- LEFT JOIN
--     OpenCPPlans AS cp ON fi.invo_professional_team = cp.invo_professional_team
-- LEFT JOIN
--     CiNWithoutPlans AS cn ON fi.invo_professional_team = cn.invo_professional_team
-- LEFT JOIN
--     OpenCINEpisodes AS oc ON dd.dept_team_id = oc.cine_referral_team                -- Join to get active CIN episodes count by team
-- LEFT JOIN
--     CareLeavers AS cl ON dd.dept_team_id = cl.clea_care_leaver_allocated_team       -- Join to get care leaver count by team

-- GROUP BY
--     dd.TeamName,
--     dd.TeamParentName,
--     cp.OpenCPPlanCount,
--     cn.CiNWithoutPlanCount,
--     oc.OpenCINEpisodeCount,
--     cl.CareLeaverCount
-- HAVING
--     -- only list teams with relevant caseloads
--     COALESCE(cp.OpenCPPlanCount, 0) > 0 OR                      -- Include teams with at least one active CP plan
--     COALESCE(cn.CiNWithoutPlanCount, 0) > 0 OR                  -- Or include teams with at least one CiN episode without a plan
--     COALESCE(oc.OpenCINEpisodeCount, 0) > 0 OR                  -- Or include teams with at least one active CIN episode
--     COALESCE(cl.CareLeaverCount, 0) > 0                         -- Or include teams with at least one care leaver
-- ORDER BY
--     CaseloadCount DESC;

--- end of previous version BAK




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
    AND i.invo_involvement_end_date IS NULL                         -- active cases only
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



