USE HDM;
GO


-- Set reporting period in Mths
DECLARE @AA_ReportingPeriod INT;
SET @AA_ReportingPeriod = 6; -- Mths


-- 
-- /**** Obtain extract/csv files ****/
-- Use built in <export as> from console output or
-- bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD





/*
****************************************
SSD AnnexA Returns Queries || SQL Server
****************************************
*/


/* 
=============================================================================
Report Name: Ofsted List 1 - Contacts YYYY
Description: 
            "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for 
            each child in the contact.""

Author: D2I
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.4: contact_source_desc added
            0.3: apply revised obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
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

    -- Step type (or is that abaove source?) (SEE ALSO ASSESSMENTS L4)
    -- Responsible Team
    -- Assigned Worker

INTO #AA_1_contacts

FROM
    #ssd_contact c

LEFT JOIN
    #ssd_person p ON c.cont_person_id = p.pers_person_id

WHERE
    c.cont_contact_start >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- [TESTING]
select * from #AA_1_contacts;




/* 
=============================================================================
Report Name: Ofsted List 2 - Early Help Assessments YYYY
Description: 
            "All early help assessments in the six months before the date of 
            inspection. Also, current early help interventions that are being 
            coordinated through the local authority."

Author: D2I
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
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

    FORMAT(e.earl_episode_start_date, 'dd/MM/yyyy')     AS EHA_START_DATE,          -- [TESTING] Need a col name change?
    FORMAT(e.earl_episode_end_date, 'dd/MM/yyyy')       AS EHA_END_DATE,            -- [TESTING] Need a col name change?
    e.earl_episode_organisation                         AS EHA_COMPLETED_BY_TEAM    -- [TESTING] Need a col name change?

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
        (e.earl_episode_end_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR e.earl_episode_end_date IS NULL OR e.earl_episode_end_date = '')
    );






/* 
=============================================================================
Report Name: Ofsted List 3 - Referrals YYYY
Description:  
            "All referrals received in the six months before the inspection.
            Children may appear multiple times on this list if they have received 
            multiple referrals."

Author: D2I
Last Modified Date: 12/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
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
    ce.cine_referral_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());






/* 
=============================================================================
Report Name: Ofsted List 4 - Assessments YYYY
Description: 
            "Young people and children with assessments in previous six months"
Author: D2I
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1 
            1.0 Further edits of source obj referencing, Fixed to working state
            0.3: Removed old obj/item naming. 
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_cin_assessments
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_4_assessments') IS NOT NULL DROP TABLE #AA_4_assessments;


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

    d.disa_disability_code                                 AS DISABILITY, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)

    FORMAT(a.cina_assessment_start_date, 'dd/MM/yyyy')  AS ASMT_START_DATE,
    a.cina_assessment_child_seen                        AS CONT_ASMT, -- ('Child Seen During Continuous Assessment')
    FORMAT(a.cina_assessment_auth_date, 'dd/MM/yyyy')   AS ASMT_AUTH_DATE,

    -- [TESTING][NEED TO CONFIRM THESE FIELDS]   
    cina_assessment_outcome_json                        AS REQU_SOCIAL_CARE_SUPPORT, 
    cina_assessment_outcome_nfa                         AS ASMT_OUTCOME_NFA, 


    -- Step type (SEE ALSO CONTACTS)
    a.cina_assessment_team                              AS ALLOCATED_TEAM,
    a.cina_assessment_worker_id                         AS ALLOCATED_WORKER


INTO #AA_4_assessments

FROM
    #ssd_cin_assessments a

INNER JOIN
    #ssd_person p ON a.cina_person_id = p.pers_person_id

LEFT JOIN   -- ensure we get all records even if there's no matching disability
    #ssd_disability d ON p.pers_person_id = d.disa_person_id

WHERE
    a.cina_assessment_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- [TESTING]
select * from #AA_4_assessments;










/* 
=============================================================================
Report Name: Ofsted List 5 - Section 47 Enquiries and ICPC OC
Description: 
            "All section 47 enquiries in the six months before the inspection.
            This includes open S47 enquiries yet to reach a decision where possible.
            Where a child has been the subject of multiple section 47 enquiries within 
            the period, please provide one row for each enquiry."

Author: D2I
Last Modified Date: 30/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1
            1.0
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


-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1

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

    d.disa_disability_code                          AS DISABILITY, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    /* Returns fields */
    s47e.s47e_s47_enquiry_id                        AS ENQUIRY_ID,
    FORMAT(se.s47_start_date, 'dd/MM/yyyy')         AS S47_ENQUIRY_START_DATE,  -- Strategy discussion initiating Section 47 Enquiry Start Date

    s47e.s47outcome                                 AS CP_CONF_NEEDED           -- Was an Initial Child Protection Conference deemed unnecessary?,
    FORMAT(se.s47_authorised_date, 'dd/MM/yyyy')    AS CP_CONF_DATE,            -- Date of Initial Child Protection Conference

-- [TESTING] THESE FIELDS NEED CONFIRMNING
    s47e.icpc_transfer_in                           AS CP_REQUIRED,             -- Did the Initial Child Protection Conference Result in a Child Protection Plan
    -- CP_CONF FORMAT(s47e.icpc_date, 'dd/MM/yyyy') AS formatted_icpc_date,     -- Applied date formatting
    CP_CONF s47e.icpc_outcome                       AS CP_REQUIRED,

    /* Aggregate fields */
    agg.CountS47s12m,               -- Sum of Number of Section 47 Enquiries in the last 12 months (NOT INCL. CURRENT)
    agg_icpc.CountICPCs12m          -- Sum of Number of ICPCs in the last 12 months  (NOT INCL. CURRENT)

    s47e.icpc_team                                  AS ALLOCATED_TEAM,
    s47e.icpc_worker_id                             AS ALLOCATED_WORKER,

INTO #AA_5_s47_enquiries 

FROM
    ssd_s47_enquiry s47e

INNER JOIN
    ssd_person p ON s47e.s47e_person_id = p.pers_person_id
LEFT JOIN (
    SELECT
    /* section 47 enquiries the child has been the subject of within 
    the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
        s47e_person_id,
        COUNT(s47e_s47_enquiry_id) - 1 as CountS47s12m
    FROM
        ssd_s47_enquiry 
    WHERE
        s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY
        s47e_person_id
) as agg ON s47e.s47e_person_id = agg.s47e_person_id

LEFT JOIN (
    SELECT
    /*initial child protection conferences the child has been the subject of 
    in the 12 months before their latest Section 47 enquiry.*/
        icpc_person_id,
        COUNT(icpc_s47_enquiry_id) as CountICPCs12m
    FROM
        ssd_initial_cp_conference icpc -- or do i need to use/reference table ssd_s47_enquiry, 
    WHERE
        s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE())
        AND (icpc_date IS NOT NULL AND icpc_date <> '')
    GROUP BY
        icpc_person_id
) as agg_icpc ON icpc.icpc_person_id = agg_icpc.icpc_person_id

WHERE
    s47e.s47e_s47_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());








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