/*
D2I Dev notes: 
CiN extract 
- 1) set by default to run against tembdb schema #tables. 
- 2) to run this on _perm persistant tables e.g. ESCC SSD Dev schema, search+_replacement all table refs 
    "#ssd_" to "ssd_development.ssd_" except those tables that are marked as _TMP_ pre-processing tables

-- CiN extract logic (in progress)
-- open CiN episode (referral) as at the report date or an open/ closed referral in the past (reporting period) 
-- https://assets.publishing.service.gov.uk/media/636a5cf3e90e076191f300d6/Children_in_need_census_2023_to_2024.pdf
-- data on all cases and episodes for the period from 1 April 2023 to 31 March 2024

Expected ssd_assessment_factors.cinf_assessment_factors field format is JSON ARRAY [ ] 
This in line with notes in ssd_assessment_factors definition "Opt2 flattened Key json structure"
cinf_table_id	cinf_assessment_id	cinf_assessment_factors_json
1000011	        1086942	            ["2B", "4B", "2C", "4C"]
1000017	        1087182	            ["21"]
*/




-- Drop TMP Pre-processing table if it exists
IF OBJECT_ID('tempdb..#split_factors_TMP') IS NOT NULL DROP TABLE #split_factors_TMP;

-- structure for parsed assessment factors
CREATE TABLE #split_factors_TMP (
    cinf_assessment_id NVARCHAR(48),
    Factor NVARCHAR(50)
);
-- Split concatenated factors into individual rows
WITH InitialCTE AS (
    SELECT 
        cinf_assessment_id,

        -- cleans the JSON string by removing [] brackets, double quotes, and extra spaces, replaces commas with spaces
        -- cleaned string then used to generate a list of factors as a single space-separated string
        LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cinf_assessment_factors_json, '[', ''), ']', ''), '"', ''), ' ', ''), ',', ','), ' ', ''))) AS FactorList
    FROM 
        ssd_assessment_factors
), RecursiveCTE AS (
    SELECT 
        cinf_assessment_id,

        -- extract 1st factor from FactorList string by finding substring -before- the 1st comma
        SUBSTRING(FactorList, 1, CHARINDEX(',', FactorList + ',') - 1) AS Factor,

        -- rem the extracted factor and trim spaces to get remaining factors from the FactorList string
        LTRIM(RTRIM(SUBSTRING(FactorList, CHARINDEX(',', FactorList + ',') + 1, LEN(FactorList)))) AS RemainingFactors
    FROM 
        InitialCTE
    WHERE 
        LEN(FactorList) > 0

    UNION ALL

    SELECT 
        -- combines the results from the initial CTE and the recursive CTE
        -- one factor at a time and updates the RemainingFactors string
        cinf_assessment_id,
        SUBSTRING(RemainingFactors, 1, CHARINDEX(',', RemainingFactors + ',') - 1) AS Factor,
        LTRIM(RTRIM(SUBSTRING(RemainingFactors, CHARINDEX(',', RemainingFactors + ',') + 1, LEN(RemainingFactors)))) AS RemainingFactors
    FROM 
        RecursiveCTE
    WHERE 
        -- until all factors are processed | RemainingFactors string is empty
        LEN(RemainingFactors) > 0
)

-- insert results into TMP split factors table
INSERT INTO #split_factors_TMP (cinf_assessment_id, Factor)
SELECT 
    cinf_assessment_id,
    Factor
FROM 
    RecursiveCTE
WHERE 
    Factor IS NOT NULL AND Factor <> '';

-- check split factors table
-- SELECT * FROM #split_factors;
/* Sample output
cinf_assessment_id	Factor
1000215	            2B
1000215	            3A
1000215	            3B
1000215	            2A
1000215	            4A
1000215	            15A
1000215	            5A
1000217	            5A
*/



