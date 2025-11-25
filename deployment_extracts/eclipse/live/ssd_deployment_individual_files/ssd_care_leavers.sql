/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_care_leavers;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_care_leavers (
    clea_table_id                     VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLEA001A"}
    clea_person_id                    VARCHAR(48),               -- metadata={"item_ref":"CLEA002A"}
    clea_care_leaver_eligibility      VARCHAR(100),              -- metadata={"item_ref":"CLEA003A","info":"LAC for 13wks(since 14yrs)+LAC since 16yrs"}
    clea_care_leaver_in_touch         VARCHAR(100),              -- metadata={"item_ref":"CLEA004A"}
    clea_care_leaver_latest_contact   TIMESTAMP,                 -- metadata={"item_ref":"CLEA005A"}
    clea_care_leaver_accommodation    VARCHAR(100),              -- metadata={"item_ref":"CLEA006A"}
    clea_care_leaver_accom_suitable   VARCHAR(100),              -- metadata={"item_ref":"CLEA007A"}
    clea_care_leaver_activity         VARCHAR(100),              -- metadata={"item_ref":"CLEA008A"}
    clea_pathway_plan_review_date     TIMESTAMP,                 -- metadata={"item_ref":"CLEA009A"}
    clea_care_leaver_personal_advisor VARCHAR(100),              -- metadata={"item_ref":"CLEA010A"}
    clea_care_leaver_allocated_team   VARCHAR(48),               -- metadata={"item_ref":"CLEA011A"}
    clea_care_leaver_worker_id        VARCHAR(100)               -- metadata={"item_ref":"CLEA012A"}
);

TRUNCATE TABLE ssd_care_leavers;

INSERT INTO ssd_care_leavers (
    clea_table_id,
    clea_person_id,
    clea_care_leaver_eligibility,
    clea_care_leaver_in_touch,
    clea_care_leaver_latest_contact,
    clea_care_leaver_accommodation,
    clea_care_leaver_accom_suitable,
    clea_care_leaver_activity,
    clea_pathway_plan_review_date,
    clea_care_leaver_personal_advisor,
    clea_care_leaver_allocated_team,
    clea_care_leaver_worker_id
)
WITH CARELEAVER_REVIEW AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY PERSONID ORDER BY REIEW_DATE DESC) AS LATEST_REVIEW
    FROM (
        SELECT 
            FAPV.ANSWERFORSUBJECTID AS PERSONID,
            FAPV.INSTANCEID,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'dateOfPathwayPlan'
                        THEN FAPV.DATEANSWERVALUE
                END
            ) AS REIEW_DATE
        FROM FORMANSWERPERSONVIEW FAPV -- [REVIEW] GUID must match (LA to review/update)
        WHERE FAPV.DESIGNGUID IN ('c17d1557-513d-443f-8013-a31eb541455b')  -- Care leavers, Pathway needs assessment and plan
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY
            FAPV.ANSWERFORSUBJECTID,
            FAPV.INSTANCEID
    ) FAPV
),
WORKER AS (    -- responsible social worker
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
        PPR.STARTDATE                        AS WORKER_START_DATE,
        PPR.CLOSEDATE                        AS WORKER_END_DATE
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW'
),
TEAM AS (      -- responsible team
    SELECT 
        PPR.RELATIONSHIPID  AS ID,
        PPR.PERSONID        AS PERSONID,
        PPR.ORGANISATIONID  AS ALLOCATED_TEAM,
        PPR.DATESTARTED     AS TEAM_START_DATE,
        PPR.DATEENDED       AS TEAM_END_DATE
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT'
),
-- EXCLUSIONS AS (
--     SELECT
--         PV.PERSONID
--     FROM PERSONVIEW PV
--     WHERE PV.PERSONID IN (   -- remove admin or OLM test records
--             1,2,3,4,5,6
--         )
--         OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
--         OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
--         OR UPPER(PV.SURNAME)  LIKE '%DUPLICATE%'
-- ),
CARELEAVER AS (
    SELECT
        CARELEAVER.CARELEAVERID,
        CARELEAVER.PERSONID,
        CARELEAVER.ELIGIBILITY,
        CARELEAVER.INTOUCHCODE,
        CARELEAVER.CONTACTDATE,
        CARELEAVER.ACCOMODATIONCODE,
        CASE
            WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered suitable'   THEN '1'
            WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered unsuitable' THEN '2'
        END AS ACCOMSUITABLE,
        CARELEAVER.MAINACTIVITYCODE,
        RANK() OVER (
            PARTITION BY CARELEAVER.PERSONID
            ORDER BY CARELEAVER.CONTACTDATE DESC
        ) AS LATEST_RECORD
    FROM CLACARELEAVERDETAILSVIEW CARELEAVER
    WHERE
        -- back check person exists in ssd_person cohort, exclusions applied
        EXISTS (
            SELECT 1
            FROM ssd_person sp
            WHERE sp.pers_person_id = CARELEAVER.PERSONID
        )
)
SELECT
    CARELEAVER.CARELEAVERID          AS clea_table_id,                     -- metadata={"item_ref":"CLEA001A"}
    CARELEAVER.PERSONID              AS clea_person_id,                    -- metadata={"item_ref":"CLEA002A"}
    CARELEAVER.ELIGIBILITY           AS clea_care_leaver_eligibility,      -- metadata={"item_ref":"CLEA003A"}
    CARELEAVER.INTOUCHCODE           AS clea_care_leaver_in_touch,         -- metadata={"item_ref":"CLEA004A"}
    CARELEAVER.CONTACTDATE::DATE     AS clea_care_leaver_latest_contact,   -- metadata={"item_ref":"CLEA005A"}
    CARELEAVER.ACCOMODATIONCODE      AS clea_care_leaver_accommodation,    -- metadata={"item_ref":"CLEA006A"}
    CARELEAVER.ACCOMSUITABLE         AS clea_care_leaver_accom_suitable,   -- metadata={"item_ref":"CLEA007A"}
    CARELEAVER.MAINACTIVITYCODE      AS clea_care_leaver_activity,         -- metadata={"item_ref":"CLEA008A"}
    CARELEAVER_REVIEW.REIEW_DATE     AS clea_pathway_plan_review_date,     -- metadata={"item_ref":"CLEA009A"}
    WORKER.ALLOCATED_WORKER          AS clea_care_leaver_personal_advisor, -- metadata={"item_ref":"CLEA010A"}
    TEAM.ALLOCATED_TEAM              AS clea_care_leaver_allocated_team,   -- metadata={"item_ref":"CLEA011A"}
    WORKER.ALLOCATED_WORKER          AS clea_care_leaver_worker_id         -- metadata={"item_ref":"CLEA012A"}
FROM CARELEAVER
LEFT JOIN CARELEAVER_REVIEW
    ON CARELEAVER_REVIEW.PERSONID = CARELEAVER.PERSONID
   AND CARELEAVER_REVIEW.LATEST_REVIEW = 1
LEFT JOIN WORKER
    ON WORKER.PERSONID = CARELEAVER.PERSONID
   AND CARELEAVER.CONTACTDATE >= WORKER.WORKER_START_DATE
   AND CARELEAVER.CONTACTDATE <= COALESCE(WORKER.WORKER_END_DATE, CURRENT_DATE)
LEFT JOIN TEAM
    ON TEAM.PERSONID = CARELEAVER.PERSONID
   AND CARELEAVER.CONTACTDATE >= TEAM.TEAM_START_DATE
   AND CARELEAVER.CONTACTDATE <= COALESCE(TEAM.TEAM_END_DATE, CURRENT_DATE)
WHERE CARELEAVER.LATEST_RECORD = 1;
