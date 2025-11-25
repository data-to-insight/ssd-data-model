/*
Everyone with an 'adoption journey' that overlaps the reporting year is included.
Adoption journey starts with an decision that adoption is in the best interests of the child.
Journey ends when they are adopted or the decision that adoption in best interests is reversed
*/
--
declare @ffa_cp_decision_date_question_user_codes table (
	question_user_code	varchar(128),
	question_text		varchar(500)
)
--
insert into @ffa_cp_decision_date_question_user_codes values
	('f4jf0f4f-jf203cc2-jc239c32c', 'FFP CP Decision Date');
--
with adoption_journeys as (
	select
		x.person_id,
		x.bid_workflow_step_id,
		x.PERIOD_OF_CARE_ID,
		x.period_of_care_start_date,
		x.period_of_care_end_date,
		x.adoption_best_interest_date adoption_journey_start,
		coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption) adoption_journey_end,
		(
			select
				min(leg.start_date)
			from
				DM_LEGAL_STATUSES leg
			where
				leg.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
				and
				leg.PERSON_ID = x.person_id
				and
				leg.LEGAL_STATUS = 'E1'
				and
				leg.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
		) date_po_granted,
		(
			select
				pla.start_date
			from
				dm_placements pla
			where
				pla.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
				and
				pla.PERSON_ID = x.person_id
				and
				pla.PLACEMENT_TYPE in ('A3', 'A4', 'A5', 'A6')
				and
				pla.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
				and
				dbo.to_weighted_start(pla.START_DATE,pla.PLACEMENT_ID) = (
					select
						min(dbo.to_weighted_start(pla1.START_DATE,pla1.PLACEMENT_ID))
					from
						dm_placements pla1
					where
						pla1.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
						and
						pla1.PERSON_ID = x.person_id
						and
						pla1.PLACEMENT_TYPE in ('A3', 'A4', 'A5', 'A6')
						and
						pla1.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
				)
		) date_placed_for_adoption,
		(
			select
				pla.start_date
			from
				dm_placements pla
			where
				pla.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
				and
				pla.PERSON_ID = x.person_id
				and
				pla.PLACEMENT_TYPE in (
					'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
					'U5'	--Placement with other foster carer who is also an approved adopter- FFA
				)
				and
				pla.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
				and
				dbo.to_weighted_start(pla.START_DATE,pla.PLACEMENT_ID) = (
					select
						min(dbo.to_weighted_start(pla1.START_DATE,pla1.PLACEMENT_ID))
					from
						dm_placements pla1
					where
						pla1.PERIOD_OF_CARE_ID = x.PERIOD_OF_CARE_ID
						and
						pla1.PERSON_ID = x.person_id
						and
						pla1.PLACEMENT_TYPE in (
							'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
							'U5'	--Placement with other foster carer who is also an approved adopter- FFA
						)
						and
						pla1.START_DATE between x.ADOPTION_BEST_INTEREST_DATE and dbo.future(coalesce(x.date_adoption_no_longer_plan,x.date_of_adoption))
				)
		) date_placed_in_ffa_placement,
		x.date_adoption_no_longer_plan,
		x.reason_adoption_no_longer_plan,
		x.date_matched_with_adopters,
		x.date_of_adoption,
		x.placement_type_at_adoption,
		x.date_of_ffa_cp_decision,
		case
			--Adopted by current foster carer
			when x.placement_type_at_adoption in ('A3', 'A5') then
				(
					--Find the earliest starting placement which is provided by the eventual adopter which is Fostering but not FFA
					select
						min(pla.START_DATE)
					from
						dm_placements pla
					inner join dm_placement_types ptyp
					on ptyp.PLACEMENT_TYPE = pla.PLACEMENT_TYPE
					inner join DM_CLA_SUMMARIES cla
					on cla.PLACEMENT_ID = pla.PLACEMENT_ID
					and
					cla.PLACEMENT_SPLIT_NUMBER = pla.SPLIT_NUMBER
					and
					cla.START_DATE = pla.START_DATE
					inner join DM_PLACEMENT_DETAILS pld
					on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
					and
					pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
					where
						pla.PERSON_ID = x.person_id
						and
						pla.PERIOD_OF_CARE_ID = x.period_of_care_id
						and
						ptyp.IS_PLACED_WITH_FOSTER_CARERS = 'Y'
						and
						pld.CARER_ID = x.carer_id_at_adoption
						and
						pla.PLACEMENT_TYPE not in (
							'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
							'U5'	--Placement with other foster carer who is also an approved adopter- FFA
						)
						and
						--The child is not subsequently FFA with carer who later adopts them
						not exists (
							select
								1
							from
								dm_placements pla1
							inner join dm_placement_types ptyp1
							on ptyp1.PLACEMENT_TYPE = pla1.PLACEMENT_TYPE
							inner join DM_CLA_SUMMARIES cla1
							on cla1.PLACEMENT_ID = pla1.PLACEMENT_ID
							and
							cla1.PLACEMENT_SPLIT_NUMBER = pla1.SPLIT_NUMBER
							and
							cla1.START_DATE = pla1.START_DATE
							inner join DM_PLACEMENT_DETAILS pld1
							on pld1.ELEMENT_DETAIL_ID = cla1.ELEMENT_DETAIL_ID
							and
							pld1.SPLIT_NUMBER = cla1.SERVICE_SPLIT_NUMBER
							where
								pla1.PERSON_ID = x.person_id
								and
								pla1.PERIOD_OF_CARE_ID = x.period_of_care_id
								and
								ptyp1.IS_PLACED_WITH_FOSTER_CARERS = 'Y'
								and
								pld1.CARER_ID = x.carer_id_at_adoption
								and
								pla1.PLACEMENT_TYPE in (
									'U2',	--Foster placement with relative or friend who is also an approved adopter- FFA
									'U5'	--Placement with other foster carer who is also an approved adopter- FFA
								)
								and
								pla1.START_DATE > pla.START_DATE
						)
				)
		end date_child_originally_placed_with_fc_who_adopted
	from
		(
			select
				bid.person_id,
				bid.WORKFLOW_STEP_ID bid_workflow_step_id,
				poc.PERIOD_OF_CARE_ID,
				poc.START_DATE period_of_care_start_date,
				poc.end_date period_of_care_end_date,
				bid.ADOPTION_BEST_INTEREST_DATE,
				(
					select
						min(nlp.adoption_plan_date_ceased)
					from
						dm_workflow_steps_people_vw nlp
					where
						nlp.person_id = bid.person_id
						and
						nlp.adoption_plan_date_ceased is not null
						and
						nlp.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
						and
						nlp.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
						and
						dbo.to_weighted_start(nlp.ADOPTION_PLAN_DATE_CEASED,nlp.WORKFLOW_STEP_ID) = (
							select
								min(dbo.to_weighted_start(nlp1.ADOPTION_PLAN_DATE_CEASED,nlp1.workflow_step_id))
							from
								dm_workflow_steps_people_vw nlp1
							where
								nlp1.person_id = bid.person_id
								and
								nlp1.adoption_plan_date_ceased is not null
								and
								nlp1.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
								and
								nlp1.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
						)
				) date_adoption_no_longer_plan,
				(
					select
						min(nlp.ADOPTION_PLAN_REASON_CAT_CODE)
					from
						dm_workflow_steps_people_vw nlp
					where
						nlp.person_id = bid.person_id
						and
						nlp.adoption_plan_date_ceased is not null
						and
						nlp.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
						and
						nlp.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
						and
						dbo.to_weighted_start(nlp.ADOPTION_PLAN_DATE_CEASED,nlp.WORKFLOW_STEP_ID) = (
							select
								min(dbo.to_weighted_start(nlp1.ADOPTION_PLAN_DATE_CEASED,nlp1.workflow_step_id))
							from
								dm_workflow_steps_people_vw nlp1
							where
								nlp1.person_id = bid.person_id
								and
								nlp1.adoption_plan_date_ceased is not null
								and
								nlp1.adoption_plan_date_ceased between poc.start_date and dbo.future(poc.end_date)
								and
								nlp1.ADOPTION_PLAN_DATE_CEASED > bid.ADOPTION_BEST_INTEREST_DATE
						)
				) reason_adoption_no_longer_plan,
				(
					select
						min(nlp.adoption_match_date)
					from
						dm_workflow_steps_people_vw nlp
					where
						nlp.person_id = bid.person_id
						and
						nlp.adoption_match_date is not null
						and
						nlp.adoption_match_date between poc.start_date and dbo.future(poc.end_date)
						and
						nlp.adoption_match_date > bid.ADOPTION_BEST_INTEREST_DATE
				) date_matched_with_adopters,
				case
					when poc.end_date is not null then
						(
							select
								pla.END_DATE
							from
								DM_CLA_SUMMARIES cla
							inner join DM_PLACEMENTS pla
							on pla.PLACEMENT_ID = cla.PLACEMENT_ID
							and
							pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
							and
							pla.IS_ADOPTED = 'Y'
							where
								cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
								and
								cla.PERSON_ID = poc.PERSON_ID
								and
								cla.END_DATE = poc.END_DATE
						)
				end date_of_adoption,
				case
					when poc.end_date is not null then
						(
							select
								pla.PLACEMENT_TYPE
							from
								DM_CLA_SUMMARIES cla
							inner join DM_PLACEMENTS pla
							on pla.PLACEMENT_ID = cla.PLACEMENT_ID
							and
							pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
							and
							pla.IS_ADOPTED = 'Y'
							where
								cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
								and
								cla.PERSON_ID = poc.PERSON_ID
								and
								cla.END_DATE = poc.END_DATE
						)
				end placement_type_at_adoption,
				(
					select
						min(cfa.date_answer)
					from
						dm_workflow_steps_people_vw ffa_cp
					inner join DM_CACHED_FORM_ANSWERS cfa
					on cfa.workflow_step_id = ffa_cp.WORKFLOW_STEP_ID
					and
					case 
						when cfa.subject_person_id <= 0 then 
							ffa_cp.person_id
						else 
							cfa.subject_person_id
					end = ffa_cp.person_id
					inner join @ffa_cp_decision_date_question_user_codes quc
					on quc.question_user_code = cfa.question_user_code
					where
						ffa_cp.person_id = bid.person_id
						and
						cfa.date_answer between poc.start_date and dbo.future(poc.end_date)
						and
						cfa.date_answer > bid.ADOPTION_BEST_INTEREST_DATE
						and
						dbo.to_weighted_start(cfa.date_answer,ffa_cp.WORKFLOW_STEP_ID) = (
							select
								min(dbo.to_weighted_start(cfa1.date_answer,ffa_cp1.WORKFLOW_STEP_ID))
							from
								dm_workflow_steps_people_vw ffa_cp1
							inner join DM_CACHED_FORM_ANSWERS cfa1
							on cfa1.workflow_step_id = ffa_cp1.WORKFLOW_STEP_ID
							and
							case 
								when cfa1.subject_person_id <= 0 then 
									ffa_cp1.person_id
								else 
									cfa1.subject_person_id
							end = ffa_cp1.person_id
							inner join @ffa_cp_decision_date_question_user_codes quc1
							on quc1.question_user_code = cfa1.question_user_code
							where
								ffa_cp1.person_id = bid.person_id
								and
								ffa_cp1.adoption_plan_date_ceased is not null
								and
								cfa1.date_answer between poc.start_date and dbo.future(poc.end_date)
								and
								cfa1.date_answer > bid.ADOPTION_BEST_INTEREST_DATE
						)
				) date_of_ffa_cp_decision,
				case
					when poc.end_date is not null then
						(
							select
								max(pld.CARER_ID)
							from
								DM_CLA_SUMMARIES cla
							inner join DM_PLACEMENT_DETAILS pld
							on pld.ELEMENT_DETAIL_ID = cla.ELEMENT_DETAIL_ID
							and
							pld.SPLIT_NUMBER = cla.SERVICE_SPLIT_NUMBER
							inner join dm_placements pla
							on pla.PLACEMENT_ID = cla.PLACEMENT_ID
							and
							pla.SPLIT_NUMBER = cla.PLACEMENT_SPLIT_NUMBER
							and
							pla.IS_ADOPTED = 'Y'
							where
								cla.PERIOD_OF_CARE_ID = poc.PERIOD_OF_CARE_ID
								and
								cla.PERSON_ID = poc.PERSON_ID
								and
								cla.END_DATE = poc.END_DATE
						)
				end carer_id_at_adoption
			from
				dm_workflow_steps_people_vw bid
			inner join DM_PERIODS_OF_CARE poc
			on poc.PERSON_ID = bid.person_id
			and
			bid.ADOPTION_BEST_INTEREST_DATE between poc.START_DATE and dbo.future(poc.END_DATE)
			where
				bid.ADOPTION_BEST_INTEREST_DATE is not null
		) x		
)
select
	'ADP' + '.' + cast(aj.bid_workflow_step_id as varchar(9)) perm_table_id,
	aj.person_id perm_person_id,
	aj.adoption_journey_start perm_adm_decision_date,
	aj.date_of_ffa_cp_decision perm_ffa_cp_decision_date,
	aj.date_po_granted perm_placement_order_date,
	aj.date_placed_for_adoption perm_placed_for_adoption_date,
	aj.date_matched_with_adopters perm_matched_date,
	aj.date_placed_in_ffa_placement perm_placed_ffa_cp_date,
	aj.date_adoption_no_longer_plan perm_decision_reversed_date,
	aj.date_child_originally_placed_with_fc_who_adopted perm_placed_foster_carer_date,
	case
		when exists (
				select
					1
				from
					DM_PERSONAL_RELATIONSHIPS rel
				inner join adoption_journeys oaj
				on oaj.person_id = rel.other_person_id
				and
				oaj.adoption_journey_start <= dbo.future(aj.adoption_journey_end)
				and
				dbo.future(oaj.adoption_journey_end) >= aj.adoption_journey_start
				where
					rel.person_id = per.person_id
					and
					rel.family_category = 'Child''s Siblings'
			) then	
			1
		else
			0
	end perm_part_of_sibling_group,
	null perm_siblings_placed_together,
	null perm_siblings_placed_apart,
	(
		select
			max(pld.ofsted_urn)
		from
			DM_CLA_SUMMARIES cla
		inner join DM_PLACEMENT_DETAILS pld
		on pld.element_detail_id = cla.element_detail_id
		and
		pld.split_number = cla.service_split_number
		where
			cla.person_id = aj.person_id
			and
			dbo.future(aj.adoption_journey_end) between cla.start_date and dbo.future(cla.end_date)
	) perm_placement_provider_urn,
	aj.reason_adoption_no_longer_plan perm_decision_reversed_reason,
	aj.date_of_adoption perm_permanence_order_date,
	aj.placement_type_at_adoption perm_permanence_order_type,
	null perm_adopted_by_carer_flag,
	aj.PERIOD_OF_CARE_ID perm_cla_id,
	null perm_adoption_worker_id
	-- , -- [REVIEW] depreciated
	-- null perm_allocated_worker
