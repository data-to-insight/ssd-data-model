
/* DEV Notes:
- Although returns expect dd/mm/YYYY formating on dates. Extract maintains DATETIME not DATE, 
- Full review needed of max/exagerated/default new field type sizes e.g. family_id NVARCHAR(48)  (keys cannot use MAX)
*/


/* ********************************************************************************************************** */
/* Development set up */

-- Note: 
-- This script is for creating PER(Persistent) tables within the temp DB name space for testing purposes. 
-- SSD extract files with the suffix ..._per.sql - for creating the persistent table versions.
-- SSD extract files with the suffix ..._tmp.sql - for creating the temporary table versions.

USE HDM_Local;
GO


/* [TESTING] Set up */
DECLARE @TestProgress INT = 0;
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder';

-- To use the above vars add this around each test CREATE object
/*
[TESTING] Create marker
SET @TableName = N'ssd_table_name_placeholder';
PRINT 'Creating table: ' + @TableName;

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));
*/


-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time
/* ********************************************************************************************************** */


-- ssd extract time-frame (YRS)
DECLARE @ssd_timeframe_years INT = 6;
DECLARE @ssd_sub1_range_years INT = 1;

-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
DECLARE @LastSept30th DATE; -- Most recent past September 30th date towards case load calc



/*
=============================================================================
Object Name: ssd_person
Description: person/child details
Author: D2I
Last Modified Date: 20/10/23
DB Compatibility: SQL Server 2014+|...

Version: 1.3
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
-- [TESTING] Create marker
SET @TableName = N'ssd_person';
PRINT 'Creating table: ' + @TableName;


-- check exists & drop
IF OBJECT_ID('ssd_person') IS NOT NULL DROP TABLE ssd_person;


-- Create structure
CREATE TABLE ssd_person (
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

-- Insert data 
INSERT INTO ssd_person (
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
CREATE INDEX IDX_ssd_person_la_person_id ON ssd_person(pers_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/*SSD Person filter (notes): - Implemented*/
-- [done]contact in last 6yrs - Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
-- [done] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
-- [picked up within the referral] active plan or has been active in 6yrs 

/*SSD Person filter (notes): - ON HOLD/Not included in SSD Ver/Iteration 1*/
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
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
Dependencies: 
- FACT_CONTACTS
- ssd.ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_family';
PRINT 'Creating table: ' + @TableName;


-- check exists & drop
IF OBJECT_ID('ssd_family') IS NOT NULL DROP TABLE ssd_family;


-- Create structure
CREATE TABLE ssd_family (
    fami_table_id           NVARCHAR(48) PRIMARY KEY, 
    fami_family_id          NVARCHAR(48),
    fami_person_id          NVARCHAR(48)
);

-- Insert data 
INSERT INTO ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )
SELECT 
    fc.EXTERNAL_ID                          AS fami_table_id,
    fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
    fc.DIM_PERSON_ID                        AS fami_person_id

FROM Child_Social.FACT_CONTACTS AS fc

WHERE EXISTS ( -- only need address data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fc.DIM_PERSON_ID
    );


-- Create index(es)
CREATE INDEX IDX_family_person_id ON ssd_family(fami_person_id);

-- Create constraint(s)
ALTER TABLE ssd_family ADD CONSTRAINT FK_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_address
Description: 
Author: D2I
Last Modified Date: 21/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Need to verify json obj structure on pre-2014 SQL server instances
Dependencies: 
- ssd_person
- DIM_PERSON_ADDRESS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_address';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_address') IS NOT NULL DROP TABLE ssd_address;


-- Create structure
CREATE TABLE ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,
    addr_person_id          NVARCHAR(48), 
    addr_address_type       NVARCHAR(48),
    addr_address_start      DATETIME,
    addr_address_end        DATETIME,
    addr_address_postcode   NVARCHAR(15),
    addr_address_json       NVARCHAR(1000)
);


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
    pa.DIM_PERSON_ID, 
    pa.ADDSS_TYPE_CODE,
    pa.START_DTTM,
    pa.END_DTTM,
    CASE 
    -- Some clean-up based on known data
        WHEN REPLACE(pa.POSTCODE, ' ', '') = REPLICATE('X', LEN(REPLACE(pa.POSTCODE, ' ', ''))) THEN '' -- clear pcode of containing all X's
        WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN ''                                -- clear pcode of containing nopostcode
        ELSE REPLACE(pa.POSTCODE, ' ', '')                                                              -- remove all spaces for consistency
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
    (   -- only need address data for ssd relevant records
        -- This also negates the need to apply DIM_PERSON_ID <> '-1';  
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = pa.DIM_PERSON_ID
    );


-- Create constraint(s)
ALTER TABLE ssd_address ADD CONSTRAINT FK_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE INDEX IDX_address_person ON ssd_address(addr_person_id);
CREATE INDEX IDX_address_start ON ssd_address(addr_address_start);
CREATE INDEX IDX_address_end ON ssd_address(addr_address_end);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_disability
Description: 
Author: D2I
Last Modified Date: 03/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_DISABILITY
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_disability';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_disability') IS NOT NULL DROP TABLE ssd_disability;

-- Create the structure
CREATE TABLE ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,
    disa_person_id          NVARCHAR(48) NOT NULL,
    disa_disability_code    NVARCHAR(48) NOT NULL
);


-- Insert data
INSERT INTO ssd_disability (
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
    );


    
-- Create constraint(s)
ALTER TABLE ssd_disability ADD CONSTRAINT FK_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_disability_person_id ON ssd_disability(disa_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





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
-- [TESTING] Create marker
SET @TableName = N'ssd_immigration_status';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_immigration_status') IS NOT NULL DROP TABLE ssd_immigration_status;


-- Create structure
CREATE TABLE ssd_immigration_status (
    immi_immigration_status_id      NVARCHAR(48) PRIMARY KEY,
    immi_person_id                  NVARCHAR(48),
    immi_mmigration_status_start    DATETIME,
    immi_immigration_status_end     DATETIME,
    immi_immigration_status         NVARCHAR(48)
);


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
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_CODE
FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS ims

WHERE 
    EXISTS 
    ( -- only need data for ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE p.pers_person_id = ims.DIM_PERSON_ID
    );


-- Create constraint(s)
ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id);
CREATE INDEX IDX_immigration_status_start ON ssd_immigration_status(immi_immigration_status_start);
CREATE INDEX IDX_immigration_status_end ON ssd_immigration_status(immi_immigration_status_end);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_mother
Description: 
Author: D2I
Last Modified Date: 28/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
Dependencies: 
- ssd_person
- FACT_PERSON_RELATION
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_mother';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_mother;

