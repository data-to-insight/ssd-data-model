

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
DECLARE @ssd_timeframe_years INT = 6,
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
Object Name: ssd_person
Description: person/child details
Author: D2I
Last Modified Date: 22/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Child_Social.DIM_PERSON
- Child_Social.FACT_REFERRALS
- Child_Social.FACT_CONTACTS
- Child_Social.FACT_EHCP_EPISODE
- Child_Social.FACT_903_DATA
=============================================================================
*/

-- Check exists & drop temporary table
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;


-- Create structure
CREATE TABLE #ssd_person (
    pers_person_id          NVARCHAR(48) PRIMARY KEY, 
    pers_sex                NVARCHAR(48),
    pers_ethnicity          NVARCHAR(38),
    pers_dob                DATETIME,
    pers_common_child_id    NVARCHAR(10),
    pers_send               NVARCHAR(1),
    pers_expected_dob       DATETIME,       -- Date or NULL
    pers_death_date         DATETIME,
    pers_nationality        NVARCHAR(48)
);

-- Insert data into temporary table
INSERT INTO #ssd_person (
    pers_person_id,
    pers_sex,
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,
    pers_send,
    pers_expected_dob,
    pers_death_date,
    pers_nationality
)
SELECT 
    p.DIM_PERSON_ID,
    p.DIM_LOOKUP_VARIATION_OF_SEX_CODE,
    p.ETHNICITY_MAIN_CODE,
    p.BIRTH_DTTM,
    NULL AS pers_common_child_id,                       -- Set to NULL as default(dev) / or set to NHS num
    p.EHM_SEN_FLAG,
        CASE WHEN ISDATE(p.DOB_ESTIMATED) = 1               
        THEN CONVERT(DATETIME, p.DOB_ESTIMATED, 121)        -- Coerce to either valid Date
        ELSE NULL END,                                      --  or NULL
    p.DEATH_DTTM,
    p.NATNL_CODE
FROM 
    Child_Social.DIM_PERSON AS p

WHERE                                                       -- Filter invalid rows
    p.DIM_PERSON_ID IS NOT NULL                                 -- Unlikely, but in case
    AND p.DIM_PERSON_ID >= 1                                    -- Erronous rows with -1 seen

AND (                                                       -- Filter irrelevant rows by timeframe
    EXISTS (
        -- contact in last x@yrs
        SELECT 1 FROM Child_Social.FACT_CONTACTS fc
        WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
        AND fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- new or ongoing/active/unclosed referral in last x@yrs
        SELECT 1 FROM Child_Social.FACT_REFERRALS fr 
        WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
        AND fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )

);

-- Create index(es)
CREATE INDEX IDX_ssd_person_la_person_id ON #ssd_person(pers_person_id);



/*SSD Person filter (notes): - Implemented*/
-- [done]contact in last 6yrs - Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
-- [changes needed] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
-- [picked up within the referral] active plan or has been active in 6yrs 

/*SSD Person filter (notes): - OnN HOLD/Not included in SSD Ver/Iteration 1*/
--1
-- ehcp request in last 6yrs - Child_Social.FACT_EHCP_EPISODE.REQUEST_DTTM ; [perhaps not in iteration|version 1]
    -- OR EXISTS (
    --     -- ehcp request in last x@yrs
    --     SELECT 1 FROM Child_Social.FACT_EHCP_EPISODE fe 
    --     WHERE fe.DIM_PERSON_ID = p.DIM_PERSON_ID
    --     AND fe.REQUEST_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    -- )
    
--2 (Uncertainty re access EH)
-- Has eh_referral open in last 6yrs - 

--3 (Uncertainty re access SEN)
-- Has a record in send - Child_Social.FACT_SEN, DIM_LOOKUP_SEN, DIM_LOOKUP_SEN_TYPE ? 



/* 
=============================================================================
Object Name: ssd_family
Description: 
Author: D2I
Last Modified Date: 22/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
Dependencies: 
- Singleview.DIM_TF_FAMILY
- ssd.ssd_person
=============================================================================
*/
-- Check exists & drop temporary table
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- Create structure for temporary table
CREATE TABLE #ssd_family (
    fami_table_id           NVARCHAR(48) PRIMARY KEY, 
    fami_family_id          NVARCHAR(48),
    fami_person_id          NVARCHAR(48)
);

-- Insert data into temporary table
INSERT INTO #ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
)
SELECT 
    EXTERNAL_ID                         AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID  AS fami_family_id,
    DIM_PERSON_ID                       AS fami_person_id
FROM Child_Social.FACT_CONTACTS AS fc


