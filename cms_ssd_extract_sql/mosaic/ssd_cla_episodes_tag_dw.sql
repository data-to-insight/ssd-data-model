select
	dbo.to_weighted_start(cla.START_DATE,cla.PERSON_ID) clae_cla_episode_id,
	cla.PERSON_ID clae_person_id,
	cla.START_DATE clae_cla_episode_start_date,
	case
		when pla.start_date = poc.start_date
		and  leg.start_date = poc.start_date then 
						'S'
		when leg.start_date > pla.start_date then
						'L'
		when leg.start_date < pla.start_date then
			case
				when prev_episode.carer_id = pld.carer_id 
				and  prev_episode.legal_status = leg.legal_status
				and  prev_episode.placement_type != pla.placement_type
					then 'T'
					else 'P'
			end
		else
			case
				when prev_episode.carer_id = pld.carer_id
					then 'U'
					else 'B'
			end 					
	end clae_cla_episode_start_reason,
	pla.CATEGORY_OF_NEED clae_cla_primary_need,
	cla.PERIOD_OF_CARE_ID clae_cla_id,
	(
		select
			max(ref.REFERRAL_ID)
		from
			DM_CIN_REFERRALS ref
		where
			ref.PERSON_ID = cla.PERSON_ID
			and
			ref.REFERRAL_DATE <= dbo.future(cla.END_DATE)
			and
			dbo.future(ref.CLOSURE_DATE) >= cla.START_DATE
	) clae_referral_id,
	cla.END_DATE clae_cla_episode_ceased,
	pla.REASON_EPISODE_CEASED clae_cla_episode_ceased_reason -- [REVIEW] 290424 RH
from
	dm_cla_summaries cla
inner join DM_PERIODS_OF_CARE poc
on poc.PERIOD_OF_CARE_ID = cla.PERIOD_OF_CARE_ID
inner join DM_LEGAL_STATUSES leg
on leg.LEGAL_STATUS_ID = cla.LEGAL_STATUS_ID
inner join DM_PLACEMENTS pla
on pla.PLACEMENT_ID = cla.PLACEMENT_ID
and
pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
inner join DM_PLACEMENT_DETAILS pld
on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
and
pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
left outer join (
		select
			prev_csm.period_of_care_id,
			prev_csm.end_date,
			prev_pla.reason_episode_ceased,
			prev_csm.placement_id,
			prev_pld.carer_id,
			ls.legal_status,
			prev_pla.placement_type
		from
			dm_cla_summaries prev_csm
		inner join dm_placements prev_pla
		on	prev_pla.placement_id = prev_csm.placement_id
		and prev_pla.split_number = prev_csm.placement_split_number
		inner join dm_legal_statuses ls
		on ls.legal_status_id = prev_csm.legal_status_id
		--
		left join dm_placement_details prev_pld
		on	prev_pld.element_detail_id = prev_csm.element_detail_id
		and prev_pld.split_number = prev_csm.service_split_number
) prev_episode
on	prev_episode.period_of_care_id = cla.period_of_care_id
and prev_episode.end_date = dbo.days_add(cla.start_date,-1)
and prev_episode.reason_episode_ceased = 'X1'
and prev_episode.placement_id != cla.placement_id