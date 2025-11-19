/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_professionals;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_professionals (
    prof_professional_id                VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"PROF001A"}
    prof_staff_id                       VARCHAR(48),               -- metadata={"item_ref":"PROF010A"}
    prof_professional_name              VARCHAR(300),              -- metadata={"item_ref":"PROF013A"}
    prof_social_worker_registration_no  VARCHAR(48),               -- metadata={"item_ref":"PROF002A"}
    prof_agency_worker_flag             CHAR(1),                   -- metadata={"item_ref":"PROF014A", "item_status": "P", "info":"Not available in SSD V1"}
    prof_professional_job_title         VARCHAR(500),              -- metadata={"item_ref":"PROF007A"}
    prof_professional_caseload          INTEGER,                   -- metadata={"item_ref":"PROF008A", "item_status": "T"}
    prof_professional_department        VARCHAR(100),              -- metadata={"item_ref":"PROF012A"}
    prof_full_time_equivalency          DOUBLE PRECISION           -- metadata={"item_ref":"PROF011A"}
);

TRUNCATE TABLE ssd_professionals;

WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
        OR COALESCE(PV.DUPLICATED,'?') = 'DUPLICATE'
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
)
INSERT INTO ssd_professionals (
    prof_professional_id,
    prof_staff_id,
    prof_professional_name,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)
SELECT
    PPR.PROFESSIONALRELATIONSHIPPERSONID AS prof_professional_id,               -- metadata={"item_ref":"PROF001A"}
    PPR.PROFESSIONALRELATIONSHIPPERSONID AS prof_staff_id,                      -- metadata={"item_ref":"PROF010A"}
    PPR.PROFESSIONALRELATIONSHIPNAME     AS prof_professional_name,             -- metadata={"item_ref":"PROF013A"}
    PROFNUM.REFERENCENUMBER              AS prof_social_worker_registration_no, -- metadata={"item_ref":"PROF002A"}
    NULL                                 AS prof_agency_worker_flag,            -- metadata={"item_ref":"PROF014A"}
    NULL                                 AS prof_professional_job_title,        -- metadata={"item_ref":"PROF007A"}
    NULL                                 AS prof_professional_caseload,         -- metadata={"item_ref":"PROF008A"}
    NULL                                 AS prof_professional_department,       -- metadata={"item_ref":"PROF012A"}
    NULL                                 AS prof_full_time_equivalency          -- metadata={"item_ref":"PROF011A"}
FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN REFERENCENUMBERPERSONVIEW PROFNUM
       ON PROFNUM.PERSONID = PPR.PROFESSIONALRELATIONSHIPPERSONID
      AND PROFNUM.REFERENCETYPE = 'Social Work England number'
WHERE PPR.PROFESSIONALRELATIONSHIPPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E);
