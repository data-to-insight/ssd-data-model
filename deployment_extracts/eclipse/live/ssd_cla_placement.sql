

/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_placement;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_placement (
    clap_cla_placement_id            VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAP001A"}
    clap_cla_id                      VARCHAR(48),               -- metadata={"item_ref":"CLAP012A"}
    clap_person_id                   VARCHAR(48),               -- metadata={"item_ref":"CLAP013A"}
    clap_cla_placement_start_date    TIMESTAMP,                 -- metadata={"item_ref":"CLAP003A"}
    clap_cla_placement_type          VARCHAR(100),              -- metadata={"item_ref":"CLAP004A"}
    clap_cla_placement_urn           VARCHAR(48),               -- metadata={"item_ref":"CLAP005A"}
    clap_cla_placement_distance      DOUBLE PRECISION,          -- metadata={"item_ref":"CLAP011A"}
    clap_cla_placement_provider      VARCHAR(48),               -- metadata={"item_ref":"CLAP007A"}
    clap_cla_placement_postcode      VARCHAR(8),                -- metadata={"item_ref":"CLAP008A"}
    clap_cla_placement_end_date      TIMESTAMP,                 -- metadata={"item_ref":"CLAP009A"}
    clap_cla_placement_change_reason VARCHAR(100)               -- metadata={"item_ref":"CLAP010A"}
);

TRUNCATE TABLE ssd_cla_placement;

