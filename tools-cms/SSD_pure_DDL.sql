

-- Create structure
CREATE TABLE ssd_person (
    pers_legacy_id          NVARCHAR(48),
    pers_person_id          NVARCHAR(48) PRIMARY KEY,
    pers_sex                NVARCHAR(48),
    pers_gender             NVARCHAR(48),                   
    pers_ethnicity          NVARCHAR(38),
    pers_dob                DATETIME,
    pers_common_child_id    NVARCHAR(10),                   -- [TESTING] [Takes NHS Number]
    pers_upn_unknown        NVARCHAR(10),
    pers_send               NVARCHAR(1),
    pers_expected_dob       DATETIME,                       -- Date or NULL
    pers_death_date         DATETIME,
    pers_is_mother          NVARCHAR(48),
    pers_nationality        NVARCHAR(48)
);
 

 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_person_la_person_id ON ssd_person(pers_person_id);
 


-- Create structure
CREATE TABLE ssd_family (
    fami_table_id           NVARCHAR(48) PRIMARY KEY, 
    fami_family_id          NVARCHAR(48),
    fami_person_id          NVARCHAR(48)
);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_family_person_id ON ssd_family(fami_person_id);

-- Create constraint(s)
ALTER TABLE ssd_family ADD CONSTRAINT FK_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);



-- Create structure
CREATE TABLE ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,
    addr_person_id          NVARCHAR(48), 
    addr_address_type       NVARCHAR(48),
    addr_address_start      DATETIME,
    addr_address_end        DATETIME,
    addr_address_postcode   NVARCHAR(15),
    addr_address_json       NVARCHAR(1000)
);




-- Create constraint(s)
ALTER TABLE ssd_address ADD CONSTRAINT FK_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_address_person ON ssd_address(addr_person_id);
CREATE NONCLUSTERED INDEX idx_address_start ON ssd_address(addr_address_start);
CREATE NONCLUSTERED INDEX idx_address_end ON ssd_address(addr_address_end);





-- Create the structure
CREATE TABLE ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,
    disa_person_id          NVARCHAR(48) NOT NULL,
    disa_disability_code    NVARCHAR(48) NOT NULL
);




    
-- Create constraint(s)
ALTER TABLE ssd_disability ADD CONSTRAINT FK_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_disability_person_id ON ssd_disability(disa_person_id);



-- Create structure
CREATE TABLE ssd_immigration_status (
    immi_immigration_status_id      NVARCHAR(48) PRIMARY KEY,
    immi_person_id                  NVARCHAR(48),
    immi_immigration_status_start   DATETIME,
    immi_immigration_status_end     DATETIME,
    immi_immigration_status         NVARCHAR(48)
);



-- Create constraint(s)
ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id);
CREATE NONCLUSTERED INDEX idx_immigration_status_start ON ssd_immigration_status(immi_immigration_status_start);
CREATE NONCLUSTERED INDEX idx_immigration_status_end ON ssd_immigration_status(immi_immigration_status_end);




-- Create structure
CREATE TABLE ssd_mother (
    moth_table_id               NVARCHAR(48) PRIMARY KEY,
    moth_person_id              NVARCHAR(48),
    moth_childs_person_id       NVARCHAR(48),
    moth_childs_dob             DATETIME
);
 

 
-- Create index(es)
CREATE INDEX idx_ssd_mother_moth_person_id ON ssd_mother(moth_person_id);

-- Add constraint(s)
ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);

-- [TESTING]
ALTER TABLE ssd_mother ADD CONSTRAINT CHK_NoSelfParenting -- Ensure data not contains person from being their own mother
CHECK (moth_person_id <> moth_childs_person_id);



-- Create structure
CREATE TABLE ssd_legal_status (
    lega_legal_status_id        NVARCHAR(48) PRIMARY KEY,
    lega_person_id              NVARCHAR(48),
    lega_legal_status           NVARCHAR(100),
    lega_legal_status_start     DATETIME,
    lega_legal_status_end       DATETIME
);
 

 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_lega_person_id ON ssd_legal_status(lega_person_id);

-- Create constraint(s)
ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id);



-- Create structure
CREATE TABLE ssd_contacts (
    cont_contact_id             NVARCHAR(48) PRIMARY KEY,
    cont_person_id              NVARCHAR(48),
    cont_contact_date           DATETIME,
    cont_contact_source_code    NVARCHAR(48),   -- 
    cont_contact_source_desc    NVARCHAR(255),  -- 
    cont_contact_outcome_json   NVARCHAR(500) 
);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_contact_person_id ON ssd_contacts(cont_person_id);


