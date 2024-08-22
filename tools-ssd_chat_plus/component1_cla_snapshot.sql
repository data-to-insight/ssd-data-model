/* 
Reductive views extract SQL - CLA snapshot
#DtoI-1647
*/

-- CTE most recent cla_episode
WITH RecentCLA AS (
    SELECT
        clae_cla_episode_id,
        clae_person_id,
        clae_cla_placement_id,
        clae_cla_episode_start_date,
        clae_cla_episode_ceased,
        clae_cla_episode_ceased_reason,
        clae_cla_id,
        clae_referral_id,
        ROW_NUMBER() OVER (PARTITION BY clae_person_id ORDER BY clae_cla_episode_start_date DESC) AS rn
    FROM
        ssd_development.ssd_cla_episodes
),
-- CTE most recent placement
RecentPlacement AS (
    SELECT
        clap_cla_placement_id,
        clap_cla_id,
        clap_person_id,
        clap_cla_placement_start_date,
        clap_cla_placement_type,
        ROW_NUMBER() OVER (PARTITION BY clap_person_id ORDER BY clap_cla_placement_start_date DESC) AS rn
    FROM
        ssd_development.ssd_cla_placement
),
-- CTE most recent legal status
RecentLegalStatus AS (
    SELECT
        lega_legal_status_id,
        lega_person_id,
        lega_legal_status,
        lega_legal_status_start_date,
        lega_legal_status_end_date,
        ROW_NUMBER() OVER (PARTITION BY lega_person_id ORDER BY lega_legal_status_start_date DESC) AS rn
    FROM
        ssd_development.ssd_legal_status
),
-- CTE most recent health check
RecentHealthCheck AS (
    SELECT
        clah_health_check_id,
        clah_person_id,
        clah_health_check_type,
        clah_health_check_date,
        clah_health_check_status,
        ROW_NUMBER() OVER (PARTITION BY clah_person_id ORDER BY clah_health_check_date DESC) AS rn
    FROM
        ssd_development.ssd_cla_health
),
-- CTE most recent visit
RecentVisit AS (
    SELECT
        clav_cla_visit_id,
        clav_cla_id,
        clav_person_id,
        clav_cla_visit_date,
        clav_cla_visit_seen,
        clav_cla_visit_seen_alone,
        ROW_NUMBER() OVER (PARTITION BY clav_person_id ORDER BY clav_cla_visit_date DESC) AS rn
    FROM
        ssd_development.ssd_cla_visits
),
-- CTE most recent review
RecentReview AS (
    SELECT
        clar_cla_review_id,
        clar_cla_id,
        clar_cla_review_due_date,
        clar_cla_review_date,
        clar_cla_review_cancelled,
        clar_cla_review_participation,
        ROW_NUMBER() OVER (PARTITION BY clar_cla_id ORDER BY clar_cla_review_date DESC) AS rn
    FROM
        ssd_development.ssd_cla_reviews
)

SELECT
    -- base ssd_person details
    p.pers_legacy_id                            AS legacy_id,
    p.pers_person_id                            AS person_id,
    p.pers_sex                                  AS sex,
    p.pers_gender                               AS gender,
    p.pers_ethnicity                            AS ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS pers_dob,
    p.pers_send_flag                            AS send_flag,
    FORMAT(p.pers_expected_dob, 'dd/MM/yyyy')   AS pers_expected_dob,
    FORMAT(p.pers_death_date, 'dd/MM/yyyy')     AS pers_death_date,
    p.pers_is_mother                            AS is_mother,
    p.pers_nationality                          AS nationality,
    p.ssd_flag                                  AS is_core_ssd_record,

    -- most recent ssd_cla_episodes
    cla.clae_cla_episode_id,                -- [TESTING]
    cla.clae_cla_placement_id,              -- [TESTING]
    FORMAT(cla.clae_cla_episode_start_date, 'dd/MM/yyyy')   AS cla_episode_start_date,
    cla.clae_cla_id,                        -- [TESTING]
    cla.clae_referral_id,                   -- [TESTING]

    -- most recent ssd_cla_placement
    pl.clap_cla_placement_id,               -- [TESTING]
    FORMAT(pl.clap_cla_placement_start_date, 'dd/MM/yyyy')  AS cla_placement_start_date,
    pl.clap_cla_placement_type,

    -- most recent ssd_legal_status
    ls.lega_legal_status,
    FORMAT(ls.lega_legal_status_start_date, 'dd/MM/yyyy')   AS legal_status_start_date,
    FORMAT(ls.lega_legal_status_end_date, 'dd/MM/yyyy')     AS legal_status_end_date,

    -- most recent ssd_cla_health
    hc.clah_health_check_type,
    FORMAT(hc.clah_health_check_date, 'dd/MM/yyyy')         AS health_check_date,
    hc.clah_health_check_status,

    -- most recent ssd_cla_visit
    FORMAT(v.clav_cla_visit_date, 'dd/MM/yyyy')             AS clav_cla_visit_date,
    v.clav_cla_visit_seen,
    v.clav_cla_visit_seen_alone,

    -- ssd_cla_reviews
    FORMAT(r.clar_cla_review_date, 'dd/MM/yyyy')            AS cla_review_date,
    FORMAT(r.clar_cla_review_due_date, 'dd/MM/yyyy')        AS cla_review_due_date,
    r.clar_cla_review_cancelled,
    r.clar_cla_review_participation

FROM
    ssd_development.ssd_person AS p
    
LEFT JOIN
    RecentCLA AS cla ON p.pers_person_id = cla.clae_person_id AND cla.rn = 1
LEFT JOIN
    RecentPlacement AS pl ON p.pers_person_id = pl.clap_person_id AND pl.rn = 1
LEFT JOIN
    RecentLegalStatus AS ls ON p.pers_person_id = ls.lega_person_id AND ls.rn = 1
LEFT JOIN
    RecentHealthCheck AS hc ON p.pers_person_id = hc.clah_person_id AND hc.rn = 1
LEFT JOIN
    RecentVisit AS v ON p.pers_person_id = v.clav_person_id AND v.rn = 1
LEFT JOIN
    RecentReview AS r ON cla.clae_cla_id = r.clar_cla_id AND r.rn = 1

-- join to ssd_cin_episodes and filter on cine_close_date being NULL
JOIN
    ssd_development.ssd_cin_episodes AS cine ON p.pers_person_id = cine.cine_person_id
    AND cine.cine_close_date IS NULL;