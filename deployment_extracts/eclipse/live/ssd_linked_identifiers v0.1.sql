/*
=============================================================================
Object Name: ssd_linked_identifiers
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- Yet to be defined
=============================================================================
*/

SELECT
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Row identifier for the ssd_linked_identifiers table  */
	NULL "link_table_id", --metadata={"item_ref:"LINK001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Person's ID generated in CMS Database */
	NULL "link_person_id", --metadata={"item_ref:"LINK002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Linked Identifier Type e.g. ['Case Number', 'Unique Pupil Number', NHS Number', 'Home Office Registration', National Insurance Number', 'YOT Number', Court Case Number', RAA ID', 'Incident ID']  */
	NULL "link_identifier_type", --metadata={"item_ref:"LINK003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Identifier value */
	NULL "link_identifier_value", --metadata={"item_ref:"LINK004A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Date the identifier is known/valid from  */
	NULL "link_valid_from_date", --metadata={"item_ref:"LINK005A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Date the identifier ceases to be known/valid  */
	NULL "link_valid_to_date" --metadata={"item_ref:"LINK006A"}

