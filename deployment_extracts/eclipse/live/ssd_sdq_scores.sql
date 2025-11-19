/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_sdq_scores;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_sdq_scores (
    csdq_table_id           VARCHAR(48) PRIMARY KEY,    -- metadata={"item_ref":"CSDQ001A"}
    csdq_person_id          VARCHAR(48),    -- metadata={"item_ref":"CSDQ002A"}
    csdq_sdq_completed_date TIMESTAMP,      -- metadata={"item_ref":"CSDQ003A"}
    csdq_sdq_score          INTEGER,        -- metadata={"item_ref":"CSDQ005A"}
    csdq_sdq_reason         VARCHAR(100)    -- metadata={"item_ref":"CSDQ004A", "item_status":"P"}
);

TRUNCATE TABLE ssd_sdq_scores;

INSERT INTO ssd_sdq_scores (
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_completed_date,
    csdq_sdq_score,
    csdq_sdq_reason
)
WITH EXCLUSIONS AS (
    SELECT
        PV.PERSONID
    FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
        OR COALESCE(PV.DUPLICATED, '?') IN ('DUPLICATE')
        OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
        OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
),
SDQ_BASE AS (
    SELECT 
        FAPV.INSTANCEID             AS instance_id, 
        FAPV.ANSWERFORSUBJECTID     AS person_id,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = '903Return_dateOfLatestSDQRecord'
                THEN FAPV.ANSWERVALUE
            END)::DATE              AS completed_date,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = '903Return_reasonForNotSubmittingStrengthsAndDifficultiesQuestionnaireInPeriod'
                THEN FAPV.ANSWERVALUE
            END)                    AS reason,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'youngPersonsStrengthsAndDifficultiesQuestionnaireScore'
                THEN FAPV.ANSWERVALUE
            END)                    AS score
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fb7f6ffc-e8a1-4b45-8eaa-356a5be33895')  -- Child in Care: SDQ scores
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID
)
SELECT
    instance_id                         AS csdq_table_id,           -- metadata={"item_ref":"CSDQ001A"}
    person_id                           AS csdq_person_id,          -- metadata={"item_ref":"CSDQ002A"}
    completed_date                      AS csdq_sdq_completed_date, -- metadata={"item_ref":"CSDQ003A"}
    score::INTEGER                      AS csdq_sdq_score,          -- metadata={"item_ref":"CSDQ005A"}
    CASE
        WHEN reason = 'No form returned as child was aged under 4 or over 17 at date of latest assessment'
            THEN 'SDQ1'
        WHEN reason = 'Carer(s) refused to complete and return questionnaire'
            THEN 'SDQ2'
        WHEN reason = 'Not possible to complete the questionnaire due to severity of the child’s disability'
            THEN 'SDQ3'
        WHEN reason = 'Other'
            THEN 'SDQ4'
        WHEN reason = 'Child or young person refuses to allow an SDQ to be completed'
            THEN 'SDQ5'
        ELSE NULL
    END                                  AS csdq_sdq_reason          -- metadata={"item_ref":"CSDQ004A"}
FROM SDQ_BASE;
