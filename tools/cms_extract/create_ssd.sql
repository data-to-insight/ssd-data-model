
/* DEV Notes:
- Although returns expect dd/mm/YYYY formating on dates. Extract maintains DATETIME not DATE, nor formatted nvarchar string to avoid conversion issues.
- Full review needed of max/exagerated/default new field type sizes e.g. family_id NVARCHAR(255)  (keys cannot use MAX)
*/



/* ********************************************************************************************************** */
/* Development set up */

-- Note: 
-- This script is for creating PER(Persistent) tables within the temp DB name space for testing purposes. 
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
-- check exists & drop
IF OBJECT_ID('Child_Social.ssd_person') IS NOT NULL DROP TABLE Child_Social.ssd_person;

-- Create structure
CREATE TABLE ssd_person (
    pers_la_person_id NVARCHAR(36) PRIMARY KEY, 
    pers_sex NVARCHAR(48),
    pers_ethnicity NVARCHAR(38),
    pers_dob DATETIME,
    pers_common_child_id NVARCHAR(10),
    pers_upn NVARCHAR(20),
    pers_upn_unknown NVARCHAR(96),
    pers_send NVARCHAR(1),
    pers_expected_dob DATETIME,
    pers_death_date DATETIME,
    pers_nationality NVARCHAR(48)
);

-- Insert data 
INSERT INTO ssd_person (
    pers_la_person_id,
    pers_sex,
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,
    pers_upn,
    pers_upn_unknown,
    pers_send,
    pers_expected_dob,
    pers_death_date,
    pers_nationality
)
SELECT 
    p.[EXTERNAL_ID],
    p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE],
    p.[ETHNICITY_MAIN_CODE],
    p.[BIRTH_DTTM],
    NULL AS pers_common_child_id, -- Set to NULL
    p.[UPN],

    (SELECT TOP 1 f.NO_UPN_CODE              -- Subquery to fetch ANY/MOST RECENT? NO_UPN_CODE.
    FROM Child_Social.FACT_903_DATA f        -- This *unlikely* to be the best source
    WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
    AND f.NO_UPN_CODE IS NOT NULL
    ORDER BY f.NO_UPN_CODE DESC) AS pers_upn_unknown,  -- desc order to ensure a non-null value first

    p.[EHM_SEN_FLAG],
    p.[DOB_ESTIMATED],
    p.[DEATH_DTTM],
    p.[NATNL_CODE]

FROM 
    Child_Social.DIM_PERSON AS p
WHERE 
    p.[EXTERNAL_ID] IS NOT NULL
