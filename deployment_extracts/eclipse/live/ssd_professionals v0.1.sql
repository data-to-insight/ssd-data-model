/*
=============================================================================
Object Name: ssd_professionals
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- @LastSept30th - ??
=============================================================================
*/
WITH EXCLUSIONS AS (
	SELECT
		PV.PERSONID
	FROM PERSONVIEW PV
	WHERE PV.PERSONID IN (
			1,2,3,4,5,6,99046,100824,100825,100826,100827,100828,100829,100830,100832,100856,100857,100861,100864,9999040,102790,
			100831,100833,100834,100838,100839,100859,100860,99524,99543,99555,99559,99613,99661,99662,99993,100276,100290,100372,109032,100924,
			100941,35698,43088,68635,74902,77731,97447,9999000,9999010,9999025,9999026,9999029,9999050,72306,109032,117746,
			97951 --not flagged as duplicate
		)
		OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
		OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
		OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)


SELECT
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "prof_professional_id",              --metadata={"item_ref:"PROF001A"}
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "prof_staff_id",                     --metadata={"item_ref:"PROF010A"}
	PPR.PROFESSIONALRELATIONSHIPNAME     AS "prof_professional_name",            --metadata={"item_ref:"PROF013A"}
	PROFNUM.REFERENCENUMBER              AS "prof_social_worker_registration_no",--metadata={"item_ref:"PROF002A"}
	NULL                                 AS "prof_professional_job_title",       --metadata={"item_ref:"PROF007A"}
	NULL                                 AS "prof_professional_department",      --metadata={"item_ref:"PROF012A"}
	NULL                                 AS "prof_full_time_equivalency",        --metadata={"item_ref:"PROF011A"}
	NULL                                 AS "prof_agency_worker_flag"            --metadata={"item_ref:"PROF013A"}

FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN REFERENCENUMBERPERSONVIEW PROFNUM ON PROFNUM.PERSONID = PPR.PROFESSIONALRELATIONSHIPPERSONID AND  PROFNUM.REFERENCETYPE = 'Social Work England number'
WHERE PPR.PROFESSIONALRELATIONSHIPPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)

