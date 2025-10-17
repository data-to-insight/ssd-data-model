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

USE HDM_local;
GO -- also reset previously defined vars


--[Start_of_Census_Year], a constant value for this census of 2023-04-01
--[Period_of_Census],  a constant value for this census of 22023-04-01 to 2024-03-31

-- end of the census year as April 1st of the current year
DECLARE @End_of_Census_Date DATE = CAST(CAST(YEAR(GETDATE()) AS VARCHAR) + '-04-01' AS DATE);

-- Calc start of the census year (one year minus one day earlier)
DECLARE @Start_of_Census_Date DATE = DATEADD(DAY, -1, DATEADD(YEAR, -1, @End_of_Census_Date));


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



-- '<?xml version="1.0" encoding="utf-8"?>' -- XML vers, encoding for XML parsing
SELECT
    (   /* Header */
        SELECT
            (   /* CollectionDetails */
                SELECT
                    'CIN' AS 'Collection'               -- N00600
                    ,YEAR(@End_of_Census_Date)      AS 'Year'               -- N00602
                    ,@Start_of_Census_Date          AS 'ReferenceDate'      -- N00603 "2025-03-31" or CONVERT(VARCHAR(10), GETDATE(), 23) ?
                FOR XML PATH(''), TYPE
            ) AS CollectionDetails,
            (   /* Source */
                SELECT
                    'L' AS 'SourceLevel'                -- N00604
                    ,'845' AS 'LEA'                     -- N00216
                    ,'Local Authority' AS 'SoftwareCode' -- N00605
                    ,'ver 3.1.21' AS 'Release'          -- N00607
                    ,'040' AS 'SerialNo'                -- N00606
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
                            ,(  -- obtain former upn from linked_identifiers table
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
                            OR (cine.cine_close_date >= @Start_of_Census_Date 
                            AND cine.cine_close_date < @End_of_Census_Date)

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