AND (
    EXISTS (
        -- has open referral
        SELECT 1 FROM Child_Social.FACT_REFERRALS fr 
        WHERE fr.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- contact in last x@yrs
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- ehcp request in last x@yrs
        SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
        WHERE fe.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    -- OR EXISTS (
        -- active plan or has been active in x@yrs
    --)
    -- OR EXISTS (
        -- eh_referral open in last x@yrs
    --)
    -- OR EXISTS (
        -- record in send
    --)
)
ORDER BY
    p.[EXTERNAL_ID] ASC;

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_ssd_person_la_person_id ON Child_Social.ssd_person(pers_la_person_id);

-- [done]has open referral - FACT_REFERRALS.REFRL_START_DTTM
-- [done]contact in last 6yrs - Child_Social.FACT_CONTACTS.CONTACT_DTTM
-- [done]ehcp request in last 6yrs - Child_Social.FACT_EHCP_EPISODE.REQUEST_DTTM ;
-- active plan or has been active in 6yrs
-- eh_referral open in last 6yrs - Child_Social.FACT_REFERRALS.REFRL_START_DTTM
-- record in send - where from ? Child_Social.FACT_SEN, DIM_LOOKUP_SEN, DIM_LOOKUP_SEN_TYPE





/* 
=============================================================================
Object Name: ssd_family
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
Dependencies: 
- Singleview.DIM_TF_FAMILY
- ssd.ssd_person
=============================================================================
*/
-- check exists & drop
IF OBJECT_ID('Child_Social.ssd_family') IS NOT NULL DROP TABLE Child_Social.ssd_family;


-- Create structure
CREATE TABLE Child_Social.ssd_family (
    fami_DIM_TF_FAMILY_ID NVARCHAR(255) PRIMARY KEY, 
    fami_family_id NVARCHAR(255),
    fami_la_person_id NVARCHAR(255),
    
    -- Define foreign key constraint
    FOREIGN KEY (fami_la_person_id) REFERENCES Child_Social.person(pers_la_person_id)
);

-- Insert data 
INSERT INTO Child_Social.ssd_family (
    fami_DIM_TF_FAMILY_ID, 
    fami_family_id, 
    fami_la_person_id
    )
SELECT 
    DIM_TF_FAMILY_ID,
    UNIQUE_FAMILY_NUMBER    as fami_family_id,
    EXTERNAL_ID             as fami_la_person_id
FROM Singleview.DIM_TF_FAMILY
WHERE EXISTS ( -- only need address data for matching/relevant records
    SELECT 1 
    FROM Child_Social.ssd_person p
    WHERE p.pers_la_person_id = f.EXTERNAL_ID
    );

-- Create a non-clustered index on foreign key
CREATE INDEX IDX_family_person ON Child_Social.ssd_family(fami_la_person_id);




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
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_address') IS NOT NULL DROP TABLE Child_Social.ssd_address;


-- Create structure
CREATE TABLE Child_Social.ssd_address (
    addr_address_id NVARCHAR(255) PRIMARY KEY,
    addr_person_id NVARCHAR(255), -- Assuming EXTERNAL_ID corresponds to la_person_id
    addr_address_type NVARCHAR(MAX),
    addr_address_start DATETIME,
    addr_address_end DATETIME,
    addr_address_postcode NVARCHAR(MAX),
    addr_address_json NVARCHAR(MAX)
);

-- Add foreign key constraint for la_person_id
ALTER TABLE Child_Social.ssd_address
ADD CONSTRAINT FK_address_person
FOREIGN KEY (addr_person_id) REFERENCES Child_Social.ssd_person(pers_person_id);


-- Non-clustered index on foreign key
CREATE INDEX IDX_address_person ON Child_Social.ssd_address(addr_person_id);

-- Non-clustered indexes on address_start and address_end
CREATE INDEX IDX_address_start ON Child_Social.ssd_address(addr_address_start);

CREATE INDEX IDX_address_end ON Child_Social.ssd_address(addr_address_end);


-- insert data
INSERT INTO Child_Social.ssd_address (
    addr_address_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start, 
    addr_address_end, 
    addr_address_postcode, 
    addr_address_json
)
SELECT 
    pa.[DIM_PERSON_ADDRESS_ID],
    pa.[EXTERNAL_ID], -- Assuming EXTERNAL_ID corresponds to la_person_id
    pa.[ADDSS_TYPE_CODE],
    pa.[START_DTTM],
    pa.[END_DTTM],
    pa.[POSTCODE],
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
    )
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa
ORDER BY
    pa.[EXTERNAL_ID] ASC;




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
- FACT_DISABILITY
=============================================================================
*/
-- Check if disability exists
IF OBJECT_ID('Child_Social.ssd_disability') IS NOT NULL DROP TABLE Child_Social.ssd_s47_disability;


-- Create structure
CREATE TABLE Child_Social.ssd_disability (
    disability_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    person_disability NVARCHAR(MAX)
);

-- Add foreign key constraint for la_person_id
ALTER TABLE Child_Social.ssd_disability
ADD CONSTRAINT FK_disability_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);

-- Non-clustered index on foreign key
CREATE INDEX IDX_disability_la_person_id 
ON Child_Social.ssd_disability(la_person_id);

-- insert data
INSERT INTO Child_Social.ssd_disability (
    disability_id, 
    la_person_id, 
    person_disability
)
SELECT 
    fd.[FACT_DISABILITY_ID],
    fd.[EXTERNAL_ID],
    fd.[DISABILITY_GROUP_CODE]
FROM 
    Child_Social.FACT_DISABILITY AS fd
ORDER BY
    fd.[EXTERNAL_ID] ASC;






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
- FACT_IMMIGRATION_STATUS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_immigration_status') IS NOT NULL DROP TABLE Child_Social.ssd_immigration_status;


