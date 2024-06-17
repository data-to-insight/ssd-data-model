
WITH SplitFactors AS (
    SELECT
        cinf.cinf_assessment_id,
        -- extract first factor from the CSV string + CAST NVARCHAR(10) (avoiding mismatched types btw recursive part of the CTE)
        -- allow isolating the first factor for further processing
        CAST(LEFT(ISNULL(cinf.cinf_assessment_factors_json, ''), CHARINDEX(',', ISNULL(cinf.cinf_assessment_factors_json, '') + ',') - 1) AS NVARCHAR(10)) AS Factor,

        -- remove first factor from the CSV string and cast the remaining string as NVARCHAR(1000) (max of 100 2char codes)
        -- allow recursive processing of remaining factors in next iterations
        CAST(STUFF(ISNULL(cinf.cinf_assessment_factors_json, ''), 1, CHARINDEX(',', ISNULL(cinf.cinf_assessment_factors_json, '') + ','), '') AS NVARCHAR(1000)) AS RemainingFactors
    FROM
        #ssd_assessment_factors cinf
    WHERE
        ISNULL(cinf.cinf_assessment_factors_json, '') <> '' -- Expected data format is 0.n factors as csv
    UNION ALL
    SELECT
    -- recursively split remaining CSV values into individual factors
    -- process until all factors extracted and included in the result set
        cinf_assessment_id,
        CAST(LEFT(RemainingFactors, CHARINDEX(',', RemainingFactors + ',') - 1) AS NVARCHAR(10)) AS Factor,                 -- find position of the first comma
        CAST(STUFF(RemainingFactors, 1, CHARINDEX(',', RemainingFactors + ','), '') AS NVARCHAR(1000)) AS RemainingFactors  -- extracts substring from start of RemainingFactors 
                                                                                                                            -- up to the pos of first comma minus 1 char (to exclude the comma itself)
    FROM
        SplitFactors
    WHERE
        RemainingFactors <> ''
        AND LEFT(RemainingFactors, CHARINDEX(',', RemainingFactors + ',') - 1) <> ''
)

