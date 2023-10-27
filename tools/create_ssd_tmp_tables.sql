

USE HDM;
GO

-- ssd time frame (YRS)
DECLARE @YearsBack INT = 6;

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time



/* Template
=============================================================================
Object Name: 
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]

Remarks: 
Dependencies: 
- 
=============================================================================
*/




/*
=============================================================================
Object Name: ssd_person
Description: person/child details
Author: D2I
Last Modified Date: 2023-10-20
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Need to confirm FACT_903_DATA as source of mother related data
Dependencies: 
- Child_Social.DIM_PERSON
- Child_Social.FACT_REFERRALS
- Child_Social.FACT_CONTACTS
- Child_Social.FACT_EHCP_EPISODE
- Child_Social.FACT_903_DATA
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;

-- Create the temporary table
SELECT 
    p.[EXTERNAL_ID] AS pers_la_person_id,
    p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE] AS pers_sex,
    p.[GENDER_MAIN_CODE] AS pers_gender, -- might need placholder, not available in every LA
    p.[ETHNICITY_MAIN_CODE] AS pers_ethnicity,
    p.[BIRTH_DTTM] AS pers_dob,
    NULL AS pers_common_child_id, -- Set to NULL
    p.[UPN] AS pers_upn,

    (SELECT TOP 1 f.NO_UPN_CODE
    FROM Child_Social.FACT_903_DATA f
    WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
    AND f.NO_UPN_CODE IS NOT NULL
    ORDER BY f.NO_UPN_CODE DESC) AS person_upn_unknown,

    p.[EHM_SEN_FLAG] AS person_send,
    p.[DOB_ESTIMATED] AS person_expected_dob,
    p.[DEATH_DTTM] AS person_death_date,
    p.[NATNL_CODE] AS person_nationality

INTO 
    #ssd_person
FROM 
    Child_Social.DIM_PERSON AS p
WHERE 
    p.[EXTERNAL_ID] IS NOT NULL
AND (
    EXISTS (
        SELECT 1 FROM Child_Social.FACT_REFERRALS fr 
        WHERE fr.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
    )
    OR EXISTS (
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
    )
    OR EXISTS (
        SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
        WHERE fe.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
    )
)
ORDER BY
    p.[EXTERNAL_ID] ASC;

-- Create a non-clustered index on la_person_id for quicker lookups and joins in the temp table
CREATE INDEX IDX_ssd_pers_la_person_id ON #ssd_person(pers_la_person_id);



/* 
=============================================================================
Object Name: ssd_family
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Singleview.DIM_TF_FAMILY
- ssd.ssd_person
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- Create the temporary table
SELECT
    DIM_TF_FAMILY_ID AS fami_id, -- to confirm
    UNIQUE_FAMILY_NUMBER AS fami_family_id,
    EXTERNAL_ID AS fami_la_person_id
INTO #ssd_family
FROM Singleview.DIM_TF_FAMILY AS dtf

WHERE EXISTS ( -- only need address data for matching/relevant records
    SELECT 1 
    FROM #ssd_person AS p
    WHERE dtf.EXTERNAL_ID = p.pers_la_person_id
);

-- Create non-clustered index on la_person_id
CREATE INDEX IDX_family_person ON #ssd_family(fami_la_person_id);



/* 
=============================================================================
Object Name: ssd_address
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Need to verify json obj structure on pre-2014 SQL server instances
Dependencies: 
- DIM_PERSON_ADDRESS
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;

-- Create the temporary table
SELECT
    pa.[DIM_PERSON_ADDRESS_ID] as addr_address_id,
    pa.[EXTERNAL_ID] as addr_la_person_id, -- Assuming EXTERNAL_ID corresponds to la_person_id
    pa.[ADDSS_TYPE_CODE] as addr_address_type,
    pa.[START_DTTM] as addr_address_start,
    pa.[END_DTTM] as addr_address_end,
    pa.[POSTCODE] as addr_address_postcode,
        
    -- Create JSON string for the address
    (
        SELECT 
            NULLIF(pa.[ROOM_NO], '') AS ROOM, 
            NULLIF(pa.[FLOOR_NO], '') AS FLOOR, 
            NULLIF(pa.[FLAT_NO], '') AS FLAT, 
            NULLIF(pa.[BUILDING], '') AS BUILDING, 
            NULLIF(pa.[HOUSE_NO], '') AS HOUSE, 
            NULLIF(pa.[STREET], '') AS STREET, 
            NULLIF(pa.[TOWN], '') AS TOWN,
            NULLIF(pa.[UPRN], '') AS UPRN,
            NULLIF(pa.[EASTING], '') AS EASTING,
            NULLIF(pa.[NORTHING], '') AS NORTHING
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) as addr_address_json

INTO #ssd_address
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa
ORDER BY
    pa.[EXTERNAL_ID] ASC;

-- Add primary key
ALTER TABLE #ssd_address ADD CONSTRAINT PK_address_id PRIMARY KEY (addr_address_id);

-- Non-clustered index on la_person_id
CREATE INDEX IDX_address_person ON #ssd_address(addr_la_person_id);

-- Non-clustered indexes on address_start and address_end
CREATE INDEX IDX_address_start ON #ssd_address(addr_address_start);
CREATE INDEX IDX_address_end ON #ssd_address(addr_address_end);


-- clean up
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;







/* 
=============================================================================
Object Name: ssd_disability
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL 
    DROP TABLE #ssd_disability;

-- Create the temporary table
SELECT TOP 100
    fd.[FACT_DISABILITY_ID] as disability_id,
    fd.[EXTERNAL_ID] as la_person_id,
    fd.[DISABILITY_GROUP_CODE] as person_disability

INTO #ssd_disability
FROM 
    Child_Social.FACT_DISABILITY AS fd
ORDER BY
    fd.[EXTERNAL_ID] ASC;

-- Add primary key constraint to disability_id
ALTER TABLE #ssd_disability
ADD CONSTRAINT PK_disability_id
PRIMARY KEY (disability_id);

-- Create non-clustered index on la_person_id
CREATE INDEX IDX_disability_la_person_id ON #ssd_disability(la_person_id);










/* 
=============================================================================
Object Name: ssd_immigration_status
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;

-- Create the temporary table
SELECT 
    ims.[FACT_IMMIGRATION_STATUS_ID] as immigration_status_id,
    ims.[EXTERNAL_ID] as la_person_id,
    ims.[START_DTTM] as immigration_status_start,
    ims.[END_DTTM] as immigration_status_end,
    ims.[DIM_LOOKUP_IMMGR_STATUS_CODE] as immigration_status
INTO 
    #ssd_immigration_status
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
ORDER BY
    ims.[EXTERNAL_ID] ASC;

-- Set the primary key
ALTER TABLE #ssd_immigration_status
ADD CONSTRAINT PK_immigration_status_id
PRIMARY KEY (immigration_status_id);

-- Non-clustered index on immigration_status_start
CREATE INDEX IDX_immigration_status_start 
ON #ssd_immigration_status(immigration_status_start);

-- Non-clustered index on immigration_status_end
CREATE INDEX IDX_immigration_status_end 
ON #ssd_immigration_status(immigration_status_end);



/* 
=============================================================================
Object Name: ssd_mother
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/

-- Create the temporary table
/*
person_child_id
la_person_id
person_child_dob
*/