-- Create structure
CREATE TABLE Child_Social.ssd_immigration_status (
    immigration_status_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    immigration_status_start DATETIME,
    immigration_status_end DATETIME,
    immigration_status NVARCHAR(MAX)
);

-- Add foreign key constraint for la_person_id
ALTER TABLE Child_Social.ssd_immigration_status
ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

-- Non-clustered index on foreign key
CREATE INDEX IDX_immigration_status_la_person_id 
ON Child_Social.ssd_immigration_status(la_person_id);

-- Non-clustered indexes on immigration_status_start and immigration_status_end
CREATE INDEX IDX_immigration_status_start 
ON Child_Social.ssd_immigration_status(immigration_status_start);

CREATE INDEX IDX_immigration_status_end 
ON Child_Social.ssd_immigration_status(immigration_status_end);

-- insert data
INSERT INTO Child_Social.ssd_immigration_status (
    immigration_status_id, 
    la_person_id, 
    immigration_status_start,
    immigration_status_end,
    immigration_status
)
SELECT 
    ims.[FACT_IMMIGRATION_STATUS_ID],
    ims.[EXTERNAL_ID],
    ims.[START_DTTM],
    ims.[END_DTTM],
    ims.[DIM_LOOKUP_IMMGR_STATUS_CODE]
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
ORDER BY
    ims.[EXTERNAL_ID] ASC;