WITH SplitFactors AS (
    SELECT
        cinf.cinf_assessment_id,
        CAST(LEFT(cinf.cinf_assessment_factors_json, CHARINDEX(',', cinf.cinf_assessment_factors_json + ',') - 1) AS NVARCHAR(10)) AS Factor,
        CAST(STUFF(cinf.cinf_assessment_factors_json, 1, CHARINDEX(',', cinf.cinf_assessment_factors_json + ','), '') AS NVARCHAR(1000)) AS RemainingFactors
    FROM
        #ssd_assessment_factors cinf
    UNION ALL
    SELECT
        cinf_assessment_id,
        CAST(LEFT(RemainingFactors, CHARINDEX(',', RemainingFactors + ',') - 1) AS NVARCHAR(10)) AS Factor,
        CAST(STUFF(RemainingFactors, 1, CHARINDEX(',', RemainingFactors + ','), '') AS NVARCHAR(1000)) AS RemainingFactors
    FROM
        SplitFactors
    WHERE
        RemainingFactors <> ''
        AND LEFT(RemainingFactors, CHARINDEX(',', RemainingFactors + ',') - 1) <> ''
)
SELECT
    (   /* Header */
        SELECT
            (   /* CollectionDetails */
                SELECT
                    'CIN' AS 'Collection'               -- N00600
                    ,'2025' AS 'Year'                   -- N00602
                    ,CONVERT(VARCHAR(10), GETDATE(), 23) AS 'ReferenceDate' -- N00603
                FOR XML PATH('CollectionDetails'), TYPE
            ),
            (   /* Source */
                SELECT
                    'L' AS 'SourceLevel'                -- N00604
                    ,'845' AS 'LEA'                     -- N00216
                    ,'Local Authority' AS 'SoftwareCode' -- N00605
                    ,'ver 3.1.21' AS 'Release'          -- N00607
                    ,'001' AS 'SerialNo'                -- N00606
                    ,CONVERT(VARCHAR(19), GETDATE(), 126) AS 'DateTime' -- N00609
                FOR XML PATH('Source'), TYPE
            )
        FOR XML PATH(''), TYPE
    ) AS Header,
    (   /* Children */
        SELECT
            (   /* Child */
                SELECT
                    (   /* ChildIdentifiers */
                        SELECT
                            pers_legacy_id AS 'LAchildID'                    -- N00097
                            ,pers_common_child_id AS 'UPN'                   -- N00001
                            ,(  -- obtain any former upns from linked_identifiers table
                                SELECT TOP 1
                                    link_identifier_value
                                FROM
                                    #ssd_linked_identifiers
                                WHERE
                                    link_person_id = p.pers_person_id
                                    AND link_identifier_type = 'Former Unique Pupil Number' -- Will only match if Str identifier has followed ssd standard
                                ORDER BY
                                    link_valid_from_date DESC
                            ) AS 'FormerUPN'                                 -- N00002
                            ,pers_upn_unknown AS 'UPNunknown'                -- N00135
                            ,CONVERT(VARCHAR(10), pers_dob, 23) AS 'PersonBirthDate' -- N00066
                            ,CONVERT(VARCHAR(10), pers_expected_dob, 23) AS 'ExpectedPersonBirthDate' -- N00098
                            ,CONVERT(VARCHAR(10), pers_death_date, 23) AS 'PersonDeathDate' -- N00108
                            ,CASE 
                                WHEN pers_sex = 'M' THEN 'M'
                                WHEN pers_sex = 'F' THEN 'F'
                                ELSE 'U'
                            END AS 'Sex'                                     -- N00783
                        FOR XML PATH('ChildIdentifiers'), TYPE
                    ),
                    (   /* ChildCharacteristics */
                        SELECT
                            pers_ethnicity AS 'Ethnicity'                    -- N00177
                            ,(
                                SELECT
                                    disa_disability_code AS 'Disability'     -- N00099
                                FROM 
                                    #ssd_disability
                                WHERE
                                    disa_person_id = p.pers_person_id
                                FOR XML PATH('Disabilities'), TYPE
                            )
                        FOR XML PATH('ChildCharacteristics'), TYPE
                    ),
                    (   /* CINdetails */
                        SELECT
                            CONVERT(VARCHAR(10), cine.cine_referral_date, 23) AS 'CINreferralDate' -- N00100
                            ,cine.cine_referral_source_code AS 'ReferralSource' -- N00152
                            ,cine.cine_cin_primary_need_code AS 'PrimaryNeedCode' -- N00101
                            ,cine.cine_referral_nfa AS 'ReferralNFA'           -- N00112
                            ,cine_close_date AS 'CINclosureDate'               -- N00102
                            ,cine_close_reason AS 'ReasonForClosure'           -- N00103
                            ,(   /* Assessments */
                                /* Each <CINDetails> group contains 0…n <Assessments> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cina.cina_assessment_start_date, 23) AS 'AssessmentActualStartDate' -- N00159 
                                    ,'PlaceholderStr' AS 'AssessmentInternalReviewDate' -- N00161
                                    ,'PlaceholderStr' AS 'AssessmentAuthorisationDate'  -- N00160

                                    ,(  -- Get unpacked Factors data from CTE
                                        SELECT
                                            Factor AS 'AssessmentFactors'
                                        FROM
                                            SplitFactors sf
                                        WHERE
                                            sf.cinf_assessment_id = cina.cina_assessment_id
                                            AND sf.Factor <> '' -- Further to CTE handling, to ensure no empty Str elements
                                        FOR XML PATH('AssessmentFactors'), TYPE
                                    )
                                FROM
                                    #ssd_cin_assessments cina
                                WHERE
                                    cina.cina_referral_id = cine.cine_referral_id
                                FOR XML PATH('Assessments'), TYPE
                            ),
                            (   /* CINPlanDates */ 
                                /* Each <CINDetails> group contains 0..n <CINPlanDates> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cinp.cinp_cin_plan_start_date, 23) AS 'CINPlanStartDate' -- N00689
                                    ,CONVERT(VARCHAR(10), cinp.cinp_cin_plan_end_date, 23) AS 'CINPlanEndDate' -- N00690
                                FROM
                                    #ssd_cin_plans cinp
                                WHERE
                                    cinp.cinp_referral_id = cine.cine_referral_id
                                FOR XML PATH('CINPlanDates'), TYPE
                            ),
                            (   /* ChildProtectionPlans */ 
                                /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), cppl.cppl_cp_plan_start_date, 23) AS 'CPPstartDate' -- N00105 
                                    ,CONVERT(VARCHAR(10), cppl.cppl_cp_plan_end_date, 23) AS 'CPPendDate' -- N00115
                                    ,cppl.cppl_cp_plan_initial_category AS 'InitialCategoryOfAbuse' -- N00113
                                    ,cppl.cppl_cp_plan_latest_category AS 'LatestCategoryOfAbuse' -- N00114
                                    ,'PlaceholderStr' AS 'NumberOfPreviousCPP' -- N00106
                                    ,(   /* CPPreviews */ 
                                        /* Each <ChildProtectionPlans> group contains 0..1 <Reviews> group */
                                        /* Each <Reviews> group contains 1..n <CPPreviewDate> items */
                                        SELECT
                                            CONVERT(VARCHAR(10), cppr.cppr_cp_review_date, 23) AS 'CPPreviewDate' -- N00116
                                        FROM
                                            #ssd_cp_reviews cppr
                                        WHERE
                                            cppr.cppr_cp_plan_id = cppl.cppl_cp_plan_id
                                        FOR XML PATH('CPPreviews'), TYPE
                                    )
                                FROM
                                    #ssd_cp_plans cppl
                                WHERE
                                    cppl.cppl_referral_id = cine.cine_referral_id
                                FOR XML PATH('ChildProtectionPlans'), TYPE
                            ),
                            (   /* Section47 */ 
                                /* Each <CINdetails> group contains 0..n <Section47> groups */
                                SELECT
                                    CONVERT(VARCHAR(10), s47.s47e_s47_start_date, 23) AS 'S47ActualStartDate'   -- N00148
                                    ,icpc.icpc_icpc_target_date AS 'InitialCPCtarget'                           -- N00109
                                    ,icpc.icpc_icpc_date AS 'DateOfInitialCPC'                                  -- N00110
                                    ,icpc.icpc_icpc_outcome_cp_flag AS 'ICPCnotRequired'                        -- N00111
                                FROM
                                    #ssd_s47_enquiry s47
                                JOIN
                                    #ssd_initial_cp_conference icpc ON s47.s47e_s47_enquiry_id = icpc.icpc_s47_enquiry_id
                                WHERE
                                    s47.s47e_referral_id = cine.cine_referral_id
                                FOR XML PATH('Section47'), TYPE
                            )
                        FROM
                            #ssd_cin_episodes cine
                        WHERE
                            cine.cine_person_id = p.pers_person_id
                        FOR XML PATH('CINdetails'), TYPE
                    )
                FROM 
                    #ssd_person p
                FOR XML PATH('Child'), TYPE
            )
        FOR XML PATH(''), TYPE
    ) AS Children
