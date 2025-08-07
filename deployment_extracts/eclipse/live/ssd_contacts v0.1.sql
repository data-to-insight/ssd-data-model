/*
=============================================================================
Object Name: ssd_contacts
Description: 

Author: Lee Hallsworth - City of Wolverhampton Council
Version: 0.1 Creation - LH - <date>
Status: Dev
Remarks:    

Dependencies:
- ssd_person
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
    FAPV.INSTANCEID             AS "cont_contact_id",   --metadata={"item_ref:"CONT001A"}
	FAPV.PERSONID               AS "cont_person_id",    --metadata={"item_ref:"CONT002A"}
	FAPV.CONTACT_DATE           AS "cont_contact_date", --metadata={"item_ref:"CONT003A"}
	CASE WHEN FAPV.CONTACT_BY = 'Acquaintance'                               THEN 'INDACQ'
	     WHEN FAPV.CONTACT_BY = 'A & E'                                      THEN 'HSERVAE'
	     WHEN FAPV.CONTACT_BY = 'Anonymous'                                  THEN 'ANON'
	     WHEN FAPV.CONTACT_BY = 'Education Services'                         THEN 'EDUSERV'
	     WHEN FAPV.CONTACT_BY = 'External e.g. from another local authority' THEN 'LASERVEXT'
	     WHEN FAPV.CONTACT_BY = 'Family Member/Relative/Carer'               THEN 'INDFRC'
	     WHEN FAPV.CONTACT_BY = 'GP'                                         THEN 'HSERVGP'
	     WHEN FAPV.CONTACT_BY = 'Health Visitor'                             THEN 'HSERVHVSTR'
	     WHEN FAPV.CONTACT_BY = 'Housing'                                    THEN 'HOUSLA'
	     WHEN FAPV.CONTACT_BY = 'Other'                                      THEN 'OTHER'
	     WHEN FAPV.CONTACT_BY = 'Other Health Services'                      THEN 'HSERVOTHR'
	     WHEN FAPV.CONTACT_BY = 'Other - including children centres'         THEN 'OTHER'
	     WHEN FAPV.CONTACT_BY = 'Other internal e,g, BC Council'             THEN 'LASERVOINT'
	     WHEN FAPV.CONTACT_BY = 'Other Legal Agency'                         THEN 'OTHERLEG'
	     WHEN FAPV.CONTACT_BY = 'Other Primary Health Services'              THEN 'HSERVPHSERV'
	     WHEN FAPV.CONTACT_BY = 'Police'                                     THEN 'POLICE'
	     WHEN FAPV.CONTACT_BY = 'School'                                     THEN 'SCHOOLS'
	     WHEN FAPV.CONTACT_BY = 'School Nurse'                               THEN 'HSERVSNRSE'
	     WHEN FAPV.CONTACT_BY = 'Self'                                       THEN 'INDSELF'
	     WHEN FAPV.CONTACT_BY = 'Social care e.g. adult social care'         THEN 'LASERVSCR'
	     WHEN FAPV.CONTACT_BY = 'Unknown'                                    THEN 'UNKNOWN'
	END                          AS "cont_contact_source_code", --metadata={"item_ref:"CONT004A"}
	FAPV.CONTACT_BY              AS "cont_contact_source_desc", --metadata={"item_ref:"CONT006A"}
	NULL                         AS "cont_contact_outcome_json" --metadata={"item_ref:"CONT005A"}
	
FROM (
    SELECT
	    FAPV.INSTANCEID, 
	    FAPV.ANSWERFORSUBJECTID AS PERSONID,
	    MAX(CASE
		      WHEN FAPV.CONTROLNAME = 'icContactDate'
		      THEN FAPV.ANSWERVALUE
	    END)::DATE              AS CONTACT_DATE, 
	    MAX(CASE
		      WHEN FAPV.CONTROLNAME = 'icContactBy'
		      THEN FAPV.ANSWERVALUE
	    END)                    AS CONTACT_BY 
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('8fae4e1f-344b-4c08-93ba-8b344513198c') --MASH summary and outcome
           AND FAPV.INSTANCESTATE = 'COMPLETE'
           AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.INSTANCEID, 
	         FAPV.ANSWERFORSUBJECTID
	           
) FAPV	

