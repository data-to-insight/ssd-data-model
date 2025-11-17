
-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_initial_cp_conference;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE IF NOT EXISTS ssd_initial_cp_conference (
    icpc_icpc_id              VARCHAR(48) PRIMARY KEY, -- metadata={"item_ref":"ICPC001A"}
    icpc_icpc_meeting_id      VARCHAR(48),             -- metadata={"item_ref":"ICPC009A"}
    icpc_s47_enquiry_id       VARCHAR(48),             -- metadata={"item_ref":"ICPC002A"}
    icpc_person_id            VARCHAR(48),             -- metadata={"item_ref":"ICPC010A"}
    icpc_cp_plan_id           VARCHAR(48),             -- metadata={"item_ref":"ICPC011A"}
    icpc_referral_id          VARCHAR(48),             -- metadata={"item_ref":"ICPC012A"}
    icpc_icpc_transfer_in     CHAR(1),                 -- metadata={"item_ref":"ICPC003A"}
    icpc_icpc_target_date     TIMESTAMP,               -- metadata={"item_ref":"ICPC004A"}
    icpc_icpc_date            TIMESTAMP,               -- metadata={"item_ref":"ICPC005A"}
    icpc_icpc_outcome_cp_flag CHAR(1),                 -- metadata={"item_ref":"ICPC013A"}
    icpc_icpc_outcome_json    VARCHAR(1000),           -- metadata={"item_ref":"ICPC006A"}
    icpc_icpc_team            VARCHAR(48),             -- metadata={"item_ref":"ICPC007A"}
    icpc_icpc_worker_id       VARCHAR(100)             -- metadata={"item_ref":"ICPC008A"}
);

TRUNCATE TABLE ssd_initial_cp_conference;

INSERT INTO ssd_initial_cp_conference (
    icpc_icpc_id,
    icpc_icpc_meeting_id,
    icpc_s47_enquiry_id,
    icpc_person_id,
    icpc_cp_plan_id,
    icpc_referral_id,
    icpc_icpc_transfer_in,
    icpc_icpc_target_date,
    icpc_icpc_date,
    icpc_icpc_outcome_cp_flag,
    icpc_icpc_outcome_json,
    icpc_icpc_team,
    icpc_icpc_worker_id
)
WITH EXCLUSIONS AS (
	SELECT
		PV.PERSONID
	FROM PERSONVIEW PV
	WHERE PV.PERSONID IN (
			1,2,3,4,5,6,99046,100824,100825,100826,100827,100828,100829,100830,100832,100856,100857,100861,100864,9999040,102790,
			100831,100833,100834,100838,100839,100859,100860,99524,99543,99555,99559,99613,99661,99662,99993,100276,100290,100372,109032,100924,
			100941,35698,43088,68635,74902,77731,97447,9999000,9999010,9999025,9999026,9999029,9999050,72306,109032,117746,
			97951 --not flagged as duplicate
		)
		OR COALESCE(PV.DUPLICATED,'?') IN ('DUPLICATE')
		OR UPPER(PV.FORENAME) LIKE '%DUPLICATE%'
		OR UPPER(PV.SURNAME) LIKE '%DUPLICATE%'
),

CALENDAR AS (
    SELECT 
        GENERATE_SERIES::DATE AS "DATE",
        EXTRACT(DOW FROM GENERATE_SERIES) AS "DAY"
    FROM GENERATE_SERIES(
        '2016-01-01',
        CURRENT_TIMESTAMP::DATE,
        INTERVAL '1 DAY'
    )
),

