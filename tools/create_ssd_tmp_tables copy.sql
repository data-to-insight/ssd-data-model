
USE HDM;

DECLARE @StartTime DATETIME, @EndTime DATETIME;
-- Record the start time
SET @StartTime = GETDATE();



/* object name: person 
*/

-- -- Check if exists, & drop it
-- IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL 
--     DROP TABLE #ssd_person;

-- -- Create '#ssd_person' structure
-- CREATE TABLE #ssd_person (
--     la_person_id NVARCHAR(255) PRIMARY KEY, 
--     person_sex NVARCHAR(MAX),
--     person_gender NVARCHAR(MAX),
--     person_ethnicity NVARCHAR(MAX),
--     person_dob DATETIME,
--     person_upn NVARCHAR(MAX),
--     person_upn_unknown NVARCHAR(MAX),
--     person_send NVARCHAR(MAX),
--     person_expected_dob NVARCHAR(MAX),
--     person_death_date DATETIME,
--     person_nationality NVARCHAR(MAX),
--     person_is_mother CHAR(1)
-- );

-- -- Insert data into '#ssd_person'
-- INSERT INTO #ssd_person (
--     la_person_id,
--     person_sex,
--     person_gender,
--     person_ethnicity,
--     person_dob,
--     person_upn,
--     person_upn_unknown,
--     person_send,
--     person_expected_dob,
--     person_death_date,
--     person_nationality,
--     person_is_mother
-- )
-- SELECT TOP 100 
--     p.[EXTERNAL_ID],
--     p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE],
--     p.[GENDER_MAIN_CODE],
--     p.[ETHNICITY_MAIN_CODE],
--     p.[BIRTH_DTTM],
--     p.[UPN],

-- 	(SELECT TOP 1 f.NO_UPN_CODE              -- Subquery to fetch the NO_UPN_CODE.
-- 	 FROM Child_Social.FACT_903_DATA f       -- This *unlikely* to be the best source
-- 	 WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
-- 	 AND f.NO_UPN_CODE IS NOT NULL
-- 	 ORDER BY f.NO_UPN_CODE DESC),  -- desc order to ensure a non-null value first

--     p.[EHM_SEN_FLAG],
--     p.[DOB_ESTIMATED],
--     p.[DEATH_DTTM],
--     p.[NATNL_CODE],
--     CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END 
-- FROM 
--     Child_Social.DIM_PERSON AS p
-- LEFT JOIN
--     Child_Social.FACT_CPIS_UPLOAD AS fc
-- ON 
--     p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
-- WHERE 
--     p.[EXTERNAL_ID] IS NOT NULL
-- ORDER BY
--     p.[EXTERNAL_ID] ASC;

-- -- Create non-clustered index on la_person_id
-- CREATE INDEX IDX_ssd_person_la_person_id ON #ssd_person(la_person_id);


/* object name: person 
*/

-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL 
    DROP TABLE #ssd_person;

-- Create and populate '#ssd_person' table using SELECT INTO
SELECT TOP 100 
    p.[EXTERNAL_ID] AS la_person_id,
    p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE] AS person_sex,
    p.[GENDER_MAIN_CODE] AS person_gender,
    p.[ETHNICITY_MAIN_CODE] AS person_ethnicity,
    p.[BIRTH_DTTM] AS person_dob,
    p.[UPN] AS person_upn,

	(SELECT TOP 1 f.NO_UPN_CODE              -- Subquery to fetch the NO_UPN_CODE.
	 FROM Child_Social.FACT_903_DATA f       -- This *unlikely* to be the best source
	 WHERE f.EXTERNAL_ID = p.EXTERNAL_ID
	 AND f.NO_UPN_CODE IS NOT NULL
	 ORDER BY f.NO_UPN_CODE DESC) AS person_upn_unknown,  -- desc order to ensure a non-null value first

    p.[EHM_SEN_FLAG] AS person_send,
    p.[DOB_ESTIMATED] AS person_expected_dob,
    p.[DEATH_DTTM] AS person_death_date,
    p.[NATNL_CODE] AS person_nationality,
    CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END AS person_is_mother
INTO 
    #ssd_person
FROM 
    Child_Social.DIM_PERSON AS p
LEFT JOIN
    Child_Social.FACT_CPIS_UPLOAD AS fc
ON 
    p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
WHERE 
    p.[EXTERNAL_ID] IS NOT NULL
