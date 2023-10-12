
/* Notes:
Ensure that extracted dates are in dd/MM/YYYY format and created fields are DATE, not DATETIME
Full review needed of max/exagerated/default new field type sizes e.g. family_id NVARCHAR(255)
*/


/*
Start of SSD table creation 
*/


/* object name: person
*/
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'person')
BEGIN
    -- Create 'person' structure
    CREATE TABLE Child_Social.person (
        la_person_id NVARCHAR(MAX) PRIMARY KEY,
        person_sex NVARCHAR(MAX),
        person_gender NVARCHAR(MAX),
        person_ethnicity NVARCHAR(MAX),
        person_dob DATETIME,
        person_upn NVARCHAR(MAX),
        person_upn_unknown NVARCHAR(MAX),
        person_send NVARCHAR(MAX),
        person_expected_dob NVARCHAR(MAX),
        person_death_date DATETIME,
        person_nationality NVARCHAR(MAX),
        person_is_mother CHAR(1)
    );
    
    -- Insert data into 'person'
    INSERT INTO Child_Social.person (
        la_person_id,
        person_sex,
        person_gender,
        person_ethnicity,
        person_dob,
        person_upn,
        person_upn_unknown,
        person_send,
        person_expected_dob,
        person_death_date,
        person_nationality,
        person_is_mother
    )
    SELECT 
        p.[EXTERNAL_ID],
        p.[DIM_LOOKUP_VARIATION_OF_SEX_CODE],
        p.[GENDER_MAIN_CODE],
        p.[ETHNICITY_MAIN_CODE],
        p.[BIRTH_DTTM],
        p.[UPN],
        p.[NO_UPN_CODE],
        p.[EHM_SEN_FLAG],
        p.[DOB_ESTIMATED],
        p.[DEATH_DTTM],
        p.[NATNL_CODE],
        CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END -- needs confirming
    FROM 
        Child_Social.DIM_PERSON AS p
    LEFT JOIN
        Child_Social.FACT_CPIS_UPLOAD AS fc
    ON 
        p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
    ORDER BY
        p.[EXTERNAL_ID] ASC;

    -- Create a non-clustered index on la_person_id for quicker lookups and joins
    CREATE INDEX IDX_person_la_person_id ON Child_Social.person(la_person_id);
END;






/* object name: family
*/
-- part of early help system(s).

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'family')
BEGIN
    -- Create 'family'
    CREATE TABLE Child_Social.family (
        DIM_TF_FAMILY_ID INT PRIMARY KEY, 
        family_id NVARCHAR(255),
        la_person_id NVARCHAR(255),
        
        -- Define foreign key constraint
        FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id)
    );

    -- Insert data from Singleview.DIM_TF_FAMILY into newly created table
    INSERT INTO Child_Social.family (
        DIM_TF_FAMILY_ID, 
        family_id, 
        la_person_id
        )
    SELECT 
        DIM_TF_FAMILY_ID,
        UNIQUE_FAMILY_NUMBER    as family_id,
        EXTERNAL_ID             as la_person_id
    FROM Singleview.DIM_TF_FAMILY;

    -- Create a non-clustered index on foreign key
    CREATE INDEX IDX_family_person ON Child_Social.family(la_person_id);
END;



/* object name: address
*/

-- Check if address exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'address')
BEGIN
    -- Create address if it doesn't exist
    CREATE TABLE Child_Social.address (
        address_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX), -- Assuming EXTERNAL_ID corresponds to la_person_id
        address_type NVARCHAR(MAX),
        address_start DATETIME,
        address_end DATETIME,
        address_postcode NVARCHAR(MAX),
        address NVARCHAR(MAX)
    );

    -- Add foreign key constraint for la_person_id
    ALTER TABLE Child_Social.address
    ADD CONSTRAINT FK_address_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Non-clustered index on foreign key
    CREATE INDEX IDX_address_person 
    ON Child_Social.address(la_person_id);

    -- Non-clustered indexes on address_start and address_end
    CREATE INDEX IDX_address_start 
    ON Child_Social.address(address_start);

    CREATE INDEX IDX_address_end 
    ON Child_Social.address(address_end);

    -- Now, insert data into newly created table
    INSERT INTO Child_Social.address (
        address_id, 
        la_person_id, 
        address_type, 
        address_start, 
        address_end, 
        address_postcode, 
        address
    )
    SELECT 
        pa.[DIM_PERSON_ADDRESS_ID],
        pa.[EXTERNAL_ID], -- Assuming EXTERNAL_ID corresponds to la_person_id
        pa.[ADDSS_TYPE_CODE],
        pa.[START_DTTM],
        pa.[END_DTTM],
        pa.[POSTCODE],
        -- Create concatenated address field
        CONCAT_WS(',', 
            NULLIF(pa.[ROOM_NO], ''), 
            NULLIF(pa.[FLOOR_NO], ''), 
            NULLIF(pa.[FLAT_NO], ''), 
            NULLIF(pa.[BUILDING], ''), 
            NULLIF(pa.[HOUSE_NO], ''), 
            NULLIF(pa.[STREET], ''), 
            NULLIF(pa.[TOWN], '')
        )
    FROM 
        Child_Social.DIM_PERSON_ADDRESS AS pa
    ORDER BY
        pa.[EXTERNAL_ID] ASC;
