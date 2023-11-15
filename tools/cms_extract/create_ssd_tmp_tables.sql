

/* ********************************************************************************************************** */
/* Development set up */

-- Note: 
-- This script is for creating TMP(Temporary) tables within the temp DB name space for testing purposes. 
-- SSD extract files with the suffix ..._per.sql - for creating the persistent table versions.
-- SSD extract files with the suffix ..._tmp.sql - for creating the temporary table versions.

USE HDM;
GO

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time
/* ********************************************************************************************************** */



-- ssd time-frame (YRS)
DECLARE @ssd_timeframe_years INT = 6;
        @ssd_sub1_range_years INT = 1;


/* Temp notes: inner join alternative
WHERE
    EXISTS (
        SELECT 1
        FROM ssd_person AS sp
        WHERE sp.pers_person_id = fsm.DIM_PERSON_ID
    );
*/



/* Template header
=============================================================================
Object Name: #temp_table_name
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
Object Name: #ssd_person
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

-- Create temporary structure
SELECT 
    p.[EXTERNAL_ID]                         AS pers_la_person_id,
    p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE]    AS pers_sex,
    p.[GENDER_MAIN_CODE]                    AS pers_gender, -- might need placholder, not available in every LA
    p.[ETHNICITY_MAIN_CODE]                 AS pers_ethnicity,
    p.[BIRTH_DTTM]                          AS pers_dob,
    NULL                                    AS pers_common_child_id, -- Set to NULL
    p.[UPN]                                 AS pers_upn,

    (SELECT f.NO_UPN_CODE
    FROM Child_Social.FACT_903_DATA f
    WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
    AND f.NO_UPN_CODE IS NOT NULL
    ORDER BY f.NO_UPN_CODE DESC)            AS pers_upn_unknown,

    p.[EHM_SEN_FLAG]                        AS pers_send,
    p.[DOB_ESTIMATED]                       AS pers_expected_dob,
    p.[DEATH_DTTM]                          AS pers_death_date,
    p.[NATNL_CODE]                          AS pers_nationality

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
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
        WHERE fe.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
)
ORDER BY
    p.[EXTERNAL_ID] ASC;



/* 
=============================================================================
Object Name: #ssd_family
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

-- Create temporary structure
SELECT
    DIM_TF_FAMILY_ID AS fami_id, -- to confirm/needs checking
    UNIQUE_FAMILY_NUMBER AS fami_family_id,
    EXTERNAL_ID AS fami_la_person_id
INTO #ssd_family
FROM Singleview.DIM_TF_FAMILY AS dtf

WHERE EXISTS ( -- only need address data for matching/relevant records
    SELECT 1 
    FROM #ssd_person AS p
    WHERE dtf.EXTERNAL_ID = p.pers_la_person_id
);



/* 
=============================================================================
Object Name: #ssd_address
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

-- Create temporary structure
SELECT
    pa.[DIM_PERSON_ADDRESS_ID] as addr_table_id,
    pa.[EXTERNAL_ID] as addr_person_id, -- Assuming EXTERNAL_ID corresponds to la_person_id
    pa.[ADDSS_TYPE_CODE] as addr_address_type,
    pa.[START_DTTM] as addr_address_start,
    pa.[END_DTTM] as addr_address_end,
    REPLACE(pa.[POSTCODE], ' ', '') as addr_address_postcode, -- whitespace removed to enforce data quality
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


-- Create constraint(s)
ALTER TABLE #ssd_address ADD CONSTRAINT PK_address_id 
PRIMARY KEY (addr_address_id);





/* 
=============================================================================
Object Name: ssd_disability
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_DISABILITY
- ssd_person
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

SELECT 
    fd.FACT_DISABILITY_ID       AS disa_table_id, 
    fd.EXTERNAL_ID              AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
INTO #ssd_disability
FROM 
    Child_Social.FACT_DISABILITY AS fd;



-- Create constraint(s)
ALTER TABLE #ssd_disability ADD CONSTRAINT PK_ssd_disability 
PRIMARY KEY (disa_id);

ALTER TABLE #ssd_disability ADD CONSTRAINT FK_ssd_disability_person
FOREIGN KEY (disa_person_id) REFERENCES #ssd_person(pers_person_id);









/* 
=============================================================================
Object Name: #ssd_immigration_status
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_IMMIGRATION_STATUS
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;

-- Create structure
SELECT 
    ims.[FACT_IMMIGRATION_STATUS_ID]    as immi_immigration_status_id,
    ims.[EXTERNAL_ID]                   as immi__person_id,
    ims.[START_DTTM]                    as immi_immigration_status_start,
    ims.[END_DTTM]                      as immi_immigration_status_end,
    ims.[DIM_LOOKUP_IMMGR_STATUS_CODE]  as immi_immigration_status
INTO 
    #ssd_immigration_status
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
ORDER BY
    ims.[EXTERNAL_ID] ASC;

)
-- Create constraint(s)
ALTER TABLE #ssd_immigration_status ADD CONSTRAINT PK_immigration_status_id
PRIMARY KEY (immi_immigration_status_id);



/* 
=============================================================================
Object Name: #ssd_mother
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_PERSON_RELATION
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;

-- Create structure
SELECT 
    pr.DIM_PERSON_ID            AS moth_person_id PRIMARY KEY,
    pr.DIM_RELATED_PERSON_ID    AS moth_childs_person_id,
    pr.DIM_RELATED_PERSON_DOB   AS moth_childs_dob

INTO #ssd_mother
FROM 
    FACT_PERSON_RELATION AS pr;


-- Create constraint(s)
ALTER TABLE #ssd_mother ADD CONSTRAINT FK_mother_person
FOREIGN KEY (moth_person_id) REFERENCES #ssd_person(pers_person_id);


/* 
=============================================================================
Object Name: #ssd_legal_status
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_LEGAL_STATUS
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- Create temporary structure
SELECT
    fls.[FACT_LEGAL_STATUS_ID]  AS lega_legal_status_id,
    fls.[DIM_PERSON_ID]         AS lega_person_id,
    fls.[START_DTTM]            AS lega_legal_status_start,
    fls.[END_DTTM]              AS lega_legal_status_end
INTO 
    #ssd_legal_status
FROM 
    Child_Social.FACT_LEGAL_STATUS AS fls;


-- Create constraint(s)
ALTER TABLE #ssd_legal_status ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES #ssd_person(pers_person_id);


/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/
--- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_contact') IS NOT NULL DROP TABLE #ssd_contact;

-- Create temporary structure
CREATE TABLE #ssd_contact (
    cont_contact_id         NVARCHAR(48) PRIMARY KEY,
    cont_person_id          NVARCHAR(48),
    cont_contact_start      DATETIME,
    cont_contact_source     NVARCHAR(255), 
    cont_contact_outcome_json NVARCHAR(MAX)
);

-- Insert data
INSERT INTO #ssd_contact (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_start,
    cont_contact_source,
    cont_contact_outcome_json
)
SELECT 
    fc.[FACT_CONTACT_ID],
    fc.[EXTERNAL_ID],
    fc.[CONTACT_DTTM],
    fc.[DIM_LOOKUP_CONT_SORC_ID],
    (
        SELECT 
            NULLIF(fc.OUTCOME_NEW_REFERRAL_FLAG, '')           AS "OUTCOME_NEW_REFERRAL_FLAG",
            NULLIF(fc.OUTCOME_EXISTING_REFERRAL_FLAG, '')      AS "OUTCOME_EXISTING_REFERRAL_FLAG",
            NULLIF(fc.OUTCOME_CP_ENQUIRY_FLAG, '')             AS "OUTCOME_CP_ENQUIRY_FLAG",
            NULLIF(fc.OUTCOME_NFA_FLAG, '')                    AS "OUTCOME_NFA_FLAG",
            NULLIF(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '')    AS "OUTCOME_NON_AGENCY_ADOPTION_FLAG",
            NULLIF(fc.OUTCOME_PRIVATE_FOSTERING_FLAG, '')      AS "OUTCOME_PRIVATE_FOSTERING_FLAG",
            NULLIF(fc.OUTCOME_ADVICE_FLAG, '')                 AS "OUTCOME_ADVICE_FLAG",
            NULLIF(fc.OUTCOME_MISSING_FLAG, '')                AS "OUTCOME_MISSING_FLAG",
            NULLIF(fc.OUTCOME_OLA_CP_FLAG, '')                 AS "OUTCOME_OLA_CP_FLAG",
            NULLIF(fc.OTHER_OUTCOMES_EXIST_FLAG, '')           AS "OTHER_OUTCOMES_EXIST_FLAG"
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cont_contact_outcome_json
FROM 
    Child_Social.FACT_CONTACTS AS fc;







/* 
=============================================================================
Object Name: #ssd_early_help_episodes
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
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL 
    DROP TABLE #ssd_early_help_episodes;

-- Create temporary structure
SELECT
    cafe.FACT_CAF_EPISODE_ID AS earl_episode_id,
    cafe.DIM_PERSON_ID AS earl_person_id,
    cafe.EPISODE_START_DTTM AS earl_episode_start_date,
    cafe.EPISODE_END_DTTM AS earl_episode_end_date,
    cafe.START_REASON AS earl_episode_reason,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE AS earl_episode_end_reason,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE AS earl_episode_organisation,
    'placeholder data' AS earl_episode_worker_id
INTO 
    #ssd_early_help_episodes
FROM 
    Child_Social.FACT_CAF_EPISODE AS cafe;



/* 
=============================================================================
Object Name: #ssd_cin_episodes
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

-- Create temporary structure
CREATE TABLE #ssd_cin_episodes
(
    cine_referral_id INT,
    cine_person_id NVARCHAR(48),
    cine_referral_date DATETIME,
    cine_cin_primary_need INT,
    cine_referral_source NVARCHAR(255),
    cine_referral_outcome_json NVARCHAR(500),
    cine_referral_nfa NCHAR(1),
    cine_close_reason NVARCHAR(255),
    cine_close_date DATETIME,
    cine_referral_team NVARCHAR(255),
    cine_referral_worker_id NVARCHAR(48)
);

-- Insert data
INSERT INTO #ssd_cin_episodes
(
    cine_referral_id,
    cine_person_id,
    cine_referral_date,
    cine_cin_primary_need,
    cine_referral_source,
    cine_referral_outcome_json,
    cine_referral_nfa,
    cine_close_reason,
    cine_close_date,
    cine_referral_team,
    cine_referral_worker_id
)
SELECT 
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC,
    (
        SELECT 
            NULLIF(fr.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')   AS "OUTCOME_SINGLE_ASSESSMENT_FLAG",
            NULLIF(fr.OUTCOME_NFA_FLAG, '')                 AS "OUTCOME_NFA_FLAG",
            NULLIF(fr.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS "OUTCOME_STRATEGY_DISCUSSION_FLAG",
            NULLIF(fr.OUTCOME_CLA_REQUEST_FLAG, '')         AS "OUTCOME_CLA_REQUEST_FLAG",
            NULLIF(fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '') AS "OUTCOME_NON_AGENCY_ADOPTION_FLAG",
            NULLIF(fr.OUTCOME_PRIVATE_FOSTERING_FLAG, '')   AS "OUTCOME_PRIVATE_FOSTERING_FLAG",
            NULLIF(fr.OUTCOME_CP_TRANSFER_IN_FLAG, '')      AS "OUTCOME_CP_TRANSFER_IN_FLAG",
            NULLIF(fr.OUTCOME_CP_CONFERENCE_FLAG, '')       AS "OUTCOME_CP_CONFERENCE_FLAG",
            NULLIF(fr.OUTCOME_CARE_LEAVER_FLAG, '')         AS "OUTCOME_CARE_LEAVER_FLAG",
            NULLIF(fr.OTHER_OUTCOMES_EXIST_FLAG, '')        AS "OTHER_OUTCOMES_EXIST_FLAG"
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    fr.OUTCOME_NFA_FLAG,
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
    fr.REFRL_END_DTTM,
    fr.DIM_DEPARTMENT_ID_DESC,
    fr.DIM_WORKER_ID_DESC
FROM 
    Child_Social.FACT_REFERRALS AS fr
WHERE 
    fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE());





/* 
=============================================================================
Object Name: #ssd_assessments
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SINGLE_ASSESSMENT
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;

-- Create temporary structure
CREATE TABLE #ssd_cin_assessments
(
    cina_assessment_id NVARCHAR(48) PRIMARY KEY,
    cina_person_id NVARCHAR(48),
    cina_referral_id NVARCHAR(48),
    cina_assessment_start_date DATETIME,
    cina_assessment_child_seen NCHAR(1),
    cina_assessment_auth_date DATETIME, -- This needs checking !! 
    cina_assessment_outcome_json NVARCHAR(500),
    cina_assessment_outcome_nfa NCHAR(1),
    cina_assessment_team NVARCHAR(255),
    cina_assessment_worker_id NVARCHAR(48)
);

-- Insert data
INSERT INTO #ssd_cin_assessments
(
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date, -- This needs checking !! 
    cina_assessment_outcome_json,
    cina_assessment_outcome_nfa,
    cina_assessment_team,
    cina_assessment_worker_id
)
SELECT 
    fa.FACT_SINGLE_ASSESSMENT_ID,
    fa.DIM_PERSON_ID,
    fa.FACT_REFERRAL_ID,
    fa.START_DTTM,
    fa.SEEN_FLAG,
    fa.START_DTTM, -- This needs checking !! 
    (
        SELECT 
            NULLIF(fa.OUTCOME_NFA_FLAG, '')                     AS "OUTCOME_NFA_FLAG",
            NULLIF(fa.OUTCOME_NFA_S47_END_FLAG, '')             AS "OUTCOME_NFA_S47_END_FLAG",
            NULLIF(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '')     AS "OUTCOME_STRATEGY_DISCUSSION_FLAG",
            NULLIF(fa.OUTCOME_CLA_REQUEST_FLAG, '')             AS "OUTCOME_CLA_REQUEST_FLAG",
            NULLIF(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')       AS "OUTCOME_PRIVATE_FOSTERING_FLAG",
            NULLIF(fa.OUTCOME_LEGAL_ACTION_FLAG, '')            AS "OUTCOME_LEGAL_ACTION_FLAG",
            NULLIF(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')        AS "OUTCOME_PROV_OF_SERVICES_FLAG",
            NULLIF(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')         AS "OUTCOME_PROV_OF_SB_CARE_FLAG",
            NULLIF(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '')   AS "OUTCOME_SPECIALIST_ASSESSMENT_FLAG",
            NULLIF(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')   AS "OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG",
            NULLIF(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')           AS "OUTCOME_OTHER_ACTIONS_FLAG",
            NULLIF(fa.OTHER_OUTCOMES_EXIST_FLAG, '')            AS "OTHER_OUTCOMES_EXIST_FLAG",
            NULLIF(fa.TOTAL_NO_OF_OUTCOMES, '')                 AS "TOTAL_NO_OF_OUTCOMES",
            NULLIF(fa.OUTCOME_COMMENTS, '')                     AS "OUTCOME_COMMENTS"
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ),
    fa.OUTCOME_NFA_FLAG,
    fa.COMPLETED_BY_DEPT_NAME,
    fa.COMPLETED_BY_USER_STAFF_ID
FROM 
    FACT_SINGLE_ASSESSMENT AS fa;


-- Create constraint(s)
ALTER TABLE #ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE #ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_social_worker 
FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_social_worker(socw_social_worker_id);





/* 
=============================================================================
Object Name: #ssd_assessment_factors
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

-- Create temporary structure
/*
asmt_id
asmt_factors
*/



