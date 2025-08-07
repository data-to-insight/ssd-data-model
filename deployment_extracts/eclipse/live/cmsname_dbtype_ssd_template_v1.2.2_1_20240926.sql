
-- META-CONTAINER: {"type": "header", "name": "extract_settings"}
-- META-ELEMENT: {"type": "header"}


/*
*********************************************************************************************************
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

*We strongly recommend that all initial pilot/trials of SSD scripts occur in a development|test environment.*

Script creates labelled persistent(unless set otherwise) tables in your existing|specified database. 

Data tables(with data copied from raw CMS tables) and indexes for the SSD are created, and therefore in some 
cases will need review and support and/or agreement from your IT or Intelligence team. 

The SQL script is non-destructive.
Reset|Clean-up scripts are available on request seperately, these would then be destructive.

Additional notes: 
A version that instead creates _temp|session tables is also available to enable those LA teams restricted to read access 
on the cms db|schema. A _temp script can also be created by performing the following adjustments:
    - Replace all instances of 'ssd_development.' with '#'
    - Set @Run_SSD_As_Temporary_Tables = 0 - This turns off such as FK constraint creation

There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results; similarly some test related 
console outputs remain to aid such as run-time problem solving. These [TESTING] blocks can/will be removed. 
********************************************************************************************************** */

-- META-ELEMENT: {"type": "deployment_system"}
-- deployment, cms and db system info

-- META-ELEMENT: {"type": "deployment_status_note"}
/*
**********************************************************************************************************
Dev Object & Item Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [AR]waitingReview,  -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder

Development notes:
Currently in [REVIEW]
- DfE returns expect dd/mm/YYYY formating on dates, SSD Extract initially maintains DATETIME not DATE.
- Extended default field sizes - Some are exagerated e.g. family_id NVARCHAR(48), to ensure cms/la compatibility
- Caseload counts - should these be restricted to SSD timeframe counts(currently this) or full system counts?
- ITEM level metadata using the format/key labels: 
- metadata={
            "item_ref"      :"AAAA000A", 

            -- and where applicable any of the following: 
            "item_status"   :"[B], [D].." As per the above status list, 
            "expected_data" :[csv list of "strings" or nums]
            "info"          : "short string desc"
            }
**********************************************************************************************************
*/
-- META-ELEMENT: {"type": "config_metadata"}
-- Developers pls leave blank 

-- META-ELEMENT: {"type": "dev_set_up"}
-- e.g. 
-- GO 
-- SET NOCOUNT ON;


-- META-ELEMENT: {"type": "ssd_timeframe"}
-- postgress version
DO $$ 
DECLARE 
    ssd_timeframe_years INT := 6; -- ssd extract time-frame (YRS)
    ssd_sub1_range_years INT := 1;
    CaseloadLastSept30th DATE;
    CaseloadTimeframeStartDate DATE;
BEGIN
    -- CASELOAD count Date (Currently: September 30th)
    CaseloadLastSept30th := CASE 
        WHEN CURRENT_DATE > MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 9, 30)
        THEN MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 9, 30)
        ELSE MAKE_DATE(EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1, 9, 30)
    END;

    -- Start Date for Caseload Timeframe
    CaseloadTimeframeStartDate := CaseloadLastSept30th - INTERVAL '6 years';

    RAISE NOTICE 'CaseloadLastSept30th: %, CaseloadTimeframeStartDate: %', CaseloadLastSept30th, CaseloadTimeframeStartDate;
END $$;


-- META-ELEMENT: {"type": "dbschema"}
-- Postgress example for review
-- Set the schema search path if needed (SSD tables created here)
SET search_path TO 'ssd_development'; -- replace 'ssd_development' with the desired schema name

DO $$ 
DECLARE 
    schema_name VARCHAR(128) := 'ssd_development';  -- set schema name here OR leave empty for default behavior
BEGIN
    RAISE NOTICE 'Schema Name: %', schema_name;
END $$;

-- META-ELEMENT: {"type": "test"}
DO $$ 
DECLARE 
    TableName VARCHAR(128) := 'table_name_placeholder'; -- replace placeholder with the actual table name
BEGIN
    RAISE NOTICE 'Table Name: %', TableName;
END $$;


-- -- META-ELEMENT: {"type": "dbschema"}
-- -- SQL Server variant for review
-- -- Point to DB/TABLE_CATALOG if required (SSD tables created here)
-- USE HDM_Local;                           -- used in logging (and seperate clean-up script(s))
-- DECLARE @schema_name NVARCHAR(128) = N'ssd_development';    -- set your schema name here OR leave empty for default behaviour. Used towards ssd_extract_log

-- -- META-ELEMENT: {"type": "test"}
-- DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder'; -- Note: also/seperately use of @table_name in non-test|live elements of script. 



-- META-END



/* ********************************************************************************************************** */
-- META-CONTAINER: {"type": "settings", "name": "testing"}
/* Towards simplistic TEST run outputs and logging  (to be removed from live v2+) */
-- Devs can ignore this block. 
-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_version_log"}
-- =============================================================================
-- Description: maintain SSD versioning meta data
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: This is a non-core SSD item, populated with the hard-coded data given
--          In most cases this will require only syntax changes for each DB type
--          SSD extract metadata enabling version consistency across LAs. 
-- Dependencies: 
-- - None
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
DROP TABLE IF EXISTS ssd_development.ssd_version_log;
DROP TABLE IF EXISTS temp_table.ssd_version_log; -- Note: PostgreSQL uses specific schema names for temp tables

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_version_log (
    version_number      VARCHAR(10) PRIMARY KEY,          -- version num (e.g., "1.0.0")
    release_date        DATE NOT NULL,                    -- date of version release
    description         VARCHAR(100),                     -- brief description of version
    is_current          BOOLEAN NOT NULL DEFAULT FALSE,   -- flag to indicate if this is the current version
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- timestamp when record was created
    created_by          VARCHAR(10),                      -- which user created the record
    impact_description  VARCHAR(255)                      -- additional notes on the impact of the release
);

-- META-ELEMENT: {"type": "insert_data"}
-- Insert & update for the current version (using MAJOR.MINOR.PATCH)
INSERT INTO ssd_development.ssd_version_log 
    (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.2.2', CURRENT_TIMESTAMP, '#DtoI-1826, META+YML restructure incl. remove opt blocks', TRUE, 'admin', 'feat/bespoke LA extracts');

-- Insert historic versioning log data
INSERT INTO ssd_development.ssd_version_log (version_number, release_date, description, is_current, created_by, impact_description)
VALUES 
    ('1.0.0', '2023-01-01', 'Initial alpha release (Phase 1 end)', FALSE, 'admin', ''),
    ('1.1.1', '2024-06-26', 'Minor updates with revised assessment_factors', FALSE, 'admin', 'Revised JSON Array structure implemented for CiN'),
    ('1.1.2', '2024-06-26', 'ssd_version_log obj added and minor patch fixes', FALSE, 'admin', 'Provide mech for extract ver visibility'),
    ('1.1.3', '2024-06-27', 'Revised filtering on ssd_person', FALSE, 'admin', 'Check IS_CLIENT flag first'),
    ('1.1.4', '2024-07-01', 'ssd_department obj added', FALSE, 'admin', 'Increased separation between professionals and departments enabling history'),
    ('1.1.5', '2024-07-09', 'ssd_person involvements history', FALSE, 'admin', 'Improved consistency on _json fields, clean-up involvements_history_json'),
    ('1.1.6', '2024-07-12', 'FK fixes for #DtoI-1769', FALSE, 'admin', 'non-unique/FK issues addressed: #DtoI-1769, #DtoI-1601'),
    ('1.1.7', '2024-07-15', 'Non-core ssd_person records added', FALSE, 'admin', 'Fix required for #DtoI-1802'),
    ('1.1.8', '2024-07-17', 'admin table creation logging process defined', FALSE, 'admin', ''),
    ('1.1.9', '2024-07-29', 'Applied CAST(person_id) + minor fixes', FALSE, 'admin', 'impacts all tables using where exists'),
    ('1.2.0', '2024-08-13', '#DtoI-1762, #DtoI-1810, improved 0/-1 handling', FALSE, 'admin', 'impacts all _team fields, AAL7 outputs'),
    ('1.2.1', '2024-08-20', '#DtoI-1820, removed destructive pre-clean-up incl .dbo refs', FALSE, 'admin', 'priority patch fix');

-- META-END








/* ********************************************************************************************************** */

/* START SSD main extract */

/* ********************************************************************************************************** */

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
		GENERATE_SERIES::DATE "DATE",
		EXTRACT(DOW FROM GENERATE_SERIES) "DAY"
	FROM GENERATE_SERIES('2016-01-01',
						 CURRENT_TIMESTAMP::DATE,
						 interval '1 DAY')
),

WORKING_DAY_CALENDAR AS (
    SELECT DISTINCT
        C.*,
        ROW_NUMBER() OVER(ORDER BY C."DATE" ASC) RN
    FROM CALENDAR C
    --Take out bank holidays and weekends
    WHERE "DATE" NOT IN (
		'2016-01-01','2016-03-25','2016-03-28','2016-05-02','2016-05-30','2016-08-29','2016-12-26','2016-12-27',
		'2017-01-02','2017-04-14','2017-04-17','2017-05-01','2017-05-29','2017-08-28','2017-12-25','2017-12-26',
		'2018-01-01','2018-03-30','2018-04-02','2018-05-07','2018-05-28','2018-08-27','2018-12-25','2018-12-26',
		'2019-01-01','2019-04-19','2019-04-22','2019-05-06','2019-05-27','2019-08-26','2019-12-25','2019-12-26',
		'2020-01-01','2020-04-10','2020-04-13','2020-05-04','2020-05-25','2020-08-31','2020-12-25','2020-12-28','2020-12-29','2020-12-30','2020-12-31',
		'2021-01-01','2021-04-02','2021-04-05','2021-05-03','2021-05-31','2021-08-30','2021-12-27','2021-12-28','2021-12-29','2021-12-30','2021-12-31',
		'2022-01-03','2022-04-15','2022-04-18','2022-05-02','2022-06-02','2022-06-03','2022-08-29','2022-12-26','2022-12-27','2022-12-28','2022-12-29','2022-12-30',
		'2023-01-02','2023-04-07','2023-04-10','2023-05-01','2023-05-08','2023-05-29','2023-08-28','2023-12-25','2023-12-26','2023-12-27','2023-12-28','2023-12-29',
		'2024-01-01','2024-03-29','2024-04-01','2024-05-06','2024-05-27','2024-08-26','2024-12-25','2024-12-26','2024-12-27','2024-12-30','2024-12-31',
		'2025-01-01','2025-04-18','2025-04-21','2025-05-05','2025-05-26','2025-08-25','2025-12-25','2025-12-26'
	) 
        AND "DAY" NOT IN (6,0)
),

WORKING_DAY_RANKS AS (
	SELECT 
		GENERATE_SERIES::DATE "DATE",
		EXTRACT(DOW FROM GENERATE_SERIES) "DAY",
		COALESCE((SELECT MAX(WDC.RN) FROM WORKING_DAY_CALENDAR WDC WHERE WDC."DATE" <= GENERATE_SERIES),0) RANK
		
	FROM GENERATE_SERIES('2016-01-01',
						 CURRENT_TIMESTAMP::DATE,
						 interval '1 DAY')
),

ALL_CIN_EPISODES AS (
    SELECT 
        *
    FROM (    
	    SELECT 
	        CLA.PERSONID, 
	        CLA.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
		    CLA.STARTDATE::DATE                                                 AS EPISODE_STARTDATE,
	        CLA.ENDDATE::DATE                                                   AS EPISODE_ENDDATE,
	        CLA.ENDREASON
	    FROM CLASSIFICATIONPERSONVIEW  CLA
	    WHERE CLA.STATUS NOT IN ('DELETED')
	     AND (CLA.CLASSIFICATIONPATHID IN (4 , 51) -- CIN & CP classification
	      OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classificaion
	      
	    UNION ALL 
	    
	    SELECT
			CLA_EPISODE.PERSONID,
			CLA_EPISODE.EPISODEOFCAREID,
			CLA_EPISODE.EOCSTARTDATE,
			CLA_EPISODE.EOCENDDATE,
			CLA_EPISODE.EOCENDREASON
		FROM CLAEPISODEOFCAREVIEW CLA_EPISODE
		) CIN
	ORDER BY PERSONID,
	         EPISODE_STARTDATE
	         
),

REFERRAL AS (
    SELECT 
        *,
        CASE WHEN CLA.PRIMARY_NEED_CAT = 'Abuse or neglect'                THEN 'N1'
             WHEN CLA.PRIMARY_NEED_CAT = 'Child''s disability'             THEN 'N2'
             WHEN CLA.PRIMARY_NEED_CAT = 'Parental illness/disability'     THEN 'N3'
             WHEN CLA.PRIMARY_NEED_CAT = 'Family in acute stress'          THEN 'N4'
             WHEN CLA.PRIMARY_NEED_CAT = 'Family dysfunction'              THEN 'N5'
             WHEN CLA.PRIMARY_NEED_CAT = 'Socially unacceptable behaviour' THEN 'N6'
             WHEN CLA.PRIMARY_NEED_CAT = 'Low income'                      THEN 'N7'
             WHEN CLA.PRIMARY_NEED_CAT = 'Absent parenting'                THEN 'N8'
             WHEN CLA.PRIMARY_NEED_CAT = 'Cases other than child in need'  THEN 'N9'
             WHEN CLA.PRIMARY_NEED_CAT = 'Not stated'                      THEN 'N0'
        END  AS PRIMARY_NEED_RANK
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID                                       AS PERSONID,
            FAPV.INSTANCEID                                               AS ASSESSMENTID,
            FAPV.SUBMITTERPERSONID                                        AS SUBMITTERPERSONID,
            MAX(CASE
		        	WHEN FAPV.CONTROLNAME = 'CINCensus_ReferralSource'
		    	    THEN FAPV.ANSWERVALUE
		        END)                                                      AS REFERRAL_SOURCE,
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'AnnexAReturn_nextSteps_agreed'
	    		    THEN FAPV.ANSWERVALUE
	    	    END)                                                      AS NEXT_STEP,  
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'CINCensus_primaryNeedCategory'
	    		    THEN FAPV.ANSWERVALUE
		        END)                                                      AS PRIMARY_NEED_CAT,
	    	MAX(CASE
	    	    	WHEN FAPV.CONTROLNAME = 'CINCensus_DateOfReferral'
	    		    THEN FAPV.DATEANSWERVALUE
	    	    END)                                                      AS DATE_OF_REFERRAL    
        FROM  FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('e6d9de9a-b56c-49d0-ab87-0f913ca8fc5f') --Child: Referral
            AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.ANSWERFORSUBJECTID,
                 FAPV.INSTANCEID,
                 FAPV.SUBMITTERPERSONID
           ) CLA      
),    


CIN_EPISODE AS (
    SELECT 
        CLA.*,
        ALL_CIN_EPISODES.ENDREASON  AS CINE_REASON_END,
        CONCAT(CLA.PERSONID, REFERRAL.ASSESSMENTID)      AS REFERRALID,
        REFERRAL.DATE_OF_REFERRAL,
	    REFERRAL.PRIMARY_NEED_RANK,
        REFERRAL.SUBMITTERPERSONID,
        REFERRAL.REFERRAL_SOURCE,
        REFERRAL.NEXT_STEP
    FROM (  
        SELECT 
            CLA.PERSONID,
            MIN(CLA.EPISODE_STARTDATE)                                    AS CINE_START_DATE,
            CASE
	    	    WHEN BOOL_AND(EPISODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(EPISODE_ENDDATE)
	        END                                                           AS CINE_CLOSE_DATE,
	        MAX(EPISODE_ID)                                               AS LAST_CINE_ID
        FROM (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, EPISODE_STARTDATE) AS EPISODE,
	            CASE WHEN NEXT_START_FLAG = 1
	                 THEN EPISODEID
	            END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   PERSONID, 
                   EPISODEID,
	               EPISODE_STARTDATE,
                   EPISODE_ENDDATE,
                   ENDREASON,
                   CASE WHEN CLA.EPISODE_STARTDATE >= LAG(CLA.EPISODE_STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST) 
                           AND CLA.EPISODE_STARTDATE <= COALESCE(LAG(CLA.EPISODE_ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.EPISODE_STARTDATE, CLA.EPISODE_ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM ALL_CIN_EPISODES  CLA
               ORDER BY CLA.PERSONID,
	                    CLA.EPISODE_ENDDATE:: DATE DESC NULLS FIRST,
	                    CLA.EPISODE_STARTDATE:: DATE DESC 
	             ) CLA
	       
	          )CLA
    	GROUP BY PERSONID, EPISODE 
        ) CLA
    LEFT JOIN  ALL_CIN_EPISODES ON ALL_CIN_EPISODES.PERSONID = CLA.PERSONID AND ALL_CIN_EPISODES.EPISODE_ENDDATE = CLA.CINE_CLOSE_DATE
    LEFT JOIN LATERAL (
            SELECT
                *
            FROM REFERRAL 
            WHERE REFERRAL.PERSONID = CLA.PERSONID 
                AND REFERRAL.DATE_OF_REFERRAL <= CLA.CINE_START_DATE
            ORDER BY  REFERRAL.DATE_OF_REFERRAL DESC 
            FETCH FIRST 1 ROW ONLY) REFERRAL ON TRUE 
),

CIN_PLAN AS (
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
            SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, STARTDATE ROWS UNBOUNDED PRECEDING) AS EPISODE 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID    AS CLAID, 
                CLA.PERSONID, 
                CLA.STARTDATE::DATE               AS STARTDATE,
                CLA.ENDDATE::DATE                 AS ENDDATE,
                CASE WHEN CLA.STARTDATE > LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                            AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE) 
                     THEN 0
                     ELSE 1
                END                               AS NEXT_START_FLAG     
            FROM CLASSIFICATIONPERSONVIEW  CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
                  AND (CLA.CLASSIFICATIONPATHID IN (4) -- CIN classification
	                     OR CLA.CLASSIFICATIONCODEID IN (1270))    -- FAMILY Help CIN classificaion
                  AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
                ORDER BY CLA.PERSONID,
	                     CLA.ENDDATE DESC NULLS FIRST,
	                     CLA.STARTDATE DESC 
	             ) CLA
	       
	          )CLA
        GROUP BY CLA.PERSONID, CLA.EPISODE
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
            SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, STARTDATE ROWS UNBOUNDED PRECEDING) AS EPISODE 
        FROM (
            SELECT  
                CLA.CLASSIFICATIONASSIGNMENTID    AS CLAID, 
                CLA.PERSONID, 
                CLA.STARTDATE::DATE               AS STARTDATE,
                CLA.ENDDATE::DATE                 AS ENDDATE,
                CASE WHEN CLA.STARTDATE > LAG(CLA.STARTDATE ) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST) 
                            AND CLA.STARTDATE <= COALESCE(LAG(CLA.ENDDATE) OVER (PARTITION BY CLA.PERSONID ORDER BY CLA.STARTDATE, CLA.ENDDATE NULLS LAST), CURRENT_DATE) 
                     THEN 0
                     ELSE 1
                END                               AS NEXT_START_FLAG     
            FROM CLASSIFICATIONPERSONVIEW  CLA
            WHERE CLA.STATUS NOT IN ('DELETED')
                  AND CLA.CLASSIFICATIONPATHID IN (51) -- CP classification
	              AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
                ORDER BY CLA.PERSONID,
	                     CLA.ENDDATE DESC NULLS FIRST,
	                     CLA.STARTDATE DESC 
	             ) CLA
	       
	          )CLA
        GROUP BY CLA.PERSONID, CLA.EPISODE
)  ,


EH_EPISODE AS (  ----------EH Episodes
    SELECT 
        PERSONID,
        EH_REFERRAL_DATE,
        EH_CLOSE_DATE,
        MAX(EH_CLOSE_REASON)          AS EH_CLOSE_REASON,
        MIN(EH_REFERRAL_ID)           AS EH_REFERRAL_ID
    FROM (    
        SELECT 
            EH.PERSONID                                                  AS PERSONID,
            MIN(EH.PRIMARY_CODE_STARTDATE)                               AS EH_REFERRAL_DATE,
            CASE
	    	    WHEN BOOL_AND(PRIMARY_CODE_ENDDATE IS NOT NULL) IS FALSE
	    	    THEN NULL
	            ELSE MAX(PRIMARY_CODE_ENDDATE)
	        END                                                           AS EH_CLOSE_DATE,
	        MAX(ENDREASON)                                                AS EH_CLOSE_REASON,
	        MAX(EPISODE_ID)                                               AS EH_REFERRAL_ID
        FROM (
            SELECT  
                *,
                SUM(NEXT_START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, PRIMARY_CODE_STARTDATE) AS EPISODE,
	            CASE WHEN NEXT_START_FLAG = 1
	                 THEN EPISODEID
	            END                                                                                                                  AS EPISODE_ID     
           FROM (
               SELECT 
                   EH.PERSONID, 
                   EH.CLASSIFICATIONASSIGNMENTID                                      AS EPISODEID,
	               EH.STARTDATE::DATE                                                 AS PRIMARY_CODE_STARTDATE,
                   EH.ENDDATE::DATE                                                   AS PRIMARY_CODE_ENDDATE,
                   EH.ENDREASON,
                   CASE WHEN EH.STARTDATE >= LAG(EH.STARTDATE ) OVER (PARTITION BY EH.PERSONID ORDER BY EH.STARTDATE, EH.ENDDATE NULLS LAST) 
                           AND EH.STARTDATE <= COALESCE(LAG(EH.ENDDATE) OVER (PARTITION BY EH.PERSONID ORDER BY EH.STARTDATE, EH.ENDDATE NULLS LAST), CURRENT_DATE)+ INTERVAL '1 day' 
                        THEN 0
                        ELSE 1
                   END                                                                 AS NEXT_START_FLAG     
               FROM CLASSIFICATIONPERSONVIEW  EH
               WHERE EH.STATUS NOT IN ('DELETED')
                   AND EH.CLASSIFICATIONCODEID IN (699,1271)
                   AND EH.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
               ORDER BY EH.PERSONID,
	                    EH.ENDDATE:: DATE DESC NULLS FIRST,
	                    EH.STARTDATE:: DATE DESC 
	             ) EH
	       
	          )EH
    	--WHERE  PERSONID = 266     
        GROUP BY PERSONID, EPISODE 
        ) EH
        
    GROUP BY  PERSONID,
              EH_REFERRAL_DATE,
              EH_CLOSE_DATE 
),

CLOSURE AS (
    SELECT DISTINCT  
        FAPV.INSTANCEID,
        FAPV.ANSWERFORSUBJECTID  AS PERSONID,
        FAPV.DATECOMPLETED::DATE AS COMPLETED_DATE,
        MAX(CASE
			WHEN FAPV.CONTROLNAME = 'AnnexA_reasonForClosure1'
			  OR FAPV.CONTROLNAME = 'reasonForClosure1' 
			  OR FAPV.CONTROLNAME = 'reasonForCaseClosure'
			THEN FAPV.ANSWERVALUE
		END)                     AS REASON,
		MAX(CASE
			WHEN FAPV.CONTROLNAME = 'dateOfClosure'
			  OR FAPV.CONTROLNAME = 'dateCaseClosed' 
			 -- OR FAPV.CONTROLNAME = 'reasonForCaseClosure'
			THEN FAPV.ANSWERVALUE
		END)::DATE                     AS CLOSURE_DATE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE (FAPV.DESIGNGUID IN ('12bb8ca2-e585-4a09-a6dd-d5b6e910a3f0') --Early Help: Closure
           OR FAPV.DESIGNGUID IN ('57eef045-0dbb-4df4-8dbd-bb07acf99e99')) --Family Help: Closure
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         --AND INSTANCEID = 1830828
    GROUP BY  FAPV.INSTANCEID,
              FAPV.ANSWERFORSUBJECTID,
              FAPV.DATECOMPLETED 
),


WORKER AS (    -------Responcible social worker 
    SELECT 
        PPR.PERSONRELATIONSHIPRECORDID       AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.PROFESSIONALRELATIONSHIPPERSONID AS ALLOCATED_WORKER,
        PPR.STARTDATE                        AS WORKER_START_DATE,
        PPR.CLOSEDATE                        AS WORKER_END_DATE
    FROM RELATIONSHIPPROFESSIONALVIEW PPR
    WHERE ALLOCATEDWORKERCODE = 'AW' 
),


TEAM AS (    -------Responcible team
    SELECT 
        PPR.RELATIONSHIPID                   AS ID,
        PPR.PERSONID                         AS PERSONID,
        PPR.ORGANISATIONID                   AS ALLOCATED_TEAM,
        PPR.DATESTARTED                      AS TEAM_START_DATE,
        PPR.DATEENDED                        AS TEAM_END_DATE
    FROM PERSONORGRELATIONSHIPVIEW PPR
    WHERE ALLOCATEDTEAMCODE = 'AT' 
),

IRO_MEETING AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                       AS PERSONID,
        FAPV.INSTANCEID                                               AS ASSESSMENTID,
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
			    THEN FAPV.DATEANSWERVALUE
		    END)                                                      AS DATE_OF_MEETING    
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('2d9d174f-77ed-40bd-ac2b-cae8015ad799') --Child: IRO Review Record
        AND FAPV.INSTANCESTATE = 'COMPLETE'
    GROUP BY FAPV.ANSWERFORSUBJECTID,
             FAPV.INSTANCEID
),

EPISODES AS (
    SELECT
	    EPIS.EPISODEOFCAREID, 
	    EPIS.PERSONID,
	    EPIS.LEGALSTATUS,
	    EPIS.EOCSTARTDATE,
	    EPIS.EOCENDDATE
    FROM CLAEPISODEOFCAREVIEW EPIS	
    WHERE EPIS.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
),

