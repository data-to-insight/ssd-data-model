/*
=============================================================================
Object Name: ssd_ehcp_requests
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
	EHCP request record unique ID from system or auto-generated as part of export. */
	NULL "ehcr_ehcp_request_id", --metadata={"item_ref:"EHCR001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	ID for linking to ssd_send table */
	NULL "ehcr_send_table_id", --metadata={"item_ref:"EHCR002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	The date the request for an EHC assessment was received. This will be the date used as the start of the 20-week period. */
	NULL "ehcr_ehcp_req_date", --metadata={"item_ref:"EHCR003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please enter the date the requestor(s) was informed of the decision about whether the local authority agrees to the request for an assessment. 
	If the request was withdrawn or ceased before decision (W), if the decision is yet to be made (A) or is historical (H) then no date is required. */
	NULL "ehcr_ehcp_req_outcome_date", --metadata={"item_ref:"EHCR004A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	This item records whether or not the initial request proceeded to the assessment stage: 
	Y - LA proceeded with an assessment 
	N - LA decided not to proceed with an assessment 
	A - Decision yet to be made 
	W – Request withdrawn or ceased before decision to assess was made 
	H – Historical – Decision to assess was made before the latest collection period 
	If a local authority decides not to proceed with an assessment and this decision is subsequently changed for any reason the original request outcome and request outcome date should not be changed. If the change follows from mediation or tribunal the appropriate mediation and tribunal indicators (items 2.5 and 2.6) should be selected for the request. 
	W may include where the person moves out of the local authority area, leaves education or training, or if the child or young person dies. 
	When A, W or H is selected, no further information is required in this module. */
	NULL "ehcr_ehcp_req_outcome" --metadata={"item_ref:"EHCR005A"}