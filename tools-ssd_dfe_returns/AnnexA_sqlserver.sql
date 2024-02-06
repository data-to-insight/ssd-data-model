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


-- -- [TESTING]
-- select * from #AA_1_contacts;




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
    #ssd_person p

INNER JOIN
    #ssd_early_help_episodes e ON p.pers_person_id = e.earl_person_id

WHERE
    (
        /* eh_epi_start_date is within the last 6 months, or earl_episode_end_date is within the last 6 months, 
        or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
        e.earl_episode_start_date >= DATEADD(MONTH, -6, GETDATE())
    OR
        (e.earl_episode_end_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR e.earl_episode_end_date IS NULL OR e.earl_episode_end_date = '')
    );



-- -- [TESTING]
-- select * from #AA_2_early_help_assessments;


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


-- -- [TESTING]
-- select * from #AA_3_referrals;



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
    END                                                 AS AGE,
    

    /* List additional AA fields */

    d.disa_disability_code                              AS DISABILITY, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)

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


-- -- [TESTING]
-- select * from #AA_4_assessments;










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

-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_5_s47_enquiries') IS NOT NULL DROP TABLE #AA_5_s47_enquiries ;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS CHILD_ID,
    p.pers_sex                                  AS GENDER,
    p.pers_ethnicity                            AS ETHNICITY,
    CONVERT(VARCHAR, p.pers_dob, 103)           AS DATE_OF_BIRTH,
    
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
    END                                             AS AGE,
    

    /* List additional AA fields */

    d.disa_disability_code                                                  AS DISABILITY,        -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    /* Returns fields */
    s47e.s47e_s47_enquiry_id                                                AS ENQUIRY_ID,
    CONVERT(VARCHAR, s47e.s47e_s47_start_date, 103)                         AS S47_ENQUIRY_START_DATE,  -- Strategy discussion initiating Section 47 Enquiry Start Date

    JSON_VALUE(s47e.s47e_s47_outcome_json, '$.OUTCOME_CP_CONFERENCE_FLAG')  AS CP_CONF_NEEDED,   -- Was an Initial Child Protection Conference deemed unnecessary?,
    CONVERT(VARCHAR, icpc.icpc_icpc_date, 103)                              AS CP_CONF_DATE,     -- Date of Initial Child Protection Conference

    -- [TESTING] 
    -- THESE FIELDS NEED CONFIRMNING
    -- CP_CONF FORMAT(s47e.icpc_date, 'dd/MM/yyyy') AS formatted_icpc_date,     -- 
    icpc.icpc_icpc_outcome_cp_flag                  AS CP_CONF_OUTCOME_CP,      -- Did the Initial Child Protection Conference Result in a Child Protection Plan

    /* Aggregate fields */
    agg.CountS47s12m,               -- Sum of Number of Section 47 Enquiries in the last 12 months (NOT INCL. CURRENT)
    agg_icpc.CountICPCs12m,         -- Sum of Number of ICPCs in the last 12 months  (NOT INCL. CURRENT)


    -- [TESTING]
    -- check/update icpc table extract, 
    -- if have icpc then take that data, else s47 dets.
    s47e.s47e_s47_completed_by_team                 AS ALLOCATED_TEAM,
    s47e.s47e_s47_completed_by_worker               AS ALLOCATED_WORKER
    
    -- -- or is it... 
    -- -- [TESTING]
    -- icpc.icpc_icpc_team                             AS ALLOCATED_TEAM,        
    -- icpc.icpc_icpc_worker_id                        AS ALLOCATED_WORKER
 

INTO #AA_5_s47_enquiries 

FROM
    #ssd_s47_enquiry s47e

INNER JOIN
    #ssd_person p ON s47e.s47e_person_id = p.pers_person_id

-- [TESTING]
-- towards icpc.icpc_icpc_outcome_cp_flag 
LEFT JOIN #ssd_initial_cp_conference icpc ON s47e.s47e_s47_enquiry_id = icpc.icpc_s47_enquiry_id

LEFT JOIN   -- ensure we get all records even if there's no matching disability
    #ssd_disability d ON p.pers_person_id = d.disa_person_id

