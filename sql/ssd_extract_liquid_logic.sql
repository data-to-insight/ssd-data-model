USE PLACEHOLDER_DB_NAME;
SELECT child_id, sex, gender, dob, ethnicity, date_of_birth, send_flag, upn, expected_birth_date, date_of_death, mother, country_of_origin FROM Child;
SELECT family_identifier, child_id FROM Family_identifier;
SELECT address, child_id, postcode, date_from, date_to FROM Address;
SELECT child_id, disability_code FROM Disability_Code;
SELECT child_id, immigration_status, immigration_status_start, immigration_status_end FROM Immigration_Status;
SELECT mothers_child_dob, mother_child_unique_id, child_unique_id FROM Mothers_Child_DOB;
SELECT legal_status_id, child_unique_id, legal_status, legal_status_start_date, legal_status_end_date FROM Legal_Status;
SELECT contact_id, child_unique_id, date_of_contact, contact_source, contact_outcome FROM Contacts;
SELECT eh_episode_id, child_unique_id, eh_episode_start_date, eh_episode_end_date, eh_episode_reason_for_involvement, eh_episode_end_reason, eh_episode_allocated_organisation, eh_episode_allocated_worker FROM Early_Help_Episodes;
SELECT cin_referral_id, child_unique_id, cin_referral_date, cin_referral_completed_by_team, cin_referral_outcome, cin_referral_source, cin_referral_completed_by_worker FROM CIN_Episodes;
SELECT assessment_id, child_unique_id, assessment_start_date, child_seen_during_assessment, assessment_authorised_date, assessment_outcome, assessment_completed_by_team, assessment_completed_by_worker FROM Assessments;
SELECT cin_plan_id, child_unique_id, cin_plan_start_date, cin_plan_end_date, cin_closure_reason, cin_closure_date, cin_allocated_team, cin_allocated_worker FROM CIN_Plans;
SELECT cin_visit_id, cin_plan_id, cin_visit_date, child_seen, child_seen_alone, child_bedroom_seen FROM CIN_Visits;
SELECT s47_enquiry_id, child_unique_id, strategy_discussion_initiating_s47_enquiry_start_date, s47_start_date, s47_outcome, date_of_initial_child_protection_conference, outcome_of_initial_child_protection_conference, s47_icpc_allocated_team, s47_icpc_allocated_worker FROM S47_Enquiry_ICPC;
SELECT cp_plan_id, child_unique_id, cp_plan_start_date, cp_plan_end_date, cp_plan_allocated_team, cp_plan_allocated_worker FROM CP_Plans;
SELECT cp_plan_id, category_of_abuse, category_of_abuse_start_date FROM Category_of_Abuse;
SELECT cp_plan_id, cp_visit_id, date_of_visit, child_seen, child_seen_alone, child_bedroom_seen FROM CP_Visits;
SELECT review_id, cp_plan_id, review_due_date, date_of_review, cp_plan_to_continue, quorate, child_participation, quality_of_representation, sufficient_progress FROM CP_Reviews;
SELECT review_id, risks_to_child_at_this_conference FROM Risks_to_child_at_this_conference;
SELECT episode_id, child_unique_id, date_episode_commenced, reason_for_new_cla_episode, date_ceased_to_be_looked_after, reason_ceased_to_be_looked_after, allocated_team, allocated_worker FROM CLA_Episodes;
SELECT placement_id, episode_id, placement_start_date, placement_type, urn_of_placement, la_of_placement, placement_provider, placement_postcode, placement_end_date, reason_for_placement_change FROM Placement;
SELECT review_id, episode_id, cla_review_due_date, cla_review_date, child_involved_in_care_plan, social_worker_met_with_child, participation_code, previously_adopted_left_care, care_plan_meeting_child_needs, permanence_plan_in_place, date_of_last_iro_visit, date_of_previous_permanence_order, previous_permanence_option, previous_permanence_arranged_la, child_convicted, health_surveillance_checks_up_to_date, date_of_last_health_assessment, date_of_last_dental_check, immunisations_up_to_date, identified_substance_misuse_problem, intervention_for_substance_misuse_problem FROM CLA_Reviews;
SELECT review_id, chosen_plan FROM Care_Plan;
SELECT visit_id, episode_id, date_of_visit, child_seen, child_seen_alone FROM CLA_Visits;
SELECT sdq_id, child_unique_id, sdq_completed_date, sdq_score FROM SDQ_Scores;
SELECT missing_episode_id, episode_id, missing_episode_start, episode_type, missing_episode_end, rhi_offered, rhi_accepted FROM Missing;
SELECT care_leaver_table_id, child_unique_id, eligibility_status, in_touch_category, latest_date_of_contact, accommodation, suitability_of_accommodation, activity_status, latest_pathway_plan_review_date, allocated_personal_advisor, allocated_team, allocated_worker FROM Care_Leavers;
SELECT child_unique_id, date_of_adm_decision, date_of_ffa_cp_decision, date_entered_care, date_of_placement_freeing_order, date_placed_for_adoption, date_matched_to_prospective_adopters, date_placed_in_ffa_cp_placement, date_decision_no_longer_placed_for_adoption, date_originally_placed_with_foster_carers, sibling_group, num_children_placed_together, num_siblings_placed_separately, urn_placement_provider_agency, reason_no_longer_placed_for_adoption, date_of_order, type_of_order, status_of_special_guardian, age_of_special_guardian FROM Permanence;
SELECT swe_registration_number, agency_worker, role_within_organisation, num_cases_held, qualification_level FROM Worker;