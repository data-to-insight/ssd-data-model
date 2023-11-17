
/* DEV Notes:
- Although returns expect dd/mm/YYYY formating on dates. Extract maintains DATETIME not DATE, nor formatted nvarchar string to avoid conversion issues.
- Full review needed of max/exagerated/default new field type sizes e.g. family_id NVARCHAR(48)  (keys cannot use MAX)
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
IF OBJECT_ID('ssd_person') IS NOT NULL DROP TABLE ssd_person;

-- Create structure
CREATE TABLE ssd_person (
    pers_la_person_id NVARCHAR(48) PRIMARY KEY, 
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
    p.EXTERNAL_ID,
    p.DIM_LOOKUP_VARIATION_OF_SEX_CODE,
    p.ETHNICITY_MAIN_CODE,
    p.BIRTH_DTTM,
    NULL AS pers_common_child_id, -- Set to NULL during dev / set to NHS#?
    p.UPN,

    (SELECT TOP 1 f.NO_UPN_CODE              -- Subquery to fetch ANY/MOST RECENT? NO_UPN_CODE.
    FROM Child_Social.FACT_903_DATA f        -- This *unlikely* to be the best source
    WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
    AND f.NO_UPN_CODE IS NOT NULL
    ORDER BY f.NO_UPN_CODE DESC) AS pers_upn_unknown,  -- desc order to ensure a non-null value first

    p.EHM_SEN_FLAG,
    p.DOB_ESTIMATED,
    p.DEATH_DTTM,
    p.NATNL_CODE

FROM 
    Child_Social.DIM_PERSON AS p
WHERE 
    p.EXTERNAL_ID IS NOT NULL
AND (
    EXISTS (
        -- has open referral
        SELECT 1 FROM Child_Social.FACT_REFERRALS fr 
        WHERE fr.EXTERNAL_ID = p.EXTERNAL_ID 
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- contact in last x@yrs
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.EXTERNAL_ID = p.EXTERNAL_ID 
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- ehcp request in last x@yrs
        SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
        WHERE fe.EXTERNAL_ID = p.EXTERNAL_ID 
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
    p.EXTERNAL_ID ASC;

-- Create index(es)
CREATE INDEX IDX_ssd_person_la_person_id ON ssd_person(pers_la_person_id);

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
IF OBJECT_ID('ssd_family') IS NOT NULL DROP TABLE ssd_family;


-- Create structure
CREATE TABLE ssd_family (
    fami_DIM_TF_FAMILY_ID   NVARCHAR(48) PRIMARY KEY, 
    fami_family_id          NVARCHAR(48),
    fami_la_person_id       NVARCHAR(48),
    
    -- Define foreign key constraint
    FOREIGN KEY (fami_la_person_id) REFERENCES person(pers_la_person_id)
);

-- Insert data 
INSERT INTO ssd_family (
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

-- Create index(es)
CREATE INDEX IDX_family_person ON ssd_family(fami_la_person_id);




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
IF OBJECT_ID('ssd_address') IS NOT NULL DROP TABLE ssd_address;


-- Create structure
CREATE TABLE ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,
    addr_person_id          NVARCHAR(48), 
    addr_address_type       NVARCHAR(48),
    addr_address_start      DATETIME,
    addr_address_end        DATETIME,
    addr_address_postcode   NVARCHAR(8),
    addr_address_json       NVARCHAR(500)
);



-- Create constraint(s)
ALTER TABLE ssd_address ADD CONSTRAINT FK_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE INDEX IDX_address_person ON ssd_address(addr_person_id);
CREATE INDEX IDX_address_start ON ssd_address(addr_address_start);
CREATE INDEX IDX_address_end ON ssd_address(addr_address_end);


-- insert data
INSERT INTO ssd_address (
    addr_table_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start, 
    addr_address_end, 
    addr_address_postcode, 
    addr_address_json
)
SELECT 
    pa.DIM_PERSON_ADDRESS_ID,
    pa.EXTERNAL_ID, -- Assuming EXTERNAL_ID corresponds to pers_person_id
    pa.ADDSS_TYPE_CODE,
    pa.START_DTTM,
    pa.END_DTTM,
    REPLACE(pa.POSTCODE, ' ', ''), -- whitespace removed to enforce data quality
    -- Create JSON string for the address
    (
        SELECT 
            NULLIF(pa.ROOM_NO, '')    AS ROOM, 
            NULLIF(pa.FLOOR_NO, '')   AS FLOOR, 
            NULLIF(pa.FLAT_NO, '')    AS FLAT, 
            NULLIF(pa.BUILDING, '')   AS BUILDING, 
            NULLIF(pa.HOUSE_NO, '')   AS HOUSE, 
            NULLIF(pa.STREET, '')     AS STREET, 
            NULLIF(pa.TOWN, '')       AS TOWN,
            NULLIF(pa.UPRN, '')       AS UPRN,
            NULLIF(pa.EASTING, '')    AS EASTING,
            NULLIF(pa.NORTHING, '')   AS NORTHING
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa

ORDER BY
    pa.EXTERNAL_ID ASC;




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
- ssd_person
- FACT_DISABILITY
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_disability') IS NOT NULL DROP TABLE ssd_disability;

-- Create the structure
CREATE TABLE ssd_disability
(
    disa_table_id                 NVARCHAR(48) PRIMARY KEY,
    disa_person_id          NVARCHAR(48) NOT NULL,
    disa_disability_code    NVARCHAR(48) NOT NULL
);

-- Create constraint(s)
ALTER TABLE ssd_disability ADD CONSTRAINT FK_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_disability_person_id ON ssd_disability(disa_person_id);


-- Insert data
INSERT INTO ssd_disability (
    disa_table_id,  -- Naming and inclusion to check/confirm 
    disa_person_id, 
    disa_disability_code
)
SELECT 
    fd.FACT_DISABILITY_ID, 
    fd.EXTERNAL_ID, 
    fd.DIM_LOOKUP_DISAB_CODE
FROM 
    Child_Social.FACT_DISABILITY AS fd;








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
-- Check if exists & drop
IF OBJECT_ID('ssd_immigration_status') IS NOT NULL DROP TABLE ssd_immigration_status;


-- Create structure
CREATE TABLE ssd_immigration_status (
    immi_immigration_status_id NVARCHAR(48) PRIMARY KEY,
    immi_person_id NVARCHAR(48),
    immi_mmigration_status_start DATETIME,
    immi_immigration_status_end DATETIME,
    immi_immigration_status NVARCHAR(48)
);

-- Create constraint(s)
ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_immigration_status_la_person_id 
ON ssd_immigration_status(immi_person_id);

CREATE INDEX IDX_immigration_status_start 
ON ssd_immigration_status(immi_immigration_status_start);

CREATE INDEX IDX_immigration_status_end 
ON ssd_immigration_status(immi_immigration_status_end);


-- insert data
INSERT INTO ssd_immigration_status (
    immi_immigration_status_id, 
    immi_person_id, 
    immi_immigration_status_start,
    immi_immigration_status_end,
    immi_immigration_status
)
SELECT 
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.EXTERNAL_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_CODE
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
ORDER BY
    ims.EXTERNAL_ID ASC;



/* 
=============================================================================
Object Name: ssd_mother
Description: 
Author: D2I
Last Modified Date: 15/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.2
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_PERSON_RELATION
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_mother;

-- Create structure
CREATE TABLE ssd_mother (
    moth_person_id              NVARCHAR(48) PRIMARY KEY,
    moth_childs_person_id       NVARCHAR(48),
    moth_childs_dob             DATETIME
);

-- Insert data
INSERT INTO ssd_mother (
    moth_person_id, 
    moth_childs_person_id, 
    moth_childs_dob
)
SELECT 
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
FROM 
    Child_Social.FACT_PERSON_RELATION AS fpr;


-- Add constraint(s)
ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);



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
-- Check if exists & drop
IF OBJECT_ID('ssd_legal_status') IS NOT NULL DROP TABLE ssd_legal_status;


-- Create structure
CREATE TABLE ssd_legal_status (
    lega_legal_status_id NVARCHAR(48) PRIMARY KEY,
    lega_person_id NVARCHAR(48),
    lega_legal_status_start DATETIME,
    lega_legal_status_end DATETIME

);

-- Insert data 
INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status_start,
    lega_legal_status_end

)
SELECT
    fls.FACT_LEGAL_STATUS_ID,
    fls.DIM_PERSON_ID,
    fls.START_DTTM,
    fls.END_DTTM
FROM 
    Child_Social.FACT_LEGAL_STATUS AS fls;

-- Create constraint(s)
ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id);



/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 06/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_contact') IS NOT NULL DROP TABLE ssd_contact;

-- Create structure
CREATE TABLE ssd_contact (
    cont_contact_id         NVARCHAR(48) PRIMARY KEY,
    cont_person_id          NVARCHAR(48),
    cont_contact_start      DATETIME,
    cont_contact_source     NVARCHAR(255), 
    cont_contact_outcome_json NVARCHAR(500) 
);

-- Insert data
INSERT INTO ssd_contact (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_start,
    cont_contact_source,
    cont_contact_outcome_json
)
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, -- Should this be DIM_PERSON_ID
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
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
    Child_Social.FACT_CONTACTS AS fc


-- Create constraint(s)
ALTER TABLE ssd_contact ADD CONSTRAINT FK_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_contact_person ON ssd_contact(cont_person_id);


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
IF OBJECT_ID('ssd_early_help_episodes') IS NOT NULL DROP TABLE ssd_early_help_episodes;

-- Create structure
CREATE TABLE ssd_early_help_episodes (
    earl_episode_id         NVARCHAR(48) PRIMARY KEY,
    earl_person_id          NVARCHAR(48),
    earl_episode_start_date DATETIME,
    earl_episode_end_date   DATETIME,
    earl_episode_reason     NVARCHAR(MAX),
    earl_episode_end_reason NVARCHAR(MAX),
    earl_episode_organisation NVARCHAR(MAX),
    earl_episode_worker_id  NVARCHAR(48)
);

-- Insert data 
INSERT INTO ssd_early_help_episodes (
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


-- Create constraint(s)
ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);



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
IF OBJECT_ID('ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_cin_episodes;

-- Create structure
CREATE TABLE ssd_cin_episodes
(
    cine_referral_id INT,
    cine_person_id NVARCHAR(48),
    cine_referral_date DATETIME,
    cine_cin_primary_need INT,
    cine_referral_source NVARCHAR(MAX),
    cine_referral_outcome_json NVARCHAR(500),
    cine_referral_nfa NCHAR(1), -- Possible case to use BIT type + CASE
    cine_close_reason NVARCHAR(MAX),
    cine_close_date DATETIME,
    cine_referral_team NVARCHAR(MAX),
    cine_referral_worker_id NVARCHAR(48)
);

-- Insert data 
INSERT INTO ssd_cin_episodes
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


-- Create constraint(s)
ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);




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
IF OBJECT_ID('ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_cin_assessments;

-- Create structure
CREATE TABLE ssd_cin_assessments
(
    cina_assessment_id NVARCHAR(48) PRIMARY KEY,
    cina_person_id NVARCHAR(48),
    cina_referral_id NVARCHAR(48),
    cina_assessment_start_date DATETIME,
    cina_assessment_child_seen NCHAR(1), -- Possible case to use BIT type + CASE
    cina_assessment_auth_date DATETIME, -- This needs checking !! 
    cina_assessment_outcome_json NVARCHAR(500),
    cina_assessment_outcome_nfa NCHAR(1), -- Possible case to use BIT type + CASE
    cina_assessment_team NVARCHAR(MAX),
    cina_assessment_worker_id NVARCHAR(48)
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


-- Create constraint(s)
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_social_worker 
FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_social_worker(socw_social_worker_id);




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
IF OBJECT_ID('ssd_assessment_factors') IS NOT NULL DROP TABLE ssd_assessment_factors;


/*
asmt_id
asmt_factors


-- Create index(es)
-- Create constraint(s)
*/