/* 
=============================================================================
Object Name: ssd_legal_status
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- Create and insert data into the temporary table using INTO
SELECT
    fls.[FACT_LEGAL_STATUS_ID] AS legal_status_id,
    fls.[EXTERNAL_ID] AS la_person_id,
    fls.[START_DTTM] AS legal_status_start,
    fls.[END_DTTM] AS legal_status_end,
    fls.[DIM_PERSON_ID] AS person_dim_id
INTO 
    #ssd_legal_status
FROM 
    Child_Social.FACT_LEGAL_STATUS AS fls;





/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_contact') IS NOT NULL DROP TABLE #ssd_contact;

-- Create the temporary table
SELECT
	fc.[FACT_CONTACT_ID] as contact_id,
	fc.[EXTERNAL_ID] as la_person_id,
    fc.[START_DTTM] as contact_start,
    fc.[SOURCE_CONTACT] as contact_source,
	fc.[CONTACT_OUTCOMES] as contact_outcome

INTO #ssd_contact

FROM 
    Child_Social.FACT_CONTACTS AS fc

ORDER BY
    fc.[EXTERNAL_ID] ASC;

-- Add primary key
ALTER TABLE #ssd_contact
ADD CONSTRAINT PK_contact_id
PRIMARY KEY (contact_id);


-- Create non-clustered index on la_person_id
CREATE INDEX IDX_contact_person ON #ssd_contact(la_person_id);




/* 
=============================================================================
Object Name: ssd_Early_help
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_early_help') IS NOT NULL DROP TABLE #ssd_early_help;

-- Create the temporary table
/*
eh_episode_id
la_person_id
eh_epi_start_date
eh_epi_end_date
eh_epi_reason
eh_epi_end_reason
eh_epi_org
eh_epi_worker_id
*/


