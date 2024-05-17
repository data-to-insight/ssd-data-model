
/*
STANDARD SAFEGUARDING DATASET EXTRACT 

Script creates labelled persistent(unless set otherwise) tables in your existing|specified database. 
There is no data sharing, and no changes to your existing systems are required. Data tables(with data copied 
from the raw CMS tables) and indexes for the SSD are created, and therefore in some cases will need support 
and/or agreement from either your IT or Intelligence team. The SQL script is always non-destructive, i.e. it 
does nothing to your existing data/tables/anything - the SSD process is simply a series of SELECT statements, 
pulling copied data into a new standardised field and table structure on your own system for access by only 
you/your LA.
*/


/* **********************************************************************************************************

Notes: 
This version of the SSD script creates persistant _perm tables. A version that instead creates _temp|session 
tables is also available to enable those restricted to read access on the cms db|schema.   

There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results; similarly some test related 
console outputs remain to aid such as run-time problem solving. These [TESTING] blocks can/will be removed. 

/*
Dev Objact & Item Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [AR]waitingReview,   -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder
*/

Development notes:
Currently in [REVIEW]
- DfE returns expect dd/mm/YYYY formating on dates, SSD Extract initially maintains DATETIME not DATE.
- Extended default field sizes - Some are exagerated e.g. family_id NVARCHAR(48), to ensure cms/la compatibility
- Caseload counts - should these be restricted to SSD timeframe counts(currently this) or full system counts?
********************************************************************************************************** */

/* Development set up */

-- Point to correct DB



/* [TESTING] 
Set up (to be removed from live v2+)
*/
DECLARE @TestProgress INT = 0;
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder';

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time
/* END [TESTING] 
*/


/* ********************************************************************************************************** */
/* SSD extract set up */

-- ssd extract time-frame (YRS)
DECLARE @ssd_timeframe_years INT = 6;
DECLARE @ssd_sub1_range_years INT = 1;

-- store date on which CASELOAD count required. Currently : Most recent past Sept30th
DECLARE @LastSept30th DATE; 



/*
=============================================================================
Object Name: ssd_person
Description: Person/child details. This the most connected table in the SSD.
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks:    
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_person';
PRINT 'Creating table: ' + @TableName;


-- check exists & drop
IF OBJECT_ID('ssd_person') IS NOT NULL DROP TABLE ssd_person;
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;


-- Create structure
CREATE TABLE ssd_development.ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- metadata={"item_ref":"PERS014A"}               
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERS001A"}   
    pers_sex                NVARCHAR(20),               -- metadata={"item_ref":"PERS002A"} 
    pers_gender             NVARCHAR(10),               -- metadata={"item_ref":"PERS003A"}   -- ["unknown",NULL, F, U, M, I] [REVIEW][TESTING]        
    pers_ethnicity          NVARCHAR(48),               -- metadata={"item_ref":"PERS004A"} 
    pers_dob                DATETIME,                   -- metadata={"item_ref":"PERS005A"} 
    pers_common_child_id    NVARCHAR(48),               -- metadata={"item_ref":"PERS013A", "item_status":"P"}                  
    pers_upn_unknown        NVARCHAR(6),                -- metadata={"item_ref":"PERS007A"}    -- SEN2 guidance suggests size(4) UN1-10                            
    pers_send_flag          NCHAR(5),                   -- metadata={"item_ref":"PERS008A"} 
    pers_expected_dob       DATETIME,                   -- metadata={"item_ref":"PERS009A"}                  
    pers_death_date         DATETIME,                   -- metadata={"item_ref":"PERS010A"} 
    pers_is_mother          NCHAR(1),                   -- metadata={"item_ref":"PERS011A"}
    pers_nationality        NVARCHAR(48)                -- metadata={"item_ref":"PERS012A"} 
);
 
-- Insert data
INSERT INTO ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,
    pers_gender,
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,                               -- [PLACEHOLDER] [Takes NHS Number]
    pers_upn_unknown,                                   -- [PLACEHOLDER] 
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality
)



-- EXTRACT SELECT



-- Left in for reference
-- WHERE                                                       -- Filter invalid rows
-- --

-- AND (                                                       -- Filter irrelevant rows by timeframe
--     EXISTS (
--         -- contact in last x@yrs (@ssd_timeframe_years)
--     )
--     OR EXISTS (
--         -- new or ongoing/active/unclosed referral in last x@yrs (@ssd_timeframe_years)
--     )
--     OR EXISTS (
--         -- care leaver contact in last x@yrs (@ssd_timeframe_years)
--     )
--     OR EXISTS (
--         -- care leaver eligibility exists
--     )
-- );

 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_dob               ON ssd_person(pers_dob);
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_common_child_id   ON ssd_person(pers_common_child_id);
CREATE NONCLUSTERED INDEX idx_ssd_person_ethnicity_gender       ON ssd_person(pers_ethnicity, pers_gender);



/*SSD Person filter notes: - To implement*/
-- [done]contact in last 6yrs - Child_Social.FACT_CONTACTS.CONTACT_DTTM - -- might have only contact, not yet RFRL 
-- [done] has open referral - FACT_REFERRALS.REFRL_START_DTTM or doesn't closed date or a closed date within last 6yrs
-- [picked up within the referral] active plan or has been active in 6yrs 

/*SSD Person filter (notes): - ON HOLD/Not included in SSD Ver/Iteration 1*/
--1
-- ehcp request in last x@yrs

--2 (Uncertainty re access EH)
-- Has eh_referral open in last 6yrs - 

--3 (Uncertainty re access SEN)
-- Has a record in send  ? 




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_family
Description: Contains the family connections for each person
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks:    
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_family';
PRINT 'Creating table: ' + @TableName;


-- check exists & drop
IF OBJECT_ID('ssd_family') IS NOT NULL DROP TABLE ssd_family;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;


-- Create structure
CREATE TABLE ssd_development.ssd_family (
    fami_table_id   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"FAMI003A"} 
    fami_family_id  NVARCHAR(48),               -- metadata={"item_ref":"FAMI001A"}
    fami_person_id  NVARCHAR(48)                -- metadata={"item_ref":"FAMI002A"}
);
-- Insert data 
INSERT INTO ssd_family (
    fami_table_id, 
    fami_family_id, 
    fami_person_id
    )




-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )



-- -- Create constraint(s)
-- ALTER TABLE ssd_family ADD CONSTRAINT FK_family_person
-- FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);

-- DEV NOTES [TESTING]
-- Msg 3728, Level 16, State 1, Line 1
-- 'FK_family_person' is not a constraint.Could not drop constraint. See previous errors.


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_family_person_id              ON ssd_family(fami_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_family_fami_family_id     ON ssd_family(fami_family_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_address
Description: Contains full address details for every person 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: addr_address_json - see spec for needed json key:values    
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_address';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_address') IS NOT NULL DROP TABLE ssd_address;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;


-- Create structure
CREATE TABLE ssd_development.ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"ADDR007A"}
    addr_person_id          NVARCHAR(48),               -- metadata={"item_ref":"ADDR002A"} 
    addr_address_type       NVARCHAR(48),               -- metadata={"item_ref":"ADDR003A"}
    addr_address_start_date DATETIME,                   -- metadata={"item_ref":"ADDR004A"}
    addr_address_end_date   DATETIME,                   -- metadata={"item_ref":"ADDR005A"}
    addr_address_postcode   NVARCHAR(15),               -- metadata={"item_ref":"ADDR006A"}
    addr_address_json       NVARCHAR(1000)              -- metadata={"item_ref":"ADDR001A"}
);


-- insert data
INSERT INTO ssd_address (
    addr_table_id, 
    addr_person_id, 
    addr_address_type, 
    addr_address_start_date, 
    addr_address_end_date, 
    addr_address_postcode, 
    addr_address_json
)




-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )

-- Create constraint(s)
ALTER TABLE ssd_address ADD CONSTRAINT FK_address_person
FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_address_person        ON ssd_address(addr_person_id);
CREATE NONCLUSTERED INDEX idx_address_start         ON ssd_address(addr_address_start_date);
CREATE NONCLUSTERED INDEX idx_address_end           ON ssd_address(addr_address_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_address_postcode  ON ssd_address(addr_address_postcode);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_disability
Description: Contains the Y/N flag for persons with disability
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks:  
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_disability';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_disability') IS NOT NULL DROP TABLE ssd_disability;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

-- Create the structure
CREATE TABLE ssd_development.ssd_disability
(
    disa_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"DISA003A"}
    disa_person_id          NVARCHAR(48) NOT NULL,      -- metadata={"item_ref":"DISA001A"}
    disa_disability_code    NVARCHAR(48) NOT NULL       -- metadata={"item_ref":"DISA002A"}
);


-- Insert data
INSERT INTO ssd_disability (
    disa_table_id,  
    disa_person_id, 
    disa_disability_code
)



-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- Create constraint(s)
ALTER TABLE ssd_disability ADD CONSTRAINT FK_disability_person 
FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id);
    
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_disability_person_id ON ssd_disability(disa_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_disability_code ON ssd_disability(disa_disability_code);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_immigration_status (UASC)
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_immigration_status';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_immigration_status') IS NOT NULL DROP TABLE ssd_immigration_status;
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;


-- Create structure
CREATE TABLE ssd_development.ssd_immigration_status (
    immi_immigration_status_id          NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"IMMI005A"}
    immi_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"IMMI001A"}
    immi_immigration_status_start_date  DATETIME,                   -- metadata={"item_ref":"IMMI003A"}
    immi_immigration_status_end_date    DATETIME,                   -- metadata={"item_ref":"IMMI004A"}
    immi_immigration_status             NVARCHAR(100)               -- metadata={"item_ref":"IMMI002A"}
);
 
 
-- insert data
INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)



-- EXTRACT SELECT


 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )

-- Create constraint(s)
ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id);
CREATE NONCLUSTERED INDEX idx_immigration_status_start ON ssd_immigration_status(immi_immigration_status_start_date);
CREATE NONCLUSTERED INDEX idx_immigration_status_end ON ssd_immigration_status(immi_immigration_status_end_date);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_mother
Description: Contains parent-child relations between mother-child 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks:   
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_mother';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_mother', 'U') IS NOT NULL DROP TABLE ssd_mother;
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;


-- Create structure
CREATE TABLE ssd_development.ssd_mother (
    moth_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
);
 