/* 
=============================================================================
Object Name: ssd_cin_plans
Description: 
Author: D2I
Last Modified Date: 06/11/12
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- 
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_cin_plans;

-- Create structure
CREATE TABLE ssd_cin_plans (
    cinp_referral_id NVARCHAR(48), 
    cinp_person_id NVARCHAR(48), 
    cinp_cin_plan_start DATETIME,
    cinp_cin_plan_end DATETIME,
    cinp_cin_plan_team NVARCHAR(MAX),
    cinp_cin_plan_worker_id NVARCHAR(48)
);

-- Insert data
INSERT INTO ssd_cin_plans (
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
ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id);



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
    cinv_cin_casenote_id NVARCHAR(48) PRIMARY KEY, -- This needs checking!!
    cinv_cin_visit_id NVARCHAR(48), -- This needs checking!!
    cinv_cin_plan_id NVARCHAR(48),
    cinv_cin_visit_date DATETIME,
    cinv_cin_visit_seen NCHAR(1), -- Possible case to use BIT type + CASE
    cinv_cin_visit_seen_alone NCHAR(1), -- Possible case to use BIT type + CASE
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


-- Create constraint(s)
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
IF OBJECT_ID('ssd_s47_enquiry_icpc') IS NOT NULL DROP TABLE ssd_s47_enquiry_icpc;


--Create structure 
CREATE TABLE ssd_s47_enquiry_icpc (
    s47_enquiry_id NVARCHAR(48) PRIMARY KEY,
    la_person_id NVARCHAR(48),
    s47_start_date DATETIME,
    s47_authorised_date DATETIME,
    s47_outcome NVARCHAR(MAX),
    icpc_transfer_in NVARCHAR(MAX),
    icpc_date DATETIME,
    icpc_outcome NVARCHAR(MAX),
    icpc_team NVARCHAR(MAX),
    icpc_worker_id NVARCHAR(48)
);



-- insert data
INSERT INTO ssd_s47_enquiry_icpc (
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
    s47.FACT_S47_ID,
    s47.EXTERNAL_ID,
    s47.START_DTTM,
    s47.START_DTTM,
    CASE 
        WHEN cpc.FACT_S47_ID IS NOT NULL THEN 'CP Plan Started'
        ELSE 'CP Plan not Required'
    END,
    cpc.TRANSFER_IN_FLAG,
    cpc.MEETING_DTTM,
    s47.OUTCOME_CP_FLAG,
    s47.COMPLETED_BY_DEPT_ID,
    s47.COMPLETED_BY_USER_STAFF_ID
FROM 
    Child_Social.FACT_S47 AS s47
LEFT JOIN 
    Child_Social.FACT_CP_CONFERENCE as cpc ON s47.FACT_S47_ID = cpc.FACT_S47_ID;

-- Create constraint(s)
ALTER TABLE ssd_s47_enquiry_icpc ADD CONSTRAINT FK_s47_person
FOREIGN KEY (la_person_id) REFERENCES ssd_person(la_person_id);




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

-- Check if exists & drop 
IF OBJECT_ID('ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_cp_reviews;

-- Create structure
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id NVARCHAR(48) PRIMARY KEY,
    cppr_cp_plan_id NVARCHAR(48),
    cppr_cp_review_due DATETIME NULL,
    cppr_cp_review_date DATETIME NULL,
    cppr_cp_review_outcome NCHAR(1), -- Possible case to use BIT type + CASE
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
    '0', -- 'PLACEHOLDER_DATA' for cppr_cp_review_quorate
    '0'  -- 'PLACEHOLDER_DATA' for cppr_cp_review_participation
FROM 
    Child_Social.FACT_CP_REVIEW;

-- Create index(es)
-- Create constraint(s)


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
-- Check if exists & drop
IF OBJECT_ID('ssd_cp_visits') IS NOT NULL DROP TABLE ssd_cp_visits;

-- Create structure
CREATE TABLE ssd_cp_visits (
    cppv_casenote_id        INT PRIMARY KEY, 
    cppv_cp_visit_id        INT, 
    cppv_cp_visit_date      DATETIME, 
    cppv_cp_visit_seen      NCHAR(1), 
    cppv_cp_visit_seen_alone NCHAR(1), 
    cppv_cp_visit_bedroom   NCHAR(1) 
);

-- Insert data
INSERT INTO ssd_cp_visits
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
    cppr_cp_review_id               NVARCHAR(48) PRIMARY KEY,
    cppr_cp_plan_id                 NVARCHAR(48),
    cppr_cp_review_due              DATETIME NULL,
    cppr_cp_review_date             DATETIME NULL,
    cppr_cp_review_outcome          NCHAR(1), 
    cppr_cp_review_quorate          NCHAR(1) DEFAULT '0',   --  'PLACEHOLDER_DATA'
    cppr_cp_review_participation    NCHAR(1) DEFAULT '0'    -- 'PLACEHOLDER_DATA'
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
    cpr.FACT_CP_REVIEW_ID,
    cpr.FACT_CP_PLAN_ID,
    cpr.DUE_DTTM,
    cpr.MEETING_DTTM,
    cpr.OUTCOME_CONTINUE_CP_FLAG,
    '0', -- 'PLACEHOLDER_DATA' for cppr_cp_review_quorate
    '0'  -- 'PLACEHOLDER_DATA' for cppr_cp_review_participation
FROM 
    Child_Social.FACT_CP_REVIEW as cpr
INNER JOIN 
    ssd_person AS p ON cpr.DIM_PERSON_ID = p.pers_person_id;

-- Create constraint(s)
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
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_involvements
- FACT_CARE_EPISODES
=============================================================================
*/

