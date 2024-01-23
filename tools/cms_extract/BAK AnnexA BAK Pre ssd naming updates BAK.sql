
-- ssd time-frames (YRS)
DECLARE @ssd_timeframe_years INT = 6;
DECLARE @ssd_sub1_range_years INT = 1;


/* 
=============================================================================
Object Name: Ofsted List 1 - Contacts YYYY
Description: List 1: Contacts "All contacts received in the six months before the date of inspection. 
Where a contact refers to multiple children, include an entry for each child in the contact.

Author: D2I
Last Modified Date: 05/01/32 RH
DB Compatibility: SQL Server 2014+|...
Version: 0.2
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: script modified to reflect new|revised obj/item naming. 
Dependencies: 
- @YearsBack
- ssd_contacts
- ssd_person
=============================================================================
*/

-- CREATE TEMPORARY TABLE `AA_1_contacts` AS 
CREATE VIEW AA_1_contacts_vw AS
SELECT
    /* Common AA fields */
    p.pers_person_id,
    p.pers_sex,
    p.pers_ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy') AS formatted_pers_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.pers_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    FORMAT(c.cont_contact_date, 'dd/MM/yyyy') AS formatted_cont_contact_date,
    c.cont_contact_source

FROM
    ssd_contacts c
LEFT JOIN
    ssd_person p ON c.cont_person_id = p.pers_person_id
WHERE
    c.cont_contact_date >= DATEADD(MONTH, -@YearsBack, GETDATE());



-- Ofsted List 2 - Early Help Assessments YYYY
-- SQL Server version
-- List 2: Early Help	"All early help assessments in the six months before the date of inspection. 
-- Also, current early help interventions that are being coordinated through the local authority.

CREATE VIEW AA_2_early_help_assessments_vw AS
SELECT
    /* Common AA fields */
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    FORMAT(p.person_dob, 'dd/MM/yyyy') as person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.person_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.person_dob) AND DAY(GETDATE()) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    FORMAT(e.eh_epi_start_date, 'dd/MM/yyyy') as eh_epi_start_date,
    FORMAT(e.eh_epi_end_date, 'dd/MM/yyyy') as eh_epi_end_date,
    e.eh_epi_org
FROM
    person p
INNER JOIN
    early_help_episodes e ON p.la_person_id = e.la_person_id
WHERE
    (
        /* eh_epi_start_date is within the last 6 months, or eh_epi_end_date is within the last 6 months, 
        or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
        e.eh_epi_start_date >= DATEADD(MONTH, -6, GETDATE())
    OR
        (e.eh_epi_end_date >= DATEADD(MONTH, -6, GETDATE()) OR e.eh_epi_end_date IS NULL OR e.eh_epi_end_date = '')
    );




-- Ofsted List 3 - Referrals YYYY
-- SQL Server version
-- List 3: Referral	"All referrals received in the six months before the inspection.
-- Children may appear multiple times on this list if they have received multiple referrals."

CREATE VIEW AA_3_referrals_vw AS
SELECT
    /* Common AA fields */
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    FORMAT(p.person_dob, 'dd/MM/yyyy') as person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.person_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.person_dob) AND DAY(GETDATE()) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    ce.cin_referral_id,
    FORMAT(ce.cin_ref_date, 'dd/MM/yyyy') as cin_ref_date,
    ce.cin_primary_need,
    CASE -- indicate if the most recent referral (or individual referral) resulted in 'No Further Action' (NFA)
        WHEN ce.cin_ref_outcomec = 'NFA' THEN 'Yes'
        ELSE 'No'
    END as cin_ref_outcomec,
    ce.cin_ref_team,
    ce.cin_ref_worker_id,
    COALESCE(sub.count_12months, 0) as count_12months
FROM
    cin_episodes ce
INNER JOIN
    person p ON ce.la_person_id = p.la_person_id