LEFT JOIN (
    SELECT
    /* section 47 enquiries the child has been the subject of within 
    the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
        s47e_person_id,
        COUNT(s47e_s47_enquiry_id) - 1 as CountS47s12m
    FROM
        #ssd_s47_enquiry 
    WHERE
        s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE())
        
    GROUP BY
        s47e_person_id
) as agg ON s47e.s47e_person_id = agg.s47e_person_id

LEFT JOIN (
    SELECT
    /*initial child protection conferences the child has been the subject of 
    in the 12 months before their latest Section 47 enquiry.*/
        icpc.icpc_person_id,
        COUNT(icpc.icpc_s47_enquiry_id) as CountICPCs12m
    FROM
        #ssd_initial_cp_conference icpc

    INNER JOIN #ssd_s47_enquiry s47e ON icpc.icpc_s47_enquiry_id = s47e.s47e_s47_enquiry_id
    WHERE
        s47e.s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE()) -- [TESTING] is this s47_start_date OR icpc_icpc_transfer_in
        AND (icpc.icpc_icpc_date IS NOT NULL AND icpc.icpc_icpc_date <> '')
    GROUP BY
        icpc.icpc_person_id
) agg_icpc ON s47e.s47e_person_id = agg_icpc.icpc_person_id


WHERE
    s47e.s47e_s47_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- [TESTING]
select * from #AA_5_s47_enquiries;






/* 
=============================================================================
Report Name: Ofsted List 6 - Children in Need YYYY
Description: 
            "All those in receipt of services as a child in need at the point 
            of inspection or in the six months before the inspection.
            This list does not include care leavers or children who are only 
            the subject of a referral."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_disability
- ssd_person
- ssd_cla_episodes
- ssd_cin_plans
- ssd_cp_plans
- ssd_assessments
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_6_children_in_need') IS NOT NULL DROP TABLE #AA_6_children_in_need;


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
    d.disa_disability_code                      AS DISABILITY, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    cp.cinp_cin_plan_id,
    cp.cinp_cin_plan_start,
    cp.cinp_cin_plan_end,
    cp.cinp_cin_plan_team  ,
    cp.cinp_cin_plan_worker_id ,

    /* case_status */
    CASE 
        WHEN ce.cla_epi_start < GETDATE() AND (ce.cla_epi_ceased IS NULL OR ce.cla_epi_ceased = '') 
        THEN 'Looked after child'
        WHEN cpp.cpp_start_date < GETDATE() AND cpp.cpp_end_date IS NULL
        THEN 'Child Protection plan'
        WHEN cp.cinp_cin_plan_start < GETDATE() AND cp.cin_plan_end IS NULL
        THEN 'Child in need plan'
        WHEN asm.cina_assessment_start_date < GETDATE() AND asm.asmt_auth_date IS NULL
        THEN 'Open Assessment'
        WHEN ce.clae_cla_episode_ceased     > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR -- chk db handling of empty strings and nulls is consistent
             cpp.cppl_cp_plan_end_date      > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR 
             cp.cinp_cin_plan_end           > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR
             asm.cina_assessment_auth_date  > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE())
        THEN 'Closed episode'
        ELSE NULL 
    END as case_status

INTO #AA_6_children_in_need

FROM
    ssd_cin_plans cp

INNER JOIN
    ssd_person p ON cp.cinp_person_id = p.pers_person_id

LEFT JOIN   -- with disability
    ssd_disability d ON cp.cinp_person_id = d.disa_person_id

LEFT JOIN   -- cla_episodes to get the most recent cla_epi_start
    (
        SELECT clae_person_id, MAX(clae_cla_episode_start) as clae_cla_episode_start, clae_cla_episode_ceased
        FROM ssd_cla_episodes
        GROUP BY clae_person_id, clae_cla_episode_ceased
    ) AS ce ON p.pers_person_id = ce.clae_person_id

LEFT JOIN   -- cp_plans to get the cpp_start_date and cpp_end_date
    (
        SELECT cppl_person_id , MAX(cppl_cp_plan_start_date) as cppl_cp_plan_start_date, cppl_cp_plan_end_date
        FROM ssd_cp_plans
        GROUP BY cppl_person_id, cppl_cp_plan_end_date
    ) AS cpp ON p.pers_person_id = cpp.cppl_person_id 

LEFT JOIN   -- joining with assessments to get the cina_assessment_start_date and cina_assessment_auth_date
    ssd_cin_assessments asm ON p.pers_person_id = asm.cina_person_id 

WHERE
    cp.cin_plan_Start >= DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE());


-- [TESTING]
select * from #AA_6_children_in_need;