FOR XML PATH('Message');






-- v2 - took over 20mins to run, but did run. 
-- SELECT 
--     (   /* Header */ 
--         SELECT
--             (
--                 SELECT
--                     'CIN'               AS 'Collection'     -- N00600
--                     ,'2025'             AS 'Year'           -- N00602
--                     ,CONVERT(VARCHAR(10), 
--                         GETDATE(), 23)  AS 'ReferenceDate'  -- N00603

--                 FOR XML PATH('CollectionDetails'), TYPE
--             ),
--             (
--                 SELECT
--                     'L'                 AS 'SourceLevel'    -- N00604
--                     ,'845'              AS 'LEA'            -- N00216
--                     ,'Local Authority'  AS 'SoftwareCode'   -- N00605
--                     ,'ver 3.1.21'       AS 'Release'        -- N00607
--                     ,'001'              AS 'SerialNo'       -- N00606
--                     ,CONVERT(VARCHAR(19),  
--                     GETDATE(), 126)     AS 'DateTime'       -- N00609

--                 FOR XML PATH('Source'), TYPE
--             ),
--             (
--                 SELECT
--                     (   
--                         SELECT
--                             'Child'     AS 'CBDSLevel'              -- N00608

--                         FOR XML PATH('CBDSLevels'), TYPE
--                     )
--                 FOR XML PATH('Content'), TYPE
--             )
--         FOR XML PATH('Header'), TYPE
--     ) AS Header,
-- (
--     SELECT
--         (   /* ChildIdentifiers */                
--             SELECT
--                 pers_legacy_id                                  AS 'LAchildID'             -- N00097
--                 ,'SSD_PH'                                       AS 'UPN'                   -- N00001   [TESTING] 
--                 ,'SSD_PH'                                       AS 'FormerUPN'             -- N00002   [TESTING]
--                 ,pers_upn_unknown                               AS 'UPNunknown'            -- N00135
--                 ,CONVERT(VARCHAR(10), pers_dob, 23)             AS 'PersonBirthDate'       -- N00066
--                 ,CONVERT(VARCHAR(10), pers_expected_dob, 23)    AS 'ExpectedBirthDate'     -- N00098
--                 ,CONVERT(VARCHAR(10), pers_death_date, 23)      AS 'PersonDeathDate'       -- N00108
--                 ,CASE 
--                     WHEN pers_sex = 'M' THEN 'M'
--                     WHEN pers_sex = 'F' THEN 'F'
--                     ELSE 'U'
--                 END                                             AS 'Sex'                   -- N00783
--             FOR XML PATH('ChildIdentifiers'), TYPE
--         ),
--         (   /* ChildCharacteristics */
--             /* Each <Child> group contains one and only one <ChildCharacteristics> group */
--             SELECT
--                 pers_ethnicity                                  AS 'Ethnicity'             -- N00177
--                 ,(
--                     SELECT
--                         disa_disability_code                    AS 'Disability'             -- N00099
--                     FROM 
--                         #ssd_disability
--                     WHERE
--                         disa_person_id = p.pers_person_id
--                     FOR XML PATH('Disabilities'), TYPE
--                 )
--             FOR XML PATH('ChildCharacteristics'), TYPE
--         ),
--         (   /* CINdetails */
--             /* Each <Child> group contains 1..n <CINdetails> group */
--             SELECT
--                 CONVERT(VARCHAR(10), cine.cine_referral_date, 23)  
--                                                                 AS 'CINreferralDate'     -- N00100
--                 ,cine.cine_referral_source_code                 AS 'ReferralSource'     -- N00152
--                 ,cine.cine_cin_primary_need_code                AS 'PrimaryNeedCode'    -- N00101
--                 ,cine.cine_referral_nfa                         AS 'ReferralNFA'        -- N00112
--                 ,cine_close_date                                AS 'CINclosureDate'     -- N00102
--                 ,cine_close_reason                              AS 'ReasonForClosure'   -- N00103
--                 ,(   /* Assessments */
--                     /* Each <CINDetails> group contains 0…n <Assessments> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), cina.cina_assessment_start_date, 23)   
--                                                                 AS 'AssessmentActualStartDate'      -- N00159 
--                         ,'SSD_PH'                               AS 'AssessmentInternalReviewDate'   -- N00161 [TESTING]
--                         ,'SSD_PH'                               AS 'AssessmentAuthorisationDate'    -- N00160 [TESTING]
--                         ,(
--                             SELECT
--                                 cinf.cinf_assessment_factors_json AS 'AssessmentFactors' -- N00181 [TESTING] still has format "{"2B":"No"},{"19A":"No"},..."
--                             FROM
--                                 #ssd_assessment_factors cinf
--                             WHERE
--                                 cinf.cinf_assessment_id = cina.cina_assessment_id
--                             FOR XML PATH('FactorsIdentifiedAtAssessment'), TYPE
--                         )
--                     FROM
--                         #ssd_cin_assessments cina
--                     WHERE
--                         cina.cina_referral_id = cine.cine_referral_id
--                     FOR XML PATH('Assessments'), TYPE
--                 ),
--                 (   /* CINPlanDates */ 
--                     /* Each <CINDetails> group contains 0..n <CINPlanDates> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), cinp.cinp_cin_plan_start_date, 23)  AS 'CINPlanStartDate'  -- N00689
--                         ,CONVERT(VARCHAR(10), cinp.cinp_cin_plan_end_date, 23)   AS 'CINPlanEndDate'    -- N00690
--                     FROM
--                         #ssd_cin_plans cinp
--                     WHERE
--                         cinp.cinp_referral_id = cine.cine_referral_id
--                     FOR XML PATH('CINPlanDates'), TYPE
--                 ),
--                 (   /* ChildProtectionPlans */ 
--                     /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups*/
--                     SELECT
--                         CONVERT(VARCHAR(10), cppl.cppl_cp_plan_start_date , 23)  AS 'CPPstartDate'              -- N00105 [TESTING]
--                         ,CONVERT(VARCHAR(10), cppl.cppl_cp_plan_end_date , 23)   AS 'CPPendDate'                -- N00115 [TESTING]
--                         ,cppl.cppl_cp_plan_initial_category                      AS 'InitialCategoryOfAbuse'    -- N00113 [TESTING]
--                         ,cppl.cppl_cp_plan_latest_category                       AS 'LatestCategoryOfAbuse'     -- N00114 [TESTING]
--                         ,'SSD_PH'                                                AS 'NumberOfPreviousCPP'       -- N00106 [TESTING]
--                         ,(   /* CPPreviews */ 
--                             /* Each <ChildProtectionPlans> group contains 0..1 <Reviews> group */
--                             /* Each <Reviews> group contains 1..n <CPPreviewDate> items */
--                             SELECT
--                                 CONVERT(VARCHAR(10), cppr.cppr_cp_review_date , 23)  AS 'CPPreviewDate'             -- N00116 [TESTING]
--                             FROM
--                                 #ssd_cp_reviews cppr
--                             WHERE
--                                 cppr.cppr_cp_plan_id = cppl.cppl_cp_plan_id
--                             FOR XML PATH('CPPreviews'), TYPE
--                         )
--                     FROM
--                         #ssd_cp_plans cppl
--                     WHERE
--                         cppl.cppl_referral_id = cine.cine_referral_id
--                     FOR XML PATH('ChildProtectionPlans'), TYPE
--                 ),
--                 (   /* Section47 */ 
--                     /* Each <CINdetails> group contains 0..n <Section47> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), s47.s47e_s47_start_date , 23)  AS 'S47ActualStartDate'             -- N00148 [TESTING]
--                     FROM
--                         #ssd_s47_enquiry s47
--                     WHERE
--                         s47.s47e_referral_id = cine.cine_referral_id
--                     FOR XML PATH('Section47'), TYPE
--                 )
--             FROM
--                 #ssd_cin_episodes cine
--             WHERE
--                 cine.cine_person_id = p.pers_person_id
--             FOR XML PATH('CINdetails'), TYPE
--         )
--     FROM 
--         #ssd_person p
-- FOR XML PATH('Child'), TYPE
-- ) AS Children
-- FOR XML PATH('Message');



-- was running fine, but incorrect structure. 
-- SELECT 
--     (   /* Header */ 
--         SELECT
--             (
--                 SELECT
--                     'CIN'               AS 'Collection'     -- N00600
--                     ,'2025'             AS 'Year'           -- N00602
--                     ,CONVERT(VARCHAR(10), 
--                         GETDATE(), 23)  AS 'ReferenceDate'  -- N00603

--                 FOR XML PATH('CollectionDetails'), TYPE
--             ),
--             (
--                 SELECT
--                     'L'                 AS 'SourceLevel'    -- N00604
--                     ,'845'              AS 'LEA'            -- N00216
--                     ,'Local Authority'  AS 'SoftwareCode'   -- N00605
--                     ,'ver 3.1.21'       AS 'Release'        -- N00607
--                     ,'001'              AS 'SerialNo'       -- N00606
--                     ,CONVERT(VARCHAR(19),  
--                     GETDATE(), 126)     AS 'DateTime'       -- N00609

--                 FOR XML PATH('Source'), TYPE
--             ),
--             (
--                 SELECT
--                     (   
--                         SELECT
--                             'Child'     AS 'CBDSLevel'              -- N00608

--                         FOR XML PATH('CBDSLevels'), TYPE
--                     )
--                 FOR XML PATH('Content'), TYPE
--             )
--         FOR XML PATH('Header'), TYPE
--     ) AS Header,
--     (
--     SELECT
--         (   /* ChildIdentifiers */                
--             SELECT
--                 pers_legacy_id          AS 'LAchildID'              -- N00097
--                 ,'SSD_PH'               AS 'UPN'                    -- N00001   [TESTING] 
--                 ,'SSD_PH'               AS 'FormerUPN'              -- N00002   [TESTING]
--                 ,pers_upn_unknown       AS 'UPNunknown'             -- N00135
--                 ,CONVERT(VARCHAR(10), pers_dob, 23)  AS 'PersonBirthDate'       -- N00066
--                 ,CONVERT(VARCHAR(10), pers_expected_dob, 23)  AS 'ExpectedBirthDate'     -- N00098
--                 ,CONVERT(VARCHAR(10), pers_death_date, 23)    AS 'PersonDeathDate'       -- N00108
--                 ,CASE 
--                     WHEN pers_sex = 'M' THEN 'M'
--                     WHEN pers_sex = 'F' THEN 'F'
--                     ELSE 'U'
--                 END                     AS 'Sex'                    -- N00783
--             FOR XML PATH('ChildIdentifiers'), TYPE
--         ),
--         (   /* ChildCharacteristics */
--             /* Each <Child> group contains one and only one <ChildCharacteristics> group */
--             SELECT
--                 pers_ethnicity          AS 'Ethnicity'              -- N00177
--                 ,(
--                     SELECT
--                         disa_disability_code AS 'Disability'        -- N00099
--                     FROM 
--                         #ssd_disability
--                     WHERE
--                         disa_person_id = p.pers_person_id
--                     FOR XML PATH('Disabilities'), TYPE
--                 )
--             FOR XML PATH('ChildCharacteristics'), TYPE
--         ),
--         (   /* CINdetails */
--             /* Each <Child> group contains 1..n <CINdetails> group */
--             SELECT
--                 CONVERT(VARCHAR(10), cine.cine_referral_date, 23)  AS 'CINreferralDate'    -- N00100
--                 ,cine.cine_referral_source_code     AS 'ReferralSource'     -- N00152
--                 ,cine.cine_cin_primary_need_code    AS 'PrimaryNeedCode'    -- N00101
--                 ,cine.cine_referral_nfa             AS 'ReferralNFA'        -- N00112
--                 ,cine_close_date                    AS 'CINclosureDate'     -- N00102
--                 ,cine_close_reason                  AS 'ReasonForClosure'   -- N00103
--                 ,(
--                     /* Assessments */
--                     /* Each <CINDetails> group contains 0…n <Assessments> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), cina.cina_assessment_start_date, 23)   AS 'AssessmentActualStartDate'  -- N00159 
--                         ,'SSD_PH'                                                   AS 'AssessmentInternalReviewDate' -- N00161 [TESTING]
--                         ,'SSD_PH'                                                   AS 'AssessmentAuthorisationDate'  -- N00160 [TESTING]
--                         ,(
--                             /* FactorsIdentifiedAtAssessment */  
--                             /* Each <FactorsIdentifiedAtAssessment> group contains 1..n <AssessmentFactors> items */
--                             SELECT
--                                 cinf.cinf_assessment_factors_json                   AS 'AssessmentFactors'  -- N00181 [TESTING] still has format "{"2B":"No"},{"19A":"No"},..."
--                             FROM
--                                 #ssd_assessment_factors cinf
--                             WHERE
--                                 cinf.cinf_assessment_id = cina.cina_assessment_id
--                             FOR XML PATH('FactorsIdentifiedAtAssessment'), TYPE
--                         )
--                     FROM
--                         #ssd_cin_assessments cina
--                     WHERE
--                         cina.cina_referral_id = cine.cine_referral_id
--                     FOR XML PATH('Assessments'), TYPE
--                 ),
--                 (
--                     /* CINPlanDates */ 
--                     /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), cinp.cinp_cin_plan_start_date, 23)   AS 'CINPlanStartDate'  -- N00689
--                         ,CONVERT(VARCHAR(10), cinp.cinp_cin_plan_end_date, 23)   AS 'CINPlanEndDate'    -- N00690
--                     FROM
--                         #ssd_cin_plans cinp
--                     WHERE
--                         cinp.cinp_referral_id = cine.cine_referral_id
--                     FOR XML PATH('CINPlanDates'), TYPE
--                 ),
--                 (
--                     /* ChildProtectionPlans */ 
--                     /* Each <CINdetails> group contains 0..n <ChildProtectionPlans> groups*/
--                     SELECT
--                         CONVERT(VARCHAR(10), cppl.cppl_cp_plan_start_date , 23)  AS 'CPPstartDate'              -- N00105 [TESTING]
--                         ,CONVERT(VARCHAR(10), cppl.cppl_cp_plan_end_date , 23)   AS 'CPPendDate'                -- N00115 [TESTING]
--                         ,cppl.cppl_cp_plan_initial_category                      AS 'InitialCategoryOfAbuse'    -- N00113 [TESTING]
--                         ,cppl.cppl_cp_plan_latest_category                       AS 'LatestCategoryOfAbuse'     -- N00114 [TESTING]
--                         ,'SSD_PH'                                                AS 'NumberOfPreviousCPP'       -- N00106 [TESTING]	
--                    FROM
--                         #ssd_cp_plans cppl
--                     WHERE
--                         cppl.cppl_referral_id = cine.cine_referral_id
--                     FOR XML PATH('ChildProtectionPlans'), TYPE
--                 ),
--                 (
--                     /* Section47 */ 
--                     /* Each <CINdetails> group contains 0..n <Section47> groups */
--                     SELECT
--                         CONVERT(VARCHAR(10), s47.s47e_s47_start_date , 23)  AS 'S47ActualStartDate'             -- N00148 [TESTING]
         
--                    FROM
--                         #ssd_s47_enquiry s47
--                     WHERE
--                         s47.s47e_referral_id = cine.cine_referral_id
--                     FOR XML PATH('Section47'), TYPE
--                 ),
--                 (
--                     /* CPPreviews */ 
--                     /* Each <ChildProtectionPlans> group contains 0..1 <Reviews> group */
--                     /* Each <Reviews> group contains 1..n <CPPreviewDate> items */
--                     SELECT
--                         CONVERT(VARCHAR(10), cppr.cppr_cp_review_date , 23)  AS 'CPPreviewDate'             -- N00116 [TESTING]
--                    FROM
--                         #ssd_cp_reviews cppr
--                     WHERE
--                         cppr.cppr_cp_plan_id = cppl.cppl_cp_plan_id
--                     FOR XML PATH('CPPreviews'), TYPE
--                 )

--             FROM
--                 #ssd_cin_episodes cine
--             WHERE
--                 cine.cine_person_id = p.pers_person_id
--             FOR XML PATH('CINdetails'), TYPE
--         )
--     FROM 
--         #ssd_person p
--     FOR XML PATH('Child'), TYPE
--     ) AS Children
-- FOR XML PATH('Message');



