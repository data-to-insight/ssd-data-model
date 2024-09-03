select
	pla.PLACEMENT_ID clap_cla_placement_id,
	-- null clap_ cla_ episode_ id, --a placement can fall in multiple CLA episodes.  Should this be period of care id? -- [REVIEW] depreciated
	pla.START_DATE clap_cla_placement_start_date,
	pla.PLACEMENT_TYPE clap_cla_placement_type,
	pla.split_number,
	(
		select
			max(pld.OFSTED_URN)
		from
			DM_CLA_SUMMARIES cla
		inner join DM_PLACEMENT_DETAILS pld
		on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
		and
		pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
		where
			cla.PLACEMENT_ID = pla.PLACEMENT_ID
			and
			cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			and
			dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
				select
					max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
				from
					DM_CLA_SUMMARIES cla1
				inner join DM_PLACEMENT_DETAILS pld1
				on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
				and
				pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
				where
					cla1.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			)
	) clap_cla_placement_urn,
	null clap_cla_placement_distance,
	pla.PERIOD_OF_CARE_ID clap_cla_id,
	(
		select
			max(pld.CIN_PROVIDER_CATEGORY_CODE)
		from
			DM_CLA_SUMMARIES cla
		inner join DM_PLACEMENT_DETAILS pld
		on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
		and
		pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
		where
			cla.PLACEMENT_ID = pla.PLACEMENT_ID
			and
			cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			and
			dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
				select
					max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
				from
					DM_CLA_SUMMARIES cla1
				inner join DM_PLACEMENT_DETAILS pld1
				on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
				and
				pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
				where
					cla1.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			)
	) clap_cla_placement_provider,
	(
		select
			max(ca.POST_CODE)
		from
			DM_CLA_SUMMARIES cla
		inner join DM_PLACEMENT_DETAILS pld
		on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
		and
		pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
		inner join DM_PLACEMENT_CARER_ADDRESSES ca
		on ca.CARER_ID = pld.CARER_ID
		and
		coalesce(pla.end_date,dbo.today()) between ca.START_DATE and dbo.future(ca.END_DATE)
		where
			cla.PLACEMENT_ID = pla.PLACEMENT_ID
			and
			cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			and
			dbo.to_weighted_start(pld.START_DATE,pld.ELEMENT_DETAIL_ID) = (
				select
					max(dbo.to_weighted_start(pld1.START_DATE,pld1.ELEMENT_DETAIL_ID))
				from
					DM_CLA_SUMMARIES cla1
				inner join DM_PLACEMENT_DETAILS pld1
				on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
				and
				pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
				where
					cla1.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla1.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
			)
	) clap_cla_placement_postcode,
	pla.END_DATE clap_cla_placement_end_date,
	pla.REASON_FOR_PLACEMENT_CHANGE clap_cla_placement_change_reason
from
	DM_PLACEMENTS pla
where
	pla.SPLIT_NUMBER = (
		select
			max(pla1.split_number)
		from
			dm_placements pla1
		where
			pla1.PLACEMENT_ID = pla.PLACEMENT_ID
	)
