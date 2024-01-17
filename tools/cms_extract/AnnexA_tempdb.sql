USE HDM_Local;
GO

-- var naming needs re-think for stat returns reporting, 
-- this atm carried over from... ssd time-frames (YRS)
DECLARE @ssd_timeframe_years INT = 1;


-- /**** SQL Server ****/
-- Obtain reports/csv files use built in export as or
-- bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD

-- -- Date field handling/formatting
-- FORMAT(p.person_dob, 'dd/MM/yyyy') AS formatted_person_dob,
-- On date filter use:     -- DATEADD(YEAR, -6, GETDATE()) *** in place of *** DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)



/*
**************************
SSD AnnexA Returns Queries
**************************
*/


/* 
=============================================================================
Report Name: Ofsted List 1 - Contacts YYYY
Description: 
            List 1: 
            Contacts "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for each child in the contact.

Author: D2I
Last Modified Date: 12/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.4: contact_source_desc added
            0.3: apply revised obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- ssd_contacts
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_1_contacts') IS NOT NULL DROP TABLE #AA_1_contacts;


SELECT
    /* Common AA fields */
    p.pers_legacy_id                        AS CHILD_ID,
    p.pers_sex                              AS GENDER,
    p.pers_ethnicity                        AS ETHNICITY,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')        AS DATE_OF_BIRTH,
    CASE
        -- If DoB is in the future, set age as -1 (unborn)
        WHEN p.pers_dob > GETDATE() THEN -1

        -- Special case for leap year babies (born Feb 29)
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            -- Check if current year is not a leap year
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2

        ELSE 
            -- Calc age normally
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                -- Subtract extra year if current date is before birthday this year
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0
            END
    END                                         AS AGE,

    /* List additional AA fields */
    FORMAT(c.cont_contact_start, 'dd/MM/yyyy')  AS DATE_OF_CONTACT,
    c.cont_contact_source_desc                  AS CONTACT_SOURCE

INTO #AA_1_contacts
FROM
    #ssd_contact c

LEFT JOIN
    #ssd_person p ON c.cont_person_id = p.pers_person_id
WHERE
    c.cont_contact_start >= DATEADD(MONTH, -@ssd_timeframe_years * 12, GETDATE());


-- [TESTING]
select * from #AA_1_contacts;




/* 
=============================================================================
Report Name: Ofsted List 2 - Early Help Assessments YYYY
Description: 
            List 2: Early Help 
            "All early help assessments in the six months before the date of inspection. 
            Also, current early help interventions that are being coordinated through the local authority.""

Author: D2I
Last Modified Date: 17/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- ssd_cin_episodes
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_2_early_help_assessments') IS NOT NULL DROP TABLE #AA_2_early_help_assessments;


SELECT
    /* Common AA fields */

    p.pers_legacy_id                        AS CHILD_ID,
    p.pers_sex                              AS GENDER,
    p.pers_ethnicity                        AS ETHNICITY,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')        AS DATE_OF_BIRTH,
    CASE
        -- If DoB is in the future, set age as -1 (unborn)
        WHEN p.pers_dob > GETDATE() THEN -1

        -- Special case for leap year babies (born Feb 29)
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            -- Check if current year is not a leap year
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2

        ELSE 
            -- Calc age normally
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                -- Subtract extra year if current date is before birthday this year
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0
            END
    END                                         AS AGE,
    
    /* List additional AA fields */

    FORMAT(e.earl_episode_start_date, 'dd/MM/yyyy')     AS earl_episode_start_date, -- [TESTING] Need a col name change
    FORMAT(e.earl_episode_end_date, 'dd/MM/yyyy')       AS earl_episode_end_date,   -- [TESTING] Need a col name change
    e.earl_episode_organisation                                                     -- [TESTING] Need a col name change

INTO #AA_2_early_help_assessments

FROM
    ssd_person p

INNER JOIN
    ssd_early_help_episodes e ON p.pers_person_id = e.earl_person_id