-- Insert data
INSERT INTO ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)

 
-- EXTRACT EXTRACT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 
-- Add constraint(s)
ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

-- ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
-- FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_mother ADD CONSTRAINT CHK_NoSelfParenting -- Ensure person cannot be their own mother
CHECK (moth_person_id <> moth_childs_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_mother_moth_person_id ON ssd_mother(moth_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_person_id ON ssd_mother(moth_childs_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_mother_childs_dob ON ssd_mother(moth_childs_dob);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_legal_status
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_legal_status';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_legal_status') IS NOT NULL DROP TABLE ssd_legal_status;
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- Create structure
CREATE TABLE ssd_development.ssd_legal_status (
    lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LEGA001A"}
    lega_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LEGA002A"}
    lega_legal_status               NVARCHAR(100),              -- metadata={"item_ref":"LEGA003A"}
    lega_legal_status_start_date    DATETIME,                   -- metadata={"item_ref":"LEGA004A"}
    lega_legal_status_end_date      DATETIME                    -- metadata={"item_ref":"LEGA005A"}
);
 
-- Insert data
INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)



-- EXTRACT SELECT 



-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 
-- Create constraint(s)
ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_legal_status_person
FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_lega_person_id ON ssd_legal_status(lega_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status ON ssd_legal_status(lega_legal_status);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_start ON ssd_legal_status(lega_legal_status_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_legal_status_end ON ssd_legal_status(lega_legal_status_end_date);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_contacts
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_contact';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_contacts') IS NOT NULL DROP TABLE ssd_contacts;
IF OBJECT_ID('tempdb..#ssd_contacts') IS NOT NULL DROP TABLE #ssd_contacts;


-- Create structure
CREATE TABLE ssd_development.ssd_contacts (
    cont_contact_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CONT001A"}
    cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
    cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
    cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
    cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
    cont_contact_outcome_json       NVARCHAR(500)               -- metadata={"item_ref":"CONT005A"}
);

-- Insert data
INSERT INTO ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)


-- EXTRACT SELECT 

    
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- Create constraint(s)
ALTER TABLE ssd_contacts ADD CONSTRAINT FK_contact_person 
FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_contact_person_id ON ssd_contacts(cont_person_id);
CREATE NONCLUSTERED INDEX idx_contact_date ON ssd_contacts(cont_contact_date);
CREATE NONCLUSTERED INDEX idx_contact_source_code ON ssd_contacts(cont_contact_source_code);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_early_help_episodes
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_early_help_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_early_help_episodes') IS NOT NULL DROP TABLE ssd_early_help_episodes;
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;


-- Create structure
CREATE TABLE ssd_development.ssd_early_help_episodes (
    earl_episode_id             NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EARL001A"}
    earl_person_id              NVARCHAR(48),               -- metadata={"item_ref":"EARL002A"}
    earl_episode_start_date     DATETIME,                   -- metadata={"item_ref":"EARL003A"}
    earl_episode_end_date       DATETIME,                   -- metadata={"item_ref":"EARL004A"}
    earl_episode_reason         NVARCHAR(MAX),              -- metadata={"item_ref":"EARL005A"}
    earl_episode_end_reason     NVARCHAR(MAX),              -- metadata={"item_ref":"EARL006A"}
    earl_episode_organisation   NVARCHAR(MAX),              -- metadata={"item_ref":"EARL007A"}
    earl_episode_worker_name    NVARCHAR(100)               -- metadata={"item_ref":"EARL008A"}
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
    earl_episode_worker_name                    
)
 

-- EXTRACT SELECT 

 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- Create constraint(s)
ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);

 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_early_help_episodes_person_id ON ssd_early_help_episodes(earl_person_id);
CREATE NONCLUSTERED INDEX idx_early_help_start_date ON ssd_early_help_episodes(earl_episode_start_date);
CREATE NONCLUSTERED INDEX idx_early_help_end_date ON ssd_early_help_episodes(earl_episode_end_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cin_episodes') IS NOT NULL DROP TABLE ssd_cin_episodes;
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- Create structure
CREATE TABLE ssd_development.ssd_cin_episodes
(
    cine_referral_id                INT,            -- metadata={"item_ref":"CINE001A"}
    cine_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CINE002A"}
    cine_referral_date              DATETIME,       -- metadata={"item_ref":"CINE003A"}
    cine_cin_primary_need           NVARCHAR(3),    -- metadata={"item_ref":"CINE010A"} -- codes N0-9
    cine_referral_source_code       NVARCHAR(48),   -- metadata={"item_ref":"CINE004A"}  
    cine_referral_source_desc       NVARCHAR(255),  -- metadata={"item_ref":"CINE012A"}
    cine_referral_outcome_json      NVARCHAR(500),  -- metadata={"item_ref":"CINE005A"}
    cine_referral_nfa               NCHAR(1),       -- metadata={"item_ref":"CINE011A"}
    cine_close_reason               NVARCHAR(100),  -- metadata={"item_ref":"CINE006A"}
    cine_close_date                 DATETIME,       -- metadata={"item_ref":"CINE007A"}
    cine_referral_team_name         NVARCHAR(255),  -- metadata={"item_ref":"CINE008A"}
    cine_referral_worker_name       NVARCHAR(100),  -- metadata={"item_ref":"CINE009A"}
);
 
-- Insert data
INSERT INTO ssd_cin_episodes
(
    cine_referral_id,
    cine_person_id,
    cine_referral_date,
    cine_cin_primary_need,
    cine_referral_source_code,
    cine_referral_source_desc,
    cine_referral_outcome_json,
    cine_referral_nfa,
    cine_close_reason,
    cine_close_date,
    cine_referral_team_name,
    cine_referral_worker_name
)



-- EXTRACT SELECT 


 
-- WHERE REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())



-- -- Create constraint(s)
-- ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
-- FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_episodes_person_id    ON ssd_cin_episodes(cine_person_id);
CREATE NONCLUSTERED INDEX idx_cin_referral_date             ON ssd_cin_episodes(cine_referral_date);
CREATE NONCLUSTERED INDEX idx_cin_close_date                ON ssd_cin_episodes(cine_close_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cin_assessments
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_assessments';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop 
IF OBJECT_ID('ssd_cin_assessments') IS NOT NULL DROP TABLE ssd_cin_assessments;
IF OBJECT_ID('tempdb..#ssd_cin_assessments') IS NOT NULL DROP TABLE #ssd_cin_assessments;


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
    cina_assessment_team_name       NVARCHAR(255),              -- metadata={"item_ref":"CINA007A"}
    cina_assessment_worker_name     NVARCHAR(100)               -- metadata={"item_ref":"CINA008A"}
);


 
-- Insert data
INSERT INTO ssd_cin_assessments
(
    cina_assessment_id,
    cina_person_id,
    cina_referral_id,
    cina_assessment_start_date,
    cina_assessment_child_seen,
    cina_assessment_auth_date,      
    cina_assessment_outcome_json,
    cina_assessment_outcome_nfa,
    cina_assessment_team_name,
    cina_assessment_worker_name
)



-- EXTRACT SELECT 


 --Exclude draft and cancelled assessments
 

-- Create constraint(s)
ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_assessments_person_id ON ssd_cin_assessments(cina_person_id);
CREATE NONCLUSTERED INDEX idx_cina_assessment_start_date ON ssd_cin_assessments(cina_assessment_start_date);
CREATE NONCLUSTERED INDEX idx_cina_assessment_auth_date ON ssd_cin_assessments(cina_assessment_auth_date);
CREATE NONCLUSTERED INDEX idx_cina_referral_id ON ssd_cin_assessments(cina_referral_id);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_assessment_factors
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
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
IF OBJECT_ID('tempdb..#ssd_assessment_factors') IS NOT NULL DROP TABLE #ssd_assessment_factors;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;




-- Create structure
CREATE TABLE ssd_development.ssd_assessment_factors (
    cinf_table_id                   NVARCHAR(48) PRIMARY KEY,       -- metadata={"item_ref":"CINF003A"}
    cinf_assessment_id              NVARCHAR(48),                   -- metadata={"item_ref":"CINF001A"}
    cinf_assessment_factors_json    NVARCHAR(1000)                  -- metadata={"item_ref":"CINF002A"}
);

-- Insert data
INSERT INTO ssd_assessment_factors (
               cinf_table_id, 
               cinf_assessment_id, 
               cinf_assessment_factors_json
           )



-- EXTRACT SELECT