/* 
=============================================================================
Object Name: #sd_cin_plans
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
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;

-- Create structure
CREATE TABLE #ssd_cin_plans (
    cinp_referral_id NVARCHAR(48), 
    cinp_person_id NVARCHAR(48), 
    cinp_cin_plan_start DATETIME,
    cinp_cin_plan_end DATETIME,
    cinp_cin_plan_team NVARCHAR(255),
    cinp_cin_plan_worker_id NVARCHAR(48)
);

-- Insert data
INSERT INTO #ssd_cin_plans (
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start,
    cinp_cin_plan_end,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT 
    fp.FACT_REFERRAL_ID                AS cinp_referral_id,
    fp.DIM_PERSON_ID                   AS cinp_person_id,
    fp.START_DTTM                      AS cinp_cin_plan_start,
    fp.END_DTTM                        AS cinp_cin_plan_end,
    cpd.DIM_OUTCM_CREATE_BY_DEPT_ID    AS cinp_cin_plan_team,
    cpd.DIM_NEED_CREATE_BY_ID          AS cinp_cin_plan_worker_id
FROM FACT_CARE_PLANS AS fp
JOIN FACT_CARE_PLAN_DETAILS AS cpd              -- Needs checking!!
ON fp.FACT_REFERRAL_ID = cpd.FACT_REFERRAL_ID;  -- Needs checking!!


-- Create constraint(s)
ALTER TABLE #ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES #ssd_person(pers_person_id);


/* 
=============================================================================
Object Name: #ssd_cin_visits
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

-- Create structure
CREATE TABLE #ssd_cin_visits
(
    cinv_cin_casenote_id NVARCHAR(48) PRIMARY KEY, -- This needs checking!!
    cinv_cin_visit_id NVARCHAR(48), -- This needs checking!!
    cinv_cin_plan_id NVARCHAR(48),
    cinv_cin_visit_date DATETIME,
    cinv_cin_visit_seen NCHAR(1),
    cinv_cin_visit_seen_alone NCHAR(1),
    cinv_cin_visit_bedroom NCHAR(1)
);

-- Insert data
INSERT INTO #ssd_cin_visits
(
    cinv_cin_casenote_id, -- This needs checking!!
    cinv_cin_visit_id, -- This needs checking!!
    cinv_cin_plan_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)
SELECT 
    cn.FACT_CASENOTE_ID, -- This needs checking!!
    'PLACEHOLDER DATA', -- This needs checking!!
    cn.FACT_FORM_ID,
    cn.EVENT_DTTM,
    cn.SEEN_FLAG,
    cn.SEEN_ALONE_FLAG,
    cn.SEEN_BEDROOM_FLAG
FROM 
    Child_Social.FACT_CASENOTES cn;

-- Create constraint(s)
ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_cin_plans 
FOREIGN KEY (cinv_cin_plan_id) REFERENCES ssd_cin_plans(cinp_cin_plan_id);


/* 
=============================================================================
Object Name: #ssd_s47
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

-- Create temporary structure
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

-- Create constraint(s)
ALTER TABLE #ssd_s47_enquiry_icpc ADD PRIMARY KEY (s47_enquiry_id);



/* 
=============================================================================
Object Name: #ssd_cp_plans
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

-- Create temporary structure
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
Object Name: #ssd_category_of_abuse
Description: 
Author: D2I
Last Modified Date: 06/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_CONTEXT_CASE_WORKER
=============================================================================
*/