-- '<?xml version="1.0" encoding="utf-8"?>' -- XML vers, encoding for XML parsing
SELECT
    (   /* Header */
        SELECT
            (   /* CollectionDetails */
                SELECT
                    'CIN' AS 'Collection'               -- N00600
                    ,'2025' AS 'Year'                   -- N00602
                    ,'2025-03-31' AS 'ReferenceDate'    -- N00603 "2025-03-31" or CONVERT(VARCHAR(10), GETDATE(), 23) ?
                FOR XML PATH(''), TYPE
            ) AS CollectionDetails,
            (   /* Source */
                SELECT
                    'L' AS 'SourceLevel'                -- N00604
                    ,'845' AS 'LEA'                     -- N00216
                    ,'Local Authority' AS 'SoftwareCode' -- N00605
                    ,'ver 3.1.21' AS 'Release'          -- N00607
                    ,'001' AS 'SerialNo'                -- N00606
                    ,CONVERT(VARCHAR(19), GETDATE(), 120) AS 'DateTime' -- N00609 120==YYYY-MM-DD HH:MM:SS
                FOR XML PATH(''), TYPE
            ) AS Source,
            (   /* Content */
                SELECT
                    (   /* CBDSLevels */
                        SELECT
                            'Child' AS 'CBDSLevel'  -- CBDSLevels details
                        FOR XML PATH(''), TYPE
                    ) AS CBDSLevels
                FOR XML PATH(''), TYPE
            ) AS Content
        FOR XML PATH(''), TYPE
    ) AS Header,
    (   /* Children */
        SELECT
            (   /* Child */
                SELECT
                    (   /* ChildIdentifiers */
                        SELECT
                            REPLACE(REPLACE(pers_legacy_id, CHAR(10), ''), CHAR(9), '')         AS 'LAchildID'                          -- N00097  rem newline char (\n) |  tab char (\t)
                            ,pers_common_child_id                                               AS 'UPN'                                -- N00001
                            ,(  -- obtain any former upns from linked_identifiers table
                                SELECT TOP 1
                                    REPLACE(REPLACE(link_identifier_value, CHAR(10), ''), CHAR(9), '')
                                FROM
                                    ssd_linked_identifiers
                                WHERE
                                    link_person_id = p.pers_person_id
                                    AND link_identifier_type = 'Former Unique Pupil Number' -- Will only match if Str identifier input using SSD guidance/standard
                                ORDER BY
                                    link_valid_from_date DESC
                            )                                                                   AS 'FormerUPN'                        -- N00002
                            ,pers_upn_unknown                                                   AS 'UPNunknown'                       -- N00135
                            ,CONVERT(VARCHAR(10), pers_dob, 23)                                 AS 'PersonBirthDate'                  -- N00066
                            ,CONVERT(VARCHAR(10), pers_expected_dob, 23)                        AS 'ExpectedPersonBirthDate'          -- N00098
                            ,CONVERT(VARCHAR(10), pers_death_date, 23)                          AS 'PersonDeathDate'                  -- N00108
                            ,CASE 
                                WHEN pers_sex = 'M' THEN 'M'
                                WHEN pers_sex = 'F' THEN 'F'
                                ELSE 'U'
                            END AS 'Sex'                                     -- N00783
                        FOR XML PATH('ChildIdentifiers'), TYPE
                    ),
                    (   /* ChildCharacteristics */
                        SELECT
                            pers_ethnicity                                                      AS 'Ethnicity'                       -- N00177
                            ,(
                                SELECT
                                    disa_disability_code                                        AS 'Disability'                      -- N00099
                                FROM 
                                    ssd_disability
                                WHERE
                                    disa_person_id = p.pers_person_id
                                FOR XML PATH('Disabilities'), TYPE
                            )
                        FOR XML PATH('ChildCharacteristics'), TYPE
                    ),
                    (   /* CINdetails */
                        SELECT
                            CONVERT(VARCHAR(10), cine.cine_referral_date, 23)                   AS 'CINreferralDate'                -- N00100
                            ,cine.cine_referral_source_code                                     AS 'ReferralSource'                 -- N00152
                            ,cine.cine_cin_primary_need_code                                    AS 'PrimaryNeedCode'                -- N00101
                            ,cine.cine_referral_nfa                                             AS 'ReferralNFA'                    -- N00112
                            ,cine_close_date                                                    AS 'CINclosureDate'                 -- N00102
                            ,cine_close_reason                                                  AS 'ReasonForClosure'               -- N00103
                            , (   /* Assessments */
                                /* Each <CINDetails> group contains 0…n <Assessments> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cina.cina_assessment_start_date, 23)   AS 'AssessmentActualStartDate',     -- N00159 
                                    'PlaceholderStr'                                            AS 'AssessmentInternalReviewDate',  -- N00161
                                    'PlaceholderStr'                                            AS 'AssessmentAuthorisationDate',   -- N00160

                                    (
                                        SELECT
                                            sf.Factor                                           AS 'AssessmentFactors'              -- N00181
                                        FROM
                                            #split_factors_TMP sf
                                        WHERE
                                            sf.cinf_assessment_id = cina.cina_assessment_id
                                            AND sf.Factor IS NOT NULL  -- Ensure no empty elements
                                        FOR XML PATH(''), TYPE
                                    ) 
                                FROM
                                    ssd_cin_assessments cina
                                WHERE
                                    cina.cina_referral_id = cine.cine_referral_id
                                FOR XML PATH('Assessments'), TYPE
                            ),
                            (   /* CINPlanDates */ 
                                /* Each <CINDetails> group contains 0..n <CINPlanDates> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cinp.cinp_cin_plan_start_date, 23)     AS 'CINPlanStartDate'           -- N00689
                                    ,CONVERT(VARCHAR(10), cinp.cinp_cin_plan_end_date, 23)      AS 'CINPlanEndDate'             -- N00690
                                FROM
                                    ssd_cin_plans cinp
                                WHERE
                                    cinp.cinp_referral_id = cine.cine_referral_id
                                FOR XML PATH('CINPlanDates'), TYPE
                            ),

                            -- [TESTING] on NumberOfPreviousCPP See replacement below

                            -- (   /* ChildProtectionPlans */ 
                            --     /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups */
                            --     SELECT
                            --         CONVERT(VARCHAR(10), cppl.cppl_cp_plan_start_date, 23)      AS 'CPPstartDate'               -- N00105 
                            --         ,CONVERT(VARCHAR(10), cppl.cppl_cp_plan_end_date, 23)       AS 'CPPendDate'                 -- N00115
                            --         ,cppl.cppl_cp_plan_initial_category                         AS 'InitialCategoryOfAbuse'     -- N00113
                            --         ,cppl.cppl_cp_plan_latest_category                          AS 'LatestCategoryOfAbuse'      -- N00114
                            --         ,'PlaceholderStr'                                           AS 'NumberOfPreviousCPP'        -- N00106
                            --         ,(  /* CPPreviews */ 
                            --             /* Each <ChildProtectionPlans> group contains 0..1 <Reviews> group */
                            --             /* Each <Reviews> group contains 1..n <CPPreviewDate> items */
                            --             SELECT
                            --                 CONVERT(VARCHAR(10), cppr.cppr_cp_review_date, 23)  AS 'CPPreviewDate'              -- N00116
                            --             FROM
                            --                 #ssd_cp_reviews cppr
                            --             WHERE
                            --                 cppr.cppr_cp_plan_id = cppl.cppl_cp_plan_id 
                            --             FOR XML PATH('CPPreviews'), TYPE
                            --         )
                            --     FROM
                            --         ssd_cp_plans cppl
                            --     WHERE
                            --         cppl.cppl_referral_id = cine.cine_referral_id
                            --     FOR XML PATH('ChildProtectionPlans'), TYPE
                            -- ),

                            -- [TESTING] on NumberOfPreviousCPP
                            (   /* ChildProtectionPlans */ 
                                /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cppl.cppl_cp_plan_start_date, 23)      AS 'CPPstartDate'               -- N00105 
                                    ,CONVERT(VARCHAR(10), cppl.cppl_cp_plan_end_date, 23)       AS 'CPPendDate'                 -- N00115
                                    ,cppl.cppl_cp_plan_initial_category                         AS 'InitialCategoryOfAbuse'     -- N00113
                                    ,cppl.cppl_cp_plan_latest_category                          AS 'LatestCategoryOfAbuse'      -- N00114
                                    ,(  /* Count of previous child protection plans */
                                        SELECT COUNT(*)
                                        FROM ssd_cp_plans prev_cppl
                                        WHERE prev_cppl.cppl_person_id = p.pers_person_id
                                    )                                                           AS 'NumberOfPreviousCPP'        -- N00106
                                    ,(  /* CPPreviews */ 
                                        /* Each <ChildProtectionPlans> group contains 0..1 <Reviews> group */
                                        /* Each <Reviews> group contains 1..n <CPPreviewDate> items */
                                        SELECT
                                            CONVERT(VARCHAR(10), cppr.cppr_cp_review_date, 23)  AS 'CPPreviewDate'              -- N00116
                                        FROM
                                            ssd_cp_reviews cppr
                                        WHERE
                                            cppr.cppr_cp_plan_id = cppl.cppl_cp_plan_id 
                                        FOR XML PATH('CPPreviews'), TYPE
                                    )
                                FROM
                                    ssd_cp_plans cppl
                                WHERE
                                    cppl.cppl_referral_id = cine.cine_referral_id
                                FOR XML PATH('ChildProtectionPlans'), TYPE
                            ),
                            (   /* Section47 */ 
                                /* Each <CINdetails> group contains 0..n <Section47> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), s47.s47e_s47_start_date, 23)           AS 'S47ActualStartDate'         -- N00148
                                    ,icpc.icpc_icpc_target_date                                 AS 'InitialCPCtarget'           -- N00109
                                    ,icpc.icpc_icpc_date                                        AS 'DateOfInitialCPC'           -- N00110
                                    ,icpc.icpc_icpc_outcome_cp_flag                             AS 'ICPCnotRequired'            -- N00111
                                FROM
                                    ssd_s47_enquiry s47
                                JOIN
                                    ssd_initial_cp_conference icpc ON s47.s47e_s47_enquiry_id = icpc.icpc_s47_enquiry_id
                                WHERE
                                    s47.s47e_referral_id = cine.cine_referral_id
                                    AND icpc.icpc_icpc_outcome_cp_flag = 'N'
                                FOR XML PATH('Section47'), TYPE
                            )
                        FROM
                            ssd_cin_episodes cine
                        WHERE
                            cine.cine_person_id = p.pers_person_id
                        FOR XML PATH('CINdetails'), TYPE
                    )
                FROM 
                    ssd_person p
                WHERE
                    EXISTS (
                        SELECT 1
                        FROM ssd_cin_episodes cine
                        WHERE cine.cine_person_id = p.pers_person_id
                        AND (
                            cine.cine_close_date IS NULL
                            OR cine.cine_close_date = ''
                            OR cine.cine_close_date >= DATEADD(YEAR, -1, GETDATE())
                        )
                    )               
                FOR XML PATH('Child'), TYPE
            )
        FOR XML PATH(''), TYPE
    ) AS Children
FOR XML PATH('Message');




/* Still to do */
-- CBDS No	XML element
-- N00105   <CPPstartDate>                  ssd_cin_plans.cinp_cin_plan_start_date [N] ---> ssd_cp_plans.cppl_cp_plan_start_date via cppl_referral_id
-- N00115   <CPPendDate>                    cinp_cin_plan_end_date  [N] ---> ssd_cp_plans.cppl_cp_plan_end_date via cppl_referral_id


-- /* Still to do */
-- -- CBDS No	XML element
-- N00002 <FormerUPN>                          - Already in the code
-- N00135 <UPNunknown>                         - Already in the code
-- N00103 <ReasonForClosure>                   - Already in the code (maps to cine_close_reason)
-- N00110 <DateOfInitialCPC>                   - Already in the code
-- N00159 <AssessmentActualStartDate>          - Already in the code
-- N00161 <AssessmentInternalReviewDate>       - Already in the code (Placeholder)
-- N00160 <AssessmentAuthorisationDate>        - Already in the code (Placeholder)
-- N00181 <AssessmentFactors>                  - Already in the code
-- N00689 <CINPlanStartDate>                   - Already in the code
-- N00690 <CINPlanEndDate>                     - Already in the code
-- N00148 <S47ActualStartDate>                 - Already in the code (maps to s47e_s47_start_date)
-- N00109 <InitialCPCtarget>                   - Already in the code (maps to icpc_icpc_target_date)
-- N00111 <ICPCnotRequired>                    - Already in the code (maps to icpc_icpc_outcome_cp_flag)
-- N00105 <CPPstartDate>                       - Already in the code (maps to cppl_cp_plan_start_date)
-- N00115 <CPPendDate>                         - Already in the code (maps to cppl_cp_plan_end_date)
-- N00113 <InitialCategoryOfAbuse>             - Already in the code
-- N00114 <LatestCategoryOfAbuse>              - Already in the code
-- N00106 <NumberOfPreviousCPP>                - [Still to do] Not sure how to generate this
-- N00116 <CPPreviewDate>                      - Already in the code (maps to cppr_cp_review_date)



/* needed objects 

-- Create structure
CREATE TABLE ssd_development.ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}   
    pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A"} 
    pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A", "item_status":"T", "expected_data":["unknown","NULL", "F", "U", "M", "I"]}       
    pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"} 
    pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
    pers_common_child_id    NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P", "info":"Populate from NHS number if available"}                           
    pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A", "info":"SEN2 guidance suggests size(4)", "expected_data":["UN1-10"]}                                 
    pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A", "item_status":"P"} 
    pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        NVARCHAR(48)                -- metadata={"item_ref":"PERS012A"} 
);


-- Create structure
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                INT,            -- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(500),  -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team              NVARCHAR(255),  -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
);

-- Create the structure
CREATE TABLE ssd_development.ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);

-- Create structure
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                INT,            -- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need_code      NVARCHAR(3),    -- metadata={"item_ref":"CINE010A", "info":"Expecting codes N0-N9"} 
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(500),  -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team              NVARCHAR(255),  -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_id         NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
);
 

-- Create structure
CREATE TABLE ssd_development.ssd_cin_assessments
(
    cina_assessment_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINA001A"}
    cina_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CINA002A"}
    cina_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CINA010A"}
    cina_assessment_start_date      DATETIME,                   -- metadata={"item_ref":"CINA003A"}
    cina_assessment_child_seen      NCHAR(1),                   -- metadata={"item_ref":"CINA004A"}
    cina_assessment_auth_date       DATETIME,                   -- metadata={"item_ref":"CINA005A"}             
    cina_assessment_outcome_json    NVARCHAR(1000),             -- metadata={"item_ref":"CINA006A"}           
    cina_assessment_outcome_nfa     NCHAR(1),                   -- metadata={"item_ref":"CINA009A"}
    cina_assessment_team            NVARCHAR(255),              -- metadata={"item_ref":"CINA007A"}
    cina_assessment_worker_id       NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
);


-- Create structure
CREATE TABLE ssd_development.ssd_assessment_factors (
    cinf_table_id                   NVARCHAR(48) PRIMARY KEY,       -- metadata={"item_ref":"CINF003A"}
    cinf_assessment_id              NVARCHAR(48),                   -- metadata={"item_ref":"CINF001A"}
    cinf_assessment_factors_json    NVARCHAR(1000)                  -- metadata={"item_ref":"CINF002A"}
);


-- Create structure
CREATE TABLE ssd_development.ssd_cp_plans (
    cppl_cp_plan_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CPPL001A"}
    cppl_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CPPL007A"}
    cppl_icpc_id                    NVARCHAR(48),               -- metadata={"item_ref":"CPPL008A"}
    cppl_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CPPL002A"}
    cppl_cp_plan_start_date         DATETIME,                   -- metadata={"item_ref":"CPPL003A"}
    cppl_cp_plan_end_date           DATETIME,                   -- metadata={"item_ref":"CPPL004A"}
    cppl_cp_plan_ola                NCHAR(1),                   -- metadata={"item_ref":"CPPL011A"}       
    cppl_cp_plan_initial_category   NVARCHAR(100),              -- metadata={"item_ref":"CPPL009A"}
    cppl_cp_plan_latest_category    NVARCHAR(100),              -- metadata={"item_ref":"CPPL010A"}
);


-- Create structure
CREATE TABLE ssd_development.ssd_initial_cp_conference (
    icpc_icpc_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ICPC001A"}
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
    icpc_icpc_team              NVARCHAR(255),              -- metadata={"item_ref":"ICPC007A"}
    icpc_icpc_worker_id         NVARCHAR(100),              -- metadata={"item_ref":"ICPC008A"}
);


-- Create structure 
CREATE TABLE ssd_development.ssd_s47_enquiry (
    s47e_s47_enquiry_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S47E001A"}
    s47e_referral_id                    NVARCHAR(48),               -- metadata={"item_ref":"S47E010A"}
    s47e_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"S47E002A"}
    s47e_s47_start_date                 DATETIME,                   -- metadata={"item_ref":"S47E004A"}
    s47e_s47_end_date                   DATETIME,                   -- metadata={"item_ref":"S47E005A"}
    s47e_s47_nfa                        NCHAR(1),                   -- metadata={"item_ref":"S47E006A"}
    s47e_s47_outcome_json               NVARCHAR(1000),             -- metadata={"item_ref":"S47E007A"}
    s47e_s47_completed_by_team          NVARCHAR(255),              -- metadata={"item_ref":"S47E009A"}
    s47e_s47_completed_by_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"S47E008A"}
);


-- Create structure
CREATE TABLE ssd_development.ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team          NVARCHAR(255),              -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
);


-- Create structure
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

*/