-- Create constraint(s)
ALTER TABLE ssd_contacts ADD CONSTRAINT FK_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id);


-- Create structure
CREATE TABLE ssd_early_help_episodes (
    earl_episode_id         NVARCHAR(48) PRIMARY KEY,
    earl_person_id          NVARCHAR(48),
    earl_episode_start_date DATETIME,
    earl_episode_end_date   DATETIME,
    earl_episode_reason     NVARCHAR(MAX),
    earl_episode_end_reason NVARCHAR(MAX),
    earl_episode_organisation NVARCHAR(MAX),
    earl_episode_worker_id  NVARCHAR(48)
);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_early_help_episodes_person_id ON ssd_early_help_episodes(earl_person_id);

-- Create constraint(s)
ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);



-- Create structure
CREATE TABLE ssd_cin_episodes
(
    cine_referral_id            INT,
    cine_person_id              NVARCHAR(48),
    cine_referral_date          DATETIME,
    cine_cin_primary_need       NVARCHAR(10),
    cine_referral_source        NVARCHAR(48),    
    cine_referral_source_desc   NVARCHAR(255),
    cine_referral_outcome_json  NVARCHAR(500),
    cine_referral_nfa           NCHAR(1),
    cine_close_reason           NVARCHAR(100),
    cine_close_date             DATETIME,
    cine_referral_team          NVARCHAR(255),
    cine_referral_worker_id     NVARCHAR(48)
);
 


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_episodes_person_id ON ssd_cin_episodes(cine_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);



-- Create structure
CREATE TABLE ssd_cin_assessments
(
    cina_assessment_id          NVARCHAR(48) PRIMARY KEY,
    cina_person_id              NVARCHAR(48),
    cina_referral_id            NVARCHAR(48),
    cina_assessment_start_date  DATETIME,
    cina_assessment_child_seen  NCHAR(1), 
    cina_assessment_auth_date   DATETIME,               -- This needs checking !! [TESTING]
    cina_assessment_outcome_json NVARCHAR(1000),        -- enlarged due to comments field    
    cina_assessment_outcome_nfa NCHAR(1), 
    cina_assessment_team        NVARCHAR(255),
    cina_assessment_worker_id   NVARCHAR(48)
);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_assessments_person_id ON ssd_cin_assessments(cina_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);


-- #DtoI-1564 121223 RH [TESTING]
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_ssd_involvements
FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_involvements(invo_professional_id);





-- Create structure
CREATE TABLE ssd_assessment_factors (
    cinf_table_id                    NVARCHAR(48) PRIMARY KEY,
    cinf_assessment_id               NVARCHAR(48),
    cinf_assessment_factors_json     NVARCHAR(500) -- size might need testing
);




-- Add constraint(s)
ALTER TABLE ssd_assessment_factors ADD CONSTRAINT FK_cinf_assessment_id
FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_cin_assessments(cina_assessment_id);




-- Create structure
CREATE TABLE ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,
    cinp_referral_id            NVARCHAR(48),
    cinp_person_id              NVARCHAR(48),
    cinp_cin_plan_start         DATETIME,
    cinp_cin_plan_end           DATETIME,
    cinp_cin_plan_team          NVARCHAR(255),
    cinp_cin_plan_worker_id     NVARCHAR(48)
);
 


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_plans_person_id ON ssd_cin_plans(cinp_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id);


-- Create structure
CREATE TABLE ssd_cin_visits
(
    -- cinv_cin_casenote_id,                -- [DEPRECIATED in Iteration1] [TESTING]
    -- cinv_cin_plan_id,                    -- [DEPRECIATED in Iteration1] [TESTING]
    cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,      
    cinv_person_id              NVARCHAR(48),
    cinv_cin_visit_date         DATETIME,
    cinv_cin_visit_seen         NCHAR(1),
    cinv_cin_visit_seen_alone   NCHAR(1),
    cinv_cin_visit_bedroom      NCHAR(1)
);
 


-- Create constraint(s)
ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
FOREIGN KEY (cinv_person_id) REFERENCES ssd_person(pers_person_id);
 

