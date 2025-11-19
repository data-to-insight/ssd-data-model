-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_contacts;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_contacts (
    cont_contact_id           VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CONT001A"}
    cont_person_id            VARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
    cont_contact_date         TIMESTAMP,                 -- metadata={"item_ref":"CONT003A"}
    cont_contact_source_code  VARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
    cont_contact_source_desc  VARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
    cont_contact_outcome_json VARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
);

TRUNCATE TABLE ssd_contacts;

INSERT INTO ssd_contacts (
    cont_contact_id,
    cont_person_id,
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
        OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)

SELECT
    FAPV.INSTANCEID   AS cont_contact_id,    --metadata={"item_ref:"CONT001A"}
    FAPV.PERSONID     AS cont_person_id,     --metadata={"item_ref:"CONT002A"}
    FAPV.CONTACT_DATE AS cont_contact_date,  --metadata={"item_ref:"CONT003A"}
    CASE 
        WHEN FAPV.CONTACT_BY = 'Acquaintance'                               THEN 'INDACQ'
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
    END                    AS cont_contact_source_code,  --metadata={"item_ref:"CONT004A"}
    FAPV.CONTACT_BY        AS cont_contact_source_desc,  --metadata={"item_ref:"CONT006A"}
    NULL                   AS cont_contact_outcome_json  --metadata={"item_ref:"CONT005A"}
FROM (
    SELECT
        FAPV.INSTANCEID, 
        FAPV.ANSWERFORSUBJECTID AS PERSONID,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'icContactDate'
                THEN FAPV.ANSWERVALUE
            END
        )::DATE              AS CONTACT_DATE, 
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'icContactBy'
                THEN FAPV.ANSWERVALUE
            END
        )                    AS CONTACT_BY 
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('8fae4e1f-344b-4c08-93ba-8b344513198c') --MASH summary and outcome
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.INSTANCEID, 
             FAPV.ANSWERFORSUBJECTID
) FAPV;