LEFT JOIN
    (
        SELECT 
            la_person_id,
            CASE -- referrals the child has received within the **12** months prior to their latest referral.
                WHEN COUNT(*) > 0 THEN COUNT(*) - 1
                ELSE 0
            END as count_12months
        FROM 
            cin_episodes
        WHERE
            cin_ref_date >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY
            la_person_id
    ) sub ON ce.la_person_id = sub.la_person_id
WHERE
    ce.cin_ref_date >= DATEADD(MONTH, -6, GETDATE());





-- Ofsted List 4 - Assessments YYYY
-- SQL Server version
-- CREATE TEMPORARY TABLE `AA_4_assessments` AS 
CREATE VIEW AA_4_assessments_vw AS
SELECT
    /* Common AA fields */
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    FORMAT(p.person_dob, 'dd/MM/yyyy') as person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.person_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.person_dob) AND DAY(GETDATE()) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */    
    a.assessment_id,
    FORMAT(a.asmt_start_date, 'dd/MM/yyyy') as asmt_start_date,
    -- FACT_SINGLE_ASSESSMENT.SEEN_FLAG  a.asmt_child_seen,
    FORMAT(a.asmt_auth_date, 'dd/MM/yyyy') as asmt_auth_date,
 
 
    a.asmt_outcome, -- TO CHECK
    -- OUTCOME_STRATEGY_DISCUSSION_FLAG
OUTCOME_CLA_REQUEST_FLAG
OUTCOME_PRIVATE_FOSTERING_FLAG
OUTCOME_LEGAL_ACTION_FLAG
OUTCOME_PROV_OF_SERVICES_FLAG
OUTCOME_PROV_OF_SB_CARE_FLAG
OUTCOME_SPECIALIST_ASSESSMENT_FLAG


    a.asmt_team,
    a.asmt_worker_id,

    /* Disability field */
    d.person_disability -- Disability field - Is this returned or generated??  Yes/No/Unknown 

FROM
    --- FACT_INITIAL_ASSESSMENT  assessments a
INNER JOIN
    person p ON a.la_person_id = p.la_person_id
LEFT JOIN   -- ensure we get all records even if there's no matching disability
    disability d ON p.la_person_id = d.la_person_id
WHERE
    a.asmt_start_date >= DATEADD(MONTH, -12, GETDATE());






-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1
-- Ofsted List 5 - Section 47 Enquiries and ICPC OC YYYY
-- List 5: Section 47 enquiries and Initial Child Protection Conferences	"All section 47 enquiries in the six months before the inspection.
-- This includes open S47 enquiries yet to reach a decision where possible.
-- Where a child has been the subject of multiple section 47 enquiries within the period, please provide one row for each enquiry."

-- CREATE TEMPORARY TABLE `AA_5_s47_enquiries` AS
CREATE VIEW AA_5_s47_enquiries_vw AS
SELECT
    /* Common AA fields */
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    FORMAT(p.person_dob, 'dd/MM/yyyy') AS formatted_person_dob, -- Applied date formatting
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.person_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.person_dob) AND DAY(GETDATE()) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    se.s47_enquiry_id,
    FORMAT(se.s47_start_date, 'dd/MM/yyyy') AS formatted_s47_start_date, -- Applied date formatting
    FORMAT(se.s47_authorised_date, 'dd/MM/yyyy') AS formatted_s47_authorised_date, -- Applied date formatting
    se.s47outcome,
    -- CP_CONF se.icpc_transfer_in, -- CP_CONF
    -- CP_CONF FORMAT(se.icpc_date, 'dd/MM/yyyy') AS formatted_icpc_date, -- Applied date formatting
    -- CP_CONF se.icpc_outcome,
    se.icpc_team,
    se.icpc_worker_id,

    /* Aggregate fields */
    agg.CountS47s12m, -- doesn't include most recent/current
    agg_icpc.CountICPCs12m -- doesn't include most recent/current

FROM
    s47_enquiry_icpc se
INNER JOIN
    person p ON se.la_person_id = p.la_person_id