from
	adoption_journeys aj
inner join dm_persons per
on per.PERSON_ID = aj.person_id
union all
select 
	'SGO' + '.' + cast(nleg.LEGAL_STATUS_ID as varchar(9)) perm_table_id,
	nleg.PERSON_ID perm_person_id,
	null perm_adm_decision_date,
	null perm_ffa_cp_decision_date,
	null perm_placement_order_date,
	null perm_placed_for_adoption_date,
	null perm_matched_date,
	null perm_placed_ffa_cp_date,
	null perm_decision_reversed_date,
	null perm_placed_foster_carer_date,
	null perm_part_of_sibling_group,
	null perm_siblings_placed_together,
	null perm_siblings_placed_apart,
	(
		select
			max(pld.ofsted_urn)
		from
			DM_CLA_SUMMARIES cla
		inner join DM_PLACEMENT_DETAILS pld
		on pld.element_detail_id = cla.element_detail_id
		and
		pld.split_number = cla.service_split_number
		where
			cla.person_id = poc.person_id
			and
			dbo.future(poc.END_DATE) between cla.start_date and dbo.future(cla.end_date)
	) perm_placement_provider_urn,
	null perm_decision_reversed_reason,
	null perm_permanence_order_date,
	null perm_permanence_order_type,
	null perm_adopted_by_carer_flag,
	poc.period_of_care_id perm_cla_id,
	null perm_adoption_worker_id
	-- , -- [REVIEW]
	-- null perm_allocated_worker -- [REVIEW] depreciated
from 
	DM_NON_LA_LEGAL_STATUSES nleg
inner join DM_NON_LA_LEGAL_STATUS_TYPES ntyp
on ntyp.LEGAL_STATUS_TYPE = nleg.LEGAL_STATUS_TYPE
inner join DM_PERIODS_OF_CARE poc
on poc.PERSON_ID = nleg.PERSON_ID
and
poc.start_date <= dbo.future(nleg.END_DATE)
and
dbo.future(poc.END_DATE) >= nleg.START_DATE
where
	ntyp.IS_SPECIAL_GUARDIANSHIP_ORDER = 'Y'