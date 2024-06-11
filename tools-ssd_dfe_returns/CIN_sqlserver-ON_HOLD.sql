SELECT 
    (   /* Header */ 
        SELECT
            (
                SELECT
                    'CIN'               AS 'Collection'     -- N00600
                    ,'2025'             AS 'Year'           -- N00602
                    ,CONVERT(VARCHAR(10), 
                        GETDATE(), 23)  AS 'ReferenceDate'  -- N00603

                FOR XML PATH('CollectionDetails'), TYPE
            ),
            (
                SELECT
                    'L'                 AS 'SourceLevel'    -- N00604
                    ,'845'              AS 'LEA'            -- N00216
                    ,'Local Authority'  AS 'SoftwareCode'   -- N00605
                    ,'ver 3.1.21'       AS 'Release'        -- N00607
                    ,'001'              AS 'SerialNo'       -- N00606
                    ,CONVERT(VARCHAR(19),  
                    GETDATE(), 126)     AS 'DateTime'       -- N00609

                FOR XML PATH('Source'), TYPE
            ),
            (
                SELECT
                    (   
                        SELECT
                            'Child'     AS 'CBDSLevel'              -- N00608

                        FOR XML PATH('CBDSLevels'), TYPE
                    )
                FOR XML PATH('Content'), TYPE
            )
        FOR XML PATH('Header'), TYPE
    ) AS Header,
    (
    SELECT
        (   /* ChildIdentifiers */                
            SELECT
                pers_legacy_id          AS 'LAchildID'              -- N00097
                ,'SSD_PH'               AS 'UPN'                    -- N00001   [TESTING] 
                ,'SSD_PH'               AS 'FormerUPN'              -- N00002   [TESTING]
                ,pers_upn_unknown       AS 'UPNunknown'             -- N00135
                ,CONVERT(VARCHAR(10), pers_dob, 23)  AS 'PersonBirthDate'       -- N00066
                ,CONVERT(VARCHAR(10), pers_expected_dob, 23)  AS 'ExpectedBirthDate'     -- N00098
                ,CONVERT(VARCHAR(10), pers_death_date, 23)    AS 'PersonDeathDate'       -- N00108
                ,CASE 
                    WHEN pers_sex = 'M' THEN 'M'
                    WHEN pers_sex = 'F' THEN 'F'
                    ELSE 'U'
                END                     AS 'Sex'                    -- N00783
            FOR XML PATH('ChildIdentifiers'), TYPE
        ),
        (   /* ChildCharacteristics */
            SELECT
                pers_ethnicity          AS 'Ethnicity'              -- N00177
                ,(
                    SELECT
                        disa_disability_code AS 'Disability'        -- N00099
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
                CONVERT(VARCHAR(10), cine.cine_referral_date, 23)  AS 'CINreferralDate'    -- N00100
                ,cine.cine_referral_source_code     AS 'ReferralSource'     -- N00152
                ,cine.cine_cin_primary_need_code    AS 'PrimaryNeedCode'    -- N00101
                ,cine.cine_referral_nfa             AS 'ReferralNFA'        -- N00112
                ,cine_close_date                    AS 'CINclosureDate'     -- N00102
                ,cine_close_reason                  AS 'ReasonForClosure'   -- N00103
                ,(
                    SELECT
                        CONVERT(VARCHAR(10), cina.cina_assessment_start_date, 23)   AS 'AssessmentActualStartDate'  -- N00159 
                        ,'SSD_PH'                                                   AS 'AssessmentInternalReviewDate' -- N00161 [TESTING]
                        ,'SSD_PH'                                                   AS 'AssessmentAuthorisationDate'  -- N00160 [TESTING]
                        ,(
                            SELECT
                                cinf.cinf_assessment_factors_json                   AS 'AssessmentFactors'  -- N00181 [TESTING] still has format "{"2B":"No"},{"19A":"No"},..."
                            FROM
                                #ssd_assessment_factors cinf
                            WHERE
                                cinf.cinf_assessment_id = cina.cina_assessment_id
                            FOR XML PATH('FactorsIdentifiedAtAssessment'), TYPE
                        )
                    FROM
                        #ssd_cin_assessments cina
                    WHERE
                        cina.cina_referral_id = cine.cine_referral_id
                    FOR XML PATH('Assessments'), TYPE
                ),
                (
                    SELECT
                        CONVERT(VARCHAR(10), cinp.cinp_cin_plan_start_date, 23)   AS 'CINPlanStartDate'  -- N00689
                        ,CONVERT(VARCHAR(10), cinp.cinp_cin_plan_end_date, 23)   AS 'CINPlanEndDate'    -- N00690
                    FROM
                        #ssd_cin_plans cinp
                    WHERE
                        cinp.cinp_referral_id = cine.cine_referral_id
                    FOR XML PATH('CINPlanDates'), TYPE
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
    ) AS Children
FOR XML PATH('Message');




/* Still to do */
-- CBDS No	XML element
-- N00002	<FormerUPN>
-- N00135	<UPNunknown>
-- N00098	<ExpectedPersonBirthDate>
-- N00108	<PersonDeathDate>
-- N00103	<ReasonForClosure>
-- N00110	<DateOfInitialCPC>
-- N00159	<AssessmentActualStartDate>
-- N00161	<AssessmentInternalReviewDate>
-- N00160	<AssessmentAuthorisationDate>
-- N00181	<AssessmentFactors>
-- N00689	<CINPlanStartDate>
-- N00690	<CINPlanEndDate>
-- N00148	<S47ActualStartDate>
-- N00109	<InitialCPCtarget>
-- N00111	<ICPCnotRequired>
-- N00105	<CPPstartDate>
-- N00115	<CPPendDate>
-- N00113	<InitialCategoryOfAbuse>
-- N00114	<LatestCategoryOfAbuse>
-- N00106	<NumberOfPreviousCPP>
-- N00116	<CPPreviewDate>



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
CREATE TABLE ssd_development.ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team          NVARCHAR(255),              -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_id     NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
);

*/