LEFT JOIN (
    SELECT
    /* section 47 enquiries the child has been the subject of within 
    the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
        la_person_id,
        COUNT(s47_enquiry_id) - 1 as CountS47s12m
    FROM
        s47_enquiry_icpc
    WHERE
        s47_start_date >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY
        la_person_id
) as agg ON se.la_person_id = agg.la_person_id

LEFT JOIN (
    SELECT
    /*initial child protection conferences the child has been the subject of 
    in the 12 months before their latest Section 47 enquiry.*/
        la_person_id,
        COUNT(s47_enquiry_id) as CountICPCs12m
    FROM
        s47_enquiry_icpc
    WHERE
        s47_start_date >= DATEADD(MONTH, -12, GETDATE())
        AND (icpc_date IS NOT NULL AND icpc_date <> '')
    GROUP BY
        la_person_id
) as agg_icpc ON se.la_person_id = agg_icpc.la_person_id

WHERE
    se.s47_start_date >= DATEADD(MONTH, -6, GETDATE());









-- Ofsted List 6 - Children in Need YYYY
--           IF                 cla_epi_start < (today)      AND cla_epi_ceased is null THEN Case status = ‘Looked after child’
          
-- ELSE IF         cpp_start_date < (today) AND cpp_end_date is null THEN Case status = ‘Child Protection plan’

-- ELSE IF         cin_plan_start < (today)   AND cin_plan_end is null   THEN Case status = ‘Child in need plan’

-- ELSE IF         asmt_start_date < (today) AND asmt_auth_date is null THEN Case status = ‘Open Assessment’

-- ELSE IF         cla_epi_ceased > (today – 6 months) OR  
-- cpp_end_date > (today – 6 months) OR 
-- cin_plan_end > (today – 6 months) OR
-- asmt_auth_date > (today – 6 months) 

-- THEN Case status = ‘Closed episode’

