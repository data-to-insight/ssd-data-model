select
	distinct
	cla.placement_id clap_cla_placement_id,
	-- cla.EPISODE_ID clap_ cla_ episode_ id, -- [REVIEW] depreciated
	cla.PLACEMENT_START clap_cla_placement_start_date,
	cla.PLACEMENT_TYPE_CODE cla_cla_placement_type,
	cla.OFSTED_URN clap_cla_placement_urn,
	cla.DISTANCE_FROM_HOME clap_cla_placement_distance,
	cla.period_of_care_id clap_cla_id,
	cla.PLACEMENT_COUNTY clap_cla_placement_la,
	cla.PROVIDER_NAME clap_cla_placement_provider, 
	cla.PLACEMENT_POSTCODE clap_cla_placement_postcode,
	cla.PLACEMENT_END clap_cla_placement_end_date,
	cla.REASON_FOR_PLACEMENT_CHANGE clap_cla_placement_change_reason
from
	SCF.Children_In_Care cla