WORKING_DAY_CALENDAR AS (
    SELECT DISTINCT
        C.*,
        ROW_NUMBER() OVER (ORDER BY C."DATE" ASC) AS rn
    FROM CALENDAR C
    --Take out bank holidays and weekends
    WHERE "DATE" NOT IN (
        '2016-01-01','2016-03-25','2016-03-28','2016-05-02','2016-05-30','2016-08-29','2016-12-26','2016-12-27',
        '2017-01-02','2017-04-14','2017-04-17','2017-05-01','2017-05-29','2017-08-28','2017-12-25','2017-12-26',
        '2018-01-01','2018-03-30','2018-04-02','2018-05-07','2018-05-28','2018-08-27','2018-12-25','2018-12-26',
        '2019-01-01','2019-04-19','2019-04-22','2019-05-06','2019-05-27','2019-08-26','2019-12-25','2019-12-26',
        '2020-01-01','2020-04-10','2020-04-13','2020-05-04','2020-05-25','2020-08-31','2020-12-25','2020-12-28',
        '2020-12-29','2020-12-30','2020-12-31',
        '2021-01-01','2021-04-02','2021-04-05','2021-05-03','2021-05-31','2021-08-30','2021-12-27','2021-12-28',
        '2021-12-29','2021-12-30','2021-12-31',
        '2022-01-03','2022-04-15','2022-04-18','2022-05-02','2022-06-02','2022-06-03','2022-08-29','2022-12-26',
        '2022-12-27','2022-12-28','2022-12-29','2022-12-30',
        '2023-01-02','2023-04-07','2023-04-10','2023-05-01','2023-05-08','2023-05-29','2023-08-28','2023-12-25',
        '2023-12-26','2023-12-27','2023-12-28','2023-12-29',
        '2024-01-01','2024-03-29','2024-04-01','2024-05-06','2024-05-27','2024-08-26','2024-12-25','2024-12-26',
        '2024-12-27','2024-12-30','2024-12-31',
        '2025-01-01','2025-04-18','2025-04-21','2025-05-05','2025-05-26','2025-08-25','2025-12-25','2025-12-26'
    )
      AND "DAY" NOT IN (6, 0)
),

WORKING_DAY_RANKS AS (
    SELECT 
        GENERATE_SERIES::DATE AS "DATE",
        EXTRACT(DOW FROM GENERATE_SERIES) AS "DAY",
        COALESCE(
            (
                SELECT MAX(WDC.rn)
                FROM WORKING_DAY_CALENDAR WDC
                WHERE WDC."DATE" <= GENERATE_SERIES
            ),
            0
        ) AS rank
    FROM GENERATE_SERIES(
        '2016-01-01',
        CURRENT_TIMESTAMP::DATE,
        INTERVAL '1 DAY'
    )
),

INITIAL_ASESSMENT AS (
    SELECT 
        *
    FROM (
        SELECT DISTINCT  
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID  AS personid,
            FAPV.DATECOMPLETED::DATE AS completiondate,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                        THEN FAPV.ANSWERVALUE
                END
            )::DATE                  AS date_of_meeting,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'AnnexAReturn_typeOfMeeting'
                        THEN FAPV.ANSWERVALUE
                END
            )                        AS meeting_type,
            MAX(
                CASE
                    WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
                        THEN FAPV.ANSWERVALUE
                END
            )                        AS next_step
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
          AND FAPV.INSTANCESTATE = 'COMPLETE'
          AND FAPV.DESIGNSUBNAME = 'Child Protection - Initial Conference'
          AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
        GROUP BY 
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID,
            FAPV.DATECOMPLETED 
    ) FAPV
    WHERE meeting_type IN (
        'Child Protection (Initial child protection conference)',
        'Child Protection (Transfer in conference)'
    )
),

ASESSMENT47 AS (
    SELECT
        *
    FROM (    
        SELECT
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID  AS personid,
            MAX(
                CASE 
                    WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
                        THEN FAPV.DATEANSWERVALUE
                END
            )                        AS startdate,
            FAPV.DATECOMPLETED::DATE AS completiondate,
            MAX(
                CASE 
                    WHEN FAPV.CONTROLNAME IN (
                        'CINCensus_unsubWhatNeedsToHappenNext',
                        'CINCensus_whatNeedsToHappenNext'
                    )
                        THEN FAPV.ANSWERVALUE
                END
            )                        AS outcome
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY 
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID,
            FAPV.DATECOMPLETED
    ) FAPV
    WHERE FAPV.outcome = 'Convene initial child protection conference'
),  

STRATEGY_DISC AS (
    SELECT 
        *,
        tarr."DATE" AS target_date
    FROM (    
        SELECT 
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID AS personid,
            MAX(
                CASE 
                    WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
                        THEN FAPV.DATEANSWERVALUE
                END
            ) AS meeting_date
        FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('f9a86a19-ea09-41f0-9403-a88e2b0e738a') --Child Protection: Strategy discussion
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY 
            FAPV.INSTANCEID,
            FAPV.ANSWERFORSUBJECTID,
            FAPV.DATECOMPLETED
    ) FAPV	
    LEFT JOIN WORKING_DAY_RANKS sdr 
        ON sdr."DATE" = FAPV.meeting_date 
    LEFT JOIN WORKING_DAY_RANKS tarr 
        ON tarr.rank = sdr.rank + 15
),

