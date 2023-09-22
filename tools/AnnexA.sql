/*
******************
SSD AnnexA Returns
******************
*/

/* Export tables to file for stat-return
Variations on how to achieve depending on db type

--MySQL
INTO OUTFILE '/root/exports/Ofsted List 1 - Initial Contacts.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n';

--SQL Server
use built in export as or
bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD

--Oracle
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

*/


/* AnnexA Queries */

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
CREATE TEMPORARY TABLE `AnnexA_1_initial_contacts` AS 
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



-- Ofsted List 2 - Early Help Assessments YYYY
-- early_help_episodes
CREATE TEMPORARY TABLE `AnnexA_2_early_help_assessments` AS 
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
    e.eh_epi_start_date as EHA_StartDate,
    e.eh_epi_end_date as EHA_CompletedDate,
    e.eh_epi_org as EHA_CompletedBy_Team
FROM
    person p
INNER JOIN
    early_help_episodes e ON p.la_person_id = e.la_person_id
WHERE
    e.eh_epi_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);
    -- For SQL Server: DATEADD(YEAR, -6, GETDATE())




-- Ofsted List 3 - Referrals YYYY
-- cin_episodes 
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.person_gender as Gender,
    p.person_ethnicity as ETHNICITY_DESCRIPTION,
    p.person_dob as BIRTH_DTTM,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
    
    /* Returns fields */
    ce.cin_referral_id,
    ce.cin_ref_date as REFRL_START_DTTM,
    ce.cin_primary_need,
    ce.cin_ref_outcome as OutcomeDesc,
    ce.cin_ref_team as DIM_RECORD_BY_DEPT_ID_DESC_,
    ce.cin_ref_worker_id as DIM_RECORD_BY_USER_ID_DESC_1
FROM
    cin_episodes ce
INNER JOIN
    person p ON ce.la_person_id = p.la_person_id
WHERE
    ce.cin_ref_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);
    -- For SQL Server: DATEADD(MONTH, -12, GETDATE())




-- cin_plans
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
    cp.cin_plan_id,
    cp.cin_plan_Start,
    cp.cin_plan_end,
    cp.cin_team,
    cp.cin_worker_id
FROM
    cin_plans cp
INNER JOIN
    person p ON cp.la_person_id = p.la_person_id
WHERE
    cp.cin_plan_Start >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);



-- cin_visits
SELECT
/* Common AA fields */
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
        END) as CurrentAge, -- Calculated Age (Note on List 1 is 'AGE')
/* Returns fields */    
    cv.cin_visit_id,
    cv.cin_plan_id,
    cv.cin_visit_date,
    cv.cin_visit_seen,
    cv.cin_visit_seen_alone,
    cv.cin_visit_bedroom
FROM
    cin_visits cv
INNER JOIN
    person p ON cv.la_person_id = p.la_person_id
WHERE
    cv.cin_visit_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);


-- Ofsted List 4 - Assessments YYYY
-- assessments
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
    a.assessment_id,
    a.asmt_start_date,
    a.asmt_child_seen,
    a.asmt_auth_date as DateOfAuthorisation,
    -- ESCC Have SocialCareSupport? 
    a.asmt_outcome as OutcomeDesc1,
    a.asmt_team as AllocatedTeam,
    a.asmt_worker_id as AllocatedWorker,

    /* Disability field */
    d.person_disability

FROM
    assessments a
INNER JOIN
    person p ON a.la_person_id = p.la_person_id
LEFT JOIN   -- Using LEFT JOIN to ensure we get all records even if there's no matching disability
    disability d ON p.la_person_id = d.la_person_id
WHERE
    a.asmt_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH);



-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1
-- Ofsted List 5 - Section 47 Enquiries and ICPC OC YYYY
-- s47_enquiry_icpc
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
        END) as CurrentAge,
    
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



-- cp_visits
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
    cv.cp_plan_id,
    cv.cp_visit_id,
    cv.cp_visit_date,
    cv.cp_visit_seen,
    cv.cp_visit_seen_alone,
    cv.cp_visit_bedroom
FROM
    cp_visits cv
INNER JOIN
    person p ON cv.la_person_id = p.la_person_id
WHERE
    cv.cp_visit_date >= DATE_SUB(CURRENT_DATE, INTERVAL -12 MONTH);



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



-- Ofsted List 9 - Care Leavers YYYY
-- care_leavers
SELECT
    /* Common AA fields */ 
    p.la_person_id as ChildID,
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
    d.person_disability, /* Disability field */

    /* Immigration Status field */
    i.immigration_status,

    cl.care_leaver_id, 
    cl.cl_eligibility as EligibilityCategory,
    cl.cl_in_touch as LAinTouch,
    cl.cl_latest_contact as LatestDateofContact,
    cl.cl_accommodation as TypeofAccommodation,
    cl.cl_accom_suitable as SuitabilityofAccommodation,
    cl.cl_activity as ActivityStatus,
    cl.cl_pathway_plan_rev_date as LatestPathwayPlanReviewDate,
    cl.cl_personal_advisor as AllocatedPersonalAdvisor,
    cl.cl_team as AllocatedTeam,
    cl.cl_worker_id as AllocatedWorker
FROM
    care_leavers cl
INNER JOIN
    person p ON cl.la_person_id = p.la_person_id
LEFT JOIN   -- Using LEFT JOIN for disability table
    disability d ON cl.la_person_id = d.la_person_id
LEFT JOIN   -- Using LEFT JOIN for immigration_status table (UASC)
    immigration_status i ON cl.la_person_id = i.la_person_id
WHERE
    cl.cl_latest_contact >= DATE_SUB(CURRENT_DATE, INTERVAL 12 MONTH);
    
-- UASC, EndReasonDesc ??



--Ofsted List 10 - Adoption YYYY
-- cla_episodes
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    f.family_id as familyID, 
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
    ce.cla_epi_start as CLAStart,
    ce.cla_epi_start_reason as AdoptionDecision,
    ce.cla_primary_need,
    ce.cla_epi_ceased as AdoptionEndDecision,
    ce.cla_epi_cease_reason as AdoptionEndReason,
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