ORDER BY
    p.[EXTERNAL_ID] ASC;

-- Create non-clustered index on la_person_id
CREATE INDEX IDX_ssd_person_la_person_id ON #ssd_person(la_person_id);



-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;

-- Insert data from Singleview.DIM_TF_FAMILY into a new temporary table '#ssd_family'
SELECT TOP 100
    DIM_TF_FAMILY_ID,
    UNIQUE_FAMILY_NUMBER AS family_id,
    EXTERNAL_ID AS la_person_id
INTO #ssd_family
FROM Singleview.DIM_TF_FAMILY;

-- Create non-clustered index on la_person_id
CREATE INDEX IDX_family_person ON #ssd_family(la_person_id);




/* object name: address
*/

-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;

-- Create the temp table #address
SELECT TOP 100
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

INTO #ssd_address
FROM 
    Child_Social.DIM_PERSON_ADDRESS AS pa
ORDER BY
    pa.[EXTERNAL_ID] ASC;

-- Add primary key constraint to address_id
ALTER TABLE #ssd_address ADD CONSTRAINT PK_address_id PRIMARY KEY (address_id);

-- Non-clustered index on la_person_id
CREATE INDEX IDX_address_person ON #ssd_address(la_person_id);

-- Non-clustered indexes on address_start and address_end
CREATE INDEX IDX_address_start ON #ssd_address(address_start);
CREATE INDEX IDX_address_end ON #ssd_address(address_end);





/* object name: disability
*/
-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL 
    DROP TABLE #ssd_disability;

-- Create the temp table #disability
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



-- Get & print run time 
SET @EndTime = GETDATE();
PRINT 'Run time duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms';


/* cleanup */
IF OBJECT_ID('tempdb..#ssd_person') IS NOT NULL DROP TABLE #ssd_person;
IF OBJECT_ID('tempdb..#ssd_family') IS NOT NULL DROP TABLE #ssd_family;
IF OBJECT_ID('tempdb..#ssd_address') IS NOT NULL DROP TABLE #ssd_address;
IF OBJECT_ID('tempdb..#ssd_disability') IS NOT NULL DROP TABLE #ssd_disability;









-- immigration_status table

IF OBJECT_ID('tempdb..#ssd_immigration_status') IS NOT NULL DROP TABLE #ssd_immigration_status;
-- Create the immigration_status table if it doesn't exist
SELECT 
    is.[FACT_IMMIGRATION_STATUS_ID] as immigration_status_id,
    is.[EXTERNAL_ID] as la_person_id,
    is.[START_DTTM] as immigration_status_start,
    is.[END_DTTM] as immigration_status_end,
    is.[DIM_LOOKUP_IMMGR_STATUS_CODE] as immigration_status

INTO 
    #ssd_immigration_status

FROM 
    Child_Social.FACT_IMMIGRATION_STATUS AS is

ORDER BY
    is.[EXTERNAL_ID] ASC;

-- Set the primary key on immigration_status_id
ALTER TABLE #ssd_immigration_status
ADD CONSTRAINT PK_immigration_status_id
PRIMARY KEY (immigration_status_id);


-- Non-clustered index on immigration_status_start
CREATE INDEX IDX_immigration_status_start 
ON #ssd_immigration_status(immigration_status_start);

-- Non-clustered index on immigration_status_end
CREATE INDEX IDX_immigration_status_end 
ON #ssd_immigration_status(immigration_status_end);



/* object name: mother
*/

/*
person_child_id
la_person_id
person_child_dob
*/



/* object name: legal_status
*/
-- Check if legal_status exists


    -- Create ssd_legal_status structure
    CREATE TABLE Child_Social.ssd_legal_status (
        legal_status_id NVARCHAR(255) PRIMARY KEY,
        la_person_id NVARCHAR(255),
        legal_status_start DATETIME,
        legal_status_end DATETIME,
        person_dim_id NVARCHAR(255)
    );

    -- Insert data into ssd_legal_status table
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





/* object name: contact
*/

-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_contact') IS NOT NULL DROP TABLE #ssd_contact;

-- Create the temp table #contact
SELECT
	fc.[FACT_CONTACT_ID] as contact_id,
	fc.[EXTERNAL_ID] as la_person_id,
    fc.[START_DTTM] as contact_start,
    fc.[SOURCE_CONTACT] as contact_source,
	fc.[CONTACT_OUTCOMES] as contact_outcome