/* 
=============================================================================
Report Name: Ofsted List 7: Child protection
Description: 
            "All those who are the subject of a child protection plan at the 
            point of inspection. Include those who ceased to be the subject of 
            a child protection plan in the six months before the inspection."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_7_child_protection') IS NOT NULL DROP TABLE #AA_7_child_protection;

-- still to include in list 7 ?!
    -- Child Protection Plan Start Date?
    -- Date of last review conference?
    -- cp end date?
    -- Number of Previous Child Protection Plans?

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
    d.disa_disability_code                      AS DISABILITY, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    /* Returns fields */    
    cv.cinv_cin_visit_id,
    cv.cin_plan_id, -- [TESTING] Do we still have access to plan id on cin_visits??? 
    cv.cinv_cin_visit_date,
    cv.cinv_cin_visit_seen,
    cv.cinv_cin_visit_seen_alone,

    /* Check if Emergency Protection Order exists within last 6 months */
    CASE WHEN ls.legal_status_id IS NOT NULL THEN 'Y' ELSE 'N' END AS emergency_protection_order,

    /* Which is it??? */
    cp.cin_team,
    cp.cin_worker_id,
    ce.cin_ref_team,
    ce.cin_ref_worker_id as cin_ref_worker,
    
    /* New fields for category of abuse */
    MIN(CASE WHEN cpp.cpp_start_date = coa_early.cpp_earliest_date THEN coa_early.cpp_category END) AS "Initial cat of abuse",
    MIN(CASE WHEN cpp.cpp_start_date = coa_latest.cpp_latest_date THEN coa_latest.cpp_category END) AS "latest cat of abuse"

INTO #AA_7_child_protection

FROM
    ssd_cin_visits cv

INNER JOIN
    ssd_person p ON cv.cinv_person_id = p.pers_person_id

LEFT JOIN   -- with disability
    ssd_disability d ON cv.cinv_person_id = d.disa_person_id

INNER JOIN
    cin_episodes ce ON cv.la_person_id = ce.la_person_id
LEFT JOIN
    legal_status ls ON cv.la_person_id = ls.la_person_id 
        AND ls.legal_status_start >= DATEADD(MONTH, -6, GETDATE())	/*PW - amended from '>= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH)'*/
LEFT JOIN
    cp_plans cpp ON cv.la_person_id = cpp.la_person_id
LEFT JOIN
    category_of_abuse coa_early ON cpp.cp_plan_id = coa_early.cp_plan_id
    AND coa_early.cpp_start_date = (
        SELECT MIN(cpp_start_date) FROM cp_plans WHERE la_person_id = cv.la_person_id
    )
LEFT JOIN
    category_of_abuse coa_latest ON cpp.cp_plan_id = coa_latest.cp_plan_id
    AND coa_latest.cpp_start_date = (
        SELECT MAX(cpp_start_date) FROM cp_plans WHERE la_person_id = cv.la_person_id
    )

WHERE
    cv.cin_visit_date >= DATEADD(MONTH, -12, GETDATE()) -- [TESTING] check time period, 12mths or 6?	/*PW - Amended from 'DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)'*/

GROUP BY
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    d.person_disability,
    cv.cin_visit_id,
    cv.cin_plan_id,
    cv.cin_visit_date,
    cv.cin_visit_seen,
    cv.cin_visit_seen_alone,
    cp.cin_team,
    cp.cin_worker_id,
    ce.cin_ref_team,
    ce.cin_ref_worker_id,
    ls.legal_status_id;


/* AA headings from sample
Does the Child have a Disability
Child Protection Plan Start Date
Initial Category of Abuse
Latest Category of Abuse
Date of the Last Statutory Visit
Was the Child Seen Alone?
Date of latest review conference
Child Protection Plan End Date
Subject to Emergency Protection Order or Protected Under Police Powers in Last Six Months (Y/N)
Sum of Number of Previous Child Protection Plans
Allocated Team
Allocated Worker

*/

-- Are these needed? Not in list 7
--     /* New fields from cin_episodes table */
--     ce.cin_primary_need, -- available in more than one place
--     ce.cin_ref_outcome, -- is this case status? 
--     ce.cin_close_reason,
--     ce.cin_ref_team,
--     ce.cin_ref_worker_id as cin_ref_worker  -- Renamed for clarity
-- INNER JOIN  -- with cin_episodes
--     cin_episodes ce ON cp.la_person_id = ce.la_person_id