INSERT INTO ssd_cla_placement (
    clap_cla_placement_id,
    clap_cla_id,
    clap_person_id,
    clap_cla_placement_start_date,
    clap_cla_placement_type,
    clap_cla_placement_urn,
    clap_cla_placement_distance,
    clap_cla_placement_provider,
    clap_cla_placement_postcode,
    clap_cla_placement_end_date,
    clap_cla_placement_change_reason
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

ADDRESS AS (
    SELECT 
        'PER'      AS CARERTYPE,
        PERSONID   AS CARERID,
        UPRN       AS UPRN,
        LATITUDE   AS LATITUDE,
        LONGITUDE  AS LONGITUDE,
        POSTCODE   AS POSTCODE,
        TYPE       AS TYPE,
        STARTDATE::DATE AS STARTDATE,
        ENDDATE::DATE   AS ENDDATE
    FROM ADDRESSPERSONVIEW
    
    UNION ALL
    
    SELECT 
        'ORG'      AS CARERTYPE,
        ORGANISATIONID AS CARERID,
        UPRN,
        LATITUDE,
        LONGITUDE,
        POSTCODE,
        TYPE,
        STARTDATE::DATE AS STARTDATE,
        ENDDATE::DATE   AS ENDDATE
    FROM ADDRESSORGANISATIONVIEW
),

CLA_PLACEMENT_EPISODES AS (
   SELECT DISTINCT 
       CLA_PLACEMENT.PERSONID,
       CLA_PLACEMENT.PERIODOFCAREID,
       CLA_PLACEMENT.PLACEMENTADDRESSID,
       CLA_PLACEMENT.PLACEMENTPOSTCODE,
       CLA_PLACEMENT.PLACEMENTTYPE,
       CLA_PLACEMENT.PLACEMENTPROVISIONCODE,
       CLA_PLACEMENT.CARERTYPE,
       CLA_PLACEMENT.CARERID,
       CLA_PLACEMENT.PLACEMENTTYPE,
       CLA_PLACEMENT.PLACEMENTTYPECODE,
       CLA_PLACEMENT.EOCSTARTDATE,
       CLA_PLACEMENT.EOCENDDATE,
       CLA_PLACEMENT.PLACEMENTCHANGEREASONCODE
   FROM CLAEPISODEOFCAREVIEW CLA_PLACEMENT 
   WHERE CLA_PLACEMENT.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
),

CLA_PLACEMENT AS (
    SELECT 
        PERSONID,
        PERIODOFCAREID,
        PLACEMENTADDRESSID,
        PLACEMENTPOSTCODE,
        PLACEMENTTYPECODE,
        PLACEMENTPROVISIONCODE,
        CARERTYPE,
        CARERID,
        MIN(EOCSTARTDATE)::DATE AS EOCSTARTDATE,
        CASE 
            WHEN BOOL_AND(EOCENDDATE IS NOT NULL) IS FALSE
            THEN NULL
            ELSE MAX(EOCENDDATE)::DATE
        END AS EOCENDDATE 
    FROM (    
        SELECT 
            *,
            SUM(START_FLAG) OVER (
                PARTITION BY PERSONID, CARERID 
                ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
            ) AS GRP
        FROM (    
            SELECT DISTINCT 
                PERSONID,
                PERIODOFCAREID,
                PLACEMENTADDRESSID,
                PLACEMENTPOSTCODE,
                PLACEMENTTYPECODE,
                PLACEMENTPROVISIONCODE,
                CARERTYPE,
                CARERID,
                EOCSTARTDATE,
                EOCENDDATE,
                CASE
                    WHEN LAG(CLA_PLACEMENT.EOCENDDATE) OVER (
                             PARTITION BY PERSONID, PERIODOFCAREID, CARERID, PLACEMENTADDRESSID
                             ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
                         ) >= EOCSTARTDATE - INTERVAL '1 day'
                         OR 
                         EOCSTARTDATE BETWEEN
                             LAG(EOCSTARTDATE) OVER (
                                 PARTITION BY PERSONID, PERIODOFCAREID, CARERID, PLACEMENTADDRESSID
                                 ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
                             )
                             AND LAG(COALESCE(EOCENDDATE, CURRENT_DATE)) OVER (
                                 PARTITION BY PERSONID, PERIODOFCAREID, CARERID, PLACEMENTADDRESSID
                                 ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST
                             )
                    THEN 0
                    ELSE 1
                END AS START_FLAG
            FROM CLA_PLACEMENT_EPISODES CLA_PLACEMENT
            ORDER BY PERSONID, EOCENDDATE DESC NULLS FIRST, EOCSTARTDATE DESC
        ) CLA_PLACEMENT
    ) CLA_PLACEMENT
    GROUP BY 
        PERSONID,
        PERIODOFCAREID,
        PLACEMENTADDRESSID,
        PLACEMENTPOSTCODE,
        PLACEMENTTYPECODE,
        PLACEMENTPROVISIONCODE,
        CARERTYPE,
        CARERID,
        GRP
)

SELECT DISTINCT 
    CLA_PLACEMENT.PLACEMENTADDRESSID AS "clap_cla_placement_id",      -- metadata={"item_ref":"CLAP001A"}
    CLA_PLACEMENT.PERIODOFCAREID     AS "clap_cla_id",                -- metadata={"item_ref":"CLAP012A"}
    CLA_PLACEMENT.PERSONID           AS "clap_person_id",             -- metadata={"item_ref":"CLAP013A"}
    CLA_PLACEMENT.EOCSTARTDATE       AS "clap_cla_placement_start_date", -- metadata={"item_ref":"CLAP003A"}
    CASE 
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'APP_ADOPT'        THEN 'A3'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'CONS_ADOPT_NOTFP' THEN 'A4'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'ORD_ADOPT_FP'     THEN 'A5'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'ORD_ADOPT_NOTFP'  THEN 'A6'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_H4'            THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F3'            THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F6'            THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F2'            THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F5'            THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F1_01'         THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PT_F4_02'         THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'SCT_FRIEND_REL'   THEN 'DQ'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'NO_CHREGS'        THEN 'H5'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'CHLD_HOME'        THEN 'K2'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'PARENT'           THEN 'P1'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'IND_LIV'          THEN 'P2'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'RES_CARE'         THEN 'R1'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'NHS'              THEN 'R2'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'YOI'              THEN 'R5'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'RES_SCH'          THEN 'S1'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'REL'              THEN 'U1'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'REL_NOT_LT_ADOPT' THEN 'U3'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'LT'               THEN 'U4'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'NOT_LT_ADOPT'     THEN 'U6'
        WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'OTH'              THEN 'Z1'
    END AS "clap_cla_placement_type",                                 -- metadata={"item_ref":"CLAP004A"}
    ADDRESS.UPRN AS "clap_cla_placement_urn",                         -- metadata={"item_ref":"CLAP005A"}
    ROUND(
        (EARTH_DISTANCE(
            LL_TO_EARTH(ADDRESS.LATITUDE, ADDRESS.LONGITUDE),
            LL_TO_EARTH(HOME_ADDRESS.LATITUDE, HOME_ADDRESS.LONGITUDE)
        ) / 1609.344)::NUMERIC,
        2
    ) AS "clap_cla_placement_distance",                               -- metadata={"item_ref":"CLAP011A"}
    CLA_PLACEMENT.PLACEMENTPROVISIONCODE AS "clap_cla_placement_provider", -- metadata={"item_ref":"CLAP007A"}
    ADDRESS.POSTCODE AS "clap_cla_placement_postcode",                -- metadata={"item_ref":"CLAP008A"}
    CLA_PLACEMENT.EOCENDDATE AS "clap_cla_placement_end_date",        -- metadata={"item_ref":"CLAP009A"}
    CLA_PLACEMENT_END.PLACEMENTCHANGEREASONCODE AS "clap_cla_placement_change_reason" -- metadata={"item_ref":"CLAP010A"}
FROM CLA_PLACEMENT	
LEFT JOIN ADDRESS 
    ON CLA_PLACEMENT.CARERID   = ADDRESS.CARERID 
   AND CLA_PLACEMENT.CARERTYPE = ADDRESS.CARERTYPE
   AND CLA_PLACEMENT.PLACEMENTPOSTCODE = ADDRESS.POSTCODE
   AND CLA_PLACEMENT.EOCSTARTDATE >= ADDRESS.STARTDATE 
   AND COALESCE(CLA_PLACEMENT.EOCSTARTDATE, CURRENT_DATE) <= COALESCE(ADDRESS.ENDDATE, CURRENT_DATE)
   AND COALESCE(CLA_PLACEMENT.EOCENDDATE, CURRENT_DATE) <= COALESCE(ADDRESS.ENDDATE, CURRENT_DATE) + INTERVAL '1 day' 
   AND COALESCE(CLA_PLACEMENT.EOCENDDATE, CURRENT_DATE) >= ADDRESS.STARTDATE
LEFT JOIN ADDRESS HOME_ADDRESS 
    ON CLA_PLACEMENT.PERSONID = HOME_ADDRESS.CARERID 
   AND HOME_ADDRESS.TYPE = 'Home'
   AND CLA_PLACEMENT.EOCSTARTDATE >= HOME_ADDRESS.STARTDATE - INTERVAL '1 day' 
   AND COALESCE(CLA_PLACEMENT.EOCSTARTDATE, CURRENT_DATE) <= COALESCE(HOME_ADDRESS.ENDDATE, CURRENT_DATE)
   AND COALESCE(CLA_PLACEMENT.EOCENDDATE, CURRENT_DATE) <= COALESCE(HOME_ADDRESS.ENDDATE, CURRENT_DATE) + INTERVAL '1 day' 
   AND COALESCE(CLA_PLACEMENT.EOCENDDATE, CURRENT_DATE) >= HOME_ADDRESS.STARTDATE
LEFT JOIN LATERAL (
    SELECT *
    FROM CLA_PLACEMENT_EPISODES CLAP
    WHERE CLA_PLACEMENT.PERSONID = CLAP.PERSONID
      AND CLA_PLACEMENT.EOCENDDATE >= CLAP.EOCENDDATE
    ORDER BY CLAP.EOCENDDATE DESC 
    FETCH FIRST 1 ROW ONLY
) CLA_PLACEMENT_END ON TRUE;