WHERE
    (
        /* eh_epi_start_date is within the last 6 months, or earl_episode_end_date is within the last 6 months, 
        or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
        e.earl_episode_start_date >= DATEADD(MONTH, -6, GETDATE())
    OR
        (e.earl_episode_end_date >= DATEADD(MONTH, -6, GETDATE()) OR e.earl_episode_end_date IS NULL OR e.earl_episode_end_date = '')
    );






/* 
=============================================================================
Report Name: Ofsted List 3 - Referrals YYYY
Description: 
            List 3: 
            Referral	"All referrals received in the six months before the inspection.
            Children may appear multiple times on this list if they have received multiple referrals."

Author: D2I
Last Modified Date: 12/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- ssd_cin_episodes
- ssd_person
=============================================================================
*/


-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_3_referrals') IS NOT NULL DROP TABLE #AA_3_referrals;

SELECT
    /* Common AA fields */

    p.pers_legacy_id                            AS CHILD_ID,
    p.pers_sex                                  AS GENDER,
    p.pers_ethnicity                            AS ETHNICITY,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DATE_OF_BIRTH,
    
    CASE
        -- If DoB is in the future, set age as -1 (unborn)
        WHEN p.pers_dob > GETDATE() THEN -1

        -- Special case for leap year babies (born Feb 29)
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            -- Check if current year is not a leap year
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2

        ELSE 
            -- Calc age normally
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                -- Subtract extra year if current date is before birthday this year
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0
            END
    END                                         AS AGE,
    
    /* List additional AA fields */

    ce.cine_referral_id                         AS REFERRAL_ID,
    FORMAT(ce.cine_referral_date, 'dd/MM/yyyy') AS REFERRAL_DATE,
    ce.cine_referral_source_desc                AS REFERRAL_SOURCE,
    CASE -- indicate if the most recent referral (or individual referral) resulted in 'No Further Action' (NFA)
        WHEN ce.cine_referral_nfa = 'NFA' THEN 'Yes'
        ELSE 'No'
    END                                         AS NFA,
    ce.cine_referral_team                       AS ALLOCATED_TEAM,
    ce.cine_referral_worker_id                  AS ALLOCATED_WORKER, 
    COALESCE(sub.count_12months, 0)             AS NUMBER_REFERRALS_LAST12MTHS

INTO #AA_3_referrals

FROM
    #ssd_cin_episodes ce
INNER JOIN
    #ssd_person p ON ce.cine_person_id = p.pers_person_id
LEFT JOIN
    (
        SELECT 
            cine_person_id,
            CASE -- referrals the child has received within the **12** months prior to their latest referral.
                WHEN COUNT(*) > 0 THEN COUNT(*) - 1
                ELSE 0
            END as count_12months
        FROM 
            #ssd_cin_episodes
        WHERE
            cine_referral_date >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY
            cine_person_id
    ) sub ON ce.cine_person_id = sub.cine_person_id
WHERE
    ce.cine_referral_date >= DATEADD(MONTH, -6, GETDATE());






/* 
=============================================================================
Report Name: Ofsted List 8 - Children in Care YYYY
Description: 
            List 8: 
            Children in Care	"....."

Author: D2I
Last Modified Date: 17/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cp_plans
- ssd_disability
- ssd_immigration_status
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_8_children_in_care') IS NOT NULL DROP TABLE #AA_8_children_in_care;

SELECT
    /* Common AA fields */

    p.pers_legacy_id                            AS CHILD_ID,
    p.pers_sex                                  AS GENDER,
    p.pers_ethnicity                            AS ETHNICITY,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DATE_OF_BIRTH, --  note: returns string representation of the date
    
    CASE
        -- If DoB is in the future, set age as -1 (unborn)
        WHEN p.pers_dob > GETDATE() THEN -1

        -- Special case for leap year babies (born Feb 29)
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            -- Check if current year is not a leap year
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2

        ELSE 
            -- Calc age normally
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                -- Subtract extra year if current date is before birthday this year
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0
            END
    END                                         AS AGE, 

    d.disa_disability_code,     -- Disability field - Is this returned or generated??  Yes/No/Unknown */    
    i.immi_immigration_status,  -- Immigration Status field 

    /* List additional AA fields */

    cp.cppl_cp_plan_start_date,
    cp.cppl_cp_plan_end_date,
    cp.cppl_cp_plan_worker_id,
    cp.cppl_cp_plan_team

INTO #AA_8_children_in_care

FROM
    ssd_cp_plans cp
INNER JOIN
    ssd_person p ON cp.cppl_person_id = p.pers_person_id
LEFT JOIN   -- disability table
    ssd_disability d ON cp.cppl_person_id = d.disa_person_id
LEFT JOIN   -- immigration_status table (UASC)
    ssd_immigration_status i ON cp.cppl_person_id = i.immi_person_id