/* Still to do */
-- CBDS No	XML element
-- N00002	<FormerUPN> 
-- N00135	<UPNunknown> 

-- N00103	<ReasonForClosure>              is this cine_close_reason
-- N00110	<DateOfInitialCPC>
-- N00159	<AssessmentActualStartDate>     
-- N00161	<AssessmentInternalReviewDate>  
-- N00160	<AssessmentAuthorisationDate>   
-- N00181	<AssessmentFactors>             
-- N00689	<CINPlanStartDate>              
-- N00690	<CINPlanEndDate>                
-- N00148	<S47ActualStartDate>            s47e_s47_start_date 
-- N00109	<InitialCPCtarget>              icpc_icpc_date ?  via icpc_referral_id 
-- N00111	<ICPCnotRequired>               icpc_icpc_outcome_cp_flag ? 
-- N00105	<CPPstartDate>                  is this ssd_cin_plans.cinp_cin_plan_start_date ? via cinp_referral_id
-- N00115	<CPPendDate>                    is this cinp_cin_plan_end_date
-- N00113	<InitialCategoryOfAbuse>        
-- N00114	<LatestCategoryOfAbuse>         
-- N00106	<NumberOfPreviousCPP>           Not sure how to generate this
-- N00116	<CPPreviewDate>                 ssd_cp_reviews.cppr_cp_review_date via ssd_cp_reviews.cppr_cp_plan_id


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