INTO #ssd_contact

FROM 
    Child_Social.FACT_CONTACT AS fc

ORDER BY
    fc.[EXTERNAL_ID] ASC;

-- Add primary key constraint to contact_id
ALTER TABLE #ssd_contact
ADD CONSTRAINT PK_contact_id
PRIMARY KEY (contact_id);


-- Create non-clustered index on la_person_id
CREATE INDEX IDX_contact_person ON #ssd_contact(la_person_id);





/* object name: s47
*/

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#ssd_s47_enquiry_icpc') IS NOT NULL 
    DROP TABLE #ssd_s47_enquiry_icpc;

-- Create the temp table #s47
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
    s47.[OUTCOME_CP_FLAG] as icpc_outcome,
    s47.[COMPLETED_BY_DEPT_ID] as icpc_team,
    s47.[COMPLETED_BY_USER_STAFF_ID] as icpc_worker_id
INTO
    #ssd_s47_enquiry_icpc
FROM 
    Child_Social.FACT_S47 AS s47
-- all records from FACT_S47 even if they don't have a match in FACT_CP_CONFERENCE
LEFT JOIN Child_Social.FACT_CP_CONFERENCE as cpc ON s47.[FACT_S47_ID] = cpc.[FACT_S47_ID]

-- Set s47_enquiry_id as the primary key for the temp table
ALTER TABLE #ssd_s47_enquiry_icpc
ADD PRIMARY KEY (s47_enquiry_id);

-- Add a foreign key constraint for la_person_id referencing person.la_person_id
ALTER TABLE #ssd_s47_enquiry_icpc
ADD FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);




/* object name: substance_abuse table
*/

-- Check if exists, & drop it
IF OBJECT_ID('tempdb..#ssd_cla_Substance_misuse') IS NOT NULL 
    DROP TABLE #ssd_cla_Substance_misuse;

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
    #ssd_cla_Substance_misuse

FROM 
    Child_Social.FACT_SUBSTANCE_MISUSE AS fsm;

-- Set the primary key on substance_misuse_id
ALTER TABLE #ssd_cla_Substance_misuse
ADD CONSTRAINT PK_substance_misuse_id_temp
PRIMARY KEY (substance_misuse_id);

-- Add the foreign key constraint for la_person_id
-- (You can only add FK constraints in temp tables if you're sure the related table will be available in the same session)
ALTER TABLE #ssd_cla_Substance_misuse
ADD CONSTRAINT FK_substance_misuse_person_temp
FOREIGN KEY (la_person_id) REFERENCES Child_Social.ssd_person(la_person_id);
/*END TMP TABLE */



/* object name: send
*/

-- Drop the temp table if it already exists
IF OBJECT_ID('tempdb..#ssd_send') IS NOT NULL
   DROP TABLE #ssd_send;

-- Create the temporary table 
SELECT 
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






/* object name: ehcp_assessment
*/

/* object name: ehcp_named_plan
*/

/* object name: ehcp_active_plans
*/

/* object name: send_need
*/

/* object name: social_worker
*/
FACT_CASEWORKER.FACT_CASEWORKER_ID as sw_id
sw_epi_start_date
sw_epi_end_date
sw_change_reason
FACT_CASEWORKER.AGENCY as sw_agency
FACT_CASEWORKER.DIM_LOOKUP_PROF_ROLE_ID_CODE as sw_role
sw_caseload
-- sw_qualification


/* object name: pre_proceedings
*/


/* object name: voice_of_child
*/








/* object name: assessment
*/

-- Drop the temp table if it already exists
IF OBJECT_ID('tempdb..#ssd_assessment') IS NOT NULL
   DROP TABLE #ssd_assessment;

-- ??
-- Child_Social FACT_CORE_ASSESSMENT	EXTERNAL_ID
-- Child_Social FACT_INITIAL_ASSESSMENT	EXTERNAL_ID
-- Child_Social FACT_SINGLE_ASSESSMENT	EXTERNAL_ID

-- dbo	DIM_ASSESSMENT_DETAILS	EXTERNAL_ID




-- cin_plans table

-- FACT_REFERRALS	REFRL_START_DTTM
-- FACT_REFERRALS	DIM_LOOKUP_CATEGORY_OF_NEED_CODE


-- FACT_SINGLE_ASSESSMENT	SEEN_FLAG