-- Create structure
CREATE TABLE ssd_cla_episodes (
    clae_cla_episode_id             NVARCHAR(48) PRIMARY KEY,
    clae_person_id                  NVARCHAR(48),
    clae_cla_episode_start          DATETIME,
    clae_cla_episode_start_reason   NVARCHAR(100),
    clae_cla_primary_need           NVARCHAR(100),
    clae_cla_episode_ceased         DATETIME,
    clae_cla_episode_cease_reason   NVARCHAR(100),
    clae_cla_team                   NVARCHAR(48),
    clae_cla_worker_id              NVARCHAR(48)
);

-- Insert data 
INSERT INTO ssd_cla_episodes (
    clae_cla_episode_id, 
    clae_person_id, 
    clae_cla_episode_start,
    clae_cla_episode_start_reason,
    clae_cla_primary_need,
    clae_cla_episode_ceased,
    clae_cla_episode_cease_reason,
    clae_cla_team,                      -- via .FACT_CLA->.FACT_REFERRAL
    clae_cla_worker_id                  -- via .FACT_CLA->.FACT_REFERRAL
)
SELECT 
    fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
    fce.DIM_PERSON_ID                       AS clae_person_id,
    fce.CARE_START_DATE                     AS clae_cla_episode_start,
    fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
    fce.CIN_903_CODE                        AS clae_cla_primary_need,
    fce.CARE_END_DATE                       AS clae_cla_episode_ceased,
    fce.CARE_REASON_END_DESC                AS clae_cla_episode_cease_reason,
    fr.DIM_DEPARTMENT_ID                    AS clae_cla_team,
    fr.DIM_WORKER_ID                        AS clae_cla_worker_id