CIN_EPISODE AS (  ----------CIN Episodes
    SELECT 
        cine_person_id,
        cine_referral_date,
        cine_close_date,
        MAX(cine_close_reason) AS cine_close_reason,
        MIN(cine_referral_id)  AS cine_referral_id
    FROM (    
        SELECT 
            CLA.PERSONID           AS cine_person_id,
            MIN(CLA.primary_code_startdate) AS cine_referral_date,
            CASE
                WHEN BOOL_AND(primary_code_enddate IS NOT NULL) IS FALSE
                    THEN NULL
                ELSE MAX(primary_code_enddate)
            END                    AS cine_close_date,
            MAX(endreason)         AS cine_close_reason,
            MAX(episode_id)        AS cine_referral_id
        FROM (
            SELECT  
                *,
                SUM(next_start_flag) OVER (
                    PARTITION BY personid 
                    ORDER BY personid, primary_code_startdate
                ) AS episode,
                CASE 
                    WHEN next_start_flag = 1
                        THEN episodeid
                END                AS episode_id     
            FROM (
                SELECT 
                    CLA.PERSONID                   AS personid, 
                    CLA.CLASSIFICATIONASSIGNMENTID AS episodeid,
                    CLA.STARTDATE::DATE            AS primary_code_startdate,
                    CLA.ENDDATE::DATE              AS primary_code_enddate,
                    CLA.ENDREASON                  AS endreason,
                    CASE 
                        WHEN CLA.STARTDATE >= LAG(CLA.STARTDATE) OVER (
                                 PARTITION BY CLA.PERSONID 
                                 ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                             )
                         AND CLA.STARTDATE <= COALESCE(
                                 LAG(CLA.ENDDATE) OVER (
                                     PARTITION BY CLA.PERSONID 
                                     ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                                 ),
                                 CURRENT_DATE
                             ) + INTERVAL '1 day' 
                            THEN 0
                        ELSE 1
                    END            AS next_start_flag     
                FROM CLASSIFICATIONPERSONVIEW CLA
                WHERE CLA.STATUS NOT IN ('DELETED')
                  AND CLA.CLASSIFICATIONPATHID IN (23, 10)
                ORDER BY CLA.PERSONID,
                         CLA.ENDDATE::DATE DESC NULLS FIRST,
                         CLA.STARTDATE::DATE DESC 
            ) CLA
        ) CLA
        GROUP BY personid, episode 
    ) CLA
    GROUP BY  
        cine_person_id,
        cine_referral_date,
        cine_close_date 
),

CP_PLAN AS (
    SELECT
        cp_plan.CLASSIFICATIONASSIGNMENTID AS planid,
        cp_plan.PERSONID                   AS personid,
        cp_plan.STARTDATE::DATE            AS plan_start_date,
        cp_plan.ENDDATE::DATE              AS plan_end_date,
        cin_episode.cine_referral_id
    FROM CLASSIFICATIONPERSONVIEW cp_plan
    LEFT JOIN LATERAL (
        SELECT 
            *
        FROM CIN_EPISODE
        WHERE CIN_EPISODE.cine_person_id = cp_plan.PERSONID
          AND CIN_EPISODE.cine_referral_date <= cp_plan.STARTDATE::DATE
        ORDER BY CIN_EPISODE.cine_referral_date DESC
        FETCH FIRST 1 ROW ONLY
    ) cin_episode ON TRUE 
    WHERE cp_plan.CLASSIFICATIONPATHID = 51 
      AND cp_plan.STATUS NOT IN ('DELETED')
      AND cp_plan.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
),

WORKER AS (    -------Responsible social worker 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS id,
        PPR.PERSONID                         AS personid,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS allocated_worker,
        PPR.STARTDATE                        AS worker_start_date,
        PPR.CLOSEDATE                        AS worker_end_date
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW' 
),

TEAM AS (    -------Responsible team
    SELECT 
        PPR.RELATIONSHIPID   AS id,
        PPR.PERSONID         AS personid,
        PPR.ORGANISATIONID   AS allocated_team,
        PPR.DATESTARTED      AS team_start_date,
        PPR.DATEENDED        AS team_end_date
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT' 
)