-- Create structure 
CREATE TABLE ssd_s47_enquiry (
    s47e_s47_enquiry_id             NVARCHAR(48) PRIMARY KEY,
    s47e_referral_id                NVARCHAR(48),
    s47e_person_id                  NVARCHAR(48),
    s47e_s47_start_date             DATETIME,
    s47e_s47_end_date               DATETIME,
    s47e_s47_nfa                    NCHAR(1),
    s47e_s47_outcome_json           NVARCHAR(1000),
    s47e_s47_completed_by_team      NVARCHAR(100),
    s47e_s47_completed_by_worker    NVARCHAR(48)
);




-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_person_id ON ssd_s47_enquiry(s47e_person_id);

-- Create constraint(s)
ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_s47_person
FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id);


-- Create structure
CREATE TABLE ssd_initial_cp_conference (
    icpc_icpc_id                    NVARCHAR(48) PRIMARY KEY,
    icpc_icpc_meeting_id            NVARCHAR(48),
    icpc_s47_enquiry_id             NVARCHAR(48),
    icpc_person_id                  NVARCHAR(48),
    icpc_cp_plan_id                 NVARCHAR(48),
    icpc_referral_id                NVARCHAR(48),
    icpc_icpc_transfer_in           NCHAR(1),
    icpc_icpc_target_date           DATETIME,
    icpc_icpc_date                  DATETIME,
    icpc_icpc_outcome_cp_flag       NCHAR(1),
    icpc_icpc_outcome_json          NVARCHAR(1000),
    icpc_icpc_team                  NVARCHAR(100),
    icpc_icpc_worker_id             NVARCHAR(48)
);
 
 
-- Create index(es)
CREATE INDEX idx_ssd_initial_cp_conference_ ON ssd_initial_cp_conference(icpc_person_id);

-- Create constraint(s)
ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_s47_enquiry_id
FOREIGN KEY (icpc_s47_enquiry_id) REFERENCES ssd_s47_enquiry(s47e_s47_enquiry_id);

ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_person_id
FOREIGN KEY (icpc_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_referral_id
FOREIGN KEY (icpc_referral_id) REFERENCES ssd_cin_episodes(cine_referral_id);



-- Create structure
CREATE TABLE ssd_cp_plans (
    cppl_cp_plan_id                   NVARCHAR(48) PRIMARY KEY,
    cppl_referral_id                  NVARCHAR(48),
    cppl_initial_cp_conference_id     NVARCHAR(48),
    cppl_person_id                    NVARCHAR(48),
    cppl_cp_plan_start_date           DATETIME,
    cppl_cp_plan_end_date             DATETIME,
    cppl_cp_plan_ola                  NVARCHAR(1),        
    cppl_cp_plan_initial_category     NVARCHAR(100),
    cppl_cp_plan_latest_category      NVARCHAR(100)
);
 
 



-- Create index(es)
CREATE INDEX idx_ssd_cp_plans_ ON ssd_cp_plans(cppl_person_id);


-- Create constraint(s)
ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_person_id
FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_initial_cp_conference_id
FOREIGN KEY (cppl_initial_cp_conference_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id);



 
-- Create structure
CREATE TABLE ssd_cp_visits (
    cppv_cp_visit_id         NVARCHAR(48),-- PRIMARY KEY,  
    cppv_person_id           NVARCHAR(48),
    cppv_cp_plan_id          NVARCHAR(48),
    cppv_casenote_date       DATETIME,
    cppv_cp_visit_date       DATETIME,
    cppv_cp_visit_seen       NCHAR(1),
    cppv_cp_visit_seen_alone NCHAR(1),
    cppv_cp_visit_bedroom    NCHAR(1)
);
 

-- Create index(es)
CREATE INDEX idx_cppv_person_id ON ssd_cp_visits(cppv_person_id);


-- Create constraint(s)
ALTER TABLE ssd_cp_visits ADD CONSTRAINT FK_cppv_to_cppl
FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


 
-- Create structure
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,
    cppr_person_id                      NVARCHAR(48),
    cppr_cp_plan_id                     NVARCHAR(48),    
    cppr_cp_review_due                  DATETIME NULL,
    cppr_cp_review_date                 DATETIME NULL,
    cppr_cp_review_meeting_id           NVARCHAR(48),      
    cppr_cp_review_outcome_continue_cp  NCHAR(1),
    cppr_cp_review_quorate              NVARCHAR(18),      
    cppr_cp_review_participation        NVARCHAR(18)        -- ['PLACEHOLDER_DATA'][TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
);
 


-- Add constraint(s)
ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


 
-- Create structure
CREATE TABLE ssd_cla_episodes (
    clae_cla_episode_id                 NVARCHAR(48) PRIMARY KEY,
    clae_person_id                      NVARCHAR(48),
    clae_cla_episode_start              DATETIME,
    clae_cla_episode_start_reason       NVARCHAR(100),
    clae_cla_primary_need               NVARCHAR(100),
    clae_cla_episode_ceased             DATETIME,
    clae_cla_episode_cease_reason       NVARCHAR(255),
    clae_cla_id                         NVARCHAR(48),
    clae_referral_id                    NVARCHAR(48),
    clae_cla_review_last_iro_contact_date DATETIME
);
 


-- Create index(es)


-- Add constraint(s)
ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_person 
FOREIGN KEY (clae_person_id) REFERENCES ssd_person (pers_person_id);



-- create structure
CREATE TABLE ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,
    clac_person_id              NVARCHAR(48),
    clac_cla_conviction_date    DATETIME,
    clac_cla_conviction_offence NVARCHAR(1000)
);


