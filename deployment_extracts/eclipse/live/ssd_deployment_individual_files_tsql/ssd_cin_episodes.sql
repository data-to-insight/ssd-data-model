-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: 
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]    
-- Dependencies: 
-- - CLASSIFICATIONPERSONVIEW
-- - CLAEPISODEOFCAREVIEW
-- - FORMANSWERPERSONVIEW
-- - ssd_person
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cin_episodes', 'U') IS NOT NULL DROP TABLE #ssd_cin_episodes;

IF OBJECT_ID('ssd_cin_episodes', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cin_episodes)
        TRUNCATE TABLE ssd_cin_episodes;
END
ELSE
BEGIN
    CREATE TABLE ssd_cin_episodes
    (
        cine_referral_id           NVARCHAR(48)  NOT NULL PRIMARY KEY,
        cine_person_id             NVARCHAR(48)  NULL,
        cine_referral_date         DATETIME      NULL,
        cine_cin_primary_need_code NVARCHAR(3)   NULL,
        cine_referral_source_code  NVARCHAR(48)  NULL,
        cine_referral_source_desc  NVARCHAR(255) NULL,
        cine_referral_outcome_json NVARCHAR(4000) NULL,
        cine_referral_nfa          NCHAR(1)      NULL,
        cine_close_reason          NVARCHAR(100) NULL,
        cine_close_date            DATETIME      NULL,
        cine_referral_team         NVARCHAR(48)  NULL,
        cine_referral_worker_id    NVARCHAR(100) NULL
    );
END

