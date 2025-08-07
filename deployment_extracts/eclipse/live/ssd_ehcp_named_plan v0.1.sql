/*
=============================================================================
Object Name: ssd_ehcp_named_plan 
Description: Placeholder structure as source data not common|confirmed

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- Yet to be defined
- ssd_person

=============================================================================
*/

SELECT
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	EHCP named plan unique ID from system or auto-generated as part of export.
	This module collects information on the content of the EHC plan, i.e. what is in Section I. It should be completed for all existing active EHC plans.
	It is possible that multiple plans may be recorded for a single person. For example, if an EHC plan has previously ceased and a further plan has later been issued following a new needs assessment. Changes may occur to this section from one year to the next for the same person, for example where an establishment named on the EHC plan is changed. */
	NULL "ehcn_named_plan_id", --metadata={"item_ref:"EHCN001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	EHCP assessment record unique ID from system or auto-generated as part of export. */
	NULL "ehcn_ehcp_asmt_id", --metadata={"item_ref:"EHCN002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Date of current EHC plan. */
	NULL "ehcn_named_plan_start_date", --metadata={"item_ref:"EHCN003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please provide the date the EHC plan ended or the date the EHC plan was transferred to another local authority. Do not record the date of the decision to cease. Local authorities must continue to maintain the EHC plan until the time has passed for bringing an appeal or, when an appeal has been registered, until it has been concluded. */
	NULL "ehcn_named_plan_cease_date", --metadata={"item_ref:"EHCN004A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please provide the reason the EHC plan ended from the list below 
	1 – Reached maximum age (this is the end of the academic year during which the young person turned 25) 
	2 – Ongoing educational or training needs being met without an EHC plan 
	3 – Moved on to higher education 
	4 – Moved on to paid employment, excluding apprenticeships 
	5 – Transferred to another LA 
	6 – Young person no longer wishes to engage in education or training 
	7 – Child or young person has moved outside England 
	8 – Child or young person deceased 
	9 – Other  */
	NULL "ehcn_named_plan_cease_reason" --metadata={"item_ref:"EHCN005A"}

