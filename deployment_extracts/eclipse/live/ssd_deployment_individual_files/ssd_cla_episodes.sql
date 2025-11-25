

-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cla_episodes;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cla_episodes (
    clae_cla_episode_id             VARCHAR(48)  PRIMARY KEY,
    clae_person_id                  VARCHAR(48),
    clae_cla_placement_id           VARCHAR(48),
    clae_cla_episode_start_date     TIMESTAMP,
    clae_cla_episode_start_reason   VARCHAR(100),
    clae_cla_primary_need_code      VARCHAR(3),
    clae_cla_episode_ceased_date    TIMESTAMP,
    clae_cla_episode_ceased_reason  VARCHAR(255),
    clae_cla_id                     VARCHAR(48),
    clae_referral_id                VARCHAR(48),
    clae_cla_last_iro_contact_date  TIMESTAMP,
    clae_entered_care_date          TIMESTAMP
);

TRUNCATE TABLE ssd_cla_episodes;

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

WITH EXCLUSIONS AS (
	SELECT
		PV.PERSONID
	FROM PERSONVIEW PV
	WHERE PV.PERSONID IN ( -- hard filter admin/test/duplicate records on system
			1,2,3,4,5,6
		)
		OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
		OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
		OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
), 

REFERRAL AS (
    SELECT 
        *,
        CASE 
            WHEN CLA.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
            WHEN CLA.PRIMARY_NEED_CAT = 'Child''s disability'             THEN 'N2'
            WHEN CLA.PRIMARY_NEED_CAT = 'Parental illness/disability'     THEN 'N3'
            WHEN CLA.PRIMARY_NEED_CAT = 'Family in acute stress'          THEN 'N4'
            WHEN CLA.PRIMARY_NEED_CAT = 'Family dysfunction'              THEN 'N5'
            WHEN CLA.PRIMARY_NEED_CAT = 'Socially unacceptable behaviour' THEN 'N6'
            WHEN CLA.PRIMARY_NEED_CAT = 'Low income'                      THEN 'N7'
            WHEN CLA.PRIMARY_NEED_CAT = 'Absent parenting'                THEN 'N8'
            WHEN CLA.PRIMARY_NEED_CAT = 'Cases other than child in need'  THEN 'N9'
            WHEN CLA.PRIMARY_NEED_CAT = 'Not stated'                      THEN 'N0'
        END AS PRIMARY_NEED_RANK
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID                                       AS PERSONID,
            FAPV.INSTANCEID                                               AS ASSESSMENTID,
            FAPV.SUBMITTERPERSONID                                        AS SUBMITTERPERSONID,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'
                    THEN FAPV.ANSWERVALUE
                END
            )                                                             AS REFERRAL_SOURCE,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
                    THEN FAPV.ANSWERVALUE
                END
            )                                                             AS NEXT_STEP,  
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
                    THEN FAPV.ANSWERVALUE
                END
            )                                                             AS PRIMARY_NEED_CAT,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'
                    THEN FAPV.DATEANSWERVALUE
                END
            )                                                             AS DATE_OF_REFERRAL    
        FROM FORMANSWERPERSONVIEW FAPV -- [REVIEW] GUID must match (LA to review/update)
        WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f') --Child: Referral
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY 
            FAPV.ANSWERFORSUBJECTID,
            FAPV.INSTANCEID,
            FAPV.SUBMITTERPERSONID
    ) CLA      
),

IRO_MEETING AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID AS PERSONID,
        FAPV.INSTANCEID         AS ASSESSMENTID,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
                THEN FAPV.DATEANSWERVALUE
            END
        )                       AS DATE_OF_MEETING    
    FROM FORMANSWERPERSONVIEW FAPV -- [REVIEW] GUID must match (LA to review/update)
    WHERE FAPV.DESIGNGUID IN ('2d9d174f-77ed-40bd-ac2b-cae8015ad799') --Child: IRO Review Record
      AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY 
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
)

SELECT
    CLA_EPISODE.EPISODEOFCAREID                                         AS "clae_cla_episode_id",         -- metadata={"item_ref":"CLAE001A"}
    CLA_EPISODE.PERSONID                                                AS "clae_person_id",              -- metadata={"item_ref":"CLAE002A"}
    CLA_EPISODE.EOCSTARTDATE                                            AS "clae_cla_episode_start_date", -- metadata={"item_ref":"CLAE003A"}
    CLA_EPISODE.EOCSTARTREASONCODE                                      AS "clae_cla_episode_start_reason", -- metadata={"item_ref":"CLAE004A"}
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
    END                                                                   AS "clae_cla_primary_need_code",       -- metadata={"item_ref":"CLAE009A"}
    CLA_EPISODE.EOCENDDATE                                                AS "clae_cla_episode_ceased_date",     -- metadata={"item_ref":"CLAE005A"}
    CLA_EPISODE.EOCENDREASONCODE                                          AS "clae_cla_episode_ceased_reason",   -- metadata={"item_ref":"CLAE006A"}
    CLA_EPISODE.PERIODOFCAREID                                            AS "clae_cla_id",                       -- metadata={"item_ref":"CLAE010A"}
    REFR.ASSESSMENTID                                                     AS "clae_referral_id",                  -- metadata={"item_ref":"CLAE011A"}
    CLA_EPISODE.PLACEMENTADDRESSID                                        AS "clae_cla_placement_id",             -- metadata={"item_ref":"CLAE013A"}    
    CLA.ADMISSIONDATE                                                     AS "clae_entered_care_date",            -- metadata={"item_ref":"CLAE014A"} 
    IRO_MEETING.DATE_OF_MEETING                                           AS "clae_cla_last_iro_contact_date"     -- metadata={"item_ref":"CLAE012A"}
FROM CLAEPISODEOFCAREVIEW CLA_EPISODE	
LEFT JOIN LATERAL (  
    SELECT *  
    FROM REFERRAL REFR
    WHERE CLA_EPISODE.PERSONID = REFR.PERSONID
      AND CLA_EPISODE.EOCSTARTDATE >= REFR.DATE_OF_REFERRAL
    ORDER BY REFR.DATE_OF_REFERRAL DESC
    FETCH FIRST 1 ROW ONLY
) REFR ON TRUE
LEFT JOIN CLAPERIODOFCAREVIEW CLA 
       ON CLA.PERSONID = CLA_EPISODE.PERSONID 
      AND CLA.PERIODOFCAREID = CLA_EPISODE.PERIODOFCAREID  
LEFT JOIN LATERAL (
    SELECT 
        *
    FROM IRO_MEETING    
    WHERE CLA_EPISODE.PERSONID = IRO_MEETING.PERSONID
      AND IRO_MEETING.DATE_OF_MEETING >= CLA.ADMISSIONDATE 
      AND IRO_MEETING.DATE_OF_MEETING <= COALESCE(CLA.DISCHARGEDATE, CURRENT_DATE)
    ORDER BY IRO_MEETING.DATE_OF_MEETING DESC 
    FETCH FIRST 1 ROW ONLY
) IRO_MEETING ON TRUE
WHERE CLA_EPISODE.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E);