FROM 
    Child_Social.FACT_CARE_EPISODES AS fce
JOIN 
    Child_Social.FACT_CLA AS fc ON fce.FACT_CARE_EPISODES_ID = fc.fact_cla_id
JOIN 
    Child_Social.FACT_REFERRALS AS fr ON fc.fact_referral_id = fr.fact_referral_id;



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clae_cla_worker_id ON ssd_cla_episodes (clae_cla_worker_id);

-- Add constraint(s) 
ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_professional 
FOREIGN KEY (clae_cla_worker_id) REFERENCES ssd_involvements (invo_professional_id);




/* 
=============================================================================
Object Name: ssd_cla_convictions
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_OFFENCE
=============================================================================
*/

-- if exists, drop
IF OBJECT_ID('ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_cla_convictions;

-- create structure
CREATE TABLE ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,
    clac_person_id              NVARCHAR(48),
    clac_cla_conviction_date    DATETIME,
    clac_cla_conviction_offence NVARCHAR(1000)
);

-- insert data
INSERT INTO ssd_cla_convictions (clac_cla_conviction_id, clac_person_id, clac_cla_conviction_date, clac_cla_conviction_offence)
SELECT 
    fo.FACT_OFFENCE_ID,
    fo.DIM_PERSON_ID,
    fo.OFFENCE_DTTM,
    fo.DESCRIPTION
