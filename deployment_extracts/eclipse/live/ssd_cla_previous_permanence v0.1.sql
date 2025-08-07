/*
=============================================================================
Object Name: ssd_cla_previous_permanence
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
	/*Row identifier for the ssd_previous_permanence table */
	NULL "lapp_table_id", --metadata={"item_ref:"LAPP001A"}
	/*Person's ID generated in CMS Database */
	NULL "lapp_person_id", --metadata={"item_ref:"LAPP002A"}
	/*Date of the previous permanence order, if known. In line with the SSDA903 guidance, if the exact date is unknown, the month and year are recorded in the form zz/MM/YYYY, using zz as the day, for example for May 2020 with the exact date being unknown enter zz/05/2020.
	If the month is unknown, the year is recorded in the form zz/zz/YYYY, for example, where the year of 2021 only is known enter zz/zz/2021. If no information is known about the date of the order, the date is recorded as zz/zz/zzzz. */
	NULL "lapp_previous_permanence_order_date", --metadata={"item_ref:"LAPP003A"}
	/*This should be completed for all children who start to be looked-after.
	Information is collected for children who previously ceased to be looked-after due to the granting of an adoption order, a special guardianship order, residence order (until 22 April 2014) or a child arrangement order. 
	Code set
	P1 - Adoption
	P2 - Special guardianship order (SGO)
	P3 - Residence order (RO) or child arrangements order (CAO) which sets out with whom the child is to live.
	P4 - Unknown
	Z1 - Child has not previously had a permanence option
	P4 should be used when it is not known to the local authority whether the child had a previous permanence option. This information can be updated if information comes to light at any stage in an episode of care. Do not include any adoptions/SGO/ROs/CAOs previously granted where the child was not previously looked-after. */
	NULL "lapp_previous_permanence_option", --metadata={"item_ref:"LAPP004A"}
	/*The name of the local authority who arranged the previous permanence option. */
	NULL "lapp_previous_permanence_la" --metadata={"item_ref:"LAPP005A"}

