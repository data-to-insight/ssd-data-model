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

IF OBJECT_ID('tempdb..#ssd_cla_episodes', 'U') IS NOT NULL
    DROP TABLE #ssd_cla_episodes;

IF OBJECT_ID('[SSD].[ssd_cla_episodes]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [SSD].[ssd_cla_episodes])
        TRUNCATE TABLE [SSD].[ssd_cla_episodes];
END
ELSE
BEGIN
    CREATE TABLE [SSD].[ssd_cla_episodes] (
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
        CONVERT(NVARCHAR(48), F.APV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), F.APV.INSTANCEID)        AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), F.APV.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN F.APV.CONTROLNAME = 'CINCensus_ReferralSource'
                 THEN F.APV.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN F.APV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
                 THEN F.APV.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN F.APV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
                 THEN F.APV.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN F.APV.CONTROLNAME = 'CINCensus_DateOfReferral'
                 THEN CAST(F.APV.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] F.APV
    WHERE F.APV.DESIGNGUID = 'e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f'
      AND F.APV.INSTANCESTATE = 'COMPLETE'
    GROUP BY
        F.APV.ANSWERFORSUBJECTID,
        F.APV.INSTANCEID,
        F.APV.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE RB.PRIMARY_NEED_CAT
            WHEN 'Abuse or neglect'                THEN 'N1'
            WHEN 'Child''s disability'             THEN 'N2'
            WHEN 'Parental illness/disability'     THEN 'N3'
            WHEN 'Family in acute stress'          THEN 'N4'
            WHEN 'Family dysfunction'              THEN 'N5'
            WHEN 'Socially unacceptable behaviour' THEN 'N6'
            WHEN 'Low income'                      THEN 'N7'
            WHEN 'Absent parenting'                THEN 'N8'
            WHEN 'Cases other than child in need'  THEN 'N9'
            WHEN 'Not stated'                      THEN 'N0'
        END AS PRIMARY_NEED_RANK
    FROM REFERRAL_BASE RB
),
IRO_MEETING AS (
    SELECT
        CONVERT(NVARCHAR(48), F.APV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), F.APV.INSTANCEID)        AS ASSESSMENTID,
        MAX(CAST(F.APV.DATEANSWERVALUE AS DATE))       AS DATE_OF_MEETING
    FROM [eclipseDelta].[dbo].[FORMANSWERPERSONVIEW] F.APV
    WHERE F.APV.DESIGNGUID = '2d9d174f-77ed-40bd-ac2b-cae8015ad799'
      AND F.APV.INSTANCESTATE = 'COMPLETE'
      AND F.APV.CONTROLNAME = 'dateOfMeeting'
    GROUP BY
        F.APV.ANSWERFORSUBJECTID,
        F.APV.INSTANCEID
)
INSERT INTO [SSD].[ssd_cla_episodes] (
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
    CONVERT(NVARCHAR(48), CE.EPISODEOFCAREID),
    CONVERT(NVARCHAR(48), CE.PERSONID),
    CAST(CE.EOCSTARTDATE AS DATETIME),
    CONVERT(NVARCHAR(100), CE.EOCSTARTREASONCODE),
    CASE CE.CATEGORYOFNEED
        WHEN 'Abuse or neglect'                THEN 'N1'
        WHEN 'Child''s disability'             THEN 'N2'
        WHEN 'Parental illness/disability'     THEN 'N3'
        WHEN 'Family in acute stress'          THEN 'N4'
        WHEN 'Family dysfunction'              THEN 'N5'
        WHEN 'Socially unacceptable behaviour' THEN 'N6'
        WHEN 'Low income'                      THEN 'N7'
        WHEN 'Absent parenting'                THEN 'N8'
        WHEN 'Cases other than child in need'  THEN 'N9'
        WHEN 'Not stated'                      THEN 'N0'
    END,
    CAST(CE.EOCENDDATE AS DATETIME),
    CONVERT(NVARCHAR(255), CE.EOCENDREASONCODE),
    CONVERT(NVARCHAR(48), CE.PERIODOFCAREID),
    RFR.ASSESSMENTID,
    CONVERT(NVARCHAR(48), CE.PLACEMENTADDRESSID),
    CAST(CLA.ADMISSIONDATE AS DATETIME),
    CAST(IROA.DATE_OF_MEETING AS DATETIME)
FROM [eclipseDelta].[dbo].[CLAEPISODEOFCAREVIEW] CE
LEFT JOIN [eclipseDelta].[dbo].[CLAPERIODOFCAREVIEW] CLA
    ON CLA.PERSONID = CE.PERSONID
   AND CLA.PERIODOFCAREID = CE.PERIODOFCAREID
OUTER APPLY (
    SELECT TOP (1) R.ASSESSMENTID
    FROM REFERRAL R
    WHERE R.PERSONID = CONVERT(VARCHAR(48), CE.PERSONID)
      AND CAST(CE.EOCSTARTDATE AS DATE) >= R.DATE_OF_REFERRAL
    ORDER BY R.DATE_OF_REFERRAL DESC
) RFR
OUTER APPLY (
    SELECT TOP (1) I.DATE_OF_MEETING
    FROM IRO_MEETING I
    WHERE I.PERSONID = CONVERT(VARCHAR(48), CE.PERSONID)
      AND I.DATE_OF_MEETING >= CAST(CLA.ADMISSIONDATE AS DATE)
      AND I.DATE_OF_MEETING <= CAST(ISNULL(CLA.DISCHARGEDATE, GETDATE()) AS DATE)
    ORDER BY I.DATE_OF_MEETING DESC
) IROA
WHERE EXISTS (
    SELECT 1
    FROM [SSD].[ssd_person] sp
    WHERE sp.pers_person_id = CONVERT(VARCHAR(48), CE.PERSONID)
);