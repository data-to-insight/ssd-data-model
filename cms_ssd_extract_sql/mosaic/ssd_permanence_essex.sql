SELECT
    NULL perm_table_id,
    c.id perm_person_id,
    c.adm_decision_date perm_adm_decision_date,
    NULL perm_ffa_cp_decision_date,
    c.placement_order_date perm_placement_order_date,
    c.date_placed_for_adoption perm_placed_for_adoption_date,
    c.panel_matching_date perm_matched_date,
    c.date_ffa perm_placed_ffa_cp_date,
    c.date_decision_reversed perm_decision_reversed_date,
    c.sibling_group perm_part_of_sibling_group,
    c.sibling_together perm_siblings_placed_together,
    NULL perm_siblings_placed_apart,
    NULL perm_placement_provider_urn,
    c.reason_reversed perm_decision_reversed_reason,
    c.ao_date perm_permanence_order_date,
    NULL perm_permanence_order_type,
    NULL perm_adopted_by_carer_flag,
    (
        SELECT
            MAX(cla.PERIOD_OF_CARE_ID)
        FROM
            SCF.Children_In_Care cla
        WHERE
            cla.person_id = c.id
            AND
            cla.poc_start = c.poc_start
    ) perm_cla_id,
    c.worker_name perm_adoption_worker_id -- [REVIEW]
FROM
    SCF.ALB_Children c

--select top 100 * from SCF.ALB_Children c
