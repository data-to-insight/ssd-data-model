/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_reviews;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_reviews (
    clar_cla_review_id            VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAR001A"}
    clar_cla_id                   VARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
    clar_cla_review_due_date      TIMESTAMP NULL,            -- metadata={"item_ref":"CLAR003A"}
    clar_cla_review_date          TIMESTAMP NULL,            -- metadata={"item_ref":"CLAR004A"}
    clar_cla_review_cancelled     CHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
    clar_cla_review_participation VARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
);

TRUNCATE TABLE ssd_cla_reviews;

INSERT INTO ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
)
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
),

CLA_REVIEW AS (
    SELECT 
        CLA_REVIEW_INNER.*,
        CLA.PERIODOFCAREID
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID AS PERSONID,
            FAPV.INSTANCEID         AS FORMID,
            MAX(
                CASE WHEN FAPV.CONTROLNAME = 'dateOfNextReview'
                     THEN FAPV.ANSWERVALUE
                END
            )::DATE                 AS NEXT_REVIEW,
            MAX(
                CASE WHEN FAPV.CONTROLNAME = 'dateOfReview'
                     THEN FAPV.ANSWERVALUE
                END
            )::DATE                 AS DATE_OF_REVIEW
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('b5c5c8d8-5ba7-4919-a3cd-9722e8e90aaf') -- Child in Care: IRO decisions
          AND FAPV.INSTANCESTATE = 'COMPLETE'
          AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
        GROUP BY
            FAPV.ANSWERFORSUBJECTID,
            FAPV.INSTANCEID
    ) CLA_REVIEW_INNER
    LEFT JOIN CLAPERIODOFCAREVIEW CLA
        ON CLA.PERSONID = CLA_REVIEW_INNER.PERSONID
       AND CLA_REVIEW_INNER.DATE_OF_REVIEW >= CLA.ADMISSIONDATE
       AND CLA_REVIEW_INNER.DATE_OF_REVIEW <= COALESCE(CLA.DISCHARGEDATE, CURRENT_DATE)
),

IRO_REVIEW AS (
    SELECT
        FAPV.ANSWERFORSUBJECTID AS PERSONID,
        FAPV.INSTANCEID         AS FORMID,
        MAX(
            CASE WHEN FAPV.CONTROLNAME = 'howWasTheChildAbleToContributeTheirViewsToTheReview'
                 THEN FAPV.SHORTANSWERVALUE
            END
        )                      AS PARTICIPATION,
        MAX(
            CASE WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
                 THEN FAPV.ANSWERVALUE
            END
        )::DATE                AS DATE_OF_MEETING
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('79f3495c-134f-4e69-b00f-7621925419f7') -- Independent Reviewing Officer: Quality assurance
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child/young person in care review'
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
)

SELECT
    IRO_REVIEW.FORMID         AS clar_cla_review_id,           -- metadata={"item_ref":"CLAR001A"}
    CLA_REVIEW.PERIODOFCAREID AS clar_cla_id,                  -- metadata={"item_ref":"CLAR011A"}
    PREVIOUSR.NEXT_REVIEW     AS clar_cla_review_due_date,     -- metadata={"item_ref":"CLAR003A"}
    CLA_REVIEW.DATE_OF_REVIEW AS clar_cla_review_date,         -- metadata={"item_ref":"CLAR004A"}
    'N'                       AS clar_cla_review_cancelled,    -- metadata={"item_ref":"CLAR012A"}
    IRO_REVIEW.PARTICIPATION  AS clar_cla_review_participation -- metadata={"item_ref":"CLAR007A"}
FROM CLA_REVIEW
LEFT JOIN LATERAL (
    SELECT *
    FROM CLA_REVIEW PREVIOUSR
    WHERE PREVIOUSR.PERSONID = CLA_REVIEW.PERSONID
      AND PREVIOUSR.PERIODOFCAREID = CLA_REVIEW.PERIODOFCAREID
      AND PREVIOUSR.DATE_OF_REVIEW < CLA_REVIEW.DATE_OF_REVIEW
    ORDER BY PREVIOUSR.DATE_OF_REVIEW DESC
    FETCH FIRST 1 ROW ONLY
) PREVIOUSR ON TRUE
LEFT JOIN IRO_REVIEW
    ON IRO_REVIEW.PERSONID = CLA_REVIEW.PERSONID
   AND IRO_REVIEW.DATE_OF_MEETING = CLA_REVIEW.DATE_OF_REVIEW;