ASSESSMENT AS (
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                                AS PERSONID,
        FAPV.INSTANCEID                                                        AS CINA_ASSESSMENT_ID,
        FAPV.DATECOMPLETED ::DATE                                              AS CINA_ASSESSMENT_AUTH_DATE,
        CASE WHEN MAX(CASE
		    	          WHEN FAPV.CONTROLNAME = 'SeenAlone'
			              THEN FAPV.ANSWERVALUE
		              END) IN ('Child seen alone', 'Child seen with others')  
		     THEN 'Y'
		     ELSE 'N'
	    END	                                                                   AS CINA_ASSESSMENT_CHILD_SEEN, 
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'CINCensus_startDateOfForm'
		    	THEN FAPV.ANSWERVALUE
	        END) ::DATE                                                        AS CINA_ASSESSMENT_START_DATE,
	    MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'WorkerOutcome'
		    	THEN FAPV.ANSWERVALUE
	        END)	                                                           AS OUTCOME  
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('94b3f530-a918-4f33-85c2-0ae355c9c2fd') --Child: Assessment
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.CONTROLNAME IN ('SeenAlone', 'CINCensus_startDateOfForm','WorkerOutcome')
        AND COALESCE(FAPV.DESIGNSUBNAME,'?') IN (
				'Reassessment',
				'Single assessment'
			)
    GROUP BY   FAPV.ANSWERFORSUBJECTID,
               FAPV.INSTANCEID,
               FAPV.DATECOMPLETED 
               
    UNION ALL 
    
    SELECT 
        FAPV.ANSWERFORSUBJECTID                                                AS CINA_PERSON_ID,
        FAPV.INSTANCEID                                                        AS CINA_ASSESSMENT_ID,
        FAPV.DATECOMPLETED ::DATE                                              AS CINA_ASSESSMENT_AUTH_DATE,
        MAX(CASE
		    	          WHEN FAPV.CONTROLNAME = 'wasTheChildSeen'
			              THEN FAPV.ANSWERVALUE
		END)                                                                   AS CINA_ASSESSMENT_CHILD_SEEN, 
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'dateOfDocument'
		    	THEN FAPV.ANSWERVALUE
	        END) ::DATE                                                        AS CINA_ASSESSMENT_START_DATE,
	    MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'outcomes2'
		    	THEN FAPV.ANSWERVALUE
	        END)	                                                           AS OUTCOME  
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('6d3b942a-37ad-40ef-8cc6-b202d2cd1c0e') --Family Help: Discussion
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.CONTROLNAME IN ('wasTheChildSeen', 'dateOfDocument','outcomes2')
        
    GROUP BY   FAPV.ANSWERFORSUBJECTID,
               FAPV.INSTANCEID,
               FAPV.DATECOMPLETED 
 ),
    
INITIAL_ASESSMENT AS (
   SELECT 
       *
   FROM (
       SELECT DISTINCT  
           FAPV.INSTANCEID,
           FAPV.ANSWERFORSUBJECTID        AS PERSONID,
           FAPV.DATECOMPLETED::DATE       AS COMPLETIONDATE,
           MAX(CASE
				    WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
				    THEN FAPV.ANSWERVALUE
		   END)::DATE                     AS DATE_OF_MEETING,
		   MAX(CASE
		            WHEN FAPV.CONTROLNAME = 'AnnexAReturn_typeOfMeeting'
		            THEN FAPV.ANSWERVALUE
	       END)                           AS MEETING_TYPE,
	       MAX(CASE
		            WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
		            THEN FAPV.ANSWERVALUE
	       END)                           AS NEXT_STEP
       FROM  FORMANSWERPERSONVIEW FAPV
       WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         AND DESIGNSUBNAME = 'Child Protection - Initial Conference'
         AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
       GROUP BY FAPV.INSTANCEID,
                FAPV.ANSWERFORSUBJECTID,
                FAPV.DATECOMPLETED 
    )FAPV
    WHERE MEETING_TYPE IN ('Child Protection (Initial child protection conference)', 'Child Protection (Transfer in conference)')
),

ASESSMENT47 AS(
    SELECT
        *
    FROM (    
        SELECT
	    	FAPV.INSTANCEID ,
	    	FAPV.ANSWERFORSUBJECTID          AS PERSONID ,
		    MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
				     THEN FAPV.DATEANSWERVALUE
		    END) AS STARTDATE,
		    FAPV.DATECOMPLETED::DATE         AS COMPLETIONDATE,
	    	MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_unsubWhatNeedsToHappenNext', 'CINCensus_whatNeedsToHappenNext')
		    		 THEN FAPV.ANSWERVALUE
	        END)                             AS OUTCOME
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.INSTANCEID ,
		         FAPV.ANSWERFORSUBJECTID,
		         FAPV.DATECOMPLETED
    ) FAPV
    WHERE FAPV.OUTCOME = 'Convene initial child protection conference'
),  

STRATEGY_DISC AS (
    SELECT 
        *,
        TARR."DATE"                 AS TARGET_DATE
    FROM (    
        SELECT 
            FAPV.INSTANCEID ,
		    FAPV.ANSWERFORSUBJECTID AS PERSONID ,
		    MAX(CASE WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
			    	 THEN FAPV.DATEANSWERVALUE
	    	END)                    AS MEETING_DATE
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('f9a86a19-ea09-41f0-9403-a88e2b0e738a') --Child Protection: Strategy discussion
          AND FAPV.INSTANCESTATE = 'COMPLETE'
        GROUP BY FAPV.INSTANCEID ,
		         FAPV.ANSWERFORSUBJECTID,
		         FAPV.DATECOMPLETED
	    ) FAPV	
    LEFT JOIN WORKING_DAY_RANKS SDR ON SDR."DATE" = FAPV.MEETING_DATE 
    LEFT JOIN WORKING_DAY_RANKS TARR ON TARR.RANK = SDR.RANK + 15
),

CP_PLAN AS (
    SELECT
	CP_PLAN.CLASSIFICATIONASSIGNMENTID  AS PLANID,
	CP_PLAN.PERSONID                    AS PERSONID,
	CP_PLAN.STARTDATE:: DATE            AS PLAN_START_DATE,
	CP_PLAN.ENDDATE:: DATE              AS PLAN_END_DATE,
	CIN_EPISODE.CINE_REFERRAL_ID
	FROM CLASSIFICATIONPERSONVIEW CP_PLAN
	LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CIN_EPISODE
                WHERE CIN_EPISODE.CINE_PERSON_ID = CP_PLAN.PERSONID
                    AND CIN_EPISODE.CINE_REFERRAL_DATE <= CP_PLAN.STARTDATE:: DATE
                ORDER BY CIN_EPISODE.CINE_REFERRAL_DATE DESC
                FETCH FIRST 1 ROW ONLY
                ) CIN_EPISODE ON TRUE 
WHERE CP_PLAN.CLASSIFICATIONPATHID = 51 
   AND CP_PLAN.STATUS NOT IN ('DELETED')
   AND CP_PLAN.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
),

CP_CATEGORY AS (
    SELECT 
        CP_CATEGORY.PERSONID,
        CP_CATEGORY.NAME,
        CP_CATEGORY.STARTDATE:: DATE AS STARTDATE,
        CP_CATEGORY.ENDDATE:: DATE   AS ENDDATE
    FROM CLASSIFICATIONPERSONVIEW CP_CATEGORY
    WHERE CP_CATEGORY.CLASSIFICATIONPATHID = 81 
),

CP_REVIEW AS(
    SELECT 
        FAPV.ANSWERFORSUBJECTID    AS PERSONID,
        FAPV.INSTANCEID 		   AS FORMID,
        MAX(CASE
	        WHEN FAPV.CONTROLNAME = 'ChildProtectionNextStep'
	        THEN FAPV.ANSWERVALUE
        END)                       AS NEXT_STEP,
        MAX(CASE
	        WHEN FAPV.CONTROLNAME = 'dateofnextplanmeetingreview_35'
	        THEN FAPV.ANSWERVALUE
        END) :: DATE               AS NEXT_REVIEW,
        MAX(CASE
	        WHEN FAPV.CONTROLNAME = '903Return_dateOfMeetingConference'
	        THEN FAPV.ANSWERVALUE
        END)::DATE                 AS DATE_OF_MEETING   
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('21e01e2e-fd65-439d-a8aa-a179106a3d45') --Child: Record of meeting(s) and plan
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.designsubname = 'Child Protection - Review Conference'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.ANSWERFORSUBJECTID ,
             FAPV.INSTANCEID      
),

IRO_REVIEW AS (
    SELECT
 	    FAPV.ANSWERFORSUBJECTID 	AS PERSONID,
        FAPV.INSTANCEID 			AS FORMID,
        MAX(CASE
              WHEN FAPV.CONTROLNAME = 'howwasthechildabletocontributetheirviewstotheconference_4'
              THEN FAPV.SHORTANSWERVALUE
        END)                      AS PARTICIPATION,
        MAX(CASE
              WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
              THEN FAPV.ANSWERVALUE
        END)::DATE                AS DATE_OF_MEETING       
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('79f3495c-134f-4e69-b00f-7621925419f7') --Independent Reviewing Officer: Quality assurance
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.designsubname = 'Child protection conference' 
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.ANSWERFORSUBJECTID,
              FAPV.INSTANCEID
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
        STARTDATE:: DATE  AS STARTDATE,
        ENDDATE:: DATE    AS ENDDATE
    FROM ADDRESSPERSONVIEW
    
    UNION ALL
    
    SELECT 
        'ORG',
        ORGANISATIONID,
        UPRN ,
        LATITUDE,
        LONGITUDE,
        POSTCODE,
        TYPE,
        STARTDATE:: DATE,
        ENDDATE:: DATE
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
        MIN(EOCSTARTDATE):: DATE EOCSTARTDATE,
        CASE WHEN BOOL_AND(EOCENDDATE IS NOT NULL) IS FALSE
             THEN NULL
             ELSE MAX(EOCENDDATE)::DATE
        END  AS EOCENDDATE 
    FROM (    
        SELECT 
            *,
            SUM(START_FLAG) OVER (PARTITION BY PERSONID, CARERID ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST) AS GRP
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
					WHEN LAG(CLA_PLACEMENT.EOCENDDATE) OVER (PARTITION BY PERSONID, PERIODOFCAREID, CARERID, PLACEMENTADDRESSID ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST) >= EOCSTARTDATE - INTERVAL '1 day'
						OR 
						EOCSTARTDATE BETWEEN
							LAG(EOCSTARTDATE) OVER (PARTITION BY PERSONID,PERIODOFCAREID, CARERID,PLACEMENTADDRESSID ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST) 
							AND LAG(COALESCE(EOCENDDATE,CURRENT_DATE)) OVER (PARTITION BY PERSONID,PERIODOFCAREID, CARERID,PLACEMENTADDRESSID ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST)
							THEN 0
						ELSE 1
				END START_FLAG
            FROM CLA_PLACEMENT_EPISODES CLA_PLACEMENT
            ORDER BY PERSONID, EOCENDDATE DESC NULLS FIRST, EOCSTARTDATE DESC
            ) CLA_PLACEMENT
        ) CLA_PLACEMENT
    GROUP BY PERSONID,PERIODOFCAREID,PLACEMENTADDRESSID,PLACEMENTPOSTCODE,PLACEMENTTYPECODE,PLACEMENTPROVISIONCODE,CARERTYPE, CARERID, GRP
    
),

CLA_REVIEW AS(
    SELECT 
        CLA_REVIEW.*,
        CLA.PERIODOFCAREID 
    FROM (    
        SELECT 
            FAPV.ANSWERFORSUBJECTID    AS PERSONID,
	        FAPV.INSTANCEID 		   AS FORMID,
	        MAX(CASE
		        WHEN FAPV.CONTROLNAME = 'dateOfNextReview'
		        THEN FAPV.ANSWERVALUE
	        END) :: DATE               AS NEXT_REVIEW,
	        MAX(CASE
		        WHEN FAPV.CONTROLNAME = 'dateOfReview'
		        THEN FAPV.ANSWERVALUE
	        END)::DATE                 AS DATE_OF_REVIEW   
	    FROM FORMANSWERPERSONVIEW FAPV
        WHERE FAPV.DESIGNGUID IN ('b5c5c8d8-5ba7-4919-a3cd-9722e8e90aaf') --Child in Care:  IRO decisions
            AND FAPV.INSTANCESTATE = 'COMPLETE'
            AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
        GROUP BY FAPV.ANSWERFORSUBJECTID ,
	             FAPV.INSTANCEID      
         ) CLA_REVIEW
    LEFT JOIN CLAPERIODOFCAREVIEW CLA ON CLA.PERSONID = CLA_REVIEW.PERSONID
          AND CLA_REVIEW.DATE_OF_REVIEW >= CLA.ADMISSIONDATE AND CLA_REVIEW.DATE_OF_REVIEW <= COALESCE(CLA.DISCHARGEDATE,CURRENT_DATE)  
   
),

CARELEAVER_REVIEW AS(
   SELECT 
   *,
     RANK () OVER (PARTITION BY PERSONID ORDER BY REIEW_DATE DESC) AS LATEST_REVIEW
   FROM (
    SELECT 
        FAPV.ANSWERFORSUBJECTID     AS PERSONID, 
        FAPV.INSTANCEID,
        MAX(CASE
		    	WHEN FAPV.CONTROLNAME = 'dateOfPathwayPlan'
			    THEN FAPV.DATEANSWERVALUE
		END) AS REIEW_DATE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('c17d1557-513d-443f-8013-a31eb541455b') --Care leavers: Pathway Needs assessment and plan 
        AND FAPV.INSTANCESTATE = 'COMPLETE'
     --   AND FAPV.ANSWERFORSUBJECTID = 75975
     --  AND FAPV.INSTANCEID = 2081278
GROUP BY FAPV.ANSWERFORSUBJECTID , 
    FAPV.INSTANCEID
    ) FAPV
)

-- META-CONTAINER: {"type": "table", "name": "ssd_person"}
-- =============================================================================
-- Description: Person/child details. This the most connected & central star node in the SSD.
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
    -- /*SSD Person filter (notes): - Implemented*/
    -- [done]contact in last 6yrs - HDM.Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
    -- [done] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
    -- [picked up within the referral] active plan or has been active in 6yrs 
-- Dependencies:
-- - 
-- =============================================================================



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_person') IS NOT NULL DROP TABLE ssd_development.ssd_person;
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}   
    pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A", "item_status":"P", "info":"If additional status to Gender is held, otherwise dup of pers_gender"}    
    pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"R", "expected_data":["unknown","NULL","F","U","M","I"]}       
    pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"} 
    pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
    pers_common_child_id    NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
    pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
    pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
    pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        NVARCHAR(48),               -- metadata={"item_ref":"PERS012A"} 
    ssd_flag                INT                         -- Non-core data flag for D2I filter testing [TESTING]
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,       -- sex and gender currently extracted as one
    pers_gender,    -- 
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,                               
    pers_upn_unknown,                                  
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality,
    ssd_flag
)


