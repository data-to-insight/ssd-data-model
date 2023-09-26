/*
******************
SSD AnnexA Returns
******************

Variations on how to achieve depending on db type

/**** MySQL ****/
INTO OUTFILE '/root/exports/Ofsted List 1 - Initial Contacts.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- Date field handling/formatting
DATE_FORMAT(p.person_dob, '%d/%m/%Y') AS formatted_person_dob,
DATE_FORMAT(c.contact_date, '%d/%m/%Y') AS formatted_contact_date,
On date filter use: DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)


/**** SQL Server ****/
use built in export as or
bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD

-- Date field handling/formatting
FORMAT(p.person_dob, 'dd/MM/yyyy') AS formatted_person_dob,
FORMAT(c.contact_date, 'dd/MM/yyyy') AS formatted_contact_date,
On date filter use:     -- DATEADD(YEAR, -6, GETDATE()) *** in place of *** DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)


/**** Oracle ****/
sqlplus username/password@databasename @/path_to_script/export_data.sql

SET HEADING ON
SET COLSEP ","
SET LINESIZE 32767
SET PAGESIZE 50000
SET TERMOUT OFF
SET FEEDBACK OFF
SET MARKUP HTML OFF SPOOL OFF
SET NUM 24

SPOOL /root/exports/Ofsted List 1 - Initial Contacts.csv
-- main query
SPOOL OFF
EXIT;

-- Date field handling/formatting
TO_CHAR(p.person_dob, 'DD/MM/YYYY') AS formatted_person_dob,
TO_CHAR(c.contact_date, 'DD/MM/YYYY') AS formatted_contact_date,


/**** PostGres ****/

-- Date field handling/formatting
TO_CHAR(p.person_dob, 'DD/MM/YYYY') AS formatted_person_dob,
TO_CHAR(c.contact_date, 'DD/MM/YYYY') AS formatted_contact_date,



**************************
SSD AnnexA Returns Queries
**************************
*/

-- Ofsted List 1 - Contacts YYYY
-- "List 1: Contacts "All contacts received in the six months before the date of inspection
-- Where a contact refers to multiple children, include an entry for each child in the contact."

-- CREATE TEMPORARY TABLE `AA_1_contacts` AS 
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender,
    p.person_ethnicity,
    DATE_FORMAT(p.person_dob, '%d/%m/%Y') AS formatted_person_dob,
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
    DATE_FORMAT(c.contact_date, '%d/%m/%Y') AS formatted_contact_date,
    c.contact_source

FROM
    contacts c
LEFT JOIN
    person p ON c.la_person_id = p.la_person_id
WHERE
    c.contact_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH);






-- Ofsted List 2 - Early Help Assessments YYYY
-- List 2: Early Help	"All early help assessments in the six months before the date of inspection. 
-- Also, current early help interventions that are being coordinated through the local authority.

-- CREATE TEMPORARY TABLE `AA_2_early_help_assessments` AS 
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
    e.eh_epi_start_date,
    e.eh_epi_end_date,
    e.eh_epi_org
FROM
    person p
INNER JOIN
    early_help_episodes e ON p.la_person_id = e.la_person_id
WHERE
    (
        /* eh_epi_start_date is within the last 6 months, or eh_epi_end_date is within the last 6 months, 
        or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
        e.eh_epi_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH)
    OR
        (e.eh_epi_end_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH) OR e.eh_epi_end_date IS NULL OR e.eh_epi_end_date = '')
    );




-- Ofsted List 3 - Referrals YYYY
-- List 3: Referral	"All referrals received in the six months before the inspection.
-- Children may appear multiple times on this list if they have received multiple referrals."

-- CREATE TEMPORARY TABLE `AA_3_referrals` AS 
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
    ce.cin_referral_id,
    ce.cin_ref_date,
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
            cin_ref_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)
        GROUP BY
            la_person_id
    ) sub ON ce.la_person_id = sub.la_person_id
WHERE
    ce.cin_ref_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH);






-- Ofsted List 4 - Assessments YYYY

-- CREATE TEMPORARY TABLE `AA_4_assessments` AS 
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
    a.assessment_id,
    a.asmt_start_date,
    a.asmt_child_seen,
    a.asmt_auth_date,
    -- ESCC Have SocialCareSupport? 
    a.asmt_outcome,
    a.asmt_team,
    a.asmt_worker_id,

    /* Disability field */
    d.person_disability, /* Disability field - Is this returned or generated??  Yes/No/Unknown */

FROM
    assessments a
INNER JOIN
    person p ON a.la_person_id = p.la_person_id
LEFT JOIN   -- ensure we get all records even if there's no matching disability
    disability d ON p.la_person_id = d.la_person_id
WHERE
    a.asmt_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);



-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1
-- Ofsted List 5 - Section 47 Enquiries and ICPC OC YYYY

-- CREATE TEMPORARY TABLE `AA_5_s47_enquiries` AS 
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
    se.s47_enquiry_id,
    se.s47_start_date,
    se.s47_authorised_date,
    se.s47outcome,
    se.icpc_transfer_in,
    se.icpc_date,
    se.icpc_outcome,
    se.icpc_team,
    se.icpc_worker_id,

    /* Aggregate field */
    agg.CountS47s12m

FROM
    s47_enquiry_icpc se
INNER JOIN
    person p ON se.la_person_id = p.la_person_id
LEFT JOIN (
    SELECT
        la_person_id,
        COUNT(s47_enquiry_id) as CountS47s12m
    FROM
        s47_enquiry_icpc
    WHERE
        s47_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)
    GROUP BY
        la_person_id
) as agg ON se.la_person_id = agg.la_person_id

WHERE
    se.s47_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);






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

    /* Returns fields */
    cp.cin_plan_id,
    cp.cin_plan_Start,
    cp.cin_plan_end,
    cp.cin_team,
    cp.cin_worker_id,

    /* Case status ???? */


FROM
    cin_plans cp
INNER JOIN
    person p ON cp.la_person_id = p.la_person_id
LEFT JOIN   -- with disability
    disability d ON cp.la_person_id = d.la_person_id

WHERE
    cp.cin_plan_Start >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);




-- Ofsted List 7: Child protection
-- still to include in list 7 ?!
    -- Child Protection Plan Start Date?
    -- Date of last review conference?
    -- cp end date?
    -- Number of Previous Child Protection Plans?

-- CREATE TEMPORARY TABLE `AA_7_child_protection` AS 
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
