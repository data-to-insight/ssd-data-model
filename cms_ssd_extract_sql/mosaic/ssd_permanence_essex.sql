select
	null perm_permanence_id,
	c.id perm_person_id,
	c.adm_decision_date perm_adm_decision_date,
	null perm_ffa_cp_decision_date,
	c.placement_order_date perm_placement_order_date,
	c.date_placed_for_adoption perm_placed_for_adoption_date,
	c.panel_matching_date perm_matched_date,
	c.date_ffa perm_placed_ffa_cp_date,
	c.date_decision_reversed perm_decision_revered_date,
	c.sibling_group perm_part_of_sibling_group,
	c.sibling_together perm_siblings_placed_together,
	null perm_siblings_placed_apart,
	null perm_placement_provider_urn,
	c.reason_reversed perm_decision_reversed_reason,
	c.ao_date perm_permanence_order_date,
	null perm_permanence_order_type,
	null perm_guardian_status,
	null perm_guardian_age,
	null perm_adopted_by_carer_flag,
	(
		select
			max(cla.PERIOD_OF_CARE_ID)
		from
			SCF.Children_In_Care cla
		where
			cla.person_id = c.id
			and
			cla.poc_start = c.poc_start
	) perm_cla_id,
	c.worker_name perm_adoption_worker_id, -- [REVIEW][_name]
	(
		select
			wkr.worker_id
		from
			raw.mosaic_fw_dm_prof_relationships prel
		inner join raw.mosaic_fw_dm_workers wkr
		on wkr.worker_id = prel.worker_id
		where
			prel.person_id = c.id
			and
			prel.PROF_REL_TYPE_CODE in (
				'REL.ALLWORK',
				'REL.ALLWORKCF'
			)
			and
			convert(datetime, convert(varchar, getdate(), 103), 103) between prel.START_DATE and coalesce(prel.end_date,'1 January 2300')
	) perm_allocated_worker
from
	SCF.ALB_Children c

--select top 100 * from SCF.ALB_Children c