END



/* object name: disability 
*/
-- Check if disability exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'disability')
BEGIN
    -- Create disability if it doesn't exist
    CREATE TABLE Child_Social.disability (
        disability_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        person_disability NVARCHAR(MAX)
    );

    -- Add foreign key constraint for la_person_id
    ALTER TABLE Child_Social.disability
    ADD CONSTRAINT FK_disability_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Non-clustered index on foreign key
    CREATE INDEX IDX_disability_la_person_id 
    ON Child_Social.disability(la_person_id);

    -- Now, insert data into newly created table
    INSERT INTO Child_Social.disability (
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
END





/* object name: immigration_status table
*/

-- Check if immigration_status exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'immigration_status')
BEGIN
    -- Create immigration_status if it doesn't exist
    CREATE TABLE Child_Social.immigration_status (
        immigration_status_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        immigration_status_start DATETIME,
        immigration_status_end DATETIME,
        immigration_status NVARCHAR(MAX)
    );

    -- Add foreign key constraint for la_person_id
    ALTER TABLE Child_Social.immigration_status
    ADD CONSTRAINT FK_immigration_status_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Non-clustered index on foreign key
    CREATE INDEX IDX_immigration_status_la_person_id 
    ON Child_Social.immigration_status(la_person_id);

    -- Non-clustered indexes on immigration_status_start and immigration_status_end
    CREATE INDEX IDX_immigration_status_start 
    ON Child_Social.immigration_status(immigration_status_start);

    CREATE INDEX IDX_immigration_status_end 
    ON Child_Social.immigration_status(immigration_status_end);

    -- Now, insert data into newly created table
    INSERT INTO Child_Social.immigration_status (
        immigration_status_id, 
        la_person_id, 
        immigration_status_start,
        immigration_status_end,
        immigration_status
    )
    SELECT 
        is.[FACT_IMMIGRATION_STATUS_ID],
        is.[EXTERNAL_ID],
        is.[START_DTTM],
        is.[END_DTTM],
        is.[DIM_LOOKUP_IMMGR_STATUS_CODE]
    FROM 
        Child_Social.FACT_IMMIGRATION_STATUS AS is
    ORDER BY
        is.[EXTERNAL_ID] ASC;
END


/* object name: mother
*/
-- Check if mother exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'mother')
/*
person_child_id
la_person_id
person_child_dob
*/



/* object name: legal_status
*/
-- Check if legal_status exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_SCHEMA = 'Child_Social' 
               AND TABLE_NAME = 'legal_status')
BEGIN

    -- Create legal_status structure
    CREATE TABLE Child_Social.legal_status (
        legal_status_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        legal_status_start DATETIME,
        legal_status_end DATETIME,
        person_dim_id INT
    );

    -- Insert data into legal_status table
    INSERT INTO Child_Social.legal_status (
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
    ALTER TABLE Child_Social.legal_status
    ADD CONSTRAINT FK_legal_status_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

END;



/* object name: contact
*/
-- Check if contact exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'contact')
BEGIN
    -- Create contact structure
    CREATE TABLE Child_Social.contact (
        contact_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        contact_start DATETIME,
        contact_source NVARCHAR(MAX),
        contact_outcome NVARCHAR(MAX)
    );

    -- Add foreign key constraint for la_person_id
    ALTER TABLE Child_Social.contact
    ADD CONSTRAINT FK_contact_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Create a non-clustered index on la_person_id for quicker lookups and joins
    CREATE INDEX IDX_contact_person ON Child_Social.contact(la_person_id);

    -- Insert data into newly created table
    INSERT INTO Child_Social.contact (
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
        Child_Social.FACT_CONTACT AS fc
    ORDER BY
        fc.[EXTERNAL_ID] ASC;
END



/* object name: early help
*/

-- Check if early_help exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'early_help')

/*
eh_episode_id
la_person_id
eh_epi_start_date
eh_epi_end_date
eh_epi_reason
eh_epi_end_reason
eh_epi_org
eh_epi_worker_id
*/



/* object name: cin_episodes
*/
-- Check if cin_episodes exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cin_episodes')

/*
cin_referral_id
la_person_id
cin_ref_date
cin_primary_need
cin_ref_source
cin_ref_outcome
cin_close_reason
cin_close_date
cin_ref_team
cin_ref_worker_id
*/



