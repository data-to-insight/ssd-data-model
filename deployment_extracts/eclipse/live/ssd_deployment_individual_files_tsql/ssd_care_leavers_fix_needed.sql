/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_care_leavers;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */


/* ===========================================
   CREATE TABLE
   =========================================== */

IF OBJECT_ID('ssd_care_leavers', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [ssd_care_leavers])
        TRUNCATE TABLE [ssd_care_leavers];
END

BEGIN
    CREATE TABLE ssd_care_leavers (
        clea_table_id                     NVARCHAR(48)  PRIMARY KEY,
        clea_person_id                    NVARCHAR(48),
        clea_care_leaver_eligibility      NVARCHAR(100),
        clea_care_leaver_in_touch         NVARCHAR(100),
        clea_care_leaver_latest_contact   DATETIME,
        clea_care_leaver_accommodation    NVARCHAR(100),
        clea_care_leaver_accom_suitable   NVARCHAR(100),
        clea_care_leaver_activity         NVARCHAR(100),
        clea_pathway_plan_review_date     DATETIME,
        clea_care_leaver_personal_advisor NVARCHAR(100),
        clea_care_leaver_allocated_team   NVARCHAR(48),
        clea_care_leaver_worker_id        NVARCHAR(100)
    );
END;

TRUNCATE TABLE ssd_care_leavers;

-- ============================================================
-- MAIN SCRIPT
-- ============================================================

;WITH CARELEAVER_REVIEW AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY PERSONID ORDER BY REVIEW_DATE DESC) AS LATEST_REVIEW
    FROM (
        SELECT 
            FAPV.ANSWERFORSUBJECTID AS PERSONID,
            FAPV.INSTANCEID,
            MAX(CASE
                    WHEN FAPV.CONTROLNAME = 'dateOfPathwayPlan'
                    THEN FAPV.DATEANSWERVALUE
                END) AS REVIEW_DATE
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID = 'c17d1557-513d-443f-8013-a31eb541455b'
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY
            FAPV.ANSWERFORSUBJECTID,
            FAPV.INSTANCEID
    ) X
),

WORKER AS (
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID AS ID,
        PPR.PERSONID,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
        PPR.STARTDATE AS WORKER_START_DATE,
        PPR.CLOSEDATE AS WORKER_END_DATE
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW'
),

TEAM AS (
    SELECT 
        PPR.RELATIONSHIPID AS ID,
        PPR.PERSONID,
        PPR.ORGANISATIONID AS ALLOCATED_TEAM,
        PPR.DATESTARTED AS TEAM_START_DATE,
        PPR.DATEENDED   AS TEAM_END_DATE
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
),

CARELEAVER AS (
    SELECT
        CL.CARELEAVERID,
        CL.PERSONID,
        CL.ELIGIBILITY,
        CL.INTOUCHCODE,
        CL.CONTACTDATE,
        CL.ACCOMODATIONCODE,

        CASE
            WHEN CL.ACCOMSUITABLE = 'Accommodation considered suitable'   THEN '1'
            WHEN CL.ACCOMSUITABLE = 'Accommodation considered unsuitable' THEN '2'
        END AS ACCOMSUITABLE,

        CL.MAINACTIVITYCODE,

        RANK() OVER (
            PARTITION BY CL.PERSONID
            ORDER BY CL.CONTACTDATE DESC
        ) AS LATEST_RECORD

    FROM CLACARELEAVERDETAILSVIEW CL

    WHERE EXISTS (
        SELECT 1
        FROM ssd_person sp
        WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CL.PERSONID)
    )

)

-- ============================================================
-- INSERT
-- ============================================================

INSERT INTO ssd_care_leavers
SELECT
    CL.CARELEAVERID,
    CL.PERSONID,
    CL.ELIGIBILITY,
    CL.INTOUCHCODE,
    CAST(CL.CONTACTDATE AS DATE),
    CL.ACCOMODATIONCODE,
    CL.ACCOMSUITABLE,
    CL.MAINACTIVITYCODE,
    CR.REVIEW_DATE,
    W.ALLOCATED_WORKER,
    T.ALLOCATED_TEAM,
    W.ALLOCATED_WORKER

FROM CARELEAVER CL

LEFT JOIN CARELEAVER_REVIEW CR
    ON CR.PERSONID = CL.PERSONID
   AND CR.LATEST_REVIEW = 1

LEFT JOIN WORKER W
    ON W.PERSONID = CL.PERSONID
   AND CL.CONTACTDATE >= W.WORKER_START_DATE
   AND CL.CONTACTDATE <= ISNULL(W.WORKER_END_DATE, GETDATE())

LEFT JOIN TEAM T
    ON T.PERSONID = CL.PERSONID
   AND CL.CONTACTDATE >= T.TEAM_START_DATE
   AND CL.CONTACTDATE <= ISNULL(T.TEAM_END_DATE, GETDATE())

WHERE CL.LATEST_RECORD = 1;