-- CREATE TEMPORARY TABLE `AA_6_children_in_need` AS
CREATE VIEW AA_6_children_in_need_vw AS
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    CASE 
        -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > GETDATE() THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
             MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
             (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(GETDATE()) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(GETDATE()) < MONTH(p.person_dob) OR 
                     (MONTH(GETDATE()) = MONTH(p.person_dob) AND DAY(GETDATE()) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')

    d.person_disability, /* Disability field - Is this returned or generated??  Yes/No/Unknown */

    /* Returns fields */
    cp.cin_plan_id,
    cp.cin_plan_Start,
    cp.cin_plan_end,
    cp.cin_team,
    cp.cin_worker_id,

    /* case_status */
    CASE 
        WHEN ce.cla_epi_start < GETDATE() AND (ce.cla_epi_ceased IS NULL OR ce.cla_epi_ceased = '') 
        THEN 'Looked after child'
        WHEN cpp.cpp_start_date < GETDATE() AND cpp.cpp_end_date IS NULL
        THEN 'Child Protection plan'
        WHEN cp.cin_plan_Start < GETDATE() AND cp.cin_plan_end IS NULL
        THEN 'Child in need plan'
        WHEN asm.asmt_start_date < GETDATE() AND asm.asmt_auth_date IS NULL
        THEN 'Open Assessment'
        WHEN ce.cla_epi_ceased > DATEADD(MONTH, -6, GETDATE()) OR
             cpp.cpp_end_date > DATEADD(MONTH, -6, GETDATE()) OR 
             cp.cin_plan_end > DATEADD(MONTH, -6, GETDATE()) OR
             asm.asmt_auth_date > DATEADD(MONTH, -6, GETDATE())
        THEN 'Closed episode'
        ELSE NULL 
    END as case_status

FROM
    cin_plans cp
INNER JOIN
    person p ON cp.la_person_id = p.la_person_id
LEFT JOIN   -- with disability
    disability d ON cp.la_person_id = d.la_person_id
LEFT JOIN   -- cla_episodes to get the most recent cla_epi_start
    (
        SELECT la_person_id, MAX(cla_epi_start) as cla_epi_start, cla_epi_ceased
        FROM cla_episodes
        GROUP BY la_person_id, cla_epi_ceased
    ) AS ce ON p.la_person_id = ce.la_person_id
LEFT JOIN   -- cp_plans to get the cpp_start_date and cpp_end_date
    (
        SELECT la_person_id, MAX(cpp_start_date) as cpp_start_date, cpp_end_date
        FROM cp_plans
        GROUP BY la_person_id, cpp_end_date
    ) AS cpp ON p.la_person_id = cpp.la_person_id
LEFT JOIN   -- joining with assessments to get the asmt_start_date and asmt_auth_date
    assessments asm ON p.la_person_id = asm.la_person_id

WHERE
    cp.cin_plan_Start >= DATEADD(MONTH, -6, GETDATE());





-- Ofsted List 7: Child protection
-- still to include in list 7 ?!
    -- Child Protection Plan Start Date?
    -- Date of last review conference?
    -- cp end date?
    -- Number of Previous Child Protection Plans?

-- CREATE TEMPORARY TABLE `AA_7_child_protection` AS
CREATE VIEW AA_7_child_protection_vw AS
SELECT
    /* Common AA fields */
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > CURRENT_DATE THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(CURRENT_DATE) <= 2 AND DAY(CURRENT_DATE) < 28 AND
            (YEAR(CURRENT_DATE) % 4 != 0 OR (YEAR(CURRENT_DATE) % 100 = 0 AND YEAR(CURRENT_DATE) % 400 != 0))
        THEN YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                    (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge -- Calculated Age (Note on List 1 is 'AGE')    

    d.person_disability, /* Disability field - Is this returned or generated??  Yes/No/Unknown */

    /* Returns fields */    
    cv.cin_visit_id,
    cv.cin_plan_id,
    cv.cin_visit_date,
    cv.cin_visit_seen,
    cv.cin_visit_seen_alone,

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

FROM
    cin_visits cv
INNER JOIN
    person p ON cv.la_person_id = p.la_person_id
LEFT JOIN
    disability d ON cv.la_person_id = d.la_person_id
INNER JOIN
    cin_episodes ce ON cv.la_person_id = ce.la_person_id
LEFT JOIN
    legal_status ls ON cv.la_person_id = ls.la_person_id 
        AND ls.legal_status_start >= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH)
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
    cv.cin_visit_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)
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




-- Are these needed? Not in list 7
--     /* New fields from cin_episodes table */
--     ce.cin_primary_need, -- available in more than one place
--     ce.cin_ref_outcome, -- is this case status? 
--     ce.cin_close_reason,
--     ce.cin_ref_team,
--     ce.cin_ref_worker_id as cin_ref_worker  -- Renamed for clarity
-- INNER JOIN  -- with cin_episodes
--     cin_episodes ce ON cp.la_person_id = ce.la_person_id



-- Ofsted List 8 - Children in Care YYYY

-- CREATE TEMPORARY TABLE `AA_8_children_in_care` AS
CREATE VIEW AA_8_children_in_care_vw AS
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > CURRENT_DATE THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(CURRENT_DATE) <= 2 AND DAY(CURRENT_DATE) < 28 AND
            (YEAR(CURRENT_DATE) % 4 != 0 OR (YEAR(CURRENT_DATE) % 100 = 0 AND YEAR(CURRENT_DATE) % 400 != 0))
        THEN YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                    (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge -- Calculated Age (Note on List 1 is 'AGE')    

    d.person_disability, /* Disability field - Is this returned or generated??  Yes/No/Unknown */

    /* Immigration Status field */
    i.immigration_status,

    /* Returns fields */
    cp.cpp_start_date,
    cp.cpp_end_date,
    cp.cpp_worker_id,
    cp.cpp_team

FROM
    cp_plans cp
INNER JOIN
    person p ON cp.la_person_id = p.la_person_id
LEFT JOIN   -- disability table
    disability d ON cp.la_person_id = d.la_person_id
LEFT JOIN   -- immigration_status table (UASC)
    immigration_status i ON cp.la_person_id = i.la_person_id





-- Ofsted List 9 - Care Leavers YYYY
-- UASC, EndReasonDesc ??

-- CREATE TEMPORARY TABLE `AA_9_care_leavers` AS
CREATE VIEW AA_9_care_leavers_vw AS
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    CASE -- provide the child's age in years at their last birthday.
        WHEN p.person_dob > CURRENT_DATE THEN -1 -- If a child is unborn, enter their age as '-1'
        -- If born on Feb 29 and the current year is not a leap year and the date is before Feb 28, adjust the age
        WHEN MONTH(p.person_dob) = 2 AND DAY(p.person_dob) = 29 AND
            MONTH(CURRENT_DATE) <= 2 AND DAY(CURRENT_DATE) < 28 AND
            (YEAR(CURRENT_DATE) % 4 != 0 OR (YEAR(CURRENT_DATE) % 100 = 0 AND YEAR(CURRENT_DATE) % 400 != 0))
        THEN YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 2
        ELSE 
            YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
            CASE 
                WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                    (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob))
                THEN 1 
                ELSE 0 -- returned if age is < 1yr
            END
    END as CurrentAge -- Calculated Age (Note on List 1 is 'AGE')    

    /* Returns fields */
    d.person_disability, /* Disability field */

    /* Immigration Status field */
    i.immigration_status,

    cl.care_leaver_id, 
    cl.cl_eligibility,
    cl.cl_in_touch,
    cl.cl_latest_contact,
    cl.cl_accommodation,
    cl.cl_accom_suitable,
    cl.cl_activity,
    cl.cl_pathway_plan_rev_date,
    cl.cl_personal_advisor,
    cl.cl_team,
    cl.cl_worker_id
FROM
    care_leavers cl
INNER JOIN
    person p ON cl.la_person_id = p.la_person_id
LEFT JOIN   -- disability table
    disability d ON cl.la_person_id = d.la_person_id
LEFT JOIN   -- immigration_status table (UASC)
    immigration_status i ON cl.la_person_id = i.la_person_id
WHERE
    cl.cl_latest_contact >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);
    




