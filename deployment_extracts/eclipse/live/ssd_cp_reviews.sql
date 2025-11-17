
-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cp_reviews;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cp_reviews
(
    cppr_cp_review_id                  VARCHAR(48)  PRIMARY KEY, -- metadata={"item_ref":"CPPR001A"}
    cppr_person_id                     VARCHAR(48),              -- metadata={"item_ref":"CPPR008A"}
    cppr_cp_plan_id                    VARCHAR(48),              -- metadata={"item_ref":"CPPR002A"}  
    cppr_cp_review_due                 TIMESTAMP NULL,           -- metadata={"item_ref":"CPPR003A"}
    cppr_cp_review_date                TIMESTAMP NULL,           -- metadata={"item_ref":"CPPR004A"}
    cppr_cp_review_meeting_id          VARCHAR(48),              -- metadata={"item_ref":"CPPR009A"}      
    cppr_cp_review_outcome_continue_cp CHAR(1),                  -- metadata={"item_ref":"CPPR005A"}
    cppr_cp_review_quorate             VARCHAR(100),             -- metadata={"item_ref":"CPPR006A"}      
    cppr_cp_review_participation       VARCHAR(100)              -- metadata={"item_ref":"CPPR007A"}
);

TRUNCATE TABLE ssd_cp_reviews;

INSERT INTO ssd_cp_reviews (
    cppr_cp_review_id,
    cppr_person_id,
    cppr_cp_plan_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_meeting_id,
    cppr_cp_review_outcome_continue_cp,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
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

CP_PLAN AS (
    SELECT 
        MIN(CLA.CLAID)     AS CLAID,
        CLA.PERSONID,
        MIN(CLA.STARTDATE) AS STARTDATE,
        CASE
            WHEN BOOL_AND(ENDDATE IS NOT NULL) IS FALSE
            THEN NULL
            ELSE MAX(ENDDATE)
        END                 AS ENDDATE
    FROM (	
        SELECT  
            *,
            SUM(NEXT_START_FLAG) OVER (
                PARTITION BY PERSONID 
                ORDER BY PERSONID, STARTDATE ROWS UNBOUNDED PRECEDING
            ) AS EPISODE 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID    AS CLAID, 
                CLA.PERSONID, 
                CLA.STARTDATE::DATE               AS STARTDATE,
                CLA.ENDDATE::DATE                 AS ENDDATE,
                CASE 
                    WHEN CLA.STARTDATE > LAG(CLA.STARTDATE) OVER (
                             PARTITION BY CLA.PERSONID 
                             ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                         )
                     AND CLA.STARTDATE <= COALESCE(
                             LAG(CLA.ENDDATE) OVER (
                                 PARTITION BY CLA.PERSONID 
                                 ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST
                             ),
                             CURRENT_DATE
                         ) 
                    THEN 0
                    ELSE 1
                END                               AS NEXT_START_FLAG     
            FROM CLASSIFICATIONPERSONVIEW CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
              AND CLA.CLASSIFICATIONPATHID IN (51) -- CP classification
              AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
            ORDER BY CLA.PERSONID,
                     CLA.ENDDATE DESC NULLS FIRST,
                     CLA.STARTDATE DESC 
        ) CLA
    ) CLA
    GROUP BY CLA.PERSONID, CLA.EPISODE
), 

CP_REVIEW AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID    AS PERSONID,
        FAPV.INSTANCEID            AS FORMID,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
                THEN FAPV.ANSWERVALUE
            END
        )                          AS NEXT_STEP,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'dateofnextplanmeetingreview_35'
                THEN FAPV.ANSWERVALUE
            END
        )::DATE                    AS NEXT_REVIEW,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
                THEN FAPV.ANSWERVALUE
            END
        )::DATE                    AS DATE_OF_MEETING   
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child Protection - Review Conference'
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID      
),

IRO_REVIEW AS (
    SELECT
        FAPV.ANSWERFORSUBJECTID    AS PERSONID,
        FAPV.INSTANCEID            AS FORMID,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'howwasthechildabletocontributetheirviewstotheconference_4'
                THEN FAPV.SHORTANSWERVALUE
            END
        )                          AS PARTICIPATION,
        MAX(
            CASE
                WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
                THEN FAPV.ANSWERVALUE
            END
        )::DATE                    AS DATE_OF_MEETING       
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('79f3495c-134f-4e69-b00f-7621925419f7') --Independent Reviewing Officer: Quality assurance
      AND FAPV.INSTANCESTATE = 'COMPLETE'
      AND FAPV.DESIGNSUBNAME = 'Child protection conference' 
      AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID
)
SELECT
    IRO_REVIEW.FORMID             AS cppr_cp_review_id,                  -- metadata={"item_ref":"CPPR001A"}
    CP_REVIEW.PERSONID            AS cppr_person_id,                     -- metadata={"item_ref":"CPPR008A"}
    CP_PLAN.CLAID                 AS cppr_cp_plan_id,                    -- metadata={"item_ref":"CPPR002A"}
    PREVIOUSR.NEXT_REVIEW         AS cppr_cp_review_due,                 -- metadata={"item_ref":"CPPR003A"}
    CP_REVIEW.DATE_OF_MEETING     AS cppr_cp_review_date,                -- metadata={"item_ref":"CPPR004A"}
    CP_REVIEW.FORMID              AS cppr_cp_review_meeting_id,          -- metadata={"item_ref":"CPPR009A"}
    CASE 
        WHEN CP_REVIEW.NEXT_STEP = 'Set next review' 
        THEN 'Y'
        ELSE 'N'
    END                           AS cppr_cp_review_outcome_continue_cp, -- metadata={"item_ref":"CPPR005A"}
    'Y'                           AS cppr_cp_review_quorate,             -- metadata={"item_ref":"CPPR006A"}
    IRO_REVIEW.PARTICIPATION      AS cppr_cp_review_participation        -- metadata={"item_ref":"CPPR007A"}
FROM CP_REVIEW
LEFT JOIN LATERAL (
    SELECT
        *
    FROM CP_REVIEW PREVIOUSR
    WHERE PREVIOUSR.PERSONID = CP_REVIEW.PERSONID
      AND PREVIOUSR.DATE_OF_MEETING < CP_REVIEW.DATE_OF_MEETING
    ORDER BY PREVIOUSR.DATE_OF_MEETING DESC
    FETCH FIRST 1 ROW ONLY
) PREVIOUSR ON TRUE 
LEFT JOIN IRO_REVIEW 
       ON IRO_REVIEW.PERSONID = CP_REVIEW.PERSONID 
      AND IRO_REVIEW.DATE_OF_MEETING = CP_REVIEW.DATE_OF_MEETING
LEFT JOIN CP_PLAN 
       ON CP_PLAN.PERSONID = CP_REVIEW.PERSONID 
      AND CP_REVIEW.DATE_OF_MEETING >= CP_PLAN.STARTDATE 
      AND CP_REVIEW.DATE_OF_MEETING <  CP_PLAN.ENDDATE;