SELECT DISTINCT
	P.PERSONID               AS "pers_person_id", --metadata={"item_ref:"PERS001A"}
	P.SURNAME                AS "pers_surname" -- metadata={"item_ref":"PERS016A"}    
	P.FORENAME               AS "pers_forename",  -- metadata={"item_ref":"PERS015A"}  
	CASE
		WHEN P.SEX = 'Male'
			THEN 'M'
		WHEN P.SEX = 'Female'
			THEN 'F'
		ELSE 'U'
	END                      AS "pers_sex", --metadata={"item_ref:"PERS002A"}
	CASE
		WHEN P.GENDER = 'Man'
			THEN '01'
		WHEN P.GENDER = 'Woman'
			THEN '02'
		WHEN P.GENDER IS NULL
			THEN '00'
		ELSE '09'
	END                      AS "pers_gender", --metadata={"item_ref:"PERS003A"}
	CASE
		WHEN P.ETHNICITYCODE = 'ARAB' THEN '??'
		WHEN P.ETHNICITYCODE = 'BANGLADESHI' THEN 'ABAN'
		WHEN P.ETHNICITYCODE = 'INDIAN' THEN 'AIND'
		WHEN P.ETHNICITYCODE = 'OTHER_ASIAN' THEN 'AOTH'
		WHEN P.ETHNICITYCODE = 'ENG_SCOT_TRAVELLER' THEN 'AOTH'
		WHEN P.ETHNICITYCODE = 'PAKISTANI' THEN 'APKN'
		WHEN P.ETHNICITYCODE = 'AFRICAN' THEN 'BAFR'
		WHEN P.ETHNICITYCODE = 'BLACK_AFRICAN' THEN 'BAFR'
		WHEN P.ETHNICITYCODE = 'BLACK_CARIBBEAN' THEN 'BCRB'
		WHEN P.ETHNICITYCODE = 'CARIBBEAN' THEN 'BCRB'
		WHEN P.ETHNICITYCODE = 'OTHER_BLACK' THEN 'BOTH'
		WHEN P.ETHNICITYCODE = 'OTHER_AFRICAN' THEN 'BOTH'
		WHEN P.ETHNICITYCODE = 'CHINESE' THEN 'CNHE'
		WHEN P.ETHNICITYCODE = 'OTHER_MIXED' THEN 'MOTH'
		WHEN P.ETHNICITYCODE = 'WHITE_AND_ASIAN' THEN 'MWAS'
		WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_AFRICAN' THEN 'MWBa'
		WHEN P.ETHNICITYCODE = 'WHITE_AND_BLACK_CARIBBEAN' THEN 'MWBC'
		WHEN P.ETHNICITYCODE = 'NOT_KNOWN' THEN 'NOBT'
		WHEN P.ETHNICITYCODE = 'OTHER_ETHNIC' THEN 'OOTH'
		WHEN P.ETHNICITYCODE = 'REFUSED' THEN 'REFU'
		WHEN P.ETHNICITYCODE = 'WHITE_BRITISH' THEN 'WBRI'
		WHEN P.ETHNICITYCODE = 'WHITE_NORTHERNIRISH' THEN 'WBRI'
		WHEN P.ETHNICITYCODE = 'WHITE_SCOTTISH' THEN 'WBRI'
		WHEN P.ETHNICITYCODE = 'WHITE_WELSH' THEN 'WBRI'
		WHEN P.ETHNICITYCODE = 'WHITE_IRISH' THEN 'WIRI'
		WHEN P.ETHNICITYCODE = 'IRISHTRAVELLER' THEN 'WIRT'
		WHEN P.ETHNICITYCODE = 'OTHER_WHITE_ORIGIN' THEN 'WOTH'
		WHEN P.ETHNICITYCODE = 'WHITE_POLISH' THEN 'WOTH'
		WHEN P.ETHNICITYCODE = 'GYPSY' THEN 'WROM'
		WHEN P.ETHNICITYCODE = 'TRAVELLER' THEN 'WROM'
		WHEN P.ETHNICITYCODE = 'ROMA' THEN 'WROM'
		WHEN P.ETHNICITYCODE IS NULL THEN 'NOBT'
		ELSE '??'
	END                        AS "pers_ethnicity", --metadata={"item_ref:"PERS004A"}
	COALESCE(P.DATEOFBIRTH,
		CASE
			WHEN P.DATEOFBIRTH IS NULL AND P.DUEDATE >= CURRENT_TIMESTAMP
			 	THEN P.DUEDATE
		END
	)                          AS "pers_dob", --metadata={"item_ref:"PERS005A"}
	P.NHSNUMBER "pers_common_child_id", --metadata={"item_ref:"PERS013A"}
	P.CAREFIRSTID "pers_legacy_id", --metadata={"item_ref:"PERS014A"}
	COALESCE(UPN.UPN,UN_UPN.UN_UPN,
			--factor in those under 5
			CASE
				WHEN EXTRACT(YEAR FROM AGE(COALESCE(P.DIEDDATE,CURRENT_TIMESTAMP),P.DATEOFBIRTH)) < 5
					THEN 'UN1'
				--new in care (1 week prior to collection period end)
			 	--NEEDS BUILDING IN
				--WHEN EOC.POCSTARTDATE + interval '1 week' >= C.SUBMISSION_TO
				-- 	THEN 'UN4'
				--when UASC
				WHEN UASC.PERSONID IS NOT NULL
				 	THEN 'UN2'
			END
	)                          AS "pers_upn_unknown", --metadata={"item_ref:"PERS007A"}
	/*Flag showing if a person has an EHC plan recorded on the system. 
	Code set 
	Y - Has an EHC Plan 
	N - Does not have an EHC Plan  */
	NULL                       AS "pers_send_flag", --metadata={"item_ref:"PERS008A"}
	CASE
		WHEN P.DUEDATE >= CURRENT_TIMESTAMP
			THEN P.DUEDATE
	END                        AS "pers_expected_dob", --metadata={"item_ref:"PERS009A"}
	P.DIEDDATE "pers_death_date", --metadata={"item_ref:"PERS010A"}
	CASE
		WHEN MOTHER.PERSONID IS NOT NULL
			THEN 'Y'
		ELSE 'N'
	END                        AS "pers_is_mother", --metadata={"item_ref:"PERS011A"}
	/*Required for UASC, reported in the ADCS Safeguarding Pressures research. */
	P.COUNTRYOFBIRTHCODE       AS "pers_nationality" --metadata={"item_ref:"PERS012A"}
FROM PERSONDEMOGRAPHICSVIEW P
LEFT JOIN (
	SELECT DISTINCT
		RNPV.PERSONID,
		RNPV.REFERENCENUMBER UPN,
		--open on the system first, then followed by the most recent
		ROW_NUMBER() OVER(PARTITION BY PERSONID ORDER BY COALESCE(RNPV.ENDDATE,CURRENT_TIMESTAMP) DESC, STARTDATE DESC) RN
	FROM REFERENCENUMBERPERSONVIEW RNPV
	WHERE RNPV.REFERENCETYPECODE = 'UPN'
) UPN ON P.PERSONID = UPN.PERSONID --derived table is around 5 seconds
	AND UPN.RN = 1
LEFT JOIN (
	SELECT DISTINCT
		A.PERSONID,
		STRING_AGG(CLASSIFICATION_CODE,', ') UN_UPN
	FROM (
		SELECT DISTINCT
			PCA.PERSON_FK PERSONID,
			--CONCAT(CG.NAME,'/',CLA.NAME) CLASSIFICATION,
			CLA.CODE CLASSIFICATION_CODE,
			--This needs major reconciliations into the front end to ensure accuracy - not convinced currently
			CAST(CLA_ASSIGN.START_DATE AS DATE) START_DATE,
			CAST(CLA_ASSIGN.END_DATE AS DATE) END_DATE,
			--open on the system first, then followed by the most recent, use dense rank here because concerns over DQ
			DENSE_RANK() OVER(PARTITION BY PCA.PERSON_FK ORDER BY COALESCE(CLA_ASSIGN.END_DATE,CURRENT_TIMESTAMP) DESC, CLA_ASSIGN.START_DATE DESC) RN
		FROM CLASSIFICATION CLA
		INNER JOIN CLASSIFICATION_GROUP CG ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
		INNER JOIN CLASSIFICATION_ASSIGNMENT CLA_ASSIGN ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
			AND COALESCE(CLA_ASSIGN.STATUS,'?') NOT IN ('DELETED')
		INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
		INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA ON PCA.ID = CLA_SUBJ.ID
		WHERE CG.ID = 2
			--based on the guidance only want those which are UN1-5, some instances where they were UN6+, remove these.
			AND CLA.CODE IN ('UN1','UN2','UN3','UN4','UN5')
	) A
	WHERE A.RN = 1
	GROUP BY A.PERSONID
) UN_UPN ON P.PERSONID = UN_UPN.PERSONID --derived table is around 5 seconds
LEFT JOIN (
	SELECT DISTINCT
		PCA.PERSON_FK PERSONID,
		CONCAT(CG.NAME,'/',CLA.NAME) CLASSIFICATION,
		CAST(CLA_ASSIGN.START_DATE AS DATE) START_DATE,
		CAST(CLA_ASSIGN.END_DATE AS DATE) END_DATE,
		ROW_NUMBER() OVER(PARTITION BY PCA.PERSON_FK ORDER BY CAST(CLA_ASSIGN.START_DATE AS DATE) DESC) RN
	FROM CLASSIFICATION CLA
	INNER JOIN CLASSIFICATION_GROUP CG ON CLA.CLASSIFICATION_GROUP_FK = CG.ID
	INNER JOIN CLASSIFICATION_ASSIGNMENT CLA_ASSIGN ON CLA.ID = CLA_ASSIGN.CLASSIFICATION_FK
		AND COALESCE(CLA_ASSIGN.STATUS,'?') NOT IN ('DELETED')
	INNER JOIN SUBJECT_CLASSIFICATION_ASSIGNM CLA_SUBJ ON CLA_ASSIGN.SUBJECT_CLASSIFICATION_ASSI_FK = CLA_SUBJ.ID
	INNER JOIN PERSON_CLASSIFICATION_ASSIGNME PCA ON PCA.ID = CLA_SUBJ.ID
	WHERE UPPER(CG.CODE) = 'ASY_STAT'
		--unacc only!
		AND CLA.ID = 423
) UASC ON P.PERSONID = UASC.PERSONID --about 2 seconds for the derived table
	AND UASC.RN = 1
	AND COALESCE(UASC.END_DATE,CURRENT_TIMESTAMP) >= CURRENT_TIMESTAMP
	AND UASC.START_DATE <= CURRENT_TIMESTAMP
LEFT JOIN (
	SELECT DISTINCT
		PV2.PERSONID,
		PV2.CAREFIRSTID,
		PV2.DATEOFBIRTH,
		EXTRACT(YEAR FROM AGE(CURRENT_DATE,PV2.DATEOFBIRTH)) AGE_ON_SNAPSHOT,
		EXTRACT(YEAR FROM AGE(PV.DATEOFBIRTH,PV2.DATEOFBIRTH)) AGE_AT_CHILD_BIRTH,
		PV2.FORENAME,
		PV2.SURNAME,
		PV.PERSONID CHILD_PERSONID,
		CONCAT(PV.FORENAME,' ',PV.SURNAME) CHILD_NAME,
		PV.DATEOFBIRTH CHILD_DOB,
		PPR.START_DATE RELATIONSHIP_START_DATE,
		PPR.CLOSE_DATE RELATIONSHIP_END_DATE,
		CASE
			WHEN CURRENT_DATE BETWEEN PPR.START_DATE AND COALESCE(PPR.CLOSE_DATE,CURRENT_DATE)
				THEN 'Y'
			ELSE 'N'
		END ACTIVE_RELATIONSHIP,
		RT.ID RELATIONSHIP_TYPE_ID,
		RT.RELATIONSHIP_CLASS,
		RT.RELATIONSHIP_CLASS_NAME
	FROM PERSONDEMOGRAPHICSVIEW PV
	INNER JOIN PERSON_PER_RELATIONSHIP PPR ON (PV.PERSONID = PPR.ROLE_A_PERSON_FK OR PV.PERSONID = PPR.ROLE_B_PERSON_FK)
	INNER JOIN PERSONVIEW PV2 ON (PPR.ROLE_B_PERSON_FK = PV2.PERSONID OR PPR.ROLE_A_PERSON_FK = PV2.PERSONID)
	INNER JOIN RELATIONSHIP_TYPE RT ON PPR.PERSON_PER_REL_TYPE_FK  = RT.ID
		AND RT.ID IN (17)
	WHERE PV.PERSONID <> COALESCE(PV2.PERSONID,000000)
		AND COALESCE(PV.DATEOFBIRTH,CURRENT_DATE) >= PV2.DATEOFBIRTH
		AND PV2.GENDER = 'Female'
) MOTHER ON P.PERSONID = MOTHER.PERSONID
WHERE P.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;




-- META-ELEMENT: {"type": "create_fk"}
-- Not required

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_dob               ON ssd_development.ssd_person(pers_dob);
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_common_child_id   ON ssd_development.ssd_person(pers_common_child_id);
CREATE NONCLUSTERED INDEX idx_ssd_person_ethnicity_gender       ON ssd_development.ssd_person(pers_ethnicity, pers_gender);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_family"}
-- =============================================================================
-- Description: Contains the family connections for each person
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
-- Dependencies: 
-- - 
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_family') IS NOT NULL DROP TABLE ssd_development.ssd_family;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )



SELECT
	CONCAT(RFAMILY.GROUPID,RFAMILY.PERSONID) AS "fami_table_id", --metadata={"item_ref:"FAMI003A"}
	RFAMILY.GROUPID                          AS "fami_family_id", --metadata={"item_ref:"FAMI001A"}
	RFAMILY.PERSONID                         AS "fami_person_id"  --metadata={"item_ref:"FAMI002A"}
	
FROM GROUPPERSONVIEW	RFAMILY
LEFT JOIN GROUPVIEW ON GROUPVIEW.GROUPID = RFAMILY.GROUPID
WHERE GROUPTYPE = 'Family'
  AND RFAMILY.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E) 
 ;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_family ADD CONSTRAINT FK_ssd_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_family_person_id          ON ssd_development.ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_development.ssd_family(fami_family_id);

-- META-END






-- META-CONTAINER: {"type": "table", "name": "ssd_address"}
-- =============================================================================
-- Description: Contains full address details for every person 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_address') IS NOT NULL DROP TABLE ssd_development.ssd_address;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
    addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
    addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
    addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
    addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
    addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
    addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_address (
    addr_table_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start_date, 
    addr_address_end_date, 
    addr_address_postcode, 
    addr_address_json
)



SELECT
	PERSADDRESS.ADDRESSID                       AS "addr_table_id",     --metadata={"item_ref:"ADDR007A"}
	JSON_BUILD_OBJECT( 
         'ROOM'    , COALESCE(PERSADDRESS.ROOMDESCRIPTION, ''),
         'FLOOR'   , COALESCE(PERSADDRESS.FLOORDESCRIPTION, ''), 
         'FLAT'    , '',
         'BUILDING', COALESCE(PERSADDRESS.BUILDINGNAMEORNUMBER, ''), 
         'HOUSE'   , COALESCE(PERSADDRESS.BUILDINGNAMEORNUMBER, ''), 
         'STREET'  , COALESCE(PERSADDRESS.STREETNAME, ''), 
         'TOWN'    , COALESCE(PERSADDRESS.TOWNORCITY, ''),
         'UPRN'    , COALESCE(PERSADDRESS.UPRN, NULL),
         'EASTING' , '',
         'NORTHING', ''
     )                                          AS "addr_address_json", --metadata={"item_ref:"ADDR001A"}
	PERSADDRESS.PERSONID                        AS "addr_person_id",    --metadata={"item_ref:"ADDR002A"}
	PERSADDRESS.TYPE                            AS "addr_address_type", --metadata={"item_ref:"ADDR003A"}
	PERSADDRESS.STARTDATE                       AS "addr_address_start_date", --metadata={"item_ref:"ADDR004A"}
	PERSADDRESS.ENDDATE                         AS "addr_address_end_date",    --metadata={"item_ref:"ADDR005A"}
	REPLACE(PERSADDRESS.POSTCODE, ' ', '')      AS "addr_postcode"             --metadata={"item_ref:"ADDR006A"}
FROM ADDRESSPERSONVIEW PERSADDRESS
WHERE PERSADDRESS.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E);




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_address ADD CONSTRAINT FK_ssd_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_address_person        ON ssd_development.ssd_address(addr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_address_start         ON ssd_development.ssd_address(addr_address_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_address_end           ON ssd_development.ssd_address(addr_address_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_ssd_address_postcode  ON ssd_development.ssd_address(addr_address_postcode);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_disability"}
-- =============================================================================
-- Description: Contains the Y/N flag for persons with disability
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_disability') IS NOT NULL DROP TABLE ssd_development.ssd_disability;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)


SELECT
	CLA.PERSONID                    AS "disa_person_id", --metadata={"item_ref:"DISA001A"}
	CLA.CLASSIFICATIONASSIGNMENTID  AS "disa_table_id",  --metadata={"item_ref:"DISA003A"}
	CASE WHEN CLASSIFICATION.NAME = 'No disability' 
	         THEN 'NONE'
	     WHEN CLASSIFICATION.NAME = 'Mobility' 
	         THEN 'MOB'
	     WHEN CLASSIFICATION.NAME = 'Hand function' 
	         THEN 'HAND'
	     WHEN CLASSIFICATION.NAME = 'Personal care' 
	         THEN 'PC'
	     WHEN CLASSIFICATION.NAME = 'Incontinence' 
	         THEN 'INC'
	     WHEN CLASSIFICATION.NAME = 'Communication' 
	         THEN 'COMM'
	     WHEN CLASSIFICATION.NAME = 'Learning Disability'
	          OR  CLA.NAME = 'Learning'
	         THEN 'LD'
	     WHEN CLASSIFICATION.NAME = 'Hearing' 
	         THEN 'HEAR'    
	     WHEN CLASSIFICATION.NAME = 'Vision' 
	         THEN 'VIS' 
	     WHEN CLASSIFICATION.NAME = 'Behaviour' 
	         THEN 'BEH' 
	     WHEN CLASSIFICATION.NAME = 'Consciousness' 
	         THEN 'CON' 
	     WHEN CLASSIFICATION.NAME = 'Diagnosed autism/aspergers' 
	             OR CLASSIFICATION.NAME = 'Autistic Spectrum Disorder'
	             OR CLASSIFICATION.NAME = 'Autism spectrum condition'
	         THEN 'AUT' 
	         ELSE 'DDA'   
	END                             AS "disa_disability_code" --metadata={"item_ref:"DISA002A"}
	
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.STATUS NOT IN ('DELETED')
	AND CLA.CLASSIFICATIONPATHID IN (55, 58, 79, 172,186)
	AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;



-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_disability ADD CONSTRAINT FK_ssd_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_disability_person_id  ON ssd_development.ssd_disability(disa_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_disability_code       ON ssd_development.ssd_disability(disa_disability_code);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_immigration_status"}
-- =============================================================================
-- Description: (UASC)
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_immigration_status') IS NOT NULL DROP TABLE ssd_development.ssd_immigration_status;
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_immigration_status (
    immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
    immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
    immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
    immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
    immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)



SELECT
	CLA.PERSONID                   AS "immi_person_id",                     --metadata={"item_ref:"IMMI001A"}
	CLA.CLASSIFICATIONASSIGNMENTID AS "immi_Immigration_status_id",         --metadata={"item_ref:"IMMI005A"}
	CLASSIFICATION.NAME            AS "immi_immigration_status",            --metadata={"item_ref:"IMMI002A"}
	CLA.STARTDATE                  AS "immi_immigration_status_start_date", --metadata={"item_ref:"IMMI003A"}
	CLA.ENDDATE                    AS "immi_immigration_status_end_date"    --metadata={"item_ref:"IMMI004A"}
 
FROM CLASSIFICATIONPERSONVIEW CLA
LEFT JOIN CLASSIFICATION ON CLASSIFICATION.ID = CLA.CLASSIFICATIONCODEID
WHERE CLA.CLASSIFICATIONPATHID IN (1, 83)
    AND CLA.STATUS NOT IN ('DELETED')
    AND CLA.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
   ;




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_immigration_status ADD CONSTRAINT FK_ssd_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_immi_person_id ON ssd_development.ssd_immigration_status(immi_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_start          ON ssd_development.ssd_immigration_status(immi_immigration_status_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_immigration_status_end            ON ssd_development.ssd_immigration_status(immi_immigration_status_end_date);

-- META-END






-- META-CONTAINER: {"type": "table", "name": "ssd_cin_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - @ssd_timeframe_years
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_cin_episodes;
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(4000), -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team              NVARCHAR(48),   -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
); 


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_episodes
(
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
	CIN_EPISODE.CINE_REFERRAL_ID                                                                    AS "cine_referral_id",             -- metadata={"item_ref":"CINE001A"}
	CIN_EPISODE.CINE_PERSON_ID                                                                      AS "cine_person_id",               -- metadata={"item_ref":"CINE002A"}
	CIN_EPISODE.CINE_REFERRAL_DATE                                                                  AS "cine_referral_date",           -- metadata={"item_ref":"CINE003A"}
	REFERRAL.PRIMARY_NEED_RANK                                                                      AS "cine_cin_primary_need_code",   -- metadata={"item_ref":"CINE010A"}
	CASE WHEN REFERRAL.REFERRAL_SOURCE = 'Acquaintance'                               THEN '1B'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'A & E'                                      THEN '3E'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Anonymous'                                  THEN '9'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Early help'                                 THEN '5D'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Education Services'                         THEN '2B'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'External e.g. from another local authority' THEN '5C'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Family Member/Relative/Carer'               THEN '1A'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'GP'                                         THEN '3A'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Health Visitor'                             THEN '3B'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Housing'                                    THEN '4'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other'                                      THEN '1D'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other Health Services'                      THEN '3F'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other - including children centres'         THEN '8'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other internal e,g, BC Council'             THEN '5B'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other Legal Agency'                         THEN '7'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Other Primary Health Services'              THEN '3D'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Police'                                     THEN '6'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'School'                                     THEN '2A'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'School Nurse'                               THEN '3C'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Self'                                       THEN '1C'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Social care e.g. adult social care'         THEN '5A'
	     WHEN REFERRAL.REFERRAL_SOURCE = 'Unknown'                                    THEN '10'
	END                                                                                           AS "cine_referral_source_code",       -- metadata={"item_ref":"CINE004A"}  
	REFERRAL.REFERRAL_SOURCE                                                                      AS "cine_referral_source_desc",       -- metadata={"item_ref":"CINE012A"}
	JSON_BUILD_OBJECT( 
	'OUTCOME_SINGLE_ASSESSMENT_FLAG',  CASE WHEN REFERRAL.NEXT_STEP IN ('Assessment','Family Help Discussion (10 days)','Family Help Discussion (CAT) -10 days','Family Help Discussion (DCYP)- 10 days')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_NFA_FLAG',                CASE WHEN REFERRAL.NEXT_STEP IN ('No further action','Signpost')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_STRATEGY_DISCUSSION_FLAG',CASE WHEN REFERRAL.NEXT_STEP = 'Strategy Discussion/Meeting'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CLA_REQUEST_FLAG', 'N',
	'OUTCOME_NON_AGENCY_ADOPTION_FLAG',CASE WHEN REFERRAL.NEXT_STEP = 'Adoption or Special Guardianship support'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_PRIVATE_FOSTERING_FLAG',  CASE WHEN REFERRAL.NEXT_STEP = 'Private Fostering'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CP_TRANSFER_IN_FLAG',     CASE WHEN REFERRAL.NEXT_STEP = 'Transfer in child protection conference'
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END,
	'OUTCOME_CP_CONFERENCE_FLAG',      'N',
	'OUTCOME_CARE_LEAVER_FLAG',        'N',
	'OTHER_OUTCOMES_EXIST_FLAG',       CASE WHEN REFERRAL.NEXT_STEP IN ('Asylum seeker','Court Report Request Section 7/Section 37','Disabled children service',
                                                                   'No recourse to public funds','Family Help Discussion(45 Day)','Family Help Discussion (45 days)',
                                                                   'Early Intervention','Universal Services')
	                                        THEN 'Y'
	                                        ELSE 'N'
	                                   END)                                                    	AS "cine_referral_outcome_json", --metadata={"item_ref:"CINE005A"}
	CASE WHEN REFERRAL.NEXT_STEP = 'No further action'
	     THEN 'Y'
	     ELSE 'N'
	END                                                                                         AS "cine_referral_nfa",          -- metadata={"item_ref":"CINE011A"} 
	CASE WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Service ceased for any other reason'                   THEN 'RC7'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Category of registration changed'                      THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Sustained progress achieved'                           THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Child subject to a full Care Order'                    THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Transferred to OLA'                                    THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Case closed after assessment, referred to EH'          THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Adopted'                                               THEN 'RC1'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'No Longer Applies'                                     THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Child moved permanently from area'                     THEN 'RC5'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Transferred to Adult Services'                         THEN 'RC6'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Special Guardianship Order'                            THEN 'RC4'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Child Arrangements Order'                              THEN 'RC3'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Died'                                                  THEN 'RC2'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Young person reached the age of 18'                    THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Child/young person has died'                           THEN 'RC2'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Case closed after assessment, no further action'       THEN 'RC8'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Consent withdrawn prior to, or at initial visit '      THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Risk assessment completed'                             THEN ''
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Case closed after assessment, referred to early help'  THEN 'RC9'
	     WHEN CIN_EPISODE.CINE_CLOSE_REASON = 'Child deemed not to be in need after referral'         THEN 'RC7'
	END                                                                                          AS "cine_close_reason",        -- metadata={"item_ref":"CINE006A"}
	CIN_EPISODE.CINE_CLOSE_REASON, 
	CIN_EPISODE.CINE_CLOSE_DATE                                                                  AS "cine_close_date",          -- metadata={"item_ref":"CINE007A"}
	--TEAM.ORGANISATIONID                                                                          AS "cine_referral_team",
	NULL                                                                                         AS "cine_referral_team",       -- metadata={"item_ref":"CINE008A"}   
	REFERRAL.SUBMITTERPERSONID                                                                   AS "cine_referral_worker_id"   -- metadata={"item_ref":"CINE009A"}
    
FROM CIN_EPISODE	
LEFT JOIN REFERRAL ON REFERRAL.PERSONID = CIN_EPISODE.CINE_PERSON_ID 
         AND REFERRAL.DATE_OF_REFERRAL = CIN_EPISODE.CINE_REFERRAL_DATE
        ;

    


-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_episodes_person_id    ON ssd_development.ssd_cin_episodes(cine_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cin_referral_date             ON ssd_development.ssd_cin_episodes(cine_referral_date);
CREATE NONCLUSTERED INDEX idx_ssd_cin_close_date                ON ssd_development.ssd_cin_episodes(cine_close_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_mother"}
-- =============================================================================
-- Description: Contains parent-child relations between mother-child 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_mother;
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_mother (
    moth_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)


SELECT
	PPR.PERSONRELATIONSHIPRECORDID               AS "moth_table_id", --metadata={"item_ref:"MOTH004A"}
	PPR.ROLEAPERSONID                            AS "moth_person_id", --metadata={"item_ref:"MOTH002A"}
	PPR.ROLEBPERSONID                            AS "moth_childs_person_id", --metadata={"item_ref:"MOTH001A"}
	PDV.DATEOFBIRTH                              AS "moth_childs_dob" --metadata={"item_ref:"MOTH003A"}

FROM RELATIONSHIPPERSONVIEW PPR
LEFT JOIN PERSONDEMOGRAPHICSVIEW PDV ON PDV.PERSONID = PPR.ROLEBPERSONID
WHERE PPR.RELATIONSHIP = 'Mother'
    AND PPR.ROLEAPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    AND PPR.ROLEBPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
   
    ;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_mother ADD CONSTRAINT FK_ssd_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_mother_moth_person_id ON ssd_development.ssd_mother(moth_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_person_id ON ssd_development.ssd_mother(moth_childs_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_dob ON ssd_development.ssd_mother(moth_childs_dob);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_legal_status"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_legal_status') IS NOT NULL DROP TABLE ssd_development.ssd_legal_status;
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_legal_status (
    lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"LEGA001A"}
    lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
    lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
    lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
    lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)

SELECT
	LS_START.EPISODEOFCAREID AS "lega_legal_status_id",          --metadata={"item_ref:"LEGA001A"}
	EPIS.PERSONID            AS "lega_person_id",                --metadata={"item_ref:"LEGA002A"}
	EPIS.LEGALSTATUS         AS "lega_legal_status",             --metadata={"item_ref:"LEGA003A"}
	EPIS.EOCSTARTDATE        AS "lega_legal_status_start_date",  --metadata={"item_ref:"LEGA004A"}
	EPIS.EOCENDDATE          AS "lega_legal_status_end_date"     --metadata={"item_ref:"LEGA005A"}

FROM (
    SELECT
	    PERSONID,
	    LEGALSTATUS,
	    MIN(EPIS.EOCSTARTDATE)   AS EOCSTARTDATE,
	    CASE
		    WHEN BOOL_AND(EPIS.EOCENDDATE IS NOT NULL) IS FALSE
			THEN NULL
			ELSE MAX(EPIS.EOCENDDATE)
	    END   EOCENDDATE	
    FROM (		
        SELECT
            *,
            SUM(START_FLAG) OVER (PARTITION BY PERSONID ORDER BY PERSONID, EOCSTARTDATE) AS GRP 
        FROM (   
            SELECT 
                *,
                CASE
			    WHEN EOCSTARTDATE BETWEEN
				    	LAG(EOCSTARTDATE) OVER (PARTITION BY PERSONID, LEGALSTATUS ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST) 
				    	AND COALESCE(LAG(EOCENDDATE) OVER (PARTITION BY PERSONID, LEGALSTATUS ORDER BY EOCSTARTDATE, EOCENDDATE NULLS LAST),CURRENT_DATE) + INTERVAL '1 day'
				    THEN 0
				    ELSE 1
			    END START_FLAG
                 FROM EPISODES EPIS
              ) EPIS
          
         ) EPIS
    GROUP BY EPIS.PERSONID,EPIS.LEGALSTATUS --,LS_START.EPISODEOFCAREID
)EPIS

LEFT JOIN LATERAL (
          SELECT
              *
          FROM EPISODES
          WHERE EPISODES.PERSONID = EPIS.PERSONID
            AND EPISODES.LEGALSTATUS = EPIS.LEGALSTATUS
            AND EPISODES.EOCSTARTDATE = EPIS.EOCSTARTDATE
          ORDER BY EPISODES.EOCSTARTDATE  
          FETCH FIRST 1 ROW ONLY ) LS_START ON TRUE
;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_legal_status ADD CONSTRAINT FK_ssd_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_lega_person_id   ON ssd_development.ssd_legal_status(lega_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status                  ON ssd_development.ssd_legal_status(lega_legal_status);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_start            ON ssd_development.ssd_legal_status(lega_legal_status_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_end              ON ssd_development.ssd_legal_status(lega_legal_status_end_date);
-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_contacts"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:Inclusion in contacts might differ between LAs. 
--         Baseline definition:
--         Contains safeguarding and referral to early help data.
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_contacts') IS NOT NULL DROP TABLE ssd_development.ssd_contacts;
IF OBJECT_ID('tempdb..#ssd_contacts') IS NOT NULL DROP TABLE #ssd_contacts;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_contacts (
    cont_contact_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CONT001A"}
    cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
    cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
    cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
    cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
    cont_contact_outcome_json       NVARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)


SELECT
    FAPV.INSTANCEID             AS "cont_contact_id",   --metadata={"item_ref:"CONT001A"}
	FAPV.PERSONID               AS "cont_person_id",    --metadata={"item_ref:"CONT002A"}
	FAPV.CONTACT_DATE           AS "cont_contact_date", --metadata={"item_ref:"CONT003A"}
	CASE WHEN FAPV.CONTACT_BY = 'Acquaintance'                               THEN 'INDACQ'
	     WHEN FAPV.CONTACT_BY = 'A & E'                                      THEN 'HSERVAE'
	     WHEN FAPV.CONTACT_BY = 'Anonymous'                                  THEN 'ANON'
	     WHEN FAPV.CONTACT_BY = 'Education Services'                         THEN 'EDUSERV'
	     WHEN FAPV.CONTACT_BY = 'External e.g. from another local authority' THEN 'LASERVEXT'
	     WHEN FAPV.CONTACT_BY = 'Family Member/Relative/Carer'               THEN 'INDFRC'
	     WHEN FAPV.CONTACT_BY = 'GP'                                         THEN 'HSERVGP'
	     WHEN FAPV.CONTACT_BY = 'Health Visitor'                             THEN 'HSERVHVSTR'
	     WHEN FAPV.CONTACT_BY = 'Housing'                                    THEN 'HOUSLA'
	     WHEN FAPV.CONTACT_BY = 'Other'                                      THEN 'OTHER'
	     WHEN FAPV.CONTACT_BY = 'Other Health Services'                      THEN 'HSERVOTHR'
	     WHEN FAPV.CONTACT_BY = 'Other - including children centres'         THEN 'OTHER'
	     WHEN FAPV.CONTACT_BY = 'Other internal e,g, BC Council'             THEN 'LASERVOINT'
	     WHEN FAPV.CONTACT_BY = 'Other Legal Agency'                         THEN 'OTHERLEG'
	     WHEN FAPV.CONTACT_BY = 'Other Primary Health Services'              THEN 'HSERVPHSERV'
	     WHEN FAPV.CONTACT_BY = 'Police'                                     THEN 'POLICE'
	     WHEN FAPV.CONTACT_BY = 'School'                                     THEN 'SCHOOLS'
	     WHEN FAPV.CONTACT_BY = 'School Nurse'                               THEN 'HSERVSNRSE'
	     WHEN FAPV.CONTACT_BY = 'Self'                                       THEN 'INDSELF'
	     WHEN FAPV.CONTACT_BY = 'Social care e.g. adult social care'         THEN 'LASERVSCR'
	     WHEN FAPV.CONTACT_BY = 'Unknown'                                    THEN 'UNKNOWN'
	END                          AS "cont_contact_source_code", --metadata={"item_ref:"CONT004A"}
	FAPV.CONTACT_BY              AS "cont_contact_source_desc", --metadata={"item_ref:"CONT006A"}
	NULL                         AS "cont_contact_outcome_json" --metadata={"item_ref:"CONT005A"}
	
FROM (
    SELECT
	    FAPV.INSTANCEID, 
	    FAPV.ANSWERFORSUBJECTID AS PERSONID,
	    MAX(CASE
		      WHEN FAPV.CONTROLNAME = 'icContactDate'
		      THEN FAPV.ANSWERVALUE
	    END)::DATE              AS CONTACT_DATE, 
	    MAX(CASE
		      WHEN FAPV.CONTROLNAME = 'icContactBy'
		      THEN FAPV.ANSWERVALUE
	    END)                    AS CONTACT_BY 
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('8fae4e1f-344b-4c08-93ba-8b344513198c') --MASH summary and outcome
           AND FAPV.INSTANCESTATE = 'COMPLETE'
           AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.INSTANCEID, 
	         FAPV.ANSWERFORSUBJECTID
	           
) FAPV	
;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_contacts ADD CONSTRAINT FK_ssd_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_contact_person_id     ON ssd_development.ssd_contacts(cont_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_contact_date          ON ssd_development.ssd_contacts(cont_contact_date);
CREATE NONCLUSTERED INDEX idx_ssd_contact_source_code   ON ssd_development.ssd_contacts(cont_contact_source_code);




-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_early_help_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_early_help_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_early_help_episodes;
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_early_help_episodes (
    earl_episode_id             NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EARL001A"}
    earl_person_id              NVARCHAR(48),               -- metadata={"item_ref":"EARL002A"}
    earl_episode_start_date     DATETIME,                   -- metadata={"item_ref":"EARL003A"}
    earl_episode_end_date       DATETIME,                   -- metadata={"item_ref":"EARL004A"}
    earl_episode_reason         NVARCHAR(MAX),              -- metadata={"item_ref":"EARL005A"}
    earl_episode_end_reason     NVARCHAR(MAX),              -- metadata={"item_ref":"EARL006A"}
    earl_episode_organisation   NVARCHAR(MAX),              -- metadata={"item_ref":"EARL007A"}
    earl_episode_worker_id      NVARCHAR(100)               -- metadata={"item_ref":"EARL008A", "item_status": "A", "info":"Consider for removal"}
);
 
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_early_help_episodes (
    earl_episode_id,
    earl_person_id,
    earl_episode_start_date,
    earl_episode_end_date,
    earl_episode_reason,
    earl_episode_end_reason,
    earl_episode_organisation,
    earl_episode_worker_id                    
)
 
SELECT
	EH_EPISODE.EH_REFERRAL_ID   AS "earl_episode_id",           --metadata={"item_ref:"EARL001A"}
	EH_EPISODE.PERSONID         AS "earl_person_id",            --metadata={"item_ref:"EARL002A"}
	EH_EPISODE.EH_REFERRAL_DATE AS "earl_episode_start_date",   --metadata={"item_ref:"EARL003A"}
	EH_EPISODE.EH_CLOSE_DATE    AS "earl_episode_end_date",     --metadata={"item_ref:"EARL004A"}
	REFERRAL.PRIMARY_NEED_CAT   AS "earl_episode_reason",       --metadata={"item_ref:"EARL005A"}
	CLOSURE.REASON              AS "earl_episode_end_reason",   --metadata={"item_ref:"EARL006A"}
	TEAM.ALLOCATED_TEAM         AS "earl_episode_organisation", --metadata={"item_ref:"EARL007A"}
	WORKER.ALLOCATED_WORKER     AS "earl_episode_worker_id"   --metadata={"item_ref:"EARL008A"}

FROM EH_EPISODE
LEFT JOIN CLOSURE ON CLOSURE.PERSONID = EH_EPISODE.PERSONID AND
                     (CLOSURE.COMPLETED_DATE = EH_EPISODE.EH_CLOSE_DATE OR CLOSURE.CLOSURE_DATE = EH_EPISODE.EH_CLOSE_DATE) 
LEFT JOIN LATERAL (
               SELECT
                   *
               FROM REFERRAL
               WHERE REFERRAL.PERSONID = EH_EPISODE.PERSONID
                 AND REFERRAL.DATE_OF_REFERRAL <= EH_EPISODE.EH_REFERRAL_DATE
               ORDER BY REFERRAL.DATE_OF_REFERRAL DESC 
               FETCH FIRST 1 ROW ONLY) REFERRAL ON TRUE
LEFT JOIN WORKER ON WORKER.PERSONID = EH_EPISODE.PERSONID
                         AND EH_EPISODE.EH_CLOSE_DATE > WORKER.WORKER_START_DATE
                         AND EH_EPISODE.EH_REFERRAL_DATE < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = EH_EPISODE.PERSONID 
                         AND EH_EPISODE.EH_CLOSE_DATE >= TEAM.TEAM_START_DATE
                         AND EH_EPISODE.EH_REFERRAL_DATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         

;




-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_early_help_episodes ADD CONSTRAINT FK_ssd_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_early_help_episodes_person_id     ON ssd_development.ssd_early_help_episodes(earl_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_early_help_start_date             ON ssd_development.ssd_early_help_episodes(earl_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_early_help_end_date               ON ssd_development.ssd_early_help_episodes(earl_episode_end_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cin_assessments"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_development.ssd_cin_assessments;
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_assessments
(
    cina_assessment_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINA001A"}
    cina_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
    cina_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
    cina_assessment_start_date      DATETIME,                   -- metadata={"item_ref":"CINA003A"}
    cina_assessment_child_seen      NCHAR(1),                   -- metadata={"item_ref":"CINA004A"}
    cina_assessment_auth_date       DATETIME,                   -- metadata={"item_ref":"CINA005A"}             
    cina_assessment_outcome_json    NVARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
    cina_assessment_outcome_nfa     NCHAR(1),                   -- metadata={"item_ref":"CINA009A"}
    cina_assessment_team            NVARCHAR(48),               -- metadata={"item_ref":"CINA007A"}
    cina_assessment_worker_id       NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
);


 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_assessments
(
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date,      
    cina_assessment_outcome_json,
    cina_assessment_outcome_nfa,
    cina_assessment_team,
    cina_assessment_worker_id
)


SELECT 
 	CONCAT(ASSESSMENT.PERSONID, ASSESSMENT.CINA_ASSESSMENT_ID) AS "cina_assessment_id",                -- metadata={"item_ref":"CINA001A"}
	ASSESSMENT.PERSONID                                        AS "cina_person_id",                    -- metadata={"item_ref":"CINA002A"}
	CIN_EPISODE.REFERRALID                                     AS "cina_referral_id",                  -- metadata={"item_ref":"CINA010A"}
	ASSESSMENT.CINA_ASSESSMENT_START_DATE                      AS "cina_assessment_start_date",        -- metadata={"item_ref":"CINA003A"}
	ASSESSMENT.CINA_ASSESSMENT_CHILD_SEEN                      AS "cina_assessment_child_seen",        -- metadata={"item_ref":"CINA004A"}
	ASSESSMENT.CINA_ASSESSMENT_AUTH_DATE                       AS "cina_assessment_auth_date",         -- metadata={"item_ref":"CINA005A"}
	JSON_BUILD_OBJECT(
	 'OUTCOME_NFA_FLAG',                      CASE WHEN ASSESSMENT.OUTCOME IN ('Case Closure','Step down to Universal Services/Signposting',
	                                                                           'Advice, Guidance and signposting','Case Closure', 'Transfer to Early Support Plan')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_NFA_S47_END_FLAG',              'N',
	 'OUTCOME_STRATEGY_DISCUSSION_FLAG',      CASE WHEN ASSESSMENT.OUTCOME IN ('Progress to Child Protection','Recommend/Progress to Strategy discussion')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,     
	 'OUTCOME_CLA_REQUEST_FLAG',              CASE WHEN ASSESSMENT.OUTCOME IN ('Recommend Child looked after planning', 'Privately fostered child',
	                                                                           'Recommend Children and Young People in Care planning')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_PRIVATE_FOSTERING_FLAG',        CASE WHEN ASSESSMENT.OUTCOME IN ('Privately fostered child not deemed to be child in need')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_LEGAL_ACTION_FLAG',             'N',
	 'OUTCOME_PROV_OF_SERVICES_FLAG',         CASE WHEN ASSESSMENT.OUTCOME IN ('Recommend Child in Need planning', 'Continue with existing plan',
	                                                                           'Recommend Disabled Children and Young People', 'Recommend Family Help SEND Service',
	                                                                           'Recommend/Progress to Family Help Discussion')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'OUTCOME_PROV_OF_SB_CARE_FLAG',          CASE WHEN ASSESSMENT.OUTCOME IN ('Short Break (Child in need)')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,     
	 'OUTCOME_SPECIALIST_ASSESSMENT_FLAG',    'N',
	 'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', 'N',
	 'OUTCOME_OTHER_ACTIONS_FLAG',            'N',
	 'OTHER_OUTCOMES_EXIST_FLAG',             CASE WHEN ASSESSMENT.OUTCOME IN ('Refer to Early Intervention','Transfer (CIN / CP / CLA)')
	                                               THEN 'Y'
	                                               ELSE 'N'
	                                          END,
	 'TOTAL_NO_OF_OUTCOMES',                  ''   )           AS "cina_assessment_outcome_json", --metadata={"item_ref:"CINA006A"}
	CASE WHEN ASSESSMENT.OUTCOME IN ('Case Closure','Step down to Universal Services/Signposting',
	                                 'Advice, Guidance and signposting','Case Closure', 'Transfer to Early Support Plan')
	     THEN 'Y'
	     ELSE 'N'
	END                                                        AS "cina_assessment_outcome_nfa", --metadata={"item_ref:"CINA009A"}
	TEAM.ALLOCATED_TEAM                                        AS "cina_assessment_team",        -- metadata={"item_ref":"CINA007A"}
	WORKER.ALLOCATED_WORKER                                    AS "cina_assessment_worker_id"    -- metadata={"item_ref":"CINA008A"}
FROM ASSESSMENT 

LEFT JOIN LATERAL 
           (SELECT
               *
            FROM CIN_EPISODE 
            WHERE ASSESSMENT.PERSONID =  CIN_EPISODE.PERSONID
              AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= CIN_EPISODE.DATE_OF_REFERRAL
            ORDER BY  CIN_EPISODE.DATE_OF_REFERRAL DESC 
            FETCH FIRST 1 ROW ONLY) CIN_EPISODE ON TRUE 
LEFT JOIN WORKER ON WORKER.PERSONID = ASSESSMENT.PERSONID 
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= WORKER.WORKER_START_DATE
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < WORKER.WORKER_END_DATE
LEFT JOIN TEAM ON TEAM.PERSONID = ASSESSMENT.PERSONID 
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE >= TEAM.TEAM_START_DATE
                         AND ASSESSMENT.CINA_ASSESSMENT_START_DATE < TEAM.TEAM_END_DATE
;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_assessments_person_id     ON ssd_development.ssd_cin_assessments(cina_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cina_assessment_start_date    ON ssd_development.ssd_cin_assessments(cina_assessment_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cina_assessment_auth_date     ON ssd_development.ssd_cin_assessments(cina_assessment_auth_date);
CREATE NONCLUSTERED INDEX idx_ssd_cina_referral_id              ON ssd_development.ssd_cin_assessments(cina_referral_id);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_assessment_factors"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: This object referrences some large source tables- Instances of 45m+. 
-- Dependencies: 
-- - 
-- - ssd_cin_assessments
-- -
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_assessment_factors') IS NOT NULL DROP TABLE ssd_development.ssd_assessment_factors;
IF OBJECT_ID('tempdb..#ssd_assessment_factors') IS NOT NULL DROP TABLE #ssd_assessment_factors;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_assessment_factors (
    cinf_table_id                   NVARCHAR(48) PRIMARY KEY,                   -- metadata={"item_ref":"CINF003A"}
    cinf_assessment_id              NVARCHAR(48),                   -- metadata={"item_ref":"CINF001A"}
    cinf_assessment_factors_json    NVARCHAR(1000)                  -- metadata={"item_ref":"CINF002A"}
);

-- Create TMP structure with filtered answers
SELECT 
    ffa.FACT_FORM_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
INTO #ssd_TMP_PRE_assessment_factors
FROM 
    HDM.Child_Social.FACT_FORM_ANSWERS ffa
WHERE 
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC = 'FAMILY ASSESSMENT'
    AND ffa.ANSWER_NO IN (  '1A', '1B', '1C'
                            ,'2A', '2B', '2C', '3A', '3B', '3C'
                            ,'4A', '4B', '4C'
                            ,'5A', '5B', '5C'
                            ,'6A', '6B', '6C'
                            ,'7A'
                            ,'8B', '8C', '8D', '8E', '8F'
                            ,'9A', '10A', '11A','12A', '13A', '14A', '15A', '16A', '17A'
                            ,'18A', '18B', '18C'
                            ,'19A', '19B', '19C'
                            ,'20', '21'
                            ,'22A', '23A', '24A')
    -- filters:                        
    AND LOWER(ffa.ANSWER) = 'yes'   -- expected [Yes/No/NULL], adds redundancy into resultant field but allows later expansion
    AND ffa.FACT_FORM_ID <> -1;     -- possible admin data present


-- META-ELEMENT: {"type": "insert_data"} 
-- into the final table
INSERT INTO ssd_development.ssd_assessment_factors (
               cinf_table_id, 
               cinf_assessment_id, 
               cinf_assessment_factors_json
           )


-- -- Opt1: (current implementation for backward compatibility)
-- -- create field structure of flattened Key only json-like array structure 
-- -- ["1A","2B","3A", ...]           
SELECT
	CONCAT(NEF.PERSONID, NEF.INSTANCEID)                AS "cinf_table_id", --metadata={"item_ref:"CINF003A"}
	NEF.INSTANCEID                                      AS "cinf_assessment_id", --metadata={"item_ref:"CINF001A"}
	JSON_ARRAY(
	    CASE WHEN NEF.ALCOHOL_CHILD IS NOT NULL THEN '1A' END,
		CASE WHEN NEF.ALCOHOL_PARENT IS NOT NULL THEN '1B' END,
		CASE WHEN NEF.ALCOHOL_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '1C' END,
		CASE WHEN NEF.DRUG_CHILD IS NOT NULL THEN '2A' END,
		CASE WHEN NEF.DRUG_PARENT IS NOT NULL THEN '2B' END,
		CASE WHEN NEF.DRUG_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '2C' END,
		CASE WHEN NEF.DOMESTIC_CHILD IS NOT NULL THEN '3A' END,
		CASE WHEN NEF.DOMESTIC_PARENT IS NOT NULL THEN '3B' END,
		CASE WHEN NEF.DOMESTIC_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '3C' END,
		CASE WHEN NEF.MENTAL_HEALTH_CHILD IS NOT NULL THEN '4A' END,
		CASE WHEN NEF.MENTAL_HEALTH_PARENT IS NOT NULL THEN '4B' END,
		CASE WHEN NEF.MENTAL_HEALTH_OTHER_PERSON IS NOT NULL THEN '4C' END,
		CASE WHEN NEF.LEARN_DIS_CHILD IS NOT NULL THEN '5A' END,
		CASE WHEN NEF.LEARN_DIS_PARENT IS NOT NULL THEN '5B' END,
		CASE WHEN NEF.LEARN_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '5C' END,
		CASE WHEN NEF.PHYS_DIS_CHILD IS NOT NULL THEN '6A' END,
		CASE WHEN NEF.PHYS_DIS_PARENT IS NOT NULL THEN '6B' END,
		CASE WHEN NEF.PHYS_DIS_OTHER_PERSON_HOUSEHOLD IS NOT NULL THEN '6C' END,
	    CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%YCarer%' THEN '7A' END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOther%'
			AND NEF.CHILD_SPECIFIC_FACTOR LIKE '%Privately fostered - Other%'
				THEN '8F' 
		END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFUKFamily%' THEN '8E' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFUKEducation%' THEN '8D' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOCIntendtostay%' THEN '8C' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PFOCIntendtoreturn%' THEN '8B' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%UASC%' THEN '9A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Miss%' THEN '10A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexExploit%' THEN '11A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Traffic%' THEN '12A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Gang%' THEN '13A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Behave%' THEN '14A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SHarm%' THEN '15A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%AbuseNeglect%' THEN '16A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%EmotAbuse%' THEN '17A' END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PhysAbuse%' 
			AND NEF.ALLEGED_PERP_PHYS_ABUSE LIKE '%18B%' 
				THEN '18B' 
		END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%PhysAbuse%' 
			AND NEF.ALLEGED_PERP_PHYS_ABUSE LIKE '%18C%' 
				THEN '18C' 
		END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexAbuse%' 
			AND NEF.ALLEGED_PERP_SEXUAL_ABUSE LIKE '%19B%' 
				THEN '19B' 
		END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%SexAbuse%' 
			AND NEF.ALLEGED_PERP_SEXUAL_ABUSE LIKE '%19C%' 
			THEN '19C' 
		END,
		CASE 
			WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Other%'
			--There is one instance of this happening where both have been selected in the entirety of Eclipse (16/06/2022 - 13:57)
			AND NEF.CHILD_SPECIFIC_FACTOR NOT LIKE '%Privately fostered - Other%'
				THEN '20' 
		END,
		CASE
			WHEN NEF.ALCOHOL_CHILD IS NULL AND NEF.ALCOHOL_OTHER_PERSON_HOUSEHOLD IS NULL AND NEF.ALCOHOL_PARENT IS NULL AND NEF.CHILD_SPECIFIC_FACTOR IS NULL AND 
			NEF.DOMESTIC_CHILD IS NULL AND NEF.DOMESTIC_OTHER_PERSON_HOUSEHOLD IS NULL AND NEF.DOMESTIC_PARENT IS NULL AND NEF.DRUG_CHILD IS NULL AND 
			NEF.DRUG_OTHER_PERSON_HOUSEHOLD IS NULL AND NEF.DRUG_PARENT IS NULL AND NEF.LEARN_DIS_CHILD IS NULL AND NEF.LEARN_DIS_OTHER_PERSON_HOUSEHOLD IS NULL AND 
			NEF.LEARN_DIS_PARENT IS NULL AND NEF.MENTAL_HEALTH_CHILD IS NULL AND NEF.MENTAL_HEALTH_OTHER_PERSON IS NULL AND NEF.MENTAL_HEALTH_PARENT IS NULL AND 
			NEF.PHYS_DIS_CHILD IS NULL AND NEF.PHYS_DIS_OTHER_PERSON_HOUSEHOLD IS NULL AND NEF.PHYS_DIS_PARENT IS NULL
			THEN '21'
		END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%FGM%' THEN '22A' END,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%Faith%' THEN '23A' END ,
		CASE WHEN NEF.CHILD_SPECIFIC_FACTOR_SHORT LIKE '%RAD%' THEN '24A' END
 	    
	)	                                                 AS  "cinf_assessment_factors_json" --metadata={"item_ref:"CINF002A"}
	
FROM (
	SELECT DISTINCT
		FAPV.ANSWERFORSUBJECTID PERSONID,
		FAPV.INSTANCEID,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholChild') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS ALCOHOL_CHILD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholOtherPersonHousehold') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS ALCOHOL_OTHER_PERSON_HOUSEHOLD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_alcoholParent') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS ALCOHOL_PARENT,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticChild') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DOMESTIC_CHILD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticOtherPersonHousehold') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DOMESTIC_OTHER_PERSON_HOUSEHOLD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_domesticParent') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DOMESTIC_PARENT,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_drugChild') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DRUG_CHILD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_drugOtherPersonHousehold') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DRUG_OTHER_PERSON_HOUSEHOLD,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_drugParent')
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS DRUG_PARENT,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisChild') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END)													 AS LEARN_DIS_CHILD,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisOtherPersonHousehold') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS LEARN_DIS_OTHER_PERSON_HOUSEHOLD,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_learnDisParent') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS LEARN_DIS_PARENT,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthChild')
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS MENTAL_HEALTH_CHILD,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthOtherPerson') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS MENTAL_HEALTH_OTHER_PERSON,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_mentalHealthParent') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS MENTAL_HEALTH_PARENT,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisChild') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS PHYS_DIS_CHILD,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisOtherPersonHousehold') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS PHYS_DIS_OTHER_PERSON_HOUSEHOLD,
		MAX(CASE
			WHEN FAPV.CONTROLNAME IN ('CINCensus_physDisParent') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS PHYS_DIS_PARENT,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_childSpecificFactor') 
				THEN FAPV.ANSWERVALUE 
			ELSE NULL 
		END) 													AS CHILD_SPECIFIC_FACTOR,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_childSpecificFactor') 
				THEN FAPV.SHORTANSWERVALUE 
			ELSE NULL 
		END) 													AS CHILD_SPECIFIC_FACTOR_SHORT,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_allegedPerpetratorOfSexualAbuse') 
				THEN FAPV.SHORTANSWERVALUE 
			ELSE NULL 
		END) 													AS ALLEGED_PERP_SEXUAL_ABUSE,
		MAX(CASE 
			WHEN FAPV.CONTROLNAME IN ('CINCensus_allegedPerpetratorOfPhysicalAbuse') 
				THEN FAPV.SHORTANSWERVALUE 
			ELSE NULL 
		END) 													AS ALLEGED_PERP_PHYS_ABUSE
	FROM FORMANSWERPERSONVIEW FAPV
	-- Child: Assessment
	WHERE FAPV.DESIGNGUID = '94b3f530-a918-4f33-85c2-0ae355c9c2fd'
		AND FAPV.INSTANCESTATE  IN ('COMPLETE')
		AND FAPV.CONTROLNAME IN ('advocacyOffered','WorkerOutcome','AnnexAReturn_typeOfAssessment','WorkerOutcome','CINCensus_startDateOfForm',
								'CINCensus_alcoholChild','CINCensus_alcoholOtherPersonHousehold','CINCensus_alcoholParent',
								'CINCensus_childSpecificFactor',
								'CINCensus_domesticChild','CINCensus_domesticOtherPersonHousehold','CINCensus_domesticParent',
								'CINCensus_drugChild','CINCensus_drugOtherPersonHousehold','CINCensus_drugParent',
								'CINCensus_learnDisChild','CINCensus_learnDisOtherPersonHousehold','CINCensus_learnDisParent',
								'CINCensus_mentalHealthChild','CINCensus_mentalHealthOtherPerson','CINCensus_mentalHealthParent',
								'CINCensus_physDisChild','CINCensus_physDisOtherPersonHousehold','CINCensus_physDisParent','advocacyAccepted',
								'CINCensus_allegedPerpetratorOfSexualAbuse','CINCensus_allegedPerpetratorOfPhysicalAbuse')
		AND COALESCE(FAPV.DESIGNSUBNAME,'?') NOT IN (
				--Trailing spaces, just to be safe.
				'CLA report for review 20 days ','CLA report for review 20 days',
				'CLA report for review 3 Months',
				'CLA report for review 6 months ','CLA report for review 6 months'
			)
		AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)	
	GROUP BY FAPV.ANSWERFORSUBJECTID, FAPV.INSTANCEID, FAPV.DATESTARTED, FAPV.DATECOMPLETED
) NEF



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_assessment_factors ADD CONSTRAINT FK_ssd_cinf_assessment_id
FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_development.ssd_cin_assessments(cina_assessment_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cinf_assessment_id ON ssd_development.ssd_assessment_factors(cinf_assessment_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cin_plans"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cin_plans;
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team          NVARCHAR(48),               -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)

SELECT
    CIN_PLAN.CLAID                      AS "cinp_cin_plan_id",          -- metadata={"item_ref":"CINP001A"}
    CIN_EPISODE.REFERRALID              AS "cinp_referral_id",          --metadata={"item_ref:"CINP007A"}
    CIN_PLAN.PERSONID                   AS "cinp_person_id",            --metadata={"item_ref:"CINP002A"}
    CIN_PLAN.STARTDATE                  AS "cinp_cin_plan_start_date",  --metadata={"item_ref:"CINP003A"}
    CIN_PLAN.ENDDATE                    AS "cinp_cin_plan_end_date",    --metadata={"item_ref:"CINP004A"}
    WORKER.ALLOCATED_WORKER             AS "cinp_cin_plan_worker_id",    --metadata={"item_ref:"CINP006A"}
    TEAM.ALLOCATED_TEAM                 AS "cinp_cin_plan_team"        --metadata={"item_ref:"CINP005A"} 
FROM CIN_PLAN 
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM WORKER 
             WHERE WORKER.PERSONID = CIN_PLAN.PERSONID
                     AND COALESCE(CIN_PLAN.ENDDATE,CURRENT_DATE) > WORKER.WORKER_START_DATE
                     AND CIN_PLAN.STARTDATE < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
             ORDER BY WORKER.WORKER_START_DATE DESC        
             FETCH FIRST 1 ROW ONLY        
             ) WORKER ON TRUE        
LEFT JOIN LATERAL (
             SELECT 
                 * 
             FROM TEAM
             WHERE TEAM.PERSONID = CIN_PLAN.PERSONID 
                     AND COALESCE(CIN_PLAN.ENDDATE,CURRENT_DATE) > TEAM.TEAM_START_DATE
                     AND CIN_PLAN.STARTDATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)  
             ORDER BY TEAM.TEAM_START_DATE DESC 
             FETCH FIRST 1 ROW ONLY 
             ) TEAM ON TRUE

LEFT JOIN LATERAL (
            SELECT
                *
            FROM CIN_EPISODE
            WHERE CIN_PLAN.PERSONID =  CIN_EPISODE.PERSONID 
                      AND CIN_PLAN.STARTDATE >= CIN_EPISODE.DATE_OF_REFERRAL
                      AND CIN_PLAN.STARTDATE <= COALESCE(CIN_EPISODE.CINE_CLOSE_DATE,CURRENT_DATE)
            ORDER BY CIN_EPISODE.DATE_OF_REFERRAL DESC 
            FETCH FIRST 1 ROW ONLY 
            ) CIN_EPISODE ON TRUE
;



-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cin_plans ADD CONSTRAINT FK_ssd_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cin_plans_person_id       ON ssd_development.ssd_cin_plans(cinp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_cin_plan_start_date  ON ssd_development.ssd_cin_plans(cinp_cin_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_cin_plan_end_date    ON ssd_development.ssd_cin_plans(cinp_cin_plan_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_cinp_referral_id          ON ssd_development.ssd_cin_plans(cinp_referral_id);

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cin_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cin_visits') IS NOT NULL DROP TABLE ssd_development.ssd_cin_visits;
IF OBJECT_ID('tempdb..#ssd_cin_visits') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cin_visits
(
    cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CINV001A"}      
    cinv_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINV007A"}
    cinv_cin_visit_date         DATETIME,                   -- metadata={"item_ref":"CINV003A"}
    cinv_cin_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CINV004A"}
    cinv_cin_visit_seen_alone   NCHAR(1),                   -- metadata={"item_ref":"CINV005A"}
    cinv_cin_visit_bedroom      NCHAR(1)                    -- metadata={"item_ref":"CINV006A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cin_visits
(
    cinv_cin_visit_id,                  
    cinv_person_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)


SELECT 
    FAPV.FORMID            AS "cinv_cin_visit_id",       --metadata={"item_ref:"CINV001A"}
	FAPV.PERSONID          AS "cinv_person_id",          --metadata={"item_ref:"CINV007A"}
	FAPV.VISIT_DATE	       AS "cinv_cin_visit_date",     --metadata={"item_ref:"CINV003A"}
	FAPV.CHILD_SEEN        AS "cinv_cin_visit_seen",       --metadata={"item_ref:"CINV004A"}
	FAPV.SEEN_ALONE        AS "cinv_cin_visit_seen_alone", --metadata={"item_ref:"CINV005A"}
	NULL                   AS "cinv_cin_visit_bedroom"     --metadata={"item_ref:"CINV006A"}
FROM CIN_PLAN
JOIN (
		
		SELECT
			FAPV.INSTANCEID            AS FORMID,
			FAPV.ANSWERFORSUBJECTID    AS PERSONID,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
				   THEN FAPV.DATEANSWERVALUE
			    END)	               AS VISIT_DATE,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
				   THEN CASE WHEN FAPV.ANSWERVALUE = 'Yes'
				             THEN 'Y'
				             ELSE 'N'
				        END     
			    END)                  AS CHILD_SEEN,
			MAX(CASE
				   WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
				   THEN CASE WHEN FAPV.ANSWERVALUE = 'Child seen alone'
				             THEN 'Y'
				             ELSE 'N'
				        END     
			    END)                  AS SEEN_ALONE
			
			
		FROM  FORMANSWERPERSONVIEW FAPV
		WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
		    AND FAPV.INSTANCESTATE = 'COMPLETE'
		    AND FAPV.designsubname IN ('Child in need', 'Family Help')
		    AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
		GROUP BY 
		    FAPV.ANSWERFORSUBJECTID,
		    FAPV.INSTANCEID	
  ) FAPV ON FAPV.PERSONID = CIN_PLAN.PERSONID
        AND FAPV.VISIT_DATE >= CIN_PLAN.STARTDATE
        AND FAPV.VISIT_DATE <= CIN_PLAN.ENDDATE
    ;
 


-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
FOREIGN KEY (cinv_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cinv_person_id        ON ssd_development.ssd_cin_visits(cinv_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cinv_cin_visit_date   ON ssd_development.ssd_cin_visits(cinv_cin_visit_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_s47_enquiry"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_s47_enquiry';


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_s47_enquiry') IS NOT NULL DROP TABLE ssd_development.ssd_s47_enquiry;
IF OBJECT_ID('tempdb..#ssd_s47_enquiry') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_s47_enquiry (
    s47e_s47_enquiry_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S47E001A"}
    s47e_referral_id                    NVARCHAR(48),               -- metadata={"item_ref":"S47E010A"}
    s47e_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"S47E002A"}
    s47e_s47_start_date                 DATETIME,                   -- metadata={"item_ref":"S47E004A"}
    s47e_s47_end_date                   DATETIME,                   -- metadata={"item_ref":"S47E005A"}
    s47e_s47_nfa                        NCHAR(1),                   -- metadata={"item_ref":"S47E006A"}
    s47e_s47_outcome_json               NVARCHAR(1000),             -- metadata={"item_ref":"S47E007A"}
    s47e_s47_completed_by_team          NVARCHAR(48),               -- metadata={"item_ref":"S47E009A"}
    s47e_s47_completed_by_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"S47E008A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_s47_enquiry(
    s47e_s47_enquiry_id,
    s47e_referral_id,
    s47e_person_id,
    s47e_s47_start_date,
    s47e_s47_end_date,
    s47e_s47_nfa,
    s47e_s47_outcome_json,
    s47e_s47_completed_by_team,
    s47e_s47_completed_by_worker_id
)


SELECT
	FAPV.INSTANCEID                    AS "s47e_s47_enquiry_id",           --metadata={"item_ref:"S47E001A"}
	CIN_EPISODE.CINE_REFERRAL_ID       AS "s47e_referral_id",              --metadata={"item_ref:"S47E010A"}
	FAPV.ANSWERFORSUBJECTID            AS "s47e_person_id",                --metadata={"item_ref:"S47E002A"}
	FAPV.STARTDATE                     AS "s47e_s47_start_date",           --metadata={"item_ref:"S47E004A"}
	FAPV.COMPLETIONDATE                AS "s47e_s47_end_date",             --metadata={"item_ref:"S47E005A"}
	CASE WHEN FAPV.OUTCOME = 'No further action' 
	     THEN 'Y'
	     ELSE 'N' 
	END                                AS "s47e_s47_nfa",                 --metadata={"item_ref:"S47E006A"}
	JSON_BUILD_OBJECT( 
         'OUTCOME_NFA_FLAG',                 CASE WHEN FAPV.OUTCOME = 'No further action' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END,
         'OUTCOME_LEGAL_ACTION_FLAG',        'N', 
         'OUTCOME_PROV_OF_SERVICES_FLAG',    'N',
         'OUTCOME_CP_CONFERENCE_FLAG',       CASE WHEN FAPV.OUTCOME = 'Convene initial child protection conference' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END, 
         'OUTCOME_NFA_CONTINUE_SINGLE_FLAG', CASE WHEN FAPV.OUTCOME IN( 'Continue discussion and plan', 'Continue assessment / plan', 'Continue assessment and plan') 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END, 
         'OUTCOME_MONITOR_FLAG',             'N', 
         'OTHER_OUTCOMES_EXIST_FLAG'    ,    CASE WHEN FAPV.OUTCOME = 'Further strategy meeting' 
	                                              THEN 'Y'
	                                              ELSE 'N' 
	                                         END,
         'TOTAL_NO_OF_OUTCOMES',             ' ',
         'OUTCOME_COMMENTS' ,                SUMMARY_UTCOME

      )                              AS	"s47e_s47_outcome_json",             --metadata={"item_ref:"S47E007A"}
	WORKER.ALLOCATED_WORKER          AS "s47e_s47_completed_by_worker_id", --metadata={"item_ref:"S47E008A"}
	TEAM.ALLOCATED_TEAM              AS "s47e_s47_completed_by_team"    --metadata={"item_ref:"S47E009A"}
		    
FROM (
	SELECT
		FAPV.INSTANCEID ,
		FAPV.ANSWERFORSUBJECTID ,
		MAX(CASE WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfStratMeeting'
				 THEN FAPV.DATEANSWERVALUE
		END)                       AS STARTDATE,
		FAPV.DATECOMPLETED::DATE   AS COMPLETIONDATE,
		MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_unsubWhatNeedsToHappenNext', 'CINCensus_whatNeedsToHappenNext')
				 THEN FAPV.ANSWERVALUE
	    END)                       AS OUTCOME,
		MAX(CASE WHEN FAPV.CONTROLNAME IN( 'CINCensus_outcomeOfSection47Enquiry')
				 THEN FAPV.ANSWERVALUE
	    END)                       AS SUMMARY_UTCOME	    
	FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fdca0a95-8578-43ca-97ff-ad3a8adf57de') --Child Protection: Section 47 Assessment
         AND FAPV.INSTANCESTATE = 'COMPLETE'
         AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)	
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DATECOMPLETED) FAPV
LEFT JOIN WORKER ON WORKER.PERSONID = FAPV.ANSWERFORSUBJECTID 
                         AND FAPV.STARTDATE >= WORKER.WORKER_START_DATE
                         AND FAPV.STARTDATE < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = FAPV.ANSWERFORSUBJECTID 
                         AND FAPV.STARTDATE >= TEAM.TEAM_START_DATE
                         AND FAPV.STARTDATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         
LEFT JOIN CIN_EPISODE ON FAPV.ANSWERFORSUBJECTID =  CIN_EPISODE.CINE_PERSON_ID 
                      AND FAPV.STARTDATE >= CIN_EPISODE.CINE_REFERRAL_DATE
                      AND FAPV.STARTDATE < COALESCE(CIN_EPISODE.CINE_CLOSE_DATE,CURRENT_DATE)                     
 ;



-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_s47_enquiry ADD CONSTRAINT FK_ssd_s47_person
FOREIGN KEY (s47e_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_person_id     ON ssd_development.ssd_s47_enquiry(s47e_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_start_date    ON ssd_development.ssd_s47_enquiry(s47e_s47_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_end_date      ON ssd_development.ssd_s47_enquiry(s47e_s47_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_referral_id   ON ssd_development.ssd_s47_enquiry(s47e_referral_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_initial_cp_conference"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_initial_cp_conference') IS NOT NULL DROP TABLE ssd_development.ssd_initial_cp_conference;
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;
 

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_initial_cp_conference (
    icpc_icpc_id                NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"ICPC001A"}
    icpc_icpc_meeting_id        NVARCHAR(48),               -- metadata={"item_ref":"ICPC009A"}
    icpc_s47_enquiry_id         NVARCHAR(48),               -- metadata={"item_ref":"ICPC002A"}
    icpc_person_id              NVARCHAR(48),               -- metadata={"item_ref":"ICPC010A"}
    icpc_cp_plan_id             NVARCHAR(48),               -- metadata={"item_ref":"ICPC011A"}
    icpc_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"ICPC012A"}
    icpc_icpc_transfer_in       NCHAR(1),                   -- metadata={"item_ref":"ICPC003A"}
    icpc_icpc_target_date       DATETIME,                   -- metadata={"item_ref":"ICPC004A"}
    icpc_icpc_date              DATETIME,                   -- metadata={"item_ref":"ICPC005A"}
    icpc_icpc_outcome_cp_flag   NCHAR(1),                   -- metadata={"item_ref":"ICPC013A"}
    icpc_icpc_outcome_json      NVARCHAR(1000),             -- metadata={"item_ref":"ICPC006A"}
    icpc_icpc_team              NVARCHAR(48),               -- metadata={"item_ref":"ICPC007A"}
    icpc_icpc_worker_id         NVARCHAR(100),              -- metadata={"item_ref":"ICPC008A"}
);
 
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_initial_cp_conference(
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
 
SELECT
	CONCAT(INITIAL_ASESSMENT.INSTANCEID,INITIAL_ASESSMENT.PERSONID) AS "icpc_icpc_id",          --metadata={"item_ref:"ICPC001A"}
	INITIAL_ASESSMENT.INSTANCEID                                    AS "icpc_icpc_meeting_id",  --metadata={"item_ref:"ICPC009A"}
	ASESSMENT47.INSTANCEID                                          AS "icpc_s47_enquiry_id",   --metadata={"item_ref:"ICPC002A"}
	INITIAL_ASESSMENT.PERSONID                                      AS "icpc_person_id",        --metadata={"item_ref:"ICPC010A"}
	CP_PLAN.PLANID                                                  AS "icpc_cp_plan_id",       --metadata={"item_ref:"ICPC011A"}
	CP_PLAN.CINE_REFERRAL_ID                                        AS "icpc_referral_id",      --metadata={"item_ref:"ICPC012A"}
	CASE WHEN INITIAL_ASESSMENT.MEETING_TYPE = 'Child Protection (Transfer in conference)'
	     THEN 'Y'
	     ELSE 'N'
	END                                                             AS "icpc_icpc_transfer_in", --metadata={"item_ref:"ICPC003A"}
	STRATEGY_DISC.TARGET_DATE                                       AS "icpc_icpc_target_date", --metadata={"item_ref:"ICPC004A"}
	INITIAL_ASESSMENT.DATE_OF_MEETING                               AS "icpc_icpc_date",        --metadata={"item_ref:"ICPC005A"}
	CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Set next review'
	     THEN 'Y'
	     ELSE 'N'
	END                                                             AS "icpc_icpc_outcome_cp_flag", --metadata={"item_ref:"ICPC013A"}
	JSON_BUILD_OBJECT( 
	    'OUTCOME_NFA_FLAG', CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Case closure' OR INITIAL_ASESSMENT.NEXT_STEP IS NULL
	                             THEN 'Y'
	                             ELSE 'N'
	                        END ,
	    'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG', '',
	    'OUTCOME_SINGLE_ASSESSMENT_FLAG',        '',
	    'OUTCOME_PROV_OF_SERVICES_FLAG',         '', 
	    'OUTCOME_CP_FLAG',  CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'Set next review'
	                             THEN 'Y'
	                             ELSE 'N'
	                        END ,
	    'OTHER_OUTCOMES_EXIST_FLAG', CASE WHEN INITIAL_ASESSMENT.NEXT_STEP = 'CIN'
	                                      THEN 'Y'
	                                      ELSE 'N'
	                                 END ,
	    'TOTAL_NO_OF_OUTCOMES',     '',
	    'OUTCOME_COMMENTS'    ,      ''
	)                                                               AS  "icpc_icpc_outcome_json", --metadata={"item_ref:"ICPC006A"}
	TEAM.ALLOCATED_TEAM                                             AS "icpc_icpc_team", --metadata={"item_ref:"ICPC007A"}
	WORKER.ALLOCATED_WORKER                                         AS "icpc_icpc_worker_id" --metadata={"item_ref:"ICPC008A"}
FROM INITIAL_ASESSMENT	
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM ASESSMENT47
             WHERE ASESSMENT47.PERSONID = INITIAL_ASESSMENT.PERSONID
                   AND ASESSMENT47.STARTDATE <= INITIAL_ASESSMENT.DATE_OF_MEETING
             ORDER BY ASESSMENT47.STARTDATE DESC
             FETCH FIRST 1 ROW ONLY) ASESSMENT47 ON TRUE
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM STRATEGY_DISC
             WHERE STRATEGY_DISC.PERSONID = INITIAL_ASESSMENT.PERSONID
                   AND STRATEGY_DISC.MEETING_DATE <= INITIAL_ASESSMENT.DATE_OF_MEETING
             ORDER BY STRATEGY_DISC.MEETING_DATE DESC
             FETCH FIRST 1 ROW ONLY) STRATEGY_DISC ON TRUE             
LEFT JOIN LATERAL (
             SELECT
                 *
             FROM CP_PLAN
             WHERE CP_PLAN.PERSONID = INITIAL_ASESSMENT.PERSONID
                 AND INITIAL_ASESSMENT.DATE_OF_MEETING <= CP_PLAN.PLAN_START_DATE
             ORDER BY CP_PLAN.PLAN_START_DATE
             FETCH FIRST 1 ROW ONLY) CP_PLAN ON TRUE  
 LEFT JOIN WORKER ON WORKER.PERSONID = INITIAL_ASESSMENT.PERSONID 
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING >= WORKER.WORKER_START_DATE
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING < COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)  
 LEFT JOIN TEAM ON TEAM.PERSONID = INITIAL_ASESSMENT.PERSONID  
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING >= TEAM.TEAM_START_DATE
                         AND INITIAL_ASESSMENT.DATE_OF_MEETING < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)  
LEFT JOIN WORKING_DAY_RANKS SDR ON SDR."DATE" = STRATEGY_DISC.MEETING_DATE                         
LEFT JOIN WORKING_DAY_RANKS IAR ON IAR."DATE" = INITIAL_ASESSMENT.DATE_OF_MEETING

;


-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_initial_cp_conference ADD CONSTRAINT FK_ssd_icpc_person_id
FOREIGN KEY (icpc_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_icpc_person_id        ON ssd_development.ssd_initial_cp_conference(icpc_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_s47_enquiry_id   ON ssd_development.ssd_initial_cp_conference(icpc_s47_enquiry_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_referral_id      ON ssd_development.ssd_initial_cp_conference(icpc_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_icpc_date        ON ssd_development.ssd_initial_cp_conference(icpc_icpc_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cp_plans"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - ssd_initial_cp_conference
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.ssd_cp_plans') IS NOT NULL DROP TABLE ssd_development.ssd_cp_plans;
IF OBJECT_ID('tempdb..#ssd_cp_plans') IS NOT NULL DROP TABLE #ssd_cp_plans;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cp_plans (
    cppl_cp_plan_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CPPL001A"}
    cppl_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CPPL007A"}
    cppl_icpc_id                    NVARCHAR(48),               -- metadata={"item_ref":"CPPL008A"}
    cppl_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CPPL002A"}
    cppl_cp_plan_start_date         DATETIME,                   -- metadata={"item_ref":"CPPL003A"}
    cppl_cp_plan_end_date           DATETIME,                   -- metadata={"item_ref":"CPPL004A"}
    cppl_cp_plan_ola                NCHAR(1),                   -- metadata={"item_ref":"CPPL011A"}       
    cppl_cp_plan_initial_category   NVARCHAR(100),              -- metadata={"item_ref":"CPPL009A"}
    cppl_cp_plan_latest_category    NVARCHAR(100),              -- metadata={"item_ref":"CPPL010A"}
);
 
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_plans (
    cppl_cp_plan_id,
    cppl_referral_id,
    cppl_icpc_id,
    cppl_person_id,
    cppl_cp_plan_start_date,
    cppl_cp_plan_end_date,
    cppl_cp_plan_ola,
    cppl_cp_plan_initial_category,
    cppl_cp_plan_latest_category
)


SELECT
	CP_PLAN.CLAID                       AS "cppl_cp_plan_id", --metadata={"item_ref:"CPPL001A"}
	CIN_EPISODE.REFERRALID              AS "cppl_referral_id", --metadata={"item_ref:"CPPL007A"}
	INITIAL_ASESSMENT.INSTANCEID        AS  "cppl_icpc_id", --metadata={"item_ref:"CPPL008A"}
	CP_PLAN.PERSONID                    AS "cppl_person_id", --metadata={"item_ref:"CPPL002A"}
	CP_PLAN.STARTDATE:: DATE            AS "cppl_cp_plan_start_date", --metadata={"item_ref:"CPPL003A"}
	CP_PLAN.ENDDATE:: DATE              AS "cppl_cp_plan_end_date", --metadata={"item_ref:"CPPL004A"}
	CP_CATEGORY_FIRST.NAME              AS "cppl_cp_plan_initial_category", --metadata={"item_ref:"CPPL009A"}
	NULL                                AS "cppl_cp_plan_ola", --metadata={"item_ref:"CPPL0101A"}
	CP_CATEGORY_LATEST.NAME             AS "cppl_cp_plan_latest_category" --metadata={"item_ref:"CPPL010A"}
FROM CP_PLAN
LEFT JOIN LATERAL (
                SELECT
                    *
                FROM INITIAL_ASESSMENT
                WHERE INITIAL_ASESSMENT.PERSONID = CP_PLAN.PERSONID
                     AND INITIAL_ASESSMENT.DATE_OF_MEETING <= CP_PLAN.STARTDATE:: DATE
                ORDER BY INITIAL_ASESSMENT.DATE_OF_MEETING DESC
                FETCH FIRST 1 ROW ONLY
                ) INITIAL_ASESSMENT ON TRUE 
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CIN_EPISODE
                WHERE CIN_EPISODE.PERSONID = CP_PLAN.PERSONID
                    AND CIN_EPISODE.DATE_OF_REFERRAL <= CP_PLAN.STARTDATE:: DATE
                ORDER BY CIN_EPISODE.DATE_OF_REFERRAL DESC
                FETCH FIRST 1 ROW ONLY
                ) CIN_EPISODE ON TRUE  
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CP_CATEGORY
                WHERE CP_CATEGORY.PERSONID = CP_PLAN.PERSONID 
                    AND CP_CATEGORY.STARTDATE <= CP_PLAN.STARTDATE::DATE
                ORDER BY CP_CATEGORY.STARTDATE DESC    
                FETCH FIRST 1 ROW ONLY
                ) CP_CATEGORY_LATEST ON TRUE
LEFT JOIN LATERAL (
                SELECT 
                    *
                FROM CP_CATEGORY
                WHERE CP_CATEGORY.PERSONID = CP_PLAN.PERSONID 
                    AND CP_CATEGORY.STARTDATE <= CP_PLAN.STARTDATE::DATE
                ORDER BY CP_CATEGORY.STARTDATE     
                FETCH FIRST 1 ROW ONLY
                ) CP_CATEGORY_FIRST ON TRUE 
  
;


-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cp_plans ADD CONSTRAINT FK_ssd_cppl_person_id
FOREIGN KEY (cppl_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_person_id ON ssd_development.ssd_cp_plans(cppl_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_icpc_id ON ssd_development.ssd_cp_plans(cppl_icpc_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_referral_id ON ssd_development.ssd_cp_plans(cppl_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_start_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_end_date ON ssd_development.ssd_cp_plans(cppl_cp_plan_end_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cp_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
--          using casenote ID as PK and linking to CP Visit where available.
--          Will have to use Person ID to link object to Person table
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================
 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cp_visits') IS NOT NULL DROP TABLE ssd_development.ssd_cp_visits;
IF OBJECT_ID('tempdb..#ssd_cp_visits') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cp_visits (
    cppv_cp_visit_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPV007A"} 
    cppv_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CPPV008A"}
    cppv_cp_plan_id                 NVARCHAR(48),   -- metadata={"item_ref":"CPPV001A"}
    cppv_cp_visit_date              DATETIME,       -- metadata={"item_ref":"CPPV003A"}
    cppv_cp_visit_seen              NCHAR(1),       -- metadata={"item_ref":"CPPV004A"}
    cppv_cp_visit_seen_alone        NCHAR(1),       -- metadata={"item_ref":"CPPV005A"}
    cppv_cp_visit_bedroom           NCHAR(1)        -- metadata={"item_ref":"CPPV006A"}
);

-- CTE Ensure unique cases only, most recent has priority-- #DtoI-1715 



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_visits (
    cppv_cp_visit_id,
    cppv_person_id,            
    cppv_cp_plan_id,  
    cppv_cp_visit_date,
    cppv_cp_visit_seen,
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom
)


SELECT
	FAPV.INSTANCEID                    AS "cppv_cp_visit_id",         --metadata={"item_ref:"CPPV007A"}
	FAPV.PERSONID                      AS "cppv_person_id",           --metadata={"item_ref:"CPPV008A"}
	CP_PLAN.CLASSIFICATIONASSIGNMENTID AS "cppv_cp_plan_id",          --metadata={"item_ref:"CPPV001A"}
	FAPV.VISIT_DATE                    AS "cppv_cp_visit_date",       --metadata={"item_ref:"CPPV003A"}
	FAPV.CHILD_SEEN                    AS "cppv_cp_visit_seen",       --metadata={"item_ref:"CPPV004A"}
	FAPV.CHILD_SEEN_ALONE              AS "cppv_cp_visit_seen_alone", --metadata={"item_ref:"CPPV005A"}
	NULL                               AS "cppv_cp_visit_bedroom"     --metadata={"item_ref:"CPPV006A"}
	
FROM (
    SELECT
        FAPV.INSTANCEID,
	    FAPV.ANSWERFORSUBJECTID AS PERSONID,
	    MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
		       THEN FAPV.DATEANSWERVALUE
	        END)                AS VISIT_DATE,
	    MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
		       THEN CASE WHEN FAPV.ANSWERVALUE = 'Yes'
		                  THEN 'Y'
		                  ELSE 'N'
		            END     
	       END)                 AS CHILD_SEEN,
    	MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
		       THEN CASE WHEN FAPV.ANSWERVALUE = 'Child seen alone'
		                 THEN 'Y'
		                 ELSE 'N'
		            END     
	        END)                AS  CHILD_SEEN_ALONE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.designsubname = 'Child Protection '
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY 
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
    ) FAPV
LEFT JOIN CLASSIFICATIONPERSONVIEW CP_PLAN ON CP_PLAN.PERSONID = FAPV.PERSONID
      AND FAPV.VISIT_DATE >= CP_PLAN.STARTDATE AND FAPV.VISIT_DATE <= COALESCE(CP_PLAN.ENDDATE,CURRENT_DATE)  	
      AND CP_PLAN.CLASSIFICATIONPATHID = 51 
 ;




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cp_visits ADD CONSTRAINT FK_ssd_cppv_to_cppl
FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);


-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cppv_person_id        ON ssd_development.ssd_cp_visits(cppv_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_plan_id       ON ssd_development.ssd_cp_visits(cppv_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_visit_date    ON ssd_development.ssd_cp_visits(cppv_cp_visit_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cp_reviews"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:    
-- Dependencies:
-- - ssd_person
-- - ssd_cp_plans
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_development.ssd_cp_reviews;
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cp_reviews
(
    cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPR001A"}
    cppr_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CPPR008A"}
    cppr_cp_plan_id                     NVARCHAR(48),               -- metadata={"item_ref":"CPPR002A"}  
    cppr_cp_review_due                  DATETIME NULL,              -- metadata={"item_ref":"CPPR003A"}
    cppr_cp_review_date                 DATETIME NULL,              -- metadata={"item_ref":"CPPR004A"}
    cppr_cp_review_meeting_id           NVARCHAR(48),               -- metadata={"item_ref":"CPPR009A"}      
    cppr_cp_review_outcome_continue_cp  NCHAR(1),                   -- metadata={"item_ref":"CPPR005A"}
    cppr_cp_review_quorate              NVARCHAR(100),              -- metadata={"item_ref":"CPPR006A"}      
    cppr_cp_review_participation        NVARCHAR(100)               -- metadata={"item_ref":"CPPR007A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cp_reviews
(
    cppr_cp_review_id,
    cppr_cp_plan_id,
    cppr_person_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_meeting_id,
    cppr_cp_review_outcome_continue_cp,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
)


SELECT
	IRO_REVIEW.FORMID             AS "cppr_cp_review_id",         --metadata={"item_ref:"CPPR001A"}
	CP_REVIEW.PERSONID            AS "cppr_person_id",            --metadata={"item_ref:"CPPR008A"}
	CP_PLAN.CLAID                 AS "cppr_cp_plan_id",           --metadata={"item_ref:"CPPR002A"}
	PREVIOUSR.NEXT_REVIEW         AS "cppr_cp_review_due",        --metadata={"item_ref:"CPPR003A"}
	CP_REVIEW.DATE_OF_MEETING     AS "cppr_cp_review_date",       --metadata={"item_ref:"CPPR004A"}
	CP_REVIEW.FORMID              AS "cppr_cp_review_meeting_id", --metadata={"item_ref:"CPPR009A"}
	CASE WHEN CP_REVIEW.NEXT_STEP = 'Set next review' 
	     THEN 'Y'
	     ELSE 'N'
	END                           AS "cppr_cp_review_outcome_continue_cp", --metadata={"item_ref:"CPPR005A"}
	'Y'                           AS "cppr_cp_review_quorate",    --metadata={"item_ref:"CPPR006A"}
	IRO_REVIEW.PARTICIPATION   AS "cppr_cp_review_participation" --metadata={"item_ref:"CPPR007A"}

FROM CP_REVIEW
LEFT JOIN LATERAL (
           SELECT
               *
           FROM  CP_REVIEW PREVIOUSR
           WHERE PREVIOUSR.PERSONID = CP_REVIEW.PERSONID
              --   AND PREVIOUSR.PLANID = CP_REVIEW.PLANID
                 AND PREVIOUSR.DATE_OF_MEETING < CP_REVIEW.DATE_OF_MEETING
           ORDER BY PREVIOUSR.DATE_OF_MEETING DESC
           FETCH FIRST 1 ROW ONLY) PREVIOUSR ON TRUE 
LEFT JOIN IRO_REVIEW ON IRO_REVIEW.PERSONID = CP_REVIEW.PERSONID AND IRO_REVIEW.DATE_OF_MEETING = CP_REVIEW.DATE_OF_MEETING
LEFT JOIN CP_PLAN ON CP_PLAN.PERSONID = CP_REVIEW.PERSONID AND CP_REVIEW.DATE_OF_MEETING >= CP_PLAN.STARTDATE AND CP_REVIEW.DATE_OF_MEETING < CP_PLAN.ENDDATE
;




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_development.ssd_cp_plans(cppl_cp_plan_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_cppr_person_id ON ssd_development.ssd_cp_reviews(cppr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_plan_id ON ssd_development.ssd_cp_reviews(cppr_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_due ON ssd_development.ssd_cp_reviews(cppr_cp_review_due);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_date ON ssd_development.ssd_cp_reviews(cppr_cp_review_date);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_meeting_id ON ssd_development.ssd_cp_reviews(cppr_cp_review_meeting_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_episodes"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_involvements
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}   
IF OBJECT_ID('ssd_development.ssd_cla_episodes') IS NOT NULL DROP TABLE ssd_development.ssd_cla_episodes;
IF OBJECT_ID('tempdb..#ssd_cla_episodes') IS NOT NULL DROP TABLE #ssd_cla_episodes;

 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_episodes (
    clae_cla_episode_id             NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAE001A"}
    clae_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAE002A"}
    clae_cla_placement_id           NVARCHAR(48),               -- metadata={"item_ref":"CLAE013A"} 
    clae_cla_episode_start_date     DATETIME,                   -- metadata={"item_ref":"CLAE003A"}
    clae_cla_episode_start_reason   NVARCHAR(100),              -- metadata={"item_ref":"CLAE004A"}
    clae_cla_primary_need_code      NVARCHAR(3),                -- metadata={"item_ref":"CLAE009A", "info":"Expecting codes N0-N9"} 
    clae_cla_episode_ceased         DATETIME,                   -- metadata={"item_ref":"CLAE005A"}
    clae_cla_episode_ceased_reason  NVARCHAR(255),              -- metadata={"item_ref":"CLAE006A"}
    clae_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAE010A"}
    clae_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CLAE011A"}
    clae_cla_last_iro_contact_date  DATETIME,                   -- metadata={"item_ref":"CLAE012A"} 
    clae_entered_care_date          DATETIME                    -- metadata={"item_ref":"CLAE014A"}
);



-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_episodes (
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_placement_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need_code,
    clae_cla_episode_ceased,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_last_iro_contact_date,
    clae_entered_care_date 
)



SELECT
	CLA_EPISODE.EPISODEOFCAREID                                         AS "clae_cla_episode_id",                  -- metadata={"item_ref":"CLAE001A"}
	CLA_EPISODE.PERSONID                                                AS "clae_person_id",                       -- metadata={"item_ref":"CLAE002A"}
	CLA_EPISODE.EOCSTARTDATE                                            AS "clae_cla_episode_start_date",          -- metadata={"item_ref":"CLAE003A"}
	CLA_EPISODE.EOCSTARTREASONCODE                                      AS "clae_cla_episode_start_reason",        -- metadata={"item_ref":"CLAE004A"}
	CASE WHEN CLA_EPISODE.CATEGORYOFNEED = 'Abuse or neglect'                THEN 'N1'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Child''s disability'             THEN 'N2'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Parental illness/disability'     THEN 'N3'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family in acute stress'          THEN 'N4'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Family dysfunction'              THEN 'N5'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Socially unacceptable behaviour' THEN 'N6'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Low income'                      THEN 'N7'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Absent parenting'                THEN 'N8'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Cases other than child in need'  THEN 'N9'
         WHEN CLA_EPISODE.CATEGORYOFNEED = 'Not stated'                      THEN 'N0'
    END                                                                AS "clae_cla_primary_need",                 -- metadata={"item_ref":"CLAE009A"}
	CLA_EPISODE.EOCENDDATE                                             AS "clae_cla_episode_ceased_date",               -- metadata={"item_ref":"CLAE005A"}
	CLA_EPISODE.EOCENDREASONCODE                                       AS "clae_cla_episode_ceased_reason",        -- metadata={"item_ref":"CLAE006A"}
	CLA_EPISODE.PERIODOFCAREID                                         AS "clae_cla_id",                           -- metadata={"item_ref":"CLAE010A"}
	REFR.ASSESSMENTID                                                  AS "clae_referral_id",                      -- metadata={"item_ref":"CLAE011A"}
	CLA_EPISODE.PLACEMENTADDRESSID                                     AS "clae_cla_placement_id",                 -- metadata={"item_ref":"CLAE013A"}    
	CLA.ADMISSIONDATE                                                  AS "clae_entered_care_date",                -- metadata={"item_ref":"CLAE014A"} 
	IRO_MEETING.DATE_OF_MEETING                                        AS "clae_cla_last_iro_contact_date"         -- metadata={"item_ref":"CLAE012A"}
	
FROM CLAEPISODEOFCAREVIEW CLA_EPISODE	
LEFT JOIN LATERAL (  
        SELECT *  
        FROM REFERRAL REFR
        WHERE CLA_EPISODE.PERSONID = REFR.PERSONID
           AND CLA_EPISODE.EOCSTARTDATE >= REFR.DATE_OF_REFERRAL
        ORDER BY REFR.DATE_OF_REFERRAL DESC
        FETCH FIRST 1 ROW ONLY
           ) REFR  ON TRUE 
           
LEFT JOIN CLAPERIODOFCAREVIEW CLA ON CLA.PERSONID = CLA_EPISODE.PERSONID AND CLA.PERIODOFCAREID = CLA_EPISODE.PERIODOFCAREID  
LEFT JOIN LATERAL (
        SELECT 
            *
        FROM IRO_MEETING    
        WHERE CLA_EPISODE.PERSONID = IRO_MEETING.PERSONID
          AND IRO_MEETING.DATE_OF_MEETING >= CLA.ADMISSIONDATE 
          AND IRO_MEETING.DATE_OF_MEETING <= COALESCE(CLA.DISCHARGEDATE,CURRENT_DATE)
        ORDER BY  IRO_MEETING.DATE_OF_MEETING DESC 
        FETCH FIRST 1 ROW ONLY) IRO_MEETING ON TRUE
WHERE CLA_EPISODE.PERSONID  NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E) 
;


-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_to_person 
FOREIGN KEY (clae_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);

-- ALTER TABLE ssd_development.ssd_cla_episodes ADD CONSTRAINT FK_ssd_clae_cla_placement_id
-- FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_development.ssd_cla_placements (clap_cla_placement_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clae_person_id ON ssd_development.ssd_cla_episodes(clae_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_start_date ON ssd_development.ssd_cla_episodes(clae_cla_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_ceased ON ssd_development.ssd_cla_episodes(clae_cla_episode_ceased);
CREATE NONCLUSTERED INDEX idx_ssd_clae_referral_id ON ssd_development.ssd_cla_episodes(clae_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_cla_last_iro_contact_date ON ssd_development.ssd_cla_episodes(clae_cla_last_iro_contact_date);
CREATE NONCLUSTERED INDEX idx_ssd_clae_cla_placement_id ON ssd_development.ssd_cla_episodes(clae_cla_placement_id);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_convictions"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_OFFENCE
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_convictions;
IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAC001A"}
    clac_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
    clac_cla_conviction_date    DATETIME,                   -- metadata={"item_ref":"CLAC003A"}
    clac_cla_conviction_offence NVARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )



-- SELECT ...


-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fo.DIM_PERSON_ID 
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_convictions ADD CONSTRAINT FK_ssd_clac_to_person 
FOREIGN KEY (clac_person_id) REFERENCES ssd_development.ssd_person (pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clac_person_id ON ssd_development.ssd_cla_convictions(clac_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clac_conviction_date ON ssd_development.ssd_cla_convictions(clac_cla_conviction_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_cla_health"}
-- =============================================================================
-- Object Name: ssd_cla_health
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_health', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_health;
IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_health (
    clah_health_check_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAH001A"}
    clah_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
    clah_health_check_type      NVARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
    clah_health_check_date      DATETIME,                   -- metadata={"item_ref":"CLAH004A"}
    clah_health_check_status    NVARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 


SELECT 
    CLAH_HEALTH_CHECK_ID                              AS "clah_health_check_id",     --metadata={"item_ref:"CLAH001A"}
    CLAH_PERSON_ID                                    AS "clah_person_id",           --metadata={"item_ref:"CLAH002A"}
    CASE WHEN CLAH_HEALTH_CHECK_TYPE = 'Dental check '
         THEN 'Dental Check'
         WHEN CLAH_HEALTH_CHECK_TYPE = 'Health check '
         THEN 'Health check'
         WHEN CLAH_HEALTH_CHECK_TYPE = 'Optician check '
         THEN 'Optician check'
    END                                               AS "clah_health_check_type",   --metadata={"item_ref:"CLAH003A"}
    CASE WHEN CLAH_HEALTH_CHECK_DATE IS NULL
         THEN REPORTING_DATE
         ELSE CLAH_HEALTH_CHECK_DATE
    END                                               AS "clah_health_check_date",   --metadata={"item_ref:"CLAH004A"}    
    CASE WHEN TAKEN_PLACE = 'No'
         THEN 'Refused'
         ELSE CLAH_HEALTH_CHECK_STATUS                         
    END                                               AS "clah_health_check_status"  --metadata={"item_ref:"CLAH005A"}
    
FROM (
    SELECT
	    FAPV.INSTANCEID                         AS CLAH_HEALTH_CHECK_ID,  
	    FAPV.ANSWERFORSUBJECTID                 AS CLAH_PERSON_ID, 
	    FAPV.DESIGNSUBNAME                      AS CLAH_HEALTH_CHECK_TYPE,
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_reportingDate') 
		        THEN FAPV.ANSWERVALUE 
	    END) ::DATE                             AS REPORTING_DATE,
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_dateOfCheck8','903Return_dateOfCheck2') 
		    THEN FAPV.ANSWERVALUE 
	    END) ::DATE                             AS CLAH_HEALTH_CHECK_DATE, 
	    MAX(CASE 
		    WHEN FAPV.CONTROLNAME IN ('903Return_DentalCheck','903Return_HealthAssessmentTakenPlace', 'hasAnOpticianCheckTakenPlace') 
		        THEN FAPV.ANSWERVALUE 
	    END)                                    AS TAKEN_PLACE,
	    FAPV.INSTANCESTATE                      AS CLAH_HEALTH_CHECK_STATUS
    FROM FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
	    AND FAPV.INSTANCESTATE IN ('COMPLETE')
	    AND FAPV.DESIGNSUBNAME IN ('Health check ', 'Dental check ','Optician check ')
    GROUP BY FAPV.INSTANCEID,
             FAPV.ANSWERFORSUBJECTID,
             FAPV.DESIGNSUBNAME,
             FAPV.INSTANCESTATE ) FAPV
WHERE FAPV.CLAH_PERSON_ID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)             

UNION ALL

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Health check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastHealthCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastHealthCheckCompleted' 			--Date last health check completed
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE 

UNION ALL 

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Dental Check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastDentalCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastDentalCheckCompleted' 			--Date last dental check completed 
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE 
         
         
UNION ALL 

SELECT DISTINCT
    FAPV.ANSWERFORSUBJECTID,
	FAPV.INSTANCEID,
	'Optician check',
	MAX(CASE 
		WHEN FAPV.CONTROLNAME IN ('dateLastOpticianCheckCompleted') 
			   THEN FAPV.DATEANSWERVALUE 
	END) :: DATE,
	FAPV.INSTANCESTATE 	
FROM FORMANSWERPERSONVIEW FAPV 
	--Future loading of health checks
WHERE FAPV.DESIGNGUID = '36c62558-e07b-41bb-b3d1-1dd850d55472'
	AND FAPV.CONTROLNAME IN (
			'dateLastOpticianCheckCompleted' 			--Date last optician check completed
			)
	AND FAPV.INSTANCESTATE IN ('COMPLETE')
	AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.ANSWERFORSUBJECTID,
         FAPV.INSTANCEID,
         FAPV.INSTANCESTATE
;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_health ADD CONSTRAINT FK_ssd_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clah_person_id ON ssd_development.ssd_cla_health (clah_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_date ON ssd_development.ssd_cla_health(clah_health_check_date);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_status ON ssd_development.ssd_cla_health(clah_health_check_status);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_immunisations"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_development.ssd_cla_immunisations;
IF OBJECT_ID('tempdb..#ssd_cla_immunisations') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_immunisations (
    clai_person_id                  NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAI002A"}
    clai_immunisations_status       NCHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
    clai_immunisations_status_date  DATETIME                    -- metadata={"item_ref":"CLAI005A"}
);

-- -- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)
-- ;WITH RankedImmunisations AS (
--     SELECT
--         fcla.DIM_PERSON_ID,
--         fcla.IMMU_UP_TO_DATE_FLAG,
--         fcla.LAST_UPDATED_DTTM,
--         ROW_NUMBER() OVER (
--             PARTITION BY fcla.DIM_PERSON_ID -- 
--             ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
--     FROM
--         HDM.Child_Social.FACT_CLA AS fcla
--     WHERE
--         EXISTS ( -- only ssd relevant records be considered for ranking
--             SELECT 1 
--             FROM ssd_development.ssd_person p
--             WHERE CAST(p.pers_person_id AS INT) = fcla.DIM_PERSON_ID -- #DtoI-1799
--         )
-- )


-- META-ELEMENT: {"type": "insert_data"} 
-- (only most recent/rn==1 records)
INSERT INTO ssd_development.ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)


SELECT
	FAPV.ANSWERFORSUBJECTID            AS "clai_person_id",              --metadata={"item_ref:"CLAI002A"}
	MAX(CASE 
	       WHEN FAPV.CONTROLNAME IN ('903Return_ImmunisationsComplete') 
		   THEN SUBSTRING(FAPV.ANSWERVALUE,1,1) 
	END)                               AS "clai_immunisations_status",    --metadata={"item_ref:"CLAI004A"}
    MAX(CASE 
	       WHEN FAPV.CONTROLNAME IN ('903Return_dateOfCheckImm') 
		   THEN FAPV.ANSWERVALUE 
	END) ::DATE                        AS "clai_immunisations_status_date" --metadata={"item_ref:"CLAI005A"}
FROM FORMANSWERPERSONVIEW FAPV
WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
	    AND FAPV.INSTANCESTATE IN ('COMPLETE')	
	    AND FAPV.DESIGNSUBNAME IN ('Immunisation check ')	
	    AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
GROUP BY FAPV.INSTANCEID ,   
         FAPV.ANSWERFORSUBJECTID 
;         


-- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clai_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clai_person_id ON ssd_development.ssd_cla_immunisations(clai_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clai_immunisations_status ON ssd_development.ssd_cla_immunisations(clai_immunisations_status);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_substance_misuse"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_development.ssd_cla_substance_misuse;
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id        NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAS001A"}
    clas_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
    clas_substance_misuse_date      DATETIME,                   -- metadata={"item_ref":"CLAS003A"}
    clas_substance_misused          NVARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
    clas_intervention_received      NCHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)


-- SELECT...


-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fsm.DIM_PERSON_ID -- #DtoI-1799
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_development.ssd_cla_episodes (clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clas_person_id ON ssd_development.ssd_cla_substance_misuse (clas_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clas_substance_misuse_date ON ssd_development.ssd_cla_substance_misuse(clas_substance_misuse_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_placement"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0 
-- Status: [D]ev
-- Remarks: DEV: filtering for OFSTED_URN LIKE 'SC%'
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_placement', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_placement;
IF OBJECT_ID('tempdb..#ssd_cla_placement', 'U') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAP001A"}
    clap_cla_id                         NVARCHAR(48),               -- metadata={"item_ref":"CLAP012A"}
    clap_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CLAP013A"}
    clap_cla_placement_start_date       DATETIME,                   -- metadata={"item_ref":"CLAP003A"}
    clap_cla_placement_type             NVARCHAR(100),              -- metadata={"item_ref":"CLAP004A"}
    clap_cla_placement_urn              NVARCHAR(48),               -- metadata={"item_ref":"CLAP005A"}
    clap_cla_placement_distance         FLOAT,                      -- metadata={"item_ref":"CLAP011A"}
    clap_cla_placement_provider         NVARCHAR(48),               -- metadata={"item_ref":"CLAP007A"}
    clap_cla_placement_postcode         NVARCHAR(8),                -- metadata={"item_ref":"CLAP008A"}
    clap_cla_placement_end_date         DATETIME,                   -- metadata={"item_ref":"CLAP009A"}
    clap_cla_placement_change_reason    NVARCHAR(100)               -- metadata={"item_ref":"CLAP010A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_placement (
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



SELECT DISTINCT 
	CLA_PLACEMENT.PLACEMENTADDRESSID            AS "clap_cla_placement_id", --metadata={"item_ref:"CLAP001A"}
	CLA_PLACEMENT.EOCSTARTDATE                  AS "clap_cla_placement_start_date", --metadata={"item_ref:"CLAP003A"}
	CASE WHEN CLA_PLACEMENT.PLACEMENTTYPECODE = 'APP_ADOPT'        THEN 'A3'
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
    END                                         AS "clap_cla_placement_type", --metadata={"item_ref:"CLAP004A"}
	ADDRESS.UPRN                                AS "clap_cla_placement_urn", --metadata={"item_ref:"CLAP005A"}
	ROUND((EARTH_DISTANCE(LL_TO_EARTH(ADDRESS.LATITUDE,ADDRESS.LONGITUDE),LL_TO_EARTH(HOME_ADDRESS.LATITUDE,HOME_ADDRESS.LONGITUDE)) / 1609.344) ::NUMERIC,2) AS "clap_cla_placement_distance", --metadata={"item_ref:"CLAP011A"}
	CLA_PLACEMENT.PERIODOFCAREID                AS "clap_cla_id", --metadata={"item_ref:"CLAP012A"}
	CLA_PLACEMENT.PLACEMENTPROVISIONCODE        AS  "clap_cla_placement_provider", --metadata={"item_ref:"CLAP007A"}
	ADDRESS.POSTCODE                            AS "clap_cla_placement_postcode", --metadata={"item_ref:"CLAP008A"}
	CLA_PLACEMENT.EOCENDDATE                    AS "clap_cla_placement_end_date", --metadata={"item_ref:"CLAP009A"}
	CLA_PLACEMENT_END.PLACEMENTCHANGEREASONCODE AS "clap_cla_placement_change_reason", --metadata={"item_ref:"CLAP010A"}
	CLA_PLACEMENT.PERSONID                  AS "clap_person_id"                    -- metadata={"item_ref":"CLAP013A"}

FROM  CLA_PLACEMENT	
LEFT JOIN ADDRESS ON CLA_PLACEMENT.CARERID	= ADDRESS.CARERID AND CLA_PLACEMENT.CARERTYPE	= ADDRESS.CARERTYPE
             AND CLA_PLACEMENT.PLACEMENTPOSTCODE = ADDRESS.POSTCODE
             AND CLA_PLACEMENT.EOCSTARTDATE >= ADDRESS.STARTDATE AND COALESCE(CLA_PLACEMENT.EOCSTARTDATE,CURRENT_DATE) <= COALESCE(ADDRESS.ENDDATE,CURRENT_DATE)
             AND COALESCE(CLA_PLACEMENT.EOCENDDATE,CURRENT_DATE) <= COALESCE(ADDRESS.ENDDATE,CURRENT_DATE) + INTERVAL '1 day' AND COALESCE(CLA_PLACEMENT.EOCENDDATE,CURRENT_DATE) >= ADDRESS.STARTDATE
LEFT JOIN ADDRESS HOME_ADDRESS ON CLA_PLACEMENT.PERSONID	= HOME_ADDRESS.CARERID AND HOME_ADDRESS.TYPE = 'Home'
             AND CLA_PLACEMENT.EOCSTARTDATE >= HOME_ADDRESS.STARTDATE - INTERVAL '1 day' AND COALESCE(CLA_PLACEMENT.EOCSTARTDATE,CURRENT_DATE) <= COALESCE(HOME_ADDRESS.ENDDATE,CURRENT_DATE)
             AND COALESCE(CLA_PLACEMENT.EOCENDDATE,CURRENT_DATE) <= COALESCE(HOME_ADDRESS.ENDDATE,CURRENT_DATE) + INTERVAL '1 day' AND COALESCE(CLA_PLACEMENT.EOCENDDATE,CURRENT_DATE) >= HOME_ADDRESS.STARTDATE
LEFT JOIN LATERAL (
                  SELECT
                      *
                  FROM CLA_PLACEMENT_EPISODES CLAP
                  WHERE CLA_PLACEMENT.PERSONID = CLAP.PERSONID
                    AND CLA_PLACEMENT.PERSONID = CLAP.PERSONID
                    AND CLA_PLACEMENT.PERSONID = CLAP.PERSONID
                    AND CLA_PLACEMENT.EOCENDDATE >= CLAP.EOCENDDATE
                  ORDER BY CLAP.EOCENDDATE DESC 
                  FETCH FIRST 1 ROW ONLY 
                  ) CLA_PLACEMENT_END ON TRUE
;



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_placement ADD CONSTRAINT FK_ssd_clap_to_clae 
FOREIGN KEY (clap_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clap_cla_placement_urn ON ssd_development.ssd_cla_placement (clap_cla_placement_urn);
CREATE NONCLUSTERED INDEX idx_ssd_clap_cla_id ON ssd_development.ssd_cla_placement(clap_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_start_date ON ssd_development.ssd_cla_placement(clap_cla_placement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_end_date ON ssd_development.ssd_cla_placement(clap_cla_placement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_postcode ON ssd_development.ssd_cla_placement(clap_cla_placement_postcode);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_type ON ssd_development.ssd_cla_placement(clap_cla_placement_type);

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_cla_reviews"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - ssd_cla_episodes
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_reviews;
IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_reviews (
    clar_cla_review_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAR001A"}
    clar_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
    clar_cla_review_due_date        DATETIME,                   -- metadata={"item_ref":"CLAR003A"}
    clar_cla_review_date            DATETIME,                   -- metadata={"item_ref":"CLAR004A"}
    clar_cla_review_cancelled       NCHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
    clar_cla_review_participation   NVARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
    );
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
) 


-- SELECT...


-- <snip>
 
    (SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
        AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
        THEN ISNULL(fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC, '') END)) 
                                                    AS clar_cla_review_participation
-- <snip>
 
-- WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'

-- AND
--     (fcr.MEETING_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
--     OR fcr.MEETING_DTTM IS NULL)
 
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE CAST(p.pers_person_id AS INT) = fcr.DIM_PERSON_ID -- #DtoI-1799
--     )    ;



-- -- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_cla_reviews ADD CONSTRAINT FK_ssd_clar_to_clae 
FOREIGN KEY (clar_cla_id) REFERENCES ssd_development.ssd_cla_episodes(clae_cla_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clar_cla_id ON ssd_development.ssd_cla_reviews(clar_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_due_date ON ssd_development.ssd_cla_reviews(clar_cla_review_due_date);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_date ON ssd_development.ssd_cla_reviews(clar_cla_review_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_previous_permanence"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_previous_permanence') IS NOT NULL DROP TABLE ssd_development.ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;



-- META-ELEMENT: {"type": "create_table"}     
CREATE TABLE ssd_development.ssd_cla_previous_permanence (
    lapp_table_id                               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LAPP001A"}
    lapp_person_id                              NVARCHAR(48),   -- metadata={"item_ref":"LAPP002A"}
    lapp_previous_permanence_option             NVARCHAR(200),  -- metadata={"item_ref":"LAPP003A"}
    lapp_previous_permanence_la                 NVARCHAR(100),  -- metadata={"item_ref":"LAPP004A"}
    lapp_previous_permanence_order_date         NVARCHAR(10)    -- metadata={"item_ref":"LAPP005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date

           )


SELECT
    IRO_REVIEW.FORMID         AS "clar_cla_review_id",           --metadata={"item_ref:"CLAR001A"}
	CLA_REVIEW.PERIODOFCAREID AS "clar_cla_id",                  --metadata={"item_ref:"CLAR011A"}
	PREVIOUSR.NEXT_REVIEW     AS "clar_cla_review_due_date",     --metadata={"item_ref:"CLAR003A"}
	CLA_REVIEW.DATE_OF_REVIEW AS "clar_cla_review_date",         --metadata={"item_ref:"CLAR004A"}
	'N'                       AS "clar_cla_review_cancelled",    --metadata={"item_ref:"CLAR012A"}
	IRO_REVIEW.PARTICIPATION  AS "clar_cla_review_participation" --metadata={"item_ref:"CLAR007A"}
FROM CLA_REVIEW
LEFT JOIN LATERAL (
           SELECT
               *
           FROM  CLA_REVIEW PREVIOUSR
           WHERE PREVIOUSR.PERSONID = CLA_REVIEW.PERSONID
                 AND PREVIOUSR.PERIODOFCAREID = CLA_REVIEW.PERIODOFCAREID
                 AND PREVIOUSR.DATE_OF_REVIEW < CLA_REVIEW.DATE_OF_REVIEW
           ORDER BY PREVIOUSR.DATE_OF_REVIEW DESC
           FETCH FIRST 1 ROW ONLY) PREVIOUSR ON TRUE 
LEFT JOIN (
 	      SELECT
	     	  FAPV.ANSWERFORSUBJECTID 	AS PERSONID,
	          FAPV.INSTANCEID 			AS FORMID,
	          MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'howWasTheChildAbleToContributeTheirViewsToTheReview'
		          THEN FAPV.SHORTANSWERVALUE
	          END)                      AS PARTICIPATION,
	          MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'dateOfMeeting'
		          THEN FAPV.ANSWERVALUE
	          END)::DATE                AS DATE_OF_MEETING       
	     FROM FORMANSWERPERSONVIEW FAPV
         WHERE FAPV.DESIGNGUID IN ('79f3495c-134f-4e69-b00f-7621925419f7') --Independent Reviewing Officer: Quality assurance
            AND FAPV.INSTANCESTATE = 'COMPLETE'
            AND FAPV.designsubname = 'Child/young person in care review' 
            AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
         GROUP BY FAPV.ANSWERFORSUBJECTID,
	              FAPV.INSTANCEID ) IRO_REVIEW ON IRO_REVIEW.PERSONID = CLA_REVIEW.PERSONID
	                                    AND IRO_REVIEW.DATE_OF_MEETING = CLA_REVIEW.DATE_OF_REVIEW
	                                   
;



-- -- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_previous_permanence ADD CONSTRAINT FK_ssd_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_lapp_person_id ON ssd_development.ssd_cla_previous_permanence(lapp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lapp_previous_permanence_option ON ssd_development.ssd_cla_previous_permanence(lapp_previous_permanence_option);


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_cla_care_plan"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:   
-- Dependencies:
-- - ssd_person
-- - #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_pre_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_pre_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_pre_cla_care_plan;


 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_care_plan (
    lacp_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"LACP001A"}
    lacp_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LACP007A"}
    lacp_cla_care_plan_start_date   DATETIME,                   -- metadata={"item_ref":"LACP004A"}
    lacp_cla_care_plan_end_date     DATETIME,                   -- metadata={"item_ref":"LACP005A"}
    lacp_cla_care_plan_json         NVARCHAR(1000)              -- metadata={"item_ref":"LACP003A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)


-- SELECT...

--     (
--         SELECT  -- Combined _json field with 'ICP' responses
--             -- SSD standard 
--             -- all keys in structure regardless of data presence ISNULL() not NULLIF()
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END, '')), NULL) AS REMAINSUP,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN1M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN6M,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURNEV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTRELFR,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTFOST18,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RESPLMT,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END, '')), NULL) AS SUPPLIV,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END, '')), NULL) AS ADOPTION,
--             COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END, '')), NULL) AS OTHERPLN
--         FROM
--             -- #ssd_TMP_PRE_cla_care_plan tmp_cpl
--             ssd_development.ssd_pre_cla_care_plan tmp_cpl

--         WHERE
--             tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
 
--         GROUP BY tmp_cpl.DIM_PERSON_ID
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--     ) AS lacp_cla_care_plan_json
 
-- FROM
--     HDM.Child_Social.FACT_CARE_PLANS AS fcp


-- WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
--     AND EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
--     );
 



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_cla_care_plan ADD CONSTRAINT FK_ssd_lacp_person_id
FOREIGN KEY (lacp_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_lacp_person_id ON ssd_development.ssd_cla_care_plan(lacp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_start_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_end_date ON ssd_development.ssd_cla_care_plan(lacp_cla_care_plan_end_date);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_cla_visits"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_cla_visits', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_cla_visits;
IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_cla_visits (
    clav_cla_visit_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLAV001A"}
    clav_cla_id                 NVARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
    clav_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
    clav_cla_visit_date         DATETIME,                   -- metadata={"item_ref":"CLAV003A"}
    clav_cla_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
    clav_cla_visit_seen_alone   NCHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 
SELECT DISTINCT 
	FAPV.INSTANCEID       AS  "clav_cla_visit_id",       --metadata={"item_ref:"CLAV001A"}
	CLA.PERIODOFCAREID    AS "clav_cla_id",              --metadata={"item_ref:"CLAV007A"}
	FAPV.PERSONID         AS "clav_person_id",           --metadata={"item_ref:"CLAV008A"}
	FAPV.VISIT_DATE       AS "clav_cla_visit_date",      --metadata={"item_ref:"CLAV003A"}
	FAPV.CHILD_SEEN       AS "clav_cla_visit_seen",      --metadata={"item_ref:"CLAV004A"}
	FAPV.CHILD_SEEN_ALONE AS "clav_cla_visit_seen_alone" --metadata={"item_ref:"CLAV005A"}
FROM (
    SELECT
        FAPV.INSTANCEID,
	    FAPV.ANSWERFORSUBJECTID AS PERSONID,
	    MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_dateOfVisit'
		       THEN FAPV.DATEANSWERVALUE
	        END)                AS VISIT_DATE,
	    MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeen'
		       THEN CASE WHEN FAPV.ANSWERVALUE = 'Yes'
		                  THEN 'Y'
		                  ELSE 'N'
		            END     
	       END)                 AS CHILD_SEEN,
    	MAX(CASE
		       WHEN FAPV.CONTROLNAME = 'AnnexAReturn_wasTheChildSeenAlone'
		       THEN CASE WHEN FAPV.ANSWERVALUE = 'Child seen alone'
		                 THEN 'Y'
		                 ELSE 'N'
		            END     
	        END)                AS  CHILD_SEEN_ALONE
    FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('7b04f2b4-1170-44a2-8f2f-111d51d8a90f') --Child: Visit
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.DESIGNSUBNAME = 'Child in care'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY 
        FAPV.ANSWERFORSUBJECTID,
        FAPV.INSTANCEID
    ) FAPV
LEFT JOIN CLAPERIODOFCAREVIEW CLA ON CLA.PERSONID = FAPV.PERSONID
      AND FAPV.VISIT_DATE >= CLA.ADMISSIONDATE AND FAPV.VISIT_DATE <= COALESCE(CLA.DISCHARGEDATE,CURRENT_DATE)  
;



-- -- META-ELEMENT: {"type": "create_fk"}   
ALTER TABLE ssd_development.ssd_cla_visits ADD CONSTRAINT FK_ssd_clav_person_id
FOREIGN KEY (clav_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clav_person_id ON ssd_development.ssd_cla_visits(clav_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clav_visit_date ON ssd_development.ssd_cla_visits(clav_cla_visit_date);
CREATE NONCLUSTERED INDEX idx_ssd_clav_cla_id ON ssd_development.ssd_cla_visits(clav_cla_id);

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_sdq_scores"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies:
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_sdq_scores;
IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CSDQ001A"} 
    csdq_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CSDQ002A"}
    csdq_sdq_completed_date     DATETIME,                   -- metadata={"item_ref":"CSDQ003A"}
    csdq_sdq_score              INT,                        -- metadata={"item_ref":"CSDQ005A"}
    csdq_sdq_reason             NVARCHAR(100)               -- metadata={"item_ref":"CSDQ004A", "item_status":"P"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_sdq_scores (
    csdq_table_id, 
    csdq_person_id, 
    csdq_sdq_completed_date, 
    csdq_sdq_score, 
    csdq_sdq_reason
)

SELECT
    INSTANCEID               AS "csdq_table_id",           --metadata={"item_ref:"CSDQ001A"}
    PERSONID                 AS "csdq_person_id",          --metadata={"item_ref:"CSDQ002A"}
    completed_date           AS "csdq_sdq_completed_date", --metadata={"item_ref:"CSDQ003A"}
    CASE WHEN REASON = 'No form returned as child was aged under 4 or over 17 at date of latest assessment'   THEN 'SDQ1'
         WHEN REASON = 'Carer(s) refused to complete and return questionnaire'                                THEN 'SDQ2'
         WHEN REASON = 'Not possible to complete the questionnaire due to severity of the child’s disability' THEN 'SDQ3'
         WHEN REASON = 'Other'                                                                                THEN 'SDQ4'
         WHEN REASON = 'Child or young person refuses to allow an SDQ to be completed'                        THEN 'SDQ5'
    END                      AS "csdq_sdq_reason",         --metadata={"item_ref:"CSDQ004A"}
    SCORE                    AS "csdq_sdq_score"           --metadata={"item_ref:"CSDQ005A"}
FROM (
    SELECT 
	    FAPV.INSTANCEID                AS INSTANCEID, 
	    FAPV.ANSWERFORSUBJECTID        AS PERSONID,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = '903Return_dateOfLatestSDQRecord'
		          THEN FAPV.ANSWERVALUE
	    END)::DATE                      AS completed_date ,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = '903Return_reasonForNotSubmittingStrengthsAndDifficultiesQuestionnaireInPeriod'
		          THEN FAPV.ANSWERVALUE
	    END)                            AS REASON,
	    MAX(CASE
		          WHEN FAPV.CONTROLNAME = 'youngPersonsStrengthsAndDifficultiesQuestionnaireScore'
		          THEN FAPV.ANSWERVALUE
	   END)                             AS SCORE 

	FROM  FORMANSWERPERSONVIEW FAPV
    WHERE FAPV.DESIGNGUID IN ('fb7f6ffc-e8a1-4b45-8eaa-356a5be33895') --Child in Care: Strengths and difficulties questionnaire scores
       AND FAPV.INSTANCESTATE = 'COMPLETE'
       AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY  FAPV.INSTANCEID,
              FAPV.ANSWERFORSUBJECTID) FAPV
             
;


-- META-ELEMENT: {"type": "create_fk"}    
ALTER TABLE ssd_development.ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
FOREIGN KEY (csdq_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_csdq_person_id ON ssd_development.ssd_sdq_scores(csdq_person_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_missing"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_missing', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_missing;
IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_missing (
    miss_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"MISS001A"}
    miss_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"MISS002A"}
    miss_missing_episode_start_date DATETIME,                   -- metadata={"item_ref":"MISS003A"}
    miss_missing_episode_type       NVARCHAR(100),              -- metadata={"item_ref":"MISS004A"}
    miss_missing_episode_end_date   DATETIME,                   -- metadata={"item_ref":"MISS005A"}
    miss_missing_rhi_offered        NVARCHAR(2),                -- metadata={"item_ref":"MISS006A", "expected_data":["N","Y","NA", NULL]}                
    miss_missing_rhi_accepted       NVARCHAR(2)                 -- metadata={"item_ref":"MISS007A"}
);


-- META-ELEMENT: {"type": "insert_data"} 
INSERT INTO ssd_development.ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,                   
    miss_missing_rhi_accepted    
)


SELECT
	INSTANCEID                      AS "miss_table_id",                   --metadata={"item_ref:"MISS001A"}
	SUBJECTID                       AS "miss_person_id",                  --metadata={"item_ref:"MISS002A"}
	MISS_MISSING_EPISODE_START_DATE AS "miss_missing_episode_start_date", --metadata={"item_ref:"MISS003A"}
	MISS_MISSING_EPISODE_TYPE       AS "miss_missing_episode_type",       --metadata={"item_ref:"MISS004A"}
	MISS_MISSING_EPISODE_END_DATE   AS "miss_missing_episode_end_date",   --metadata={"item_ref:"MISS005A"}
	MISS_MISSING_RHI_OFFERED        AS "miss_missing_rhi_offered",        --metadata={"item_ref:"MISS006A"}
	MISS_MISSING_RHI_ACCEPTED       AS "miss_missing_rhi_accepted"        --metadata={"item_ref:"MISS007A"}

FROM (
    SELECT 
        FAPV.INSTANCEID,
        FAPV.SUBJECTID,
        FAPV.PAGETITLE,
        MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('DATECHILDLASTSEEN%')
			    THEN FAPV.DATEANSWERVALUE
		    END) AS MISS_MISSING_EPISODE_START_DATE,
	    MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('ABSENCETYPE%')
		    	THEN FAPV.ANSWERVALUE
	    	END)	AS MISS_MISSING_EPISODE_TYPE,
	   MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('FOUNDREPORTDATE%')
			    THEN FAPV.DATEANSWERVALUE
		   END) AS	MISS_MISSING_EPISODE_END_DATE,
	   MAX(CASE
		    	WHEN UPPER(FAPV.CONTROLNAME) LIKE ('HASARETURNHOMEINTERVIEWBEENOFFERED%')
			    THEN FAPV.ANSWERVALUE
		   END)	AS MISS_MISSING_RHI_OFFERED,
	   MAX(CASE
			    WHEN UPPER(FAPV.CONTROLNAME) LIKE ('HASTHERETURNHOMEINTERVIEWBEENACCEPTED%')
			    THEN FAPV.ANSWERVALUE
		   END)	AS MISS_MISSING_RHI_ACCEPTED		
    

    FROM FORMANSWERPERSONVIEW FAPV

    WHERE FAPV.DESIGNGUID IN ('e112bee8-4f50-4904-8ebc-842e2fd33994') --Missing: Child reported missing
        AND FAPV.INSTANCESTATE = 'COMPLETE'
        AND FAPV.ANSWERFORSUBJECTID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
    GROUP BY FAPV.INSTANCEID,
             FAPV.SUBJECTID,
             FAPV.PAGETITLE) AS FAPV
;



-- META-ELEMENT: {"type": "create_fk"}  
ALTER TABLE ssd_development.ssd_missing ADD CONSTRAINT FK_ssd_missing_to_person
FOREIGN KEY (miss_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_miss_person_id        ON ssd_development.ssd_missing(miss_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_start    ON ssd_development.ssd_missing(miss_missing_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_end      ON ssd_development.ssd_missing(miss_missing_episode_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_offered      ON ssd_development.ssd_missing(miss_missing_rhi_offered);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_accepted     ON ssd_development.ssd_missing(miss_missing_rhi_accepted);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_care_leavers"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:   
--             This table the cohort of children who are preparing to leave care, typically 15/16/17yrs+; 
--             Not those who are finishing a period of care. 
--             clea_care_leaver_eligibility == LAC for 13wks+(since 14yrs)+LAC since 16yrs 

-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- - HDM.Child_Social.FACT_CLA_CARE_LEAVERS
-- - HDM.Child_Social.DIM_CLA_ELIGIBILITY
-- - HDM.Child_Social.FACT_CARE_PLANS
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_care_leavers', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_care_leavers;
IF OBJECT_ID('tempdb..#ssd_care_leavers', 'U') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_care_leavers
(
    clea_table_id                           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLEA001A"}
    clea_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"CLEA002A"}
    clea_care_leaver_eligibility            NVARCHAR(100),              -- metadata={"item_ref":"CLEA003A", "info":"LAC for 13wks(since 14yrs)+LAC since 16yrs"}
    clea_care_leaver_in_touch               NVARCHAR(100),              -- metadata={"item_ref":"CLEA004A"}
    clea_care_leaver_latest_contact         DATETIME,                   -- metadata={"item_ref":"CLEA005A"}
    clea_care_leaver_accommodation          NVARCHAR(100),              -- metadata={"item_ref":"CLEA006A"}
    clea_care_leaver_accom_suitable         NVARCHAR(100),              -- metadata={"item_ref":"CLEA007A"}
    clea_care_leaver_activity               NVARCHAR(100),              -- metadata={"item_ref":"CLEA008A"}
    clea_pathway_plan_review_date           DATETIME,                   -- metadata={"item_ref":"CLEA009A"}
    clea_care_leaver_personal_advisor       NVARCHAR(100),              -- metadata={"item_ref":"CLEA010A"}
    clea_care_leaver_allocated_team         NVARCHAR(48),              -- metadata={"item_ref":"CLEA011A"}
    clea_care_leaver_worker_id              NVARCHAR(100)               -- metadata={"item_ref":"CLEA012A"}
);



-- META-ELEMENT: {"type": "insert_data"}  
-- IF using a CTE/Pre-processing TMP table add this in here


INSERT INTO ssd_development.ssd_care_leavers
(
    clea_table_id,
    clea_person_id,
    clea_care_leaver_eligibility,
    clea_care_leaver_in_touch,
    clea_care_leaver_latest_contact,
    clea_care_leaver_accommodation,
    clea_care_leaver_accom_suitable,
    clea_care_leaver_activity,
    clea_pathway_plan_review_date,
    clea_care_leaver_personal_advisor,                  
    clea_care_leaver_allocated_team,
    clea_care_leaver_worker_id            
)
 
SELECT
	CARELEAVER.CARELEAVERID               AS "clea_table_id",                         --metadata={"item_ref:"CLEA001A"}
	CARELEAVER.PERSONID                   AS "clea_person_id",                        --metadata={"item_ref:"CLEA002A"}
	CARELEAVER.ELIGIBILITY                AS "clea_care_leaver_eligibility",         --metadata={"item_ref:"CLEA003A"}
	CARELEAVER.INTOUCHCODE                AS "clea_care_leaver_in_touch",             --metadata={"item_ref:"CLEA004A"}
	CARELEAVER.CONTACTDATE::DATE          AS "clea_care_leaver_latest_contact",       --metadata={"item_ref:"CLEA005A"}
	CARELEAVER.ACCOMODATIONCODE           AS  "clea_care_leaver_accommodation",       --metadata={"item_ref:"CLEA006A"}
	CARELEAVER.ACCOMSUITABLE              AS "clea_care_leaver_accom_suitable",       --metadata={"item_ref:"CLEA007A"}
	CARELEAVER.MAINACTIVITYCODE           AS "clea_care_leaver_activity",             --metadata={"item_ref:"CLEA008A"}
	CARELEAVER_REVIEW.REIEW_DATE          AS "clea_pathway_plan_review_date",         --metadata={"item_ref:"CLEA009A"}
	WORKER.ALLOCATED_WORKER               AS "clea_care_leaver_personal_advisor",     --metadata={"item_ref:"CLEA010A"}
	TEAM.ALLOCATED_TEAM                   AS  "clea_care_leaver_allocated_team", --metadata={"item_ref:"CLEA011A"}
	WORKER.ALLOCATED_WORKER               AS "clea_care_leaver_worker_id"           --metadata={"item_ref:"CLEA012A"}
	
FROM (
	SELECT
	    CARELEAVER.CARELEAVERID,
	    CARELEAVER.PERSONID,
	    CARELEAVER.ELIGIBILITY,
	    CARELEAVER.INTOUCHCODE,
	    CARELEAVER.CONTACTDATE,
	    CARELEAVER.ACCOMODATIONCODE,
	    CASE WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered suitable'   THEN 1
	         WHEN CARELEAVER.ACCOMSUITABLE = 'Accommodation considered unsuitable' THEN 2
	    END    AS ACCOMSUITABLE,
	    CARELEAVER.MAINACTIVITYCODE,
	    RANK () OVER (PARTITION BY CARELEAVER.PERSONID ORDER BY CARELEAVER.CONTACTDATE DESC) AS LATEST_RECORD
	    FROM CLACARELEAVERDETAILSVIEW CARELEAVER
	    WHERE CARELEAVER.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
     	) CARELEAVER
LEFT JOIN CARELEAVER_REVIEW ON CARELEAVER_REVIEW.PERSONID = CARELEAVER.PERSONID	 AND CARELEAVER_REVIEW.LATEST_REVIEW = 1
LEFT JOIN WORKER ON WORKER.PERSONID = CARELEAVER.PERSONID 
                         AND CARELEAVER.CONTACTDATE >= WORKER.WORKER_START_DATE
                         AND CARELEAVER.CONTACTDATE <= COALESCE(WORKER.WORKER_END_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = CARELEAVER.PERSONID 
                         AND CARELEAVER.CONTACTDATE >= TEAM.TEAM_START_DATE
                         AND CARELEAVER.CONTACTDATE <= COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                         

WHERE LATEST_RECORD = 1
;




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_care_leavers ADD CONSTRAINT FK_ssd_care_leavers_person
FOREIGN KEY (clea_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_clea_person_id                    ON ssd_development.ssd_care_leavers(clea_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clea_care_leaver_latest_contact   ON ssd_development.ssd_care_leavers(clea_care_leaver_latest_contact);
CREATE NONCLUSTERED INDEX idx_ssd_clea_pathway_plan_review_date     ON ssd_development.ssd_care_leavers(clea_pathway_plan_review_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_permanence"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
--         DEV: 181223: Assumed that only one permanence order per child. 
--         - In order to handle/reflect the v.rare cases where this has broken down, further work is required.
--         DEV: Some fields need spec checking for datatypes e.g. perm_adopted_by_carer_flag and others
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_ADOPTION
-- - HDM.Child_Social.FACT_CLA_PLACEMENT
-- - HDM.Child_Social.FACT_LEGAL_STATUS
-- - HDM.Child_Social.FACT_CARE_EPISODES
-- - HDM.Child_Social.FACT_CLA
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_permanence', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_permanence;
IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_permanence (
    perm_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PERM001A"}
    perm_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"PERM002A"}
    perm_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"PERM022A"}
    perm_adm_decision_date          DATETIME,                   -- metadata={"item_ref":"PERM003A"}
    perm_part_of_sibling_group      NCHAR(1),                   -- metadata={"item_ref":"PERM012A"}
    perm_siblings_placed_together   INT,                        -- metadata={"item_ref":"PERM013A"}
    perm_siblings_placed_apart      INT,                        -- metadata={"item_ref":"PERM014A"}
    perm_ffa_cp_decision_date       DATETIME,                   -- metadata={"item_ref":"PERM004A"}              
    perm_placement_order_date       DATETIME,                   -- metadata={"item_ref":"PERM006A"}
    perm_matched_date               DATETIME,                   -- metadata={"item_ref":"PERM008A"}
    perm_adopter_sex                NVARCHAR(48),               -- metadata={"item_ref":"PERM025A"}
    perm_adopter_legal_status       NVARCHAR(100),              -- metadata={"item_ref":"PERM026A"}
    perm_number_of_adopters         INT,                        -- metadata={"item_ref":"PERM027A"}
    perm_placed_for_adoption_date   DATETIME,                   -- metadata={"item_ref":"PERM007A"}             
    perm_adopted_by_carer_flag      NCHAR(1),                   -- metadata={"item_ref":"PERM021A"}
    perm_placed_foster_carer_date   DATETIME,                   -- metadata={"item_ref":"PERM011A"}
    perm_placed_ffa_cp_date         DATETIME,                   -- metadata={"item_ref":"PERM009A"}
    perm_placement_provider_urn     NVARCHAR(48),               -- metadata={"item_ref":"PERM015A"}  
    perm_decision_reversed_date     DATETIME,                   -- metadata={"item_ref":"PERM010A"}                  
    perm_decision_reversed_reason   NVARCHAR(100),              -- metadata={"item_ref":"PERM016A"}
    perm_permanence_order_date      DATETIME,                   -- metadata={"item_ref":"PERM017A"}              
    perm_permanence_order_type      NVARCHAR(100),              -- metadata={"item_ref":"PERM018A"}        
    perm_adoption_worker_id         NVARCHAR(100)               -- metadata={"item_ref":"PERM023A"}
    
);

-- META-ELEMENT: {"type": "insert_data"}  
-- CTE to rank permanence rows for each person


INSERT INTO ssd_development.ssd_permanence (
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_adopter_sex,
    perm_adopter_legal_status,
    perm_number_of_adopters,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_foster_carer_date,
    perm_placed_ffa_cp_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker_id
)  


-- SELECT...

-- WHERE rn = 1
-- AND EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = perm_person_id -- this a NVARCHAR(48) equality link
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_permanence ADD CONSTRAINT FK_ssd_perm_person_id
FOREIGN KEY (perm_person_id) REFERENCES ssd_development.ssd_cla_episodes(clae_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_perm_person_id            ON ssd_development.ssd_permanence(perm_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_perm_adm_decision_date    ON ssd_development.ssd_permanence(perm_adm_decision_date);
CREATE NONCLUSTERED INDEX idx_ssd_perm_order_date           ON ssd_development.ssd_permanence(perm_permanence_order_date);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_professionals"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - @CaseloadLastSept30th
-- - @CaseloadTimeframeStartDate
-- - @ssd_timeframe_years
-- - HDM.Child_Social.DIM_WORKER
-- - HDM.Child_Social.FACT_REFERRALS
-- - ssd_cin_episodes (if counting caseloads within SSD timeframe)
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_professionals', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_professionals;
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_professionals (
    prof_professional_id                NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PROF001A"}
    prof_staff_id                       NVARCHAR(48),               -- metadata={"item_ref":"PROF010A"}
    prof_professional_name              NVARCHAR(300),              -- metadata={"item_ref":"PROF013A"}
    prof_social_worker_registration_no  NVARCHAR(48),               -- metadata={"item_ref":"PROF002A"}
    prof_agency_worker_flag             NCHAR(1),                   -- metadata={"item_ref":"PROF014A", "item_status": "P", "info":"Not available in SSD V1"}
    prof_professional_job_title         NVARCHAR(500),              -- metadata={"item_ref":"PROF007A"}
    prof_professional_caseload          INT,                        -- metadata={"item_ref":"PROF008A", "item_status": "T"}             
    prof_professional_department        NVARCHAR(100),              -- metadata={"item_ref":"PROF012A"}
    prof_full_time_equivalency          FLOAT                       -- metadata={"item_ref":"PROF011A"}
);


-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_professionals (
    prof_professional_id, 
    prof_staff_id, 
    prof_professional_name,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)

SELECT
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "prof_professional_id",              --metadata={"item_ref:"PROF001A"}
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "prof_staff_id",                     --metadata={"item_ref:"PROF010A"}
	PPR.PROFESSIONALRELATIONSHIPNAME     AS "prof_professional_name",            --metadata={"item_ref:"PROF013A"}
	PROFNUM.REFERENCENUMBER              AS "prof_social_worker_registration_no",--metadata={"item_ref:"PROF002A"}
	NULL                                 AS "prof_professional_job_title",       --metadata={"item_ref:"PROF007A"}
	NULL                                 AS "prof_professional_department",      --metadata={"item_ref:"PROF012A"}
	NULL                                 AS "prof_full_time_equivalency",        --metadata={"item_ref:"PROF011A"}
	NULL                                 AS "prof_agency_worker_flag"            --metadata={"item_ref:"PROF013A"}

FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN REFERENCENUMBERPERSONVIEW PROFNUM ON PROFNUM.PERSONID = PPR.PROFESSIONALRELATIONSHIPPERSONID AND  PROFNUM.REFERENCETYPE = 'Social Work England number'
WHERE PPR.PROFESSIONALRELATIONSHIPPERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;





-- META-ELEMENT: {"type": "create_fk"}    
-- tbc

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_prof_staff_id             ON ssd_development.ssd_professionals (prof_staff_id);
CREATE NONCLUSTERED INDEX idx_ssd_prof_social_worker_reg_no ON ssd_development.ssd_professionals(prof_social_worker_registration_no);

-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_department"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.1:
--             1.0: 
-- Status: [D]ev
-- Remarks: 
-- Dependencies: 
-- - HDM.Child_Social.DIM_DEPARTMENT
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_department', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_department;
IF OBJECT_ID('tempdb..#ssd_department', 'U') IS NOT NULL DROP TABLE #ssd_department;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_department (
    dept_team_id           NVARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
    dept_team_name         NVARCHAR(255), -- metadata={"item_ref":"DEPT1002A"}
    dept_team_parent_id    NVARCHAR(48),  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
    dept_team_parent_name  NVARCHAR(255)  -- metadata={"item_ref":"DEPT1004A"}
);

-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)



SELECT
	ORGANISATIONID AS "dept_team_id",           --metadata={"item_ref:"DEPT1001A"}
	DESCRIPTION    AS "dept_team_name",         --metadata={"item_ref:"DEPT1002A"}
	NULL           AS "dept_team_parent_id",    --metadata={"item_ref:"DEPT1003A"}
	NULL           AS "dept_team_parent_name"  --metadata={"item_ref:"DEPT1004A"}
	
FROM ORGANISATIONVIEW	
WHERE ORGANISATIONCLASS = 'TEAM' AND 
      COALESCE(SECTOR,'') NOT IN  ('CHARITY', 'PRIVATE') AND 
      COALESCE(SECTORSUBTYPE,'') NOT IN ('ADULT_SOCIAL_SERVICES','EDUCATION')
;

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_department ADD CONSTRAINT FK_ssd_dept_team_parent_id 
FOREIGN KEY (dept_team_parent_id) REFERENCES ssd_development.ssd_department(dept_team_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE INDEX idx_ssd_dept_team_id ON ssd_development.ssd_department (dept_team_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_involvements"}
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks:  
--             [TESTING] The below towards v1.0 for ref. only
--             Regarding the increased size/len on invo_professional_team
--             The (truncated)COMMENTS field is only used if:
--                 WORKER_HISTORY_DEPARTMENT_DESC is NULL.
--                 DEPARTMENT_NAME is NULL.
--                 GROUP_NAME is NULL.
--                 COMMENTS contains the keyword %WORKER% or %ALLOC%.
-- Dependencies:
-- - ssd_person
-- - ssd_departments (if obtaining team_name)
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- =============================================================================

 
-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_involvements', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_involvements;
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_involvements (
    invo_involvements_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"INVO005A"}
    invo_professional_id        NVARCHAR(48),               -- metadata={"item_ref":"INVO006A"}
    invo_professional_role_id   NVARCHAR(200),              -- metadata={"item_ref":"INVO007A"}
    invo_professional_team      NVARCHAR(48),               -- metadata={"item_ref":"INVO009A", "info":"This is a truncated field at 255"}
    invo_person_id              NVARCHAR(48),               -- metadata={"item_ref":"INVO011A"}
    invo_involvement_start_date DATETIME,                   -- metadata={"item_ref":"INVO002A"}
    invo_involvement_end_date   DATETIME,                   -- metadata={"item_ref":"INVO003A"}
    invo_worker_change_reason   NVARCHAR(200),              -- metadata={"item_ref":"INVO004A"}
    invo_referral_id            NVARCHAR(48)                -- metadata={"item_ref":"INVO010A"}
);
 
-- META-ELEMENT: {"type": "insert_data"}
INSERT INTO ssd_development.ssd_involvements (
    invo_involvements_id,
    invo_professional_id,
    invo_professional_role_id,
    invo_professional_team,
    invo_person_id,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)



SELECT
	PPR.PERSONRELATIONSHIPRECORDID       AS "invo_involvements_id",        --metadata={"item_ref:"INVO005A"}
	PPR.PROFESSIONALRELATIONSHIPPERSONID AS "invo_professional_id",        --metadata={"item_ref:"INVO006A"}
	PPR.RELATIONSHIPCLASSCODE            AS "invo_professional_role_id",   --metadata={"item_ref:"INVO007A"}
	TEAM.ALLOCATED_TEAM                  AS "invo_professional_team",      --metadata={"item_ref:"INVO009A"}
	PPR.STARTDATE                        AS "invo_involvement_start_date", --metadata={"item_ref:"INVO002A"}
	PPR.CLOSEDATE                        AS "invo_involvement_end_date",  --metadata={"item_ref:"INVO003A"}
	PPR.STARTREASONCODE                  AS "invo_worker_change_reason",   --metadata={"item_ref:"INVO004A"}
	PPR.PERSONID                         AS "invo_person_id",              --metadata={"item_ref:"INVO011A"}
	CIN_EPISODE.CINE_REFERRAL_ID         AS "invo_referral_id"             --metadata={"item_ref:"INVO010A"}

FROM RELATIONSHIPPROFESSIONALVIEW PPR
LEFT JOIN CIN_EPISODE ON PPR.PERSONID =  CIN_EPISODE.CINE_PERSON_ID 
                      AND PPR.STARTDATE >= CIN_EPISODE.CINE_REFERRAL_DATE
                      AND PPR.STARTDATE < COALESCE(CIN_EPISODE.CINE_CLOSE_DATE,CURRENT_DATE)
LEFT JOIN TEAM ON TEAM.PERSONID = PPR.PERSONID 
                         AND COALESCE(PPR.CLOSEDATE,CURRENT_DATE) >= TEAM.TEAM_START_DATE
                         AND PPR.STARTDATE < COALESCE(TEAM.TEAM_END_DATE,CURRENT_DATE)                      
WHERE PPR.PERSONID NOT IN (SELECT E.PERSONID FROM EXCLUSIONS E)
;



-- META-ELEMENT: {"type": "create_fk"} 
-- tbc

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_invo_person_id                ON ssd_development.ssd_involvements(invo_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_invo_professional_role_id     ON ssd_development.ssd_involvements(invo_professional_role_id);
CREATE NONCLUSTERED INDEX idx_ssd_invo_involvement_start_date   ON ssd_development.ssd_involvements(invo_involvement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_involvement_end_date     ON ssd_development.ssd_involvements(invo_involvement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_referral_id              ON ssd_development.ssd_involvements(invo_referral_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_linked_identifiers"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled on a localised basis. 

-- Dependencies: 
-- - Will be LA specific depending on systems/data being linked
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.linked_identifiers', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_linked_identifiers;
IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_linked_identifiers (
    link_table_id               NVARCHAR(48) DEFAULT NEWID() PRIMARY KEY,               -- metadata={"item_ref":"LINK001A"}
    link_person_id              NVARCHAR(48),                               -- metadata={"item_ref":"LINK002A"} 
    link_identifier_type        NVARCHAR(100),                              -- metadata={"item_ref":"LINK003A"}
    link_identifier_value       NVARCHAR(100),                              -- metadata={"item_ref":"LINK004A"}
    link_valid_from_date        DATETIME,                                   -- metadata={"item_ref":"LINK005A"}
    link_valid_to_date          DATETIME                                    -- metadata={"item_ref":"LINK006A"}
);


-- Notes: 
-- By default this object is supplied empty in readiness for manual user input. 
-- Those inserting data must refer to the SSD specification for the standard SSD identifier_types




-- -- Example entry 1

-- -- META-ELEMENT: {"type": "insert_data"}
-- -- link_identifier_type "FORMER_UPN"
-- INSERT INTO ssd_development.ssd_linked_identifiers (
--     link_person_id, 
--     link_identifier_type,
--     link_identifier_value,
--     link_valid_from_date, 
--     link_valid_to_date
-- )
-- SELECT
--     csp.dim_person_id                   AS link_person_id,
--     'Former Unique Pupil Number'        AS link_identifier_type,
--     'SSD_PH'                            AS link_identifier_value,       -- csp.former_upn [TESTING] Removed for compatibility
--     NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
--     NULL                                AS link_valid_to_date           -- NULL for valid_to_date
-- FROM
--     HDM.Child_Social.DIM_PERSON csp
-- WHERE
--     csp.former_upn IS NOT NULL

-- -- AND (link_valid_to_date IS NULL OR link_valid_to_date > GETDATE()) -- We can't yet apply this until source(s) defined. 
-- -- Filter shown here for future reference #DtoI-1806

--  AND EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );

-- -- Example entry 2

-- -- META-ELEMENT: {"type": "insert_data"}
-- -- link_identifier_type "UPN"
-- INSERT INTO ssd_development.ssd_linked_identifiers (
--     link_person_id, 
--     link_identifier_type,
--     link_identifier_value,
--     link_valid_from_date, 
--     link_valid_to_date
-- )
-- SELECT
--     csp.dim_person_id                   AS link_person_id,
--     'Unique Pupil Number'               AS link_identifier_type,
--     'SSD_PH'                            AS link_identifier_value,       -- csp.upn [TESTING] Removed for compatibility
--     NULL                                AS link_valid_from_date,        -- NULL for valid_from_date
--     NULL                                AS link_valid_to_date           -- NULL for valid_to_date
-- FROM
--     HDM.Child_Social.DIM_PERSON csp

-- -- LEFT JOIN -- csp.upn [TESTING] Removed for compatibility
-- --     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

-- WHERE
--     csp.upn IS NOT NULL AND
--     EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_linked_identifiers ADD CONSTRAINT FK_ssd_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_link_person_id        ON ssd_development.ssd_linked_identifiers(link_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_from_date  ON ssd_development.ssd_linked_identifiers(link_valid_from_date);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_to_date    ON ssd_development.ssd_linked_identifiers(link_valid_to_date);


/* END SSD main extract */
/* ********************************************************************************************************** */





/* Start 

        NON-CORE Objects 
        Incl.
        SSDF Other DfE projects (e.g. 1b, 2(a,b) elements extracts 
        
        */


-- META-END





-- META-CONTAINER: {"type": "table", "name": "ssd_s251_finance"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.s251_finance', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_s251_finance;
IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_s251_finance (
    s251_table_id           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"S251001A"}
    s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
    s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
    s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
    s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
    s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
);




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_s251_finance ADD CONSTRAINT FK_ssd_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_development.ssd_cla_placement(clap_cla_placement_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_s251_cla_placement_id ON ssd_development.ssd_s251_finance(s251_cla_placement_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_voice_of_child"}
-- =============================================================================
-- Object Name: ssd_voice_of_child
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"} 
IF OBJECT_ID('ssd_development.voice_of_child', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_voice_of_child;
IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"VOCH007A"}
    voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
    voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
    voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
    voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
    voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
    voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
);


-- SELECT...


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = source_table.DIM_PERSON_ID
--     );



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_voice_of_child ADD CONSTRAINT FK_ssd_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_voice_of_child_voch_person_id ON ssd_development.ssd_voice_of_child(voch_person_id);


-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_pre_proceedings"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================


-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.pre_proceedings', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_pre_proceedings;
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_pre_proceedings (
    prep_table_id                           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"PREP024A"}
    prep_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"PREP001A"}
    prep_plo_family_id                      NVARCHAR(48),               -- metadata={"item_ref":"PREP002A"}
    prep_pre_pro_decision_date              DATETIME,                   -- metadata={"item_ref":"PREP003A"}
    prep_initial_pre_pro_meeting_date       DATETIME,                   -- metadata={"item_ref":"PREP004A"}
    prep_pre_pro_outcome                    NVARCHAR(100),              -- metadata={"item_ref":"PREP005A"}
    prep_agree_stepdown_issue_date          DATETIME,                   -- metadata={"item_ref":"PREP006A"}
    prep_cp_plans_referral_period           INT,                        -- metadata={"item_ref":"PREP007A"}
    prep_legal_gateway_outcome              NVARCHAR(100),              -- metadata={"item_ref":"PREP008A"}
    prep_prev_pre_proc_child                INT,                        -- metadata={"item_ref":"PREP009A"}
    prep_prev_care_proc_child               INT,                        -- metadata={"item_ref":"PREP010A"}
    prep_pre_pro_letter_date                DATETIME,                   -- metadata={"item_ref":"PREP011A"}
    prep_care_pro_letter_date               DATETIME,                   -- metadata={"item_ref":"PREP012A"}
    prep_pre_pro_meetings_num               INT,                        -- metadata={"item_ref":"PREP013A"}
    prep_pre_pro_parents_legal_rep          NCHAR(1),                   -- metadata={"item_ref":"PREP014A"}
    prep_parents_legal_rep_point_of_issue   NCHAR(2),                   -- metadata={"item_ref":"PREP015A"}
    prep_court_reference                    NVARCHAR(48),               -- metadata={"item_ref":"PREP016A"}
    prep_care_proc_court_hearings           INT,                        -- metadata={"item_ref":"PREP017A"}
    prep_care_proc_short_notice             NCHAR(1),                   -- metadata={"item_ref":"PREP018A"}
    prep_proc_short_notice_reason           NVARCHAR(100),              -- metadata={"item_ref":"PREP019A"}
    prep_la_inital_plan_approved            NCHAR(1),                   -- metadata={"item_ref":"PREP020A"}
    prep_la_initial_care_plan               NVARCHAR(100),              -- metadata={"item_ref":"PREP021A"}
    prep_la_final_plan_approved             NCHAR(1),                   -- metadata={"item_ref":"PREP022A"}
    prep_la_final_care_plan                 NVARCHAR(100)               -- metadata={"item_ref":"PREP023A"}
);



-- SELECT...


-- To switch on once source data defined.
-- WHERE EXISTS 
-- ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_development.ssd_person p
--     WHERE p.pers_person_id = plo_source_data_table.DIM_PERSON_ID
--     );





-- META-ELEMENT: {"type": "create_fk"}  
-- #DtoI-1769
ALTER TABLE ssd_development.ssd_pre_proceedings ADD CONSTRAINT FK_ssd_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_prep_person_id                ON ssd_development.ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_prep_pre_pro_decision_date    ON ssd_development.ssd_pre_proceedings (prep_pre_pro_decision_date);
CREATE NONCLUSTERED INDEX idx_ssd_prep_legal_gateway_outcome    ON ssd_development.ssd_pre_proceedings (prep_legal_gateway_outcome);

-- META-END



/* End

        SSDF Other projects elements extracts 
        
        */



/* Start 

        Non-Core Liquid Logic elements extracts (E.g. SEND/EH Module data)
        
        */




-- META-CONTAINER: {"type": "table", "name": "ssd_send"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [P]laceholder
-- Remarks: Have temporarily disabled populating UPN & ULN as these access non-core
--             CMS modules. Can be re-enabled on a localised basis. 
-- Dependencies: 
-- - ssd_person
-- - 
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_send') IS NOT NULL DROP TABLE ssd_development.ssd_send;
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL DROP TABLE #ssd_send;

-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_send (
    send_table_id       NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"SEND001A"}
    send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
    send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
    send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
    send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );

-- META-ELEMENT: {"type": "insert_data"} 
-- for link_identifier_type "FORMER_UPN"
INSERT INTO ssd_development.ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    send_upn_unknown
)



-- SELECT
--     NEWID() AS send_table_id,          -- generate unique id
--     csp.dim_person_id AS send_person_id,
--     'SSD_PH' AS send_upn,               -- csp.upn # only available with Education schema
--     'SSD_PH' AS send_uln,               -- ep.uln # only available with Education schema              
--     'SSD_PH' AS send_upn_unknown      
-- FROM
--     HDM.Child_Social.DIM_PERSON csp

-- -- -- temporarily disabled populating UPN & ULN as these access non-core
-- -- LEFT JOIN
-- --     -- we have to switch to Education schema in order to obtain this
-- --     Education.DIM_PERSON ep ON csp.dim_person_id = ep.dim_person_id

-- WHERE
--     EXISTS (
--         SELECT 1
--         FROM ssd_development.ssd_person p
--         WHERE p.pers_person_id = csp.dim_person_id
--     );
 


-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_development.ssd_person(pers_person_id);

-- META-ELEMENT: {"type": "create_idx"}
CREATE NONCLUSTERED INDEX idx_ssd_send_person_id ON ssd_development.ssd_send (send_person_id);

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_sen_need"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks:
-- Dependencies:
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_sen_need', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_sen_need  ;
IF OBJECT_ID('tempdb..#ssd_sen_need', 'U') IS NOT NULL DROP TABLE #ssd_sen_need  ;
 
 
-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_sen_need (
    senn_table_id                   NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"SENN001A"}
    senn_active_ehcp_id             NVARCHAR(48),               -- metadata={"item_ref":"SENN002A"}
    senn_active_ehcp_need_type      NVARCHAR(100),              -- metadata={"item_ref":"SENN003A"}
    senn_active_ehcp_need_rank      NCHAR(1)                    -- metadata={"item_ref":"SENN004A"}
);
 

-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_development.ssd_ehcp_active_plans(ehcp_active_ehcp_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

-- META-END


-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_requests"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N'ssd_ehcp_requests ';



-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_requests ;
IF OBJECT_ID('tempdb..#ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_requests ;


-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_requests (
    ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCR001A"}
    ehcr_send_table_id              NVARCHAR(48),               -- metadata={"item_ref":"EHCR002A"}
    ehcr_ehcp_req_date              DATETIME,                   -- metadata={"item_ref":"EHCR003A"}
    ehcr_ehcp_req_outcome_date      DATETIME,                   -- metadata={"item_ref":"EHCR004A"}
    ehcr_ehcp_req_outcome           NVARCHAR(100)               -- metadata={"item_ref":"EHCR005A"}
);



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_development.ssd_send(send_table_id);


-- META-ELEMENT: {"type": "create_idx"}
-- tbc

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_assessment"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_assessment ;
IF OBJECT_ID('tempdb..#ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_assessment ;


-- META-ELEMENT: {"type": "create_table"} 
CREATE TABLE ssd_development.ssd_ehcp_assessment (
    ehca_ehcp_assessment_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCA001A"}
    ehca_ehcp_request_id                    NVARCHAR(48),               -- metadata={"item_ref":"EHCA002A"}
    ehca_ehcp_assessment_outcome_date       DATETIME,                   -- metadata={"item_ref":"EHCA003A"}
    ehca_ehcp_assessment_outcome            NVARCHAR(100),              -- metadata={"item_ref":"EHCA004A"}
    ehca_ehcp_assessment_exceptions         NVARCHAR(100)               -- metadata={"item_ref":"EHCA005A"}
);




-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

-- META-END



-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_named_plan"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_named_plan;
IF OBJECT_ID('tempdb..#ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_named_plan;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_named_plan (
    ehcn_named_plan_id              NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCN001A"}
    ehcn_ehcp_asmt_id               NVARCHAR(48),               -- metadata={"item_ref":"EHCN002A"}
    ehcn_named_plan_start_date      DATETIME,                   -- metadata={"item_ref":"EHCN003A"}
    ehcn_named_plan_ceased_date     DATETIME,                   -- metadata={"item_ref":"EHCN004A"}     
    ehcn_named_plan_ceased_reason   NVARCHAR(100)               -- metadata={"item_ref":"EHCN005A"}   
);



-- META-ELEMENT: {"type": "create_fk"} 
ALTER TABLE ssd_development.ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_development.ssd_ehcp_assessment(ehca_ehcp_assessment_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc

-- META-END




-- META-CONTAINER: {"type": "table", "name": "ssd_ehcp_active_plans"}
-- =============================================================================
-- Description: Placeholder structure as source data not common|confirmed
-- Author: D2I
-- Version: 0.1
-- Status: [P]laceholder
-- Remarks: 
-- Dependencies: 
-- - Yet to be defined
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "drop_table"}
IF OBJECT_ID('ssd_development.ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_ehcp_active_plans  ;
IF OBJECT_ID('tempdb..#ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE ssd_development.ssd_ehcp_active_plans (
    ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"EHCP001A"}
    ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
    ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
);



-- META-ELEMENT: {"type": "create_fk"}
ALTER TABLE ssd_development.ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_development.ssd_ehcp_requests(ehcr_ehcp_request_id);

-- META-ELEMENT: {"type": "create_idx"}
-- tbc
    

-- META-END


/* End

        Non-Core Liquid Logic elements extracts 
        
        */





/* Start

        SSD Extract Logging
        */







-- -- META-CONTAINER: {"type": "table", "name": "ssd_extract_log"}
-- -- =============================================================================
-- -- Description: Enable LA extract overview logging
-- -- Author: D2I
-- -- Version: 0.1
-- -- Status: [B]acklog
-- -- Remarks: Not core SSD / Not essential / low priority
-- -- Dependencies: 
-- -- - 
-- -- =============================================================================


-- -- META-ELEMENT: {"type": "drop_table"}
-- IF OBJECT_ID('ssd_development.ssd_extract_log', 'U') IS NOT NULL DROP TABLE ssd_development.ssd_extract_log;
-- IF OBJECT_ID('tempdb..#ssd_extract_log', 'U') IS NOT NULL DROP TABLE #ssd_extract_log;

-- -- META-ELEMENT: {"type": "create_table"}
-- CREATE TABLE ssd_development.ssd_extract_log (
--     table_name           NVARCHAR(255) PRIMARY KEY,     
--     schema_name          NVARCHAR(255),
--     status               NVARCHAR(50), -- status code includes error output + schema.table_name
--     rows_inserted        INT,
--     table_size_kb        INT,
--     has_pk      BIT,
--     has_fks     BIT,
--     index_count          INT,
--     creation_date        DATETIME DEFAULT GETDATE(),
--     null_count           INT,          -- New: count of null values for each table
--     pk_datatype          NVARCHAR(255),-- New: datatype of the PK field
--     additional_detail    NVARCHAR(MAX), -- on hold|future use, e.g. data quality issues detected
--     error_message        NVARCHAR(MAX)  -- on hold|future use, e.g. errors encountered during the process
-- );


-- -- META-ELEMENT: {"type": "insert_data"} 
-- -- GO
-- -- Ensure all variables are declared correctly
-- DECLARE @row_count          INT;
-- DECLARE @table_size_kb      INT;
-- DECLARE @has_pk             BIT;
-- DECLARE @has_fks            BIT;
-- DECLARE @index_count        INT;
-- DECLARE @null_count         INT;
-- DECLARE @pk_datatype        NVARCHAR(255);
-- DECLARE @additional_detail  NVARCHAR(MAX);
-- DECLARE @error_message      NVARCHAR(MAX);
-- DECLARE @table_name         NVARCHAR(255);
-- DECLARE @sql                NVARCHAR(MAX) = N'';   


-- -- Placeholder for table_cursor selection logic
-- DECLARE table_cursor CURSOR FOR
-- SELECT 'ssd_development.ssd_version_log'             UNION ALL -- Admin table, not SSD
-- SELECT 'ssd_development.ssd_person'                  UNION ALL
-- SELECT 'ssd_development.ssd_family'                  UNION ALL
-- SELECT 'ssd_development.ssd_address'                 UNION ALL
-- SELECT 'ssd_development.ssd_disability'              UNION ALL
-- SELECT 'ssd_development.ssd_immigration_status'      UNION ALL
-- SELECT 'ssd_development.ssd_mother'                  UNION ALL
-- SELECT 'ssd_development.ssd_legal_status'            UNION ALL
-- SELECT 'ssd_development.ssd_contacts'                UNION ALL
-- SELECT 'ssd_development.ssd_early_help_episodes'     UNION ALL
-- SELECT 'ssd_development.ssd_cin_episodes'            UNION ALL
-- SELECT 'ssd_development.ssd_cin_assessments'         UNION ALL
-- SELECT 'ssd_development.ssd_assessment_factors'      UNION ALL
-- SELECT 'ssd_development.ssd_cin_plans'               UNION ALL
-- SELECT 'ssd_development.ssd_cin_visits'              UNION ALL
-- SELECT 'ssd_development.ssd_s47_enquiry'             UNION ALL
-- SELECT 'ssd_development.ssd_initial_cp_conference'   UNION ALL
-- SELECT 'ssd_development.ssd_cp_plans'                UNION ALL
-- SELECT 'ssd_development.ssd_cp_visits'               UNION ALL
-- SELECT 'ssd_development.ssd_cp_reviews'              UNION ALL
-- SELECT 'ssd_development.ssd_cla_episodes'            UNION ALL
-- SELECT 'ssd_development.ssd_cla_convictions'         UNION ALL
-- SELECT 'ssd_development.ssd_cla_health'              UNION ALL
-- SELECT 'ssd_development.ssd_cla_immunisations'       UNION ALL
-- SELECT 'ssd_development.ssd_cla_substance_misuse'    UNION ALL
-- SELECT 'ssd_development.ssd_cla_placement'           UNION ALL
-- SELECT 'ssd_development.ssd_cla_reviews'             UNION ALL
-- SELECT 'ssd_development.ssd_cla_previous_permanence' UNION ALL
-- SELECT 'ssd_development.ssd_cla_care_plan'           UNION ALL
-- SELECT 'ssd_development.ssd_cla_visits'              UNION ALL
-- SELECT 'ssd_development.ssd_sdq_scores'              UNION ALL
-- SELECT 'ssd_development.ssd_missing'                 UNION ALL
-- SELECT 'ssd_development.ssd_care_leavers'            UNION ALL
-- SELECT 'ssd_development.ssd_permanence'              UNION ALL
-- SELECT 'ssd_development.ssd_professionals'           UNION ALL
-- SELECT 'ssd_development.ssd_department'              UNION ALL
-- SELECT 'ssd_development.ssd_involvements'            UNION ALL
-- SELECT 'ssd_development.ssd_linked_identifiers'      UNION ALL
-- SELECT 'ssd_development.ssd_s251_finance'            UNION ALL
-- SELECT 'ssd_development.ssd_voice_of_child'          UNION ALL
-- SELECT 'ssd_development.ssd_pre_proceedings'         UNION ALL
-- SELECT 'ssd_development.ssd_send'                    UNION ALL
-- SELECT 'ssd_development.ssd_sen_need'                UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_requests'           UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_assessment'         UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_named_plan'         UNION ALL
-- SELECT 'ssd_development.ssd_ehcp_active_plans';

-- -- Define placeholder tables
-- DECLARE @ssd_placeholder_tables TABLE (table_name NVARCHAR(255));
-- INSERT INTO @ssd_placeholder_tables (table_name)
-- VALUES
--     ('ssd_development.ssd_send'),
--     ('ssd_development.ssd_sen_need'),
--     ('ssd_development.ssd_ehcp_requests'),
--     ('ssd_development.ssd_ehcp_assessment'),
--     ('ssd_development.ssd_ehcp_named_plan'),
--     ('ssd_development.ssd_ehcp_active_plans');

-- DECLARE @dfe_project_placeholder_tables TABLE (table_name NVARCHAR(255));
-- INSERT INTO @dfe_project_placeholder_tables (table_name)
-- VALUES
--     ('ssd_development.ssd_s251_finance'),
--     ('ssd_development.ssd_voice_of_child'),
--     ('ssd_development.ssd_pre_proceedings');

-- -- Open table cursor
-- OPEN table_cursor;

-- -- Fetch next table name from the list
-- FETCH NEXT FROM table_cursor INTO @table_name;

-- -- Iterate table names listed above
-- WHILE @@FETCH_STATUS = 0
-- BEGIN
--     BEGIN TRY
--         -- Generate the schema-qualified table name
--         DECLARE @full_table_name NVARCHAR(511);
--         SET @full_table_name = CASE WHEN @schema_name = '' THEN @table_name ELSE @schema_name + '.' + @table_name END;

--         -- Check if table exists
--         SET @sql = N'SELECT @table_exists = COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name';
--         DECLARE @table_exists INT;
--         EXEC sp_executesql @sql, N'@table_exists INT OUTPUT, @schema_name NVARCHAR(255), @table_name NVARCHAR(255)', @table_exists OUTPUT, @schema_name, @table_name;

--         IF @table_exists = 0
--         BEGIN
--             THROW 50001, 'Table does not exist', 1;
--         END
        
--         -- get row count
--         SET @sql = N'SELECT @row_count = COUNT(*) FROM ' + @full_table_name;
--         EXEC sp_executesql @sql, N'@row_count INT OUTPUT', @row_count OUTPUT;

--         -- get table size in KB
--         SET @sql = N'SELECT @table_size_kb = SUM(reserved_page_count) * 8 FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
--         EXEC sp_executesql @sql, N'@table_size_kb INT OUTPUT', @table_size_kb OUTPUT;

--         -- check for primary key (flag field)
--         SET @sql = N'
--             SELECT @has_pk = CASE WHEN EXISTS (
--                 SELECT 1 
--                 FROM sys.indexes i
--                 WHERE i.is_primary_key = 1 AND i.object_id = OBJECT_ID(''' + @full_table_name + ''')
--             ) THEN 1 ELSE 0 END';
--         EXEC sp_executesql @sql, N'@has_pk BIT OUTPUT', @has_pk OUTPUT;

--         -- check for foreign key(s) (flag field)
--         SET @sql = N'
--             SELECT @has_fks = CASE WHEN EXISTS (
--                 SELECT 1 
--                 FROM sys.foreign_keys fk
--                 WHERE fk.parent_object_id = OBJECT_ID(''' + @full_table_name + ''')
--             ) THEN 1 ELSE 0 END';
--         EXEC sp_executesql @sql, N'@has_fks BIT OUTPUT', @has_fks OUTPUT;

--         -- count index(es)
--         SET @sql = N'
--             SELECT @index_count = COUNT(*)
--             FROM sys.indexes
--             WHERE object_id = OBJECT_ID(''' + @full_table_name + ''')';
--         EXEC sp_executesql @sql, N'@index_count INT OUTPUT', @index_count OUTPUT;

--         -- Get null values count (~overview of data sparcity)
--         DECLARE @col NVARCHAR(255);
--         DECLARE @total_nulls INT;
--         SET @total_nulls = 0;

--         DECLARE column_cursor CURSOR FOR
--         SELECT COLUMN_NAME
--         FROM INFORMATION_SCHEMA.COLUMNS
--         WHERE TABLE_SCHEMA = CASE WHEN @schema_name = '' THEN SCHEMA_NAME() ELSE @schema_name END AND TABLE_NAME = @table_name;

--         OPEN column_cursor;
--         FETCH NEXT FROM column_cursor INTO @col;
--         WHILE @@FETCH_STATUS = 0
--         BEGIN
--             SET @sql = N'SELECT @total_nulls = @total_nulls + (SELECT COUNT(*) FROM ' + @full_table_name + ' WHERE ' + @col + ' IS NULL)';
--             EXEC sp_executesql @sql, N'@total_nulls INT OUTPUT', @total_nulls OUTPUT;
--             FETCH NEXT FROM column_cursor INTO @col;
--         END
--         CLOSE column_cursor;
--         DEALLOCATE column_cursor;

--         SET @null_count = @total_nulls;

--         -- get datatype of the primary key
--         SET @sql = N'
--             SELECT TOP 1 @pk_datatype = c.DATA_TYPE
--             FROM INFORMATION_SCHEMA.COLUMNS c
--             JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu ON c.COLUMN_NAME = kcu.COLUMN_NAME AND c.TABLE_NAME = kcu.TABLE_NAME AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
--             JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
--             WHERE tc.CONSTRAINT_TYPE = ''PRIMARY KEY''
--             AND kcu.TABLE_NAME = @table_name
--             AND kcu.TABLE_SCHEMA = CASE WHEN @schema_name = '''' THEN SCHEMA_NAME() ELSE @schema_name END';
--         EXEC sp_executesql @sql, N'@pk_datatype NVARCHAR(255) OUTPUT, @table_name NVARCHAR(255), @schema_name NVARCHAR(255)', @pk_datatype OUTPUT, @table_name, @schema_name;

--         -- set additional_detail comment to make sense|add detail to expected 
--         -- empty/placholder tables incl. future DfE projects
--         SET @additional_detail = NULL;

--         IF EXISTS (SELECT 1 FROM @ssd_placeholder_tables WHERE table_name = @table_name)
--         BEGIN
--             SET @additional_detail = 'ssd placeholder table';
--         END
--         ELSE IF EXISTS (SELECT 1 FROM @dfe_project_placeholder_tables WHERE table_name = @table_name)
--         BEGIN
--             SET @additional_detail = 'DfE project placeholder table';
--         END

--         -- insert log entry 
--         INSERT INTO ssd_development.ssd_extract_log (
--             table_name, 
--             schema_name, 
--             status, 
--             rows_inserted, 
--             table_size_kb, 
--             has_pk, 
--             has_fks, 
--             index_count, 
--             null_count, 
--             pk_datatype, 
--             additional_detail
--             )
--         VALUES (@table_name, @schema_name, 'Success', @row_count, @table_size_kb, @has_pk, @has_fks, @index_count, @null_count, @pk_datatype, @additional_detail);
--     END TRY
--     BEGIN CATCH
--         -- log any error (this only an indicator of possible issue)
--         -- tricky 
--         SET @error_message = ERROR_MESSAGE();
--         INSERT INTO ssd_development.ssd_extract_log (
--             table_name, 
--             schema_name, 
--             status, 
--             rows_inserted, 
--             table_size_kb, 
--             has_pk, 
--             has_fks, 
--             index_count, 
--             null_count, 
--             pk_datatype, 
--             additional_detail, 
--             error_message
--             )
--         VALUES (@table_name, @schema_name, 'Error', 0, NULL, 0, 0, 0, 0, NULL, @additional_detail, @error_message);
--     END CATCH;

--     -- Fetch next table name
--     FETCH NEXT FROM table_cursor INTO @table_name;
-- END;

-- CLOSE table_cursor;
-- DEALLOCATE table_cursor;

-- SET @sql = N'';



-- -- META-ELEMENT: {"type": "console_output"}
-- -- Forming part of the extract admin results output
-- SELECT * FROM ssd_development.ssd_extract_log ORDER BY rows_inserted DESC;


-- META-ELEMENT: {"type": "console_output"} 
-- output for ref most recent/current ssd version and last update
SELECT * FROM ssd_development.ssd_version_log WHERE is_current = 1;


-- -- META-END


