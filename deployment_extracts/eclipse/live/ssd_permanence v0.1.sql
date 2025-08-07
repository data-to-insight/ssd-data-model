/*
=============================================================================
Object Name: ssd_permanence
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
=============================================================================
*/

SELECT
	ADOP.ADOPTIONID  AS "perm_table_id", --metadata={"item_ref:"PERM001A"}
	ADOP.PERSONID    AS "perm_person_id", --metadata={"item_ref:"PERM002A"}
	/*System identifier for the whole period of care, encompassing all episodes within that period of care. */
	CLA.PERIODOFCAREID AS "perm_cla_id", --metadata={"item_ref:"PERM022A"}
	/*The date of the decision that the child should be placed for adoption. This is the date on which the local authority formally decides that a child should be placed for adoption, i.e. the date the agency decision maker takes the decision to endorse the proposed adoption plan for the child. */
	NULL "perm_adm_decision_date", --metadata={"item_ref:"PERM003A"}
	/*Date of the decision that the child should be placed in a FFA or CP placement with a selected family, if applicable */
	NULL "perm_ffa_cp_decision_date", --metadata={"item_ref:"PERM004A"}
	/*The date that a Placement order or Freeing order was granted. This can be ascertained from the date when a child's legal status has changed to E1 (Placement order granted) or D1 (Freeing order granted). */
	NULL "perm_placement_order_date", --metadata={"item_ref:"PERM006A"}
	/*The date that the child was placed for adoption with particular prospective adopters.. Or, if the child was placed with their foster carers or were in a FFA/concurrent planning placement, record the date this placement changed from a foster placement to an adoption placement. 
	This is the date that child goes to live with the prospective adopters who will adopt them. It does not mean that the child has been adopted. */
	NULL "perm_placed_for_adoption_date", --metadata={"item_ref:"PERM007A"}
	/*The date that the child was matched to particular prospective adopters or with dually approved foster carers/adopters for FFA. 
	This is the date on which the local authority formally decides that the child should be placed for adoption with the particular prospective adopters. If the child is adopted by the foster carer or relatives with whom he/she is already placed, the date of decision should be recorded here. */
	NULL "perm_matched_date", --metadata={"item_ref:"PERM008A"}
	/*Flag showing if the child was Adopted by their former carer. Y/N */
	NULL "perm_adopted_by_carer_flag", --metadata={"item_ref:"PERM021A"}
	/*Date the child was placed in a FFA or CP placement. */
	NULL "perm_placed_ffa_cp_date", --metadata={"item_ref:"PERM009A"}
	/*The date that the local authority formally decides that a child should no longer be placed for adoption */
	NULL "perm_decision_reversed_date", --metadata={"item_ref:"PERM010A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Date the child was originally placed with their foster carer(s) (only if the child was adopted by their foster carer(s)) */
	NULL "perm_placed_foster_carer_date", --metadata={"item_ref:"PERM011A"}
	/*Is the child a part of a sibling group
	Code set
	0 - No 
	1 - Yes */
	NULL "perm_part_of_sibling_group", --metadata={"item_ref:"PERM012A"}
	/*Number of children placed, or planned to be placed, for adoption together as sibling group INCLUDING this child */
	NULL "perm_siblings_placed_together", --metadata={"item_ref:"PERM013A"}
	/*Number of siblings placed, or planned to be placed, for adoption separately from the child */
	NULL "perm_siblings_placed_apart", --metadata={"item_ref:"PERM014A"}
	/*URN of the placement provider agency */
	NULL "perm_placement_provider_urn", --metadata={"item_ref:"PERM015A"}
	ADOP.REASONNOLONGERPLANNEDCODE AS "perm_decision_reversed_reason", --metadata={"item_ref:"PERM016A"}
	/*Date permanence order granted -  this is the CLA Placement End Date */
	NULL "perm_permanence_order_date", --metadata={"item_ref:"PERM017A"}
	/*Type of Permanence order granted 
	- Adoption 
	- Special Guardianship  
	- Child Arrangements Order/ Residence Order */
	NULL "perm_permanence_order_type", --metadata={"item_ref:"PERM018A"}
	/*Adoption Social Worker */
	NULL "perm_adoption_worker", --metadata={"item_ref:"PERM023A"}
	ADOP.GENDEROFADOPTERSCODE AS "perm_adopter_sex", --metadata={"item_ref:"PERM025A"}
	ADOP.ADOPTERSLEGALSTATUSCODE AS "perm_adopter_legal_status", --metadata={"item_ref:"PERM026A"}
	/*Number of Adopters/ Prospective Adopters */
	NULL "perm_number_of_adopters" --metadata={"item_ref:"PERM027A"}

FROM CLAADOPTIONSVIEW ADOP
LEFT JOIN LATERAL (
             SELECT
                 PERSONID,
                 PERIODOFCAREID,
                 ADMISSIONDATE,
                 DISCHARGEDATE
             FROM CLAPERIODOFCAREVIEW CLA
             WHERE CLA.PERSONID = ADOP.PERSONID
               AND CLA.ADMISSIONDATE <= ADOP.DATESHOULDBEPLACED
             ORDER BY   CLA.ADMISSIONDATE DESC 
             FETCH FIRST 1 ROW ONLY ) CLA ON TRUE
           

WHERE ADOP.PERSON_FK  = 101170