FROM 
    Child_Social.FACT_OFFENCE as fo
INNER JOIN 
    ssd_person AS p ON fo.DIM_PERSON_ID = p.pers_person_id;


-- add constraint(s)
ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id);



/* 
=============================================================================
Object Name: ssd_cla_health
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_HEALTH_CHECK 
=============================================================================
*/


-- if exists, drop
IF OBJECT_ID('ssd_cla_health', 'U') IS NOT NULL DROP TABLE ssd_cla_health;

-- create structure
CREATE TABLE ssd_cla_health (
    clah_health_check_id        NVARCHAR(48) PRIMARY KEY,
    clah_person_id              NVARCHAR(48),
    clah_health_check_type      NVARCHAR(500),
    clah_health_check_date      DATETIME
);

-- insert data
INSERT INTO ssd_cla_health (clah_health_check_id, clah_person_id, clah_health_check_type, clah_health_check_date)
SELECT 
    fhc.FACT_HEALTH_CHECK_ID,
    fhc.DIM_PERSON_ID,
    fhc.DIM_LOOKUP_HC_TYPE_DESC,
    fhc.START_DTTM
FROM 
    Child_Social.FACT_HEALTH_CHECK as fhc
INNER JOIN 
    ssd_person AS p ON fhc.DIM_PERSON_ID = p.pers_person_id;


-- add constraint(s)
ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

CREATE NONCLUSTERED INDEX idx_clah_person_id ON ssd_cla_health (clah_person_id);


/* 
=============================================================================
Object Name: ssd_cla_immunisations
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

-- awaiting detail on spec sheet


/* 
=============================================================================
Object Name: ssd_substance_misuse
Description: 
Author: D2I
Last Modified Date: 14/11/2023
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SUBSTANCE_MISUSE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_cla_substance_misuse;

-- Create structure 
CREATE TABLE ssd_cla_substance_misuse (
    clas_substance_misuse_id       NVARCHAR(48) PRIMARY KEY,
    clas_person_id                 NVARCHAR(48),
    clas_substance_misuse_date     DATETIME,
    clas_substance_misused         NCHAR(100),
    clas_intervention_received     NCHAR(1)
);

-- Insert data
INSERT INTO ssd_cla_substance_misuse (
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
    ssd_person AS p ON fSM.DIM_PERSON_ID = p.pers_person_id;

-- Add constraint(s)
ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

CREATE NONCLUSTERED INDEX idx_clas_person_id ON ssd_cla_substance_misuse (clas_person_id);


/* 
=============================================================================
Object Name: ssd_cla_placement
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CLA_PLACEMENT
=============================================================================
*/


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_placement', 'U') IS NOT NULL DROP TABLE ssd_cla_placement;

-- Create structure
CREATE TABLE ssd_cla_placement (
    clap_cla_placement_id           NVARCHAR(48) PRIMARY KEY,
    clap_cla_episode_id             NVARCHAR(48),
    clap_cla_placement_start_date   DATETIME,
    clap_cla_placement_type         NVARCHAR(100),
    clap_cla_placement_urn          NVARCHAR(48),
    clap_cla_placement_distance     FLOAT, -- Float precision determined by value (or use DECIMAL(3, 2), -- Adjusted to fixed precision)
    clap_cla_placement_la           NVARCHAR(48),
    clap_cla_placement_provider     NVARCHAR(48),
    clap_cla_placement_postcode     NVARCHAR(8),
    clap_cla_placement_end_date     DATETIME,
    clap_cla_placement_change_reason NVARCHAR(100)
);

-- Insert data 
INSERT INTO ssd_cla_placement (
    clap_cla_placement_id, 
    clap_cla_episode_id, 
    clap_cla_placement_start_date,
    clap_cla_placement_type,
    clap_cla_placement_urn,
    clap_cla_placement_distance,
    clap_cla_placement_la,
    clap_cla_placement_provider,
    clap_cla_placement_postcode,
    clap_cla_placement_end_date,
    clap_cla_placement_change_reason
)
SELECT 
    fcp.FACT_CLA_PLACEMENT_ID                   AS clap_cla_placement_id,
    fce.FACT_CARE_EPISODES_ID                   AS clap_cla_episode_id, -- Adjust with actual column name [TESTING]
    fcp.START_DTTM                              AS clap_cla_placement_start_date,
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE          AS clap_cla_placement_type,
    fce.OFSTED_URN                              AS clap_cla_placement_urn,
    fcp.DISTANCE_FROM_HOME                      AS clap_cla_placement_distance,
    'PLACEHOLDER_DATA'                          AS clap_cla_placement_la, -- Replace with actual data source [TESTING]
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
    fcp.POSTCODE                                AS clap_cla_placement_postcode,
    fcp.END_DTTM                                AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE          AS clap_cla_placement_change_reason