;WITH ALL_CIN_EPISODES AS (
    SELECT
        CONVERT(NVARCHAR(48), CLA.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(48), CLA.CLASSIFICATIONASSIGNMENTID) AS EPISODEID,
        CAST(CLA.STARTDATE AS DATE) AS EPISODE_STARTDATE,
        CAST(CLA.ENDDATE   AS DATE) AS EPISODE_ENDDATE,
        CLA.ENDREASON
    FROM CLASSIFICATIONPERSONVIEW CLA
    WHERE CLA.STATUS NOT IN ('DELETED')
      AND (CLA.CLASSIFICATIONPATHID IN (4, 51) OR CLA.CLASSIFICATIONCODEID IN (1270))

    UNION ALL

    SELECT
        CONVERT(NVARCHAR(48), CLA_EPISODE.PERSONID) AS PERSONID,
        CONVERT(NVARCHAR(48), CLA_EPISODE.EPISODEOFCAREID) AS EPISODEID,
        CAST(CLA_EPISODE.EOCSTARTDATE AS DATE) AS EPISODE_STARTDATE,
        CAST(CLA_EPISODE.EOCENDDATE   AS DATE) AS EPISODE_ENDDATE,
        CLA_EPISODE.EOCENDREASON AS ENDREASON
    FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
),
REFERRAL_BASE AS (
    SELECT
        CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS PERSONID,
        CONVERT(NVARCHAR(48), FAPV.INSTANCEID)        AS ASSESSMENTID,
        CONVERT(NVARCHAR(100), FAPV.SUBMITTERPERSONID) AS SUBMITTERPERSONID,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource' THEN FAPV.ANSWERVALUE END) AS REFERRAL_SOURCE,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed' THEN FAPV.ANSWERVALUE END) AS NEXT_STEP,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory' THEN FAPV.ANSWERVALUE END) AS PRIMARY_NEED_CAT,
        MAX(CASE WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral' THEN CAST(FAPV.DATEANSWERVALUE AS DATE) END) AS DATE_OF_REFERRAL
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f')
      AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY FAPV.ANSWERFORSUBJECTID, FAPV.INSTANCEID, FAPV.SUBMITTERPERSONID
),
REFERRAL AS (
    SELECT
        RB.*,
        CASE WHEN RB.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
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
EPISODES_ORDERED AS (
    SELECT
        ACE.PERSONID,
        ACE.EPISODEID,
        ACE.EPISODE_STARTDATE,
        ACE.EPISODE_ENDDATE,
        ACE.ENDREASON,
        CASE
            WHEN ACE.EPISODE_STARTDATE >= LAG(ACE.EPISODE_STARTDATE) OVER (
                    PARTITION BY ACE.PERSONID
                    ORDER BY ACE.EPISODE_STARTDATE, CASE WHEN ACE.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END, ACE.EPISODE_ENDDATE
                 )
             AND ACE.EPISODE_STARTDATE <= DATEADD(
                    DAY, 1,
                    ISNULL(
                        LAG(ACE.EPISODE_ENDDATE) OVER (
                            PARTITION BY ACE.PERSONID
                            ORDER BY ACE.EPISODE_STARTDATE, CASE WHEN ACE.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END, ACE.EPISODE_ENDDATE
                        ),
                        CAST(GETDATE() AS DATE)
                    )
                 )
                THEN 0
            ELSE 1
        END AS NEXT_START_FLAG
    FROM ALL_CIN_EPISODES ACE
),
EPISODES_GROUPED AS (
    SELECT
        EO.*,
        SUM(EO.NEXT_START_FLAG) OVER (
            PARTITION BY EO.PERSONID
            ORDER BY EO.EPISODE_STARTDATE, EO.EPISODEID
        ) AS EPISODE_GRP,
        CASE WHEN EO.NEXT_START_FLAG = 1 THEN EO.EPISODEID END AS EPISODE_ID
    FROM EPISODES_ORDERED EO
),
CIN_BASE AS (
    SELECT
        EG.PERSONID,
        EG.EPISODE_GRP,
        MIN(EG.EPISODE_STARTDATE) AS CINE_START_DATE,
        CASE
            WHEN MAX(CASE WHEN EG.EPISODE_ENDDATE IS NULL THEN 1 ELSE 0 END) = 1 THEN NULL
            ELSE MAX(EG.EPISODE_ENDDATE)
        END AS CINE_CLOSE_DATE,
        MAX(EG.EPISODE_ID) AS LAST_CINE_ID
    FROM EPISODES_GROUPED EG
    GROUP BY EG.PERSONID, EG.EPISODE_GRP
),
CIN_EPISODE AS (
    SELECT
        CB.PERSONID,
        CB.CINE_START_DATE,
        CB.CINE_CLOSE_DATE,
        ACE.ENDREASON AS CINE_REASON_END,
        RA.ASSESSMENTID,
        CONVERT(NVARCHAR(48), CONCAT(CB.PERSONID, RA.ASSESSMENTID)) AS REFERRALID,
        CAST(RA.DATE_OF_REFERRAL AS DATETIME) AS DATE_OF_REFERRAL,
        RA.PRIMARY_NEED_RANK,
        RA.SUBMITTERPERSONID,
        RA.REFERRAL_SOURCE,
        RA.NEXT_STEP
    FROM CIN_BASE CB
    LEFT JOIN ALL_CIN_EPISODES ACE
           ON ACE.PERSONID = CB.PERSONID
          AND ACE.EPISODE_ENDDATE = CB.CINE_CLOSE_DATE
    OUTER APPLY (
        SELECT TOP (1) *
        FROM REFERRAL R
        WHERE R.PERSONID = CB.PERSONID
          AND R.DATE_OF_REFERRAL <= CB.CINE_START_DATE
        ORDER BY R.DATE_OF_REFERRAL DESC
    ) RA
)
INSERT INTO ssd_cin_episodes (
    cine_referral_id,
    cine_person_id,
    cine_referral_date,
    cine_cin_primary_need_code,
    cine_referral_source_code,
    cine_referral_source_desc,
    cine_referral_outcome_json,
    cine_referral_nfa,
    cine_close_reason,
    cine_close_date,
    cine_referral_team,
    cine_referral_worker_id
)
SELECT
    CE.REFERRALID             AS cine_referral_id,
    CE.PERSONID               AS cine_person_id,
    CE.DATE_OF_REFERRAL       AS cine_referral_date,
    CE.PRIMARY_NEED_RANK      AS cine_cin_primary_need_code,
    CASE
        WHEN CE.REFERRAL_SOURCE = 'Acquaintance'                               THEN '1B'
        WHEN CE.REFERRAL_SOURCE = 'A & E'                                      THEN '3E'
        WHEN CE.REFERRAL_SOURCE = 'Anonymous'                                  THEN '9'
        WHEN CE.REFERRAL_SOURCE = 'Early help'                                 THEN '5D'
        WHEN CE.REFERRAL_SOURCE = 'Education Services'                         THEN '2B'
        WHEN CE.REFERRAL_SOURCE = 'External e.g. from another local authority' THEN '5C'
        WHEN CE.REFERRAL_SOURCE = 'Family Member/Relative/Carer'               THEN '1A'
        WHEN CE.REFERRAL_SOURCE = 'GP'                                         THEN '3A'
        WHEN CE.REFERRAL_SOURCE = 'Health Visitor'                             THEN '3B'
        WHEN CE.REFERRAL_SOURCE = 'Housing'                                    THEN '4'
        WHEN CE.REFERRAL_SOURCE = 'Other'                                      THEN '1D'
        WHEN CE.REFERRAL_SOURCE = 'Other Health Services'                      THEN '3F'
        WHEN CE.REFERRAL_SOURCE = 'Other - including children centres'         THEN '8'
        WHEN CE.REFERRAL_SOURCE = 'Other internal e,g, BC Council'             THEN '5B'
        WHEN CE.REFERRAL_SOURCE = 'Other Legal Agency'                         THEN '7'
        WHEN CE.REFERRAL_SOURCE = 'Other Primary Health Services'              THEN '3D'
        WHEN CE.REFERRAL_SOURCE = 'Police'                                     THEN '6'
        WHEN CE.REFERRAL_SOURCE = 'School'                                     THEN '2A'
        WHEN CE.REFERRAL_SOURCE = 'School Nurse'                               THEN '3C'
        WHEN CE.REFERRAL_SOURCE = 'Self'                                       THEN '1C'
        WHEN CE.REFERRAL_SOURCE = 'Social care e.g. adult social care'         THEN '5A'
        WHEN CE.REFERRAL_SOURCE = 'Unknown'                                    THEN '10'
    END AS cine_referral_source_code,
    CE.REFERRAL_SOURCE AS cine_referral_source_desc,
    CONVERT(NVARCHAR(4000),
        '{'
        + '"OUTCOME_SINGLE_ASSESSMENT_FLAG":"' + CASE WHEN CE.NEXT_STEP IN (
                'Assessment',
                'Family Help Discussion (10 days)',
                'Family Help Discussion (CAT) -10 days',
                'Family Help Discussion (DCYP)- 10 days'
            ) THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_NFA_FLAG":"' + CASE WHEN CE.NEXT_STEP IN ('No further action','Signpost') THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_STRATEGY_DISCUSSION_FLAG":"' + CASE WHEN CE.NEXT_STEP = 'Strategy Discussion/Meeting' THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_CLA_REQUEST_FLAG":"N",'
        + '"OUTCOME_NON_AGENCY_ADOPTION_FLAG":"' + CASE WHEN CE.NEXT_STEP = 'Adoption or Special Guardianship support' THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_PRIVATE_FOSTERING_FLAG":"' + CASE WHEN CE.NEXT_STEP = 'Private Fostering' THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_CP_TRANSFER_IN_FLAG":"' + CASE WHEN CE.NEXT_STEP = 'Transfer in child protection conference' THEN 'Y' ELSE 'N' END + '",'
        + '"OUTCOME_CP_CONFERENCE_FLAG":"N",'
        + '"OUTCOME_CARE_LEAVER_FLAG":"N",'
        + '"OTHER_OUTCOMES_EXIST_FLAG":"' + CASE WHEN CE.NEXT_STEP IN (
                'Asylum seeker',
                'Court Report Request Section 7/Section 37',
                'Disabled children service',
                'No recourse to public funds',
                'Family Help Discussion(45 Day)',
                'Family Help Discussion (45 days)',
                'Early Intervention',
                'Universal Services'
            ) THEN 'Y' ELSE 'N' END + '"'
        + '}'
    ) AS cine_referral_outcome_json,
    CASE WHEN CE.NEXT_STEP = 'No further action' THEN 'Y' ELSE 'N' END AS cine_referral_nfa,
    CASE
        WHEN CE.CINE_REASON_END IN (
                 'Adopted',
                 'Adopted - Consent dispensed with',
                 'Adopted - Application unopposed',
                 'Adopted - PRE 2000',
                 'PRE-Adopted',
                 'Adopted consent dispensed with by court',
                 'ADOPTED/FREED FOR ADOPTION - PRE 2000',
                 'Adopted - application for an adoption order unopposed'
             ) THEN 'RC1'
        WHEN CE.CINE_REASON_END IN ('Died','Child/young person has died') THEN 'RC2'
        WHEN CE.CINE_REASON_END IN ('Child Arrangements Order','Residence order or a child arrangements order') THEN 'RC3'
        WHEN CE.CINE_REASON_END IN (
                 'Special Guardianship Order',
                 'Special guardianship made to former foster carers',
                 'Special guardianship made to other than former foster carers',
                 'Special guardianship relative/friend not former foster carer(s)',
                 'Special guardianship other not relative/friend/former foster carer'
             ) THEN 'RC4'
        WHEN CE.CINE_REASON_END = 'Child moved permanently from area' THEN 'RC5'
        WHEN CE.CINE_REASON_END IN (
                 'Transferred to Adult Services',
                 'Transferred to care of Adult Social Services',
                 'Transferred to residential care funded by Adult Social Services'
             ) THEN 'RC6'
        WHEN CE.CINE_REASON_END = 'Case closed after assessment, no further action' THEN 'RC8'
        WHEN CE.CINE_REASON_END IN (
                 'Case closed after assessment, referred to early help',
                 'Case closed after assessment, referred to EH'
             ) THEN 'RC9'
        WHEN CE.CINE_CLOSE_DATE IS NULL THEN ''
        ELSE 'RC7'
    END AS cine_close_reason,
    CE.CINE_CLOSE_DATE AS cine_close_date,
    NULL AS cine_referral_team,
    CE.SUBMITTERPERSONID AS cine_referral_worker_id
FROM CIN_EPISODE CE
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = CE.PERSONID
);