/* 
=============================================================================
Object Name: ssd_mother
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
IF OBJECT_ID('Child_Social.ssd_mother') IS NOT NULL DROP TABLE Child_Social.ssd_mother;


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
- FACT_LEGAL_STATUS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_legal_status') IS NOT NULL DROP TABLE Child_Social.ssd_legal_status;


-- Create structure
CREATE TABLE Child_Social.ssd_legal_status (
    legal_status_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    legal_status_start DATETIME,
    legal_status_end DATETIME,
    person_dim_id NVARCHAR(255)
);

-- Insert data 
INSERT INTO Child_Social.ssd_legal_status (
    legal_status_id,
    la_person_id,
    legal_status_start,
    legal_status_end,
    person_dim_id
)
SELECT
    fls.[FACT_LEGAL_STATUS_ID],
    fls.[EXTERNAL_ID],
    fls.[START_DTTM],
    fls.[END_DTTM],
    fls.[DIM_PERSON_ID]
FROM 
    Child_Social.FACT_LEGAL_STATUS AS fls;

-- Add foreign key constraint linking la_person_id in legal_status to la_person_id in person
ALTER TABLE Child_Social.ssd_legal_status
ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);



/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_CONTACTS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_contact') IS NOT NULL DROP TABLE Child_Social.ssd_contact;

-- Create structure
CREATE TABLE Child_Social.ssd_contact (
    contact_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    contact_start DATETIME,
    contact_source NVARCHAR(MAX),
    contact_outcome NVARCHAR(MAX)
);


-- Insert data
INSERT INTO Child_Social.ssd_contact (
    contact_id, 
    la_person_id, 
    contact_start,
    contact_source,
    contact_outcome
)
SELECT 
    fc.[FACT_CONTACT_ID],
    fc.[EXTERNAL_ID],
    fc.[START_DTTM],
    fc.[SOURCE_CONTACT],
    fc.[CONTACT_OUTCOMES]
FROM 
    Child_Social.FACT_CONTACTS AS fc
ORDER BY
    fc.[EXTERNAL_ID] ASC;

-- Add foreign key constraint(s)
ALTER TABLE Child_Social.ssd_contact ADD CONSTRAINT FK_contact_person FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_contact_person ON Child_Social.ssd_contact(la_person_id);


/* 
=============================================================================
Object Name: ssd_early_help_episodes
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
IF OBJECT_ID('Child_Social.ssd_early_help_episodes') IS NOT NULL DROP TABLE Child_Social.ssd_early_help_episodes;

-- Create structure
CREATE TABLE Child_Social.ssd_early_help_episodes (
    earl_episode_id NVARCHAR(48) PRIMARY KEY,
    earl_person_id NVARCHAR(36),
    earl_episode_start_date DATETIME,
    earl_episode_end_date DATETIME,
    earl_episode_reason NVARCHAR(255),
    earl_episode_end_reason NVARCHAR(255),
    earl_episode_organisation NVARCHAR(255),
    earl_episode_worker_id NVARCHAR(48)
);

-- Insert data 
INSERT INTO Child_Social.ssd_early_help_episodes (
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
    cafe.FACT_CAF_EPISODE_ID,
    cafe.DIM_PERSON_ID,
    cafe.EPISODE_START_DTTM,
    cafe.EPISODE_END_DTTM,
    cafe.START_REASON,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE,
    'placeholder data' -- placeholder value
FROM 
    Child_Social.FACT_CAF_EPISODE AS cafe;





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
- @ssd_timeframe_years
- FACT_REFERRALS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_cin_episodes') IS NOT NULL DROP TABLE Child_Social.ssd_cin_episodes;

-- Create structure
CREATE TABLE Child_Social.ssd_cin_episodes
(
    cine_referral_id INT,
    cine_person_id NVARCHAR(48),
    cine_referral_date DATETIME,
    cine_cin_primary_need INT,
    cine_referral_source NVARCHAR(255),
    cine_referral_outcome_json NVARCHAR(255),
    cine_referral_nfa NCHAR(1),
    cine_close_reason NVARCHAR(255),
    cine_close_date DATETIME,
    cine_referral_team NVARCHAR(255),
    cine_referral_worker_id NVARCHAR(36)
);

-- Insert data 
INSERT INTO Child_Social.ssd_cin_episodes
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
    Child_Social.FACT_REFERRALS AS fr;

WHERE 
    fr.EFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE());

-- foreign key constraint(s)
ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);




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
IF OBJECT_ID('ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_cin_assessments;

-- Create structure
CREATE TABLE ssd_cin_assessments
(
    cina_assessment_id NVARCHAR(36) PRIMARY KEY,
    cina_person_id NVARCHAR(36),
    cina_referral_id NVARCHAR(36),
    cina_assessment_start_date DATETIME,
    cina_assessment_child_seen NCHAR(1),
    cina_assessment_auth_date DATETIME, -- This needs checking !! 
    cina_assessment_outcome_json NVARCHAR(255),
    cina_assessment_outcome_nfa NCHAR(1),
    cina_assessment_team NVARCHAR(255),
    cina_assessment_worker_id NVARCHAR(36)
);

-- Insert data
INSERT INTO ssd_cin_assessments
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

-- foreign key constraint(s)
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_social_worker FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_social_worker(socw_social_worker_id);




/* 
=============================================================================
Object Name: ssd_assessment_factors
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
IF OBJECT_ID('Child_Social.ssd_assessment_factors') IS NOT NULL DROP TABLE Child_Social.ssd_assessment_factors;


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
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_cin_plans') IS NOT NULL DROP TABLE Child_Social.ssd_cin_plans;

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
IF OBJECT_ID('ssd_cin_visits') IS NOT NULL DROP TABLE ssd_cin_visits;

-- Create structure
CREATE TABLE ssd_cin_visits
(
    cinv_cin_casenote_id NVARCHAR(36) PRIMARY KEY, -- This needs checking!!
    cinv_cin_visit_id NVARCHAR(36), -- This needs checking!!
    cinv_cin_plan_id NVARCHAR(36),
    cinv_cin_visit_date DATETIME,
    cinv_cin_visit_seen NCHAR(1),
    cinv_cin_visit_seen_alone NCHAR(1),
    cinv_cin_visit_bedroom NCHAR(1)
);

-- Insert data
INSERT INTO ssd_cin_visits
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

ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_cin_plans 
FOREIGN KEY (cinv_cin_plan_id) REFERENCES ssd_cin_plans(cinp_cin_plan_id);




/* 
=============================================================================
Object Name: ssd_s47
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_s47_enquiry_icpc') IS NOT NULL DROP TABLE Child_Social.ssd_s47_enquiry_icpc;


--Create structure 
CREATE TABLE Child_Social.ssd_s47_enquiry_icpc (
    s47_enquiry_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    s47_start_date DATETIME,
    s47_authorised_date DATETIME,
    s47_outcome NVARCHAR(MAX),
    icpc_transfer_in NVARCHAR(MAX),
    icpc_date DATETIME,
    icpc_outcome NVARCHAR(MAX),
    icpc_team NVARCHAR(MAX),
    icpc_worker_id NVARCHAR(MAX)
);

-- Add foreign key constraint for la_person_id
ALTER TABLE Child_Social.ssd_s47_enquiry_icpc
ADD CONSTRAINT FK_s47_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);

-- insert data
INSERT INTO Child_Social.ssd_s47_enquiry_icpc (
    s47_enquiry_id,
    la_person_id,
    s47_start_date,
    s47_authorised_date,
    s47_outcome,
    icpc_transfer_in,
    icpc_date,
    icpc_outcome,
    icpc_team,
    icpc_worker_id
)
SELECT 
    s47.[FACT_S47_ID],
    s47.[EXTERNAL_ID],
    s47.[START_DTTM],
    s47.[START_DTTM],
    CASE 
        WHEN cpc.[FACT_S47_ID] IS NOT NULL THEN 'CP Plan Started'
        ELSE 'CP Plan not Required'
    END,
    cpc.[TRANSFER_IN_FLAG],
    cpc.[MEETING_DTTM],
    s47.[OUTCOME_CP_FLAG],
    s47.[COMPLETED_BY_DEPT_ID],
    s47.[COMPLETED_BY_USER_STAFF_ID]
FROM 
    Child_Social.FACT_S47 AS s47
LEFT JOIN 
    Child_Social.FACT_CP_CONFERENCE as cpc ON s47.[FACT_S47_ID] = cpc.[FACT_S47_ID];



/* 
=============================================================================
Object Name: ssd_cp_plans
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

-- Check if table exists, & drop if it does
IF OBJECT_ID('ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_cp_reviews;

-- Create structure for ssd_cp_reviews table
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id NVARCHAR(36) PRIMARY KEY,
    cppr_cp_plan_id NVARCHAR(36),
    cppr_cp_review_due DATETIME NULL,
    cppr_cp_review_date DATETIME NULL,
    cppr_cp_review_outcome NCHAR(1),
    cppr_cp_review_quorate NCHAR(1) DEFAULT '0', -- using '0' as placeholder
    cppr_cp_review_participation NCHAR(1) DEFAULT '0' -- using '0' as placeholder
);

-- Insert data from source table
INSERT INTO ssd_cp_reviews
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
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: This has issues, where/what is the fk back to cp_plans? 
Dependencies: 
- FACT_CASENOTES
=============================================================================
*/
-- Check if the table exists, and drop if it does
IF OBJECT_ID('Child_Social.ssd_cp_visits') IS NOT NULL DROP TABLE Child_Social.ssd_cp_visits;