SELECT
    CONCAT(initial_asessment.INSTANCEID, initial_asessment.personid) AS icpc_icpc_id,          --metadata={"item_ref:"ICPC001A"}
    initial_asessment.INSTANCEID                                     AS icpc_icpc_meeting_id,  --metadata={"item_ref:"ICPC009A"}
    asessment47.INSTANCEID                                           AS icpc_s47_enquiry_id,   --metadata={"item_ref:"ICPC002A"}
    initial_asessment.personid                                       AS icpc_person_id,        --metadata={"item_ref:"ICPC010A"}
    cp_plan.planid                                                   AS icpc_cp_plan_id,       --metadata={"item_ref:"ICPC011A"}
    cp_plan.cine_referral_id                                         AS icpc_referral_id,      --metadata={"item_ref:"ICPC012A"}
    CASE 
        WHEN initial_asessment.meeting_type = 'Child Protection (Transfer in conference)'
            THEN 'Y'
        ELSE 'N'
    END                                                              AS icpc_icpc_transfer_in, --metadata={"item_ref:"ICPC003A"}
    strategy_disc.target_date                                        AS icpc_icpc_target_date, --metadata={"item_ref:"ICPC004A"}
    initial_asessment.date_of_meeting                                AS icpc_icpc_date,        --metadata={"item_ref:"ICPC005A"}
    CASE 
        WHEN initial_asessment.next_step = 'Set next review'
            THEN 'Y'
        ELSE 'N'
    END                                                              AS icpc_icpc_outcome_cp_flag, --metadata={"item_ref:"ICPC013A"}
    JSON_BUILD_OBJECT( 
        'OUTCOME_NFA_FLAG',
            CASE 
                WHEN initial_asessment.next_step = 'Case closure'
                     OR initial_asessment.next_step IS NULL
                    THEN 'Y'
                ELSE 'N'
            END,
        'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', '',
        'OUTCOME_SINGLE_ASSESSMENT_FLAG',        '',
        'OUTCOME_PROV_OF_SERVICES_FLAG',         '', 
        'OUTCOME_CP_FLAG',
            CASE 
                WHEN initial_asessment.next_step = 'Set next review'
                    THEN 'Y'
                ELSE 'N'
            END,
        'OTHER_OUTCOMES_EXIST_FLAG',
            CASE 
                WHEN initial_asessment.next_step = 'CIN'
                    THEN 'Y'
                ELSE 'N'
            END,
        'TOTAL_NO_OF_OUTCOMES', '',
        'OUTCOME_COMMENTS',     ''
    )                                                              AS icpc_icpc_outcome_json, --metadata={"item_ref:"ICPC006A"}
    TEAM.allocated_team                                            AS icpc_icpc_team,        --metadata={"item_ref:"ICPC007A"}
    WORKER.allocated_worker                                        AS icpc_icpc_worker_id    --metadata={"item_ref:"ICPC008A"}
FROM INITIAL_ASESSMENT initial_asessment
LEFT JOIN LATERAL (
    SELECT
        *
    FROM ASESSMENT47
    WHERE ASESSMENT47.personid = initial_asessment.personid
      AND ASESSMENT47.startdate <= initial_asessment.date_of_meeting
    ORDER BY ASESSMENT47.startdate DESC
    FETCH FIRST 1 ROW ONLY
) asessment47 ON TRUE
LEFT JOIN LATERAL (
    SELECT
        *
    FROM STRATEGY_DISC
    WHERE STRATEGY_DISC.personid = initial_asessment.personid
      AND STRATEGY_DISC.meeting_date <= initial_asessment.date_of_meeting
    ORDER BY STRATEGY_DISC.meeting_date DESC
    FETCH FIRST 1 ROW ONLY
) strategy_disc ON TRUE             
LEFT JOIN LATERAL (
    SELECT
        *
    FROM CP_PLAN
    WHERE CP_PLAN.personid = initial_asessment.personid
      AND initial_asessment.date_of_meeting <= CP_PLAN.plan_start_date
    ORDER BY CP_PLAN.plan_start_date
    FETCH FIRST 1 ROW ONLY
) cp_plan ON TRUE  
LEFT JOIN WORKER 
       ON WORKER.personid = initial_asessment.personid 
      AND initial_asessment.date_of_meeting >= WORKER.worker_start_date
      AND initial_asessment.date_of_meeting < COALESCE(WORKER.worker_end_date, CURRENT_DATE)  
LEFT JOIN TEAM 
       ON TEAM.personid = initial_asessment.personid  
      AND initial_asessment.date_of_meeting >= TEAM.team_start_date
      AND initial_asessment.date_of_meeting < COALESCE(TEAM.team_end_date, CURRENT_DATE)  
LEFT JOIN WORKING_DAY_RANKS sdr 
       ON sdr."DATE" = strategy_disc.meeting_date                         
LEFT JOIN WORKING_DAY_RANKS iar 
       ON iar."DATE" = initial_asessment.date_of_meeting;
