

/* **********************************************************************************************************

Notes: 
This version of the SSD script creates persistant _perm tables. A version that instead creates _temp|session 
tables is also available to enable those restricted to read access on the cms db|schema.   

There remain some [TESTING] [REVIEW] notes as the project works through wider testing, and similarly some test related 
console outputs to aid problem solving during set up. These can/will be later removed. 

/*
Dev Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [A]waitingReview,   -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder
*/

Development notes:
Although returns expect dd/mm/YYYY formating on dates. SSD Extract initially maintains DATETIME not DATE. in [REVIEW]
Extended default field sizes max/exagerated e.g. family_id NVARCHAR(48) in {REVIEW]

********************************************************************************************************** */

/* Development set up */

USE HDM;
GO


/* [TESTING] Set up (to be removed from live v2+)*/
DECLARE @TestProgress INT = 0;
DECLARE @TableName NVARCHAR(128) = N'table_name_placeholder';

-- Query run time vars
DECLARE @StartTime DATETIME, @EndTime DATETIME;
SET @StartTime = GETDATE(); -- Record the start time
/* END [TESTING] (to be removed from live v2+)*/


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
            0.1 Additional inclusion criteria added to capture care leavers 120324 JH
Status: [R]elease
Remarks:    
            Note: Due to part reliance on 903 table, be aware that if 903 not populated pre-ssd run, 
            this/subsequent queries can return v.low|unexpected row counts.
Dependencies:
- Child_Social.DIM_PERSON
- Child_Social.FACT_REFERRALS
- Child_Social.FACT_CONTACTS
- Child_Social.FACT_903_DATA
- Child_Social.FACT_CLA_CARE_LEAVERS
- Child_Social.DIM_CLA_ELIGIBILITY
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_person';
PRINT 'Creating table: ' + @TableName;


-- check exists & drop
IF OBJECT_ID('ssd_person') IS NOT NULL DROP TABLE ssd_person;
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;


-- Create structure
CREATE TABLE ssd_person (
    pers_legacy_id          NVARCHAR(48),               -- item_ref=PERS014A, 
    pers_person_id          NVARCHAR(48) PRIMARY KEY,   -- item_ref=PERS001A,    
    pers_sex                NVARCHAR(48),               -- item_ref=PERS002A, 
    pers_gender             NVARCHAR(48),               -- item_ref=PERS003A,                 
    pers_ethnicity          NVARCHAR(38),
    pers_dob                DATETIME,
    pers_common_child_id    NVARCHAR(10),                   
    pers_upn_unknown        NVARCHAR(10),                                
    pers_send_flag          NVARCHAR(1),
    pers_expected_dob       DATETIME,                   
    pers_death_date         DATETIME,
    pers_is_mother          NVARCHAR(48),
    pers_nationality        NVARCHAR(48)
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
SELECT
    p.LEGACY_ID,
    p.DIM_PERSON_ID,
    p.GENDER_MAIN_CODE,
    p.NHS_NUMBER,                                       -- [PLACEHOLDER] 
    p.ETHNICITY_MAIN_CODE,
        CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM                               -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL END,                                  --  or NULL
    NULL AS pers_common_child_id,                       -- Set to NULL as default(dev) / or set to NHS num
    'SSD_PH',                                 -- [PLACEHOLDER] as f903.NO_UPN_CODE table refresh populated only in reporting period
    p.EHM_SEN_FLAG,
        CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM                               -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL END,                                  --  or NULL
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND              -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI')  -- check for child relation only
        THEN 'Y'
        ELSE NULL -- No child relation found
    END,
    p.NATNL_CODE
   
FROM
    Child_Social.DIM_PERSON AS p
 
-- Removed only to allow [TESTING][PLACEHOLDER]  as 903 table refresh only in reporting period
-- LEFT JOIN
--     Child_Social.FACT_903_DATA f903 ON p.DIM_PERSON_ID = f903.DIM_PERSON_ID
 
WHERE                                                       -- Filter invalid rows
    p.DIM_PERSON_ID IS NOT NULL                                 -- Unlikely, but in case
    AND p.DIM_PERSON_ID >= 1                                    -- Erronous rows with -1 seen
    -- [TESTING] AND f903.YEAR_TO_DATE = 'Y'                    -- 903 table includes children looked after in previous year and year to date,
                                                                -- this filters for those current in the current year to date to avoid duplicates
   
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
        AND (fr.REFRL_START_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fr.REFRL_END_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) OR fr.REFRL_END_DTTM IS NULL)
    )
    OR EXISTS (
        -- care leaver contact in last x@yrs
        SELECT 1 FROM Child_Social.FACT_CLA_CARE_LEAVERS fccl
        WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
        AND fccl.IN_TOUCH_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())
    )
    OR EXISTS (
        -- care leaver eligibility exists
        SELECT 1 FROM Child_Social.DIM_CLA_ELIGIBILITY dce
        WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
        AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
    )
);

 
-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_dob               ON ssd_person(pers_dob);
CREATE NONCLUSTERED INDEX idx_ssd_person_pers_common_child_id   ON ssd_person(pers_common_child_id);
CREATE NONCLUSTERED INDEX idx_ssd_person_ethnicity_gender       ON ssd_person(pers_ethnicity, pers_gender);



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
Description: Contains the family connections for each person
Author: D2I
Version: 1.0
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;


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


WHERE EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fc.DIM_PERSON_ID
    );


-- Create constraint(s)
ALTER TABLE ssd_family ADD CONSTRAINT FK_family_person
FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id);

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
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;


-- Create structure
CREATE TABLE ssd_address (
    addr_table_id           NVARCHAR(48) PRIMARY KEY,
    addr_person_id          NVARCHAR(48), 
    addr_address_type       NVARCHAR(48),
    addr_address_start_date DATETIME,
    addr_address_end_date   DATETIME,
    addr_address_postcode   NVARCHAR(15),
    addr_address_json       NVARCHAR(1000)
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
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = pa.DIM_PERSON_ID
    );

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
            0.1: Removed disability_code replace() into Y/N flag 130324 RH
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;

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
    fd.FACT_DISABILITY_ID       AS disa_table_id, 
    fd.DIM_PERSON_ID            AS disa_person_id, 
    fd.DIM_LOOKUP_DISAB_CODE    AS disa_disability_code
FROM 
    Child_Social.FACT_DISABILITY AS fd

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fd.DIM_PERSON_ID
    );


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
            0.9 rem ims.DIM_LOOKUP_IMMGR_STATUS_DESC rpld with _CODE 270324 JH 
Status: [R]elease
Remarks: Replaced IMMIGRATION_STATUS_CODE with IMMIGRATION_STATUS_DESC and
            increased field size to 100
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
IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;


-- Create structure
CREATE TABLE ssd_immigration_status (
    immi_immigration_status_id              NVARCHAR(48) PRIMARY KEY,
    immi_person_id                          NVARCHAR(48),
    immi_immigration_status_start_date      DATETIME,
    immi_immigration_status_end_date        DATETIME,
    immi_immigration_status                 NVARCHAR(100)
);
 
 
-- insert data
INSERT INTO ssd_immigration_status (
    immi_immigration_status_id,
    immi_person_id,
    immi_immigration_status_start_date,
    immi_immigration_status_end_date,
    immi_immigration_status
)
SELECT
    ims.FACT_IMMIGRATION_STATUS_ID,
    ims.DIM_PERSON_ID,
    ims.START_DTTM,
    ims.END_DTTM,
    ims.DIM_LOOKUP_IMMGR_STATUS_DESC
FROM
    Child_Social.FACT_IMMIGRATION_STATUS AS ims
 
WHERE
    EXISTS
    ( -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE p.pers_person_id = ims.DIM_PERSON_ID
    );


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
            0.2: updated to exclude relationships with an end date 280224 JH
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_mother') IS NOT NULL DROP TABLE #ssd_mother;


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
JOIN
    Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> 'M'
    AND
    fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND
    fpr.END_DTTM IS NULL
 
AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fpr.DIM_PERSON_ID
    );
 
-- Add constraint(s)
ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);

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
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_legal_status') IS NOT NULL DROP TABLE #ssd_legal_status;

-- Create structure
CREATE TABLE ssd_legal_status (
    lega_legal_status_id            NVARCHAR(48) PRIMARY KEY,
    lega_person_id                  NVARCHAR(48),
    lega_legal_status               NVARCHAR(100),
    lega_legal_status_start_date    DATETIME,
    lega_legal_status_end_date      DATETIME
);
 
-- Insert data
INSERT INTO ssd_legal_status (
    lega_legal_status_id,
    lega_person_id,
    lega_legal_status,
    lega_legal_status_start_date,
    lega_legal_status_end_date
 
)
SELECT
    fls.FACT_LEGAL_STATUS_ID,
    fls.DIM_PERSON_ID,
    fls.DIM_LOOKUP_LGL_STATUS_DESC,
    fls.START_DTTM,
    fls.END_DTTM
FROM
    Child_Social.FACT_LEGAL_STATUS AS fls
WHERE EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fls.DIM_PERSON_ID
    );
 
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
            0.2 cont_contact_source_code field name edit 260124 RH
            0.1 cont_contact_source_desc added RH
Status: [R]elease
Remarks:Inclusion in contacts might differ between LAs. 
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
IF OBJECT_ID('ssd_contacts') IS NOT NULL DROP TABLE ssd_contacts;
IF OBJECT_ID('tempdb..#ssd_contacts') IS NOT NULL DROP TABLE #ssd_contacts;


-- Create structure
CREATE TABLE ssd_contacts (
    cont_contact_id             NVARCHAR(48) PRIMARY KEY,
    cont_person_id              NVARCHAR(48),
    cont_contact_date           DATETIME,
    cont_contact_source_code    NVARCHAR(48),   
    cont_contact_source_desc    NVARCHAR(255),  
    cont_contact_outcome_json   NVARCHAR(500) 
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
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC,
    (   -- Create JSON string for the address
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
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fc.DIM_PERSON_ID
    );


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
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_early_help_episodes') IS NOT NULL DROP TABLE #ssd_early_help_episodes;


-- Create structure
CREATE TABLE ssd_early_help_episodes (
    earl_episode_id             NVARCHAR(48) PRIMARY KEY,
    earl_person_id              NVARCHAR(48),
    earl_episode_start_date     DATETIME,
    earl_episode_end_date       DATETIME,
    earl_episode_reason         NVARCHAR(MAX),
    earl_episode_end_reason     NVARCHAR(MAX),
    earl_episode_organisation   NVARCHAR(MAX),
    earl_episode_worker_name    NVARCHAR(100)   
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
    earl_episode_worker_name                    -- consider for removal [TESTING]
)
 
SELECT
    cafe.FACT_CAF_EPISODE_ID,
    cafe.DIM_PERSON_ID,
    cafe.EPISODE_START_DTTM,
    cafe.EPISODE_END_DTTM,
    cafe.START_REASON,
    cafe.DIM_LOOKUP_CAF_EP_ENDRSN_ID_CODE,
    cafe.DIM_LOOKUP_ORIGINATING_ORGANISATION_CODE,
    'SSD_PH'                              -- [PLACEHOLDER_DATA] [TESTING]
FROM
    Child_Social.FACT_CAF_EPISODE AS cafe
 
WHERE EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = cafe.DIM_PERSON_ID
    );


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
            0.1: contact_source_desc added, _source now populated with ID 141223 RH
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_cin_episodes') IS NOT NULL DROP TABLE #ssd_cin_episodes;

-- Create structure
CREATE TABLE ssd_cin_episodes
(
    cine_referral_id            INT,
    cine_person_id              NVARCHAR(48),
    cine_referral_date          DATETIME,
    cine_cin_primary_need       NVARCHAR(10),
    cine_referral_source_code   NVARCHAR(48),    
    cine_referral_source_desc   NVARCHAR(255),
    cine_referral_outcome_json  NVARCHAR(500),
    cine_referral_nfa           NCHAR(1),
    cine_close_reason           NVARCHAR(100),
    cine_close_date             DATETIME,
    cine_referral_team_name     NVARCHAR(255),
    cine_referral_worker_name   NVARCHAR(100)
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
SELECT
    fr.FACT_REFERRAL_ID,
    fr.DIM_PERSON_ID,
    fr.REFRL_START_DTTM,
    fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
    fr.DIM_LOOKUP_CONT_SORC_ID,
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
    DIM_PERSON_ID <> -1;  -- Exclude rows with '-1'
    ;

-- Create constraint(s)
ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id);


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
            0.9: fa.COMPLETED_BY_USER_NAME replaces fa.COMPLETED_BY_USER_STAFF_ID 080524
Status: [R]elease
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
    cina_assessment_id              NVARCHAR(48) PRIMARY KEY,
    cina_person_id                  NVARCHAR(48),
    cina_referral_id                NVARCHAR(48),
    cina_assessment_start_date      DATETIME,
    cina_assessment_child_seen      NCHAR(1), 
    cina_assessment_auth_date       DATETIME,               
    cina_assessment_outcome_json    NVARCHAR(1000),           
    cina_assessment_outcome_nfa     NCHAR(1), 
    cina_assessment_team_name       NVARCHAR(255),
    cina_assessment_worker_name     NVARCHAR(100)
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
SELECT 
    fa.FACT_SINGLE_ASSESSMENT_ID,
    fa.DIM_PERSON_ID,
    fa.FACT_REFERRAL_ID,
    fa.START_DTTM,
    fa.SEEN_FLAG,
    fa.START_DTTM,                 
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
    fa.COMPLETED_BY_DEPT_NAME                               AS cina_assessment_team_name,
    fa.COMPLETED_BY_USER_NAME                               AS cina_assessment_worker_name
FROM 
    Child_Social.FACT_SINGLE_ASSESSMENT AS fa

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fa.DIM_PERSON_ID
    );

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
Status: [R]elease
Remarks: This object referrences some large source tables- Instances of 45m+. 
Dependencies: 
- ssd_cin_assessments
- FACT_SINGLE_ASSESSMENT
- FACT_FORM_ANSWERS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_assessment_factors';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_assessment_factors') IS NOT NULL DROP TABLE ssd_assessment_factors;
IF OBJECT_ID('tempdb..#ssd_assessment_factors') IS NOT NULL DROP TABLE #ssd_assessment_factors;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_assessment_factors') IS NOT NULL DROP TABLE ssd_TMP_PRE_assessment_factors;


-- Create TMP structure with filtered answers
SELECT 
    ffa.FACT_FORM_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
INTO #ssd_TMP_PRE_assessment_factors

FROM 
    Child_Social.FACT_FORM_ANSWERS ffa
WHERE 
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC = 'FAMILY ASSESSMENT'
    AND ffa.ANSWER_NO IN ('1A', '1B', '1C', '2A', '2B', '2C', '3A', '3B', '3C', 
                                  '4A', '4B', '4C', '5A', '5B', '5C', '6A', '6B', '6C', 
                                  '7A', '8B', '8C', '8D', '8E', '8F', '9A', '10A', '11A', 
                                  '12A', '13A', '14A', '15A', '16A', '17A', '18A', '18B', 
                                  '18C', '19A', '19B', '19C', 
                                  '20', '21', 
                                  '22A', '23A', '24A');




-- Create structure
CREATE TABLE ssd_assessment_factors (
    cinf_table_id                    NVARCHAR(48) PRIMARY KEY,
    cinf_assessment_id               NVARCHAR(48),
    cinf_assessment_factors_json     NVARCHAR(1000) -- size might need testing
);

-- Insert data
INSERT INTO ssd_assessment_factors (
               cinf_table_id, 
               cinf_assessment_id, 
               cinf_assessment_factors_json
           )

SELECT 
    fsa.EXTERNAL_ID     AS cinf_table_id, 
    fsa.FACT_FORM_ID    AS cinf_assessment_id,
    (
        SELECT 
            -- 
            CASE WHEN tmp_af.ANSWER_NO = '1A'  THEN tmp_af.ANSWER END AS '1A',
            CASE WHEN tmp_af.ANSWER_NO = '1B'  THEN tmp_af.ANSWER END AS '1B',
            CASE WHEN tmp_af.ANSWER_NO = '1C'  THEN tmp_af.ANSWER END AS '1C',
            CASE WHEN tmp_af.ANSWER_NO = '2A'  THEN tmp_af.ANSWER END AS '2A',
            CASE WHEN tmp_af.ANSWER_NO = '2B'  THEN tmp_af.ANSWER END AS '2B',
            CASE WHEN tmp_af.ANSWER_NO = '2C'  THEN tmp_af.ANSWER END AS '2C',
            CASE WHEN tmp_af.ANSWER_NO = '3A'  THEN tmp_af.ANSWER END AS '3A',
            CASE WHEN tmp_af.ANSWER_NO = '3B'  THEN tmp_af.ANSWER END AS '3B',
            CASE WHEN tmp_af.ANSWER_NO = '3C'  THEN tmp_af.ANSWER END AS '3C',
            CASE WHEN tmp_af.ANSWER_NO = '4A'  THEN tmp_af.ANSWER END AS '4A',
            CASE WHEN tmp_af.ANSWER_NO = '4B'  THEN tmp_af.ANSWER END AS '4B',
            CASE WHEN tmp_af.ANSWER_NO = '4C'  THEN tmp_af.ANSWER END AS '4C',
            CASE WHEN tmp_af.ANSWER_NO = '5A'  THEN tmp_af.ANSWER END AS '5A',
            CASE WHEN tmp_af.ANSWER_NO = '5B'  THEN tmp_af.ANSWER END AS '5B',
            CASE WHEN tmp_af.ANSWER_NO = '5C'  THEN tmp_af.ANSWER END AS '5C',
            CASE WHEN tmp_af.ANSWER_NO = '6A'  THEN tmp_af.ANSWER END AS '6A',
            CASE WHEN tmp_af.ANSWER_NO = '6B'  THEN tmp_af.ANSWER END AS '6B',
            CASE WHEN tmp_af.ANSWER_NO = '6C'  THEN tmp_af.ANSWER END AS '6C',
            CASE WHEN tmp_af.ANSWER_NO = '7A'  THEN tmp_af.ANSWER END AS '7A',
            CASE WHEN tmp_af.ANSWER_NO = '8B'  THEN tmp_af.ANSWER END AS '8B',
            CASE WHEN tmp_af.ANSWER_NO = '8C'  THEN tmp_af.ANSWER END AS '8C',
            CASE WHEN tmp_af.ANSWER_NO = '8D'  THEN tmp_af.ANSWER END AS '8D',
            CASE WHEN tmp_af.ANSWER_NO = '8E'  THEN tmp_af.ANSWER END AS '8E',
            CASE WHEN tmp_af.ANSWER_NO = '8F'  THEN tmp_af.ANSWER END AS '8F',
            CASE WHEN tmp_af.ANSWER_NO = '9A'  THEN tmp_af.ANSWER END AS '9A',
            CASE WHEN tmp_af.ANSWER_NO = '10A' THEN tmp_af.ANSWER END AS '10A',
            CASE WHEN tmp_af.ANSWER_NO = '11A' THEN tmp_af.ANSWER END AS '11A',
            CASE WHEN tmp_af.ANSWER_NO = '12A' THEN tmp_af.ANSWER END AS '12A',
            CASE WHEN tmp_af.ANSWER_NO = '13A' THEN tmp_af.ANSWER END AS '13A',
            CASE WHEN tmp_af.ANSWER_NO = '14A' THEN tmp_af.ANSWER END AS '14A',
            CASE WHEN tmp_af.ANSWER_NO = '15A' THEN tmp_af.ANSWER END AS '15A',
            CASE WHEN tmp_af.ANSWER_NO = '16A' THEN tmp_af.ANSWER END AS '16A',
            CASE WHEN tmp_af.ANSWER_NO = '17A' THEN tmp_af.ANSWER END AS '17A',
            CASE WHEN tmp_af.ANSWER_NO = '18A' THEN tmp_af.ANSWER END AS '18A',
            CASE WHEN tmp_af.ANSWER_NO = '18B' THEN tmp_af.ANSWER END AS '18B',
            CASE WHEN tmp_af.ANSWER_NO = '18C' THEN tmp_af.ANSWER END AS '18C',
            CASE WHEN tmp_af.ANSWER_NO = '19A' THEN tmp_af.ANSWER END AS '19A',
            CASE WHEN tmp_af.ANSWER_NO = '19B' THEN tmp_af.ANSWER END AS '19B',
            CASE WHEN tmp_af.ANSWER_NO = '19C' THEN tmp_af.ANSWER END AS '19C',
            CASE WHEN tmp_af.ANSWER_NO = '20'  THEN tmp_af.ANSWER END AS '20',
            CASE WHEN tmp_af.ANSWER_NO = '21'  THEN tmp_af.ANSWER END AS '21',
            CASE WHEN tmp_af.ANSWER_NO = '22A' THEN tmp_af.ANSWER END AS '22A',
            CASE WHEN tmp_af.ANSWER_NO = '23A' THEN tmp_af.ANSWER END AS '23A',
            CASE WHEN tmp_af.ANSWER_NO = '24A' THEN tmp_af.ANSWER END AS '24A'
        FROM 
            #ssd_TMP_PRE_assessment_factors tmp_af
        WHERE 
            tmp_af.FACT_FORM_ID = fsa.FACT_FORM_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS cinf_assessment_factors_json
FROM 
    Child_Social.FACT_SINGLE_ASSESSMENT fsa
WHERE 
    fsa.EXTERNAL_ID <> -1;


-- Add constraint(s)
ALTER TABLE ssd_assessment_factors ADD CONSTRAINT FK_cinf_assessment_id
FOREIGN KEY (cinf_assessment_id) REFERENCES ssd_cin_assessments(cina_assessment_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX idx_cinf_assessment_id ON ssd_assessment_factors(cinf_assessment_id);




/* issues with join [TESTING]
-- The multi-part identifier "cpd.DIM_OUTCM_CREATE_BY_DEPT_ID" could not be bound. */




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
            0.1: Update fix returning new row for each revision of the plan JH 070224
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_CARE_PLANS
- FACT_CARE_PLAN_SUMMARY
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_plans';
PRINT 'Creating table: ' + @TableName;

-- Check if exists & drop
IF OBJECT_ID('ssd_cin_plans', 'U') IS NOT NULL DROP TABLE ssd_cin_plans;
IF OBJECT_ID('tempdb..#ssd_cin_plans', 'U') IS NOT NULL DROP TABLE #ssd_cin_plans;


-- Create structure
CREATE TABLE ssd_cin_plans (
    cinp_cin_plan_id            NVARCHAR(48) PRIMARY KEY,
    cinp_referral_id            NVARCHAR(48),
    cinp_person_id              NVARCHAR(48),
    cinp_cin_plan_start_date    DATETIME,
    cinp_cin_plan_end_date      DATETIME,
    cinp_cin_plan_team_name     NVARCHAR(255),
    cinp_cin_plan_worker_name   NVARCHAR(100)
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
SELECT
    cps.FACT_CARE_PLAN_SUMMARY_ID      AS cinp_cin_plan_id,
    cps.FACT_REFERRAL_ID               AS cinp_referral_id,
    cps.DIM_PERSON_ID                  AS cinp_person_id,
    cps.START_DTTM                     AS cinp_cin_plan_start_date,
    cps.END_DTTM                       AS cinp_cin_plan_end_date,
 
    (SELECT
        MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
                 THEN fp.DIM_PLAN_COORD_DEPT_ID_DESC END))
 
                                       AS cinp_cin_plan_team_name,
 
    (SELECT
        MAX(CASE WHEN fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID  
                 THEN fp.DIM_PLAN_COORD_ID_DESC END))
                 
                                       AS cinp_cin_plan_worker_name
 
FROM Child_Social.FACT_CARE_PLAN_SUMMARY cps  
 
LEFT JOIN Child_Social.FACT_CARE_PLANS fp ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
 
WHERE DIM_LOOKUP_PLAN_TYPE_CODE = 'FP' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
 
AND EXISTS
(
    -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = cps.DIM_PERSON_ID
)
 
GROUP BY
    cps.FACT_CARE_PLAN_SUMMARY_ID,
    cps.FACT_REFERRAL_ID,
    cps.DIM_PERSON_ID,
    cps.START_DTTM,
    cps.END_DTTM
    ;

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
Status: [R]elease
Remarks:    Source table can be very large! Avoid any unfiltered queries.
            Notes: Does this need to be filtered by only visits in their current Referral episode?
                    however for some this ==2 weeks, others==~17 years
                --> when run for records in ssd_person c.64k records 29s runtime
Dependencies:
- ssd_person
- FACT_CASENOTES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cin_visits';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists, & drop
IF OBJECT_ID('ssd_cin_visits') IS NOT NULL DROP TABLE ssd_cin_visits;
IF OBJECT_ID('tempdb..#ssd_cin_visits') IS NOT NULL DROP TABLE #ssd_cin_visits;
 
-- Create structure
CREATE TABLE ssd_cin_visits
(
    cinv_cin_visit_id           NVARCHAR(48) PRIMARY KEY,      
    cinv_person_id              NVARCHAR(48),
    cinv_cin_visit_date         DATETIME,
    cinv_cin_visit_seen         NCHAR(1),
    cinv_cin_visit_seen_alone   NCHAR(1),
    cinv_cin_visit_bedroom      NCHAR(1)
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
SELECT
    cn.FACT_CASENOTE_ID,                
    cn.DIM_PERSON_ID,
    cn.EVENT_DTTM,
    cn.SEEN_FLAG,
    cn.SEEN_ALONE_FLAG,
    cn.SEEN_BEDROOM_FLAG
FROM
    Child_Social.FACT_CASENOTES cn
 
WHERE
    cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('CNSTAT', 'CNSTATCOVID', 'STAT', 'HVIS', 'DRCT', 'IRO',
    'SUPERCONT', 'STVL', 'STVLCOVID', 'CNSTAT', 'CNSTATCOVID', 'STVC', 'STVCPCOVID')
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = cn.DIM_PERSON_ID
    );
 
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
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_s47_enquiry') IS NOT NULL DROP TABLE #ssd_s47_enquiry;

-- Create structure 
CREATE TABLE ssd_s47_enquiry (
    s47e_s47_enquiry_id                 NVARCHAR(48) PRIMARY KEY,
    s47e_referral_id                    NVARCHAR(48),
    s47e_person_id                      NVARCHAR(48),
    s47e_s47_start_date                 DATETIME,
    s47e_s47_end_date                   DATETIME,
    s47e_s47_nfa                        NCHAR(1),
    s47e_s47_outcome_json               NVARCHAR(1000),
    s47e_s47_completed_by_team_name     NVARCHAR(255),
    s47e_s47_completed_by_worker_name   NVARCHAR(100)
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
    s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team_name,
    s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker_name

FROM 
    Child_Social.FACT_S47 AS s47;

-- Create constraint(s)
ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_s47_person
FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id);

-- Create index(es)
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_person_id     ON ssd_s47_enquiry(s47e_person_id);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_start_date    ON ssd_s47_enquiry(s47e_s47_start_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_end_date      ON ssd_s47_enquiry(s47e_s47_end_date);
CREATE NONCLUSTERED INDEX idx_ssd_s47_enquiry_referral_id   ON ssd_s47_enquiry(s47e_referral_id);





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
Version: 1.0
            0.3 Updated source of CP_PLAN_ID 100424 JH
            0.2 Updated the worker fields 020424 JH
            0.1 Re-instated the worker details 010224 JH
Status: [R]elease
Remarks:
Dependencies:
- FACT_CP_CONFERENCE
- FACT_MEETINGS
- FACT_CP_PLAN
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_initial_cp_conference';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_initial_cp_conference') IS NOT NULL DROP TABLE ssd_initial_cp_conference;
IF OBJECT_ID('tempdb..#ssd_initial_cp_conference') IS NOT NULL DROP TABLE #ssd_initial_cp_conference;
 

-- Create structure
CREATE TABLE ssd_initial_cp_conference (
    icpc_icpc_id                    NVARCHAR(48) PRIMARY KEY,
    icpc_icpc_meeting_id            NVARCHAR(48),
    icpc_s47_enquiry_id             NVARCHAR(48),
    icpc_person_id                  NVARCHAR(48),
    icpc_cp_plan_id                 NVARCHAR(48),
    icpc_referral_id                NVARCHAR(48),
    icpc_icpc_transfer_in           NCHAR(1),
    icpc_icpc_target_date           DATETIME,
    icpc_icpc_date                  DATETIME,
    icpc_icpc_outcome_cp_flag       NCHAR(1),
    icpc_icpc_outcome_json          NVARCHAR(1000),
    icpc_icpc_team_name             NVARCHAR(255),
    icpc_icpc_worker_name           NVARCHAR(100)
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
 
SELECT
    fcpc.FACT_CP_CONFERENCE_ID,
    fcpc.FACT_MEETING_ID,
    fcpc.FACT_S47_ID,
    fcpc.DIM_PERSON_ID,
    fcpp.FACT_CP_PLAN_ID,
    fcpc.FACT_REFERRAL_ID,
    fcpc.TRANSFER_IN_FLAG,
    fcpc.DUE_DTTM,
    fm.ACTUAL_DTTM,
    fcpc.OUTCOME_CP_FLAG,
    (
        SELECT
            NULLIF(fcpc.OUTCOME_NFA_FLAG, '')                       AS "OUTCOME_NFA_FLAG",
            NULLIF(fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG, '')  AS "OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG",
            NULLIF(fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG, '')         AS "OUTCOME_SINGLE_ASSESSMENT_FLAG",
            NULLIF(fcpc.OUTCOME_PROV_OF_SERVICES_FLAG, '')          AS "OUTCOME_PROV_OF_SERVICES_FLAG",
            NULLIF(fcpc.OUTCOME_CP_FLAG, '')                        AS "OUTCOME_CP_FLAG",
            NULLIF(fcpc.OTHER_OUTCOMES_EXIST_FLAG, '')              AS "OTHER_OUTCOMES_EXIST_FLAG",
            NULLIF(fcpc.TOTAL_NO_OF_OUTCOMES, '')                   AS "TOTAL_NO_OF_OUTCOMES",
            NULLIF(fcpc.OUTCOME_COMMENTS, '')                       AS "OUTCOME_COMMENTS"
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )                                                               AS icpc_icpc_outcome_json,
    fcpc.ORGANISED_BY_DEPT_NAME                                     AS icpc_icpc_team_name,
    fcpc.ORGANISED_BY_USER_NAME                                     AS icpc_icpc_worker_name
 
 
FROM
    Child_Social.FACT_CP_CONFERENCE AS fcpc
JOIN
    Child_Social.FACT_MEETINGS AS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
LEFT JOIN
    Child_Social.FACT_CP_PLAN AS fcpp ON fcpc.FACT_CP_CONFERENCE_ID = fcpp.FACT_INITIAL_CP_CONFERENCE_ID
 
WHERE
    fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference'


-- Create constraint(s)
ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_s47_enquiry_id
FOREIGN KEY (icpc_s47_enquiry_id) REFERENCES ssd_s47_enquiry(s47e_s47_enquiry_id);

ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_person_id
FOREIGN KEY (icpc_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_icpc_referral_id
FOREIGN KEY (icpc_referral_id) REFERENCES ssd_cin_episodes(cine_referral_id);


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
            0.3: added IS_OLA field to identify OLA temporary plans
            which need to be excluded from statutory returns 090224 JCH
            0.2: removed depreciated team/worker id fields RH
Status: [R]elease
Remarks:
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
IF OBJECT_ID('tempdb..#ssd_cp_plans') IS NOT NULL DROP TABLE #ssd_cp_plans;

-- Create structure
CREATE TABLE ssd_cp_plans (
    cppl_cp_plan_id                   NVARCHAR(48) PRIMARY KEY,
    cppl_referral_id                  NVARCHAR(48),
    cppl_icpc_id                      NVARCHAR(48), 
    cppl_person_id                    NVARCHAR(48),
    cppl_cp_plan_start_date           DATETIME,
    cppl_cp_plan_end_date             DATETIME,
    cppl_cp_plan_ola                  NVARCHAR(1),        
    cppl_cp_plan_initial_category     NVARCHAR(100),
    cppl_cp_plan_latest_category      NVARCHAR(100)
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
SELECT
    cpp.FACT_CP_PLAN_ID                 AS cppl_cp_plan_id,
    cpp.FACT_REFERRAL_ID                AS cppl_referral_id,
    cpp.FACT_INITIAL_CP_CONFERENCE_ID   AS cppl_icpc_id,
    cpp.DIM_PERSON_ID                   AS cppl_person_id,
    cpp.START_DTTM                      AS cppl_cp_plan_start_date,
    cpp.END_DTTM                        AS cppl_cp_plan_end_date,
    cpp.IS_OLA                          AS cppl_cp_plan_ola,
    cpp.INIT_CATEGORY_DESC              AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC                AS cppl_cp_plan_latest_category
 
FROM
    Child_Social.FACT_CP_PLAN cpp
 
 
WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = cpp.DIM_PERSON_ID
    );


-- Create constraint(s)
ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_person_id
FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_icpc_id
FOREIGN KEY (cppl_icpc_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id);

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
            0.3: (cppv casenote date) removed 070524 RH
            0.2: cppv_person_id added, where claus removed 'STVCPCOVID' 130224 JH
Status: [R]elease
Remarks: Not all CP Visit Casenotes have a link back to the CP Visit -
         using casenote ID as PK and linking to CP Visit where available.
         Will have to use Person ID to link object to Person table
Dependencies:
- FACT_CASENOTES
- FACT_CP_VISIT
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_visits';
PRINT 'Creating table: ' + @TableName;
 
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cp_visits') IS NOT NULL DROP TABLE ssd_cp_visits;
IF OBJECT_ID('tempdb..#ssd_cp_visits') IS NOT NULL DROP TABLE #ssd_cp_visits;
  
 
-- Create structure
CREATE TABLE ssd_cp_visits (
    cppv_cp_visit_id         NVARCHAR(48), 
    cppv_person_id           NVARCHAR(48),
    cppv_cp_plan_id          NVARCHAR(48),
    cppv_cp_visit_date       DATETIME,
    cppv_cp_visit_seen       NCHAR(1),
    cppv_cp_visit_seen_alone NCHAR(1),
    cppv_cp_visit_bedroom    NCHAR(1)
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
 
SELECT
    cn.FACT_CASENOTE_ID     AS cppv_cp_visit_id,  
    p.DIM_PERSON_ID         AS cppv_person_id,            
    cpv.FACT_CP_PLAN_ID     AS cppv_cp_plan_id,  
    cn.EVENT_DTTM           AS cppv_cp_visit_date,
    cn.SEEN_FLAG            AS cppv_cp_visit_seen,
    cn.SEEN_ALONE_FLAG      AS cppv_cp_visit_seen_alone,
    cn.SEEN_BEDROOM_FLAG    AS cppv_cp_visit_bedroom
 
FROM
    Child_Social.FACT_CASENOTES AS cn
 
LEFT JOIN
    Child_Social.FACT_CP_VISIT AS cpv ON cn.FACT_CASENOTE_ID = cpv.FACT_CASENOTE_ID
 
LEFT JOIN
    Child_Social.DIM_PERSON p ON cn.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC'); -- Ref. ( 'STVC','STVCPCOVID')



-- Create constraint(s)
ALTER TABLE ssd_cp_visits ADD CONSTRAINT FK_cppv_to_cppl
FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);

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
            0.1: Resolved issue with linking to Quoracy information 130224 JH
Status: [R]elease
Remarks:    cppr_cp_review_participation - ON HOLD/Not included in SSD Ver/Iteration 1
            Resolved issue with linking to Quoracy information. Added fm.FACT_MEETING_ID
            so users can identify conferences including multiple children. Reviews held
            pre-LCS implementation don't have a CP_PLAN_ID recorded so have added
            cpr.DIM_PERSON_ID for linking reviews to the ssd_cp_plans object.
            Re-named cppr_cp_review_outcome_continue_cp for clarity.
Dependencies:
- ssd_person
- ssd_cp_plans
- FACT_CP_REVIEW
- FACT_MEETINGS
- FACT_MEETING_SUBJECTS
- FACT_FORM_ANSWERS [Participation info - ON HOLD/Not included in SSD Ver/Iteration 1]
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_reviews';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if table exists, & drop
IF OBJECT_ID('ssd_cp_reviews') IS NOT NULL DROP TABLE ssd_cp_reviews;
IF OBJECT_ID('tempdb..#ssd_cp_reviews') IS NOT NULL DROP TABLE #ssd_cp_reviews;
  
 
-- Create structure
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,
    cppr_person_id                      NVARCHAR(48),
    cppr_cp_plan_id                     NVARCHAR(48),    
    cppr_cp_review_due                  DATETIME NULL,
    cppr_cp_review_date                 DATETIME NULL,
    cppr_cp_review_meeting_id           NVARCHAR(48),      
    cppr_cp_review_outcome_continue_cp  NCHAR(1),
    cppr_cp_review_quorate              NVARCHAR(18),      
    cppr_cp_review_participation        NVARCHAR(18)       
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
SELECT
    cpr.FACT_CP_REVIEW_ID                       AS cppr_cp_review_id ,
    cpr.FACT_CP_PLAN_ID                         AS cppr_cp_plan_id,
    cpr.DIM_PERSON_ID                           AS cppr_person_id,
    cpr.DUE_DTTM                                AS cppr_cp_review_due,
    cpr.MEETING_DTTM                            AS cppr_cp_review_date,
    fm.FACT_MEETING_ID                          AS cppr_cp_review_meeting_id,
    cpr.OUTCOME_CONTINUE_CP_FLAG                AS cppr_cp_review_outcome_continue_cp,
    (CASE WHEN ffa.ANSWER_NO = 'WasConf'
        AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
        THEN ffa.ANSWER END)                    AS cppr_cp_review_quorate,    
    'PLACEHOLDER DATA'                          AS cppr_cp_review_participation
 
FROM
    Child_Social.FACT_CP_REVIEW as cpr
 
LEFT JOIN
    Child_Social.FACT_MEETINGS fm               ON cpr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    Child_Social.FACT_MEETING_SUBJECTS fms      ON cpr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND cpr.DIM_PERSON_ID = fms.DIM_PERSON_ID
 
LEFT JOIN    
    Child_Social.FACT_FORM_ANSWERS ffa          ON fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.ANSWER_NO = 'WasConf'
    AND fms.FACT_OUTCM_FORM_ID IS NOT NULL
    AND fms.FACT_OUTCM_FORM_ID <> '-1'
 
LEFT JOIN
    Child_Social.DIM_PERSON p ON cpr.DIM_PERSON_ID = p.DIM_PERSON_ID
 
GROUP BY cpr.FACT_CP_REVIEW_ID,
    cpr.FACT_CP_PLAN_ID,
    cpr.DIM_PERSON_ID,
    cpr.DUE_DTTM,
    cpr.MEETING_DTTM,
    fm.FACT_MEETING_ID,
    cpr.OUTCOME_CONTINUE_CP_FLAG,
    fms.FACT_OUTCM_FORM_ID,
    ffa.ANSWER_NO,
    ffa.FACT_FORM_ID,
    ffa.ANSWER

WHERE EXISTS ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = cpr.DIM_PERSON_ID
    );

-- Add constraint(s)
ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id);

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
            0.9: cla_placement_id added as part of cla_placements review RH 060324
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_involvements
- ssd_person
- FACT_CLA
- FACT_REFERRALS
- FACT_CARE_EPISODES
- FACT_CASENOTES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_episodes';
PRINT 'Creating table: ' + @TableName;


-- Check if table exists, & drop
IF OBJECT_ID('ssd_cla_episodes') IS NOT NULL DROP TABLE ssd_cla_episodes;
IF OBJECT_ID('tempdb..#ssd_cla_episodes') IS NOT NULL DROP TABLE #ssd_cla_episodes;

 
-- Create structure
CREATE TABLE ssd_cla_episodes (
    clae_cla_episode_id                 NVARCHAR(48) PRIMARY KEY,
    clae_person_id                      NVARCHAR(48),
    clae_cla_placement_id               NVARCHAR(48), 
    clae_cla_episode_start_date         DATETIME,
    clae_cla_episode_start_reason       NVARCHAR(100),
    clae_cla_primary_need               NVARCHAR(100),
    clae_cla_episode_ceased             DATETIME,
    clae_cla_episode_ceased_reason      NVARCHAR(255),
    clae_cla_id                         NVARCHAR(48),
    clae_referral_id                    NVARCHAR(48),
    clae_cla_last_iro_contact_date      DATETIME, 
    clae_entered_care_date              DATETIME      
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
SELECT
    fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
    fce.FACT_CLA_PLACEMENT_ID               AS clae_cla_placement_id,
    fce.DIM_PERSON_ID                       AS clae_person_id,
    fce.CARE_START_DATE                     AS clae_cla_episode_start_date,
    fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
    fce.CIN_903_CODE                        AS clae_cla_primary_need,
    fce.CARE_END_DATE                       AS clae_cla_episode_ceased,
    fce.CARE_REASON_END_DESC                AS clae_cla_episode_ceased_reason,
    fc.FACT_CLA_ID                          AS clae_cla_id,                    
    fc.FACT_REFERRAL_ID                     AS clae_referral_id,
        (SELECT MAX(CASE WHEN fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
        --AND cn.DIM_CREATED_BY_DEPT_ID IN (5956,727)
        AND cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
        THEN cn.EVENT_DTTM END))                                                        
                                            AS clae_cla_last_iro_contact_date,
    fc.START_DTTM                           AS clae_entered_care_date -- [TESTING] Added RH 060324
 
FROM
    Child_Social.FACT_CARE_EPISODES AS fce
JOIN
    Child_Social.FACT_CLA AS fc ON fce.FACT_CLA_ID = fc.FACT_CLA_ID
 
LEFT JOIN
    Child_Social.FACT_CASENOTES cn               ON fce.DIM_PERSON_ID = cn.DIM_PERSON_ID

WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fce.DIM_PERSON_ID
    )
 
GROUP BY
    fce.FACT_CARE_EPISODES_ID,
    fce.DIM_PERSON_ID,
    fce.FACT_CLA_PLACEMENT_ID,
    fce.CARE_START_DATE,
    fce.CARE_REASON_DESC,
    fce.CIN_903_CODE,
    fce.CARE_END_DATE,
    fce.CARE_REASON_END_DESC,
    fc.FACT_CLA_ID,                    
    fc.FACT_REFERRAL_ID,
    fc.START_DTTM,
    cn.DIM_PERSON_ID;

-- Add constraint(s)
ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_person 
FOREIGN KEY (clae_person_id) REFERENCES ssd_person (pers_person_id);

ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_cla_placement_id
FOREIGN KEY (clae_cla_placement_id) REFERENCES ssd_cla_placements (clap_cla_placement_id);

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
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_OFFENCE
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_convictions';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE ssd_cla_convictions;
IF OBJECT_ID('tempdb..#ssd_cla_convictions', 'U') IS NOT NULL DROP TABLE #ssd_cla_convictions;


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

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fo.DIM_PERSON_ID
    );


-- add constraint(s)
ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


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
Status: [R]elease
Remarks: 1.5 JH updated source for clah_health_check_type to resolve blanks.
            Updated to use DIM_LOOKUP_EXAM_STATUS_DESC as opposed to _CODE
            to inprove readability.
Dependencies:
- ssd_person
- FACT_HEALTH_CHECK
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_health';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_cla_health', 'U') IS NOT NULL DROP TABLE ssd_cla_health;
IF OBJECT_ID('tempdb..#ssd_cla_health', 'U') IS NOT NULL DROP TABLE #ssd_cla_health;

-- create structure
CREATE TABLE ssd_cla_health (
    clah_health_check_id             NVARCHAR(48) PRIMARY KEY,
    clah_person_id                   NVARCHAR(48),
    clah_health_check_type           NVARCHAR(500),
    clah_health_check_date           DATETIME,
    clah_health_check_status         NVARCHAR(48)
);
 
-- insert data
INSERT INTO ssd_cla_health (
    clah_health_check_id,
    clah_person_id,
    clah_health_check_type,
    clah_health_check_date,
    clah_health_check_status
    )
 
SELECT
    fhc.FACT_HEALTH_CHECK_ID,
    fhc.DIM_PERSON_ID,
    fhc.DIM_LOOKUP_EVENT_TYPE_DESC,
    fhc.START_DTTM,
    fhc.DIM_LOOKUP_EXAM_STATUS_DESC
FROM
    Child_Social.FACT_HEALTH_CHECK as fhc
 
 
WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fhc.DIM_PERSON_ID
    );


-- add constraint(s)
ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

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
            0.2: most recent status reworked / 903 source removed 220224 JH
            0.1: clai_immunisations_status_date removed RH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_CLA
- FACT_903_DATA [Depreciated]
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_immunisations';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_immunisations') IS NOT NULL DROP TABLE ssd_cla_immunisations;
IF OBJECT_ID('tempdb..#ssd_cla_immunisations') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

-- Create structure
CREATE TABLE ssd_cla_immunisations (
    clai_person_id                 NVARCHAR(48) PRIMARY KEY,
    clai_immunisations_status      NCHAR(1),
    clai_immunisations_status_date DATETIME
);

-- CTE rank records by LAST_UPDATED_DTTM (on DIM_PERSON_ID)
;WITH RankedImmunisations AS (
    SELECT
        fcla.DIM_PERSON_ID,
        fcla.IMMU_UP_TO_DATE_FLAG,
        fcla.LAST_UPDATED_DTTM,
        ROW_NUMBER() OVER (
            PARTITION BY fcla.DIM_PERSON_ID -- 
            ORDER BY fcla.LAST_UPDATED_DTTM DESC) AS rn -- rank the order / most recent(rn==1)
    FROM
        Child_Social.FACT_CLA AS fcla
    WHERE
        EXISTS ( -- only ssd relevant records be considered for ranking
            SELECT 1 
            FROM ssd_person p
            WHERE p.pers_person_id = fcla.DIM_PERSON_ID
        )
)
-- Insert data (only most recent/rn==1 records)
INSERT INTO ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)
SELECT
    DIM_PERSON_ID,
    IMMU_UP_TO_DATE_FLAG,
    LAST_UPDATED_DTTM
FROM
    RankedImmunisations
WHERE
    rn = 1; -- pull needed record based on rank==1/most recent record for each DIM_PERSON_ID

-- add constraint(s)
ALTER TABLE ssd_cla_immunisations ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clai_person_id) REFERENCES ssd_person(pers_person_id);

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
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_person
- FACT_SUBSTANCE_MISUSE
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_substance_misuse';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_substance_misuse') IS NOT NULL DROP TABLE ssd_cla_substance_misuse;
IF OBJECT_ID('tempdb..#ssd_cla_substance_misuse') IS NOT NULL DROP TABLE #ssd_cla_substance_misuse;

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

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fSM.DIM_PERSON_ID
    );


-- Add constraint(s)
ALTER TABLE ssd_cla_substance_misuse ADD CONSTRAINT FK_ssd_cla_substance_misuse_clas_person_id 
FOREIGN KEY (clas_person_id) REFERENCES ssd_cla_episodes (clae_person_id);

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
            0.2: 060324 JH
            0.1: Corrected/removal of placement_la & episode_id 090124 RH
Status: [R]elease
Remarks: DEV: filtering for OFSTED_URN LIKE 'SC%'
Dependencies: 
- ssd_person
- FACT_CLA_PLACEMENT
- FACT_CARE_EPISODES
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_placement';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_cla_placement', 'U') IS NOT NULL DROP TABLE ssd_cla_placement;
IF OBJECT_ID('tempdb..#ssd_cla_placement', 'U') IS NOT NULL DROP TABLE #ssd_cla_placement;
  
-- Create structure
CREATE TABLE ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,
    clap_cla_id                         NVARCHAR(48),
    clap_person_id                      NVARCHAR(48),
    clap_cla_placement_start_date       DATETIME,
    clap_cla_placement_type             NVARCHAR(100),
    clap_cla_placement_urn              NVARCHAR(48),
    clap_cla_placement_distance         FLOAT, 
    clap_cla_placement_provider         NVARCHAR(48),
    clap_cla_placement_postcode         NVARCHAR(8),
    clap_cla_placement_end_date         DATETIME,
    clap_cla_placement_change_reason    NVARCHAR(100)
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
SELECT
    fcp.FACT_CLA_PLACEMENT_ID                   AS clap_cla_placement_id,
    fcp.FACT_CLA_ID                             AS clap_cla_id,   
    fcp.DIM_PERSON_ID                           AS clap_person_id,                             
    fcp.START_DTTM                              AS clap_cla_placement_start_date,
    fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE          AS clap_cla_placement_type,
    (
        SELECT
            TOP(1) fce.OFSTED_URN
            FROM   Child_Social.FACT_CARE_EPISODES fce
            WHERE  fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
            AND    fce.OFSTED_URN LIKE 'SC%'
            AND fce.OFSTED_URN IS NOT NULL        
    )                                           AS clap_cla_placement_urn,
 
    TRY_CAST(fcp.DISTANCE_FROM_HOME AS FLOAT)   AS clap_cla_placement_distance,                         -- convert to FLOAT (source col is nvarchar, also holds nulls/ints)
    fcp.DIM_LOOKUP_PLACEMENT_PROVIDER_CODE      AS clap_cla_placement_provider,
 
    CASE -- removal of common/invalid placeholder data i.e ZZZ, XX
        WHEN LEN(LTRIM(RTRIM(fcp.POSTCODE))) <= 4 THEN NULL
        ELSE LTRIM(RTRIM(fcp.POSTCODE))        -- simplistic clean-up
    END                                         AS clap_cla_placement_postcode,
    fcp.END_DTTM                                AS clap_cla_placement_end_date,
    fcp.DIM_LOOKUP_PLAC_CHNG_REAS_CODE          AS clap_cla_placement_change_reason
 
FROM
    Child_Social.FACT_CLA_PLACEMENT AS fcp
 
-- JOIN
--     Child_Social.FACT_CARE_EPISODES AS fce ON fcp.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID    -- [TESTING]
 
WHERE fcp.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A1','A2','A3','A4','A5','A6','F1','F2','F3','F4','F5','F6','H1','H2','H3',
                                            'H4','H5','H5a','K1','K2','M2','M3','P1','P2','Q1','Q2','R1','R2','R3',
                                            'R5','S1','T0','T1','U1','U2','U3','U4','U5','U6','Z1')


-- Add constraint(s)
ALTER TABLE ssd_cla_placement ADD CONSTRAINT FK_clap_to_clae 
FOREIGN KEY (clap_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

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
            0.1: clar_cla_id change from clar cla episode id 120124 JH
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_cla_episodes
- FACT_CLA_REVIEW
- FACT_MEETING_SUBJECTS 
- FACT_MEETINGS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_reviews';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE ssd_cla_reviews;
IF OBJECT_ID('tempdb..#ssd_cla_reviews', 'U') IS NOT NULL DROP TABLE #ssd_cla_reviews;
  
-- Create structure
CREATE TABLE ssd_cla_reviews (
    clar_cla_review_id                      NVARCHAR(48) PRIMARY KEY,
    clar_cla_id                             NVARCHAR(48),
    clar_cla_review_due_date                DATETIME,
    clar_cla_review_date                    DATETIME,
    clar_cla_review_cancelled               NVARCHAR(48),
    clar_cla_review_participation           NVARCHAR(100)
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
 
SELECT
    fcr.FACT_CLA_REVIEW_ID                          AS clar_cla_review_id,
    fcr.FACT_CLA_ID                                 AS clar_cla_id,                
    fcr.DUE_DTTM                                    AS clar_cla_review_due_date,
    fcr.MEETING_DTTM                                AS clar_cla_review_date,
    fm.CANCELLED                                    AS clar_cla_review_cancelled,
 
    (SELECT MAX(CASE WHEN fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
        AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
        THEN fms.DIM_LOOKUP_PARTICIPATION_CODE_DESC END))  
 
                                                    AS clar_cla_review_participation
 
FROM
    Child_Social.FACT_CLA_REVIEW AS fcr
 
LEFT JOIN
    Child_Social.FACT_MEETINGS fm               ON fcr.FACT_MEETING_ID = fm.FACT_MEETING_ID
 
LEFT JOIN
    Child_Social.FACT_MEETING_SUBJECTS fms      ON fcr.FACT_MEETING_ID = fms.FACT_MEETINGS_ID
    AND fms.DIM_PERSON_ID = fcr.DIM_PERSON_ID
 
LEFT JOIN
    Child_Social.FACT_FORMS ff ON fms.FACT_OUTCM_FORM_ID = ff.FACT_FORM_ID
    AND fms.FACT_OUTCM_FORM_ID <> '1071252'     -- duplicate outcomes form for ESCC causing PK error
 
LEFT JOIN
    Child_Social.DIM_PERSON p ON fcr.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE  ff.DIM_LOOKUP_FORM_TYPE_ID_CODE NOT IN ('1391', '1195', '1377', '1540', '2069', '2340')  -- 'LAC / Adoption Outcome Record'
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM #ssd_person p
    WHERE p.pers_person_id = fcr.DIM_PERSON_ID
    )
 
GROUP BY fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID,
    ff.FACT_FORM_ID,
    ff.DIM_LOOKUP_FORM_TYPE_ID_CODE
    ;

-- Add constraint(s)
ALTER TABLE ssd_cla_reviews ADD CONSTRAINT FK_clar_to_clae 
FOREIGN KEY (clar_cla_id) REFERENCES ssd_cla_episodes(clae_cla_id);

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
Status: [R]elease
Remarks: Adapted from 1.3 ver, needs re-test also with Knowsley.
        1.5 JH tmp table was not being referenced, updated query and reduced running
        time considerably, also filtered out rows where ANSWER IS NULL
Dependencies:
- ssd_person
- FACT_903_DATA [depreciated]
- FACT_FORMS
- FACT_FORM_ANSWERS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_previous_permanence';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_previous_permanence') IS NOT NULL DROP TABLE ssd_cla_previous_permanence;
IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_previous_permanence') IS NOT NULL DROP TABLE #ssd_TMP_PRE_previous_permanence;
 
-- Create TMP structure with filtered answers
SELECT
    ffa.FACT_FORM_ID,
    ffa.FACT_FORM_ANSWER_ID,
    ffa.ANSWER_NO,
    ffa.ANSWER
 
INTO #ssd_TMP_PRE_previous_permanence
FROM
    Child_Social.FACT_FORM_ANSWERS ffa
WHERE
    ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'
    AND
    ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG')
    AND
    ffa.ANSWER IS NOT NULL
 


-- Create structure
CREATE TABLE ssd_cla_previous_permanence (
    lapp_table_id                               NVARCHAR(48) PRIMARY KEY,
    lapp_person_id                              NVARCHAR(48),
    lapp_previous_permanence_option             NVARCHAR(200),
    lapp_previous_permanence_la                 NVARCHAR(100),
    lapp_previous_permanence_order_date         NVARCHAR(10)
);
 
-- Insert data
INSERT INTO ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date
           )
SELECT
    tmp_ffa.FACT_FORM_ID AS lapp_table_id,
    ff.DIM_PERSON_ID AS lapp_person_id,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'PREVADOPTORD' THEN tmp_ffa.ANSWER END), NULL) AS lapp_previous_permanence_option,
    COALESCE(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'INENG'        THEN tmp_ffa.ANSWER END), NULL) AS lapp_previous_permanence_la,
    CASE 
        WHEN PATINDEX('%[^0-9]%', MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END)) = 0 AND 
             CAST(MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END) AS INT) BETWEEN 1 AND 31 THEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERDATE' THEN tmp_ffa.ANSWER END) 
        ELSE 'zz' 
    END + '/' + 
 -- Adjusted CASE statement for ORDERMONTH to convert month names to numbers
    CASE 
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('January', 'Jan')  THEN '01'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('February', 'Feb') THEN '02'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('March', 'Mar')    THEN '03'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('April', 'Apr')    THEN '04'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('May')             THEN '05'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('June', 'Jun')     THEN '06'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('July', 'Jul')     THEN '07'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('August', 'Aug')   THEN '08'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('September', 'Sep') THEN '09'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('October', 'Oct')  THEN '10'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('November', 'Nov') THEN '11'
        WHEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERMONTH' THEN tmp_ffa.ANSWER END) IN ('December', 'Dec') THEN '12'
        ELSE 'zz' -- also handles 'unknown' string
    END + '/' + 
    CASE 
        WHEN PATINDEX('%[^0-9]%', MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END)) = 0 THEN MAX(CASE WHEN tmp_ffa.ANSWER_NO = 'ORDERYEAR' THEN tmp_ffa.ANSWER END) 
        ELSE 'zzzz' 
    END
    AS lapp_previous_permanence_order_date
FROM
    #ssd_TMP_PRE_previous_permanence tmp_ffa
JOIN
    Child_Social.FACT_FORMS ff ON tmp_ffa.FACT_FORM_ID = ff.FACT_FORM_ID
 
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = ff.DIM_PERSON_ID
    )
 
GROUP BY tmp_ffa.FACT_FORM_ID, ff.FACT_FORM_ID, ff.DIM_PERSON_ID;
 
-- Add constraint(s)
ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


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
            0.1: Altered _json keys and groupby towards > clarity 190224 JH
Status: [R]elease
Remarks:    Added short codes to plan type questions to improve readability.
            Removed form type filter, only filtering ffa. on ANSWER_NO.
Dependencies:
- FACT_CARE_PLANS
- FACT_FORMS
- FACT_FORM_ANSWERS
- #ssd_TMP_PRE_cla_care_plan - Used to stage/prep most recent relevant form response
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_care_plan';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE ssd_cla_care_plan;
IF OBJECT_ID('tempdb..#ssd_cla_care_plan', 'U') IS NOT NULL DROP TABLE #ssd_cla_care_plan;

IF OBJECT_ID('tempdb..#ssd_TMP_PRE_cla_care_plan') IS NOT NULL DROP TABLE #ssd_TMP_PRE_cla_care_plan;
 
 
WITH MostRecentQuestionResponse AS (
    SELECT  -- Return the most recent response for each question for each persons
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM
        Child_Social.FACT_FORM_ANSWERS ffa
    JOIN
        Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID    -- obtain the relevant person_id
    WHERE
        ffa.ANSWER_NO    IN ('CPFUP1', 'CPFUP10', 'CPFUP2', 'CPFUP3', 'CPFUP4', 'CPFUP5', 'CPFUP6', 'CPFUP7', 'CPFUP8', 'CPFUP9')
    GROUP BY
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO
),
LatestResponses AS (
    SELECT  -- Now add the answered_date (only indirectly of use here/cross referencing)
        mrqr.DIM_PERSON_ID,
        mrqr.ANSWER_NO,
        mrqr.MaxFormID AS FACT_FORM_ID,
        ffa.ANSWER,
        ffa.ANSWERED_DTTM AS LatestResponseDate
    FROM
        MostRecentQuestionResponse mrqr
    JOIN
        Child_Social.FACT_FORM_ANSWERS ffa ON mrqr.MaxFormID = ffa.FACT_FORM_ID AND mrqr.ANSWER_NO = ffa.ANSWER_NO
)
 
SELECT
    -- Add the now aggregated reponses into tmp table
    lr.FACT_FORM_ID,
    lr.DIM_PERSON_ID,
    lr.ANSWER_NO,
    lr.ANSWER,
    lr.LatestResponseDate
INTO #ssd_TMP_PRE_cla_care_plan
FROM
    LatestResponses lr
ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;
 
 
-- Create structure
CREATE TABLE ssd_cla_care_plan (
    lacp_table_id                       NVARCHAR(48) PRIMARY KEY,
    lacp_person_id                      NVARCHAR(48),
    lacp_cla_care_plan_start_date       DATETIME,
    lacp_cla_care_plan_end_date         DATETIME,
    lacp_cla_care_plan_json             NVARCHAR(1000)
);
 
-- Insert data
INSERT INTO ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)
SELECT
    fcp.FACT_CARE_PLAN_ID          AS lacp_table_id,
    fcp.DIM_PERSON_ID              AS lacp_person_id,
    fcp.START_DTTM                 AS lacp_cla_care_plan_start_date,
    fcp.END_DTTM                   AS lacp_cla_care_plan_end_date,
    (
        SELECT  -- Combined _json field with 'ICP' responses
               
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END), NULL) AS REMAINSUP,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END), NULL) AS RETURN1M,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END), NULL) AS RETURN6M,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END), NULL) AS RETURNEV,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END), NULL) AS LTRELFR,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END), NULL) AS LTFOST18,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END), NULL) AS RESPLMT,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END), NULL) AS SUPPLIV,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END), NULL) AS ADOPTION,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END), NULL) AS OTHERPLN
   
        FROM
            #ssd_TMP_PRE_cla_care_plan tmp_cpl
 
        WHERE
            tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
 
        GROUP BY tmp_cpl.DIM_PERSON_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS lacp_cla_care_plan_json
 
FROM
    Child_Social.FACT_CARE_PLANS AS fcp
 
 
WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A';
 

-- Add constraint(s)
ALTER TABLE ssd_cla_care_plan ADD CONSTRAINT FK_lacp_person_id
FOREIGN KEY (lacp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);
 
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
Version: 1.0!
            !0.3: Prep for casenote_id to be removed... not yet actioned RH
            0.2: FK updated to person_id. change from clav.VISIT_DTTM  150224 JH
            0.1: pers_person_id and clav_cla_id  added JH
Status: [R]elease
Remarks:
Dependencies:
- FACT_CARE_EPISODES
- FACT_CASENOTES
- FACT_CLA_VISIT
=============================================================================
*/
 
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_visits';
PRINT 'Creating table: ' + @TableName;
 
-- Check if exists & drop
IF OBJECT_ID('ssd_cla_visits', 'U') IS NOT NULL DROP TABLE ssd_cla_visits;
IF OBJECT_ID('tempdb..#ssd_cla_visits', 'U') IS NOT NULL DROP TABLE #ssd_cla_visits;


-- Create structure
CREATE TABLE ssd_cla_visits (
    clav_cla_visit_id          NVARCHAR(48) PRIMARY KEY,
    clav_cla_id                NVARCHAR(48),
    clav_person_id             NVARCHAR(48),
    clav_cla_visit_date        DATETIME,
    clav_cla_visit_seen        NCHAR(1),
    clav_cla_visit_seen_alone  NCHAR(1)
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
 
SELECT
    clav.FACT_CLA_VISIT_ID      AS clav_cla_visit_id,
    clav.FACT_CLA_ID            AS clav_cla_id,
    clav.DIM_PERSON_ID          AS clav_person_id,
    cn.EVENT_DTTM               AS clav_cla_visit_date,
    cn.SEEN_FLAG                AS clav_cla_visit_seen,
    cn.SEEN_ALONE_FLAG          AS clav_cla_visit_seen_alone
 
FROM
    Child_Social.FACT_CLA_VISIT AS clav
 
LEFT JOIN
    Child_Social.FACT_CASENOTES AS cn ON  clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
    AND clav.DIM_PERSON_ID = cn.DIM_PERSON_ID
 
LEFT JOIN
    Child_Social.DIM_PERSON p ON   clav.DIM_PERSON_ID = p.DIM_PERSON_ID
 
WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVL')
 
AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = clav.DIM_PERSON_ID
    );



-- Add constraint(s)
ALTER TABLE ssd_cla_visits ADD CONSTRAINT FK_clav_person_id
FOREIGN KEY (clav_person_id) REFERENCES ssd_cla_episodes(clae_person_id);

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
Status: [R]elease
Remarks: ASSESSMENT_TEMPLATE_ID_CODEs ranges validated at 12/12/23
        Removed csdq_form_id as the form id is also being used as csdq_table_id
        Added placeholder for csdq_sdq_reason
        Removed PRIMARY KEY stipulation for csdq_table_id
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
IF OBJECT_ID('tempdb..#ssd_sdq_scores', 'U') IS NOT NULL DROP TABLE #ssd_sdq_scores;
 

/* V8.1 */
-- Create structure
CREATE TABLE ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48), 
    csdq_person_id              NVARCHAR(48),
    csdq_sdq_score              NVARCHAR(48),
    csdq_sdq_completed_date     DATETIME,
    csdq_sdq_details_json       NVARCHAR(1000),
    csdq_sdq_reason             NVARCHAR(48)
);
 
-- Insert data
INSERT INTO ssd_sdq_scores (
    csdq_table_id,
    csdq_person_id,
    csdq_sdq_score,
    csdq_sdq_completed_date,
    csdq_sdq_details_json,
    csdq_sdq_reason
)
SELECT
    ff.FACT_FORM_ID         AS csdq_table_id,
    ff.DIM_PERSON_ID        AS csdq_person_id,
    (
        SELECT TOP 1
            CASE
                WHEN ISNUMERIC(ffa_inner.ANSWER) = 1 THEN CAST(ffa_inner.ANSWER AS INT)
                ELSE NULL
            END
        FROM Child_Social.FACT_FORM_ANSWERS ffa_inner
        WHERE ffa_inner.FACT_FORM_ID = ff.FACT_FORM_ID
            AND ffa_inner.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
            AND ffa_inner.ANSWER_NO = 'SDQScore'
            AND ffa_inner.ANSWER IS NOT NULL
        ORDER BY ffa_inner.ANSWER DESC -- Using the date as it is
    ) AS csdq_sdq_score,
    '1900/01/01'         AS csdq_sdq_completed_date,
    (
        SELECT
            CASE WHEN ffa_inner.ANSWER_NO = 'FormEndDate'
            THEN ffa_inner.ANSWER END AS "SDQ_COMPLETED_DATE",
            CASE WHEN ffa_inner.ANSWER_NO = 'SDQScore'
            THEN
                CASE WHEN ISNUMERIC(ffa_inner.ANSWER) = 1 THEN CAST(ffa_inner.ANSWER AS INT) ELSE NULL END
            END AS "SDQ_SCORE"
        FROM Child_Social.FACT_FORM_ANSWERS ffa_inner
        WHERE ff.FACT_FORM_ID = ffa_inner.FACT_FORM_ID
            AND ffa_inner.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
            AND ffa_inner.ANSWER_NO IN ('FormEndDate','SDQScore')
            AND ffa_inner.ANSWER IS NOT NULL
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS csdq_sdq_details_json,
    'SSD_PH'      AS csdq_sdq_reason
   
FROM
    Child_Social.FACT_FORMS ff
JOIN
    Child_Social.FACT_FORM_ANSWERS ffa ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
    AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE 'Strengths and Difficulties Questionnaire%'
    AND ffa.ANSWER_NO IN ('FormEndDate','SDQScore')
    AND ffa.ANSWER IS NOT NULL
WHERE EXISTS (
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = ff.DIM_PERSON_ID
);
 
 
-- Ensure the previous statement is terminated
;WITH RankedSDQScores AS (
    SELECT
        *,
        -- Assign unique row nums <within each partition> of csdq_person_id,
        -- the most recent csdq_form_id/csdq_table_id will have a row number of 1.
        ROW_NUMBER() OVER (PARTITION BY csdq_person_id ORDER BY csdq_table_id DESC) AS rn
    FROM
        ssd_sdq_scores
)
 
-- delete all records from the ssd_sdq_scores table where row number(rn) > 1
-- i.e. keep only the most recent
DELETE FROM RankedSDQScores
WHERE rn > 1;
 
-- identify and remove exact dups
;WITH DuplicateSDQScores AS (
    SELECT
        *,
        -- Assign row num to each set of dups,
        -- partitioned by all columns that could potentially make a row unique
        ROW_NUMBER() OVER (PARTITION BY csdq_table_id, csdq_person_id, csdq_sdq_details_json ORDER BY csdq_table_id) AS row_num
    FROM
        ssd_sdq_scores
)
-- Delete dups
DELETE FROM DuplicateSDQScores
WHERE row_num > 1;
 
 
-- -- [TESTING]
-- select * from ssd_sdq_scores
-- order by csdq_person_id desc, csdq_table_id desc;
 
-- non-spec column clean-up
ALTER TABLE ssd_sdq_scores DROP COLUMN csdq_sdq_score;

/* end V8.1 */


-- Add constraint(s)
ALTER TABLE ssd_sdq_scores ADD CONSTRAINT FK_csdq_person_id
FOREIGN KEY (csdq_person_id) REFERENCES ssd_person(pers_person_id);

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
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_missing', 'U') IS NOT NULL DROP TABLE #ssd_missing;

-- Create structure
CREATE TABLE ssd_missing (
    miss_table_id                       NVARCHAR(48) PRIMARY KEY,
    miss_person_id                      NVARCHAR(48),
    miss_missing_episode_start_date     DATETIME,
    miss_missing_episode_type           NVARCHAR(100),
    miss_missing_episode_end_date       DATETIME,
    miss_missing_rhi_offered            NVARCHAR(10),                   
    miss_missing_rhi_accepted           NVARCHAR(10)                   
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
SELECT 
    fmp.FACT_MISSING_PERSON_ID          AS miss_table_id,
    fmp.DIM_PERSON_ID                   AS miss_person_id,
    fmp.START_DTTM                      AS miss_missing_episode_start_date,
    fmp.MISSING_STATUS                  AS miss_missing_episode_type,
    fmp.END_DTTM                        AS miss_missing_episode_end_date,
    fmp.RETURN_INTERVIEW_OFFERED        AS miss_missing_rhi_offered,   
    fmp.RETURN_INTERVIEW_ACCEPTED       AS miss_missing_rhi_accepted 
FROM 
    Child_Social.FACT_MISSING_PERSON AS fmp

WHERE EXISTS 
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = fmp.DIM_PERSON_ID
    );


-- Add constraint(s)
ALTER TABLE ssd_missing ADD CONSTRAINT FK_missing_to_person
FOREIGN KEY (miss_person_id) REFERENCES ssd_person(pers_person_id);

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
            0.3: change of main source to DIM_CLA_ELIGIBILITY in order to capture full care leaver cohort 12/03/24 JH
            0.2: switch field _worker)nm and _team_nm around as in wrong order RH
            0.1: worker/p.a id field changed to descriptive name towards AA reporting JH
Status: [R]elease
Remarks:    Dev: Note that <multiple> refs to ssd_person need changing when porting code to tempdb.. versions.
            Dev: Ensure index on ssd_person.pers_person_id is intact to ensure performance on <FROM ssd_person> references in the CTEs(added for performance)
            Dev: Revised V3/4 to aid performance on large involvements table aggr
Dependencies:
- FACT_INVOLVEMENTS
- FACT_CLA_CARE_LEAVERS
- DIM_CLA_ELIGIBILITY
- FACT_CARE_PLANS
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_care_leavers';
PRINT 'Creating table: ' + @TableName;
 
 
-- Check if exists & drop
IF OBJECT_ID('ssd_care_leavers', 'U') IS NOT NULL DROP TABLE ssd_care_leavers;
IF OBJECT_ID('tempdb..#ssd_care_leavers', 'U') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
 
-- Create structure
CREATE TABLE ssd_care_leavers
(
    clea_table_id                           NVARCHAR(48),
    clea_person_id                          NVARCHAR(48),
    clea_care_leaver_eligibility            NVARCHAR(100),
    clea_care_leaver_in_touch               NVARCHAR(100),
    clea_care_leaver_latest_contact         DATETIME,
    clea_care_leaver_accommodation          NVARCHAR(100),
    clea_care_leaver_accom_suitable         NVARCHAR(100),
    clea_care_leaver_activity               NVARCHAR(100),
    clea_pathway_plan_review_date           DATETIME,
    clea_care_leaver_personal_advisor       NVARCHAR(100),
    clea_care_leaver_allocated_team_name    NVARCHAR(255),
    clea_care_leaver_worker_name            NVARCHAR(100)        
);
 
/* V4 */
-- CTE for involvement history incl. worker data
-- aggregate/extract current worker infos, allocated team, and p.advisor ID
WITH InvolvementHistoryCTE AS (
    SELECT
        fi.DIM_PERSON_ID,
        -- worker, alloc team, and p.advisor dets <<per involvement type>>
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.DIM_WORKER_NAME END)                      AS CurrentWorkerName,  -- c.w name for the 'CW' inv type
        MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END)  AS AllocatedTeamName,  -- team desc for the 'CW' inv type
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_NAME END)                  AS PersonalAdvisorName -- p.a. for the '16PLUS' inv type
    FROM (
        SELECT *,
            -- Assign a row number, partition by p + inv type
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
            -- Mark the involvement type ('CW' or '16PLUS')
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM Child_Social.FACT_INVOLVEMENTS
        WHERE
            -- Filter records to just 'CW' and '16PLUS' inv types
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS')
                                                    -- Switched off in v1.6 [TESTING]
            -- AND END_DTTM IS NULL                 -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
            -- AND DIM_WORKER_ID IS NOT NULL        -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND DIM_WORKER_ID <> -1                 -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
 
            -- where the inv type is 'CW' + flagged as allocated
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
                                                    -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
    ) fi
 
    -- aggregate the result(s)
    GROUP BY
        fi.DIM_PERSON_ID
)
 
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
 
SELECT
    CONCAT(dce.DIM_CLA_ELIGIBILITY_ID, fccl.FACT_CLA_CARE_LEAVERS_ID)
              AS clea_table_id,
    dce.DIM_PERSON_ID                                       AS clea_person_id,
    CASE WHEN
        dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NULL
        THEN 'No Current Eligibility'
        ELSE dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC END     AS clea_care_leaver_eligibility,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE                      AS clea_care_leaver_in_touch,
    fccl.IN_TOUCH_DTTM                                      AS clea_care_leaver_latest_contact,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC                 AS clea_care_leaver_accommodation,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC             AS clea_care_leaver_accom_suitable,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC                      AS clea_care_leaver_activity,
 
    MAX(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
        AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH'
        THEN fcp.MODIF_DTTM END)                            AS clea_pathway_plan_review_date,
 
    ih.PersonalAdvisorName                                  AS clea_care_leaver_personal_advisor,
    ih.AllocatedTeamName                                    AS clea_care_leaver_allocated_team_name,
    ih.CurrentWorkerName                                    AS clea_care_leaver_worker_name
 
FROM
    Child_Social.DIM_CLA_ELIGIBILITY AS dce
 
LEFT JOIN Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID    -- towards clea_care_leaver_in_touch, _latest_contact, _accommodation, _accom_suitable and _activity
 
LEFT JOIN Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID           -- towards clea_pathway_plan_review_date
               
LEFT JOIN Child_Social.DIM_PERSON p ON dce.DIM_PERSON_ID = p.DIM_PERSON_ID                        -- towards LEGACY_ID for testing only
 
LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID                     -- connect with CTE aggr data      
 
WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = dce.DIM_PERSON_ID
    )
 
GROUP BY
    dce.DIM_CLA_ELIGIBILITY_ID,
    fccl.FACT_CLA_CARE_LEAVERS_ID,
    p.LEGACY_ID,  
    dce.DIM_PERSON_ID,
    dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE,
    fccl.IN_TOUCH_DTTM,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC,
    ih.PersonalAdvisorName,
    ih.CurrentWorkerName,
    ih.AllocatedTeamName          
    ;


-- Add constraint(s)
ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leavers_person
FOREIGN KEY (clea_person_id) REFERENCES ssd_person(pers_person_id);


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
            0.5: perm_placed_foster_carer_date placeholder re-added 240424 RH
            0.4: worker_name field name change for consistency 100424 JH
            0.3: entered_care_date removed/moved to cla_episodes 060324 RH
            0.2: perm_placed_foster_carer_date (from fc.START_DTTM) removed RH
            0.1: perm_adopter_sex, perm_adopter_legal_status added RH
Status: [R]elease
Remarks: 
        DEV: 181223: Assumed that only one permanence order per child. 
        - In order to handle/reflect the v.rare cases where this has broken down, further work is required.

        DEV: Some fields need spec checking for datatypes e.g. perm_adopted_by_carer_flag and others

Dependencies: 
- ssd_person
- FACT_ADOPTION
- FACT_CLA_PLACEMENT
- FACT_LEGAL_STATUS
- FACT_CARE_EPISODES
- FACT_CLA
=============================================================================
*/

-- [TESTING] Create marker
SET @TableName = N'ssd_permanence';
PRINT 'Creating table: ' + @TableName;


-- Check if exists & drop
IF OBJECT_ID('ssd_permanence', 'U') IS NOT NULL DROP TABLE ssd_permanence;
IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

-- Create structure
CREATE TABLE ssd_permanence (
    perm_table_id                        NVARCHAR(48) PRIMARY KEY,
    perm_person_id                       NVARCHAR(48),
    perm_cla_id                          NVARCHAR(48),
    perm_adm_decision_date               DATETIME,
    perm_part_of_sibling_group           NCHAR(1),
    perm_siblings_placed_together        INT,
    perm_siblings_placed_apart           INT,
    perm_ffa_cp_decision_date            DATETIME,              
    perm_placement_order_date            DATETIME,
    perm_matched_date                    DATETIME,
    perm_adopter_sex                     NVARCHAR(48),
    perm_adopter_legal_status            NVARCHAR(100),
    perm_number_of_adopters              INT,
    perm_placed_for_adoption_date        DATETIME,             
    perm_adopted_by_carer_flag           NCHAR(1),
    perm_placed_foster_carer_date        DATETIME,
    perm_placed_ffa_cp_date              DATETIME,
    perm_placement_provider_urn          NVARCHAR(48),  
    perm_decision_reversed_date          DATETIME,                  
    perm_decision_reversed_reason        NVARCHAR(100),
    perm_permanence_order_date           DATETIME,              
    perm_permanence_order_type           NVARCHAR(100),        
    perm_adoption_worker_name            NVARCHAR(100)
    
);


WITH RankedPermanenceData AS (
    -- CTE to rank permanence rows for each person
    -- used to assist in dup filtering on/towards perm_table_id

    SELECT
        CASE 
            WHEN (fa.DIM_PERSON_ID = fce.DIM_PERSON_ID)
            THEN CONCAT(fa.FACT_ADOPTION_ID, fce.FACT_CARE_EPISODES_ID)
            ELSE fce.FACT_CARE_EPISODES_ID 
        END                                               AS perm_table_id,
        p.LEGACY_ID                                       AS perm_person_id,
        fce.FACT_CLA_ID                                   AS perm_cla_id,
        fa.DECISION_DTTM                                  AS perm_adm_decision_date,              
        fa.SIBLING_GROUP                                  AS perm_part_of_sibling_group,
        fa.NUMBER_TOGETHER                                AS perm_siblings_placed_together,
        fa.NUMBER_APART                                   AS perm_siblings_placed_apart,              
        fcpl.FFA_IS_PLAN_DATE                             AS perm_ffa_cp_decision_date,
        fa.PLACEMENT_ORDER_DTTM                           AS perm_placement_order_date,
        fa.MATCHING_DTTM                                  AS perm_matched_date,
        fa.DIM_LOOKUP_ADOPTER_GENDER_CODE                 AS perm_adopter_sex,
        fa.DIM_LOOKUP_ADOPTER_LEGAL_STATUS_CODE           AS perm_adopter_legal_status,
        fa.NO_OF_ADOPTERS                                 AS perm_number_of_adopters,
        CASE 
            WHEN fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3','A4','A5','A6')
            THEN fcpl.START_DTTM 
            ELSE NULL 
        END                                               AS perm_placed_for_adoption_date,
        fa.ADOPTED_BY_CARER_FLAG                          AS perm_adopted_by_carer_flag,
        '1900/01/01'                                      AS perm_placed_foster_carer_date,         -- [PLACEHOLDER_DATA] [TESTING]
        fa.FOSTER_TO_ADOPT_DTTM                           AS perm_placed_ffa_cp_date,
        CASE 
            WHEN fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3','A4','A5','A6')
            THEN fce.OFSTED_URN 
            ELSE NULL 
        END                                               AS perm_placement_provider_urn,
        fa.NO_LONGER_PLACED_DTTM                          AS perm_decision_reversed_date,
        fa.DIM_LOOKUP_ADOP_REASON_CEASED_CODE             AS perm_decision_reversed_reason,
        fce.PLACEND                                       AS perm_permanence_order_date,
        CASE
            WHEN fce.CARE_REASON_END_CODE IN ('E1', 'E12', 'E11') THEN 'Adoption'
            WHEN fce.CARE_REASON_END_CODE IN ('E48', 'E44', 'E43', '45', 'E45', 'E47', 'E46') THEN 'Special Guardianship Order'
            WHEN fce.CARE_REASON_END_CODE IN ('45', 'E41') THEN 'Child Arrangements/ Residence Order'
            ELSE NULL
        END                                               AS perm_permanence_order_type,
        fa.ADOPTION_SOCIAL_WORKER_NAME                    AS perm_adoption_worker_name,
        ROW_NUMBER() OVER (
            PARTITION BY p.LEGACY_ID                     -- partition on person identifier
            ORDER BY CAST(RIGHT(CASE 
                                    WHEN (fa.DIM_PERSON_ID = fce.DIM_PERSON_ID)
                                    THEN CONCAT(fa.FACT_ADOPTION_ID, fce.FACT_CARE_EPISODES_ID)
                                    ELSE fce.FACT_CARE_EPISODES_ID 
                                END, 5) AS INT) DESC    -- take last 5 digits, coerce to int so we can sort/order
        )                                                 AS rn -- we only want rn==1
    FROM Child_Social.FACT_CARE_EPISODES fce
    LEFT JOIN Child_Social.FACT_ADOPTION AS fa ON fa.DIM_PERSON_ID = fce.DIM_PERSON_ID AND fa.START_DTTM IS NOT NULL
    LEFT JOIN Child_Social.FACT_CLA AS fc ON fc.FACT_CLA_ID = fce.FACT_CLA_ID -- [TESTING] IS this still requ if fc.START_DTTM not in use here? 
    LEFT JOIN Child_Social.FACT_CLA_PLACEMENT AS fcpl ON fcpl.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
        AND fcpl.FACT_CLA_PLACEMENT_ID <> '-1'
        AND (fcpl.DIM_LOOKUP_PLACEMENT_TYPE_CODE IN ('A3', 'A4', 'A5', 'A6') OR fcpl.FFA_IS_PLAN_DATE IS NOT NULL)
    LEFT JOIN Child_Social.DIM_PERSON p ON fce.DIM_PERSON_ID = p.DIM_PERSON_ID
    WHERE ((fce.PLACEND IS NULL AND fa.START_DTTM IS NOT NULL)
        OR fce.CARE_REASON_END_CODE IN ('E48', 'E1', 'E44', 'E12', 'E11', 'E43', '45', 'E41', 'E45', 'E47', 'E46'))
        AND fce.DIM_PERSON_ID <> '-1'

        -- -- Exclusion block commented for further [TESTING] 
        -- AND EXISTS ( -- ssd records only
        --     SELECT 1
        --     FROM ssd_person p
        --     WHERE p.pers_person_id = fce.DIM_PERSON_ID
        -- )

)

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


SELECT
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

FROM RankedPermanenceData
WHERE rn = 1
AND EXISTS
    ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = perm_person_id
    );



-- Add constraint(s)
ALTER TABLE ssd_permanence ADD CONSTRAINT FK_perm_person_id
FOREIGN KEY (perm_person_id) REFERENCES ssd_cla_episodes(clae_person_id);


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
            0.9: prof_professional_id now becomes staff_id 090424 JH
            0.8: prof_table_id(prof_system_id) becomes prof_professional_id 090424 JH
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_professionals', 'U') IS NOT NULL DROP TABLE #ssd_professionals;


-- Determine/Define date on which CASELOAD count required (Currently: September 30th)
SET @LastSept30th = CASE 
                        WHEN CONVERT(DATE, GETDATE()) > DATEFROMPARTS(YEAR(GETDATE()), 9, 30) 
                        THEN DATEFROMPARTS(YEAR(GETDATE()), 9, 30)
                        ELSE DATEFROMPARTS(YEAR(GETDATE()) - 1, 9, 30)
                    END;


-- Create structure
CREATE TABLE ssd_professionals (
    prof_professional_id                  NVARCHAR(48) PRIMARY KEY,
    prof_staff_id                         NVARCHAR(48),
    prof_professional_name                NVARCHAR(300),
    prof_social_worker_registration_no    NVARCHAR(48),
    prof_agency_worker_flag               NCHAR(1),
    prof_professional_job_title           NVARCHAR(500),
    prof_professional_caseload            INT,              
    prof_professional_department          NVARCHAR(100),
    prof_full_time_equivalency            FLOAT
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

SELECT 
    dw.DIM_WORKER_ID                        AS prof_professional_id,
    dw.STAFF_ID                             AS prof_staff_id,
    CONCAT(dw.SURNAME, ' ', dw.FORENAME)    AS prof_professional_name,              -- used also as Allocated Worker|Assigned Worker
    dw.WORKER_ID_CODE                       AS prof_social_worker_registration_no,
    ''                                      AS prof_agency_worker_flag,             -- Not available in SSD Ver/Iteration 1 [TESTING] [PLACEHOLDER_DATA]
    dw.JOB_TITLE                            AS prof_professional_job_title,
    ISNULL(rc.OpenCases, 0)                 AS prof_professional_caseload,          -- 0 when no open cases on given date.
    dw.DEPARTMENT_NAME                      AS prof_professional_department,
    dw.FULL_TIME_EQUIVALENCY                AS prof_full_time_equivalency
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


-- Add constraint(s)

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
            0.9: added person_id and changed source of professional_team 090424 JH
Status: [R]elease
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
IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
-- Create structure
CREATE TABLE ssd_involvements (
    invo_involvements_id             NVARCHAR(48) PRIMARY KEY,
    invo_professional_id             NVARCHAR(48),
    invo_professional_role_id        NVARCHAR(200),
    invo_professional_team           NVARCHAR(1000),
    invo_person_id                   NVARCHAR(48),
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
    invo_person_id,
    invo_involvement_start_date,
    invo_involvement_end_date,
    invo_worker_change_reason,
    invo_referral_id
)
SELECT
    fi.FACT_INVOLVEMENTS_ID                       AS invo_involvements_id,
    fi.DIM_WORKER_ID                              AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    -- use first non-NULL value for prof team, in order of depat, grp, or relevant comment
    COALESCE(
        fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC,   -- prev/relevant dept name if available
        fi.DIM_DEPARTMENT_NAME,                   -- otherwise, use existing dept name
        fi.DIM_GROUP_NAME,                        -- then, use wider grp name if the above are NULL

        CASE -- if still NULL, refer into comments data
            WHEN fi.COMMENTS LIKE '%WORKER%' OR fi.COMMENTS LIKE '%ALLOC%' -- refer to comments for specific keywords
            THEN fi.COMMENTS 
        END -- if fi.COMMENTS is NULL, results in NULL
    )                                              AS invo_professional_team,
    fi.DIM_PERSON_ID                              AS invo_person_id,
    fi.START_DTTM                                 AS invo_involvement_start_date,
    fi.END_DTTM                                   AS invo_involvement_end_date,
    fi.DIM_LOOKUP_CWREASON_CODE                   AS invo_worker_change_reason,
    fi.FACT_REFERRAL_ID                           AS invo_referral_id
FROM
    Child_Social.FACT_INVOLVEMENTS AS fi
WHERE EXISTS
    (
    SELECT 1
    FROM ssd_person p
    WHERE p.pers_person_id = fi.DIM_PERSON_ID
    );




-- Add constraint(s)
ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional 
FOREIGN KEY (invo_professional_id) REFERENCES ssd_professionals (prof_professional_id);

ALTER TABLE ssd_involvements ADD CONSTRAINT FK_invo_to_professional_role 
FOREIGN KEY (invo_professional_role_id) REFERENCES ssd_professionals (prof_social_worker_registration_no);



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
CREATE TABLE ssd_linked_identifiers (
    link_table_id            NVARCHAR(48) PRIMARY KEY DEFAULT NEWID(),
    link_person_id          NVARCHAR(48), 
    link_identifier_type    NVARCHAR(100),
    link_identifier_value   NVARCHAR(100),
    link_valid_from_date    DATETIME,
    link_valid_to_date      DATETIME
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


-- Create constraint(s)
ALTER TABLE ssd_linked_identifiers ADD CONSTRAINT FK_link_to_person 
FOREIGN KEY (link_person_id) REFERENCES ssd_person(pers_person_id);

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
CREATE TABLE ssd_s251_finance (
    s251_table_id           NVARCHAR(48) PRIMARY KEY,
    s251_cla_placement_id   NVARCHAR(48), 
    s251_placeholder_1      NVARCHAR(48),
    s251_placeholder_2      NVARCHAR(48),
    s251_placeholder_3      NVARCHAR(48),
    s251_placeholder_4      NVARCHAR(48)
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

-- Create constraint(s)
ALTER TABLE ssd_s251_finance ADD CONSTRAINT FK_s251_to_cla_placement 
FOREIGN KEY (s251_cla_placement_id) REFERENCES ssd_cla_placement(clap_cla_placement_id);

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
CREATE TABLE ssd_voice_of_child (
    voch_table_id               NVARCHAR(48) PRIMARY KEY,
    voch_person_id              NVARCHAR(48), 
    voch_explained_worries      NCHAR(1), 
    voch_story_help_understand  NCHAR(1), 
    voch_agree_worker           NCHAR(1), 
    voch_plan_safe              NCHAR(1), 
    voch_tablet_help_explain    NCHAR(1)
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

-- Create constraint(s)
ALTER TABLE ssd_voice_of_child ADD CONSTRAINT FK_voch_to_person 
FOREIGN KEY (voch_person_id) REFERENCES ssd_person(pers_person_id);


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
Status: [P]laceholder
Remarks: 
Dependencies: 
- Yet to be defined
- ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_pre_proceedings';
PRINT 'Creating table: ' + @TableName;


-- Check if exists, & drop
IF OBJECT_ID('ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE ssd_pre_proceedings;
IF OBJECT_ID('tempdb..#ssd_pre_proceedings', 'U') IS NOT NULL DROP TABLE #ssd_pre_proceedings;

-- Create structure
CREATE TABLE ssd_pre_proceedings (
    prep_table_id                           NVARCHAR(48) PRIMARY KEY,
    prep_person_id                          NVARCHAR(48),
    prep_plo_family_id                      NVARCHAR(48),
    prep_pre_pro_decision_date              DATETIME,
    prep_initial_pre_pro_meeting_date       DATETIME,
    prep_pre_pro_outcome                    NVARCHAR(100),
    prep_agree_stepdown_issue_date          DATETIME,
    prep_cp_plans_referral_period           INT, 
    prep_legal_gateway_outcome              NVARCHAR(100),
    prep_prev_pre_proc_child                INT,
    prep_prev_care_proc_child               INT,
    prep_pre_pro_letter_date                DATETIME,
    prep_care_pro_letter_date               DATETIME,
    prep_pre_pro_meetings_num               INT,
    prep_pre_pro_parents_legal_rep          NCHAR(1), 
    prep_parents_legal_rep_point_of_issue   NCHAR(2),
    prep_court_reference                    NVARCHAR(48),
    prep_care_proc_court_hearings           INT,
    prep_care_proc_short_notice             NCHAR(1), 
    prep_proc_short_notice_reason           NVARCHAR(100),
    prep_la_inital_plan_approved            NCHAR(1), 
    prep_la_initial_care_plan               NVARCHAR(100),
    prep_la_final_plan_approved             NCHAR(1), 
    prep_la_final_care_plan                 NVARCHAR(100)
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

-- Create constraint(s)
ALTER TABLE ssd_pre_proceedings ADD CONSTRAINT FK_prep_to_person 
FOREIGN KEY (prep_person_id) REFERENCES ssd_person(pers_person_id);

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
Status: [P]laceholder
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
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL DROP TABLE #ssd_send;

-- Create structure 
CREATE TABLE ssd_send (
    send_table_id       NVARCHAR(48) PRIMARY KEY,
    send_person_id      NVARCHAR(48),
    send_upn            NVARCHAR(48),
    send_uln            NVARCHAR(48),
    send_upn_unknown    NVARCHAR(48)
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
 

-- Add constraint(s)
ALTER TABLE ssd_send ADD CONSTRAINT FK_send_to_person 
FOREIGN KEY (send_person_id) REFERENCES ssd_person(pers_person_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/*
=============================================================================
Object Name: ssd_sen_need
Description: Placeholder structure as source data not common|confirmed
Author: D2I
Version: 0.1
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
CREATE TABLE ssd_sen_need (
    senn_table_id                       NVARCHAR(48) PRIMARY KEY,
    senn_active_ehcp_id                 NVARCHAR(48),
    senn_active_ehcp_need_type          NVARCHAR(100),
    senn_active_ehcp_need_rank          NVARCHAR(1)
);
 
-- Create constraint(s)
ALTER TABLE ssd_sen_need ADD CONSTRAINT FK_send_to_ehcp_active_plans
FOREIGN KEY (senn_active_ehcp_id) REFERENCES ssd_ehcp_active_plans(pers_person_id);

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
Version: 0.1
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
CREATE TABLE ssd_ehcp_requests (
    ehcr_ehcp_request_id            NVARCHAR(48) PRIMARY KEY,
    ehcr_send_table_id              NVARCHAR(48),
    ehcr_ehcp_req_date              DATETIME,
    ehcr_ehcp_req_outcome_date      DATETIME,
    ehcr_ehcp_req_outcome           NVARCHAR(100)
);


-- Create constraint(s)
ALTER TABLE ssd_ehcp_requests ADD CONSTRAINT FK_ehcp_requests_send
FOREIGN KEY (ehcr_send_table_id) REFERENCES ssd_send(send_table_id);

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
Version: 0.1
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
CREATE TABLE ssd_ehcp_assessment (
    ehca_ehcp_assessment_id             NVARCHAR(48) PRIMARY KEY,
    ehca_ehcp_request_id                NVARCHAR(48),
    ehca_ehcp_assessment_outcome_date   DATETIME,
    ehca_ehcp_assessment_outcome        NVARCHAR(100),
    ehca_ehcp_assessment_exceptions     NVARCHAR(100)
);


-- Create constraint(s)
ALTER TABLE ssd_ehcp_assessment ADD CONSTRAINT FK_ehcp_assessment_requests
FOREIGN KEY (ehca_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);

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
Version: 0.1
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
CREATE TABLE ssd_ehcp_named_plan (
    ehcn_named_plan_id                  NVARCHAR(48),
    ehcn_ehcp_asmt_id                   NVARCHAR(48),
    ehcn_named_plan_start_date          DATETIME,
    ehcn_named_plan_ceased_date         DATETIME,      
    ehcn_named_plan_ceased_reason       NVARCHAR(100)   
);




-- Create constraint(s)
ALTER TABLE ssd_ehcp_named_plan ADD CONSTRAINT FK_ehcp_named_plan_assessment
FOREIGN KEY (ehcn_ehcp_asmt_id) REFERENCES ssd_ehcp_assessment(ehca_ehcp_assessment_id);

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
Version: 0.1
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
CREATE TABLE ssd_ehcp_active_plans (
    ehcp_active_ehcp_id                 NVARCHAR(48),
    ehcp_ehcp_request_id                NVARCHAR(48),
    ehcp_active_ehcp_last_review_date   DATETIME
);


-- Create constraint(s)
ALTER TABLE ssd_ehcp_active_plans ADD CONSTRAINT FK_ehcp_active_plans_requests
FOREIGN KEY (ehcp_ehcp_request_id) REFERENCES ssd_ehcp_requests(ehcr_ehcp_request_id);


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




/* 
=============================================================================
MOD Name: involvements history, involvements type history
Description: 
Author: D2I
Version: 0.1
Status: [DT]ataTesting
Remarks: 
Dependencies: 
- FACT_INVOLVEMENTS
- ssd_person
=============================================================================
*/
ALTER TABLE ssd_person
ADD involvement_history_json NVARCHAR(4000),  -- Adjust data type as needed
    involvement_type_story NVARCHAR(1000);  -- Adjust data type as needed


-- CTE for involvement history incl. worker data
WITH InvolvementHistoryCTE AS (
    SELECT 
        fi.DIM_PERSON_ID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.DIM_WORKER_ID END)                          AS CurrentWorkerID,
        MAX(CASE WHEN fi.RecentInvolvement = 'CW'       THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END)    AS AllocatedTeam,
        MAX(CASE WHEN fi.RecentInvolvement = '16PLUS'   THEN fi.DIM_WORKER_ID END)                          AS PersonalAdvisorID,

        JSON_QUERY((
            -- structure of the main|complete invovements history json 
            SELECT 
                fi2.FACT_INVOLVEMENTS_ID                AS 'involvement_id',
                fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE    AS 'involvement_type_code',
                fi2.START_DTTM                          AS 'start_date', 
                fi2.END_DTTM                            AS 'end_date', 
                fi2.DIM_WORKER_ID                       AS 'worker_id', 
                fi2.DIM_DEPARTMENT_ID                   AS 'department_id'
            FROM 
                Child_Social.FACT_INVOLVEMENTS fi2
            WHERE 
                fi2.DIM_PERSON_ID = fi.DIM_PERSON_ID

            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            -- Comment/replace this block(1 of 3)replace the above line with: FOR JSON PATH to enable FULL contact history in _json (involvement_history_json)
            -- FOR JSON PATH
            -- end of comment block 1
        )) AS involvement_history
    FROM (

        -- Comment this block(2 of 3) to enable FULL contact history in _json (involvement_history_json)
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
            -- end of comment block 2

            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM Child_Social.FACT_INVOLVEMENTS
        WHERE 
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
            -- AND END_DTTM IS NULL -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
            AND DIM_WORKER_ID IS NOT NULL       -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND DIM_WORKER_ID <> -1             -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
                                                -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
    ) fi

    -- Comment this block(3 of 3) to enable FULL contact history in _json (involvement_history_json)
    WHERE fi.rn = 1
    -- end of comment block 3

    AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
        SELECT 1 FROM ssd_person p
        WHERE p.pers_person_id = fi.DIM_PERSON_ID
    )

    GROUP BY 
        fi.DIM_PERSON_ID
),
-- CTE for involvement type story
InvolvementTypeStoryCTE AS (
    SELECT 
        fi.DIM_PERSON_ID,
        STUFF((
            -- Concat involvement type codes into string
            -- cannot use STRING AGG as appears to not work (Needs v2017+)
            SELECT CONCAT(',', '"', fi3.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '"')
            FROM Child_Social.FACT_INVOLVEMENTS fi3
            WHERE fi3.DIM_PERSON_ID = fi.DIM_PERSON_ID

            AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
                SELECT 1 FROM ssd_person p
                WHERE p.pers_person_id = fi3.DIM_PERSON_ID
            )

            ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
            FOR XML PATH('')
        ), 1, 1, '') AS InvolvementTypeStory
    FROM 
        Child_Social.FACT_INVOLVEMENTS fi
    
    WHERE 
        EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
            SELECT 1 FROM ssd_person p
            WHERE p.pers_person_id = fi.DIM_PERSON_ID
        )
    GROUP BY 
        fi.DIM_PERSON_ID
)


-- Update
UPDATE p
SET
    p.involvement_history_json = ih.involvement_history,
    p.involvement_type_story = CONCAT('[', its.InvolvementTypeStory, ']')
FROM ssd_person p
LEFT JOIN InvolvementHistoryCTE ih ON p.pers_person_id = ih.DIM_PERSON_ID
LEFT JOIN InvolvementTypeStoryCTE its ON p.pers_person_id = its.DIM_PERSON_ID;