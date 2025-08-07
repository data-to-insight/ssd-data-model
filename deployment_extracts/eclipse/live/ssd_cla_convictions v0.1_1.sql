/*
=============================================================================
Object Name: ssd_cla_convictions
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
- FACT_OFFENCE - ??

=============================================================================
*/

SELECT
	/*Row identifier for the ssd_cla_convictions table */
	NULL "clac_cla_conviction_id", --metadata={"item_ref:"CLAC001A"}
	/*Person's ID generated in CMS Database */
	NULL "clac_person_id", --metadata={"item_ref:"CLAC002A"}
	/*Date of Offence */
	NULL "clac_cla_conviction_date", --metadata={"item_ref:"CLAC003A"}
	/*Details of offence committed. */
	NULL "clac_cla_conviction_offence" --metadata={"item_ref:"CLAC004A"}