/* 
=============================================================================
Report Name: Ofsted List 8 - Children in Care YYYY
Description: 
            "All children in care at the point of inspection. Include all 
            those children who ceased to be looked after in the six months 
            before the inspection."

Author: D2I
Last Modified Date: 31/01/24 RH
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
    END                                     AS AGE, 

    /* List additional AA fields */

    d.disa_disability_code                  AS DISABILITY,     
    i.immi_immigration_status,  

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


-- [TESTING]
select * from #AA_8_children_in_care;




/* 
=============================================================================
Report Name: Ofsted List 9 -  Leaving Care Services YYYY
Description: 
            "All those who have reached the threshold for receiving leaving 
            care services at the point of inspection (entitled children).Includes:
            Relevant children, Former relevant children, Qualifying care leaver
            Eligible children"

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
-
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_9_care_leavers') IS NOT NULL DROP TABLE #AA_9_care_leavers;

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

    /* List additional AA fields */

    d.disa_disability_code                      AS DISABILITY     




INTO #AA_9_care_leavers

FROM
-- 

INNER JOIN
    ssd_person p ON xx.xxxx_person_id = p.pers_person_id

LEFT JOIN   -- disability table
    ssd_disability d ON xx.xxxx_person_id = d.disa_person_id



/* 
=============================================================================
Report Name: Ofsted List 10 - Adoption YYYY
Description: 
            "All those children who, in the 12 months before the inspection, 
            have: been adopted, had the decision that they should be placed 
            for adoption but they have not yet been adopted, had an adoption 
            decision reversed during the 12 months."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
-
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_10_adoption') IS NOT NULL DROP TABLE #AA_10_adoption;

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

    /* List additional AA fields */

    d.disa_disability_code                      AS DISABILITY 




INTO #AA_10_adoption

FROM
-- 

INNER JOIN
    ssd_person p ON xx.xxxx_person_id = p.pers_person_id

LEFT JOIN   -- disability table
    ssd_disability d ON xx.xxxx_person_id = d.disa_person_id



/* 
=============================================================================
Report Name: Ofsted List 11 - Adopters YYYY
Description: 
            "All those individuals who in the 12 months before the inspection 
            have had contact with the local authority adoption agency"

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Incomplete as required data not held within the ssd and beyond 
            project scope. 
Dependencies: 
- ssd_person
- ssd_permanence
- ssd_disability
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_11_adopters') IS NOT NULL DROP TABLE #AA_11_adopters;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ADOPTER_ID,      -- Individual adopter identifier
    --  fam.fami_person_id            -- IS this coming from fc.DIM_PERSON_ID AS fami_person_id, as doesnt seem valid context
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

    /* List additional AA fields */
    d.disa_disability_code                      AS DISABILITY,     

    perm.perm_adopted_by_carer_flag             AS ADOPTED_BY_CARER, -- Is the (prospective) adopter fostering for adoption?
    -- Date enquiry received
    -- Date Stage 1 started
    -- Date Stage 1 ended
    -- Date Stage 2 started
    -- Date Stage 2 ended
    -- Date application submitted
    -- Date application approved
    perm.perm_matched_date                      AS MATCHED_DATE, -- Date adopter matched with child(ren)
    perm.perm_placed_for_adoption_date          AS PLACED_DATE, -- Date child/children placed with adopter(s)
    perm.perm_siblings_placed_together          AS NUM_SIBLINGS_PLACED, -- No. of children placed
    perm.perm_permanence_order_date             AS ADOPTION_ORDER_DATE, -- Date of Adoption Order
    perm.perm_decision_reversed_date            AS ADOPTION_LEAVE_DATE, -- Date of leaving adoption process
    perm.perm_decision_reversed_reason          AS ADOPTION_LEAVE_REASON-- Reason for leaving adoption process

INTO #AA_11_adopters

FROM
    ssd_permanence perm

INNER JOIN
    ssd_person p ON perm.perm_person_id = p.pers_person_id

LEFT JOIN   -- disability table
    ssd_disability d ON perm.perm_person_id = d.disa_person_id

LEFT JOIN
    ssd_contacts c ON perm.perm_person_id = c.cont_person_id 

WHERE
    c.cont_contact_start >= DATEADD(MONTH, -12, GETDATE()) -- Filter on last 12 months