WHERE EXISTS ( -- only need address data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fc.DIM_PERSON_ID
);





/* 
=============================================================================
Object Name: ssd_address
Description: 
Author: D2I
Last Modified Date: 21/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Need to verify json obj structure on pre-2014 SQL server instances
Dependencies: 
- ssd_person
- DIM_PERSON_ADDRESS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;

-- Create structure
CREATE TABLE #ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,
    addr_person_id          NVARCHAR(48), 
    addr_address_type       NVARCHAR(48),
    addr_address_start      DATETIME,
    addr_address_end        DATETIME,
    addr_address_postcode   NVARCHAR(15),
    addr_address_json       NVARCHAR(1000)
);

-- insert data
INSERT INTO #ssd_address (
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
    pa.DIM_PERSON_ID, -- Assuming EXTERNAL_ID corresponds to pers_person_id
    pa.ADDSS_TYPE_CODE,
    pa.START_DTTM,
    pa.END_DTTM,
    CASE 
        WHEN REPLACE(pa.POSTCODE, ' ', '') NOT LIKE '%[^X]%' THEN ''
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''
        ELSE REPLACE(pa.POSTCODE, ' ', '')
    END AS CleanedPostcode,
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
    ) AS addr_address_json
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa

WHERE EXISTS 
    ( -- only need address data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = pa.DIM_PERSON_ID
    )

-- Create index(es)
CREATE INDEX IDX_address_person ON #ssd_address(addr_person_id);
CREATE INDEX IDX_address_start ON #ssd_address(addr_address_start);
CREATE INDEX IDX_address_end ON #ssd_address(addr_address_end);



/* 
=============================================================================
Object Name: ssd_disability
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_DISABILITY
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

-- Create the structure
CREATE TABLE #ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,
    disa_person_id          NVARCHAR(48) NOT NULL,
    disa_disability_code    NVARCHAR(48) NOT NULL
);


-- Insert data
INSERT INTO #ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)
SELECT 
    fd.FACT_DISABILITY_ID, 
    fd.DIM_PERSON_ID, 
    fd.DIM_LOOKUP_DISAB_CODE
FROM 
    Child_Social.FACT_DISABILITY AS fd

WHERE EXISTS 
    ( -- only need address data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fd.DIM_PERSON_ID
    )
;
-- Create index(es)
CREATE INDEX IDX_disability_person_id ON #ssd_disability(disa_person_id);




/* 
=============================================================================
Object Name: #ssd_immigration_status
Description: 
Author: D2I
Last Modified Date: 23/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_IMMIGRATION_STATUS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;


-- Create structure
CREATE TABLE #ssd_immigration_status (
    immi_immigration_status_id      NVARCHAR(48) PRIMARY KEY,
    immi_person_id                  NVARCHAR(48),
    immi_immigration_status_start   DATETIME,
    immi_immigration_status_end     DATETIME,
    immi_immigration_status         NVARCHAR(48)
);


-- insert data
INSERT INTO #ssd_immigration_status (
    immi_immigration_status_id, 
    immi_person_id, 
    immi_immigration_status_start,
    immi_immigration_status_end,
    immi_immigration_status
)
SELECT 
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_CODE
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims

WHERE 
    EXISTS (
        SELECT 1
        FROM #ssd_person p
        WHERE p.pers_person_id = ims.DIM_PERSON_ID
    );


-- Create index(es)
CREATE INDEX IDX_immigration_status_immi_person_id ON #ssd_immigration_status(immi_person_id);
CREATE INDEX IDX_immigration_status_start ON #ssd_immigration_status(immi_immigration_status_start);
CREATE INDEX IDX_immigration_status_end ON #ssd_immigration_status(immi_immigration_status_end);




/* 
=============================================================================
Object Name: ssd_mother
Description: 
Author: D2I
Last Modified Date: 15/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_PERSON_RELATION
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_mother', 'U') IS NOT NULL DROP TABLE #ssd_mother;

-- Create structure
CREATE TABLE #ssd_mother (
    moth_table_id               NVARCHAR(48) PRIMARY KEY,
    moth_person_id              NVARCHAR(48),
    moth_childs_person_id       NVARCHAR(48),
    moth_childs_dob             DATETIME
);

-- Insert data
INSERT INTO #ssd_mother (
    moth_table_id,
    moth_person_id, 
    moth_childs_person_id, 
    moth_childs_dob
)
SELECT 
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
FROM 
    Child_Social.FACT_PERSON_RELATION AS fpr
    
WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fpr.DIM_PERSON_ID
    );


-- Create index(es)
CREATE INDEX IDX_ssd_mother_moth_person_id ON #ssd_mother(moth_person_id);



/* 
=============================================================================
Object Name: #ssd_legal_status
Description: 
Author: D2I
Last Modified Date: 22/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_LEGAL_STATUS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;


-- Create structure
CREATE TABLE #ssd_legal_status (
    lega_legal_status_id        NVARCHAR(48) PRIMARY KEY,
    lega_person_id              NVARCHAR(48),
    lega_legal_status_start     DATETIME,
    lega_legal_status_end       DATETIME
);

-- Insert data 
INSERT INTO #ssd_legal_status (
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
    Child_Social.FACT_LEGAL_STATUS AS fls

WHERE 
    EXISTS (
        SELECT 1
        FROM #ssd_person p
        WHERE p.pers_person_id = fls.DIM_PERSON_ID
    );

-- Create index(es)
CREATE INDEX IDX_ssd_legal_status_lega_person_id ON #ssd_legal_status(lega_person_id);




/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 06/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_contact') IS NOT NULL DROP TABLE #ssd_contact;

-- Create structure
CREATE TABLE #ssd_contact (
    cont_contact_id             NVARCHAR(48) PRIMARY KEY,
    cont_person_id              NVARCHAR(48),
    cont_contact_start          DATETIME,
    cont_contact_source         NVARCHAR(255), 
    cont_contact_outcome_json   NVARCHAR(500) 
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
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
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

WHERE 
    EXISTS (
        SELECT 1
        FROM #ssd_person p
        WHERE p.pers_person_id = fc.DIM_PERSON_ID
    );


-- Create index(es)
CREATE INDEX IDX_contact_person_id ON #ssd_contact(cont_person_id);


/* 
=============================================================================
Object Name: ssd_early_help_episodes
Description: 
Author: D2I
Last Modified Date: 22/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.9
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CAF_EPISODE
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;

-- Create structure
CREATE TABLE #ssd_early_help_episodes (
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
INSERT INTO #ssd_early_help_episodes (
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
    'PLACEHOLDER_DATA' -- placeholder value [TESTING]
FROM 
    Child_Social.FACT_CAF_EPISODE AS cafe
WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = cafe.DIM_PERSON_ID
    );

-- Create index(es)
CREATE INDEX IDX_ssd_early_help_episodes_person_id ON #ssd_early_help_episodes(earl_person_id);






/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- FACT_REFERRALS
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- Create structure
CREATE TABLE #ssd_cin_episodes
(
    cine_referral_id            INT,
    cine_person_id              NVARCHAR(48),
    cine_referral_date          DATETIME,
    cine_cin_primary_need       INT,
    cine_referral_source        NVARCHAR(100),
    cine_referral_outcome_json  NVARCHAR(500),
    cine_referral_nfa           NCHAR(1), 
    cine_close_reason           NVARCHAR(100),
    cine_close_date             DATETIME,
    cine_referral_team          NVARCHAR(100),
    cine_referral_worker_id     NVARCHAR(48)
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

-- Create index(es)
CREATE INDEX IDX_ssd_cin_episodes_person_id ON #ssd_cin_episodes(cine_person_id);






/* 
=============================================================================
Object Name: #ssd_cin_assessments
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.9
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SINGLE_ASSESSMENT
=============================================================================
*/
-- Check if exists, & drop 
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;