FROM 
    Child_Social.FACT_CLA_PLACEMENT AS fcp
JOIN 
    Child_Social.FACT_CARE_EPISODES AS fce ON fcp.FACT_CARE_EPISODES_ID = fce.ID; -- Adjust with actual column name [TESTING]

-- Add constraint(s)
ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_clap_to_clae 
FOREIGN KEY (clap_cla_episode_id) REFERENCES ssd_cla_episodes(clae_cla_episode_id);

CREATE NONCLUSTERED INDEX idx_clap_cla_episode_id ON ssd_cla_substance_misuse (clap_cla_episode_id);



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

-- Check if exists & drop
IF OBJECT_ID('ssd_cla_review', 'U') IS NOT NULL DROP TABLE ssd_cla_review;

-- Create structure
CREATE TABLE ssd_cla_review (
    clar_cla_review_id                 NVARCHAR(48) PRIMARY KEY,
    clar_cla_episode_id                NVARCHAR(48),
    clar_cla_review_due_date           DATETIME,
    clar_cla_review_date               DATETIME,
    clar_cla_review_participation      NVARCHAR(100),
    clar_cla_review_last_iro_contact_date DATETIME
);

-- Insert data
INSERT INTO ssd_cla_review (
    clar_cla_review_id, 
    clar_cla_episode_id, 
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_participation,
    clar_cla_review_last_iro_contact_date
)
SELECT 
    fcr.FACT_CLA_REVIEW_ID                     AS clar_cla_review_id,
    'PLACEHOLDER_EPISODE_ID'                   AS clar_cla_episode_id, -- Replace with actual data source [TESTING]
    fcr.DUE_DTTM                               AS clar_cla_review_due_date,
    fcr.MEETING_DTTM                           AS clar_cla_review_date,
    'PLACEHOLDER_PARTICIPATION'                AS clar_cla_review_participation, -- Replace with actual data source [TESTING]
    'PLACEHOLDER_LAST_CONTACT_DATE'            AS clar_cla_review_last_iro_contact_date -- Replace with actual data source [TESTING]
FROM 
    Child_Social.FACT_CLA_REVIEW AS fcr;

-- Add constraint(s)
ALTER TABLE ssd_cla_review ADD CONSTRAINT FK_clar_to_clae 
FOREIGN KEY (clar_cla_episode_id) REFERENCES ssd_cla_episodes(clae_cla_episode_id);

-- Create nonclustered indexes
CREATE NONCLUSTERED INDEX idx_clar_cla_episode_id ON ssd_cla_review (clar_cla_episode_id);
CREATE NONCLUSTERED INDEX idx_clar_review_last_iro_contact_date ON ssd_cla_review (clar_cla_review_last_iro_contact_date);




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
- ssd_person
- FACT_MISSING_PERSON
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_missing', 'U') IS NOT NULL DROP TABLE ssd_missing;

-- Create structure
CREATE TABLE ssd_missing (
    miss_table_id           NVARCHAR(48) PRIMARY KEY,
    miss_la_person_id       NVARCHAR(48),
    miss_mis_epi_start      DATETIME,
    miss_mis_epi_type       NVARCHAR(100),
    miss_mis_epi_end        DATETIME,
    miss_mis_epi_rhi_offered NCHAR(1),
    miss_mis_epi_rhi_accepted NCHAR(1)
);

-- Insert data 
INSERT INTO ssd_missing (
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
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_ID AS substance_type_id,
    fsm.DIM_LOOKUP_SUBSTANCE_TYPE_CODE AS substance_type_code
FROM 
    Child_Social.FACT_MISSING_PERSON AS fmp
INNER JOIN 
    ssd_person AS p ON fmp.DIM_PERSON_ID = p.pers_person_id;

-- Add constraint(s)
ALTER TABLE ssd_missing ADD CONSTRAINT FK_missing_to_person
FOREIGN KEY (miss_la_person_id) REFERENCES ssd_person(pers_person_id);




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
- DIM_PERSON
=============================================================================
*/
-- Check if exists, & drop
IF OBJECT_ID('ssd_send') IS NOT NULL DROP TABLE ssd_send;


-- Create structure 
CREATE TABLE ssd_send (
    send_table_id       NVARCHAR(48),
    send_person_id      NVARCHAR(48),
    send_upn            NVARCHAR(48),
    send_uln            NVARCHAR(48),
    upn_unknown         NVARCHAR(48)
    );

-- insert data
INSERT INTO ssd_send (
    send_table_id,
    send_person_id, 
    send_upn,
    send_uln,
    upn_unknown

)
SELECT 
    f.FACT_903_DATA_ID  AS send_table_id,
    f.EXTERNAL_ID       AS send_person_id, -- DIM_PERSON_ID?? [TESTING]
    f.FACT_903_DATA_ID  AS send_upn,
    p.ULN               AS send_uln,
    f.NO_UPN_CODE       AS upn_unknown

FROM 
    Child_Social.FACT_903_DATA AS f
LEFT JOIN 
    Education.DIM_PERSON AS p ON f.DIM_PERSON_ID = p.DIM_PERSON_ID;

-- Add constraint(s)
ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);

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
Object Name: ssd_professionals
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
-
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_professionals', 'U') IS NOT NULL DROP TABLE ssd_professionals;