-- add constraint(s)
ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id);



-- create structure
CREATE TABLE ssd_cla_health (
    clah_health_check_id             NVARCHAR(48) PRIMARY KEY,
    clah_person_id                   NVARCHAR(48),
    clah_health_check_type           NVARCHAR(500),
    clah_health_check_date           DATETIME,
    clah_health_check_status         NVARCHAR(48)
);
 

-- add constraint(s)
ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clah_person_id ON ssd_cla_health (clah_person_id);



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_cla_immunisations;

-- Create structure 
CREATE TABLE ssd_cla_immunisations (
    clai_immunisations_id          NVARCHAR(48) PRIMARY KEY,
    clai_person_id                 NVARCHAR(48),
    clai_immunisations_status      NCHAR(1)
);


-- add constraint(s)
ALTER TABLE ssd_cla_immunisations
ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clai_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)


-- Create structure 
CREATE TABLE ssd_cla_substance_misuse (
    clas_substance_misuse_id       NVARCHAR(48) PRIMARY KEY,
    clas_person_id                 NVARCHAR(48),
    clas_substance_misuse_date     DATETIME,
    clas_substance_misused         NVARCHAR(100),
    clas_intervention_received     NCHAR(1)
);


-- Add constraint(s)
ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

CREATE NONCLUSTERED INDEX idx_clas_person_id ON ssd_cla_substance_misuse (clas_person_id);


-- Create structure
CREATE TABLE ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,
    clap_cla_id                         NVARCHAR(48),
    clap_cla_placement_start_date       DATETIME,
    clap_cla_placement_type             NVARCHAR(100),
    clap_cla_placement_urn              NVARCHAR(48),
    clap_cla_placement_distance         FLOAT, -- Float precision determined by value (or use DECIMAL(3, 2), -- Adjusted to fixed precision)
    clap_cla_placement_la               NVARCHAR(48),
    clap_cla_placement_provider         NVARCHAR(48),
    clap_cla_placement_postcode         NVARCHAR(8),
    clap_cla_placement_end_date         DATETIME,
    clap_cla_placement_change_reason    NVARCHAR(100)
);
 