-- Create structure
CREATE TABLE #ssd_cin_assessments
(
    cina_assessment_id          NVARCHAR(48) PRIMARY KEY,
    cina_person_id              NVARCHAR(48),
    cina_referral_id            NVARCHAR(48),
    cina_assessment_start_date  DATETIME,
    cina_assessment_child_seen  NCHAR(1), 
    cina_assessment_auth_date   DATETIME, -- This needs checking !! [TESTING]
    cina_assessment_outcome_json NVARCHAR(1000),
    cina_assessment_outcome_nfa NCHAR(1), 
    cina_assessment_team        NVARCHAR(100),
    cina_assessment_worker_id   NVARCHAR(48)
);

-- Insert data
INSERT INTO #ssd_cin_assessments
(
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date, -- This needs checking !! [TESTING]
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
    fa.START_DTTM,              -- This needs checking !! [TESTING]
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
    Child_Social.FACT_SINGLE_ASSESSMENT AS fa
WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fa.DIM_PERSON_ID
    );

-- Create index(es)
CREATE INDEX IDX_ssd_cin_assessments_person_id ON #ssd_cin_assessments(cina_person_id);





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
Object Name: ssd_professionals
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
-
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;

-- Create structure
CREATE TABLE #ssd_professionals (
    prof_table_id                         NVARCHAR(48) PRIMARY KEY,
    prof_professional_id                  NVARCHAR(48),
    prof_social_worker_registration_no    NVARCHAR(48),
    prof_agency_worker_flag               NCHAR(1),
    prof_professional_job_title           NVARCHAR(500),
    prof_professional_caseload            INT,
    prof_professional_department          NVARCHAR(100),
    prof_full_time_equivalency            FLOAT
);