-- -- Add constraint(s)
-- ALTER TABLE ssd_assessment_factors ADD CONSTRAINT FK_cinf_assessment_id
-- FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_cin_assessments(cina_assessment_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_cinf_assessment_id ON ssd_assessment_factors(cinf_assessment_id);


-- Drop tmp/pre-processing structure(s)
IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors') IS NOT NULL DROP TABLE #ssd_TMP_PRE_assessment_factors;




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cin_plans
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_plans';
PRINT 'Creating table: ' + @TableName;

-- Check if exists & drop
IF OBJECT_ID('ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_cin_plans;
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;


-- Create structure
CREATE TABLE ssd_development.ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINP001A"}
    cinp_referral_id            NVARCHAR(48),               -- metadata={"item_ref":"CINP007A"}
    cinp_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINP002A"}
    cinp_cin_plan_start_date    DATETIME,                   -- metadata={"item_ref":"CINP003A"}
    cinp_cin_plan_end_date      DATETIME,                   -- metadata={"item_ref":"CINP004A"}
    cinp_cin_plan_team_name     NVARCHAR(255),              -- metadata={"item_ref":"CINP005A"}
    cinp_cin_plan_worker_name   NVARCHAR(100),              -- metadata={"item_ref":"CINP006A"}
);
 
-- Insert data
INSERT INTO ssd_cin_plans (
    cinp_cin_plan_id,
    cinp_referral_id,
    cinp_person_id,
    cinp_cin_plan_start_date,
    cinp_cin_plan_end_date,
    cinp_cin_plan_team_name,
    cinp_cin_plan_worker_name
)



-- EXTRACT SELECT

 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 


-- Create constraint(s)
ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cin_plans_person_id ON ssd_cin_plans(cinp_person_id);
CREATE NONCLUSTERED INDEX idx_cinp_cin_plan_start_date ON ssd_cin_plans(cinp_cin_plan_start_date);
CREATE NONCLUSTERED INDEX idx_cinp_cin_plan_end_date ON ssd_cin_plans(cinp_cin_plan_end_date);
CREATE NONCLUSTERED INDEX idx_cinp_referral_id ON ssd_cin_plans(cinp_referral_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cin_visits
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_visits';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists, & drop
IF OBJECT_ID('ssd_cin_visits') IS NOT NULL DROP TABLE ssd_cin_visits;
IF OBJECT_ID('tempdb..#ssd_cin_visits') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
-- Create structure
CREATE TABLE ssd_development.ssd_cin_visits
(
    cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CINV001A"}      
    cinv_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CINV007A"}
    cinv_cin_visit_date         DATETIME,                   -- metadata={"item_ref":"CINV003A"}
    cinv_cin_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CINV004A"}
    cinv_cin_visit_seen_alone   NCHAR(1),                   -- metadata={"item_ref":"CINV005A"}
    cinv_cin_visit_bedroom      NCHAR(1)                    -- metadata={"item_ref":"CINV006A"}
);
 
-- Insert data
INSERT INTO ssd_cin_visits
(
    cinv_cin_visit_id,                  
    cinv_person_id,
    cinv_cin_visit_date,
    cinv_cin_visit_seen,
    cinv_cin_visit_seen_alone,
    cinv_cin_visit_bedroom
)


-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 


-- Create constraint(s)
ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
FOREIGN KEY (cinv_person_id) REFERENCES ssd_person(pers_person_id);
 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_cinv_person_id ON ssd_cin_visits(cinv_person_id);
CREATE NONCLUSTERED INDEX idx_cinv_cin_visit_date ON ssd_cin_visits(cinv_cin_visit_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_s47_enquiry
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: Check spec for s47_outcome_json key:value structure
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_s47_enquiry';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_s47_enquiry') IS NOT NULL DROP TABLE ssd_s47_enquiry;
IF OBJECT_ID('tempdb..#ssd_s47_enquiry') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

-- Create structure 
CREATE TABLE ssd_development.ssd_s47_enquiry (
    s47e_s47_enquiry_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S47E001A"}
    s47e_referral_id                    NVARCHAR(48),               -- metadata={"item_ref":"S47E010A"}
    s47e_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"S47E002A"}
    s47e_s47_start_date                 DATETIME,                   -- metadata={"item_ref":"S47E004A"}
    s47e_s47_end_date                   DATETIME,                   -- metadata={"item_ref":"S47E005A"}
    s47e_s47_nfa                        NCHAR(1),                   -- metadata={"item_ref":"S47E006A"}
    s47e_s47_outcome_json               NVARCHAR(1000),             -- metadata={"item_ref":"S47E007A"}
    s47e_s47_completed_by_team_name     NVARCHAR(255),              -- metadata={"item_ref":"S47E009A"}
    s47e_s47_completed_by_worker_name   NVARCHAR(100),              -- metadata={"item_ref":"S47E008A"}
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
    s47e_s47_completed_by_team_name,
    s47e_s47_completed_by_worker_name
)



-- EXTRACT SELECT



-- -- Create constraint(s)
-- ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_s47_person
-- FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_person_id     ON ssd_s47_enquiry(s47e_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_start_date    ON ssd_s47_enquiry(s47e_s47_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_end_date      ON ssd_s47_enquiry(s47e_s47_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_referral_id   ON ssd_s47_enquiry(s47e_referral_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_initial_cp_conference
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: Check spec for icpc_outcome_json key:value structure
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_initial_cp_conference';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_initial_cp_conference') IS NOT NULL DROP TABLE ssd_initial_cp_conference;
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;
 

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
    icpc_icpc_team_name         NVARCHAR(255),              -- metadata={"item_ref":"ICPC007A"}
    icpc_icpc_worker_name       NVARCHAR(100),              -- metadata={"item_ref":"ICPC008A"}
);
 
 
-- insert data
INSERT INTO ssd_initial_cp_conference(
    icpc_icpc_id,
    icpc_icpc_meeting_id,
    icpc_s47_enquiry_id,
    icpc_person_id,
    icpc_cp_plan_id,
    icpc_referral_id,
    icpc_icpc_transfer_in,
    icpc_icpc_target_date,
    icpc_icpc_date,
    icpc_icpc_outcome_cp_flag,
    icpc_icpc_outcome_json,
    icpc_icpc_team_name,
    icpc_icpc_worker_name
)
 


-- EXTRACT SELECT
 
-- WHERE
--     MTG_TYPE_ID_CODE = 'CPConference'


-- -- Create constraint(s)
-- ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_s47_enquiry_id
-- FOREIGN KEY (icpc_s47_enquiry_id) REFERENCES ssd_s47_enquiry(s47e_s47_enquiry_id);

-- ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_person_id
-- FOREIGN KEY (icpc_person_id) REFERENCES ssd_person(pers_person_id);

-- ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_referral_id
-- FOREIGN KEY (icpc_referral_id) REFERENCES ssd_cin_episodes(cine_referral_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_icpc_person_id        ON ssd_initial_cp_conference(icpc_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_s47_enquiry_id   ON ssd_initial_cp_conference(icpc_s47_enquiry_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_referral_id      ON ssd_initial_cp_conference(icpc_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_icpc_icpc_date        ON ssd_initial_cp_conference(icpc_icpc_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cp_plans
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/

-- [TESTING] Create marker
SET @TableName = N'ssd_cp_plans';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop 
IF OBJECT_ID('ssd_cp_plans') IS NOT NULL DROP TABLE ssd_cp_plans;
IF OBJECT_ID('tempdb..#ssd_cp_plans') IS NOT NULL DROP TABLE #ssd_cp_plans;

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
 
 
-- Insert data
INSERT INTO ssd_cp_plans (
    cppl_cp_plan_id,
    cppl_referral_id,
    cppl_icpc_id,
    cppl_person_id,
    cppl_cp_plan_start_date,
    cppl_cp_plan_end_date,
    cppl_cp_plan_ola,
    cppl_cp_plan_initial_category,
    cppl_cp_plan_latest_category
)


-- EXTRACT SELECT

 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- -- Create constraint(s)
-- ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_person_id
-- FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id);

-- ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_icpc_id
-- FOREIGN KEY (cppl_icpc_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_person_id ON ssd_cp_plans(cppl_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_icpc_id ON ssd_cp_plans(cppl_icpc_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_referral_id ON ssd_cp_plans(cppl_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_start_date ON ssd_cp_plans(cppl_cp_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_cp_plans_end_date ON ssd_cp_plans(cppl_cp_plan_end_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/*
=============================================================================
Object Name: ssd_cp_visits
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_visits';
PRINT 'Creating table: ' + @TableName;
 
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cp_visits') IS NOT NULL DROP TABLE ssd_cp_visits;
IF OBJECT_ID('tempdb..#ssd_cp_visits') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
 
-- Create structure
CREATE TABLE ssd_development.ssd_cp_visits (
    cppv_cp_visit_id                NVARCHAR(48),   -- metadata={"item_ref":"CPPV007A"} PRIMARY KEY,
    cppv_person_id                  NVARCHAR(48),   -- metadata={"item_ref":"CPPV008A"}
    cppv_cp_plan_id                 NVARCHAR(48),   -- metadata={"item_ref":"CPPV001A"}
    cppv_cp_visit_date              DATETIME,       -- metadata={"item_ref":"CPPV003A"}
    cppv_cp_visit_seen              NCHAR(1),       -- metadata={"item_ref":"CPPV004A"}
    cppv_cp_visit_seen_alone        NCHAR(1),       -- metadata={"item_ref":"CPPV005A"}
    cppv_cp_visit_bedroom           NCHAR(1)        -- metadata={"item_ref":"CPPV006A"}
);
 
-- Insert data
INSERT INTO ssd_cp_visits
(
    cppv_cp_visit_id,
    cppv_person_id,
    cppv_cp_plan_id,        
    cppv_cp_visit_date,      
    cppv_cp_visit_seen,      
    cppv_cp_visit_seen_alone,
    cppv_cp_visit_bedroom  
)
 


-- EXTRACT SELECT

 
-- WHERE CASNT_TYPE_ID_CODE IN ('STVC'); -- Ref. ( 'STVC','STVCPCOVID')



-- -- Create constraint(s)
-- ALTER TABLE ssd_cp_visits ADD CONSTRAINT FK_cppv_to_cppl
-- FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cppv_person_id        ON ssd_cp_visits(cppv_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_plan_id       ON ssd_cp_visits(cppv_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppv_cp_visit_date    ON ssd_cp_visits(cppv_cp_visit_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/*
=============================================================================
Object Name: ssd_cp_reviews
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_reviews';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if table exists, & drop
IF OBJECT_ID('ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_cp_reviews;
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
 
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
    cppr_cp_review_participation        NVARCHAR(100)               -- metadata={"item_ref":"CPPR007A", "item_status":"P"}
);
 
-- Insert data
INSERT INTO ssd_cp_reviews
(
    cppr_cp_review_id,
    cppr_cp_plan_id,
    cppr_person_id,
    cppr_cp_review_due,
    cppr_cp_review_date,
    cppr_cp_review_meeting_id,
    cppr_cp_review_outcome_continue_cp,
    cppr_cp_review_quorate,
    cppr_cp_review_participation
)


-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )

-- -- Add constraint(s)
-- ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
-- FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_cppr_person_id ON ssd_cp_reviews(cppr_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_plan_id ON ssd_cp_reviews(cppr_cp_plan_id);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_due ON ssd_cp_reviews(cppr_cp_review_due);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_date ON ssd_cp_reviews(cppr_cp_review_date);
CREATE NONCLUSTERED INDEX idx_ssd_cppr_cp_review_meeting_id ON ssd_cp_reviews(cppr_cp_review_meeting_id);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cla_episodes
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if table exists, & drop
IF OBJECT_ID('ssd_cla_episodes') IS NOT NULL DROP TABLE ssd_cla_episodes;
IF OBJECT_ID('tempdb..#ssd_cla_episodes') IS NOT NULL DROP TABLE #ssd_cla_episodes;

 
-- Create structure
CREATE TABLE ssd_development.ssd_cla_episodes (
    clae_cla_episode_id             NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAE001A"}
    clae_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAE002A"}
    clae_cla_placement_id           NVARCHAR(48),               -- metadata={"item_ref":"CLAE013A"} 
    clae_cla_episode_start_date     DATETIME,                   -- metadata={"item_ref":"CLAE003A"}
    clae_cla_episode_start_reason   NVARCHAR(100),              -- metadata={"item_ref":"CLAE004A"}
    clae_cla_primary_need           NVARCHAR(3),              ``-- metadata={"item_ref":"CLAE009A", "expected_data":"N0-N9"} 
    clae_cla_episode_ceased         DATETIME,                   -- metadata={"item_ref":"CLAE005A"}
    clae_cla_episode_ceased_reason  NVARCHAR(255),              -- metadata={"item_ref":"CLAE006A"}
    clae_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAE010A"}
    clae_referral_id                NVARCHAR(48),               -- metadata={"item_ref":"CLAE011A"}
    clae_cla_last_iro_contact_date  DATETIME,                   -- metadata={"item_ref":"CLAE012A"} 
    clae_entered_care_date          DATETIME                    -- metadata={"item_ref":"CLAE014A", "item_status":"T"}
);
 
-- Insert data
INSERT INTO ssd_cla_episodes (
    clae_cla_episode_id,
    clae_person_id,
    clae_cla_placement_id,
    clae_cla_episode_start_date,
    clae_cla_episode_start_reason,
    clae_cla_primary_need,
    clae_cla_episode_ceased,
    clae_cla_episode_ceased_reason,
    clae_cla_id,
    clae_referral_id,
    clae_cla_last_iro_contact_date,
    clae_entered_care_date 
)


-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 


-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_person 
-- FOREIGN KEY (clae_person_id) REFERENCES ssd_person (pers_person_id);

-- ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_cla_placement_id
-- FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_cla_placements (clap_cla_placement_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_clae_person_id ON ssd_cla_episodes(clae_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_start_date ON ssd_cla_episodes(clae_cla_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clae_episode_ceased ON ssd_cla_episodes(clae_cla_episode_ceased);
CREATE NONCLUSTERED INDEX idx_ssd_clae_referral_id ON ssd_cla_episodes(clae_referral_id);
CREATE NONCLUSTERED INDEX idx_ssd_clae_cla_last_iro_contact_date ON ssd_cla_episodes(clae_cla_last_iro_contact_date);
CREATE NONCLUSTERED INDEX idx_clae_cla_placement_id ON ssd_cla_episodes(clae_cla_placement_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_cla_convictions
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_convictions';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_cla_convictions;
IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;


-- create structure
CREATE TABLE ssd_development.ssd_cla_convictions (
    clac_cla_conviction_id      NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAC001A"}
    clac_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
    clac_cla_conviction_date    DATETIME,                   -- metadata={"item_ref":"CLAC003A"}
    clac_cla_conviction_offence NVARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
);

-- insert data
INSERT INTO ssd_cla_convictions (
    clac_cla_conviction_id, 
    clac_person_id, 
    clac_cla_conviction_date, 
    clac_cla_conviction_offence
    )


-- EXTRACT SELECT

-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- -- add constraint(s)
-- ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
-- FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_clac_person_id ON ssd_cla_convictions(clac_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clac_conviction_date ON ssd_cla_convictions(clac_cla_conviction_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cla_health
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_health';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_cla_health', 'U') IS NOT NULL DROP TABLE ssd_cla_health;
IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

-- create structure
CREATE TABLE ssd_development.ssd_cla_health (
    clah_health_check_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAH001A"}
    clah_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAH002A"}
    clah_health_check_type      NVARCHAR(500),              -- metadata={"item_ref":"CLAH003A"}
    clah_health_check_date      DATETIME,                   -- metadata={"item_ref":"CLAH004A"}
    clah_health_check_status    NVARCHAR(48)                -- metadata={"item_ref":"CLAH005A"}
);
 
-- insert data
INSERT INTO ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 

-- EXTRACT SELECT
 
 
-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- -- add constraint(s)
-- ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
-- FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clah_person_id ON ssd_cla_health (clah_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_date ON ssd_cla_health(clah_health_check_date);
CREATE NONCLUSTERED INDEX idx_ssd_clah_health_check_status ON ssd_cla_health(clah_health_check_status);







-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cla_immunisations
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_immunisations';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_cla_immunisations;
IF OBJECT_ID('tempdb..#ssd_cla_immunisations') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

-- Create structure
CREATE TABLE ssd_development.ssd_cla_immunisations (
    clai_person_id                  NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAI002A"}
    clai_immunisations_status       NCHAR(1),                   -- metadata={"item_ref":"CLAI004A"}
    clai_immunisations_status_date  DATETIME                    -- metadata={"item_ref":"CLAI005A"}
);



-- Insert data (only most recent/rn==1 records)
INSERT INTO ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)

-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- -- add constraint(s)
-- ALTER TABLE ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
-- FOREIGN KEY (clai_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_clai_person_id ON ssd_cla_immunisations(clai_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clai_immunisations_status ON ssd_cla_immunisations(clai_immunisations_status);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cla_substance_misuse
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_substance_misuse';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_cla_substance_misuse;
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

-- Create structure 
CREATE TABLE ssd_development.ssd_cla_substance_misuse (
    clas_substance_misuse_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAS001A"}
    clas_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
    clas_substance_misuse_date      DATETIME,                   -- metadata={"item_ref":"CLAS003A"}
    clas_substance_misused          NVARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
    clas_intervention_received      NCHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
);

-- Insert data
INSERT INTO ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)


-- EXTRACT SELECT



-- WHERE EXISTS 
--     (   -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     );


-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
-- FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clas_person_id ON ssd_cla_substance_misuse (clas_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clas_substance_misuse_date ON ssd_cla_substance_misuse(clas_substance_misuse_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_placement
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_placement';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_placement', 'U') IS NOT NULL DROP TABLE ssd_cla_placement;
IF OBJECT_ID('tempdb..#ssd_cla_placement', 'U') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
-- Create structure
CREATE TABLE ssd_development.ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAP001A"}
    clap_cla_id                         NVARCHAR(48),               -- metadata={"item_ref":"CLAP012A"}
    clap_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"CLAP013A"}
    clap_cla_placement_start_date       DATETIME,                   -- metadata={"item_ref":"CLAP003A"}
    clap_cla_placement_type             NVARCHAR(100),              -- metadata={"item_ref":"CLAP004A"}
    clap_cla_placement_urn              NVARCHAR(48),               -- metadata={"item_ref":"CLAP005A"}
    clap_cla_placement_distance         FLOAT,                      -- metadata={"item_ref":"CLAP011A"}
    clap_cla_placement_provider         NVARCHAR(48),               -- metadata={"item_ref":"CLAP007A"}
    clap_cla_placement_postcode         NVARCHAR(8),                -- metadata={"item_ref":"CLAP008A"}
    clap_cla_placement_end_date         DATETIME,                   -- metadata={"item_ref":"CLAP009A"}
    clap_cla_placement_change_reason    NVARCHAR(100)               -- metadata={"item_ref":"CLAP010A"}
);
 
-- Insert data
INSERT INTO ssd_cla_placement (
    clap_cla_placement_id,
    clap_cla_id,
    clap_person_id,
    clap_cla_placement_start_date,
    clap_cla_placement_type,
    clap_cla_placement_urn,
    clap_cla_placement_distance,
    clap_cla_placement_provider,
    clap_cla_placement_postcode,
    clap_cla_placement_end_date,
    clap_cla_placement_change_reason  
)


-- EXTRACT SELECT



-- WHERE PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
--                                             'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
--                                             'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')


-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_clap_to_clae 
-- FOREIGN KEY (clap_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clap_cla_placement_urn ON ssd_cla_placement (clap_cla_placement_urn);
CREATE NONCLUSTERED INDEX idx_ssd_clap_cla_id ON ssd_cla_placement(clap_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_start_date ON ssd_cla_placement(clap_cla_placement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_end_date ON ssd_cla_placement(clap_cla_placement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_postcode ON ssd_cla_placement(clap_cla_placement_postcode);
CREATE NONCLUSTERED INDEX idx_ssd_clap_placement_type ON ssd_cla_placement(clap_cla_placement_type);






-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cla_reviews
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_reviews';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE ssd_cla_reviews;
IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
-- Create structure
CREATE TABLE ssd_development.ssd_cla_reviews (
    clar_cla_review_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAR001A"}
    clar_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"CLAR011A"}
    clar_cla_review_due_date        DATETIME,                   -- metadata={"item_ref":"CLAR003A"}
    clar_cla_review_date            DATETIME,                   -- metadata={"item_ref":"CLAR004A"}
    clar_cla_review_cancelled       NCHAR(1),                   -- metadata={"item_ref":"CLAR012A"}
    clar_cla_review_participation   NVARCHAR(100)               -- metadata={"item_ref":"CLAR007A"}
    );
 
-- Insert data
INSERT INTO ssd_cla_reviews (
    clar_cla_review_id,
    clar_cla_id,
    clar_cla_review_due_date,
    clar_cla_review_date,
    clar_cla_review_cancelled,
    clar_cla_review_participation
)
 


-- EXTRACT SELECT
 


-- WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'
 
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )
 


-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_reviews ADD CONSTRAINT FK_clar_to_clae 
-- FOREIGN KEY (clar_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_clar_cla_id ON ssd_cla_reviews(clar_cla_id);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_due_date ON ssd_cla_reviews(clar_cla_review_due_date);
CREATE NONCLUSTERED INDEX idx_ssd_clar_review_date ON ssd_cla_reviews(clar_cla_review_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cla_previous_permanence
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_previous_permanence';
PRINT 'Creating table: ' + @TableName;
 


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_previous_permanence') IS NOT NULL DROP TABLE ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;


-- Create structure
CREATE TABLE ssd_development.ssd_cla_previous_permanence (
    lapp_table_id                       NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LAPP001A"}
    lapp_person_id                      NVARCHAR(48),               -- metadata={"item_ref":"LAPP002A"}
    lapp_previous_permanence_option     NVARCHAR(200),              -- metadata={"item_ref":"LAPP004A"}
    lapp_previous_permanence_la         NVARCHAR(100),              -- metadata={"item_ref":"LAPP005A"}
    lapp_previous_permanence_order_date NVARCHAR(100)               -- metadata={"item_ref":"LAPP003A"} -- must remain NVARCHAR
);
 
-- Insert data
INSERT INTO ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date
           )


-- EXTRACT SELECT


--     CASE 
--         WHEN PATINDEX('%[^0-9]%', MAX(CASE WHEN ANSWER_NO = 'ORDERDATE' THEN ANSWER END)) = 0 AND 
--              CAST(MAX(CASE WHEN ANSWER_NO = 'ORDERDATE' THEN ANSWER END) AS INT) BETWEEN 1 AND 31 THEN MAX(CASE WHEN ANSWER_NO = 'ORDERDATE' THEN ANSWER END) 
--         ELSE 'zz' 
--     END + '/' + 
--  -- Adjusted CASE statement for ORDERMONTH to convert month names to numbers
--     CASE 
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('January', 'Jan')  THEN '01'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('February', 'Feb') THEN '02'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('March', 'Mar')    THEN '03'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('April', 'Apr')    THEN '04'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('May')             THEN '05'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('June', 'Jun')     THEN '06'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('July', 'Jul')     THEN '07'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('August', 'Aug')   THEN '08'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('September', 'Sep') THEN '09'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('October', 'Oct')  THEN '10'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('November', 'Nov') THEN '11'
--         WHEN MAX(CASE WHEN ANSWER_NO = 'ORDERMONTH' THEN ANSWER END) IN ('December', 'Dec') THEN '12'
--         ELSE 'zz' -- also handles 'unknown' string
--     END + '/' + 
--     CASE 
--         WHEN PATINDEX('%[^0-9]%', MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END)) = 0 THEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END) 
--         ELSE 'zzzz' 
--     END
--     AS lapp_previous_permanence_order_date

 
 
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     );
 

 
-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_lapp_person_id
-- FOREIGN KEY (lapp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


-- create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_lapp_person_id ON ssd_cla_previous_permanence(lapp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lapp_previous_permanence_option ON ssd_cla_previous_permanence(lapp_previous_permanence_option);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cla_care_plan
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: Check spec for key:value structure of json field
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_care_plan';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_cla_care_plan') IS NOT NULL DROP TABLE #ssd_TMP_PRE_cla_care_plan;
 
 
-- Create structure
CREATE TABLE ssd_development.ssd_cla_care_plan (
    lacp_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"LACP001A"}
    lacp_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"LACP007A"}
    lacp_cla_care_plan_start_date   DATETIME,                   -- metadata={"item_ref":"LACP004A"}
    lacp_cla_care_plan_end_date     DATETIME,                   -- metadata={"item_ref":"LACP005A"}
    lacp_cla_care_plan_json         NVARCHAR(1000)              -- metadata={"item_ref":"LACP003A"}
);
 
-- Insert data
INSERT INTO ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)



-- EXTRACT SELECT
 
 
-- WHERE PLAN_STATUS_ID_CODE = 'A';
 

-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_care_plan ADD CONSTRAINT FK_lacp_person_id
-- FOREIGN KEY (lacp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);
 
-- create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_lacp_person_id ON ssd_cla_care_plan(lacp_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_start_date ON ssd_cla_care_plan(lacp_cla_care_plan_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_lacp_care_plan_end_date ON ssd_cla_care_plan(lacp_cla_care_plan_end_date);



 
-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_cla_visits
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
 
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_visits';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_visits', 'U') IS NOT NULL DROP TABLE ssd_cla_visits;
IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;


-- Create structure
CREATE TABLE ssd_development.ssd_cla_visits (
    clav_cla_visit_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLAV001A"}
    clav_cla_id                 NVARCHAR(48),               -- metadata={"item_ref":"CLAV007A"}
    clav_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CLAV008A"}
    clav_cla_visit_date         DATETIME,                   -- metadata={"item_ref":"CLAV003A"}
    clav_cla_visit_seen         NCHAR(1),                   -- metadata={"item_ref":"CLAV004A"}
    clav_cla_visit_seen_alone   NCHAR(1)                    -- metadata={"item_ref":"CLAV005A"}
);
 
-- Insert data
INSERT INTO ssd_cla_visits (
    clav_cla_visit_id,
    clav_cla_id,
    clav_person_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 


-- EXTRACT SELECT


 
-- WHERE CASNT_TYPE_ID_CODE IN ('STVL')
 
-- AND EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     );



-- -- Add constraint(s)
-- ALTER TABLE ssd_cla_visits ADD CONSTRAINT FK_clav_person_id
-- FOREIGN KEY (clav_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

-- create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_clav_person_id ON ssd_cla_visits(clav_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clav_visit_date ON ssd_cla_visits(clav_cla_visit_date);
CREATE NONCLUSTERED INDEX idx_ssd_clav_cla_id ON ssd_cla_visits(clav_cla_id);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_sdq_scores
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_sdq_scores';
PRINT 'Creating table: ' + @TableName;
 
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE ssd_sdq_scores;
IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 

-- Create structure
CREATE TABLE ssd_development.ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48),               -- metadata={"item_ref":"CSDQ001A"} PRIMARY KEY
    csdq_person_id              NVARCHAR(48),               -- metadata={"item_ref":"CSDQ002A"}
    csdq_sdq_score              NVARCHAR(100),              -- metadata={"item_ref":"CSDQ005A"}
    csdq_sdq_completed_date     DATETIME,                   -- metadata={"item_ref":"CSDQ003A"}
    csdq_sdq_details_json       NVARCHAR(1000),             -- Depreciated to be removed [TESTING]
    csdq_sdq_reason             NVARCHAR(100)               -- metadata={"item_ref":"CSDQ004A"}
);
 
-- Insert data
INSERT INTO ssd_development.ssd_sdq_scores (
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_score,
    csdq_sdq_completed_date,
    csdq_sdq_details_json,
    csdq_sdq_reason
)


-- EXTRACT SELECT



-- WHERE EXISTS (
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = ff.DIM_PERSON_ID
-- );
 


-- -- Add constraint(s)
-- ALTER TABLE ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
-- FOREIGN KEY (csdq_person_id) REFERENCES ssd_person(pers_person_id);

-- DEV NOTES [TESTING]
-- Msg 2627, Level 14, State 1, Line 3129
-- Violation of PRIMARY KEY constraint 'PK__ssd_sdq___EACA4F0597284006'. 
-- Cannot insert duplicate key in object 'ssd_development.ssd_sdq_scores'. The duplicate key value is (2316504).

-- create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_csdq_person_id ON ssd_sdq_scores(csdq_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_missing
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_missing';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_missing', 'U') IS NOT NULL DROP TABLE ssd_missing;
IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

-- Create structure
CREATE TABLE ssd_development.ssd_missing (
    miss_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MISS001A"}
    miss_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"MISS002A"}
    miss_missing_episode_start_date DATETIME,                   -- metadata={"item_ref":"MISS003A"}
    miss_missing_episode_type       NVARCHAR(100),              -- metadata={"item_ref":"MISS004A"}
    miss_missing_episode_end_date   DATETIME,                   -- metadata={"item_ref":"MISS005A"}
    miss_missing_rhi_offered        NVARCHAR(2),                -- metadata={"item_ref":"MISS006A"}                
    miss_missing_rhi_accepted       NVARCHAR(2)                 -- metadata={"item_ref":"MISS007A"}
);


-- Insert data 
INSERT INTO ssd_missing (
    miss_table_id,
    miss_person_id,
    miss_missing_episode_start_date,
    miss_missing_episode_type,
    miss_missing_episode_end_date,
    miss_missing_rhi_offered,                   
    miss_missing_rhi_accepted    
)


-- EXTRACT SELECT



-- WHERE EXISTS 
--     ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     );


-- -- Add constraint(s)
-- ALTER TABLE ssd_missing ADD CONSTRAINT FK_missing_to_person
-- FOREIGN KEY (miss_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_miss_person_id        ON ssd_missing(miss_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_start    ON ssd_missing(miss_missing_episode_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_episode_end      ON ssd_missing(miss_missing_episode_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_offered      ON ssd_missing(miss_missing_rhi_offered);
CREATE NONCLUSTERED INDEX idx_ssd_miss_rhi_accepted     ON ssd_missing(miss_missing_rhi_accepted);






-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/*
=============================================================================
Object Name: ssd_care_leavers
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_care_leavers';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_care_leavers', 'U') IS NOT NULL DROP TABLE ssd_care_leavers;
IF OBJECT_ID('tempdb..#ssd_care_leavers', 'U') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
 
-- Create structure
CREATE TABLE ssd_development.ssd_care_leavers
(
    clea_table_id                           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CLEA001A"}
    clea_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"CLEA002A"}
    clea_care_leaver_eligibility            NVARCHAR(100),              -- metadata={"item_ref":"CLEA003A"}
    clea_care_leaver_in_touch               NVARCHAR(100),              -- metadata={"item_ref":"CLEA004A"}
    clea_care_leaver_latest_contact         DATETIME,                   -- metadata={"item_ref":"CLEA005A"}
    clea_care_leaver_accommodation          NVARCHAR(100),              -- metadata={"item_ref":"CLEA006A"}
    clea_care_leaver_accom_suitable         NVARCHAR(100),              -- metadata={"item_ref":"CLEA007A"}
    clea_care_leaver_activity               NVARCHAR(100),              -- metadata={"item_ref":"CLEA008A"}
    clea_pathway_plan_review_date           DATETIME,                   -- metadata={"item_ref":"CLEA009A"}
    clea_care_leaver_personal_advisor       NVARCHAR(100),              -- metadata={"item_ref":"CLEA010A"}
    clea_care_leaver_allocated_team_name    NVARCHAR(255),              -- metadata={"item_ref":"CLEA011A"}
    clea_care_leaver_worker_name            NVARCHAR(100)               -- metadata={"item_ref":"CLEA012A"}
);
  
-- Insert data
INSERT INTO ssd_care_leavers
(
    clea_table_id,
    clea_person_id,
    clea_care_leaver_eligibility,
    clea_care_leaver_in_touch,
    clea_care_leaver_latest_contact,
    clea_care_leaver_accommodation,
    clea_care_leaver_accom_suitable,
    clea_care_leaver_activity,
    clea_pathway_plan_review_date,
    clea_care_leaver_personal_advisor,                  
    clea_care_leaver_allocated_team_name,
    clea_care_leaver_worker_name            
)
 


-- EXTRACT SELECT


-- WHERE EXISTS ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = SOURCE_PERSON_ID
--     )


-- -- Add constraint(s)
-- ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leavers_person
-- FOREIGN KEY (clea_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_clea_person_id                        ON ssd_care_leavers(clea_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_clea_care_leaver_latest_contact   ON ssd_care_leavers(clea_care_leaver_latest_contact);
CREATE NONCLUSTERED INDEX idx_ssd_clea_pathway_plan_review_date     ON ssd_care_leavers(clea_pathway_plan_review_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_permanence
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/

-- [TESTING] Create marker
SET @TableName = N'ssd_permanence';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_permanence', 'U') IS NOT NULL DROP TABLE ssd_permanence;
IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

-- Create structure
CREATE TABLE ssd_development.ssd_permanence (
    perm_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PERM001A"}
    perm_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"PERM002A"}
    perm_cla_id                     NVARCHAR(48),               -- metadata={"item_ref":"PERM022A"}
    perm_adm_decision_date          DATETIME,                   -- metadata={"item_ref":"PERM003A"}
    perm_part_of_sibling_group      NCHAR(1),                   -- metadata={"item_ref":"PERM012A"}
    perm_siblings_placed_together   INT,                        -- metadata={"item_ref":"PERM013A"}
    perm_siblings_placed_apart      INT,                        -- metadata={"item_ref":"PERM014A"}
    perm_ffa_cp_decision_date       DATETIME,                   -- metadata={"item_ref":"PERM004A"}              
    perm_placement_order_date       DATETIME,                   -- metadata={"item_ref":"PERM006A"}
    perm_matched_date               DATETIME,                   -- metadata={"item_ref":"PERM008A"}
    perm_adopter_sex                NVARCHAR(48),               -- metadata={"item_ref":"PERM025A"}
    perm_adopter_legal_status       NVARCHAR(100),              -- metadata={"item_ref":"PERM026A"}
    perm_number_of_adopters         INT,                        -- metadata={"item_ref":"PERM027A"}
    perm_placed_for_adoption_date   DATETIME,                   -- metadata={"item_ref":"PERM007A"}             
    perm_adopted_by_carer_flag      NCHAR(1),                   -- metadata={"item_ref":"PERM021A"}
    perm_placed_foster_carer_date   DATETIME,                   -- metadata={"item_ref":"PERM011A", "item_Status":"P"}
    perm_placed_ffa_cp_date         DATETIME,                   -- metadata={"item_ref":"PERM009A"}
    perm_placement_provider_urn     NVARCHAR(48),               -- metadata={"item_ref":"PERM015A"}  
    perm_decision_reversed_date     DATETIME,                   -- metadata={"item_ref":"PERM010A"}                  
    perm_decision_reversed_reason   NVARCHAR(100),              -- metadata={"item_ref":"PERM016A"}
    perm_permanence_order_date      DATETIME,                   -- metadata={"item_ref":"PERM017A"}              
    perm_permanence_order_type      NVARCHAR(100),              -- metadata={"item_ref":"PERM018A"}        
    perm_adoption_worker_name       NVARCHAR(100)               -- metadata={"item_ref":"PERM023A"}
    
);

-- Insert data
INSERT INTO ssd_permanence (
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_adopter_sex,
    perm_adopter_legal_status,
    perm_number_of_adopters,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_foster_carer_date,
    perm_placed_ffa_cp_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker_name
)  


-- EXTRACT SELECT


-- WHERE EXISTS
--     ( -- only ssd relevant records
--     SELECT 1
--     FROM ssd_person p
--     WHERE p.pers_person_id = perm_person_id
--     );



-- -- Add constraint(s)
-- ALTER TABLE ssd_permanence ADD CONSTRAINT FK_perm_person_id
-- FOREIGN KEY (perm_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_perm_person_id            ON ssd_permanence(perm_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_perm_adm_decision_date    ON ssd_permanence(perm_adm_decision_date);
CREATE NONCLUSTERED INDEX idx_ssd_perm_order_date           ON ssd_permanence(perm_permanence_order_date);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_professionals
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_professionals';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_professionals', 'U') IS NOT NULL DROP TABLE ssd_professionals;
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;


-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;

-- Determine/Define date on which CASELOAD count starts
DECLARE @SSDStartDate DATE = DATEADD(YEAR, -@ssd_timeframe_years, @LastSept30th);


-- Create structure
CREATE TABLE ssd_development.ssd_professionals (
    prof_professional_id                NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PROF001A"}
    prof_staff_id                       NVARCHAR(48),               -- metadata={"item_ref":"PROF010A"}
    prof_professional_name              NVARCHAR(300),              -- metadata={"item_ref":"PROF013A", "item_notes":"used as Allocated|Assigned worker"}
    prof_social_worker_registration_no  NVARCHAR(48),               -- metadata={"item_ref":"PROF002A"}
    prof_agency_worker_flag             NCHAR(1),                   -- metadata={"item_ref":"PROF014A"}
    prof_professional_job_title         NVARCHAR(500),              -- metadata={"item_ref":"PROF007A"}
    prof_professional_caseload          INT,                        -- metadata={"item_ref":"PROF008A", "item_notes":"0 when no open cases on given date"}             
    prof_professional_department        NVARCHAR(100),              -- metadata={"item_ref":"PROF012A"}
    prof_full_time_equivalency          FLOAT                       -- metadata={"item_ref":"PROF011A"}
);

-- Insert data
INSERT INTO ssd_professionals (
    prof_professional_id, 
    prof_staff_id, 
    prof_professional_name,
    prof_social_worker_registration_no,
    prof_agency_worker_flag,
    prof_professional_job_title,
    prof_professional_caseload,
    prof_professional_department,
    prof_full_time_equivalency
)



-- EXTRACT SELECT


-- LEFT JOIN 
--     SELECT 
--         -- Calculate CASELOAD 
--         -- [REVIEW][TESTING] count within restricted ssd timeframe only
--         DIM_WORKER_ID,
--         COUNT(*) AS OpenCases



-- Add constraint(s)
-- SSD_PH

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prof_staff_id                 ON ssd_professionals (prof_staff_id);
CREATE NONCLUSTERED INDEX idx_ssd_prof_social_worker_reg_no ON ssd_professionals(prof_social_worker_registration_no);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/*
=============================================================================
Object Name: ssd_involvements
Description:
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [B]acklog
Remarks: 
    
Dependencies:
- 
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_involvements';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_involvements', 'U') IS NOT NULL DROP TABLE ssd_involvements;
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
-- Create structure
CREATE TABLE ssd_development.ssd_involvements (
    invo_involvements_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"INVO005A"}
    invo_professional_id        NVARCHAR(48),               -- metadata={"item_ref":"INVO006A"}
    invo_professional_role_id   NVARCHAR(200),              -- metadata={"item_ref":"INVO007A"}
    invo_professional_team      NVARCHAR(1000),             -- metadata={"item_ref":"INVO009A"}
    invo_person_id              NVARCHAR(48),               -- metadata={"item_ref":"INVO011A"}
    invo_involvement_start_date DATETIME,                   -- metadata={"item_ref":"INVO002A"}
    invo_involvement_end_date   DATETIME,                   -- metadata={"item_ref":"INVO003A"}
    invo_worker_change_reason   NVARCHAR(200),              -- metadata={"item_ref":"INVO004A"}
    invo_referral_id            NVARCHAR(48)                -- metadata={"item_ref":"INVO010A"}
);
 
-- Insert data
INSERT INTO ssd_involvements (
    invo_involvements_id,
    invo_professional_id,
    invo_professional_role_id,
    invo_professional_team,
    invo_person_id,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)


-- EXTRACT SELECT


WHERE EXISTS
    (
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fi.DIM_PERSON_ID
    );




-- -- Add constraint(s)
-- ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional 
-- FOREIGN KEY (invo_professional_id) REFERENCES ssd_professionals (prof_professional_id);

-- ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional_role 
-- FOREIGN KEY (invo_professional_role_id) REFERENCES ssd_professionals (prof_social_worker_registration_no);



-- Create index(es)
CREATE NONCLUSTERED INDEX idx_invo_person_id            ON ssd_involvements (invo_person_id);
CREATE NONCLUSTERED INDEX idx_invo_professional_role_id ON ssd_involvements (invo_professional_role_id);
CREATE NONCLUSTERED INDEX idx_ssd_invo_start_date       ON ssd_involvements(invo_involvement_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_end_date         ON ssd_involvements(invo_involvement_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_invo_referral_id      ON ssd_involvements(invo_referral_id);



    

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_linked_identifiers
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [R]elease
Remarks: The list of allowed identifier_type codes are:
            ['Case Number', 
            'Unique Pupil Number', 
            'NHS Number', 
            'Home Office Registration', 
            'National Insurance Number', 
            'YOT Number', 
            'Court Case Number', 
            'RAA ID', 
            'Incident ID']
            To have any further codes agreed into the standard, issue a change request

Dependencies: 
- Yet to be defined
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_linked_identifiers';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop 
IF OBJECT_ID('ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE ssd_linked_identifiers;
IF OBJECT_ID('tempdb..#ssd_linked_identifiers', 'U') IS NOT NULL DROP TABLE #ssd_linked_identifiers;

-- Create structure
CREATE TABLE ssd_development.ssd_linked_identifiers (
    link_table_id               NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),   -- metadata={"item_ref":"LINK001A"}
    link_person_id              NVARCHAR(48),                               -- metadata={"item_ref":"LINK002A"} 
    link_identifier_type        NVARCHAR(100),                              -- metadata={"item_ref":"LINK003A"}
    link_identifier_value       NVARCHAR(100),                              -- metadata={"item_ref":"LINK004A"}
    link_valid_from_date        DATETIME,                                   -- metadata={"item_ref":"LINK005A"}
    link_valid_to_date          DATETIME                                    -- metadata={"item_ref":"LINK006A"}
);

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_linked_identifiers (
--     -- row id ommitted as ID generated (link_table_id)
--     link_person_id,
--     link_identifier_type,
--     link_identifier_value,
--     link_valid_from_date,
--     link_valid_to_date
-- )
-- VALUES
--     ('SSD_PH', 'SSD_PH', 'SSD_PH', '1900/01/01', '1900/01/01');


-- -- Create constraint(s)
-- ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
-- FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_link_person_id        ON ssd_linked_identifiers(link_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_from_date  ON ssd_linked_identifiers(link_valid_from_date);
CREATE NONCLUSTERED INDEX idx_ssd_link_valid_to_date    ON ssd_linked_identifiers(link_valid_to_date);





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* Start 

         SSDF Other DfE projects (e.g. 1b, 2(a,b) elements extracts 
        
        */



/* 
=============================================================================
Object Name: ssd_s251_finance
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
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
IF OBJECT_ID('tempdb..#ssd_s251_finance', 'U') IS NOT NULL DROP TABLE #ssd_s251_finance;

-- Create structure
CREATE TABLE ssd_development.ssd_s251_finance (
    s251_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"S251001A"}
    s251_cla_placement_id   NVARCHAR(48),               -- metadata={"item_ref":"S251002A"} 
    s251_placeholder_1      NVARCHAR(48),               -- metadata={"item_ref":"S251003A"}
    s251_placeholder_2      NVARCHAR(48),               -- metadata={"item_ref":"S251004A"}
    s251_placeholder_3      NVARCHAR(48),               -- metadata={"item_ref":"S251005A"}
    s251_placeholder_4      NVARCHAR(48)                -- metadata={"item_ref":"S251006A"}
);

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_s251_finance (
--     -- row id ommitted as ID generated (s251_table_id,)
--     s251_cla_placement_id,
--     s251_placeholder_1,
--     s251_placeholder_2,
--     s251_placeholder_3,
--     s251_placeholder_4
-- )
-- VALUES
--     ('SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH');

-- -- Create constraint(s)
-- ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
-- FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_s251_cla_placement_id ON ssd_s251_finance(s251_cla_placement_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));





/* 
=============================================================================
Object Name: ssd_voice_of_child
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
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
IF OBJECT_ID('tempdb..#ssd_voice_of_child', 'U') IS NOT NULL DROP TABLE #ssd_voice_of_child;

-- Create structure
CREATE TABLE ssd_development.ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"VOCH007A"}
    voch_person_id              NVARCHAR(48),               -- metadata={"item_ref":"VOCH001A"}
    voch_explained_worries      NCHAR(1),                   -- metadata={"item_ref":"VOCH002A"}
    voch_story_help_understand  NCHAR(1),                   -- metadata={"item_ref":"VOCH003A"}
    voch_agree_worker           NCHAR(1),                   -- metadata={"item_ref":"VOCH004A"}
    voch_plan_safe              NCHAR(1),                   -- metadata={"item_ref":"VOCH005A"}
    voch_tablet_help_explain    NCHAR(1)                    -- metadata={"item_ref":"VOCH006A"}
);

-- -- Insert placeholder data [TESTING]
-- INSERT INTO ssd_voice_of_child (
--     -- row id ommitted as ID generated (voch_table_id,)
--     voch_person_id,
--     voch_explained_worries,
--     voch_story_help_understand,
--     voch_agree_worker,
--     voch_plan_safe,
--     voch_tablet_help_explain
-- )
-- VALUES
--     ('10001', 'Y', 'Y', 'Y', 'Y', 'Y'),
--     ('10002', 'Y', 'Y', 'Y', 'Y', 'Y');


-- To switch on once source data for voice defined.
-- WHERE EXISTS 
--  ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = ssd_voice_of_child.DIM_PERSON_ID
--     );

-- -- Create constraint(s)
-- ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
-- FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_voice_of_child_voch_person_id ON ssd_voice_of_child(voch_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_pre_proceedings
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
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
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

-- Create structure
CREATE TABLE ssd_development.ssd_pre_proceedings (
    prep_table_id                           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"PREP024A"}
    prep_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"PREP001A"}
    prep_plo_family_id                      NVARCHAR(48),               -- metadata={"item_ref":"PREP002A"}
    prep_pre_pro_decision_date              DATETIME,                   -- metadata={"item_ref":"PREP003A"}
    prep_initial_pre_pro_meeting_date       DATETIME,                   -- metadata={"item_ref":"PREP004A"}
    prep_pre_pro_outcome                    NVARCHAR(100),              -- metadata={"item_ref":"PREP005A"}
    prep_agree_stepdown_issue_date          DATETIME,                   -- metadata={"item_ref":"PREP006A"}
    prep_cp_plans_referral_period           INT,                        -- metadata={"item_ref":"PREP007A"}
    prep_legal_gateway_outcome              NVARCHAR(100),              -- metadata={"item_ref":"PREP008A"}
    prep_prev_pre_proc_child                INT,                        -- metadata={"item_ref":"PREP009A"}
    prep_prev_care_proc_child               INT,                        -- metadata={"item_ref":"PREP010A"}
    prep_pre_pro_letter_date                DATETIME,                   -- metadata={"item_ref":"PREP011A"}
    prep_care_pro_letter_date               DATETIME,                   -- metadata={"item_ref":"PREP012A"}
    prep_pre_pro_meetings_num               INT,                        -- metadata={"item_ref":"PREP013A"}
    prep_pre_pro_parents_legal_rep          NCHAR(1),                   -- metadata={"item_ref":"PREP014A"}
    prep_parents_legal_rep_point_of_issue   NCHAR(2),                   -- metadata={"item_ref":"PREP015A"}
    prep_court_reference                    NVARCHAR(48),               -- metadata={"item_ref":"PREP016A"}
    prep_care_proc_court_hearings           INT,                        -- metadata={"item_ref":"PREP017A"}
    prep_care_proc_short_notice             NCHAR(1),                   -- metadata={"item_ref":"PREP018A"}
    prep_proc_short_notice_reason           NVARCHAR(100),              -- metadata={"item_ref":"PREP019A"}
    prep_la_inital_plan_approved            NCHAR(1),                   -- metadata={"item_ref":"PREP020A"}
    prep_la_initial_care_plan               NVARCHAR(100),              -- metadata={"item_ref":"PREP021A"}
    prep_la_final_plan_approved             NCHAR(1),                   -- metadata={"item_ref":"PREP022A"}
    prep_la_final_care_plan                 NVARCHAR(100)               -- metadata={"item_ref":"PREP023A"}
);

-- -- Insert placeholder data
-- INSERT INTO ssd_pre_proceedings (
--     -- row id ommitted as ID generated (prep_table_id,)
--     prep_person_id,
--     prep_plo_family_id,
--     prep_pre_pro_decision_date,
--     prep_initial_pre_pro_meeting_date,
--     prep_pre_pro_outcome,
--     prep_agree_stepdown_issue_date,
--     prep_cp_plans_referral_period,
--     prep_legal_gateway_outcome,
--     prep_prev_pre_proc_child,
--     prep_prev_care_proc_child,
--     prep_pre_pro_letter_date,
--     prep_care_pro_letter_date,
--     prep_pre_pro_meetings_num,
--     prep_pre_pro_parents_legal_rep,
--     prep_parents_legal_rep_point_of_issue,
--     prep_court_reference,
--     prep_care_proc_court_hearings,
--     prep_care_proc_short_notice,
--     prep_proc_short_notice_reason,
--     prep_la_inital_plan_approved,
--     prep_la_initial_care_plan,
--     prep_la_final_plan_approved,
--     prep_la_final_care_plan
-- )
-- VALUES
--     (
--     'SSD_PH', 'PLO_FAMILY1', '1900/01/01', '1900/01/01', 'Outcome1', 
--     '1900/01/01', 3, 'Approved', 2, 1, '1900/01/01', '1900/01/01', 2, 'Y', 
--     'NA', 'COURT_REF_1', 1, 'Y', 'Reason1', 'Y', 'Initial Plan 1', 'Y', 'Final Plan 1'
--     ),
--     (
--     'SSD_PH', 'PLO_FAMILY2', '1900/01/01', '1900/01/01', 'Outcome2',
--     '1900/01/01', 4, 'Denied', 1, 2, '1900/01/01', '1900/01/01', 3, 'Y',
--     'IS', 'COURT_REF_2', 2, 'Y', 'Reason2', 'Y', 'Initial Plan 2', 'Y', 'Final Plan 2'
--     );



-- To switch on once source data defined.
-- WHERE EXISTS 
-- ( -- only ssd relevant records
--     SELECT 1 
--     FROM ssd_person p
--     WHERE p.pers_person_id = ssd_pre_proceedings.DIM_PERSON_ID
--     );

-- -- Create constraint(s)
-- ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
-- FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_prep_person_id                ON ssd_pre_proceedings (prep_person_id);
CREATE NONCLUSTERED INDEX idx_prep_pre_pro_decision_date    ON ssd_pre_proceedings (prep_pre_pro_decision_date);
CREATE NONCLUSTERED INDEX idx_prep_legal_gateway_outcome    ON ssd_pre_proceedings (prep_legal_gateway_outcome);



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
Object Name: ssd_send
Description: 
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks: 
    
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_send';
PRINT 'Creating table: ' + @TableName;



-- Check if exists, & drop
IF OBJECT_ID('ssd_send') IS NOT NULL DROP TABLE ssd_send;
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL DROP TABLE #ssd_send;

-- Create structure 
CREATE TABLE ssd_development.ssd_send (
    send_table_id       NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SEND001A"}
    send_person_id      NVARCHAR(48),               -- metadata={"item_ref":"SEND005A"}
    send_upn            NVARCHAR(48),               -- metadata={"item_ref":"SEND002A"}
    send_uln            NVARCHAR(48),               -- metadata={"item_ref":"SEND003A"}
    send_upn_unknown    NVARCHAR(6)                 -- metadata={"item_ref":"SEND004A"}
    );

-- -- Insert placeholder data
-- INSERT INTO ssd_send (
--     send_table_id,
--     send_person_id, 
--     send_upn,
--     send_uln,
--     send_upn_unknown

-- )
-- VALUES ('SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH', 'SSD_PH');
 

-- -- Add constraint(s)
-- ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
-- FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/*
=============================================================================
Object Name: ssd_sen_need
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_sen_need';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists, & drop
IF OBJECT_ID('ssd_sen_need', 'U') IS NOT NULL DROP TABLE ssd_sen_need  ;
IF OBJECT_ID('tempdb..#ssd_sen_need', 'U') IS NOT NULL DROP TABLE #ssd_sen_need  ;
 
 
-- Create structure
CREATE TABLE ssd_development.ssd_sen_need (
    senn_table_id                   NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"SENN001A"}
    senn_active_ehcp_id             NVARCHAR(48),               -- metadata={"item_ref":"SENN002A"}
    senn_active_ehcp_need_type      NVARCHAR(100),              -- metadata={"item_ref":"SENN003A"}
    senn_active_ehcp_need_rank      NCHAR(1)                    -- metadata={"item_ref":"SENN004A"}
);
 
-- -- Create constraint(s)
-- ALTER TABLE ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
-- FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_ehcp_active_plans(pers_person_id);

-- Create index(es)


-- -- Insert placeholder data
-- INSERT INTO ssd_sen_need (senn_table_id, senn_active_ehcp_id, senn_active_ehcp_need_type, senn_active_ehcp_need_rank)
-- VALUES ('SSD_PH', 'SSD_PH', 'SSD_PH', '0');
 
 


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));
 



/* 
=============================================================================
Object Name: ssd_ehcp_requests 
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_ehcp_requests ';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE ssd_ehcp_requests ;
IF OBJECT_ID('tempdb..#ssd_ehcp_requests', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_requests ;


-- Create structure
CREATE TABLE ssd_development.ssd_ehcp_requests (
    ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCR001A"}
    ehcr_send_table_id              NVARCHAR(48),               -- metadata={"item_ref":"EHCR002A"}
    ehcr_ehcp_req_date              DATETIME,                   -- metadata={"item_ref":"EHCR003A"}
    ehcr_ehcp_req_outcome_date      DATETIME,                   -- metadata={"item_ref":"EHCR004A"}
    ehcr_ehcp_req_outcome           NVARCHAR(100)               -- metadata={"item_ref":"EHCR005A"}
);


-- -- Create constraint(s)
-- ALTER TABLE ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
-- FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_send(send_table_id);

-- Create index(es)



-- -- Insert placeholder data
-- INSERT INTO ssd_ehcp_requests (ehcr_ehcp_request_id, ehcr_send_table_id, ehcr_ehcp_req_date, ehcr_ehcp_req_outcome_date, ehcr_ehcp_req_outcome)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', '1900/01/01', 'SSD_PH');


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_ehcp_assessment
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_ehcp_assessment';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE ssd_ehcp_assessment ;
IF OBJECT_ID('tempdb..#ssd_ehcp_assessment', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_assessment ;


-- Create ssd_ehcp_assessment table
CREATE TABLE ssd_development.ssd_ehcp_assessment (
    ehca_ehcp_assessment_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCA001A"}
    ehca_ehcp_request_id                    NVARCHAR(48),               -- metadata={"item_ref":"EHCA002A"}
    ehca_ehcp_assessment_outcome_date       DATETIME,                   -- metadata={"item_ref":"EHCA003A"}
    ehca_ehcp_assessment_outcome            NVARCHAR(100),              -- metadata={"item_ref":"EHCA004A"}
    ehca_ehcp_assessment_exceptions         NVARCHAR(100)               -- metadata={"item_ref":"EHCA005A"}
);


-- -- Create constraint(s)
-- ALTER TABLE ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
-- FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);

-- Create index(es)



-- -- Insert placeholder data
-- INSERT INTO ssd_ehcp_assessment (ehca_ehcp_assessment_id, ehca_ehcp_request_id, ehca_ehcp_assessment_outcome_date, ehca_ehcp_assessment_outcome, ehca_ehcp_assessment_exceptions)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', 'SSD_PH', 'SSD_PH');





-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));






/* 
=============================================================================
Object Name: ssd_ehcp_named_plan 
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_ehcp_named_plan';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE ssd_ehcp_named_plan;
IF OBJECT_ID('tempdb..#ssd_ehcp_named_plan', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_named_plan;

-- Create structure
CREATE TABLE ssd_development.ssd_ehcp_named_plan (
    ehcn_named_plan_id              NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCN001A"}
    ehcn_ehcp_asmt_id               NVARCHAR(48),               -- metadata={"item_ref":"EHCN002A"}
    ehcn_named_plan_start_date      DATETIME,                   -- metadata={"item_ref":"EHCN003A"}
    ehcn_named_plan_ceased_date     DATETIME,                   -- metadata={"item_ref":"EHCN004A"}     
    ehcn_named_plan_ceased_reason   NVARCHAR(100)               -- metadata={"item_ref":"EHCN005A"}   
);




-- -- Create constraint(s)
-- ALTER TABLE ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
-- FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_ehcp_assessment(ehca_ehcp_assessment_id);

-- Create index(es)



-- -- Insert placeholder data
-- INSERT INTO ssd_ehcp_named_plan (ehcn_named_plan_id, ehcn_ehcp_asmt_id, ehcn_named_plan_start_date, ehcn_named_plan_ceased_date, ehcn_named_plan_ceased_reason)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01', '1900/01/01', 'SSD_PH');


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_ehcp_active_plans
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 1.0
            0.2: -
            0.1: -
Status: [P]laceholder
Remarks:
Dependencies:
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_ehcp_active_plans';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE ssd_ehcp_active_plans  ;
IF OBJECT_ID('tempdb..#ssd_ehcp_active_plans', 'U') IS NOT NULL DROP TABLE #ssd_ehcp_active_plans  ;

-- Create structure
CREATE TABLE ssd_development.ssd_ehcp_active_plans (
    ehcp_active_ehcp_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"EHCP001A"}
    ehcp_ehcp_request_id                NVARCHAR(48),               -- metadata={"item_ref":"EHCP002A"}
    ehcp_active_ehcp_last_review_date   DATETIME                    -- metadata={"item_ref":"EHCP003A"}
);


-- -- Create constraint(s)
-- ALTER TABLE ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
-- FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);


-- -- Insert placeholder data
-- INSERT INTO ssd_ehcp_active_plans (ehcp_active_ehcp_id, ehcp_ehcp_request_id, ehcp_active_ehcp_last_review_date)
-- VALUES ('SSD_PH', 'SSD_PH', '1900/01/01');



/* End

        Non-Core Liquid Logic elements extracts 
        
        */






/* ********************************************************************************************************** */
/* Development clean up */

-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* ********************************************************************************************************** */



/* Start

        Non-SDD Bespoke extract mods
        
        Examples of how to build on the ssd with bespoke additional fields. These can be 
        refreshed|incl. within the rebuild script and rebuilt at the same time as the SSD
        Changes should be limited to additional, non-destructive enhancements that do not
        alter the core structure of the SSD. 
        */




-- /* 
-- =============================================================================
-- MOD Name: involvements history, involvements type history
-- Description: 
-- Author: D2I
-- Version: 0.1
-- Status: [DT]ataTesting
-- Remarks: 
-- Dependencies: 
-- - FACT_INVOLVEMENTS
-- - ssd_person
-- =============================================================================
-- */
-- ALTER TABLE ssd_person
-- ADD involvement_history_json NVARCHAR(4000),  -- Adjust data type as needed
--     involvement_type_story NVARCHAR(1000);  -- Adjust data type as needed


-- -- CTE for involvement history incl. worker data
-- WITH InvolvementHistoryCTE AS (
--     SELECT 
--         fi.DIM_PERSON_ID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.DIM_WORKER_ID END)                          AS CurrentWorkerID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END)    AS AllocatedTeam,
--         MAX(CASE WHEN fi.RecentInvolvement = '16PLUS'   THEN fi.DIM_WORKER_ID END)                          AS PersonalAdvisorID,

--         JSON_QUERY((
--             -- structure of the main|complete invovements history json 
--             SELECT 
--                 fi2.FACT_INVOLVEMENTS_ID                AS 'involvement_id',
--                 fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE    AS 'involvement_type_code',
--                 fi2.START_DTTM                          AS 'start_date', 
--                 fi2.END_DTTM                            AS 'end_date', 
--                 fi2.DIM_WORKER_ID                       AS 'worker_id', 
--                 fi2.DIM_DEPARTMENT_ID                   AS 'department_id'
--             FROM 
--                 Child_Social.FACT_INVOLVEMENTS fi2
--             WHERE 
--                 fi2.DIM_PERSON_ID = fi.DIM_PERSON_ID

--             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--             -- Comment/replace this block(1 of 3)replace the above line with: FOR JSON PATH to enable FULL contact history in _json (involvement_history_json)
--             -- FOR JSON PATH
--             -- end of comment block 1
--         )) AS involvement_history
--     FROM (

--         -- Comment this block(2 of 3) to enable FULL contact history in _json (involvement_history_json)
--         SELECT *,
--             ROW_NUMBER() OVER (
--                 PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
--                 ORDER BY FACT_INVOLVEMENTS_ID DESC
--             ) AS rn,
--             -- end of comment block 2

--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
--         FROM Child_Social.FACT_INVOLVEMENTS
--         WHERE 
--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
--             -- AND END_DTTM IS NULL -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
--             AND DIM_WORKER_ID IS NOT NULL       -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND DIM_WORKER_ID <> -1             -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
--                                                 -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
--     ) fi

--     -- Comment this block(3 of 3) to enable FULL contact history in _json (involvement_history_json)
--     WHERE fi.rn = 1
--     -- end of comment block 3

--     AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
--         SELECT 1 FROM ssd_person p
--         WHERE p.pers_person_id = fi.DIM_PERSON_ID
--     )

--     GROUP BY 
--         fi.DIM_PERSON_ID
-- ),
-- -- CTE for involvement type story
-- InvolvementTypeStoryCTE AS (
--     SELECT 
--         fi.DIM_PERSON_ID,
--         STUFF((
--             -- Concat involvement type codes into string
--             -- cannot use STRING AGG as appears to not work (Needs v2017+)
--             SELECT CONCAT(',', '"', fi3.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '"')
--             FROM Child_Social.FACT_INVOLVEMENTS fi3
--             WHERE fi3.DIM_PERSON_ID = fi.DIM_PERSON_ID

--             AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
--                 SELECT 1 FROM ssd_person p
--                 WHERE p.pers_person_id = fi3.DIM_PERSON_ID
--             )

--             ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
--             FOR XML PATH('')
--         ), 1, 1, '') AS InvolvementTypeStory
--     FROM 
--         Child_Social.FACT_INVOLVEMENTS fi
    
--     WHERE 
--         EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
--             SELECT 1 FROM ssd_person p
--             WHERE p.pers_person_id = fi.DIM_PERSON_ID
--         )
--     GROUP BY 
--         fi.DIM_PERSON_ID
-- )


-- -- Update
-- UPDATE p
-- SET
--     p.involvement_history_json = ih.involvement_history,
--     p.involvement_type_story = CONCAT('[', its.InvolvementTypeStory, ']')
-- FROM ssd_person p
-- LEFT JOIN InvolvementHistoryCTE ih ON p.pers_person_id = ih.DIM_PERSON_ID
-- LEFT JOIN InvolvementTypeStoryCTE its ON p.pers_person_id = its.DIM_PERSON_ID;