-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_category_of_abuse') IS NOT NULL DROP TABLE #ssd_category_of_abuse;






/* 
=============================================================================
Object Name: #ssd_cp_visits
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

-- Create temporary structure
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

-- Create constraint(s)
ALTER TABLE #ssd_cp_visits ADD CONSTRAINT PK_cppv_casenote_id 
PRIMARY KEY (cppv_casenote_id);

-- WHERE DIM_LOOKUP_CASNT_TYPE_ID_DESC IN ( 'STVC','STVCPCOVID')





/* 
=============================================================================
Object Name: #ssd_cp_reviews
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
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL DROP TABLE #ssd_cp_reviews;

-- Create structure
CREATE TABLE #ssd_cp_reviews
(
    cppr_cp_review_id           NVARCHAR(36) PRIMARY KEY,
    cppr_cp_plan_id             NVARCHAR(36),
    cppr_cp_review_due          DATETIME,
    cppr_cp_review_date         DATETIME,
    cppr_cp_review_outcome      NCHAR(1),
    cppr_cp_review_quorate      NCHAR(1) DEFAULT '0', -- using '0' as placeholder
    cppr_cp_review_participation NCHAR(1) DEFAULT '0' -- using '0' as placeholder
);

-- Insert data
INSERT INTO #ssd_cp_reviews
(
    cppr_cp_review_id,
    cppr_cp_plan_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_outcome,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
)
SELECT 
    FACT_CP_REVIEW_ID,
    FACT_CP_PLAN_ID,
    DUE_DTTM,
    MEETING_DTTM,
    OUTCOME_CONTINUE_CP_FLAG,
    '0', -- Placeholder for cppr_cp_review_quorate
    '0'  -- Placeholder for cppr_cp_review_participation
FROM 
    Child_Social.FACT_CP_REVIEW;

-- Create constraint(s)
ALTER TABLE #ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);






/* 
=============================================================================
Object Name: #ssd_cp_reviews_risks
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
Object Name: #ssd_cla_episodes
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
Object Name: #ssd_cla_convictions
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
Object Name: #ssd_cla_health
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
Object Name: #ssd_cla_immunisations
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
Object Name: #ssd_substance_misuse
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
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

-- Create structure 
CREATE TABLE #ssd_cla_substance_misuse (
    clas_substance_misuse_id       NVARCHAR(48) PRIMARY KEY,
    clas_person_id                 NVARCHAR(48),
    clas_substance_misuse_date     DATETIME,
    clas_substance_misused         NCHAR(100),
    clas_intervention_received     NCHAR(1)
);

-- Insert data 
INSERT INTO #ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)
SELECT 
    fsm.FACT_SUBSTANCE_MISUSE_ID               AS clas_substance_misuse_id,
    fsm.DIM_PERSON_ID                          AS clas_person_id,
    fsm.START_DTTM                             AS clas_substance_misuse_date,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE         AS clas_substance_misused,
    fsm.ACCEPT_FLAG                            AS clas_intervention_received
FROM 
    Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;
INNER JOIN 
    ssd_person AS p ON fsm.DIM_PERSON_ID = p.pers_person_id;



/* 
=============================================================================
Object Name: #ssd_placement
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
Object Name: #ssd_cla_reviews
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

-- Create temporary structure
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
Object Name: #ssd_cla_previous_permanence
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
Object Name: #ssd_cla_care_plan
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
Object Name: #ssd_cla_visits
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
Object Name: #ssd_sdq_scores
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
Object Name: #ssd_missing
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

-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_missing') IS NOT NULL DROP TABLE #ssd_missing;

-- Create structure
CREATE TABLE #ssd_missing (
    miss_table_id           NVARCHAR(48),
    miss_la_person_id       NVARCHAR(48),
    miss_mis_epi_start      DATETIME,
    miss_mis_epi_type       NVARCHAR(100),
    miss_mis_epi_end        DATETIME,
    miss_mis_epi_rhi_offered NCHAR(1),
    miss_mis_epi_rhi_accepted NCHAR(1)
);

-- Insert data
INSERT INTO #ssd_missing (
    miss_table_id,
    miss_la_person_id,
    miss_mis_epi_start,
    miss_mis_epi_type,
    miss_mis_epi_end,
    miss_mis_epi_rhi_offered,
    miss_mis_epi_rhi_accepted
)
SELECT 
    fmp.FACT_MISSING_PERSON_ID      AS miss_table_id,
    fmp.DIM_PERSON_ID               AS miss_la_person_id,
    fmp.START_DTTM                  AS miss_mis_epi_start,
    fmp.MISSING_STATUS              AS miss_mis_epi_type,
    fmp.END_DTTM                    AS miss_mis_epi_end,
    fmp.RETURN_INTERVIEW_OFFERED    AS miss_mis_epi_rhi_offered,
    fmp.RETURN_INTERVIEW_ACCEPTED	AS miss_mis_epi_rhi_accepted
FROM 
    Child_Social.FACT_MISSING_PERSON AS fmp;

INNER JOIN 
    ssd_person AS p ON fmp.DIM_PERSON_ID = p.pers_person_id;



/* 
=============================================================================
Object Name: #ssd_care_leavers
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
Object Name: #ssd_permanence
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
Object Name: #ssd_send
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

-- Create temporary structure
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
Object Name: #ssd_ehcp_assessment
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
Object Name: #ssd_ehcp_named_plan
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
Object Name: #ssd_ehcp_active_plans
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
Object Name: #ssd_send_need
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
Object Name: #ssd_social_worker
Description: 
Author: D2I
Last Modified Date: 06/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_CONTEXT_CASE_WORKER
=============================================================================
*/