-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
DECLARE @LastSept30th DATE;
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;

-- Insert data
INSERT INTO #ssd_professionals (
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
    'N'                               AS prof_agency_worker_flag,           -- Not available in SSD Ver/Iteration 1 [TESTING] [PLACEHOLDER_DATA]
    dw.JOB_TITLE                      AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)           AS prof_professional_caseload,        -- 0 when no open cases on given date.
    dw.DEPARTMENT_NAME                AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY          AS prof_full_time_equivalency
FROM 
    Child_Social.DIM_WORKER AS dw
LEFT JOIN (
    SELECT 
        -- Calculate CASELOAD 
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
CREATE NONCLUSTERED INDEX idx_prof_professional_id ON #ssd_professionals (prof_professional_id);





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
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;

-- Create structure
CREATE TABLE #ssd_involvements (
    invo_involvements_id             NVARCHAR(48) PRIMARY KEY,
    invo_professional_id             NVARCHAR(48),
    invo_professional_role_id        NVARCHAR(48),
    invo_professional_team           NVARCHAR(48),
    invo_involvement_start_date      DATETIME,
    invo_involvement_end_date        DATETIME,
    invo_worker_change_reason        NVARCHAR(48)
);

-- Insert data
INSERT INTO #ssd_involvements (
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
CREATE NONCLUSTERED INDEX idx_invo_professional_id ON #ssd_involvements (invo_professional_id);



    

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
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

-- Create structure
CREATE TABLE #ssd_pre_proceedings (
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
INSERT INTO #ssd_pre_proceedings (
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


-- Create nonclustered index
CREATE NONCLUSTERED INDEX idx_prep_person_id ON #ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_prep_pre_pro_decision_date ON #ssd_pre_proceedings (prep_pre_pro_decision_date);


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
IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

-- Create structure
CREATE TABLE #ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY, 
    voch_person_id              NVARCHAR(48), 
    voch_explained_worries      NCHAR(1), 
    voch_story_help_understand  NCHAR(1), 
    voch_agree_worker           NCHAR(1), 
    voch_plan_safe              NCHAR(1), 
    voch_tablet_help_explain    NCHAR(1)
);

-- Insert placeholder data [TESTING]
INSERT INTO #ssd_voice_of_child (
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
IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;

-- Create structure
CREATE TABLE #ssd_linked_identifiers (
    link_link_id NVARCHAR(48) PRIMARY KEY, 
    link_person_id NVARCHAR(48), 
    link_identifier_type NVARCHAR(MAX),
    link_identifier_value NVARCHAR(MAX),
    link_valid_from_date DATETIME,
    link_valid_to_date DATETIME
);

-- Insert placeholder data [TESTING]
INSERT INTO #ssd_linked_identifiers (
    link_link_id,
    link_person_id,
    link_identifier_type,
    link_identifier_value,
    link_valid_from_date,
    link_valid_to_date
)
VALUES
    ('PLACEHOLDER_DATA', 'DIM_PERSON.PERSON_ID', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', NULL, NULL);

-- To switch on once source data defined.
-- INNER JOIN 
--     ssd_person AS p ON ssd_linked_identifiers.DIM_PERSON_ID = p.pers_person_id;





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
IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

-- Create structure
CREATE TABLE #ssd_s251_finance (
    s251_id NVARCHAR(48) PRIMARY KEY, 
    s251_cla_placement_id NVARCHAR(48), 
    s251_placeholder_1 NVARCHAR(48),
    s251_placeholder_2 NVARCHAR(48),
    s251_placeholder_3 NVARCHAR(48),
    s251_placeholder_4 NVARCHAR(48)
);

-- Insert placeholder data [TESTING]
INSERT INTO #ssd_s251_finance (
    s251_id,
    s251_cla_placement_id,
    s251_placeholder_1,
    s251_placeholder_2,
    s251_placeholder_3,
    s251_placeholder_4
)
VALUES
    ('PLACEHOLDER_DATA_ID', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA');








/* ********************************************************************************************************** */
/* Development clean up */

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

