-- disability
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    d.person_disability
FROM
    person p
INNER JOIN
    disability d ON p.la_person_id = d.la_person_id;


-- immigration_status
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    i.immigration_status,
    i.immigration_status_start,
    i.immigration_status_end
FROM
    person p
INNER JOIN
    immigration_status i ON p.la_person_id = i.la_person_id;

-- legal status
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    l.legal_status,
    l.legal_status_start,
    l.legal_status_end
FROM
    person p
INNER JOIN
    legal_status l ON p.la_person_id = l.la_person_id;

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
    -- ESCC have school data add-ons here
FROM
    person p
INNER JOIN
    contacts c ON p.la_person_id = c.la_person_id
WHERE
    c.contact_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);
    -- SQL Server: DATEADD(YEAR, -6, GETDATE())


-- early_help_episodes
SELECT
    /* Common AA fields */ 
    p.la_person_id,
    p.sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    YEAR(CURRENT_DATE) - YEAR(p.person_dob) - 
        (CASE 
            WHEN MONTH(CURRENT_DATE) < MONTH(p.person_dob) OR 
                (MONTH(CURRENT_DATE) = MONTH(p.person_dob) AND DAY(CURRENT_DATE) < DAY(p.person_dob)) THEN 1 
            ELSE 0 
        END) as CurrentAge, -- Calculated Age (Note on List 1 field is AGE)
    
    /* Returns fields */
    e.eh_episode_id,
    e.eh_epi_start_date as EHA_StartDate,
    e.eh_epi_end_date as EHA_CompletedDate,
    e.eh_epi_reason,        -- Towards ADCS_SP return
    e.eh_epi_end_reason,    -- Towards ADCS_SP return
    e.eh_epi_org as EHA_CompletedBy_Team,
    e.eh_epi_worker_id -- New Local field
FROM
    person p
INNER JOIN
    early_help_episodes e ON p.la_person_id = e.la_person_id
WHERE
    e.eh_epi_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);
    -- SQL Server: DATEADD(YEAR, -6, GETDATE())




-- cin_episodes 
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    ce.cin_referral_id,
    ce.cin_ref_date,
    ce.cin_primary_need,
    ce.cin_ref_source,
    ce.cin_ref_outcome,
    ce.cin_close_reason,
    ce.cin_close_date,
    ce.cin_ref_team,
    ce.cin_ref_worker_id
FROM
    person p
INNER JOIN
    cin_episodes ce ON p.la_person_id = ce.la_person_id
WHERE
    ce.cin_ref_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);
    -- SQL Server: DATEADD(YEAR, -6, GETDATE())



-- cin_plans
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    cp.cin_plan_id,
    cp.cin_plan_Start,
    cp.cin_plan_end,
    cp.cin_team,
    cp.cin_worker_id
FROM
    person p
INNER JOIN
    cin_plans cp ON p.la_person_id = cp.la_person_id
WHERE
    cp.cin_plan_Start >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);


-- cin_visits
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    cv.cin_visit_id,
    cv.cin_plan_id,
    cv.cin_visit_date,
    cv.cin_visit_seen,
    cv.cin_visit_seen_alone,
    cv.cin_visit_bedroom
FROM
    person p
INNER JOIN
    cin_visits cv ON p.la_person_id = cv.la_person_id
WHERE
    cv.cin_visit_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);



-- s47_enquiry_icpc
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    se.s47_enquiry_id,
    se.s47_start_date,
    se.s47_authorised_date,
    se.s47outcome,
    se.icpc_transfer_in,
    se.icpc_date,
    se.icpc_outcome,
    se.icpc_team,
    se.icpc_worker_id
FROM
    person p
INNER JOIN
    s47_enquiry_icpc se ON p.la_person_id = se.la_person_id
WHERE
    se.s47_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);


-- cp_plans
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    cp.cp_plan_id,
    cp.cpp_start_date,
    cp.cpp_end_date,
    cp.cpp_team,
    cp.cpp_worker_id
FROM
    person p
INNER JOIN
    cp_plans cp ON p.la_person_id = cp.la_person_id
WHERE
    cp.cpp_start_date >= DATE_ADD(CURRENT_DATE, INTERVAL -6 YEAR);


-- category_of_abuse
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    ca.cpp_category_id,
    ca.cp_plan_id,
    ca.cpp_category,
    ca.cpp_category_start
FROM
    person p
INNER JOIN
    category_of_abuse ca ON p.la_person_id = ca.la_person_id
WHERE
    ca.cpp_category_start >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);



-- cp_visits
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    cv.cp_plan_id,
    cv.cp_visit_id,
    cv.cp_visit_date,
    cv.cp_visit_seen,
    cv.cp_visit_seen_alone,
    cv.cp_visit_bedroom
FROM
    person p
INNER JOIN
    cp_visits cv ON p.la_person_id = cv.la_person_id
WHERE
    cv.cp_visit_date >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);



SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
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
    person p
INNER JOIN
    cp_reviews cr ON p.la_person_id = cr.la_person_id
WHERE
    cr.cp_rev_due >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);



SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    ce.cla_episode_id,
    ce.cla_epi_start,
    ce.cla_epi_start_reason,
    ce.cla_primary_need,
    ce.cla_epi_ceased,
    ce.cla_epi_cease_reason,
    ce.cla_team,
    ce.cla_worker_id
FROM
    person p
INNER JOIN
    cla_episodes ce ON p.la_person_id = ce.la_person_id
WHERE
    ce.cla_epi_start >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);



-- missing
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
    m.missing_episode_id,
    m.cla_episode_id,
    m.mis_epi_start,
    m.mis_epi_type,
    m.mis_epi_end,
    m.mis_epi_rhi_offered,
    m.mis_epi_rhi_accepted
FROM
    person p
INNER JOIN
    missing m ON p.la_person_id = m.la_person_id
WHERE
    m.mis_epi_start >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);




-- care_leavers
-- do we need to join up social workers
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
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
    person p
INNER JOIN
    care_leavers cl ON p.la_person_id = cl.la_person_id
WHERE
    cl.cl_latest_contact >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);




-- permanence
SELECT
    p.la_person_id,
    p.person_sex,
    p.person_gender,
    p.person_ethnicity,
    p.person_dob,
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
    person p
INNER JOIN
    permanence perm ON p.la_person_id = perm.la_person_id
WHERE
    perm.permanence_order_date >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);



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
    person p
INNER JOIN
    social_worker sw ON p.la_person_id = sw.la_person_id
WHERE
    sw.sw_epi_start_date >= DATE_SUB(CURRENT_DATE, INTERVAL 6 YEAR);
