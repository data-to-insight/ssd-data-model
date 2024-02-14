
/*
****************************************
CLA Cohort Reductive View || SQL Server
****************************************
*/


/* 
=============================================================================
Report Name: CLA Cohort
Description: 
            ""
Author: D2I
Last Modified Date: 13/02/24
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_cla_health
- ssd_cla_placement
- ssd_legal_status
- ssd_cla_reviews
- ssd_immigration_status
=============================================================================
*/

SELECT
-- from ssd_cla_episodes
    e.clae_cla_episode_id                   AS episode_id,
    e.clae_person_id                        AS child_id,
    e.clae_cla_episode_start                AS episode_start,
    e.clae_cla_episode_start_reason         AS episode_start_reason,
    e.clae_cla_primary_need                 AS primary_need,
    e.clae_cla_episode_ceased               AS episode_ceased,
    e.clae_cla_episode_cease_reason         AS episode_cease_reason,
    e.clae_cla_id                           AS cla_id,          -- Not requ? 
    e.clae_referral_id                      AS referral_id,
    e.clae_cla_review_last_iro_contact_date AS review_last_iro_contact_date,
    -- from ssd_cla_placement
    p.clap_cla_placement_id                 AS placement_id,    -- Not requ? 
    p.clap_cla_placement_start_date         AS placement_start_date,
    p.clap_cla_placement_type               AS placement_type,
    p.clap_cla_placement_urn                AS placement_urn,
    p.clap_cla_placement_distance           AS placement_distance,
    p.clap_cla_placement_la                 AS placement_la,
    p.clap_cla_placement_provider           AS placement_provider,
    p.clap_cla_placement_postcode           AS placement_postcode,
    p.clap_cla_placement_end_date           AS placement_end_date,
    p.clap_cla_placement_change_reason      AS placement_change_reason,
    -- from ssd_cla_health 
    h.clah_health_check_id                  AS health_check_id,  -- Not requ? 
    h.clah_health_check_type                AS health_check_type,
    h.clah_health_check_date                AS health_check_date,
    h.clah_health_check_status              AS health_check_status,
    -- most recent legal status
    ls.lega_legal_status                    AS legal_status,
    ls.lega_legal_status_start              AS legal_status_start,
    ls.lega_legal_status_end                AS legal_status_end,
    -- most recent immigration status (flag) (need to check actual string value to match on...not yet checked)
    CASE         
        -- Is UASC?                                            
        WHEN latest_status.immi_immigration_status = 'Unaccompanied Asylum Seeking Child (UASC)' THEN 'Y'
        ELSE 'N'
    END                                     AS uasc_status,
    -- most recent review dets
    r.clar_cla_review_id                    AS cla_review_id,
    r.clar_cla_review_due_date              AS cla_review_due_date,
    r.clar_cla_review_date                  AS cla_review_date,
    r.clar_cla_review_cancelled             AS cla_review_cancelled,
    r.clar_cla_review_participation         AS cla_review_participation,
    -- most recent visit dets
    clav.clav_casenote_id                   AS casenote_id,     -- Not requ? 
    clav.clav_cla_id                        AS cla_id ,         -- Not requ?         
    clav.clav_cla_visit_date                AS cla_visit_date,      
    clav.clav_cla_visit_seen                AS cla_visit_seen,        
    clav.clav_cla_visit_seen_alone          AS cla_visit_seen_alone

FROM
    #ssd_cla_episodes e

LEFT JOIN ssd_cla_placement p ON e.clae_cla_id = p.clap_cla_id
LEFT JOIN ssd_cla_health h ON e.clae_person_id = h.clah_person_id
LEFT JOIN (
    SELECT
        -- partitioning by lega_person_id
        lega_person_id,
        lega_legal_status,
        lega_legal_status_start,
        lega_legal_status_end,
        
        ROW_NUMBER() OVER (PARTITION BY lega_person_id -- assign unique row num (most recent rn ===1)
        ORDER BY lega_legal_status_start DESC) AS rn
    FROM 
        #ssd_legal_status
) ls ON e.clae_person_id = ls.lega_person_id AND ls.rn = 1
LEFT JOIN (
    SELECT
        -- partitioning by clar_cla_id
        clar_cla_id,
        clar_cla_review_id,
        clar_cla_review_due_date,
        clar_cla_review_date,
        clar_cla_review_cancelled,
        clar_cla_review_participation,
        
        ROW_NUMBER() OVER (PARTITION BY clar_cla_id -- assign unique row num (most recent rn ===1)
        ORDER BY clar_cla_review_date DESC) AS rn
    FROM 
        #ssd_cla_reviews
) r ON e.clae_cla_id = r.clar_cla_id AND r.rn = 1;
LEFT JOIN (
    SELECT
        -- partitioning by clav_cla_id (or should this be clav_person_id??)
        clav_cla_visit_id,
        clav_casenote_id,
        clav_person_id,
        clav_cla_id,
        clav_cla_visit_date,
        clav_cla_visit_seen,
        clav_cla_visit_seen_alone

        ROW_NUMBER() OVER (PARTITION BY clav_cla_id -- assign unique row num (most recent rn ===1)
        ORDER BY clav_cla_visit_date DESC) AS rn
    FROM 
        #ssd_cla_visits
) v ON e.clae_cla_id = v.clav_cla_id AND v.rn = 1
LEFT JOIN  
    (    -- most recent immigration status
        SELECT 
            -- partitioning by immi_person_id (group by each person) 
            immi_person_id,
            immi_immigration_status,
            ROW_NUMBER() OVER (PARTITION BY immi_person_id -- assign unique row num (most recent rn ===1)
            -- get latest status based on end date, (using start date as a secondary order in case of ties or NULL end dates)
            ORDER BY immi_immigration_status_start DESC, immi_immigration_status_end DESC) AS rn
        FROM 
            #ssd_immigration_status
    ) latest_status ON clae.clae_person_id = latest_status.immi_person_id AND latest_status.rn = 1;