/* object name: assessments
*/
-- Check if assessments exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'assessments')

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



/* object name: assessment_factors
*/

-- Check if assessment_factors exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'assessment_factors')

/*
asmt_id
asmt_factors
*/




/* object name: cin_plans
*/

-- Check if cin_plans exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cin_plans')

/*
cin_plan_id
la_person_id
cin_plan_Start
cin_plan_end
cin_team
cin_worker_id
*/


/* object name: cin_visits
*/

-- Check if cin_visits exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cin_visits')

/*
cin_visit_id
cin_plan_id
cin_visit_date
cin_visit_seen
cin_visit_seen_alone
cin_visit_bedroom

*/


/* object name: s47
*/
-- Check if s47_enquiry_icpc exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 's47_enquiry_icpc')
BEGIN
    -- Create s47_enquiry_icpc structure
    CREATE TABLE Child_Social.s47_enquiry_icpc (
        s47_enquiry_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
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
    ALTER TABLE Child_Social.s47_enquiry_icpc
    ADD CONSTRAINT FK_s47_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);

    -- Populate s47_enquiry_icpc table with data
    INSERT INTO Child_Social.s47_enquiry_icpc (
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
END


/* object name: cp_plans
*/


/* object name: category_of_abuse
*/


/* object name: cp_visits
*/


/* object name: cp_reviews
*/


/* object name: cp_reviews_risks
*/


/* object name: cla_episodes
*/



/* object name: cla_convictions
*/

-- Check if cla_convictions exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cla_convictions')



/* object name: cla_health
*/


/* object name: cla_immunisations
*/


/* object name: substance_misuse
*/

-- Check if substance_misuse exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cla_Substance_misuse')
BEGIN
    -- Create cla_Substance_misuse structure
    CREATE TABLE Child_Social.cla_Substance_misuse (
        substance_misuse_id INT PRIMARY KEY,
        la_person_id NVARCHAR(MAX),
        create_date DATETIME,
        person_dim_id INT,
        start_date DATETIME,
        end_date DATETIME,
        substance_type_id INT,
        substance_type_code NVARCHAR(MAX)
    );

    -- Insert data intocla_Substance_misuse table
    INSERT INTO Child_Social.cla_Substance_misuse (
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
    ALTER Child_Social.cla_Substance_misuse
    ADD CONSTRAINT FK_substance_misuse_person
    FOREIGN KEY (la_person_id) REFERENCES Child_Social.person(la_person_id);
END;



/* object name: placement
*/

-- Check if placement exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'placement')




-- NEEDS FURTHER WORK
/* object name: cla_reviews
*/

-- Check if cla_reviews exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'cla_Substance_misuse')
BEGIN
    SELECT 
    FACT_CLA_REVIEW.[FACT_CLA_REVIEW_ID] as cp_review_id
    --FACT_CLA_REVIEW.[] as cp_plan_id -- FACT_CLA_ID? 
    FACT_CLA_REVIEW.[DUE_DTTM] as cp_rev_due
    --FACT_CLA_REVIEW.[START_DTTM] as cp_rev_date
    --FACT_CLA_REVIEW.[] as cp_rev_outcome
    --FACT_CLA_REVIEW.[] as cp_rev_quorate
    --FACT_CLA_REVIEW.[] as cp_rev_participation
    --FACT_CLA_REVIEW.[] as cp_rev_cyp_views_quality
    --FACT_CLA_REVIEW.[] as cp_rev_sufficient_prog
    --FACT_CLA_REVIEW.[] as cp_review_id
    --FACT_CLA_REVIEW.[] as cp_review_risks

    INTO #cla_reviews

    FROM FACT_CLA_REVIEW
END




/* object name: cla_previous_permanence
*/

/* object name: cla_care_plan
*/


/* object name: cla_visits
*/

/* object name: sdq_scores
*/

/* object name: missing
*/

/* object name: care_leavers
*/

/* object name: permanence
*/



/* object name: send
*/
-- Check if send exists
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Child_Social' AND TABLE_NAME = 'send')
BEGIN
    -- Create send structure
    CREATE TABLE Child_Social.send (
        send_table_id INT,
        la_person_id NVARCHAR(MAX),
        send_upn INT,
        upn_unknown NVARCHAR(MAX),
        send_uln NVARCHAR(MAX)
    );

    -- Populate send table with data
    INSERT INTO Child_Social.send (
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
END;

/* ?? Should this actually be pulling from Child_Social.FACT_SENRECORD.DIM_PERSON_ID | Child_Social.FACT_SEN.DIM_PERSON_ID
*/


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

/* object name: pre_proceedings
*/


/* object name: voice_of_child
*/


