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
	SEN need record unique ID from system or auto-generated as part of export. */
	NULL "senn_table_id", --metadata={"item_ref:"SENN001A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	EHCP active plan unique ID from system or auto-generated as part of export. */
	NULL "senn_active_ehcp_id", --metadata={"item_ref:"SENN002A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	Please record the nature of the person’s special educational need. These options are consistent with those collected within the spring term school census. Where multiple types of need are recorded and ranked, the primary type of need should be ranked 1 under Type of need rank, and if applicable a secondary type of need should be ranked 2. 
	-SPLD  Specific learning difficulty 
	-MLD   Moderate learning difficulty 
	-SLD    Severe learning difficulty 
	-PMLD Profound and multiple learning difficulty 
	-SEMH Social, emotional and mental health 
	-SLCN  Speech, language and communication needs 
	-HI      Hearing impairment 
	-VI      Vision impairment 
	-MSI   Multi-sensory impairment 
	-PD     Physical disability 
	-ASD   Autistic spectrum disorder 
	-OTH   Other difficulty  */
	NULL "senn_active_ehcp_need_type", --metadata={"item_ref:"SENN003A"}
	/*(currently 'PLACEHOLDER_DATA' pending further development) 
	If only one type of need is recorded, this should be recorded as rank 1. If multiple types of need are recorded, then the primary type of need should be recorded as rank 1 and the secondary type of need should be recorded as rank 2. Up to two types of need can be recorded. */
	NULL "senn_active_ehcp_need_rank" --metadata={"item_ref:"SENN004A"}