-- Create structure
CREATE TABLE ssd_mother (
    moth_table_id               NVARCHAR(48) PRIMARY KEY,
    moth_person_id              NVARCHAR(48),
    moth_childs_person_id       NVARCHAR(48),
    moth_childs_dob             DATETIME
);

-- Insert data
INSERT INTO ssd_mother (
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
    )

 AND fpr.DIM_LOOKUP_RELTN_TYPE_CODE IN ('CHI', 'PAR'); -- only interested in parent/child relations

-- Create index(es)
CREATE INDEX IDX_ssd_mother_moth_person_id ON ssd_mother(moth_person_id);

-- Add constraint(s)
ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
-- [TESTING] Create marker
SET @TableName = N'ssd_legal_status';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_legal_status') IS NOT NULL DROP TABLE ssd_legal_status;


-- Create structure
CREATE TABLE ssd_legal_status (
    lega_legal_status_id        NVARCHAR(48) PRIMARY KEY,
    lega_person_id              NVARCHAR(48),
    lega_legal_status_start     DATETIME,
    lega_legal_status_end       DATETIME
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
    Child_Social.FACT_LEGAL_STATUS AS fls

WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fls.DIM_PERSON_ID
    );

-- Create index(es)
CREATE INDEX IDX_ssd_legal_status_lega_person_id ON ssd_legal_status(lega_person_id);

-- Create constraint(s)
ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_contact
Description: 
Author: D2I
Last Modified Date: 06/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Inclusion in contacts might differ between LAs. 
        Baseline definition:
        Contains safeguarding and referral to early help data.
        
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_contact';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_contact') IS NOT NULL DROP TABLE ssd_contact;

