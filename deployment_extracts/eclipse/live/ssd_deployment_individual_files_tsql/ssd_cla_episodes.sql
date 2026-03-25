-- META-CONTAINER: {"type": "table", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - FORMANSWERPERSONVIEW
-- - CLAEPISODEOFCAREVIEW
-- - CLAPERIODOFCAREVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_episodes', 'U') IS NOT NULL DROP TABLE #ssd_cla_episodes;

IF OBJECT_ID('ssd_cla_episodes', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_episodes)
        TRUNCATE TABLE ssd_cla_episodes;
END
ELSE
BEGIN
    CREATE TABLE ssd_cla_episodes (
        clae_cla_episode_id             NVARCHAR(48)  NOT NULL PRIMARY KEY,
        clae_person_id                  NVARCHAR(48)  NULL,
        clae_cla_placement_id           NVARCHAR(48)  NULL,
        clae_cla_episode_start_date     DATETIME      NULL,
        clae_cla_episode_start_reason   NVARCHAR(100) NULL,
        clae_cla_primary_need_code      NVARCHAR(3)   NULL,
        clae_cla_episode_ceased_date    DATETIME      NULL,
        clae_cla_episode_ceased_reason  NVARCHAR(255) NULL,
        clae_cla_id                     NVARCHAR(48)  NULL,
        clae_referral_id                NVARCHAR(48)  NULL,
        clae_cla_last_iro_contact_date  DATETIME      NULL,
        clae_entered_care_date          DATETIME      NULL
    );
END;

;WITH REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), FAPV.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource' THEN FAPV.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed' THEN FAPV.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory' THEN FAPV.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral' THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID,
        FAPV.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE
            WHEN RB.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
            WHEN RB.PRIMARY_NEED_CAT = 'Child''s disability'             THEN 'N2'
            WHEN RB.PRIMARY_NEED_CAT = 'Parental illness/disability'     THEN 'N3'
            WHEN RB.PRIMARY_NEED_CAT = 'Family in acute stress'          THEN 'N4'
            WHEN RB.PRIMARY_NEED_CAT = 'Family dysfunction'              THEN 'N5'
            WHEN RB.PRIMARY_NEED_CAT = 'Socially unacceptable behaviour' THEN 'N6'
            WHEN RB.PRIMARY_NEED_CAT = 'Low income'                      THEN 'N7'
            WHEN RB.PRIMARY_NEED_CAT = 'Absent parenting'                THEN 'N8'
            WHEN RB.PRIMARY_NEED_CAT = 'Cases other than child in need'  THEN 'N9'
            WHEN RB.PRIMARY_NEED_CAT = 'Not stated'                      THEN 'N0'
        END AS PRIMARY_NEED_RANK
    FROM REFERRAL_BASE RB
),
IRO_MEETING AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)         AS ASSESSMENTID,
        MAX(CAST(FAPV.DATEANSWERVALUE AS DATE))        AS DATE_OF_MEETING
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('2d9d174f-77ed-40bd-ac2b-cae8015ad799')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.CONTROLNAME = 'dateOfMeeting'
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
)
INSERT INTO ssd_cla_episodes (
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need_code,
    clae_cla_episode_ceased_date,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_placement_id,
    clae_entered_care_date,
    clae_cla_last_iro_contact_date
)
SELECT
    CONVERT(NVARCHAR(48), CLA_EPISODE.EPISODEOFCAREID) AS clae_cla_episode_id,
    CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID)        AS clae_person_id,
    CAST(CLA_EPISODE.EOCSTARTDATE AS DATETIME)         AS clae_cla_episode_start_date,
    CONVERT(NVARCHAR(100), CLA_EPISODE.EOCSTARTREASONCODE) AS clae_cla_episode_start_reason,
    CASE
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Abuse or neglect'                THEN 'N1'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Child''s disability'             THEN 'N2'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Parental illness/disability'     THEN 'N3'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family in acute stress'          THEN 'N4'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family dysfunction'              THEN 'N5'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Socially unacceptable behaviour' THEN 'N6'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Low income'                      THEN 'N7'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Absent parenting'                THEN 'N8'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Cases other than child in need'  THEN 'N9'
        WHEN CLA_EPISODE.CATEGORYOFNEED = 'Not stated'                      THEN 'N0'
    END AS clae_cla_primary_need_code,
    CAST(CLA_EPISODE.EOCENDDATE AS DATETIME)           AS clae_cla_episode_ceased_date,
    CONVERT(NVARCHAR(255), CLA_EPISODE.EOCENDREASONCODE) AS clae_cla_episode_ceased_reason,
    CONVERT(NVARCHAR(48), CLA_EPISODE.PERIODOFCAREID)  AS clae_cla_id,
    REFR.ASSESSMENTID                                   AS clae_referral_id,
    CONVERT(NVARCHAR(48), CLA_EPISODE.PLACEMENTADDRESSID) AS clae_cla_placement_id,
    CAST(CLA.ADMISSIONDATE AS DATETIME)                AS clae_entered_care_date,
    CAST(IROA.DATE_OF_MEETING AS DATETIME)             AS clae_cla_last_iro_contact_date
FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
LEFT JOIN CLAPERIODOFCAREVIEW CLA
    ON CLA.PERSONID = CLA_EPISODE.PERSONID
   AND CLA.PERIODOFCAREID = CLA_EPISODE.PERIODOFCAREID
OUTER APPLY (
    SELECT TOP (1)
        R.ASSESSMENTID,
        R.DATE_OF_REFERRAL
    FROM REFERRAL R
    WHERE R.PERSONID = CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID)
      AND CAST(CLA_EPISODE.EOCSTARTDATE AS DATE) >= R.DATE_OF_REFERRAL
    ORDER BY R.DATE_OF_REFERRAL DESC
) REFR
OUTER APPLY (
    SELECT TOP (1)
        I.DATE_OF_MEETING
    FROM IRO_MEETING I
    WHERE I.PERSONID = CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID)
      AND I.DATE_OF_MEETING >= CAST(CLA.ADMISSIONDATE AS DATE)
      AND I.DATE_OF_MEETING <= CAST(ISNULL(CLA.DISCHARGEDATE, GETDATE()) AS DATE)
    ORDER BY I.DATE_OF_MEETING DESC
) IROA
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID)
);