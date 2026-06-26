/* ===========================================
   CREATE TABLE
   =========================================== */

IF OBJECT_ID('ssd_sdq_scores', 'U') IS NULL
BEGIN
    CREATE TABLE ssd_sdq_scores (
        csdq_table_id           VARCHAR(48) PRIMARY KEY,
        csdq_person_id          VARCHAR(48),
        csdq_sdq_completed_date DATETIME,
        csdq_sdq_score          INT,
        csdq_sdq_reason         VARCHAR(100)
    );
END;

TRUNCATE TABLE ssd_sdq_scores;

-- ============================================================
-- MAIN QUERY
-- ============================================================

;WITH EXCLUSIONS AS (
    SELECT PERSONID
    FROM [eclipseDelta].[dbo].[PERSONVIEW]
    WHERE PERSONID IN (1,2,3,4,5,6)
       OR ISNULL(DUPLICATED, '?') = 'DUPLICATE'
       OR UPPER(FORENAME) LIKE '%DUPLICATE%'
       OR UPPER(SURNAME)  LIKE '%DUPLICATE%'
),

SDQ_BASE AS (
    SELECT 
        FAPV.INSTANCEID         AS instance_id, 
        FAPV.ANSWERFORSUBJECTID AS person_id,

        MAX(CASE
                WHEN CAST(FAPV.CONTROLNAME AS VARCHAR(200))= '903Return_dateOfLatestSDQRecord'
                THEN CAST(FAPV.DATEANSWERVALUE AS DATE)
            END) AS completed_date,

        MAX(CASE
                WHEN CAST(FAPV.CONTROLNAME AS VARCHAR(200)) = '903Return_reasonForNotSubmittingStrengthsAndDifficultiesQuestionnaireInPeriod'
                THEN CAST(FAPV.ANSWERVALUE AS VARCHAR(50))
            END) AS reason,

        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'youngPersonsStrengthsAndDifficultiesQuestionnaireScore'
                THEN CAST(FAPV.ANSWERVALUE AS VARCHAR(50))
            END) AS score

    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] FAPV
    WHERE FAPV.DESIGNGUID = CONVERT(UNIQUEIDENTIFIER, 'fb7f6ffc-e8a1-4b45-8eaa-356a5be33895')
      AND CAST(FAPV.INSTANCESTATE AS VARCHAR(255)) = 'COMPLETE'
      AND TRY_CAST(FAPV.ANSWERFORSUBJECTID AS BIGINT) NOT IN (SELECT PERSONID FROM EXCLUSIONS)
    GROUP BY
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID
)

-- ============================================================
-- INSERT
-- ============================================================

INSERT INTO ssd_sdq_scores (
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_completed_date,
    csdq_sdq_score,
    csdq_sdq_reason
)
SELECT
    instance_id,
    person_id,
    completed_date,
    CAST(score AS INT),

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
    END
FROM SDQ_BASE;