-- Add constraint(s)
ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_clap_to_clae 
FOREIGN KEY (clap_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clap_cla_placement_urn  ON ssd_cla_placement (clap_cla_placement_urn );


-- Create structure
CREATE TABLE ssd_cla_reviews (
    clar_cla_review_id                      NVARCHAR(48) PRIMARY KEY,
    clar_cla_id                             NVARCHAR(48),
    clar_cla_review_due_date                DATETIME,
    clar_cla_review_date                    DATETIME,
    clar_cla_review_cancelled               NVARCHAR(48),
    clar_cla_review_participation           NVARCHAR(100)
    );
 


-- Add constraint(s)
ALTER TABLE ssd_cla_reviews ADD CONSTRAINT FK_clar_to_clae 
FOREIGN KEY (clar_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

-- Create index(es)




-- Create structure
CREATE TABLE ssd_cla_previous_permanence (
    lapp_table_id                               NVARCHAR(48) PRIMARY KEY,
    lapp_person_id                              NVARCHAR(48),
    lapp_previous_permanence_option             NVARCHAR(200),
    lapp_previous_permanence_la                 NVARCHAR(100),
    lapp_previous_permanence_order_date_json    NVARCHAR(MAX)
);



-- create index(es)


-- Add constraint(s)
ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);




-- Create structure
CREATE TABLE ssd_cla_care_plan (
    lacp_table_id                       NVARCHAR(48) PRIMARY KEY,
    lacp_person_id                      NVARCHAR(48),
    --lacp_referral_id                  NVARCHAR(48),
    lacp_cla_care_plan_start_date       DATETIME,
    lacp_cla_care_plan_end_date         DATETIME,
    lacp_cla_care_plan_json             NVARCHAR(1000)
);
 


-- Add constraint(s)
ALTER TABLE ssd_cla_care_plan ADD CONSTRAINT FK_lacp_person_id
FOREIGN KEY (lacp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


-- Create structure
CREATE TABLE ssd_cla_visits (
    clav_cla_visit_id          NVARCHAR(48) PRIMARY KEY,
    clav_cla_id                NVARCHAR(48),
    clav_person_id             NVARCHAR(48),
    clav_casenote_id           NVARCHAR(48),
    clav_cla_visit_date        DATETIME,
    clav_cla_visit_seen        NCHAR(1),
    clav_cla_visit_seen_alone  NCHAR(1)
);
 

-- Add constraint(s)
ALTER TABLE ssd_cla_visits ADD CONSTRAINT FK_clav_person_id
FOREIGN KEY (clav_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


/* V8.1 */
-- Create structure
CREATE TABLE ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48), -- PRIMARY KEY,
    csdq_person_id              NVARCHAR(48),
    csdq_sdq_score              NVARCHAR(48),
    csdq_sdq_details_json       NVARCHAR(1000),
    csdq_sdq_reason             NVARCHAR(48)
);
 

 
-- non-spec column clean-up
ALTER TABLE ssd_sdq_scores DROP COLUMN csdq_sdq_score;
 

-- Create structure
CREATE TABLE ssd_missing (
    miss_table_id               NVARCHAR(48) PRIMARY KEY,
    miss_person_id              NVARCHAR(48),
    miss_missing_episode_start  DATETIME,
    miss_missing_episode_type   NVARCHAR(100),
    miss_missing_episode_end    DATETIME,
    miss_missing_rhi_offered    NVARCHAR(10),                   -- [TESTING] Confirm source data/why >7 required
    miss_missing_rhi_accepted   NVARCHAR(10)                    -- [TESTING] Confirm source data/why >7 required
);



-- Add constraint(s)
ALTER TABLE ssd_missing ADD CONSTRAINT FK_missing_to_person
FOREIGN KEY (miss_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)




-- Create structure
CREATE TABLE ssd_care_leavers
(
    clea_table_id                           NVARCHAR(48),
    clea_person_id                          NVARCHAR(48),
    clea_care_leaver_eligibility            NVARCHAR(100),
    clea_care_leaver_in_touch               NVARCHAR(100),
    clea_care_leaver_latest_contact         DATETIME,
    clea_care_leaver_accommodation          NVARCHAR(100),
    clea_care_leaver_accom_suitable         NVARCHAR(100),
    clea_care_leaver_activity               NVARCHAR(100),
    clea_pathway_plan_review_date           DATETIME,
    clea_care_leaver_personal_advisor       NVARCHAR(100),
    clea_care_leaver_allocated_team_name    NVARCHAR(48),
    clea_care_leaver_worker_name            NVARCHAR(48)        
);



-- Add index(es)
CREATE INDEX idx_clea_person_id ON ssd_care_leavers(clea_person_id);
CREATE NONCLUSTERED INDEX idx_clea_care_leaver_activity ON ssd_care_leavers (clea_care_leaver_activity);



-- Add constraint(s)
ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leavers_person
FOREIGN KEY (clea_person_id) REFERENCES ssd_person(pers_person_id);


-- Removed as worker details directly pulled through
-- ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leaver_worker
-- FOREIGN KEY (clea_care_leaver_worker_id) REFERENCES ssd_involvements(invo_professional_id);


-- Create structure
CREATE TABLE ssd_permanence (
    perm_table_id                        NVARCHAR(48) PRIMARY KEY,
    perm_person_id                       NVARCHAR(48),
    perm_cla_id                          NVARCHAR(48),
    perm_entered_care_date               DATETIME,              
    perm_adm_decision_date               DATETIME,
    perm_part_of_sibling_group           NCHAR(1),
    perm_siblings_placed_together        INT,
    perm_siblings_placed_apart           INT,
    perm_ffa_cp_decision_date            DATETIME,              
    perm_placement_order_date            DATETIME,
    perm_matched_date                    DATETIME,
    perm_placed_for_adoption_date        DATETIME,              
    perm_adopted_by_carer_flag           NCHAR(1),              -- [TESTING] (datatype changed)
    perm_placed_ffa_cp_date              DATETIME,
    perm_placed_foster_carer_date        DATETIME,
    perm_placement_provider_urn          NVARCHAR(48),  
    perm_decision_reversed_date          DATETIME,                  
    perm_decision_reversed_reason        NVARCHAR(100),
    perm_permanence_order_date           DATETIME,              
    perm_permanence_order_type           NVARCHAR(100),        
    perm_adoption_worker                 NVARCHAR(100),          -- [TESTING] (datatype changed)
    perm_adopter_sex                     NVARCHAR(48),
    perm_adopter_legal_status            NVARCHAR(100),
    perm_number_of_adopters              NVARCHAR(3)
);
 
 

-- Add constraint(s)
ALTER TABLE ssd_permanence ADD CONSTRAINT FK_perm_person_id
FOREIGN KEY (perm_person_id) REFERENCES ssd_cla_episodes(clae_person_id);




-- Create structure
CREATE TABLE ssd_professionals (
    prof_table_id                         NVARCHAR(48) PRIMARY KEY,
    prof_professional_id                  NVARCHAR(48),
    prof_social_worker_registration_no    NVARCHAR(48),
    prof_agency_worker_flag               NCHAR(1),
    prof_professional_job_title           NVARCHAR(500),
    prof_professional_caseload            INT,              -- aggr result field
    prof_professional_department          NVARCHAR(100),
    prof_full_time_equivalency            FLOAT
);




-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prof_professional_id ON ssd_professionals (prof_professional_id);



-- Create structure
CREATE TABLE ssd_involvements (
    invo_involvements_id             NVARCHAR(48) PRIMARY KEY,
    invo_professional_id             NVARCHAR(48),
    invo_professional_role_id        NVARCHAR(200),
    invo_professional_team           NVARCHAR(200),
    invo_involvement_start_date      DATETIME,
    invo_involvement_end_date        DATETIME,
    invo_worker_change_reason        NVARCHAR(200),
    invo_referral_id                 NVARCHAR(48)
);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_invo_professional_id ON ssd_involvements (invo_professional_id);
CREATE NONCLUSTERED INDEX idx_invo_professional_role_id ON ssd_involvements (invo_professional_role_id);
CREATE NONCLUSTERED INDEX idx_invo_professional_team ON ssd_involvements (invo_professional_team);


-- Add constraint(s)
ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional 
FOREIGN KEY (invo_professional_id) REFERENCES ssd_professionals (prof_professional_id);

ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional_role 
FOREIGN KEY (invo_professional_role_id) REFERENCES ssd_professionals (prof_social_worker_registration_no);



-- Create structure
CREATE TABLE ssd_linked_identifiers (
    link_link_id            NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),
    link_person_id          NVARCHAR(48), 
    link_identifier_type    NVARCHAR(100),
    link_identifier_value   NVARCHAR(100),
    link_valid_from_date    DATETIME,
    link_valid_to_date      DATETIME
);


