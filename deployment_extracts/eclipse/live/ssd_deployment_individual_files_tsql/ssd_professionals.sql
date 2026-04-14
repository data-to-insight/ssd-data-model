-- META-CONTAINER: {"type": "table", "name": "ssd_professionals"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - RELATIONSHIPPROFESSIONALVIEW
-- - REFERENCENUMBERPERSONVIEW
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;

IF OBJECT_ID('ssd_professionals', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_professionals)
        TRUNCATE TABLE ssd_professionals;
END
ELSE
BEGIN
    CREATE TABLE ssd_professionals (
        prof_professional_id               NVARCHAR(48)  NOT NULL PRIMARY KEY,
        prof_staff_id                      NVARCHAR(48)  NULL,
        prof_professional_name             NVARCHAR(300) NULL,
        prof_social_worker_registration_no NVARCHAR(48)  NULL,
        prof_agency_worker_flag            NCHAR(1)      NULL,
        prof_professional_job_title        NVARCHAR(500) NULL,
        prof_professional_caseload         INT           NULL,
        prof_professional_department       NVARCHAR(100) NULL,
        prof_full_time_equivalency         FLOAT         NULL
    );
END

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
    CONVERT(NVARCHAR(48), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS prof_professional_id,
    CONVERT(NVARCHAR(48), PPR.PROFESSIONALRELATIONSHIPPERSONID) AS prof_staff_id,
    CONVERT(NVARCHAR(300), PPR.PROFESSIONALRELATIONSHIPNAME)    AS prof_professional_name,
    CONVERT(NVARCHAR(48), PROFNUM.REFERENCENUMBER)              AS prof_social_worker_registration_no,
    NULL AS prof_agency_worker_flag,
    NULL AS prof_professional_job_title,
    NULL AS prof_professional_caseload,
    NULL AS prof_professional_department,
    NULL AS prof_full_time_equivalency
FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN REFERENCENUMBERPERSONVIEW PROFNUM
       ON PROFNUM.PERSONID = PPR.PROFESSIONALRELATIONSHIPPERSONID
      AND PROFNUM.REFERENCETYPE = 'Social Work England number';