--Ofsted List 10 - Adoption YYYY

-- CREATE TEMPORARY TABLE `AA_10_adoption` AS
CREATE VIEW AA_10_adoption_vw AS
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    f.family_id, 
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge,
    
    /* Disability field */
    d.person_disability,

    /* Returns fields */
    ce.cla_episode_id,
    ce.cla_epi_start,
    ce.cla_epi_start_reason,
    ce.cla_primary_need,
    ce.cla_epi_ceased,
    ce.cla_epi_cease_reason,
    ce.cla_team,
    ce.cla_worker_id,

    /* Permanence fields */
    perm.adm_decision_date,
    perm.placement_order_date,
    perm.matched_date,
    perm.placed_for_adoption_date,
    perm.permanence_order_date,
    perm.placed_ffa_cp_date
    perm.placed_foster_carer_date -- is this AdoptedByFormerCarer??

FROM
    cla_episodes ce
INNER JOIN
    person p ON ce.la_person_id = p.la_person_id
LEFT JOIN   
    disability d ON p.la_person_id = d.la_person_id
LEFT JOIN   
    family f ON p.la_person_id = f.la_person_id
INNER JOIN
    permanence perm ON p.la_person_id = perm.la_person_id
WHERE
    ce.cla_epi_start >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);





--Ofsted List 11 - Adopters YYYY
-- Not currently part of the SSD









-- Spec/table references --

/* Below are notes on object sql */


-- disability
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as AGE, -- Calculated Age
    d.person_disability
FROM
    disability d
INNER JOIN
    person p ON d.la_person_id = p.la_person_id;



-- immigration_status
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as AGE, -- Calculated Age
    i.immigration_status,
    i.immigration_status_start,
    i.immigration_status_end
FROM
    immigration_status i
INNER JOIN
    person p ON i.la_person_id = p.la_person_id
WHERE
    i.immigration_status_start >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);



-- legal status
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as AGE, -- Calculated Age
    l.legal_status,
    l.legal_status_start,
    l.legal_status_end