/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_REFERRALS
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- Create the temporary table
SELECT
    fr.FACT_REFERRAL_ID AS cin_referral_id,
    fr.EXTERNAL_ID AS la_person_id,
    fr.REFRL_START_DTTM AS cin_ref_date,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_ID AS cin_primary_need,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC AS cin_ref_source,
    -- Need the appropriate field for cin_ref_outcome
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE AS cin_close_reason,
    fr.REFRL_END_DTTM AS cin_close_date,
    fr.DIM_DEPARTMENT_ID AS cin_ref_team,
    fr.DIM_WORKER_ID AS cin_ref_worker_id

INTO 
    #ssd_cin_episodes

FROM
    Child_Social.FACT_REFERRALS AS fr
WHERE 
    fr.REFRL_START_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE());



/* 
=============================================================================
Object Name: ssd_assessments
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_assessment') IS NOT NULL DROP TABLE #ssd_assessment;

-- Create the temporary table
/*
assessment_id
la_person_id
asmt_start_date
asmt_child_seen
asmt_auth_date
asmt_outcome
asmt_team
asmt_worker_id

-- ??
-- Child_Social FACT_CORE_ASSESSMENT	EXTERNAL_ID
-- Child_Social FACT_INITIAL_ASSESSMENT	EXTERNAL_ID
-- Child_Social FACT_SINGLE_ASSESSMENT	EXTERNAL_ID

-- dbo	DIM_ASSESSMENT_DETAILS	EXTERNAL_ID
*/


/* 
=============================================================================
Object Name: ssd_assessment_factors
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_assessment') IS NOT NULL DROP TABLE #ssd_assessment_factors;

-- Create the temporary table
/*
asmt_id
asmt_factors
*/



/* 
=============================================================================
Object Name: ssd_cin_plans
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cin_plans') IS NOT NULL DROP TABLE #ssd_cin_plans;

-- Create the temporary table
/*
cin_plan_id
la_person_id
cin_plan_Start
cin_plan_end
cin_team
cin_worker_id
*/

/* 
=============================================================================
Object Name: ssd_cin_visits
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_cin_visits') IS NOT NULL DROP TABLE #ssd_cin_visits;

-- Create the temporary table
/*
cin_visit_id
cin_plan_id
cin_visit_date
cin_visit_seen
cin_visit_seen_alone
cin_visit_bedroom

*/




