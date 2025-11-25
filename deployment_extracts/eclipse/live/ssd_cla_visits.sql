/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_visits;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_visits (
    clav_cla_visit_id          VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAV001A"}
    clav_cla_id                VARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
    clav_person_id             VARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
    clav_cla_visit_date        TIMESTAMP,                 -- metadata={"item_ref":"CLAV003A"}
    clav_cla_visit_seen        CHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
    clav_cla_visit_seen_alone  CHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
);

TRUNCATE TABLE ssd_cla_visits;

INSERT INTO ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
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
FAPV_CTE AS (
    SELECT
        FAPV.INSTANCEID            AS instance_id,
        FAPV.ANSWERFORSUBJECTID    AS person_id,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
                THEN FAPV.DATEANSWERVALUE
            END)::DATE             AS visit_date,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
                THEN CASE
                         WHEN FAPV.ANSWERVALUE = 'Yes'
                             THEN 'Y'
                         ELSE 'N'
                     END
            END)                   AS child_seen,
        MAX(CASE
                WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
                THEN CASE
                         WHEN FAPV.ANSWERVALUE = 'Child seen alone'
                             THEN 'Y'
                         ELSE 'N'
                     END
            END)                   AS child_seen_alone
    FROM FORMANSWERPERSONVIEW FAPV -- [REVIEW] GUID must match (LA to review/update)
    WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') -- Child: Visit
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.DESIGNSUBNAME = 'Child in care'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
)
SELECT DISTINCT
    FAPV.instance_id           AS clav_cla_visit_id,        -- metadata={"item_ref":"CLAV001A"}
    CLA.PERIODOFCAREID         AS clav_cla_id,              -- metadata={"item_ref":"CLAV007A"}
    FAPV.person_id             AS clav_person_id,           -- metadata={"item_ref":"CLAV008A"}
    FAPV.visit_date            AS clav_cla_visit_date,      -- metadata={"item_ref":"CLAV003A"}
    FAPV.child_seen            AS clav_cla_visit_seen,      -- metadata={"item_ref":"CLAV004A"}
    FAPV.child_seen_alone      AS clav_cla_visit_seen_alone -- metadata={"item_ref":"CLAV005A"}
FROM FAPV_CTE FAPV
LEFT JOIN CLAPERIODOFCAREVIEW CLA
    ON CLA.PERSONID = FAPV.person_id
   AND FAPV.visit_date >= CLA.ADMISSIONDATE
   AND FAPV.visit_date <= COALESCE(CLA.DISCHARGEDATE, CURRENT_DATE);