-- Create the permanent table with suitable data types
CREATE TABLE Child_Social.ssd_cp_visits (
    cppv_casenote_id INT PRIMARY KEY, -- Assuming FACT_CASENOTE_ID is of INT data type
    cppv_cp_visit_id INT, -- Assuming the appropriate data type for Child_Social.FACT_CASENOTES
    cppv_cp_visit_date DATETIME, -- Assuming EVENT_DTTM is of DATETIME data type
    cppv_cp_visit_seen BIT, -- Assuming SEEN_FLAG is a BIT (true/false) data type
    cppv_cp_visit_seen_alone BIT, -- Assuming SEEN_ALONE_FLAG is a BIT data type
    cppv_cp_visit_bedroom BIT -- Assuming SEEN_BEDROOM_FLAG is a BIT data type
);

-- Populate the table
INSERT INTO Child_Social.ssd_cp_visits
SELECT 
    cn.FACT_CASENOTE_ID,
    cn.Child_Social.FACT_CASENOTES,
    cn.EVENT_DTTM,
    cn.SEEN_FLAG,
    cn.SEEN_ALONE_FLAG,
    cn.SEEN_BEDROOM_FLAG 
FROM 
    Child_Social.FACT_CASENOTES AS cn;




/* 
=============================================================================
Object Name: ssd_cp_reviews
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

-- Check if table exists, & drop
IF OBJECT_ID('ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_cp_reviews;

-- Create structure
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id NVARCHAR(36) PRIMARY KEY,
    cppr_cp_plan_id NVARCHAR(36),
    cppr_cp_review_due DATETIME NULL,
    cppr_cp_review_date DATETIME NULL,
    cppr_cp_review_outcome NCHAR(1),
    cppr_cp_review_quorate NCHAR(1) DEFAULT '0', -- using '0' as placeholder
    cppr_cp_review_participation NCHAR(1) DEFAULT '0' -- using '0' as placeholder
);

-- Insert data
INSERT INTO ssd_cp_reviews
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


ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


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
IF OBJECT_ID('Child_Social.ssd_cp_visits') IS NOT NULL DROP TABLE Child_Social.ssd_cp_visits;

BEGIN
    -- Create structure
    CREATE TABLE Child_Social.ssd_cla_Substance_misuse (
        substance_misuse_id NVARCHAR(255) PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        create_date DATETIME,
        person_dim_id NVARCHAR(255),
        start_date DATETIME,
        end_date DATETIME,
        substance_type_id NVARCHAR(255),
        substance_type_code NVARCHAR(MAX)
    );

    -- insert data
    INSERT INTO Child_Social.ssd_cla_Substance_misuse (
        substance_misuse_id,
        la_person_id,
        create_date,
        person_dim_id,
        start_date,
        end_date,
        substance_type_id,
        substance_type_code
    )
    SELECT 
        fsm.[FACT_SUBSTANCE_MISUSE_ID] as substance_misuse_id,
        fsm.[EXTERNAL_ID] as la_person_id,
        -- fsm.[DIM_PERSON_ID] as la_person_id, -- which is it
        FORMAT(fsm.[START_DTTM], 'dd/MM/yyyy') as substance_misuse_date,
        fsm.[DIM_LOOKUP_SUBSTANCE_TYPE_CODE] as substance_misused,
        fsm.[ACCEPT_FLAG] as intervention_received -- needs confirming
    FROM 
        Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;

    -- Add foreign key constraint for la_person_id
    ALTER Child_Social.ssd_cla_substance_misuse
    ADD CONSTRAINT FK_substance_misuse_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);
END;



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

-- Create structure 



-- insert data
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
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- TABLE_SCHEMA	TABLE_NAME	COLUMN_NAME
-- Child_Social	FACT_CLA	NO_OF_TIMES_MISSING
-- Child_Social	FACT_CONTACTS	OUTCOME_MISSING_FLAG
-- Child_Social	FACT_MISSING_PERSON	FACT_MISSING_PERSON_ID
-- Child_Social	FACT_MISSING_PERSON	DIM_LOOKUP_ICS_MISSING_END_REASON_ID
-- Child_Social	FACT_MISSING_PERSON	DURATION_OF_TIME_MISSING
-- Child_Social	FACT_MISSING_PERSON	LOCATION_MISSING_FROM
-- Child_Social	FACT_MISSING_PERSON	MISSING_STATUS
-- Child_Social	FACT_MISSING_PERSON	TIME_MISSING
-- Child_Social	FACT_MISSING_PERSON	TOTAL_TIME_MISSING
-- Child_Social	FACT_MISSING_PERSON	DIM_LOOKUP_ICS_MISSING_END_REASON_CODE
-- Child_Social	FACT_MISSING_PERSON	DIM_LOOKUP_ICS_MISSING_END_REASON_DESC
-- Child_Social	FACT_MISSING_PERSON_LINK	FACT_MISSING_PERSON_ID
-- Child_Social	FACT_MISSING_PERSON_LINK	FACT_MISSING_PERSON_LINK_ID
-- Child_Social	FACT_MISSING_REASONS_MARCH31	FACT_MISSING_REASONS_MARCH31_ID
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID_1
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID_2
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID_3
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID_4
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_ID_5
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_STATUS_CODE
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE_1
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE_2
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE_3
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE_4
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_REASON_CODE_5
-- Child_Social	FACT_MISSING_STATUS	MISSING_STATUS
-- Child_Social	FACT_MISSING_STATUS	DIM_LOOKUP_MISSING_STATUS_ID
-- Child_Social	FACT_MISSING_STATUS	FACT_MISSING_PERSON_ID
-- Child_Social	FACT_MISSING_STATUS	FACT_MISSING_STATUS_ID
-- Child_Social	FACT_PLACEMATCH_PLACEMENT	MISSING
-- Education	FACT_TASK	FACT_CHILD_MISSING_EDUCATION_ID
-- Singleview	FACT_TF_INDIVIDUAL_PROGRESS	MISSING_FROM_EDUCATION_MONTHS
-- Education	FACT_WEEKLY_ATTENDANCE_SNAPSHOT	TOTAL_MISSING_MARKS



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
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'ssd_send')
BEGIN
    DROP TABLE Child_Social.ssd_send;
END

-- Create structure 
CREATE TABLE Child_Social.ssd_send (
    send_table_id NVARCHAR(255),
    la_person_id NVARCHAR(255),
    send_upn NVARCHAR(255),
    upn_unknown NVARCHAR(MAX),
    send_uln NVARCHAR(MAX)
);

-- insert data
INSERT INTO Child_Social.ssd_send (
    send_table_id,
    la_person_id, 
    send_upn,
    upn_unknown,
    send_uln
)
SELECT 
    f.FACT_903_DATA_ID as send_table_id,
    f.EXTERNAL_ID as la_person_id, 
    f.FACT_903_DATA_ID as send_upn,
    f.NO_UPN_CODE as upn_unknown,
    p.ULN as send_uln
FROM 
    Child_Social.FACT_903_DATA AS f
LEFT JOIN 
    Education.DIM_PERSON AS p ON f.DIM_PERSON_ID = p.DIM_PERSON_ID;


/* ?? Should this actually be pulling from Child_Social.FACT_SENRECORD.DIM_PERSON_ID | Child_Social.FACT_SEN.DIM_PERSON_ID
*/


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
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists, & drop
IF OBJECT_ID('Child_Social.ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE Child_Social.ssd_pre_proceedings;

-- Create structure
CREATE TABLE Child_Social.ssd_pre_proceedings (
    prep_id INT PRIMARY KEY IDENTITY(1,1),
    prep_person_id NVARCHAR(36),
    prep_plo_family_id NVARCHAR(36),
    prep_pre_pro_decision_date DATETIME,
    prep_initial_pre_pro_meeting_date DATETIME,
    prep_pre_pro_outcome NVARCHAR(255),
    prep_agree_stepdown_issue_date DATETIME,
    prep_cp_plans_referral_period INT,
    prep_legal_gateway_outcome NVARCHAR(255),
    prep_prev_pre_proc_child INT,
    prep_prev_care_proc_child INT,
    prep_pre_pro_letter_date DATETIME,
    prep_care_pro_letter_date DATETIME,
    prep_pre_pro_meetings_num INT,
    prep_pre_pro_parents_legal_rep NCHAR(1),
    prep_parents_legal_rep_point_of_issue NCHAR(2),
    prep_court_reference NVARCHAR(36),
    prep_care_proc_court_hearings INT,
    prep_care_proc_short_notice NCHAR(1),
    prep_proc_short_notice_reason NVARCHAR(255),
    prep_la_inital_plan_approved NCHAR(1),
    prep_la_initial_care_plan NVARCHAR(255),
    prep_la_final_plan_approved NCHAR(1),
    prep_la_final_care_plan NVARCHAR(255)
);

-- Insert placeholder data
-- Insert placeholder data
INSERT INTO Child_Social.ssd_pre_proceedings (
    prep_person_id,
    prep_plo_family_id,
    prep_pre_pro_decision_date,
    prep_initial_pre_pro_meeting_date,
    prep_pre_pro_outcome,
    prep_agree_stepdown_issue_date,
    prep_cp_plans_referral_period,
    prep_legal_gateway_outcome,
    prep_prev_pre_proc_child,
    prep_prev_care_proc_child,
    prep_pre_pro_letter_date,
    prep_care_pro_letter_date,
    prep_pre_pro_meetings_num,
    prep_pre_pro_parents_legal_rep,
    prep_parents_legal_rep_point_of_issue,
    prep_court_reference,
    prep_care_proc_court_hearings,
    prep_care_proc_short_notice,
    prep_proc_short_notice_reason,
    prep_la_inital_plan_approved,
    prep_la_initial_care_plan,
    prep_la_final_plan_approved,
    prep_la_final_care_plan
)
VALUES
    (
    'DIM_PERSON1.PERSON_ID', 'PLO_FAMILY1', '2023-01-01', '2023-01-02', 'Outcome1', 
    '2023-01-03', 3, 'Approved', 2, 1, '2023-01-04', '2023-01-05', 2, 'Y', 
    'NA', 'COURT_REF_1', 1, 'N', 'Reason1', 'Y', 'Initial Plan 1', 'Y', 'Final Plan 1'
    ),
    (
    'DIM_PERSON2.PERSON_ID', 'PLO_FAMILY2', '2023-02-01', '2023-02-02', 'Outcome2',
    '2023-02-03', 4, 'Denied', 1, 2, '2023-02-04', '2023-02-05', 3, 'N',
    'IS', 'COURT_REF_2', 2, 'Y', 'Reason2', 'N', 'Initial Plan 2', 'N', 'Final Plan 2'
    );

-- Add foreign key constraint
ALTER TABLE Child_Social.ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);



/* 
=============================================================================
Object Name: ssd_voice_of_child
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('Child_Social.ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE Child_Social.ssd_voice_of_child;

-- Create structure
CREATE TABLE Child_Social.ssd_voice_of_child (
    voch_person_id NVARCHAR(48) PRIMARY KEY, 
    voch_explained_worries NCHAR(1),
    voch_story_help_understand NCHAR(1),
    voch_agree_worker NCHAR(1),
    voch_plan_safe NCHAR(1),
    voch_tablet_help_explain NCHAR(1)
);

-- Insert placeholder data
INSERT INTO Child_Social.ssd_voice_of_child (
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



ALTER TABLE Child_Social.ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);




/* 
=============================================================================
Object Name: ssd_linked_identifiers
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists, & drop 
IF OBJECT_ID('Child_Social.ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE Child_Social.ssd_linked_identifiers;

-- Create structure
CREATE TABLE Child_Social.ssd_linked_identifiers (
    link_link_id NVARCHAR(36) PRIMARY KEY, 
    link_person_id NVARCHAR(36), 
    link_identifier_type NVARCHAR(255),
    link_identifier_value NVARCHAR(255),
    link_valid_from_date DATETIME,
    link_valid_to_date DATETIME
);

-- Insert placeholder data
INSERT INTO Child_Social.ssd_linked_identifiers (
    link_link_id,
    link_person_id,
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date,
    link_valid_to_date
)
VALUES
    ('placeholder data', 'DIM_PERSON.PERSON_ID', 'placeholder data', 'placeholder data', NULL, NULL);

-- Add foreign key constraint
ALTER TABLE Child_Social.ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);





/* 
=============================================================================
Object Name: ssd_s251_finance
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists, & drop 
IF OBJECT_ID('Child_Social.ssd_s251_finance', 'U') IS NOT NULL DROP TABLE Child_Social.ssd_s251_finance;

-- Create structure
CREATE TABLE Child_Social.ssd_s251_finance (
    s251_id NVARCHAR(36) PRIMARY KEY, 
    s251_cla_placement_id NVARCHAR(36), 
    s251_placeholder_1 NVARCHAR(48),
    s251_placeholder_2 NVARCHAR(48),
    s251_placeholder_3 NVARCHAR(48),
    s251_placeholder_4 NVARCHAR(48)
);

-- Insert placeholder data
INSERT INTO Child_Social.ssd_s251_finance (
    s251_id,
    s251_cla_placement_id,
    s251_placeholder_1,
    s251_placeholder_2,
    s251_placeholder_3,
    s251_placeholder_4
)
VALUES
    ('placeholder data', 'placeholder data', 'placeholder data', 'placeholder data', 'placeholder data', 'placeholder data');

-- Add foreign key constraint
ALTER TABLE Child_Social.ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);









/* ********************************************************************************************************** */
/* Development clean up */

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* cleanup */
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;


/* ********************************************************************************************************** */