-- Check if exists, & drop
IF OBJECT_ID('tempdb..#ssd_social_worker') IS NOT NULL DROP TABLE #ssd_social_worker;

-- Create structure ,
CREATE TABLE #ssd_social_worker(
    socw_social_worker_id           NVARCHAR(48),
    socw_worker_episode_start_date  DATETIME,
    socw_worker_episode_end_date    DATETIME,
    socw_worker_change_reason       NVARCHAR(48)
);

-- Insert data,
INSERT INTO #ssd_social_worker (
    socw_social_worker_id, 
    socw_worker_episode_start_date, 
    socw_worker_episode_end_date, 
    socw_worker_change_reason
)
SELECT 
    [DIM_WORKER_ID]             AS socw_social_worker_id,
    [START_DTTM]                AS socw_worker_episode_start_date,
    [END_DTTM]                  AS socw_worker_episode_end_date,
    [DIM_LOOKUP_CWREASON_CODE]  AS socw_worker_change_reason
FROM 
    Child_Social.FACT_CONTEXT_CASE_WORKER;

/* 
=============================================================================
Object Name: #ssd_pre_proceedings
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
Object Name: #ssd_voice_of_child
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
IF OBJECT_ID('tempdb..#ssd_voice_of_child') IS NOT NULL DROP TABLE #ssd_voice_of_child;

-- Create structure
CREATE TABLE #ssd_voice_of_child (
    voch_person_id NVARCHAR(48) PRIMARY KEY, -- Assuming NVARCHAR() as a generic type for id
    voch_explained_worries NCHAR(1),
    voch_story_help_understand NCHAR(1),
    voch_agree_worker NCHAR(1),
    voch_plan_safe NCHAR(1),
    voch_tablet_help_explain NCHAR(1)
);

-- Insert placeholder data
INSERT INTO #ssd_voice_of_child (
    voch_person_id,
    voch_explained_worries,
    voch_story_help_understand,
    voch_agree_worker,
    voch_plan_safe,
    voch_tablet_help_explain
)
VALUES
    ('ID001', 'Y', 'Y', 'Y', 'N', 'N'),
    ('ID002', 'Y', 'Y', 'Y', 'N', 'N');


ALTER TABLE Child_Social.#ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES #ssd_person(pers_person_id);








/* ********************************************************************************************************** */
/*
Development clean up etc
*/

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* cleanup */
/* Drop commands only appear in the TEMP/TEST table defs script */
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;




/* ********************************************************************************************************** */

