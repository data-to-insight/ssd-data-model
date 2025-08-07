/*
=============================================================================
Object Name: ssd_ehcp_active_plans
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
	EHCP active plan unique ID from system or auto-generated as part of export. */
	NULL "ehcp_active_ehcp_id", --metadata={"item_ref:"EHCP001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	EHCP request record unique ID from system or auto-generated as part of export. */
	NULL "ehcp_ehcp_request_id", --metadata={"item_ref:"EHCP002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please enter the date when the local authority wrote to the parent or young person with the notification of the decision as to whether to retain, cease or amend the plan following the annual review meeting. Note that this date will not be the same as the date of the review meeting. */
	NULL "ehcp_active_ehcp_last_review_date" --metadata={"item_ref:"EHCP003A"}