/* 
=============================================================================
Object Name: ssd_s47
Description: 
Author: D2I
Last Modified Date: 24/10/23
DB Compatibility: SQL Server 2014+|...
Version: 0.2
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: s47.[OUTCOME_CP_FLAG] as icpc_outcome, -- needs checking snd s47_enquiry_id coming in as not unique?!? Duplicate vals on s47_enquiry_id. 
Dependencies: 
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_s47_enquiry_icpc') IS NOT NULL DROP TABLE #ssd_s47_enquiry_icpc;

-- Create the temporary table
SELECT
    s47.[FACT_S47_ID] as s47_enquiry_id,
    s47.[EXTERNAL_ID] as la_person_id,
    s47.[START_DTTM] as s47_start_date,
    s47.[START_DTTM] as s47_authorised_date,
    
    -- Checking for existence of a record in FACT_CP_CONFERENCE
    CASE 
        WHEN cpc.[FACT_S47_ID] IS NOT NULL THEN 'CP Plan Started'
        ELSE 'CP Plan not Required'
    END as s47_outcome,

    cpc.[TRANSFER_IN_FLAG] as icpc_transfer_in, 
    cpc.[MEETING_DTTM] as icpc_date,
    -- s47.[OUTCOME_CP_FLAG] as icpc_outcome, -- needs checking
    s47.[COMPLETED_BY_DEPT_ID] as icpc_team,
    s47.[COMPLETED_BY_USER_STAFF_ID] as icpc_worker_id
INTO
    #ssd_s47_enquiry_icpc
FROM 
    Child_Social.FACT_S47 AS s47

-- all records from FACT_S47 even if they don't have a match in FACT_CP_CONFERENCE
LEFT JOIN Child_Social.FACT_CP_CONFERENCE as cpc ON s47.[FACT_S47_ID] = cpc.[FACT_S47_ID]
WHERE 
    s47.[FACT_S47_ID] IS NOT NULL

-- Set s47_enquiry_id as the primary key
ALTER TABLE #ssd_s47_enquiry_icpc ADD PRIMARY KEY (s47_enquiry_id);



/* 
=============================================================================
Object Name: ssd_cp_plans
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks:  worker details/fields to check. 
Dependencies: 
- FACT_CP_PLAN
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_cp_plans') IS NOT NULL DROP TABLE #ssd_cp_plans;

-- Create the temporary table
SELECT 
    cpp.FACT_CP_PLAN_ID AS cppl_cp_plan_id,
    cpp.FACT_REFERRAL_ID AS cppl_referral_id,
    cpp.FACT_INITIAL_CP_CONFERENCE_ID AS cppl_initial_cp_conference_id,
    cpp.DIM_PERSON_ID AS cppl_person_id,
    cpp.START_DTTM AS cppl_cp_plan_start_date,
    cpp.END_DTTM AS cppl_cp_plan_end_date,

    -- Fields for cppl_cp_plan_team and cppl_cp_plan_worker_id are missing
    -- cpp.[] AS CPPL_cp_plan_team
    -- cpp.[] AS CPPL_cp_plan_worker_id

    cpp.INIT_CATEGORY_DESC AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC AS cppl_cp_plan_latest_category,
    cpp.FACT_CP_PLAN_ID AS cppv_cp_plan_id

INTO 
    #ssd_cp_plans

FROM 
    Child_Social.FACT_CP_PLAN AS cpp


/* 
=============================================================================
Object Name: ssd_category_of_abuse
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_cp_visits
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]

Remarks: This has issues, where/what is the fk back to cp_plans? 
Dependencies: 
- FACT_CASENOTES
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_cp_visits') IS NOT NULL DROP TABLE #ssd_cp_visits;

-- Create the temporary table
SELECT 
    cn.FACT_CASENOTE_ID AS cppv_casenote_id, -- need to confirm this JH
    cn.Child_Social.FACT_CASENOTES AS cppv_cp_visit_id,
    cn.EVENT_DTTM AS cppv_cp_visit_date,
    cn.SEEN_FLAG AS cppv_cp_visit_seen,
    cn.SEEN_ALONE_FLAG AS cppv_cp_visit_seen_alone,
    cn.SEEN_BEDROOM_FLAG AS cppv_cp_visit_bedroom
INTO 
    #ssd_cp_visits

FROM 
    Child_Social.FACT_CASENOTES AS cn;

-- Set the primary key
ALTER TABLE #ssd_cp_visits
ADD CONSTRAINT PK_cppv_casenote_id PRIMARY KEY (cppv_casenote_id);

-- WHERE DIM_LOOKUP_CASNT_TYPE_ID_DESC IN ( 'STVC','STVCPCOVID')

/* 
=============================================================================
Object Name: ssd_cp_reviews
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_cp_reviews_risks
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_cla_episodes
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_cla_convictions
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/




/* 
=============================================================================
Object Name: ssd_cla_health
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_cla_immunisations
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_substance_misuse
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cla_Substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_Substance_misuse;


-- Create the temporary table
SELECT 
    fsm.[FACT_SUBSTANCE_MISUSE_ID] as substance_misuse_id,
    fsm.[EXTERNAL_ID] as la_person_id,
    fsm.[CREATE_DTTM] as create_date,
    fsm.[DIM_PERSON_ID] as person_dim_id,
    fsm.[START_DTTM] as start_date,
    fsm.[END_DTTM] as end_date,
    fsm.[DIM_LOOKUP_SUBSTANCE_TYPE_ID] as substance_type_id,
    fsm.[DIM_LOOKUP_SUBSTANCE_TYPE_CODE] as substance_type_code

INTO 
    #ssd_cla_Substance_misuse

FROM 
    Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;

-- Set the primary key on substance_misuse_id
ALTER TABLE #ssd_cla_Substance_misuse
ADD CONSTRAINT PK_substance_misuse_id_temp
PRIMARY KEY (substance_misuse_id);





/* 
=============================================================================
Object Name: ssd_placement
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_placement') IS NOT NULL DROP TABLE #ssd_placement;




/* 
=============================================================================
Object Name: ssd_cla_reviews
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
-- IF OBJECT_ID('tempdb..#ssd_cla_reviews') IS NOT NULL DROP TABLE #ssd_cla_reviews;

-- SELECT 
-- FACT_CLA_REVIEW.[FACT_CLA_REVIEW_ID] as cp_review_id
-- --FACT_CLA_REVIEW.[] as cp_plan_id -- FACT_CLA_ID? 
-- FACT_CLA_REVIEW.[DUE_DTTM] as cp_rev_due
-- --FACT_CLA_REVIEW.[START_DTTM] as cp_rev_date
-- --FACT_CLA_REVIEW.[] as cp_rev_outcome
-- --FACT_CLA_REVIEW.[] as cp_rev_quorate
-- --FACT_CLA_REVIEW.[] as cp_rev_participation
-- --FACT_CLA_REVIEW.[] as cp_rev_cyp_views_quality
-- --FACT_CLA_REVIEW.[] as cp_rev_sufficient_prog
-- --FACT_CLA_REVIEW.[] as cp_review_id
-- --FACT_CLA_REVIEW.[] as cp_review_risks

-- INTO #ssd_cla_reviews

-- FROM FACT_CLA_REVIEW



/* 
=============================================================================
Object Name: ssd_cla_previous_permanence
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;


/* 
=============================================================================
Object Name: ssd_cla_care_plan
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cla_care_plan') IS NOT NULL DROP TABLE #ssd_cla_care_plan;


/* 
=============================================================================
Object Name: ssd_cla_visits
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_sdq_scores
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_missing
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_care_leavers
Description: 
Author: D2I
Last Modified Date:
DB Compatibility: SQL Server 2014+|... 
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_permanence
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_send
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL
   DROP TABLE #ssd_send;

-- Create the temporary table
SELECT 
    -- need id field
    f.EXTERNAL_ID, 
    f.FACT_903_DATA_ID,
    f.DIM_PERSON_ID, 
    f.NO_UPN_CODE,

    p.ULN -- Education schema? 
INTO 
    #ssd_send 
FROM 
    Child_Social.FACT_903_DATA AS f
LEFT JOIN 
    Education.DIM_PERSON AS p ON f.DIM_PERSON_ID = p.DIM_PERSON_ID;





/* 
=============================================================================
Object Name: ssd_ehcp_assessment
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_ehcp_named_plan
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_ehcp_active_plans
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/

/* 
=============================================================================
Object Name: ssd_send_need
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/


/* 
=============================================================================
Object Name: ssd_social_worker
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- FACT_CASEWORKER.FACT_CASEWORKER_ID as sw_id
-- sw_epi_start_date
-- sw_epi_end_date
-- sw_change_reason
-- FACT_CASEWORKER.AGENCY as sw_agency
-- FACT_CASEWORKER.DIM_LOOKUP_PROF_ROLE_ID_CODE as sw_role
-- sw_caseload
-- sw_qualification


/* 
=============================================================================
Object Name: ssd_pre_proceedings
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/

/* 
=============================================================================
Object Name: ssd_voice_of_child
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/










/* ********************************************************************************************************** */
/*
Development clean up etc
*/

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* cleanup */
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;


/* ********************************************************************************************************** */