FROM
    person p
INNER JOIN
    legal_status l ON p.la_person_id = l.la_person_id;
WHERE
    l.legal_status_start >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);



-- contacts
SELECT
    p.la_person_id,
    p.person_gender as Gender,
    p.person_ethnicity as ETHNICITY_DESCRIPTION,
    p.person_dob as BIRTH_DTTM,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as AGE, -- Calculated Age
    c.contact_id as ContactID,
    c.contact_date as CONTACT_DTTM,
    c.contact_source as DIM_LOOKUP_CONT_SORC_ID_DESC,
    c.contact_outcome as ContactOutcomeDesc
    -- Additional fields for ESCC or any other organization can be added here as required
FROM
    contacts c
INNER JOIN
    person p ON c.la_person_id = p.la_person_id
WHERE
    c.contact_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);
    -- For SQL Server: DATEADD(YEAR, -6, GETDATE())




-- cp_plans
SELECT
/* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
/* Returns fields */
    cp.cp_plan_id,
    cp.cpp_start_date,
    cp.cpp_end_date,
    cp.cpp_team,
    cp.cpp_worker_id
FROM
    cp_plans cp
INNER JOIN
    person p ON cp.la_person_id = p.la_person_id
WHERE
    cp.cpp_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);




-- category_of_abuse
SELECT
/* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
/* Returns fields */
    ca.cpp_category_id,
    ca.cp_plan_id,
    ca.cpp_category,
    ca.cpp_category_start
FROM
    category_of_abuse ca
INNER JOIN
    person p ON ca.la_person_id = p.la_person_id
WHERE
    ca.cpp_category_start >= DATE_SUB(CURRENT_DATE, INTERVAL -12 MONTH);





-- cp_reviews
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    cr.cp_review_id,
    cr.cp_plan_id,
    cr.cp_rev_due,
    cr.cp_rev_date,
    cr.cp_rev_outcome,
    cr.cp_rev_quorate,
    cr.cp_rev_participation,
    cr.cp_rev_cyp_views_quality,
    cr.cp_rev_sufficient_prog
FROM
    cp_reviews cr
INNER JOIN
    person p ON cr.la_person_id = p.la_person_id
WHERE
    cr.cp_rev_due >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);








-- missing
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    m.missing_episode_id,
    m.cla_episode_id,
    m.mis_epi_start,
    m.mis_epi_type,
    m.mis_epi_end,
    m.mis_epi_rhi_offered,
    m.mis_epi_rhi_accepted
FROM
    missing m
INNER JOIN
    person p ON m.la_person_id = p.la_person_id
WHERE
    m.mis_epi_start >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);





-- permanence
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    perm.permanence_id,
    perm.adm_decision_date,
    perm.entered_care_date,
    perm.ffa_cp_decision_date,
    perm.placement_order_date,
    perm.placed_for_adoption_date,
    perm.matched_date,
    perm.placed_ffa_cp_date,
    perm.decision_reversed_date,
    perm.placed_foster_carer_date,
    perm.sibling_group,
    perm.siblings_placed_together,
    perm.siblings_placed_apart,
    perm.place_provider_urn,
    perm.decision_reversed_reason,
    perm.permanence_order_date,
    perm.permanence_order_type,
    perm.guardian_status,
    perm.guardian_age
FROM
    permanence perm
INNER JOIN
    person p ON perm.la_person_id = p.la_person_id
WHERE
    perm.permanence_order_date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);




-- social workers
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    sw.sw_id,
    sw.sw_epi_start_date,
    sw.sw_epi_end_date,
    sw.sw_change_reason,
    sw.sw_agency,
    sw.sw_role,
    sw.sw_caseload,
    sw.sw_qualification
FROM
    social_worker sw
INNER JOIN
    person p ON sw.la_person_id = p.la_person_id
    -- or do we need? social_worker sw ON p.la_person_id = sw.la_person_id
WHERE
    sw.sw_epi_start_date >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);
