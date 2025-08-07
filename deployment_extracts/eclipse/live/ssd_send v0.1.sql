/*
=============================================================================
Object Name: ssd_send
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
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Row identifier for the ssd_send table */
	NULL "send_table_id", --metadata={"item_ref:"SEND001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	The Child's Unique Pupil Number */
	NULL "send_upn", --metadata={"item_ref:"SEND002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) The young person’s unique learner number (ULN) as used in the Individualised Learner Record. */
	NULL "send_uln", --metadata={"item_ref:"SEND003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Where no identifier is available, please record one of the following options:
	-UN1   Child is aged under 6 years old and is not yet assigned a UPN
	-UN2   Child has never attended a state-funded school in England and has not been assigned a UPN
	-UN3   Child is educated outside of England and has not been assigned a UPN
	-UN5   Sources collating UPNs reflect discrepancy/ies for the child’s name and/or surname and/or date of birth therefore prevent reliable matching (for example duplicated UPN)
	-UN8   Person is new to LA and the UPN or ULN is not yet known
	-UN9   Young person has never attended a state-funded school or further education setting in England and has not been assigned a UPN or ULN
	-UN10  Request for assessment resulted in no further action before UPN or ULN known */
	NULL "send_upn_unknown", --metadata={"item_ref:"SEND004A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Person's ID generated in CMS Database */
	NULL "send_person_id" --metadata={"item_ref:"SEND005A"}