-- Create structure
CREATE TABLE ssd_professionals (
    prof_table_id                         NVARCHAR(48) PRIMARY KEY,
    prof_professional_id                  NVARCHAR(48),
    prof_social_worker_registration_no    NVARCHAR(48),
    prof_agency_worker_flag               NCHAR(1),
    prof_professional_job_title           NVARCHAR(500),
    prof_professional_caseload            INT,
    prof_professional_department          NVARCHAR(100),
    prof_full_time_equivalency            FLOAT
);

-- Determine last September 30th date
DECLARE @LastSept30th DATE
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END

-- Insert data
INSERT INTO ssd_professionals (
    prof_table_id, 
    prof_professional_id, 
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)
SELECT 
    dw.DIM_WORKER_ID                  AS prof_table_id,
    dw.STAFF_ID                       AS prof_professional_id,
    dw.WORKER_ID_CODE                 AS prof_social_worker_registration_no,
    'PLACEHOLDER_FLAG'                AS prof_agency_worker_flag,           -- Replace with actual data [TESTING]
    dw.JOB_TITLE                      AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)           AS prof_professional_caseload,        -- 0 when no open cases on given date.
    dw.DEPARTMENT_NAME                AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY          AS prof_full_time_equivalency
FROM 
    Child_Social.DIM_WORKER AS dw
