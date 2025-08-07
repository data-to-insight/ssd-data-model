/*
=============================================================================
Object Name: ssd_pre_proceedings
Description: Placeholder structure as source data not common|confirmed

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
- Yet to be defined
=============================================================================
*/

SELECT
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Row identifier for the ssd_pre_proceedings table */
	NULL "prep_table_id", --metadata={"item_ref:"PREP024A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Person's ID generated in CMS Database */
	NULL "prep_person_id", --metadata={"item_ref:"PREP001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Unique Identifier number for each family group - a family group is described as a group of children linked by parents all starting and ceasing pre or care proceedings at the same time */
	NULL "prep_plo_family_id", --metadata={"item_ref:"PREP002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	This is the date of legal meeting / panel that agreed to commence pre-proceedings. The date should be recorded in a DD/MM/YYYY format, i.e. day/month/year as a four digit number. */
	NULL "prep_pre_pro_decision_date", --metadata={"item_ref:"PREP003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	This is the first pre-proceedings meeting following the legal meeting / panel that agreed to commence pre-proceedings. The date should be recorded in a DD/MM/YYYY format, i.e. day/month/year as a four digit number. */
	NULL "prep_initial_pre_pro_meeting_date", --metadata={"item_ref:"PREP004A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select: 
	Decision to Issue Care Proceedings / 
	Decision to step down 
	If still in pre-proceedings, please leave blank.  */
	NULL "prep_pre_pro_outcome", --metadata={"item_ref:"PREP005A"}
	/*[Guidance text replicated from related stat-return field(s). Thus may not be entirely applicable to this data item within the SSD. A review of item/field guidance notes towards the SSD is in progress.]This is the date of legal meeting / panel that agreed to end pre-proceedings to either step down or issue care proceedings. The date should be recorded in a DD/MM/YYYY format, i.e. day/month/year as a four digit number. */
	NULL "prep_agree_stepdown_issue_date", --metadata={"item_ref:"PREP006A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please provide a numeric value for the number of the times the child has been the subject of a Child Protection Plan during this referral period. If none, please put 0. */
	NULL "prep_cp_plans_referral_period", --metadata={"item_ref:"PREP007A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select one of these options: 
	A – Continue with current plan 
	B – Start pre-proceedings 
	C – Issue care proceedings 
	D – Unknown  */
	NULL "prep_legal_gateway_outcome", --metadata={"item_ref:"PREP008A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please provide a numeric value. If there have not been any previous periods, please put 0. */
	NULL "prep_prev_pre_proc_child", --metadata={"item_ref:"PREP009A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please provide a numeric value. If there have not been any previous periods, please put 0. */
	NULL "prep_prev_care_proc_child", --metadata={"item_ref:"PREP010A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	If the case has not been in pre-proceedings, please leave blank. 
	Please use the UK date format: DD/MM/YYYY  */
	NULL "prep_pre_pro_letter_date", --metadata={"item_ref:"PREP011A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	If care proceedings have not been issued, please leave blank.  
	Please use the UK date format DD/MM/YYYY */
	NULL "prep_care_pro_letter_date", --metadata={"item_ref:"PREP012A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please give a numeric value for the number of meetings that took place with parents, excluding the initial meeting. */
	NULL "prep_pre_pro_meetings_num", --metadata={"item_ref:"PREP013A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) Please select Yes / No / Unknown */
	NULL "prep_pre_pro_parents_legal_rep", --metadata={"item_ref:"PREP014A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select Yes / No / Unknown / Not in care proceedings */
	NULL "prep_parents_legal_rep_point_of_issue", --metadata={"item_ref:"PREP015A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	This is the Court number which is given to a family group when care proceedings are issued. This may be stored on the case management system or held in legal files.
	If the case is not in care proceedings, please leave blank. */
	NULL "prep_court_reference", --metadata={"item_ref:"PREP016A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	This includes the initial IRH and final hearing. Please give a numeric value.
	If case is not in care proceedings, please leave blank. */
	NULL "prep_care_proc_court_hearings", --metadata={"item_ref:"PREP017A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select Yes / No / Unknown / Not in care proceedings.
	A short notice application is an urgent application for the court to hear the case within the next 2 – 5 days. */
	NULL "prep_care_proc_short_notice", --metadata={"item_ref:"PREP018A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please choose the main reason from this list:
	(A) Applications under the Children Act 1989 where without such an order a child’s immediate safety would be compromised, including where there is an immediate threat of child abduction.
	(B) Applications for Emergency Protection Orders where the criteria for such or order is met.
	(c) Other
	If a short notice application has not taken place, please select 'No short notice applications'.
	A short notice application is an urgent application for the court to hear the case within the next 2 – 5 days. */
	NULL "prep_proc_short_notice_reason", --metadata={"item_ref:"PREP019A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select Yes / No / Unknown */
	NULL "prep_la_inital _plan_approved", --metadata={"item_ref:"PREP020A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please choose one option from this list:
	A – Interim / Care Order
	B – Interim / Care Order – Placement with parents
	C – Adoption
	D – Interim / Supervision Order
	E – Special Guardianship Order
	F – Private Law Order
	G – Other
	If case is not in care proceedings, please select 'Not in care proceedings'
	Please note ‘Care order – placement with parents’ means that the public care order was granted but that the child remained in their parent’s care, rather than in another placement. */
	NULL "prep_la_initial_care_plan", --metadata={"item_ref:"PREP021A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please select Yes / No / Unknown */
	NULL "prep_la_final_plan_approved", --metadata={"item_ref:"PREP022A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please choose one option from this list:

	A – Care Order 
	B – Care Order – Placement with parents 
	C – Adoption 
	D – Supervision Order 
	E – Special Guardianship Order 
	F – Private Law Order 
	G – Other 
	H – Not yet at final hearing - still in care proceedings 
	If not yet at the final hearing, please select "Not yet at final hearing - still in care proceedings'. This will indicate that the case is still active in care proceedings. */
	NULL "prep_la_final_care_plan" --metadata={"item_ref:"PREP023A"}