-- Create constraint(s)
ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);




-- Create structure
CREATE TABLE ssd_s251_finance (
    s251_id                 NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),
    s251_cla_placement_id   NVARCHAR(48), 
    s251_placeholder_1      NVARCHAR(48),
    s251_placeholder_2      NVARCHAR(48),
    s251_placeholder_3      NVARCHAR(48),
    s251_placeholder_4      NVARCHAR(48)
);



-- Create constraint(s)
ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);



-- Create structure
CREATE TABLE ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),
    voch_person_id              NVARCHAR(48), 
    voch_explained_worries      NCHAR(1), 
    voch_story_help_understand  NCHAR(1), 
    voch_agree_worker           NCHAR(1), 
    voch_plan_safe              NCHAR(1), 
    voch_tablet_help_explain    NCHAR(1)
);


-- Create constraint(s)
ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);



-- Create structure
CREATE TABLE ssd_pre_proceedings (
    prep_table_id                       NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),
    prep_person_id                      NVARCHAR(48),
    prep_plo_family_id                  NVARCHAR(48),
    prep_pre_pro_decision_date          DATETIME,
    prep_initial_pre_pro_meeting_date   DATETIME,
    prep_pre_pro_outcome                NVARCHAR(100),
    prep_agree_stepdown_issue_date      DATETIME,
    prep_cp_plans_referral_period       INT, -- count cp plans the child has been subject within referral period (cin episode)
    prep_legal_gateway_outcome          NVARCHAR(100),
    prep_prev_pre_proc_child            INT,
    prep_prev_care_proc_child           INT,
    prep_pre_pro_letter_date            DATETIME,
    prep_care_pro_letter_date           DATETIME,
    prep_pre_pro_meetings_num           INT,
    prep_pre_pro_parents_legal_rep      NCHAR(1), 
    prep_parents_legal_rep_point_of_issue NCHAR(2),
    prep_court_reference                NVARCHAR(48),
    prep_care_proc_court_hearings       INT,
    prep_care_proc_short_notice         NCHAR(1), 
    prep_proc_short_notice_reason       NVARCHAR(100),
    prep_la_inital_plan_approved        NCHAR(1), 
    prep_la_initial_care_plan           NVARCHAR(100),
    prep_la_final_plan_approved         NCHAR(1), 
    prep_la_final_care_plan             NVARCHAR(100)
);