LEFT JOIN (
    SELECT 
        -- open cases count
        DIM_WORKER_ID,
        COUNT(*) AS OpenCases
    FROM 
        Child_Social.FACT_REFERRALS
    WHERE 
        REFRL_START_DTTM <= @LastSept30th AND 
        (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM > @LastSept30th)
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID;


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prof_professional_id ON ssd_professionals (prof_professional_id);





/* 
=============================================================================
Object Name: ssd_involvements
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_professionals
- FACT_INVOLVEMENTS
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('ssd_involvements', 'U') IS NOT NULL DROP TABLE ssd_involvements;

-- Create structure
CREATE TABLE ssd_involvements (
    invo_involvements_id             NVARCHAR(48) PRIMARY KEY,
    invo_professional_id             NVARCHAR(48),
    invo_professional_role_id        NVARCHAR(48),
    invo_professional_team           NVARCHAR(48),
    invo_involvement_start_date      DATETIME,
    invo_involvement_end_date        DATETIME,
    invo_worker_change_reason        NVARCHAR(48)
);

-- Insert data
INSERT INTO ssd_involvements (
    invo_involvements_id, 
    invo_professional_id, 
    invo_professional_role_id,
    invo_professional_team,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason
)
SELECT 
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    fi.DIM_WORKER_ID                              AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC        AS invo_professional_team,
    fi.START_DTTM                                 AS invo_involvement_start_date,
    fi.END_DTTM                                   AS invo_involvement_end_date,
    fi.DIM_LOOKUP_CWREASON_CODE                   AS invo_worker_change_reason
FROM 
    Child_Social.FACT_INVOLVEMENTS AS fi;

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_invo_professional_id ON ssd_involvements (invo_professional_id);

-- Add constraint(s)
ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional 
FOREIGN KEY (invo_professional_id) REFERENCES ssd_professionals (prof_professional_id);

ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional_role 
FOREIGN KEY (invo_professional_role_id) REFERENCES ssd_professionals (prof_social_worker_registration_no);


    

/* 
=============================================================================
Object Name: ssd_pre_proceedings
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/

-- Check if exists, & drop
IF OBJECT_ID('ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE ssd_pre_proceedings;

-- Create structure
CREATE TABLE ssd_pre_proceedings (
    prep_table_id                       NVARCHAR(48) PRIMARY KEY,
    prep_person_id                      NVARCHAR(48),
    prep_plo_family_id                  NVARCHAR(48),
    prep_pre_pro_decision_date          DATETIME,
    prep_initial_pre_pro_meeting_date   DATETIME,
    prep_pre_pro_outcome                NVARCHAR(100),
    prep_agree_stepdown_issue_date      DATETIME,
    prep_cp_plans_referral_period       INT, -- SHOULD THIS BE A DATE?
    prep_legal_gateway_outcome          NVARCHAR(100),
    prep_prev_pre_proc_child            INT,
    prep_prev_care_proc_child           INT,
    prep_pre_pro_letter_date            DATETIME,
    prep_care_pro_letter_date           DATETIME,
    prep_pre_pro_meetings_num           INT,
    prep_pre_pro_parents_legal_rep      NCHAR(1), 
    prep_parents_legal_rep_point_of_issue NCHAR(2),
    prep_court_reference                NVARCHAR(48),
    prep_care_proc_court_hearings       INT,
    prep_care_proc_short_notice         NCHAR(1), 
    prep_proc_short_notice_reason       NVARCHAR(100),
    prep_la_inital_plan_approved        NCHAR(1), 
    prep_la_initial_care_plan           NVARCHAR(100),
    prep_la_final_plan_approved         NCHAR(1), 
    prep_la_final_care_plan             NVARCHAR(100)
);

-- Insert placeholder data
INSERT INTO ssd_pre_proceedings (#
    prep_table_id,
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
    '10001', 'DIM_PERSON1.PERSON_ID', 'PLO_FAMILY1', '2023-01-01', '2023-01-02', 'Outcome1', 
    '2023-01-03', 3, 'Approved', 2, 1, '2023-01-04', '2023-01-05', 2, 'Y', 
    'NA', 'COURT_REF_1', 1, 'N', 'Reason1', 'Y', 'Initial Plan 1', 'Y', 'Final Plan 1'
    ),
    (
    '10002', 'DIM_PERSON2.PERSON_ID', 'PLO_FAMILY2', '2023-02-01', '2023-02-02', 'Outcome2',
    '2023-02-03', 4, 'Denied', 1, 2, '2023-02-04', '2023-02-05', 3, 'N',
    'IS', 'COURT_REF_2', 2, 'Y', 'Reason2', 'N', 'Initial Plan 2', 'N', 'Final Plan 2'
    );

-- To switch on once source data defined.
-- INNER JOIN 
--     ssd_person AS p ON ssd_pre_proceedings.DIM_PERSON_ID = p.pers_person_id;

-- Create constraint(s)
ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

-- Create nonclustered index
CREATE NONCLUSTERED INDEX idx_prep_person_id ON ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_prep_pre_pro_decision_date ON ssd_pre_proceedings (prep_pre_pro_decision_date);


/* 
=============================================================================
Object Name: ssd_voice_of_child
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE ssd_voice_of_child;

-- Create structure
CREATE TABLE ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY, 
    voch_person_id              NVARCHAR(48), 
    voch_explained_worries      NCHAR(1), 
    voch_story_help_understand  NCHAR(1), 
    voch_agree_worker           NCHAR(1), 
    voch_plan_safe              NCHAR(1), 
    voch_tablet_help_explain    NCHAR(1)
);

-- Insert placeholder data
INSERT INTO ssd_voice_of_child (
    voch_table_id,
    voch_person_id,
    voch_explained_worries,
    voch_story_help_understand,
    voch_agree_worker,
    voch_plan_safe,
    voch_tablet_help_explain
)
VALUES
    ('ID001','P001', 'Y', 'Y', 'Y', 'N', 'N'),
    ('ID002','P002', 'Y', 'Y', 'Y', 'N', 'N');

-- To switch on once source data defined.
-- INNER JOIN 
--     ssd_person AS p ON ssd_voice_of_child.DIM_PERSON_ID = p.pers_person_id;


-- Create constraint(s)
ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
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
IF OBJECT_ID('ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE ssd_linked_identifiers;

-- Create structure
CREATE TABLE ssd_linked_identifiers (
    link_link_id NVARCHAR(48) PRIMARY KEY, 
    link_person_id NVARCHAR(48), 
    link_identifier_type NVARCHAR(MAX),
    link_identifier_value NVARCHAR(MAX),
    link_valid_from_date DATETIME,
    link_valid_to_date DATETIME
);

-- Insert placeholder data
INSERT INTO ssd_linked_identifiers (
    link_link_id,
    link_person_id,
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date,
    link_valid_to_date
)
VALUES
    ('placeholder data', 'DIM_PERSON.PERSON_ID', 'placeholder data', 'placeholder data', NULL, NULL);

-- To switch on once source data defined.
-- INNER JOIN 
--     ssd_person AS p ON ssd_linked_identifiers.DIM_PERSON_ID = p.pers_person_id;

-- Create constraint(s)
ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
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
IF OBJECT_ID('ssd_s251_finance', 'U') IS NOT NULL DROP TABLE ssd_s251_finance;

-- Create structure
CREATE TABLE ssd_s251_finance (
    s251_id NVARCHAR(48) PRIMARY KEY, 
    s251_cla_placement_id NVARCHAR(48), 
    s251_placeholder_1 NVARCHAR(48),
    s251_placeholder_2 NVARCHAR(48),
    s251_placeholder_3 NVARCHAR(48),
    s251_placeholder_4 NVARCHAR(48)
);

-- Insert placeholder data
INSERT INTO ssd_s251_finance (
    s251_id,
    s251_cla_placement_id,
    s251_placeholder_1,
    s251_placeholder_2,
    s251_placeholder_3,
    s251_placeholder_4
)
VALUES
    ('placeholder data', 'placeholder data', 'placeholder data', 'placeholder data', 'placeholder data', 'placeholder data');

-- Create constraint(s)
ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);









/* ********************************************************************************************************** */
/* Development clean up */

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */

