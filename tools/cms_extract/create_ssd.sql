
/* DEV Notes:
- Although returns expect dd/mm/YYYY formating on dates. Extract maintains DATETIME not DATE, nor formatted nvarchar string to avoid conversion issues.
- Full review needed of max/exagerated/default new field type sizes e.g. family_id NVARCHAR(255)  (keys cannot use MAX)
*/



/* ********************************************************************************************************** */
/* Development set up */

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
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
    )
    OR EXISTS (
        -- contact in last x@yrs
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
    )
    OR EXISTS (
        -- ehcp request in last x@yrs
        SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
        WHERE fe.[EXTERNAL_ID] = p.[EXTERNAL_ID] 
        AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE())
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

-- Add foreign key constraint for la_person_id
ALTER TABLE Child_Social.ssd_contact
ADD CONSTRAINT FK_contact_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_contact_person ON Child_Social.ssd_contact(la_person_id);

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
- @YearsBack
- FACT_REFERRALS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_cin_episodes') IS NOT NULL DROP TABLE Child_Social.ssd_cin_episodes;


-- create structure
CREATE TABLE ssd_cin_episodes (
    cin_referral_id NVARCHAR(255) PRIMARY KEY,
    la_person_id NVARCHAR(255),
    cin_ref_date DATETIME,
    cin_primary_need NVARCHAR(255),
    cin_ref_source NVARCHAR(255),
    cin_ref_outcome NVARCHAR(255),
    cin_close_reason NVARCHAR(255),
    cin_close_date DATETIME,
    cin_ref_team NVARCHAR(255),
    cin_ref_worker_id NVARCHAR(255)
);

-- Insert data 
INSERT INTO ssd_cin_episodes (
    cin_referral_id,
    la_person_id,
    cin_ref_date,
    cin_primary_need,
    cin_ref_source,
    cin_ref_outcome,
    cin_close_reason,
    cin_close_date,
    cin_ref_team,
    cin_ref_worker_id
)
SELECT
    fr.FACT_REFERRAL_ID,
    fr.EXTERNAL_ID,
    fr.EFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_ID,
    fr.DIM_LOOKUP_CONT_SORC_ID_DESC,
    --fr.cin_ref_outcome, -- Need the appropriate field
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
    fr.REFRL_END_DTTM,
    fr.DIM_DEPARTMENT_ID,
    fr.DIM_WORKER_ID
FROM
    Child_Social.FACT_REFERRALS AS fr
WHERE 
    fr.EFRL_START_DTTM >= DATEADD(YEAR, -@YearsBack, GETDATE());

ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person FOREIGN KEY (la_person_id) REFERENCES person(la_person_id);



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
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_assessments') IS NOT NULL DROP TABLE Child_Social.ssd_assessments;

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
-- Check if exists & drop
IF OBJECT_ID('Child_Social.ssd_cin_visits') IS NOT NULL DROP TABLE Child_Social.ssd_cin_visits;


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
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists, & drop 
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'ssd_voice_of_child')
BEGIN
    DROP TABLE Child_Social.ssd_voice_of_child;
END

-- Create structure
CREATE TABLE Child_Social.ssd_voice_of_child (
    la_person_id NVARCHAR(255) PRIMARY KEY, -- Assuming NVARCHAR(255) as a generic type for id
    voc_explained_worries NVARCHAR(255),
    voc_story_help_understand NVARCHAR(255),
    voc_agree_worker NVARCHAR(255),
    voc_plan_safe NVARCHAR(255),
    voc_tablet_help_explain NVARCHAR(255)
);

-- Insert placeholder data
INSERT INTO Child_Social.ssd_voice_of_child (
    la_person_id,
    voc_explained_worries,
    voc_story_help_understand,
    voc_agree_worker,
    voc_plan_safe,
    voc_tablet_help_explain
)
VALUES
    ('ID001', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data'),
    ('ID002', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data', 'Placeholder Data');

    





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