-- Create structure
CREATE TABLE ssd_contact (
    cont_contact_id             NVARCHAR(48) PRIMARY KEY,
    cont_person_id              NVARCHAR(48),
    cont_contact_start          DATETIME,
    cont_contact_source         NVARCHAR(100), -- Receives ID field not desc hence size
    cont_contact_outcome_json   NVARCHAR(500) 
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
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    (                                                           -- Create JSON string for the address
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
    
WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fc.DIM_PERSON_ID
    );


-- Create constraint(s)
ALTER TABLE ssd_contact ADD CONSTRAINT FK_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE INDEX IDX_contact_person_id ON ssd_contact(cont_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
-- [TESTING] Create marker
SET @TableName = N'ssd_early_help_episodes';
PRINT 'Creating table: ' + @TableName;


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
    'PLACEHOLDER_DATA'                              -- [PLACEHOLDER_DATA] [TESTING]
FROM 
    Child_Social.FACT_CAF_EPISODE AS cafe

WHERE EXISTS 
    ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = cafe.DIM_PERSON_ID
    );

-- Create index(es)
CREATE INDEX IDX_ssd_early_help_episodes_person_id ON ssd_early_help_episodes(earl_person_id);

-- Create constraint(s)
ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_cin_episodes;

-- Create structure
CREATE TABLE ssd_cin_episodes
(
    cine_referral_id            INT,
    cine_person_id              NVARCHAR(48),
    cine_referral_date          DATETIME,
    cine_cin_primary_need       INT,
    cine_referral_source        NVARCHAR(255),
    cine_referral_outcome_json  NVARCHAR(500),
    cine_referral_nfa           NCHAR(1), 
    cine_close_reason           NVARCHAR(100),
    cine_close_date             DATETIME,
    cine_referral_team          NVARCHAR(255),
    cine_referral_worker_id     NVARCHAR(48)
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
    ) AS cine_referral_outcome_json,
    fr.OUTCOME_NFA_FLAG,
    fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
    fr.REFRL_END_DTTM,
    fr.DIM_DEPARTMENT_ID_DESC,
    fr.DIM_WORKER_ID_DESC
FROM 
    Child_Social.FACT_REFERRALS AS fr

WHERE 
    fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
AND
    DIM_PERSON_ID <> '-1';  -- Exclude rows with '-1'
    ;

-- Create index(es)
CREATE INDEX IDX_ssd_cin_episodes_person_id ON ssd_cin_episodes(cine_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: #ssd_cin_assessments
Description: 
Author: D2I
Last Modified Date: 04/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SINGLE_ASSESSMENT
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_assessments';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop 
IF OBJECT_ID('ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_cin_assessments;

-- Create structure
CREATE TABLE ssd_cin_assessments
(
    cina_assessment_id          NVARCHAR(48) PRIMARY KEY,
    cina_person_id              NVARCHAR(48),
    cina_referral_id            NVARCHAR(48),
    cina_assessment_start_date  DATETIME,
    cina_assessment_child_seen  NCHAR(1), 
    cina_assessment_auth_date   DATETIME,               -- This needs checking !! [TESTING]
    cina_assessment_outcome_json NVARCHAR(1000),        -- enlarged due to comments field    
    cina_assessment_outcome_nfa NCHAR(1), 
    cina_assessment_team        NVARCHAR(255),
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
    cina_assessment_auth_date,      -- This needs checking !! [TESTING]
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
    fa.START_DTTM,                  -- This needs checking !! [TESTING]
    (
        SELECT 
            NULLIF(fa.OUTCOME_NFA_FLAG, '')                 AS "OUTCOME_NFA_FLAG",
            NULLIF(fa.OUTCOME_NFA_S47_END_FLAG, '')         AS "OUTCOME_NFA_S47_END_FLAG",
            NULLIF(fa.OUTCOME_STRATEGY_DISCUSSION_FLAG, '') AS "OUTCOME_STRATEGY_DISCUSSION_FLAG",
            NULLIF(fa.OUTCOME_CLA_REQUEST_FLAG, '')         AS "OUTCOME_CLA_REQUEST_FLAG",
            NULLIF(fa.OUTCOME_PRIVATE_FOSTERING_FLAG, '')   AS "OUTCOME_PRIVATE_FOSTERING_FLAG",
            NULLIF(fa.OUTCOME_LEGAL_ACTION_FLAG, '')        AS "OUTCOME_LEGAL_ACTION_FLAG",
            NULLIF(fa.OUTCOME_PROV_OF_SERVICES_FLAG, '')    AS "OUTCOME_PROV_OF_SERVICES_FLAG",
            NULLIF(fa.OUTCOME_PROV_OF_SB_CARE_FLAG, '')     AS "OUTCOME_PROV_OF_SB_CARE_FLAG",
            NULLIF(fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG, '') AS "OUTCOME_SPECIALIST_ASSESSMENT_FLAG",
            NULLIF(fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '') AS "OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG",
            NULLIF(fa.OUTCOME_OTHER_ACTIONS_FLAG, '')       AS "OUTCOME_OTHER_ACTIONS_FLAG",
            NULLIF(fa.OTHER_OUTCOMES_EXIST_FLAG, '')        AS "OTHER_OUTCOMES_EXIST_FLAG",
            NULLIF(fa.TOTAL_NO_OF_OUTCOMES, '')             AS "TOTAL_NO_OF_OUTCOMES",
            NULLIF(fa.OUTCOME_COMMENTS, '')                 AS "OUTCOME_COMMENTS" -- dictates a larger _json size
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cina_assessment_outcome_json, 
    fa.OUTCOME_NFA_FLAG                                     AS cina_assessment_outcome_nfa,
    fa.COMPLETED_BY_DEPT_NAME                               AS cina_assessment_team,
    fa.COMPLETED_BY_USER_STAFF_ID                           AS cina_assessment_worker_id
FROM 
    Child_Social.FACT_SINGLE_ASSESSMENT AS fa

WHERE EXISTS 
(
    -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fa.DIM_PERSON_ID
);


-- Create index(es)
CREATE INDEX IDX_ssd_cin_assessments_person_id ON ssd_cin_assessments(cina_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_social_worker 
FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_social_worker(socw_social_worker_id);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
-- [TESTING] Create marker
SET @TableName = N'ssd_assessment_factors';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_assessment_factors') IS NOT NULL DROP TABLE ssd_assessment_factors;



/* issues with join [TESTING]
-- The multi-part identifier "cpd.DIM_OUTCM_CREATE_BY_DEPT_ID" could not be bound. */






/* 
=============================================================================
Object Name: ssd_cin_plans
Description: 
Author: D2I
Last Modified Date: 08/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: [TESTING] - not sent to knowsley
Dependencies: 
- ssd_person
- FACT_CARE_PLANS
=============================================================================
*/


-- [TESTING] Create marker
SET @TableName = N'ssd_cin_plans';
PRINT 'Creating table: ' + @TableName;

-- Check if exists & drop
IF OBJECT_ID('ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_cin_plans;

-- Create structure
CREATE TABLE ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,
    cinp_referral_id            NVARCHAR(48),
    cinp_person_id              NVARCHAR(48),
    cinp_cin_plan_start         DATETIME,
    cinp_cin_plan_end           DATETIME,
    cinp_cin_plan_team          NVARCHAR(255),
    cinp_cin_plan_worker_id     NVARCHAR(48)
);
 
-- Insert data
INSERT INTO ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start,
    cinp_cin_plan_end,
    cinp_cin_plan_team,
    cinp_cin_plan_worker_id
)
SELECT
    fp.FACT_CARE_PLAN_ID               AS cinp_cin_plan_id, 
    fp.FACT_REFERRAL_ID                AS cinp_referral_id,
    fp.DIM_PERSON_ID                   AS cinp_person_id,
    fp.START_DTTM                      AS cinp_cin_plan_start,
    fp.END_DTTM                        AS cinp_cin_plan_end,
    fp.DIM_PLAN_COORD_DEPT_ID_DESC     AS cinp_cin_plan_team,
    fp.DIM_PLAN_COORD_ID_DESC          AS cinp_cin_plan_worker_id

FROM Child_Social.FACT_CARE_PLANS AS fp

JOIN Child_Social.FACT_CARE_PLAN_SUMMARY AS cps ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
 
WHERE DIM_LOOKUP_PLAN_TYPE_CODE = 'FP' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
AND EXISTS 
(
    -- only need data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fp.DIM_PERSON_ID
);


-- Create index(es)
CREATE INDEX IDX_ssd_cin_plans_person_id ON ssd_cin_plans(cinp_person_id);

-- Create constraint(s)
ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_cin_visits
Description: 
Author: D2I
Last Modified Date: 07/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:    Source table can be very large! Avoid any unfiltered queries. 
            Notes: Does this need to be filtered by only visits in their current Referral episode? 
                    however for some this ==2 weeks, others==~17 years
Dependencies: 
- FACT_CASENOTES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_visits';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_cin_visits') IS NOT NULL DROP TABLE ssd_cin_visits;

-- Create structure
CREATE TABLE ssd_cin_visits
(
    cinv_cin_casenote_id        NVARCHAR(48) PRIMARY KEY,       -- This needs checking!! [TESTING]
    cinv_cin_visit_id           NVARCHAR(48),                   -- This needs checking!! [TESTING]
    cinv_cin_plan_id            NVARCHAR(48),
    cinv_cin_visit_date         DATETIME,
    cinv_cin_visit_seen         NCHAR(1), 
    cinv_cin_visit_seen_alone   NCHAR(1), 
    cinv_cin_visit_bedroom      NCHAR(1)
);

-- Insert data
INSERT INTO ssd_cin_visits
(
    cinv_cin_casenote_id,               -- This needs checking!! [TESTING]
    cinv_cin_visit_id,                  -- This needs checking!! [TESTING]
    cinv_cin_plan_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)
SELECT 
    cn.FACT_CASENOTE_ID,                -- This needs checking!! [TESTING]
    cn.FACT_FORM_ID,     -- This needs checking!! [TESTING]
    cn.FACT_FORM_ID,
    cn.EVENT_DTTM,
    cn.SEEN_FLAG,
    cn.SEEN_ALONE_FLAG,
    cn.SEEN_BEDROOM_FLAG
FROM 
    Child_Social.FACT_CASENOTES cn

WHERE
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO', 
    'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID');


-- Create constraint(s)
ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_cin_plans 
FOREIGN KEY (cinv_cin_plan_id) REFERENCES ssd_cin_plans(cinp_cin_plan_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_s47_enquiry
Description: 
Author: D2I
Last Modified Date: 22/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_s47_enquiry';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_s47_enquiry') IS NOT NULL DROP TABLE ssd_s47_enquiry;

-- Create structure 
CREATE TABLE ssd_s47_enquiry (
    s47e_s47_enquiry_id             NVARCHAR(48) PRIMARY KEY,
    s47e_referral_id                NVARCHAR(48),
    s47e_person_id                  NVARCHAR(48),
    s47e_s47_start_date             DATETIME,
    s47e_s47_end_date               DATETIME,
    s47e_s47_nfa                    NCHAR(1),
    s47e_s47_outcome_json           NVARCHAR(1000),
    s47e_s47_completed_by_team      NVARCHAR(100),
    s47e_s47_completed_by_worker    NVARCHAR(48)
);

-- insert data
INSERT INTO ssd_s47_enquiry(
    s47e_s47_enquiry_id,
    s47e_referral_id,
    s47e_person_id,
    s47e_s47_start_date,
    s47e_s47_end_date,
    s47e_s47_nfa,
    s47e_s47_outcome_json,
    s47e_s47_completed_by_team,
    s47e_s47_completed_by_worker
)
SELECT 
    s47.FACT_S47_ID,
    s47.FACT_REFERRAL_ID,
    s47.DIM_PERSON_ID,
    s47.START_DTTM,
    s47.END_DTTM,
    s47.OUTCOME_NFA_FLAG,
    (
        SELECT 
            NULLIF(s47.OUTCOME_NFA_FLAG, '')                   AS "OUTCOME_NFA_FLAG",
            NULLIF(s47.OUTCOME_LEGAL_ACTION_FLAG, '')          AS "OUTCOME_LEGAL_ACTION_FLAG",
            NULLIF(s47.OUTCOME_PROV_OF_SERVICES_FLAG, '')      AS "OUTCOME_PROV_OF_SERVICES_FLAG",
            NULLIF(s47.OUTCOME_PROV_OF_SB_CARE_FLAG, '')       AS "OUTCOME_PROV_OF_SB_CARE_FLAG",
            NULLIF(s47.OUTCOME_CP_CONFERENCE_FLAG, '')         AS "OUTCOME_CP_CONFERENCE_FLAG",
            NULLIF(s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG, '')   AS "OUTCOME_NFA_CONTINUE_SINGLE_FLAG",
            NULLIF(s47.OUTCOME_MONITOR_FLAG, '')               AS "OUTCOME_MONITOR_FLAG",
            NULLIF(s47.OTHER_OUTCOMES_EXIST_FLAG, '')          AS "OTHER_OUTCOMES_EXIST_FLAG",
            NULLIF(s47.TOTAL_NO_OF_OUTCOMES, '')               AS "TOTAL_NO_OF_OUTCOMES",
            NULLIF(s47.OUTCOME_COMMENTS, '')                   AS "OUTCOME_COMMENTS"
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS s47e_s47_outcome_json,
    s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
    s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker
FROM 
    Child_Social.FACT_S47 AS s47;


-- Create index(es)
CREATE INDEX IDX_ssd_s47_enquiry_person_id ON ssd_s47_enquiry(s47e_person_id);

-- Create constraint(s)
ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_s47_person
FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id);


/* Removed 22/11/23
    CASE 
        WHEN cpc.FACT_S47_ID IS NOT NULL 
        THEN 'CP Plan Started'
        ELSE 'CP Plan not Required'
    END,
&     
LEFT JOIN 
    Child_Social.FACT_CP_CONFERENCE as cpc ON s47.FACT_S47_ID = cpc.FACT_S47_ID;

    */

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_initial_cp_conference
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: maping now available.... 
Dependencies: 
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/



/* 
=============================================================================
Object Name: ssd_cp_plans
Description: 
Author: D2I
Last Modified Date: 24/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [*Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Still need to add: 
cppl_cp_plan_team		y		"Link to [Child_Social].[FACT_INVOLVEMENTS.FACT_REFERRAL_ID] using [FACT_CP_PLAN.FACT_REFERRAL_ID]
WHERE [FACT_INVOLVEMENTS].[DIM_LOOKUP_INVOLVEMENT_TYPE_CODE] = 'CW'

will need to use [FACT_INVOLVEMENTS].[START_DTTM] and  [FACT_INVOLVEMENTS].[END_DTTM] to ascertain the correct worker for the date at which the report is run etc.

[FACT_INVOLVEMENTS].[FACT_WORKER_HISTORY_ID] and [FACT_INVOLVEMENTS].[FACT_WORKER_HISTORY_DEPARTMENT_DESC] will return the worker id and worker team name for the relevant Involvement
"
cppl_cp_plan_worker_id	ssd_involvements.invo_professional_id	y		"Link to [Child_Social].[FACT_INVOLVEMENTS.FACT_REFERRAL_ID] using [FACT_CP_PLAN.FACT_REFERRAL_ID]
WHERE [FACT_INVOLVEMENTS].[DIM_LOOKUP_INVOLVEMENT_TYPE_CODE] = 'CW'

will need to use [FACT_INVOLVEMENTS].[START_DTTM] and  [FACT_INVOLVEMENTS].[END_DTTM] to ascertain the correct worker for the date at which the report is run etc.

[FACT_INVOLVEMENTS].[FACT_WORKER_HISTORY_ID] and [FACT_INVOLVEMENTS].[FACT_WORKER_HISTORY_DEPARTMENT_DESC] will return the worker id and worker team name for the relevant Involvement
"


Dependencies: 
- ssd_person
- ssd_initial_cp_conference
- FACT_CP_PLAN
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_plans';
PRINT 'Creating table: ' + @TableName;




-- Check if exists & drop 
IF OBJECT_ID('ssd_cp_plans') IS NOT NULL DROP TABLE ssd_cp_plans;

-- Create structure
CREATE TABLE ssd_cp_plans (
    cppl_cp_plan_id                   NVARCHAR(48) PRIMARY KEY,
    cppl_referral_id                  NVARCHAR(48),
    cppl_initial_cp_conference_id     NVARCHAR(48),
    cppl_person_id                    NVARCHAR(48),
    cppl_cp_plan_start_date           DATETIME,
    cppl_cp_plan_end_date             DATETIME,
    cppl_cp_plan_team                 NVARCHAR(48), -- [PLACEHOLDER_DATA'] [TESTING]
    cppl_cp_plan_worker_id            NVARCHAR(48), -- [PLACEHOLDER_DATA'] [TESTING]
    cppl_cp_plan_initial_category     NVARCHAR(100),
    cppl_cp_plan_latest_category      NVARCHAR(100)
);


-- Insert data
INSERT INTO ssd_cp_plans (
    cppl_cp_plan_id, 
    cppl_referral_id, 
    cppl_initial_cp_conference_id, 
    cppl_person_id, 
    cppl_cp_plan_start_date, 
    cppl_cp_plan_end_date, 
    cppl_cp_plan_team, 
    cppl_cp_plan_worker_id, 
    cppl_cp_plan_initial_category, 
    cppl_cp_plan_latest_category
)
SELECT 
    FACT_CP_PLAN_ID AS cppl_cp_plan_id,
    FACT_REFERRAL_ID AS cppl_referral_id,
    FACT_INITIAL_CP_CONFERENCE_ID AS cppl_initial_cp_conference_id,
    DIM_PERSON_ID AS cppl_person_id,
    START_DTTM AS cppl_cp_plan_start_date,
    END_DTTM AS cppl_cp_plan_end_date,
    'PLACEHOLDER_DATA' AS cppl_cp_plan_team,                -- [PLACEHOLDER_DATA] [TESTING]
    'PLACEHOLDER_DATA' AS cppl_cp_plan_worker_id,           -- [PLACEHOLDER_DATA] [TESTING]
    INIT_CATEGORY_DESC AS cppl_cp_plan_initial_category,
    CP_CATEGORY_DESC AS cppl_cp_plan_latest_category
FROM 
    Child_Social.FACT_CP_PLAN;



-- Create index(es)


-- Create constraint(s)
ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_person_id
FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_initial_cp_conference_id
FOREIGN KEY (cppl_initial_cp_conference_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




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
Last Modified Date: 08/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: This has issues, where/what is the fk back to cp_plans? 
Dependencies: 
- FACT_CASENOTES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_visits';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cp_visits') IS NOT NULL DROP TABLE ssd_cp_visits;


-- Create structure
CREATE TABLE ssd_cp_visits (
    cppv_cp_visit_id        INT PRIMARY KEY,        -- [TESTING]  INT vs VARCHAR here? 
    cppv_casenote_id        INT,                    -- [TESTING]  INT vs VARCHAR here? 
    cppv_cp_plan_id         NVARCHAR(48),
    cppv_cp_visit_date      DATETIME,
    cppv_cp_visit_seen      NCHAR(1),
    cppv_cp_visit_seen_alone NCHAR(1),
    cppv_cp_visit_bedroom   NCHAR(1)
);
 
-- Insert data
INSERT INTO ssd_cp_visits
(
    cppv_cp_visit_id,
    cppv_casenote_id,        
    cppv_cp_plan_id,          
    cppv_cp_visit_date,      
    cppv_cp_visit_seen,      
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom  
)
 
SELECT
    cpv.FACT_CP_VISIT_ID    AS cppv_cp_visit_id,                
    cn.FACT_CASENOTE_ID     AS cppv_casenote_id,
    cpv.FACT_CP_PLAN_ID     AS cppv_cp_plan_id,  
    cn.EVENT_DTTM           AS cppv_cp_visit_date,
    cn.SEEN_FLAG            AS cppv_cp_visit_seen,
    cn.SEEN_ALONE_FLAG      AS cppv_cp_visit_seen_alone,
    cn.SEEN_BEDROOM_FLAG    AS cppv_cp_visit_bedroom
 
FROM
    Child_Social.FACT_CP_VISIT AS cpv
JOIN
    Child_Social.FACT_CASENOTES AS cn ON cpv.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
 
WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ( 'STVC','STVCPCOVID');

-- Create constraint(s)



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_cp_reviews
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [*Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks:    Some fields - ON HOLD/Not included in SSD Ver/Iteration 1
            Tested in batch 1.3. But needs additions! for cppr_cp_review_quorate - 
            FACT_FORM_ANSWERS.ANSWER
            Link using FACT_CP_REVIEW.FACT_CASE_PATHWAY_STEP_ID to FACT_CASE_PATHWAY_STEP  
            Link using FACT_CASE_PATHWAY_STEP.FACT_FORMS_ID to FACT_FORM_ANSWERS.ANSWER
            WHERE 
            ANSWER_NO = 'WasConf' AND DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'REVIEW%'
Dependencies: 
- ssd_person
- ssd_cp_plans
- FACT_CP_REVIEW
- FACT_FORM_ANSWERS
- FACT_CASE_PATHWAY_STEP
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_reviews';
PRINT 'Creating table: ' + @TableName;



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
    cppr_cp_review_quorate          NCHAR(1) DEFAULT '0',   -- ['PLACEHOLDER_DATA'][TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
    cppr_cp_review_participation    NCHAR(1) DEFAULT '0'    -- ['PLACEHOLDER_DATA'][TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
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
    '0', -- for cppr_cp_review_quorate       -- [PLACEHOLDER_DATA] [TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
    '0'  -- for cppr_cp_review_participation -- [PLACEHOLDER_DATA] [TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
FROM 
    Child_Social.FACT_CP_REVIEW as cpr

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = cpr.DIM_PERSON_ID
    );

-- Add constraint(s)
ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_cla_episodes
Description: 
Author: D2I
Last Modified Date: 08/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_involvements
- FACT_CLA
- FACT_REFERRALS
- FACT_CARE_EPISODES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if table exists, & drop
IF OBJECT_ID('ssd_cla_episodes') IS NOT NULL DROP TABLE ssd_cla_episodes;


-- Create structure
CREATE TABLE ssd_cla_episodes (
    clae_cla_episode_id             NVARCHAR(48) PRIMARY KEY,
    clae_person_id                  NVARCHAR(48),
    clae_cla_episode_start          DATETIME,
    clae_cla_episode_start_reason   NVARCHAR(100),
    clae_cla_primary_need           NVARCHAR(100),
    clae_cla_episode_ceased         DATETIME,
    clae_cla_episode_cease_reason   NVARCHAR(255),
    clae_cla_team                   NVARCHAR(48),
    clae_cla_worker_id              NVARCHAR(48),
    clae_cla_id                     NVARCHAR(48),
    clae_referral_id                NVARCHAR(48)
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
    clae_cla_team,                       
    clae_cla_worker_id,                  
    clae_cla_id, 
    clae_referral_id
)
SELECT
    fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
    fce.DIM_PERSON_ID                       AS clae_person_id,
    fce.CARE_START_DATE                     AS clae_cla_episode_start,
    fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
    fce.CIN_903_CODE                        AS clae_cla_primary_need,
    fce.CARE_END_DATE                       AS clae_cla_episode_ceased,
    fce.CARE_REASON_END_DESC                AS clae_cla_episode_cease_reason,
    fi.DIM_DEPARTMENT_ID                    AS clae_cla_team,               
    fi.DIM_WORKER_NAME                      AS clae_cla_worker_id,           
    fc.FACT_CLA_ID                          AS clae_cla_id,                    
    fc.FACT_REFERRAL_ID                     AS clae_referral_id
 
FROM
    Child_Social.FACT_CARE_EPISODES AS fce

JOIN
    Child_Social.FACT_CLA AS fc ON fce.FACT_CARE_EPISODES_ID = fc.fact_cla_id
JOIN
    Child_Social.FACT_INVOLVEMENTS AS fi ON fc.fact_referral_id = fi.fact_referral_id

 
WHERE fi.IS_ALLOCATED_CW_FLAG = 'Y';
 

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clae_cla_worker_id ON ssd_cla_episodes (clae_cla_worker_id);

-- Add constraint(s)
ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_professional 
FOREIGN KEY (clae_cla_worker_id) REFERENCES ssd_involvements (invo_professional_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_cla_convictions
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_OFFENCE
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_convictions';
PRINT 'Creating table: ' + @TableName;


-- if exists, drop
IF OBJECT_ID('ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_cla_convictions;
--IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;

-- create structure
CREATE TABLE ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,
    clac_person_id              NVARCHAR(48),
    clac_cla_conviction_date    DATETIME,
    clac_cla_conviction_offence NVARCHAR(1000)
);

-- insert data
INSERT INTO ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )
SELECT 
    fo.FACT_OFFENCE_ID,
    fo.DIM_PERSON_ID,
    fo.OFFENCE_DTTM,
    fo.DESCRIPTION
FROM 
    Child_Social.FACT_OFFENCE as fo

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fo.DIM_PERSON_ID
    );

-- add constraint(s)
ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_cla_health
Description: 
Author: D2I
Last Modified Date: 24/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_HEALTH_CHECK 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_health';
PRINT 'Creating table: ' + @TableName;



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
INSERT INTO ssd_cla_health (
    clah_health_check_id, 
    clah_person_id, 
    clah_health_check_type, 
    clah_health_check_date
    )
SELECT 
    fhc.FACT_HEALTH_CHECK_ID,
    fhc.DIM_PERSON_ID,
    fhc.DIM_LOOKUP_HC_TYPE_DESC,
    fhc.START_DTTM
FROM 
    Child_Social.FACT_HEALTH_CHECK as fhc

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fhc.DIM_PERSON_ID
    );

-- add constraint(s)
ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clah_person_id ON ssd_cla_health (clah_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_immunisations
Description: 
Author: D2I
Last Modified Date: 06/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_903_DATA
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_immunisations';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_cla_immunisations;

-- Create structure 
CREATE TABLE #ssd_cla_immunisations (
    clai_immunisations_id          NVARCHAR(48) PRIMARY KEY,
    clai_person_id                 NVARCHAR(48),
    clai_immunisations_status_date DATETIME,
    clai_immunisations_status      NCHAR(1)
);

-- Insert data
INSERT INTO #ssd_cla_immunisations (
    clai_immunisations_id,
    clai_person_id,
    clai_immunisations_status_date,
    clai_immunisations_status
)
SELECT 
    f903.FACT_903_DATA_ID,
    f903.DIM_PERSON_ID,
    '20010101', -- [PLACEHOLDER_DATA] [TESTING] in YYYYMMDD format
    f903.IMMUN_CODE
FROM 
    Child_Social.FACT_903_DATA AS f903

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = f903.DIM_PERSON_ID
);

-- add constraint(s)
ALTER TABLE ssd_cla_immunisations
ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clas_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE INDEX IX_ssd_cla_immunisations_person_id ON ssd_cla_immunisations (clai_person_id);

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_substance_misuse
Description: 
Author: D2I
Last Modified Date: 14/11/2023
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SUBSTANCE_MISUSE
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_substance_misuse';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_cla_substance_misuse;

-- Create structure 
CREATE TABLE ssd_cla_substance_misuse (
    clas_substance_misuse_id       NVARCHAR(48) PRIMARY KEY,
    clas_person_id                 NVARCHAR(48),
    clas_substance_misuse_date     DATETIME,
    clas_substance_misused         NVARCHAR(100),
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
    Child_Social.FACT_SUBSTANCE_MISUSE AS fsm

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM #ssd_person p
    WHERE p.pers_person_id = fSM.DIM_PERSON_ID
    );

-- Add constraint(s)
ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

CREATE NONCLUSTERED INDEX idx_clas_person_id ON ssd_cla_substance_misuse (clas_person_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_placement
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.9
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_CLA_PLACEMENT
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_placement';
PRINT 'Creating table: ' + @TableName;



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
    clap_cla_placement_change_reason NVARCHAR(100),
    clap_cla_id                     NVARCHAR(48)   
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
    clap_cla_placement_change_reason,
    clap_cla_id  
)
SELECT 
    fcp.FACT_CLA_PLACEMENT_ID                   AS clap_cla_placement_id,
    fce.FACT_CARE_EPISODES_ID                   AS clap_cla_episode_id,             -- [PLACEHOLDER_DATA] [TESTING]
    fcp.START_DTTM                              AS clap_cla_placement_start_date,
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE          AS clap_cla_placement_type,
    fce.OFSTED_URN                              AS clap_cla_placement_urn,
    fcp.DISTANCE_FROM_HOME                      AS clap_cla_placement_distance,
    'PLACEHOLDER_DATA'                          AS clap_cla_placement_la,           -- [PLACEHOLDER_DATA] [TESTING]
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
    fcp.POSTCODE                                AS clap_cla_placement_postcode,
    fcp.END_DTTM                                AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE          AS clap_cla_placement_change_reason,
    fcp.FACT_CLA_ID                             AS clap_cla_id  
FROM 
    Child_Social.FACT_CLA_PLACEMENT AS fcp
    
JOIN 
    Child_Social.FACT_CARE_EPISODES AS fce ON fcp.FACT_CARE_EPISODES_ID = fce.FACT_CARE_EPISODES_ID; -- Adjust with actual column name [TESTING]

-- Add constraint(s)
ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_clap_to_clae 
FOREIGN KEY (clap_cla_episode_id) REFERENCES ssd_cla_episodes(clae_cla_episode_id);

CREATE NONCLUSTERED INDEX idx_clap_cla_episode_id ON ssd_cla_substance_misuse (clap_cla_episode_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_reviews
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [*Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Still needs work on review_participation: 'FACT_FORM_ANSWERS.ANSWER
Link using FACT_CLA_REVIEW.FACT_CASE_PATHWAY_STEP_ID to FACT_CASE_PATHWAY_STEP  
Link using FACT_CASE_PATHWAY_STEP.FACT_FORMS_ID to FACT_FORM_ANSWERS.ANSWER
WHERE 'FACT_FORM_ANSWERS.DIM_ASSESSMENT_TEMPLATE_ID_DESC IN ('CLA Review Outcomes', 'LAC Outcome Record') AND FACT_FORM_ANSWERS.ANSWER_NO IN ('ChildPart', 'ICSParticipationCode')

Dependencies: 
-- ssd_cla_episodes
-- FACT_CLA_REVIEW
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_reviews';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_review', 'U') IS NOT NULL DROP TABLE ssd_cla_review;

-- Create structure
CREATE TABLE ssd_cla_review (
    clar_cla_review_id                      NVARCHAR(48) PRIMARY KEY,
    clar_cla_episode_id                     NVARCHAR(48),
    clar_cla_review_due_date                DATETIME,
    clar_cla_review_date                    DATETIME,
    clar_cla_review_participation           NVARCHAR(100),
    clar_cla_review_last_iro_contact_date   DATETIME
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
    'PLACEHOLDER_EPISODE_ID'                   AS clar_cla_episode_id,                  -- [PLACEHOLDER_DATA] [TESTING]
    fcr.DUE_DTTM                               AS clar_cla_review_due_date,
    fcr.MEETING_DTTM                           AS clar_cla_review_date,
    'PLACEHOLDER_DATA'                         AS clar_cla_review_participation,        -- [PLACEHOLDER_DATA] [TESTING]
    '01/01/2001'                               AS clar_cla_review_last_iro_contact_date -- [PLACEHOLDER_DATA] [TESTING]
FROM 
    Child_Social.FACT_CLA_REVIEW AS fcr;

-- Add constraint(s)
ALTER TABLE ssd_cla_review ADD CONSTRAINT FK_clar_to_clae 
FOREIGN KEY (clar_cla_episode_id) REFERENCES ssd_cla_episodes(clae_cla_episode_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clar_cla_episode_id ON ssd_cla_review (clar_cla_episode_id);
CREATE NONCLUSTERED INDEX idx_clar_review_last_iro_contact_date ON ssd_cla_review (clar_cla_review_last_iro_contact_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_previous_permanence
Description: 
Author: D2I
Last Modified Date: 24/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Needs further Dev work to add in:
lapp_previous_permanence_order_date		y		"Combination of'
FACT_FORM_ANSWERS.ANSWER
WHERE 
'FACT_FORM_ANSWERS.ANSWER_NO = 'ORDERYEAR'
'FACT_FORM_ANSWERS.ANSWER_NO = 'ORDERMONTH' 
'FACT_FORM_ANSWERS.ANSWER_NO = 'ORDERDATE'"
lapp_previous_permanence_option		y		"FACT_FORM_ANSWERS.ANSWER
WHERE 
'FACT_FORM_ANSWERS.ANSWER_NO = 'PREVADOPTORD'"
lapp_previous_permanence_la		y		"FACT_FORM_ANSWERS.ANSWER
WHERE 
'FACT_FORM_ANSWERS.ANSWER_NO = 'INENG'"


Dependencies: 
- ssd_person
- FACT_903_DATA
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_previous_permanence';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_previous_permanence', 'U') IS NOT NULL DROP TABLE ssd_cla_previous_permanence;

-- Create structure
CREATE TABLE ssd_cla_previous_permanence (
    lapp_table_id                         NVARCHAR(48) PRIMARY KEY,
    lapp_person_id                        NVARCHAR(48),
    lapp_previous_permanence_order_date   NVARCHAR(100),    -- [TESTING] [ESCC 48?] 
    lapp_previous_permanence_option       NVARCHAR(200),    -- [TESTING] [ESCC 128]
    lapp_previous_permanence_la           NVARCHAR(100)     -- [TESTING] [ESCC 12?]
);


-- Insert data
INSERT INTO ssd_cla_previous_permanence (
    lapp_table_id, 
    lapp_person_id, 
    lapp_previous_permanence_order_date,
    lapp_previous_permanence_option,
    lapp_previous_permanence_la
)
SELECT 
    FACT_903_DATA_ID    AS lapp_table_id,
    DIM_PERSON_ID       AS lapp_person_id,
    DATE_PERM           AS lapp_previous_permanence_order_date,
    PREV_PERM           AS lapp_previous_permanence_option,
    LA_PERM             AS lapp_previous_permanence_la
FROM 
    Child_Social.FACT_903_DATA;


-- Create index(es)
CREATE INDEX IDX_lapp_person_id ON ssd_cla_previous_permanence(lapp_person_id);

-- Add contraint(s)
ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_person(pers_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
Last Modified Date: 06/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_FORMS
- FACT_FORM_ANSWERS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_sdq_scores';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE ssd_sdq_scores;

-- Create structure
CREATE TABLE ssd_sdq_scores (
    csdq_table_id              NVARCHAR(48) PRIMARY KEY,
    csdq_person_id             NVARCHAR(48),
    csdq_sdq_completed_date    DATETIME,
    csdq_sdq_reason            NVARCHAR(100),
    csdq_sdq_score             NVARCHAR(100)
);

-- Insert data
INSERT INTO ssd_sdq_scores (
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_completed_date,
    csdq_sdq_reason,
    csdq_sdq_score
)
SELECT 
    ffa.FACT_FORM_ID AS csdq_table_id,
    ff.DIM_PERSON_ID AS csdq_person_id,
    (
        SELECT ANSWER 
        FROM Child_Social.FACT_FORM_ANSWERS
        WHERE DIM_ASSESSMENT_TEMPLATE_ID_DESC IN ('Strengths and Difficulties Questionnaire', 'Strengths and Difficulties Questionnaire (EHM)') 
        AND ANSWER_NO = 'FormEndDate'
        AND FACT_FORM_ID = ffa.FACT_FORM_ID
    ) AS csdq_sdq_completed_date,
    fd.SDQ_REASON AS csdq_sdq_reason,
    (
        SELECT ANSWER 
        FROM Child_Social.FACT_FORM_ANSWERS
        WHERE DIM_ASSESSMENT_TEMPLATE_ID_DESC IN ('Strengths and Difficulties Questionnaire', 'Strengths and Difficulties Questionnaire (EHM)') 
        AND ANSWER_NO = 'SDQScore'
        AND FACT_FORM_ID = ffa.FACT_FORM_ID
    ) AS csdq_sdq_score
FROM 
    FACT_FORM_ANSWERS ffa

JOIN Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID

LEFT JOIN Child_Social.FACT_903_DATA fd ON ff.DIM_PERSON_ID = fd.DIM_PERSON_ID;


-- Add FK constraint for csdq_person_id
ALTER TABLE ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
FOREIGN KEY (csdq_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_missing
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_MISSING_PERSON
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_missing';
PRINT 'Creating table: ' + @TableName;




-- Check if exists & drop
IF OBJECT_ID('ssd_missing', 'U') IS NOT NULL DROP TABLE ssd_missing;

-- Create structure
CREATE TABLE ssd_missing (
    miss_table_id               NVARCHAR(48) PRIMARY KEY,
    miss_la_person_id           NVARCHAR(48),
    miss_mis_epi_start          DATETIME,
    miss_mis_epi_type           NVARCHAR(100),
    miss_mis_epi_end            DATETIME,
    miss_mis_epi_rhi_offered    NVARCHAR(10),                   -- Confirm source data/why >7 required
    miss_mis_epi_rhi_accepted   NVARCHAR(10)                    -- Confirm source data/why >7 required
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
    fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
    fmp.DIM_PERSON_ID                   AS miss_la_person_id,
    fmp.START_DTTM                      AS miss_mis_epi_start,
    fmp.MISSING_STATUS                  AS miss_mis_epi_type,
    fmp.END_DTTM                        AS miss_mis_epi_end,
    fmp.RETURN_INTERVIEW_OFFERED        AS miss_mis_epi_rhi_offered,
    fmp.RETURN_INTERVIEW_ACCEPTED       AS miss_mis_epi_rhi_accepted 
FROM 
    Child_Social.FACT_MISSING_PERSON AS fmp

WHERE EXISTS ( -- only need data for ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fmp.DIM_PERSON_ID
    );

-- Add constraint(s)
ALTER TABLE ssd_missing ADD CONSTRAINT FK_missing_to_person
FOREIGN KEY (miss_la_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




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
Object Name: ssd_professionals
Description: 
Author: D2I
Last Modified Date: 24/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @LastSept30th
- DIM_WORKER
- FACT_REFERRALS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_professionals';
PRINT 'Creating table: ' + @TableName;




-- Check if exists & drop
IF OBJECT_ID('ssd_professionals', 'U') IS NOT NULL DROP TABLE ssd_professionals;

-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;

-- Create structure
CREATE TABLE ssd_professionals (
    prof_table_id                         NVARCHAR(48) PRIMARY KEY,
    prof_professional_id                  NVARCHAR(48),
    prof_social_worker_registration_no    NVARCHAR(48),
    prof_agency_worker_flag               NCHAR(1),
    prof_professional_job_title           NVARCHAR(500),
    prof_professional_caseload            INT,              -- aggr result field
    prof_professional_department          NVARCHAR(100),
    prof_full_time_equivalency            FLOAT
);



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
        (REFRL_END_DTTM IS NULL OR REFRL_END_DTTM >= @LastSept30th)
    GROUP BY 
        DIM_WORKER_ID
) AS rc ON dw.DIM_WORKER_ID = rc.DIM_WORKER_ID;



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prof_professional_id ON ssd_professionals (prof_professional_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_involvements
Description: 
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_professionals
- FACT_INVOLVEMENTS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_involvements';
PRINT 'Creating table: ' + @TableName;




-- Check if exists & drop
IF OBJECT_ID('ssd_involvements', 'U') IS NOT NULL DROP TABLE ssd_involvements;

-- Create structure
CREATE TABLE ssd_involvements (
    invo_involvements_id             NVARCHAR(48) PRIMARY KEY,
    invo_professional_id             NVARCHAR(48),
    invo_professional_role_id        NVARCHAR(200),
    invo_professional_team           NVARCHAR(200),
    invo_involvement_start_date      DATETIME,
    invo_involvement_end_date        DATETIME,
    invo_worker_change_reason        NVARCHAR(200),
    invo_referral_id                 NVARCHAR(48)
);

-- Insert data
INSERT INTO ssd_involvements (
    invo_involvements_id, 
    invo_professional_id, 
    invo_professional_role_id,
    invo_professional_team,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)
SELECT 
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    fi.DIM_WORKER_ID                              AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC        AS invo_professional_team,
    fi.START_DTTM                                 AS invo_involvement_start_date,
    fi.END_DTTM                                   AS invo_involvement_end_date,
    fi.DIM_LOOKUP_CWREASON_CODE                   AS invo_worker_change_reason,
    fi.FACT_REFERRAL_ID                           AS invo_referral_id
FROM 
    Child_Social.FACT_INVOLVEMENTS AS fi;

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_invo_professional_id ON ssd_involvements (invo_professional_id);

-- Add constraint(s)
ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional 
FOREIGN KEY (invo_professional_id) REFERENCES ssd_professionals (prof_professional_id);

ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional_role 
FOREIGN KEY (invo_professional_role_id) REFERENCES ssd_professionals (prof_social_worker_registration_no);


    

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_linked_identifiers
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_linked_identifiers';
PRINT 'Creating table: ' + @TableName;



-- Check if exists, & drop 
IF OBJECT_ID('ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE ssd_linked_identifiers;

-- Create structure
CREATE TABLE ssd_linked_identifiers (
    link_link_id NVARCHAR(48) PRIMARY KEY, 
    link_person_id NVARCHAR(48), 
    link_identifier_type NVARCHAR(100),
    link_identifier_value NVARCHAR(100),
    link_valid_from_date DATETIME,
    link_valid_to_date DATETIME
);

-- Insert placeholder data [TESTING]
INSERT INTO ssd_linked_identifiers (
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
-- WHERE EXISTS ( -- only need data for ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = ssd_linked_identifiers.DIM_PERSON_ID
--     );

-- Create constraint(s)
ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* Start 

        SSDF Other projects elements extracts 
        
        */



/* 
=============================================================================
Object Name: ssd_s251_finance
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_s251_finance';
PRINT 'Creating table: ' + @TableName;




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

-- Insert placeholder data [TESTING]
INSERT INTO ssd_s251_finance (
    s251_id,
    s251_cla_placement_id,
    s251_placeholder_1,
    s251_placeholder_2,
    s251_placeholder_3,
    s251_placeholder_4
)
VALUES
    ('PLACEHOLDER_DATA_ID', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA', 'PLACEHOLDER_DATA');

-- Create constraint(s)
ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_voice_of_child
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 16/11/23
DB Compatibility: SQL Server 2014+|...
Version: 1.3
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_voice_of_child';
PRINT 'Creating table: ' + @TableName;



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

-- Insert placeholder data [TESTING]
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
-- WHERE EXISTS ( -- only need data for ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = ssd_voice_of_child.DIM_PERSON_ID
--     );

-- Create constraint(s)
ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_pre_proceedings
Description: Currently only with placeholder structure as source data not yet conformed
Author: D2I
Last Modified Date: 02/11/23
DB Compatibility: SQL Server 2014+|...
Version: 0.1
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- Yet to be defined
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_pre_proceedings';
PRINT 'Creating table: ' + @TableName;




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
INSERT INTO ssd_pre_proceedings (
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
-- WHERE EXISTS ( -- only need data for ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = ssd_pre_proceedings.DIM_PERSON_ID
--     );

-- Create constraint(s)
ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prep_person_id ON ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_prep_pre_pro_decision_date ON ssd_pre_proceedings (prep_pre_pro_decision_date);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* End

        SSDF Other projects elements extracts 
        
        */








/* Start 

        Non-Core Liquid Logic elements extracts (E.g. SEND/EH Module data)
        
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
Object Name: ssd_send
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: SQL Server 2014+|...
Version: 0.9
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_903_DATA
- ssd_person
- Education.DIM_PERSON
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_send';
PRINT 'Creating table: ' + @TableName;



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
    f903.FACT_903_DATA_ID   AS send_table_id,
    f903.DIM_PERSON_ID      AS send_person_id,      -- [TESTING]
    f903.FACT_903_DATA_ID   AS send_upn,
    p.ULN                   AS send_uln,
    f903.NO_UPN_CODE        AS upn_unknown

FROM 
    Child_Social.FACT_903_DATA AS f903

LEFT JOIN 
    Education.DIM_PERSON AS p ON f903.DIM_PERSON_ID = p.DIM_PERSON_ID;

-- Add constraint(s)
ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);

/* ?? Should this actually be pulling from Child_Social.FACT_SENRECORD.DIM_PERSON_ID | Child_Social.FACT_SEN.DIM_PERSON_ID
*/



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* End

        Non-Core Liquid Logic elements extracts 
        
        */






/* ********************************************************************************************************** */
/* Development clean up */

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */

