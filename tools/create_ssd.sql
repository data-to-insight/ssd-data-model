

/*
-- person table
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND  TABLE_NAME = 'person')
BEGIN
    SELECT 
        p.[EXTERNAL_ID] as la_person_id,
        p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE] as person_sex,
        p.[GENDER_MAIN_CODE] as person_gender,
        p.[ETHNICITY_MAIN_CODE] as person_ethnicity,
        p.[BIRTH_DTTM] as person_dob,
        p.[UPN] as person_upn,
        p.[NO_UPN_CODE] as person_upn_unknown,
        p.[EHM_SEN_FLAG] as person_send,
        p.[DOB_ESTIMATED] as person_expected_dob,
        p.[DEATH_DTTM] as person_death_date,
        p.[NATNL_CODE] as person_nationality,
        CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END as person_is_mother

    INTO Child_Social.person
    FROM 
        Child_Social.DIM_PERSON AS p
    LEFT JOIN
        Child_Social.FACT_CPIS_UPLOAD AS fc
    ON 
        p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
    ORDER BY
        p.[EXTERNAL_ID] ASC;

    -- Add primary key constraint
    ALTER TABLE Child_Social.person
    ADD PRIMARY KEY (la_person_id);
    
    -- Create a non-clustered index on la_person_id for quicker lookups and joins
    CREATE INDEX IDX_person_la_person_id ON Child_Social.person(la_person_id);
END;
*/


/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#person') IS NOT NULL DROP TABLE #person;

-- Create the temp table #person
SELECT 
    p.[EXTERNAL_ID] as la_person_id,
    p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE] as person_sex,
    p.[GENDER_MAIN_CODE] as person_gender,
    p.[ETHNICITY_MAIN_CODE] as person_ethnicity,
    p.[BIRTH_DTTM] as person_dob,
    p.[UPN] as person_upn,
    p.[NO_UPN_CODE] as person_upn_unknown,
    p.[EHM_SEN_FLAG] as person_send,
    p.[DOB_ESTIMATED] as person_expected_dob,
    p.[DEATH_DTTM] as person_death_date,
    p.[NATNL_CODE] as person_nationality,
    CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END as person_is_mother
INTO #person
FROM 
    Child_Social.DIM_PERSON AS p
LEFT JOIN
    Child_Social.FACT_CPIS_UPLOAD AS fc
ON 
    p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
ORDER BY
    p.[EXTERNAL_ID] ASC;

-- Add primary key constraint to temp table
ALTER TABLE #person
ADD PRIMARY KEY (la_person_id);
    
-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_person_la_person_id ON #person(la_person_id);
/* END TMP TABLE */




/*
-- family table
-- part of early help system(s). set blank template out
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND  TABLE_NAME = 'family')
BEGIN

    -- Create the 'family' table
    CREATE TABLE Child_Social.family (
        family_id NVARCHAR(MAX) PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        
        -- Define the foreign key constraint
        FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id)
    );

    -- Create a non-clustered index on the foreign key
    CREATE INDEX IDX_family_person ON Child_Social.family(la_person_id);
END;
*/

/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#family') IS NOT NULL 
    DROP TABLE #family;

-- Create the temp table #family
CREATE TABLE #family (
    family_id NVARCHAR(MAX) PRIMARY KEY,
    la_person_id NVARCHAR(MAX)
);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_family_person ON #family(la_person_id);
/* END TMP TABLE */




/*
-- address table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'address')
BEGIN
    -- Create the address table if it doesn't exist
    SELECT 
        pa.[DIM_PERSON_ADDRESS_ID] as address_id,
        pa.[EXTERNAL_ID] as la_person_id, -- Assuming EXTERNAL_ID corresponds to la_person_id
        pa.[ADDSS_TYPE_CODE] as address_type,
        pa.[START_DTTM] as address_start,
        pa.[END_DTTM] as address_end,
        pa.[POSTCODE] as address_postcode,
        
        -- Create the concatenated address field
        CONCAT_WS(',', 
            NULLIF(pa.[ROOM_NO], ''), 
            NULLIF(pa.[FLOOR_NO], ''), 
            NULLIF(pa.[FLAT_NO], ''), 
            NULLIF(pa.[BUILDING], ''), 
            NULLIF(pa.[HOUSE_NO], ''), 
            NULLIF(pa.[STREET], ''), 
            NULLIF(pa.[TOWN], '')
        ) as address

    INTO 
        Child_Social.address

    FROM 
        Child_Social.DIM_PERSON_ADDRESS AS pa
    ORDER BY
        pa.[EXTERNAL_ID] ASC;

    -- Set the primary key on address_id
    ALTER TABLE Child_Social.address
    ADD CONSTRAINT PK_address_id
    PRIMARY KEY (address_id);

    -- Add the foreign key constraint for la_person_id
    ALTER TABLE Child_Social.address
    ADD CONSTRAINT FK_address_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Non-clustered index on the foreign key
    CREATE INDEX IDX_address_person 
    ON Child_Social.address(la_person_id);

    -- Non-clustered indexes on address_start and address_end
    CREATE INDEX IDX_address_start 
    ON Child_Social.address(address_start);

    CREATE INDEX IDX_address_end 
    ON Child_Social.address(address_end);
END

*/

/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#address') IS NOT NULL DROP TABLE #address;

-- Create the temp table #address
-- Create the temp table #address
SELECT 
    pa.[DIM_PERSON_ADDRESS_ID] as address_id,
    pa.[EXTERNAL_ID] as la_person_id, -- Assuming EXTERNAL_ID corresponds to la_person_id
    pa.[ADDSS_TYPE_CODE] as address_type,
    pa.[START_DTTM] as address_start,
    pa.[END_DTTM] as address_end,
    pa.[POSTCODE] as address_postcode,
        
    -- Create the concatenated address field
    CONCAT_WS(',', 
        NULLIF(pa.[ROOM_NO], ''), 
        NULLIF(pa.[FLOOR_NO], ''), 
        NULLIF(pa.[FLAT_NO], ''), 
        NULLIF(pa.[BUILDING], ''), 
        NULLIF(pa.[HOUSE_NO], ''), 
        NULLIF(pa.[STREET], ''), 
        NULLIF(pa.[TOWN], '')
    ) as address

INTO #address
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa
ORDER BY
    pa.[EXTERNAL_ID] ASC;

-- Add primary key constraint to address_id
ALTER TABLE #address
ADD CONSTRAINT PK_address_id
PRIMARY KEY (address_id);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_address_person ON #address(la_person_id);

-- Non-clustered indexes on address_start and address_end
CREATE INDEX IDX_address_start ON #address(address_start);
CREATE INDEX IDX_address_end ON #address(address_end);
/* END TMP TABLE */




/*
-- disability table 
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'disability')
BEGIN
    -- Create the disability table if it doesn't exist
    SELECT 
        fd.[FACT_DISABILITY_ID] as disability_id,
        fd.[EXTERNAL_ID] as la_person_id,
        fd.[DISABILITY_GROUP_CODE] as person_disability

    INTO 
        Child_Social.disability

    FROM 
        Child_Social.FACT_DISABILITY AS fd

    ORDER BY
        fd.[EXTERNAL_ID] ASC;

    -- Set the primary key on disability_id
    ALTER TABLE Child_Social.disability
    ADD CONSTRAINT PK_disability_id
    PRIMARY KEY (disability_id);

    -- Add the foreign key constraint
    ALTER TABLE Child_Social.disability
    ADD CONSTRAINT FK_disability_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Index the foreign key
    CREATE INDEX IDX_disability_la_person_id ON Child_Social.disability(la_person_id);
END
*/

/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#disability') IS NOT NULL 
    DROP TABLE #disability;

-- Create the temp table #disability
SELECT 
    fd.[FACT_DISABILITY_ID] as disability_id,
    fd.[EXTERNAL_ID] as la_person_id,
    fd.[DISABILITY_GROUP_CODE] as person_disability

INTO #disability
FROM 
    Child_Social.FACT_DISABILITY AS fd
ORDER BY
    fd.[EXTERNAL_ID] ASC;

-- Add primary key constraint to disability_id
ALTER TABLE #disability
ADD CONSTRAINT PK_disability_id
PRIMARY KEY (disability_id);

-- Add foreign key constraint to la_person_id referencing person.la_person_id
ALTER TABLE #disability
ADD CONSTRAINT FK_disability_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_disability_la_person_id ON #disability(la_person_id);

/* END TMP TABLE */




/*
-- immigration_status table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'immigration_status')
BEGIN
    -- Create the immigration_status table if it doesn't exist
    SELECT 
        is.[FACT_IMMIGRATION_STATUS_ID] as immigration_status_id,
        is.[EXTERNAL_ID] as la_person_id,
        is.[START_DTTM] as immigration_status_start,
        is.[END_DTTM] as immigration_status_end,
        is.[DIM_LOOKUP_IMMGR_STATUS_CODE] as immigration_status

    INTO 
        Child_Social.immigration_status

    FROM 
        Child_Social.FACT_IMMIGRATION_STATUS AS is

    ORDER BY
        is.[EXTERNAL_ID] ASC;

    -- Set the primary key on immigration_status_id
    ALTER TABLE Child_Social.immigration_status
    ADD CONSTRAINT PK_immigration_status_id
    PRIMARY KEY (immigration_status_id);

    -- Add the foreign key constraint
    ALTER TABLE Child_Social.immigration_status
    ADD CONSTRAINT FK_immigration_status_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Index the foreign key
    CREATE INDEX IDX_immigration_status_la_person_id 
    ON Child_Social.immigration_status(la_person_id);

    -- Non-clustered index on immigration_status_start
    CREATE INDEX IDX_immigration_status_start 
    ON Child_Social.immigration_status(immigration_status_start);

    -- Non-clustered index on immigration_status_end
    CREATE INDEX IDX_immigration_status_end 
    ON Child_Social.immigration_status(immigration_status_end);
END
*/

/* TEMP TABLE DEF */
IF OBJECT_ID('tempdb..#immigration_status') IS NOT NULL DROP TABLE #immigration_status;
-- Create the immigration_status table if it doesn't exist
SELECT 
    is.[FACT_IMMIGRATION_STATUS_ID] as immigration_status_id,
    is.[EXTERNAL_ID] as la_person_id,
    is.[START_DTTM] as immigration_status_start,
    is.[END_DTTM] as immigration_status_end,
    is.[DIM_LOOKUP_IMMGR_STATUS_CODE] as immigration_status

INTO 
    #immigration_status

FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS is

ORDER BY
    is.[EXTERNAL_ID] ASC;

-- Set the primary key on immigration_status_id
ALTER TABLE #immigration_status
ADD CONSTRAINT PK_immigration_status_id
PRIMARY KEY (immigration_status_id);

-- Add the foreign key constraint
ALTER TABLE #immigration_status
ADD CONSTRAINT FK_immigration_status_person
FOREIGN KEY (la_person_id) REFERENCES #person(la_person_id);

-- Index the foreign key
CREATE INDEX IDX_immigration_status_la_person_id 
ON #immigration_status(la_person_id);

-- Non-clustered index on immigration_status_start
CREATE INDEX IDX_immigration_status_start 
ON #immigration_status(immigration_status_start);

-- Non-clustered index on immigration_status_end
CREATE INDEX IDX_immigration_status_end 
ON #immigration_status(immigration_status_end);
/* END TMP TABLE DEF */





/*
-- contact table
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'contact')
BEGIN

    -- Create the contact table
    SELECT
        fc.[FACT_CONTACT_ID] as contact_id,
        fc.[EXTERNAL_ID] as la_person_id,
        fc.[START_DTTM] as contact_start,
        fc.[SOURCE_CONTACT] as contact_source,
        fc.[CONTACT_OUTCOMES] as contact_outcome

    INTO Child_Social.contact

    FROM 
        Child_Social.FACT_CONTACT AS fc

    ORDER BY
        fc.[EXTERNAL_ID] ASC;

    -- Add primary key constraint to contact_id
    ALTER TABLE Child_Social.contact
    ADD CONSTRAINT PK_contact_id
    PRIMARY KEY (contact_id);

    -- Add foreign key relationship to person.la_person_id
    ALTER TABLE Child_Social.contact
    ADD CONSTRAINT FK_contact_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Create a non-clustered index on la_person_id for quicker lookups and joins
    CREATE INDEX IDX_contact_person ON Child_Social.contact(la_person_id);
END;

*/

/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#contact') IS NOT NULL DROP TABLE #contact;

-- Create the temp table #contact
SELECT
	fc.[FACT_CONTACT_ID] as contact_id,
	fc.[EXTERNAL_ID] as la_person_id,
    fc.[START_DTTM] as contact_start,
    fc.[SOURCE_CONTACT] as contact_source,
	fc.[CONTACT_OUTCOMES] as contact_outcome

INTO #contact

FROM 
    Child_Social.FACT_CONTACT AS fc

ORDER BY
    fc.[EXTERNAL_ID] ASC;

-- Add primary key constraint to contact_id
ALTER TABLE #contact
ADD CONSTRAINT PK_contact_id
PRIMARY KEY (contact_id);

-- Add foreign key relationship to person.la_person_id
ALTER TABLE #contact
ADD CONSTRAINT FK_contact_person
FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

-- Create a non-clustered index on la_person_id for quicker lookups and joins
CREATE INDEX IDX_contact_person ON #contact(la_person_id);
/*END TMP TABLE */




-- s47 table
/*
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 's47_enquiry_icpc')
BEGIN

    -- Create the s47_enquiry_icpc table in Child_Social schema
    SELECT
        s47.[FACT_S47_ID] as s47_enquiry_id,
        s47.[EXTERNAL_ID] as la_person_id,
        s47.[START_DTTM] as s47_start_date,
        s47.[START_DTTM] as s47_authorised_date,
        cpc.[YOUR_COLUMN_NAME] as s47_outcome,      -- TO DO 
        cpc.[TRANSFER_IN_FLAG] as icpc_transfer_in, -- TO CHECK
        cpc.[MEETING_DTTM] as icpc_date,            -- TO CHECK
        s47.[OUTCOME_CP_FLAG] as icpc_outcome,      -- TO CHECK
        s47.[COMPLETED_BY_DEPT_ID] as icpc_team,
        s47.[COMPLETED_BY_USER_STAFF_ID] as icpc_worker_id

    INTO
        Child_Social.s47_enquiry_icpc

    FROM 
        Child_Social.FACT_S47 AS s47
    JOIN
        Child_Social.FACT_CP_CONFERENCE as cpc ON s47.[EXTERNAL_ID] = cpc.[EXTERNAL_ID];

    -- Set s47_enquiry_id as the primary key for the table
    ALTER TABLE Child_Social.s47_enquiry_icpc
    ADD CONSTRAINT PK_s47_enquiry_id
    PRIMARY KEY (s47_enquiry_id);

    -- Add a foreign key constraint for la_person_id referencing person.la_person_id
    ALTER TABLE Child_Social.s47_enquiry_icpc
    ADD CONSTRAINT FK_s47_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);
END
*/

/* TEMP TABLE DEF */
-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#s47_enquiry_icpc') IS NOT NULL 
    DROP TABLE #s47_enquiry_icpc;

-- Create the temp table #s47
SELECT
    s47.[FACT_S47_ID] as s47_enquiry_id,
    s47.[EXTERNAL_ID] as la_person_id,
    s47.[START_DTTM] as s47_start_date,
    s47.[START_DTTM] as s47_authorised_date,
    cpc.[YOUR_COLUMN_NAME] as s47_outcome,      -- TO DO 
    cpc.[TRANSFER_IN_FLAG] as icpc_transfer_in, -- TO CHECK
    cpc.[MEETING_DTTM] as icpc_date,            -- TO CHECK
    s47.[OUTCOME_CP_FLAG] as icpc_outcome,      -- TO CHECK
    s47.[COMPLETED_BY_DEPT_ID] as icpc_team,
    s47.[COMPLETED_BY_USER_STAFF_ID] as icpc_worker_id
INTO
    #s47_enquiry_icpc
FROM 
    Child_Social.FACT_S47 AS s47
JOIN
    Child_Social.FACT_CP_CONFERENCE as cpc ON s47.[EXTERNAL_ID] = cpc.[EXTERNAL_ID];

-- Set s47_enquiry_id as the primary key for the temp table
ALTER TABLE #s47_enquiry_icpc
ADD PRIMARY KEY (s47_enquiry_id);

-- Add a foreign key constraint for la_person_id referencing person.la_person_id
ALTER TABLE #s47_enquiry_icpc
ADD FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);
/*END TMP TABLE */







/*
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cla_Substance_misuse')
BEGIN
    -- Create cla_Substance_misuse table
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
        Child_Social.cla_Substance_misuse

    FROM 
        Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;

    -- Set the primary key on substance_misuse_id
    ALTER TABLE Child_Social.cla_Substance_misuse
    ADD CONSTRAINT PK_substance_misuse_id
    PRIMARY KEY (substance_misuse_id);

    -- Add the foreign key constraint for la_person_id
    ALTER TABLE Child_Social.cla_Substance_misuse
    ADD CONSTRAINT FK_substance_misuse_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);
END
*/

/* TEMP TABLE DEF */
-- Drop the temp table if it exists
IF OBJECT_ID('tempdb..#cla_Substance_misuse') IS NOT NULL 
    DROP TABLE #cla_Substance_misuse;

-- Create the temporary table #cla_Substance_misuse
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
    #cla_Substance_misuse

FROM 
    Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;

-- Set the primary key on substance_misuse_id
ALTER TABLE #cla_Substance_misuse
ADD CONSTRAINT PK_substance_misuse_id_temp
PRIMARY KEY (substance_misuse_id);

-- Add the foreign key constraint for la_person_id
-- (You can only add FK constraints in temp tables if you're sure the related table will be available in the same session)
ALTER TABLE #cla_Substance_misuse
ADD CONSTRAINT FK_substance_misuse_person_temp
FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);
/*END TMP TABLE */