-- Create constraint(s)
ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prep_person_id ON ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_prep_pre_pro_decision_date ON ssd_pre_proceedings (prep_pre_pro_decision_date);

CREATE NONCLUSTERED INDEX idx_prep_legal_gateway_outcome ON ssd_pre_proceedings (prep_legal_gateway_outcome);



-- Create structure 
CREATE TABLE ssd_send (
    send_table_id       NVARCHAR(48),
    send_person_id      NVARCHAR(48),
    send_upn            NVARCHAR(48),
    send_uln            NVARCHAR(48),
    upn_unknown         NVARCHAR(48)
    );


-- Add constraint(s)
ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);


-- Create structure
CREATE TABLE ssd_ehcp_requests (
    ehcr_ehcp_request_id NVARCHAR(48),
    ehcr_send_table_id NVARCHAR(48),
    ehcr_ehcp_req_date DATETIME,
    ehcr_ehcp_req_outcome_date DATETIME,
    ehcr_ehcp_req_outcome NVARCHAR(100)
);



-- Create constraint(s)
ALTER TABLE ssd_ehcp_requests
ADD CONSTRAINT FK_ehcp_requests_send
FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_send(send_table_id);



-- Create ssd_ehcp_assessment table
CREATE TABLE ssd_ehcp_assessment (
    ehca_ehcp_assessment_id NVARCHAR(48),
    ehca_ehcp_request_id NVARCHAR(48),
    ehca_ehcp_assessment_outcome_date DATETIME,
    ehca_ehcp_assessment_outcome NVARCHAR(100),
    ehca_ehcp_assessment_exceptions NVARCHAR(100)
);




-- Create constraint(s)
ALTER TABLE ssd_ehcp_assessment
ADD CONSTRAINT FK_ehcp_assessment_requests
FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);



-- Create structure
CREATE TABLE ssd_ehcp_named_plan (
    ehcn_named_plan_id NVARCHAR(48),
    ehcn_ehcp_asmt_id NVARCHAR(48),
    ehcn_named_plan_start_date DATETIME,
    ehcn_named_plan_cease_date DATETIME,
    ehcn_named_plan_cease_reason NVARCHAR(100)
);


-- Create constraint(s)
ALTER TABLE ssd_ehcp_named_plan
ADD CONSTRAINT FK_ehcp_named_plan_assessment
FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_ehcp_assessment(ehca_ehcp_assessment_id);


-- Create structure
CREATE TABLE ssd_ehcp_active_plans (
    ehcp_active_ehcp_id NVARCHAR(48),
    ehcp_ehcp_request_id NVARCHAR(48),
    ehcp_active_ehcp_last_review_date DATETIME
);


-- Create constraint(s)
ALTER TABLE ssd_ehcp_active_plans
ADD CONSTRAINT FK_ehcp_active_plans_requests
FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);










ALTER TABLE ssd_person
ADD involvement_history_json NVARCHAR(4000),  -- Adjust data type as needed
    involvement_type_story NVARCHAR(1000);  -- Adjust data type as needed

