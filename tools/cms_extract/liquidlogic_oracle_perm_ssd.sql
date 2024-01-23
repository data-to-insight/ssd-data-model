

/* ********************************************************************************************************** */
/* Development set up */

-- Note: 
-- This script is for creating PERM(Persistent) tables within the temp DB name space for testing purposes. 
-- SSD extract files with the suffix ..._perm.sql - for creating the persistent table versions.
-- SSD extract files with the suffix ..._temp.sql - for creating the temporary table versions.


USE HDM;
GO



-- ssd extract time-frame (YRS)
DECLARE
    v_ssd_timeframe_years NUMBER := 6;
    v_ssd_sub1_range_years NUMBER := 1;
    v_LastSept30th DATE; -- Most recent past September 30th date towards case load calc
    -- Determine/Define date on which CASELOAD count required (Currently: September 30th)
BEGIN



/*
=============================================================================
Object Name: ssd_person
Description: person/child details
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.5
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]

Remarks:    
            Note: Due to part reliance on 903 table, be aware that if 903 not populated pre-ssd run, 
            this/subsequent queries can return v.low|unexpected row counts.
Dependencies: 
- Child_Social.DIM_PERSON
- Child_Social.FACT_REFERRALS
- Child_Social.FACT_CONTACTS
- Child_Social.FACT_EHCP_EPISODE
- Child_Social.FACT_903_DATA
=============================================================================
*/


    -- check exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_person';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_person (
        pers_legacy_id          NVARCHAR2(48),
        pers_person_id          NVARCHAR2(48) CONSTRAINT ssd_person_pk PRIMARY KEY,
        pers_sex                NVARCHAR2(48),
        pers_gender             NVARCHAR2(48),
        pers_ethnicity          NVARCHAR2(38),
        pers_dob                TIMESTAMP,
        pers_common_child_id    NVARCHAR2(10),
        pers_upn_unknown        NVARCHAR2(10),
        pers_send               NVARCHAR2(1),
        pers_expected_dob       TIMESTAMP,
        pers_death_date         TIMESTAMP,
        pers_is_mother          NVARCHAR2(48),
        pers_nationality        NVARCHAR2(48)
    )';
    
INSERT INTO ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,
    pers_gender,
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,   -- [TESTING] [Takes NHS Number]
    pers_upn_unknown,
    pers_send,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality
)


SELECT
    p.LEGACY_ID,
    p.DIM_PERSON_ID,
    p.GENDER_MAIN_CODE,
    p.NHS_NUMBER,           -- [TESTING] [Takes NHS Number]
    p.ETHNICITY_MAIN_CODE,
    CASE 
        WHEN p.DOB_ESTIMATED = 'N' THEN p.BIRTH_DTTM   -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL                                      -- or NULL
    END,
    NULL AS pers_common_child_id,                     -- Set to NULL as default(dev) / or set to NHS num
    f903.NO_UPN_CODE,
    p.EHM_SEN_FLAG,
    CASE 
        WHEN p.DOB_ESTIMATED = 'Y' THEN p.BIRTH_DTTM   -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL                                      -- or NULL
    END,
    p.DEATH_DTTM,
    CASE 
        WHEN p.GENDER_MAIN_CODE <> 'M' AND
             EXISTS (
                SELECT 1 FROM Child_Social.FACT_PERSON_RELATION fpr 
                WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND 
                fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI'
             ) -- check for child relation only
        THEN 'Y' 
        ELSE NULL -- No child relation found
    END,
    p.NATNL_CODE
FROM
    Child_Social.DIM_PERSON p
LEFT JOIN
    Child_Social.FACT_903_DATA f903 ON p.DIM_PERSON_ID = f903.DIM_PERSON_ID
WHERE
    p.DIM_PERSON_ID IS NOT NULL AND 
    p.DIM_PERSON_ID >= 1 AND 
    (
        EXISTS (
            -- contact in last x@yrs
            SELECT 1 FROM Child_Social.FACT_CONTACTS fc
            WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID AND
            fc.CONTACT_DTTM >= ADD_MONTHS(SYSDATE, -12 * v_ssd_timeframe_years)
        ) OR EXISTS (
            -- new or ongoing/active/unclosed referral in last x@yrs
            SELECT 1 FROM Child_Social.FACT_REFERRALS fr
            WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
            (
                fr.REFRL_START_DTTM >= ADD_MONTHS(SYSDATE, -12 * v_ssd_timeframe_years) OR
                fr.REFRL_END_DTTM >= ADD_MONTHS(SYSDATE, -12 * v_ssd_timeframe_years) OR
                fr.REFRL_END_DTTM IS NULL
            )
        ) OR EXISTS (
            -- care leaver contact in last x@yrs
            SELECT 1 FROM Child_Social.FACT_CLA_CARE_LEAVERS fccl
            WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID AND
            fccl.IN_TOUCH_DTTM >= ADD_MONTHS(SYSDATE, -12 * v_ssd_timeframe_years)
        )
    );


    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_person_la_person_id ON ssd_person(pers_person_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_family
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: Part of early help system. Restrict to records related to x@yrs of ssd_person
Dependencies: 
- FACT_CONTACTS
- ssd.ssd_person
=============================================================================
*/


BEGIN
    -- check exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_family';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_family (
        fami_table_id           NVARCHAR2(48) PRIMARY KEY, 
        fami_family_id          NVARCHAR2(48),
        fami_person_id          NVARCHAR2(48)
    )';

    -- Data insertion here
    INSERT INTO ssd_family (
        fami_table_id, 
        fami_family_id, 
        fami_person_id
    )
    SELECT 
        fc.EXTERNAL_ID                          AS fami_table_id,
        fc.DIM_LOOKUP_FAMILYOFRESIDENCE_ID      AS fami_family_id,
        fc.DIM_PERSON_ID                        AS fami_person_id
    FROM Child_Social.FACT_CONTACTS fc
    WHERE EXISTS 
        ( -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fc.DIM_PERSON_ID
        );

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_family_person_id ON ssd_family(fami_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_family ADD CONSTRAINT FK_family_person
    FOREIGN KEY (fami_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_address
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2)+|...
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- DIM_PERSON_ADDRESS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_address';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_address (
        addr_table_id           NVARCHAR2(48) PRIMARY KEY,
        addr_person_id          NVARCHAR2(48), 
        addr_address_type       NVARCHAR2(48),
        addr_address_start      DATE,
        addr_address_end        DATE,
        addr_address_postcode   NVARCHAR2(15),
        addr_address_json       NVARCHAR2(4000)  -- Increased size to ensure enough space
    )';

    -- Insert data
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
            WHEN REPLACE(pa.POSTCODE, ' ', '') = RPAD('X', LENGTH(REPLACE(pa.POSTCODE, ' ', '')), 'X') THEN NULL
            WHEN LOWER(REPLACE(pa.POSTCODE, ' ', '')) = 'nopostcode' THEN NULL
            ELSE REPLACE(pa.POSTCODE, ' ', '')
        END AS CleanedPostcode,
        JSON_OBJECT(    -- DB Compatibility: Oracle 12c+
            'ROOM' VALUE pa.ROOM_NO,
            'FLOOR' VALUE pa.FLOOR_NO,
            'FLAT' VALUE pa.FLAT_NO,
            'BUILDING' VALUE pa.BUILDING,
            'HOUSE' VALUE pa.HOUSE_NO,
            'STREET' VALUE pa.STREET,
            'TOWN' VALUE pa.TOWN,
            'UPRN' VALUE pa.UPRN,
            'EASTING' VALUE pa.EASTING,
            'NORTHING' VALUE pa.NORTHING
        ) AS addr_address_json
    FROM 
        Child_Social.DIM_PERSON_ADDRESS pa
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = pa.DIM_PERSON_ID
        );

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_address ADD CONSTRAINT FK_address_person
    FOREIGN KEY (addr_person_id) REFERENCES ssd_person(pers_person_id)';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_address_person ON ssd_address(addr_person_id)';
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_address_start ON ssd_address(addr_address_start)';
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_address_end ON ssd_address(addr_address_end)';
END;
/



/* 
=============================================================================
Object Name: ssd_disability
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_DISABILITY
=============================================================================
*/


BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_disability';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create the structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_disability (
        disa_table_id           NVARCHAR2(48) PRIMARY KEY,
        disa_person_id          NVARCHAR2(48) NOT NULL,
        disa_disability_code    NVARCHAR2(48) NOT NULL
    )';

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
        Child_Social.FACT_DISABILITY fd
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fd.DIM_PERSON_ID
        );

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_disability ADD CONSTRAINT FK_disability_person 
    FOREIGN KEY (disa_person_id) REFERENCES ssd_person(pers_person_id)';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_disability_person_id ON ssd_disability(disa_person_id)';
END;
/




/* 
=============================================================================
Object Name: #ssd_immigration_status
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_IMMIGRATION_STATUS
=============================================================================
*/


BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_immigration_status';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_immigration_status (
        immi_immigration_status_id      NVARCHAR2(48) PRIMARY KEY,
        immi_person_id                  NVARCHAR2(48),
        immi_immigration_status_start   DATE,
        immi_immigration_status_end     DATE,
        immi_immigration_status         NVARCHAR2(48)
    )';

    -- Insert data
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
        Child_Social.FACT_IMMIGRATION_STATUS ims
    WHERE 
        EXISTS 
        (   -- only ssd relevant records
            SELECT 1
            FROM ssd_person p
            WHERE p.pers_person_id = ims.DIM_PERSON_ID
        );

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_immigration_status ADD CONSTRAINT FK_immigration_status_person
    FOREIGN KEY (immi_person_id) REFERENCES ssd_person(pers_person_id)';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_immigration_status_immi_person_id ON ssd_immigration_status(immi_person_id)';
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_immigration_status_start ON ssd_immigration_status(immi_immigration_status_start)';
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_immigration_status_end ON ssd_immigration_status(immi_immigration_status_end)';
END;
/



/* 
=============================================================================
Object Name: ssd_mother
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
Dependencies: 
- ssd_person
- FACT_PERSON_RELATION
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_mother';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_mother (
        moth_table_id               NVARCHAR2(48) PRIMARY KEY,
        moth_person_id              NVARCHAR2(48),
        moth_childs_person_id       NVARCHAR2(48),
        moth_childs_dob             DATE
    )';
 
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
        Child_Social.FACT_PERSON_RELATION fpr
    JOIN
        Child_Social.DIM_PERSON p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
    WHERE
        p.GENDER_MAIN_CODE <> 'M'
        AND
        fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI' -- only interested in parent/child relations
    AND EXISTS
        (   -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE p.pers_person_id = fpr.DIM_PERSON_ID
        );
 
    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_mother_moth_person_id ON ssd_mother(moth_person_id)';

    -- Add constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_mother ADD CONSTRAINT FK_moth_to_person 
    FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id)';

    EXECUTE IMMEDIATE 'ALTER TABLE ssd_mother ADD CONSTRAINT FK_child_to_person 
    FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_legal_status
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_LEGAL_STATUS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_legal_status';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_legal_status (
        lega_legal_status_id        NVARCHAR2(48) PRIMARY KEY,
        lega_person_id              NVARCHAR2(48),
        lega_legal_status           NVARCHAR2(256),
        lega_legal_status_start     DATE,
        lega_legal_status_end       DATE
    )';
 
    -- Insert data
    INSERT INTO ssd_legal_status (
        lega_legal_status_id,
        lega_person_id,
        lega_legal_status,
        lega_legal_status_start,
        lega_legal_status_end
    )
    SELECT
        fls.FACT_LEGAL_STATUS_ID,
        fls.DIM_PERSON_ID,
        fls.DIM_LOOKUP_LGL_STATUS_DESC,
        fls.START_DTTM,
        fls.END_DTTM
    FROM
        Child_Social.FACT_LEGAL_STATUS fls
    WHERE EXISTS
        (   -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE p.pers_person_id = fls.DIM_PERSON_ID
        );

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_legal_status_lega_person_id ON ssd_legal_status(lega_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_legal_status ADD CONSTRAINT FK_legal_status_person
    FOREIGN KEY (lega_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_contacts
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.5
           1.4 cont_contact_source_desc added

Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks:Inclusion in contacts might differ between LAs. 
        Baseline definition:
        Contains safeguarding and referral to early help data.


        
Dependencies: 
- ssd_person
- FACT_CONTACTS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_contacts';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_contacts (
        cont_contact_id             NVARCHAR2(48) PRIMARY KEY,
        cont_person_id              NVARCHAR2(48),
        cont_contact_start          DATE,
        cont_contact_source         NVARCHAR2(48),
        cont_contact_source_desc    NVARCHAR2(255),
        cont_contact_outcome_json   NVARCHAR2(2000) -- Size increased to ensure enough space for JSON data
    )';

    -- Insert data
    INSERT INTO ssd_contacts (
        cont_contact_id, 
        cont_person_id, 
        cont_contact_start,
        cont_contact_source,
        cont_contact_source_desc,
        cont_contact_outcome_json
    )
    SELECT 
        fc.FACT_CONTACT_ID,
        fc.DIM_PERSON_ID, 
        fc.CONTACT_DTTM,
        fc.DIM_LOOKUP_CONT_SORC_ID,
        fc.DIM_LOOKUP_CONT_SORC_ID_DESC,
        JSON_OBJECT(
            'OUTCOME_NEW_REFERRAL_FLAG' VALUE fc.OUTCOME_NEW_REFERRAL_FLAG,
            'OUTCOME_EXISTING_REFERRAL_FLAG' VALUE fc.OUTCOME_EXISTING_REFERRAL_FLAG,
            'OUTCOME_CP_ENQUIRY_FLAG' VALUE fc.OUTCOME_CP_ENQUIRY_FLAG,
            'OUTCOME_NFA_FLAG' VALUE fc.OUTCOME_NFA_FLAG,
            'OUTCOME_NON_AGENCY_ADOPTION_FLAG' VALUE fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG,
            'OUTCOME_PRIVATE_FOSTERING_FLAG' VALUE fc.OUTCOME_PRIVATE_FOSTERING_FLAG,
            'OUTCOME_ADVICE_FLAG' VALUE fc.OUTCOME_ADVICE_FLAG,
            'OUTCOME_MISSING_FLAG' VALUE fc.OUTCOME_MISSING_FLAG,
            'OUTCOME_OLA_CP_FLAG' VALUE fc.OUTCOME_OLA_CP_FLAG,
            'OTHER_OUTCOMES_EXIST_FLAG' VALUE fc.OTHER_OUTCOMES_EXIST_FLAG
        ) AS cont_contact_outcome_json
    FROM 
        Child_Social.FACT_CONTACTS fc
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fc.DIM_PERSON_ID
        );

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_contacts ADD CONSTRAINT FK_contact_person 
    FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id)';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_contact_person_id ON ssd_contacts(cont_person_id)';
END;
/





/* 
=============================================================================
Object Name: ssd_cin_episodes
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2) |...
Version: 1.5
            1.4: contact_source_desc added, _source now populated with ID

Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- FACT_REFERRALS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cin_episodes';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cin_episodes
    (
        cine_referral_id            NUMBER,
        cine_person_id              NVARCHAR2(48),
        cine_referral_date          DATE,
        cine_cin_primary_need       NVARCHAR2(10),
        cine_referral_source        NVARCHAR2(48),    
        cine_referral_source_desc   NVARCHAR2(255),
        cine_referral_outcome_json  NVARCHAR2(2000), -- Increased size for JSON data
        cine_referral_nfa           CHAR(1),
        cine_close_reason           NVARCHAR2(100),
        cine_close_date             DATE,
        cine_referral_team          NVARCHAR2(255),
        cine_referral_worker_id     NVARCHAR2(48)
    )';
 
    -- Insert data
    -- Note: You'll need to declare and set the variable v_ssd_timeframe_years properly
    INSERT INTO ssd_cin_episodes
    (
        cine_referral_id,
        cine_person_id,
        cine_referral_date,
        cine_cin_primary_need,
        cine_referral_source,
        cine_referral_source_desc,
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
        fr.DIM_LOOKUP_CATEGORY_OF_NEED_CODE,
        fr.DIM_LOOKUP_CONT_SORC_ID,
        fr.DIM_LOOKUP_CONT_SORC_ID_DESC,
        JSON_OBJECT( -- DB Compatibility: Oracle 12c Rel2 (12.2)
            'OUTCOME_SINGLE_ASSESSMENT_FLAG' VALUE fr.OUTCOME_SINGLE_ASSESSMENT_FLAG,
            'OUTCOME_NFA_FLAG' VALUE fr.OUTCOME_NFA_FLAG,
            'OUTCOME_STRATEGY_DISCUSSION_FLAG' VALUE fr.OUTCOME_STRATEGY_DISCUSSION_FLAG,
            'OUTCOME_CLA_REQUEST_FLAG' VALUE fr.OUTCOME_CLA_REQUEST_FLAG,
            'OUTCOME_NON_AGENCY_ADOPTION_FLAG' VALUE fr.OUTCOME_NON_AGENCY_ADOPTION_FLAG,
            'OUTCOME_PRIVATE_FOSTERING_FLAG' VALUE fr.OUTCOME_PRIVATE_FOSTERING_FLAG,
            'OUTCOME_CP_TRANSFER_IN_FLAG' VALUE fr.OUTCOME_CP_TRANSFER_IN_FLAG,
            'OUTCOME_CP_CONFERENCE_FLAG' VALUE fr.OUTCOME_CP_CONFERENCE_FLAG,
            'OUTCOME_CARE_LEAVER_FLAG' VALUE fr.OUTCOME_CARE_LEAVER_FLAG,
            'OTHER_OUTCOMES_EXIST_FLAG' VALUE fr.OTHER_OUTCOMES_EXIST_FLAG
        ) AS cine_referral_outcome_json,
        fr.OUTCOME_NFA_FLAG,
        fr.DIM_LOOKUP_REFRL_ENDRSN_ID_CODE,
        fr.REFRL_END_DTTM,
        fr.DIM_DEPARTMENT_ID_DESC,
        fr.DIM_WORKER_ID_DESC
    FROM
        Child_Social.FACT_REFERRALS fr
    WHERE
        fr.REFRL_START_DTTM >= ADD_MONTHS(SYSDATE, -12 * v_ssd_timeframe_years) -- Substitute your timeframe variable
    AND
        fr.DIM_PERSON_ID <> -1;  -- Exclude rows with '-1'

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_cin_episodes_person_id ON ssd_cin_episodes(cine_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cin_episodes ADD CONSTRAINT FK_ssd_cin_episodes_to_person 
    FOREIGN KEY (cine_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/






/* 
=============================================================================
Object Name: #ssd_cin_assessments
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2)
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_SINGLE_ASSESSMENT
=============================================================================
*/


BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cin_assessments';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cin_assessments
    (
        cina_assessment_id          NVARCHAR2(48) PRIMARY KEY,
        cina_person_id              NVARCHAR2(48),
        cina_referral_id            NVARCHAR2(48),
        cina_assessment_start_date  DATE,
        cina_assessment_child_seen  CHAR(1), 
        cina_assessment_auth_date   DATE,
        cina_assessment_outcome_json NVARCHAR2(2000), -- Enlarged due to comments field
        cina_assessment_outcome_nfa CHAR(1), 
        cina_assessment_team        NVARCHAR2(255),
        cina_assessment_worker_id   NVARCHAR2(48)
    )';
 
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
        cina_assessment_team,
        cina_assessment_worker_id
    )
    SELECT 
        fa.FACT_SINGLE_ASSESSMENT_ID,
        fa.DIM_PERSON_ID,
        fa.FACT_REFERRAL_ID,
        fa.START_DTTM,
        fa.SEEN_FLAG,
        fa.START_DTTM, -- This needs checking !! [TESTING]
        JSON_OBJECT( -- DB Compatibility: Oracle 12c Rel2 (12.2)
            'OUTCOME_NFA_FLAG' VALUE fa.OUTCOME_NFA_FLAG,
            'OUTCOME_NFA_S47_END_FLAG' VALUE fa.OUTCOME_NFA_S47_END_FLAG,
            'OUTCOME_STRATEGY_DISCUSSION_FLAG' VALUE fa.OUTCOME_STRATEGY_DISCUSSION_FLAG,
            'OUTCOME_CLA_REQUEST_FLAG' VALUE fa.OUTCOME_CLA_REQUEST_FLAG,
            'OUTCOME_PRIVATE_FOSTERING_FLAG' VALUE fa.OUTCOME_PRIVATE_FOSTERING_FLAG,
            'OUTCOME_LEGAL_ACTION_FLAG' VALUE fa.OUTCOME_LEGAL_ACTION_FLAG,
            'OUTCOME_PROV_OF_SERVICES_FLAG' VALUE fa.OUTCOME_PROV_OF_SERVICES_FLAG,
            'OUTCOME_PROV_OF_SB_CARE_FLAG' VALUE fa.OUTCOME_PROV_OF_SB_CARE_FLAG,
            'OUTCOME_SPECIALIST_ASSESSMENT_FLAG' VALUE fa.OUTCOME_SPECIALIST_ASSESSMENT_FLAG,
            'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG' VALUE fa.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG,
            'OUTCOME_OTHER_ACTIONS_FLAG' VALUE fa.OUTCOME_OTHER_ACTIONS_FLAG,
            'OTHER_OUTCOMES_EXIST_FLAG' VALUE fa.OTHER_OUTCOMES_EXIST_FLAG,
            'TOTAL_NO_OF_OUTCOMES' VALUE fa.TOTAL_NO_OF_OUTCOMES,
            'OUTCOME_COMMENTS' VALUE fa.OUTCOME_COMMENTS -- Dictates a larger _json size
        ) AS cina_assessment_outcome_json, 
        fa.OUTCOME_NFA_FLAG AS cina_assessment_outcome_nfa,
        fa.COMPLETED_BY_DEPT_NAME AS cina_assessment_team,
        fa.COMPLETED_BY_USER_STAFF_ID AS cina_assessment_worker_id
    FROM 
        Child_Social.FACT_SINGLE_ASSESSMENT fa
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fa.DIM_PERSON_ID
        );

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_cin_assessments_person_id ON ssd_cin_assessments(cina_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_person 
    FOREIGN KEY (cina_person_id) REFERENCES ssd_person(pers_person_id)';

    -- Note: The next constraint references 'ssd_involvements' which should be defined in your DB
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cin_assessments ADD CONSTRAINT FK_ssd_cin_assessments_to_ssd_involvements
    FOREIGN KEY (cina_assessment_worker_id) REFERENCES ssd_involvements(invo_professional_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_assessment_factors
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2)
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: This object referrences some large source tables- Instances of 45m+. 
Dependencies: 
- ssd_cin_assessments
- FACT_SINGLE_ASSESSMENT
- FACT_FORM_ANSWERS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_assessment_factors';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_assessment_factors
    (
        cina_assessment_id          NVARCHAR2(48) PRIMARY KEY,
        cina_person_id              NVARCHAR2(48),
        cina_referral_id            NVARCHAR2(48),
        cina_assessment_start_date  DATE,
        cina_assessment_child_seen  CHAR(1), 
        cina_assessment_auth_date   DATE,
        cina_assessment_outcome_json NVARCHAR2(2000), -- Enlarged due to comments field
        cina_assessment_outcome_nfa CHAR(1), 
        cina_assessment_team        NVARCHAR2(255),
        cina_assessment_worker_id   NVARCHAR2(48)
    )';

    -- Insert data
    INSERT INTO ssd_assessment_factors
    (
        cina_assessment_id,
        cina_person_id,
        cina_referral_id,
        cina_assessment_start_date,
        cina_assessment_child_seen,
        cina_assessment_auth_date,
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
        fa.START_DTTM, -- This needs checking !! [TESTING]
        JSON_OBJECT( -- DB Compatibility: Oracle 12c Rel2 (12.2)
        '1A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '1A'),
        '1B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '1B'),
        '1C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '1C'),
        '2A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '2A'),
        '2B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '2B'),
        '2C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '2C'),
        '3A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '3A'),
        '3B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '3B'),
        '3C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '3C'),
        '4A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '4A'),
        '4B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '4B'),
        '4C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '4C'),
        '5A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '5A'),
        '5B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '5B'),
        '5C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '5C'),
        '6A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '6A'),
        '6B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '6B'),
        '6C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '6C'),
        '7A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '7A'),
        '8B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '8B'),
        '8C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '8C'),
        '8D' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '8D'),
        '8E' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '8E'),
        '8F' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '8F'),
        '9A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '9A'),
        '10A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '10A'),
        '11A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '11A'),
        '12A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '12A'),
        '13A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '13A'),
        '14A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '14A'),
        '15A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '15A'),
        '16A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '16A'),
        '17A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '17A'),
        '18A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '18A'),
        '18B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '18B'),
        '18C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '18C'),
        '19A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '19A'),
        '19B' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '19B'),
        '19C' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '19C'),
        '20' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '20'),
        '21' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '21'),
        '22A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '22A'),
        '23A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '23A'),
        '24A' VALUE (SELECT ANSWER FROM Child_Social.FACT_FORM_ANSWERS WHERE FACT_FORM_ID = fa.FACT_SINGLE_ASSESSMENT_ID AND ANSWER_NO = '24A')
    ) AS cina_assessment_outcome_json

        fa.OUTCOME_NFA_FLAG AS cina_assessment_outcome_nfa,
        fa.COMPLETED_BY_DEPT_NAME AS cina_assessment_team,
        fa.COMPLETED_BY_USER_STAFF_ID AS cina_assessment_worker_id
    FROM 
        Child_Social.FACT_SINGLE_ASSESSMENT fa
    WHERE 
        fa.EXTERNAL_ID <> -1;

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_assessment_factors ADD CONSTRAINT FK_cinf_assessment_id
    FOREIGN KEY (cina_assessment_id) REFERENCES ssd_cin_assessments(cina_assessment_id)';
END;
/



/* 
=============================================================================
Object Name: ssd_cin_plans
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: [TESTING] - not sent to knowsley
Dependencies: 
- ssd_person
- FACT_CARE_PLANS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cin_plans';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cin_plans (
        cinp_cin_plan_id            NVARCHAR2(48) PRIMARY KEY,
        cinp_referral_id            NVARCHAR2(48),
        cinp_person_id              NVARCHAR2(48),
        cinp_cin_plan_start         DATE,
        cinp_cin_plan_end           DATE,
        cinp_cin_plan_team          NVARCHAR2(255),
        cinp_cin_plan_worker_id     NVARCHAR2(48)
    )';
 
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
    FROM Child_Social.FACT_CARE_PLANS fp
    JOIN Child_Social.FACT_CARE_PLAN_SUMMARY cps ON fp.FACT_CARE_PLAN_SUMMARY_ID = cps.FACT_CARE_PLAN_SUMMARY_ID
    WHERE cps.DIM_LOOKUP_PLAN_TYPE_CODE = 'FP' AND cps.DIM_LOOKUP_PLAN_STATUS_ID_CODE <> 'z'
    AND EXISTS 
    (
        -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fp.DIM_PERSON_ID
    );

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_cin_plans_person_id ON ssd_cin_plans(cinp_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cin_plans ADD CONSTRAINT FK_cinp_to_person 
    FOREIGN KEY (cinp_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/




/*
=============================================================================
Object Name: ssd_cin_visits
Description:
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+|...
Version: 1.5
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks:    Source table can be very large! Avoid any unfiltered queries.
            Notes: Does this need to be filtered by only visits in their current Referral episode?
                    however for some this ==2 weeks, others==~17 years
                --> when run for records in ssd_person c.64k records 29s runtime
Dependencies:
- FACT_CASENOTES
=============================================================================
*/

 BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cin_visits';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cin_visits
    (
        cinv_cin_visit_id           NVARCHAR2(48) PRIMARY KEY,      
        cinv_person_id              NVARCHAR2(48),
        cinv_cin_visit_date         DATE,
        cinv_cin_visit_seen         CHAR(1),
        cinv_cin_visit_seen_alone   CHAR(1),
        cinv_cin_visit_bedroom      CHAR(1)
    )';
 
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
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cin_visits ADD CONSTRAINT FK_ssd_cin_visits_to_person
    FOREIGN KEY (cinv_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/

 












/* 
=============================================================================
Object Name: ssd_s47_enquiry
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2)
Version: 1.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_S47
- FACT_CP_CONFERENCE
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_s47_enquiry';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure 
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_s47_enquiry (
        s47e_s47_enquiry_id             NVARCHAR2(48) PRIMARY KEY,
        s47e_referral_id                NVARCHAR2(48),
        s47e_person_id                  NVARCHAR2(48),
        s47e_s47_start_date             DATE,
        s47e_s47_end_date               DATE,
        s47e_s47_nfa                    CHAR(1),
        s47e_s47_outcome_json           NVARCHAR2(2000), -- Increased size to accommodate JSON data
        s47e_s47_completed_by_team      NVARCHAR2(100),
        s47e_s47_completed_by_worker    NVARCHAR2(48)
    )';

    -- Insert data
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
        JSON_OBJECT( -- DB Compatibility: Oracle 12c Rel2 (12.2)
            'OUTCOME_NFA_FLAG' VALUE s47.OUTCOME_NFA_FLAG,
            'OUTCOME_LEGAL_ACTION_FLAG' VALUE s47.OUTCOME_LEGAL_ACTION_FLAG,
            'OUTCOME_PROV_OF_SERVICES_FLAG' VALUE s47.OUTCOME_PROV_OF_SERVICES_FLAG,
            'OUTCOME_PROV_OF_SB_CARE_FLAG' VALUE s47.OUTCOME_PROV_OF_SB_CARE_FLAG,
            'OUTCOME_CP_CONFERENCE_FLAG' VALUE s47.OUTCOME_CP_CONFERENCE_FLAG,
            'OUTCOME_NFA_CONTINUE_SINGLE_FLAG' VALUE s47.OUTCOME_NFA_CONTINUE_SINGLE_FLAG,
            'OUTCOME_MONITOR_FLAG' VALUE s47.OUTCOME_MONITOR_FLAG,
            'OTHER_OUTCOMES_EXIST_FLAG' VALUE s47.OTHER_OUTCOMES_EXIST_FLAG,
            'TOTAL_NO_OF_OUTCOMES' VALUE s47.TOTAL_NO_OF_OUTCOMES,
            'OUTCOME_COMMENTS' VALUE s47.OUTCOME_COMMENTS
        ) AS s47e_s47_outcome_json,
        s47.COMPLETED_BY_DEPT_ID AS s47e_s47_completed_by_team,
        s47.COMPLETED_BY_USER_STAFF_ID AS s47e_s47_completed_by_worker
    FROM 
        Child_Social.FACT_S47 s47;

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_s47_enquiry_person_id ON ssd_s47_enquiry(s47e_person_id)';

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_s47_enquiry ADD CONSTRAINT FK_s47_person
    FOREIGN KEY (s47e_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_initial_cp_conference
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 12c Rel2 (12.2)
Version: 1.0
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_S47
- FACT_CP_CONFERENCE
- FACT_MEETINGS
=============================================================================
*/

BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_initial_cp_conference';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_initial_cp_conference (
        icpc_icpc_id                    NVARCHAR2(48) PRIMARY KEY,
        icpc_icpc_meeting_id            NVARCHAR2(48),
        icpc_s47_enquiry_id             NVARCHAR2(48),
        icpc_person_id                  NVARCHAR2(48),
        icpc_cp_plan_id                 NVARCHAR2(48),
        icpc_referral_id                NVARCHAR2(48),
        icpc_icpc_transfer_in           CHAR(1),
        icpc_icpc_target_date           DATE,
        icpc_icpc_date                  DATE,
        icpc_icpc_outcome_cp_flag       CHAR(1),
        icpc_icpc_outcome_json          NVARCHAR2(2000) -- Increased size to accommodate JSON data
        --icpc_icpc_team                  NVARCHAR2(100),
        --icpc_icpc_worker_id             NVARCHAR2(48)
    )';
 
    -- Insert data
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
        icpc_icpc_outcome_json
        --icpc_icpc_team,
        --icpc_icpc_worker_id
    )
    SELECT
        fcpc.FACT_CP_CONFERENCE_ID,
        fcpc.FACT_MEETING_ID,
        fcpc.FACT_S47_ID,
        fcpc.DIM_PERSON_ID,
        fcpc.FACT_CP_PLAN_ID,
        fcpc.FACT_REFERRAL_ID,
        fcpc.TRANSFER_IN_FLAG,
        fcpc.DUE_DTTM,
        fm.ACTUAL_DTTM,
        fcpc.OUTCOME_CP_FLAG,
        JSON_OBJECT(
            'OUTCOME_NFA_FLAG' VALUE fcpc.OUTCOME_NFA_FLAG,
            'OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG' VALUE fcpc.OUTCOME_REFERRAL_TO_OTHER_AGENCY_FLAG,
            'OUTCOME_SINGLE_ASSESSMENT_FLAG' VALUE fcpc.OUTCOME_SINGLE_ASSESSMENT_FLAG,
            'OUTCOME_PROV_OF_SERVICES_FLAG' VALUE fcpc.OUTCOME_PROV_OF_SERVICES_FLAG,
            'OUTCOME_CP_FLAG' VALUE fcpc.OUTCOME_CP_FLAG,
            'OTHER_OUTCOMES_EXIST_FLAG' VALUE fcpc.OTHER_OUTCOMES_EXIST_FLAG,
            'TOTAL_NO_OF_OUTCOMES' VALUE fcpc.TOTAL_NO_OF_OUTCOMES,
            'OUTCOME_COMMENTS' VALUE fcpc.OUTCOME_COMMENTS
        ) AS icpc_icpc_outcome_json
        --fm.DIM_DEPARTMENT_ID_DESC AS icpc_icpc_team,
        --fm.DIM_WORKER_ID_DESC AS icpc_icpc_worker_id
    FROM
        Child_Social.FACT_CP_CONFERENCE fcpc
    JOIN
        Child_Social.FACT_MEETINGS fm ON fcpc.FACT_MEETING_ID = fm.FACT_MEETING_ID
    WHERE
        fm.DIM_LOOKUP_MTG_TYPE_ID_CODE = 'CPConference';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ssd_initial_cp_conference_ ON ssd_initial_cp_conference(icpc_person_id)';

    Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_initial_cp_conference ADD CONSTRAINT FK_s47_person
    FOREIGN KEY (icpc_person_id) REFERENCES ssd_person(pers_person_id)';
END;
/





/* 
=============================================================================
Object Name: ssd_cp_plans
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 

Dependencies: 
- ssd_person
- ssd_initial_cp_conference
- FACT_CP_PLAN
=============================================================================
*/

BEGIN
    -- Check if exists & drop 
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cp_plans';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cp_plans (
        cppl_cp_plan_id                   NVARCHAR2(48) PRIMARY KEY,
        cppl_referral_id                  NVARCHAR2(48),
        cppl_initial_cp_conference_id     NVARCHAR2(48),
        cppl_person_id                    NVARCHAR2(48),
        cppl_cp_plan_start_date           DATE,
        cppl_cp_plan_end_date             DATE,
        cppl_cp_plan_team                 NVARCHAR2(48), -- [PLACEHOLDER_DATA] [TESTING]
        cppl_cp_plan_worker_id            NVARCHAR2(48), -- [PLACEHOLDER_DATA] [TESTING]
        cppl_cp_plan_initial_category     NVARCHAR2(100),
        cppl_cp_plan_latest_category      NVARCHAR2(100)
    )';

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

    -- Create constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_person_id
    FOREIGN KEY (cppl_person_id) REFERENCES ssd_person(pers_person_id)';

    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cp_plans ADD CONSTRAINT FK_cppl_initial_cp_conference_id
    FOREIGN KEY (cppl_initial_cp_conference_id) REFERENCES ssd_initial_cp_conference(icpc_icpc_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_cp_visits
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- FACT_CASENOTES
=============================================================================
*/


BEGIN
    -- Check if exists & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cp_visits';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cp_visits (
        cppv_cp_visit_id        NUMBER PRIMARY KEY,      -- Changed from INT to NUMBER
        cppv_casenote_id        NUMBER,                  -- Changed from INT to NUMBER
        cppv_cp_plan_id         NVARCHAR2(48),
        cppv_cp_visit_date      DATE,
        cppv_cp_visit_seen      CHAR(1),
        cppv_cp_visit_seen_alone CHAR(1),
        cppv_cp_visit_bedroom   CHAR(1)
    )';
 
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
        Child_Social.FACT_CP_VISIT cpv
    JOIN
        Child_Social.FACT_CASENOTES cn ON cpv.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID
    WHERE cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE IN ('STVC','STVCPCOVID');

    -- Note: Add constraints as necessary, e.g., 
    -- EXECUTE IMMEDIATE 'ALTER TABLE ssd_cp_visits ADD CONSTRAINT FK_cppv_cp_plan_id
    -- FOREIGN KEY (cppv_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_cp_reviews
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.5
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks:    Some fields - ON HOLD/Not included in SSD Ver/Iteration 1
            Tested in batch 1.3.
            Placeholder used for cppr_cp_review_quorate- FACT_CASE_PATHWAY_STEP does not 
            contain any data in the FACT_FORM_ID column so unable to link on this 
Dependencies: 
- ssd_person
- ssd_cp_plans
- FACT_CP_REVIEW
- FACT_FORM_ANSWERS [Quoracy and Participation info - ON HOLD/Not included in SSD Ver/Iteration 1]
=============================================================================
*/

BEGIN
    -- Check if table exists, & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cp_reviews';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cp_reviews
    (
        cppr_cp_review_id                   NVARCHAR2(48) PRIMARY KEY,
        cppr_cp_plan_id                     NVARCHAR2(48),
        cppr_cp_review_due                  DATE,
        cppr_cp_review_date                 DATE,
        cppr_cp_review_cancelled            NVARCHAR2(1),
        cppr_cp_review_outcome_continue_cp  CHAR(1),
        cppr_cp_review_quorate              NVARCHAR2(18),      
        cppr_cp_review_participation        NVARCHAR2(18)        -- ['PLACEHOLDER_DATA'][TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
    )';
 
    -- Insert data
    INSERT INTO ssd_cp_reviews
    (
        cppr_cp_review_id,
        cppr_cp_plan_id,
        cppr_cp_review_due,
        cppr_cp_review_date,
        cppr_cp_review_cancelled,
        cppr_cp_review_outcome_continue_cp,
        cppr_cp_review_quorate,
        cppr_cp_review_participation
    )
    SELECT
        cpr.FACT_CP_REVIEW_ID                       AS cppr_cp_review_id ,
        cpr.FACT_CP_PLAN_ID                         AS cppr_cp_plan_id,
        cpr.DUE_DTTM                                AS cppr_cp_review_due,
        cpr.MEETING_DTTM                            AS cppr_cp_review_date,
        fm.CANCELLED                                AS cppr_cp_review_cancelled,
        cpr.OUTCOME_CONTINUE_CP_FLAG                AS cppr_cp_review_outcome_continue_cp,
        MAX(CASE WHEN ffa.ANSWER_NO = 'WasConf'
            AND fms.FACT_OUTCM_FORM_ID = ffa.FACT_FORM_ID
            THEN ffa.ANSWER END)                    AS cppr_cp_review_quorate,    
        'PLACEHOLDER DATA'                          AS cppr_cp_review_participation
    FROM
        Child_Social.FACT_CP_REVIEW cpr
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
    WHERE EXISTS ( -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = cpr.DIM_PERSON_ID
    )
    GROUP BY cpr.FACT_CP_REVIEW_ID,
        cpr.FACT_CP_PLAN_ID,
        cpr.DUE_DTTM,
        cpr.MEETING_DTTM,
        fm.CANCELLED,
        cpr.OUTCOME_CONTINUE_CP_FLAG;

    -- Add constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cp_reviews ADD CONSTRAINT FK_ssd_cp_reviews_to_cp_plans 
    FOREIGN KEY (cppr_cp_plan_id) REFERENCES ssd_cp_plans(cppl_cp_plan_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_cla_episodes
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.5
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
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

BEGIN
    -- Check if table exists, & drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cla_episodes';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- Create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cla_episodes (
        clae_cla_episode_id                 NVARCHAR2(48) PRIMARY KEY,
        clae_person_id                      NVARCHAR2(48),
        clae_cla_episode_start              DATE,
        clae_cla_episode_start_reason       NVARCHAR2(100),
        clae_cla_primary_need               NVARCHAR2(100),
        clae_cla_episode_ceased             DATE,
        clae_cla_episode_cease_reason       NVARCHAR2(255),
        clae_cla_id                         NVARCHAR2(48),
        clae_referral_id                    NVARCHAR2(48),
        clae_cla_review_last_iro_contact_date DATE
    )';
 
    -- Insert data
    INSERT INTO ssd_cla_episodes (
        clae_cla_episode_id,
        clae_person_id,
        clae_cla_episode_start,
        clae_cla_episode_start_reason,
        clae_cla_primary_need,
        clae_cla_episode_ceased,
        clae_cla_episode_cease_reason,
        clae_cla_id,
        clae_referral_id,
        clae_cla_review_last_iro_contact_date
    )
    SELECT
        fce.FACT_CARE_EPISODES_ID               AS clae_cla_episode_id,
        fce.DIM_PERSON_ID                       AS clae_person_id,
        fce.CARE_START_DATE                     AS clae_cla_episode_start,
        fce.CARE_REASON_DESC                    AS clae_cla_episode_start_reason,
        fce.CIN_903_CODE                        AS clae_cla_primary_need,
        fce.CARE_END_DATE                       AS clae_cla_episode_ceased,
        fce.CARE_REASON_END_DESC                AS clae_cla_episode_cease_reason,
        fc.FACT_CLA_ID                          AS clae_cla_id,                    
        fc.FACT_REFERRAL_ID                     AS clae_referral_id,
            (SELECT MAX(CASE WHEN fce.DIM_PERSON_ID = cn.DIM_PERSON_ID
            --AND cn.DIM_CREATED_BY_DEPT_ID IN (5956,727)
            AND cn.DIM_LOOKUP_CASNT_TYPE_ID_CODE = 'IRO'
            THEN cn.EVENT_DTTM END))                                                        
                                                AS clae_cla_review_last_iro_contact_date
    FROM
        Child_Social.FACT_CARE_EPISODES fce
    JOIN
        Child_Social.FACT_CLA fc ON fce.fact_cla_id = fc.FACT_CLA_ID
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
        fce.CARE_START_DATE,
        fce.CARE_REASON_DESC,
        fce.CIN_903_CODE,
        fce.CARE_END_DATE,
        fce.CARE_REASON_END_DESC,
        fc.FACT_CLA_ID,                    
        fc.FACT_REFERRAL_ID,
        cn.DIM_PERSON_ID;

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX idx_clae_cla_worker_id ON ssd_cla_episodes (clae_cla_worker_id)';
    
    -- Add constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cla_episodes ADD CONSTRAINT FK_clae_to_professional 
    FOREIGN KEY (clae_cla_worker_id) REFERENCES ssd_involvements (invo_professional_id)';
END;
/




/* 
=============================================================================
Object Name: ssd_cla_convictions
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.1
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_OFFENCE
=============================================================================
*/
BEGIN
    -- if exists, drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cla_convictions';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cla_convictions (
        clac_cla_conviction_id      NVARCHAR2(48) PRIMARY KEY,
        clac_person_id              NVARCHAR2(48),
        clac_cla_conviction_date    DATE,
        clac_cla_conviction_offence NVARCHAR2(1000)
    )';

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
        Child_Social.FACT_OFFENCE fo
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fo.DIM_PERSON_ID
        );

   
    -- Add constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cla_convictions ADD CONSTRAINT FK_clac_to_clae 
    FOREIGN KEY (clac_person_id) REFERENCES ssd_cla_episodes(clae_person_id)';
END;
/





/* 
=============================================================================
Object Name: ssd_cla_health
Description: 
Author: D2I
Last Modified Date: 22/01/24
DB Compatibility: Oracle 8i+
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- FACT_HEALTH_CHECK 
- ssd_cla_episodes (FK)
=============================================================================
*/

BEGIN
    -- if exists, drop
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE ssd_cla_health';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- create structure
    EXECUTE IMMEDIATE 'CREATE TABLE ssd_cla_health (
        clah_health_check_id             NVARCHAR2(48) PRIMARY KEY,
        clah_person_id                   NVARCHAR2(48),
        clah_health_check_type           NVARCHAR2(500),
        clah_health_check_date           DATE,
        clah_health_check_status         NVARCHAR2(48)
    )';
 
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
        fhc.DIM_LOOKUP_HC_TYPE_DESC,
        fhc.START_DTTM,
        fhc.DIM_LOOKUP_EXAM_STATUS_CODE
    FROM
        Child_Social.FACT_HEALTH_CHECK fhc
    WHERE EXISTS 
        (   -- only ssd relevant records
        SELECT 1 
        FROM ssd_person p
        WHERE p.pers_person_id = fhc.DIM_PERSON_ID
        );


    -- add constraint(s)
    EXECUTE IMMEDIATE 'ALTER TABLE ssd_cla_health ADD CONSTRAINT FK_clah_to_clae 
    FOREIGN KEY (clah_person_id) REFERENCES ssd_cla_episodes(clae_person_id)';

    -- Create index(es)
    EXECUTE IMMEDIATE 'CREATE INDEX idx_clah_person_id ON ssd_cla_health (clah_person_id)';
END;
/









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

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = f903.DIM_PERSON_ID
    );

-- add constraint(s)
ALTER TABLE ssd_cla_immunisations
ADD CONSTRAINT FK_ssd_cla_immunisations_person
FOREIGN KEY (clas_person_id) REFERENCES ssd_person(pers_person_id);


-- Create index(es)
CREATE NONCLUSTERED INDEX IX_ssd_cla_immunisations_person_id ON ssd_cla_immunisations (clai_person_id);

-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));

/* 
=============================================================================
Object Name: ssd_cla_substance_misuse
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
SET @TableName = N'ssd_cla_substance_misuse';
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

WHERE EXISTS 
    (   -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
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
Last Modified Date: 09/01/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
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
 
-- Create structure
CREATE TABLE ssd_cla_placement (
    clap_cla_placement_id               NVARCHAR(48) PRIMARY KEY,
    clap_cla_id                         NVARCHAR(48),
    clap_cla_placement_start_date       DATETIME,
    clap_cla_placement_type             NVARCHAR(100),
    clap_cla_placement_urn              NVARCHAR(48),
    clap_cla_placement_distance         FLOAT, -- Float precision determined by value (or use DECIMAL(3, 2), -- Adjusted to fixed precision)
    clap_cla_placement_la               NVARCHAR(48),
    clap_cla_placement_provider         NVARCHAR(48),
    clap_cla_placement_postcode         NVARCHAR(8),
    clap_cla_placement_end_date         DATETIME,
    clap_cla_placement_change_reason    NVARCHAR(100)
);
 
-- Insert data
INSERT INTO ssd_cla_placement (
    clap_cla_placement_id,
    clap_cla_id,
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
    fcp.FACT_CLA_ID                             AS clap_cla_id,                                
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
    'PLACEHOLDER_DATA'                          AS clap_cla_placement_la,                               -- [PLACEHOLDER_DATA] [TESTING]
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
CREATE NONCLUSTERED INDEX idx_clap_cla_episode_id ON ssd_cla_placement(clap_cla_episode_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_cla_review
Description: 
Author: D2I
Last Modified Date: 12/01/24
DB Compatibility: SQL Server 2014+|...
Version: 1.6
            1.5: clar_cla_id change from clar_cla_episode_id

Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cla_episodes
- FACT_CLA_REVIEW
- FACT_MEETING_SUBJECTS 
- FACT_MEETINGS
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_review';
PRINT 'Creating table: ' + @TableName;



-- Check if exists & drop
IF OBJECT_ID('ssd_cla_review', 'U') IS NOT NULL DROP TABLE ssd_cla_review;
 
-- Create structure
CREATE TABLE ssd_cla_review (
    clar_cla_review_id                      NVARCHAR(48) PRIMARY KEY,
    clar_cla_id                             NVARCHAR(48),
    clar_cla_review_due_date                DATETIME,
    clar_cla_review_date                    DATETIME,
    clar_cla_review_cancelled               NVARCHAR(48),
    clar_cla_review_participation           NVARCHAR(100)
    );
 
-- Insert data
INSERT INTO ssd_cla_review (
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
 
 
GROUP BY fcr.FACT_CLA_REVIEW_ID,
    fcr.FACT_CLA_ID,                                            
    fcr.DIM_PERSON_ID,                              
    fcr.DUE_DTTM,                                    
    fcr.MEETING_DTTM,                              
    fm.CANCELLED,
    fms.FACT_MEETINGS_ID


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
Last Modified Date: 11/12/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Adapted from 1.3 ver, needs re-test also with Knowsley. 

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
    ffa.ANSWER_NO IN ('ORDERYEAR', 'ORDERMONTH', 'ORDERDATE', 'PREVADOPTORD', 'INENG');




-- Create structure
CREATE TABLE ssd_cla_previous_permanence (
    lapp_table_id                               NVARCHAR(48) PRIMARY KEY,
    lapp_person_id                              NVARCHAR(48),
    lapp_previous_permanence_option             NVARCHAR(200),
    lapp_previous_permanence_la                 NVARCHAR(100),
    lapp_previous_permanence_order_date_json    NVARCHAR(MAX)
);

-- Insert data 
INSERT INTO ssd_cla_previous_permanence (
               lapp_table_id,
               lapp_person_id,
               lapp_previous_permanence_option,
               lapp_previous_permanence_la,
               lapp_previous_permanence_order_date_json
           )
SELECT
    ff.FACT_FORM_ID AS lapp_table_id,
    ff.DIM_PERSON_ID AS lapp_person_id,
    MAX(CASE WHEN ffa.ANSWER_NO = 'PREVADOPTORD'    THEN ffa.ANSWER END) AS lapp_previous_permanence_option,
    MAX(CASE WHEN ffa.ANSWER_NO = 'INENG'           THEN ffa.ANSWER END) AS lapp_previous_permanence_la,
    (
        SELECT 
            MAX(CASE WHEN sub.ANSWER_NO = 'ORDERYEAR'       THEN sub.ANSWER END) as 'ORDERYEAR',
            MAX(CASE WHEN sub.ANSWER_NO = 'ORDERMONTH'      THEN sub.ANSWER END) as 'ORDERMONTH',
            MAX(CASE WHEN sub.ANSWER_NO = 'ORDERDATE'       THEN sub.ANSWER END) as 'ORDERDATE'

        FROM 
            Child_Social.FACT_FORM_ANSWERS sub
        WHERE 
            sub.FACT_FORM_ID = ff.FACT_FORM_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS lapp_previous_permanence_order_date_json
FROM
    Child_Social.FACT_FORM_ANSWERS ffa
JOIN
    Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID
WHERE
    ffa.EXTERNAL_ID <> -1 
    AND ffa.DIM_ASSESSMENT_TEMPLATE_ID_DESC LIKE '%OUTCOME%'

GROUP BY ff.FACT_FORM_ID, ff.DIM_PERSON_ID;




/* PREVIOUS VERSION 
-- Create structure
CREATE TABLE ssd_cla_previous_permanence (
    lapp_table_id                             NVARCHAR(48) PRIMARY KEY,
    lapp_person_id                            NVARCHAR(48),
    lapp_previous_permanence_order_date       NVARCHAR(100), -- Placeholder for combination data
    lapp_previous_permanence_option           NVARCHAR(200),
    lapp_previous_permanence_la               NVARCHAR(100)
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
    ffa.FACT_FORM_ID                AS lapp_table_id,
    ff.DIM_PERSON_ID                AS lapp_person_id,
    'PLACEHOLDER_DATA'              AS lapp_previous_permanence_order_date,              -- [TESTING] {PLACEHOLDER_DATA}
    ffa_answer_prev.PREVADOPTORD    AS lapp_previous_permanence_option,
    ffa_answer_ineng.INENG          AS lapp_previous_permanence_la
FROM 
    Child_Social.FACT_FORMS ff

LEFT JOIN 
    Child_Social.FACT_FORM_ANSWERS ffa ON ff.FACT_FORM_ID = ffa.FACT_FORM_ID
LEFT JOIN 
    (
    SELECT FACT_FORM_ID, ANSWER AS PREVADOPTORD 
    FROM Child_Social.FACT_FORM_ANSWERS 
    WHERE ANSWER_NO = 'PREVADOPTORD'
    ) 
    ffa_answer_prev ON ffa.FACT_FORM_ID = ffa_answer_prev.FACT_FORM_ID
LEFT JOIN 
    (
    SELECT FACT_FORM_ID, ANSWER AS INENG 
    FROM Child_Social.FACT_FORM_ANSWERS 
    WHERE ANSWER_NO = 'INENG'
    ) 
    ffa_answer_ineng ON ffa.FACT_FORM_ID = ffa_answer_ineng.FACT_FORM_ID;


*/


-- create index(es)


-- Add constraint(s)
ALTER TABLE ssd_cla_previous_permanence ADD CONSTRAINT FK_lapp_person_id
FOREIGN KEY (lapp_person_id) REFERENCES ssd_cla_episodes(clae_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_cla_care_plan
Description: 
Author: D2I
Last Modified Date: 04/01/23
DB Compatibility: SQL Server 2014+|...
Version: 1.4
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:    FACT_FORM_ANSWERS.ANSWER_NO = 'ICP' 
            Most recent date in FACT_FORM_ANSWERS.ANSWERED_DTTM once above filter applied
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
        ffa.DIM_ASSESSMENT_TEMPLATE_ID_CODE IN ('2066', '29')
        AND ffa.ANSWER_NO                   IN ('CPFUP1', 'CPFUP10', 'CPFUP2', 'CPFUP3', 'CPFUP4', 'CPFUP5', 'CPFUP6', 'CPFUP7', 'CPFUP8', 'CPFUP9')
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
    --lacp_referral_id                  NVARCHAR(48),
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
                
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP1,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP2,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP3,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP4,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP5,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP6,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP7,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP8,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END), NULL) AS CPFUP9,
            COALESCE(MAX(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END), NULL) AS CPFUP10
    
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
ALTER TABLE ssd_cla_care_plan ADD CONSTRAINT FK_lacp_cla_episode_id
FOREIGN KEY (lacp_cla_episode_id) REFERENCES ssd_cla_episodes(clae_person_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));


/* 
=============================================================================
Object Name: ssd_cla_visits
Description: 
Author: D2I
Last Modified Date: 12/01/24
DB Compatibility: SQL Server 2014+|...
Version: 1.6
            1.5 pers_id and cla_id added

Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
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
 
-- Create structure
CREATE TABLE ssd_cla_visits (
    clav_cla_visit_id          NVARCHAR(48) PRIMARY KEY,
    clav_casenote_id           NVARCHAR(48),
    clav_person_id             NVARCHAR(48),
    clav_cla_id                NVARCHAR(48),
    clav_cla_visit_date        DATETIME,
    clav_cla_visit_seen        NCHAR(1),
    clav_cla_visit_seen_alone  NCHAR(1)
);
 
-- Insert data
INSERT INTO ssd_cla_visits (
    clav_cla_visit_id,
    clav_casenote_id,
    clav_person_id,
    clav_cla_id,
    clav_cla_visit_date,
    clav_cla_visit_seen,
    clav_cla_visit_seen_alone
)
 
SELECT
    clav.FACT_CLA_VISIT_ID      AS clav_cla_visit_id,
    clav.FACT_CASENOTE_ID       AS clav_casenote_id,
    clav.DIM_PERSON_ID          AS clav_person_id,
    clav.FACT_CLA_ID            AS clav_cla_id,
    clav.VISIT_DTTM             AS clav_cla_visit_date,
    cn.SEEN_FLAG                AS clav_cla_visit_seen,
    cn.SEEN_ALONE_FLAG          AS clav_cla_visit_seen_alone
FROM
    Child_Social.FACT_CLA_VISIT AS clav
 
LEFT JOIN
    Child_Social.FACT_CASENOTES AS cn ON clav.FACT_CASENOTE_ID = cn.FACT_CASENOTE_ID;


-- Add constraint(s)
ALTER TABLE ssd_cla_visits ADD CONSTRAINT FK_clav_cla_episode_id 
FOREIGN KEY (clav_cla_episode_id) REFERENCES ssd_cla_episodes(clae_cla_episode_id);


-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



/* 
=============================================================================
Object Name: ssd_sdq_scores V6
Description: 
Author: D2I
Last Modified Date: 15/01/24
DB Compatibility: SQL Server 2014+|...
Version: 1.6
Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:    ASSESSMENT_TEMPLATE_ID_CODEs ranges validated at 12/12/23
            See ticket https://trello.com/c/2hWQH0bD for potential sdq history field
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


/* V8 */
-- Create structure
CREATE TABLE ssd_sdq_scores (
    csdq_table_id               NVARCHAR(48) PRIMARY KEY,
    csdq_form_id                NVARCHAR(48),
    csdq_person_id              NVARCHAR(48),
    csdq_sdq_score              NVARCHAR(48),
    csdq_sdq_details_json       NVARCHAR(1000)          
);
 
-- Insert data
INSERT INTO ssd_sdq_scores (
    csdq_table_id,
    csdq_form_id,
    csdq_person_id,
    csdq_sdq_score,
    csdq_sdq_details_json
)
SELECT
    ff.FACT_FORM_ID         AS csdq_table_id,
    ffa.FACT_FORM_ID        AS csdq_form_id,
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
    ) AS csdq_sdq_details_json
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
        -- the most recent csdq_form_id will have a row number of 1.
        ROW_NUMBER() OVER (PARTITION BY csdq_person_id ORDER BY csdq_form_id DESC) AS rn
    FROM
        ssd_sdq_scores
)

-- delete all records from the #ssd_sdq_scores table where row number(rn) > 1
-- i.e. keep only the most recent
DELETE FROM RankedSDQScores
WHERE rn > 1;

-- identify and remove exact dups
;WITH DuplicateSDQScores AS (
    SELECT
        *,
        -- Assign row num to each set of dups,
        -- partitioned by all columns that could potentially make a row unique
        ROW_NUMBER() OVER (PARTITION BY csdq_table_id, csdq_person_id, csdq_sdq_details_json ORDER BY csdq_form_id) AS row_num
    FROM
        ssd_sdq_scores
)
-- Delete dups
DELETE FROM DuplicateSDQScores
WHERE row_num > 1;

-- [TESTING]
select * from ssd_sdq_scores
order by csdq_person_id desc, csdq_form_id desc;

-- -- non-spec column clean-up 
-- ALTER TABLE ssd_sdq_scores DROP COLUMN csdq_sdq_score;


/* end V8 */



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

WHERE EXISTS 
    ( -- only ssd relevant records
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
Last Modified Date: 12/01/24 JH
DB Compatibility: SQL Server 2014+|...
Version: 1.6
            1.5: worker/p.a id field changed to descriptive name towards AA reporting

Status: [Dev, *Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:    Dev: Note that <multiple> refs to ssd_person need changing when porting code to tempdb.. versions. 
            Dev: Ensure index on ssd_person.pers_person_id is intact to ensure performance on <FROM ssd_person> references in the CTEs(added for performance)
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



-- Create structure
CREATE TABLE ssd_care_leavers
(
    clea_table_id                       NVARCHAR(48),
    clea_person_id                      NVARCHAR(48),
    clea_care_leaver_eligibility        NVARCHAR(100),
    clea_care_leaver_in_touch           NVARCHAR(100),
    clea_care_leaver_latest_contact     DATETIME,
    clea_care_leaver_accommodation      NVARCHAR(100),
    clea_care_leaver_accom_suitable     NVARCHAR(100),
    clea_care_leaver_activity           NVARCHAR(100),
    clea_pathway_plan_review_date       DATETIME,
    clea_care_leaver_personal_advisor   NVARCHAR(100),
    clea_care_leaver_allocated_team     NVARCHAR(48),
    clea_care_leaver_worker_id          NVARCHAR(48)        -- [TESTING] Should this field retain the _id suffix post v1.5 changes? 
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
    clea_care_leaver_worker_id, 
    clea_care_leaver_allocated_team                    
)
SELECT 
    fccl.FACT_CLA_CARE_LEAVERS_ID                   AS clea_table_id, 
    fccl.DIM_PERSON_ID                              AS clea_person_id, 
    dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC          AS clea_care_leaver_eligibility, 
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE              AS clea_care_leaver_in_touch, 
    fccl.IN_TOUCH_DTTM                              AS clea_care_leaver_latest_contact, 
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC         AS clea_care_leaver_accommodation, 
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC     AS clea_care_leaver_accom_suitable, 
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC              AS clea_care_leaver_activity, 

    MAX(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
        AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH'
        THEN fcp.MODIF_DTTM END)                    AS clea_pathway_plan_review_date,

    ih.PersonalAdvisorName                          AS clea_care_leaver_personal_advisor,
    ih.CurrentWorkerName                            AS clea_care_leaver_worker_id,
    ih.AllocatedTeamName                            AS clea_care_leaver_allocated_team
FROM 
    Child_Social.FACT_CLA_CARE_LEAVERS AS fccl

LEFT JOIN Child_Social.DIM_CLA_ELIGIBILITY AS dce ON fccl.DIM_PERSON_ID = dce.DIM_PERSON_ID     -- towards clea_care_leaver_eligibility

LEFT JOIN Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID         -- towards clea_pathway_plan_review_date
    AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = 'PATH'               

LEFT JOIN InvolvementHistoryCTE AS ih ON fccl.DIM_PERSON_ID = ih.DIM_PERSON_ID                  -- connect with CTE aggr data      
 
WHERE
    -- Exists-on ssd_person clause should already filter these, this only a fail-safe
    fccl.FACT_CLA_CARE_LEAVERS_ID <> -1
 
GROUP BY
    fccl.FACT_CLA_CARE_LEAVERS_ID,
    fccl.DIM_PERSON_ID,
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

/* End V4 */





-- Add index(es)
CREATE INDEX IDX_clea_person_id ON ssd_care_leavers(clea_person_id);

-- Add constraint(s)
ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leavers_person
FOREIGN KEY (clea_person_id) REFERENCES ssd_person(pers_person_id);

ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_care_leaver_worker
FOREIGN KEY (clea_care_leaver_worker_id) REFERENCES ssd_involvements(invo_professional_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));




/* 
=============================================================================
Object Name: ssd_permanence
Description: 
Author: D2I
Last Modified Date: 18/01/23 JH
DB Compatibility: SQL Server 2014+|...
Version: 1.7
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
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


-- Create structure
CREATE TABLE ssd_permanence (
    perm_table_id                        NVARCHAR(48) PRIMARY KEY,
    perm_person_id                       NVARCHAR(48),
    perm_cla_id                          NVARCHAR(48),
    perm_entered_care_date               DATETIME,              
    perm_adm_decision_date               DATETIME,
    perm_part_of_sibling_group           NCHAR(1),
    perm_siblings_placed_together        INT,
    perm_siblings_placed_apart           INT,
    perm_ffa_cp_decision_date            DATETIME,              
    perm_placement_order_date            DATETIME,
    perm_matched_date                    DATETIME,
    perm_placed_for_adoption_date        DATETIME,              
    perm_adopted_by_carer_flag           NCHAR(1),              -- [TESTING] (datatype changed)
    perm_placed_ffa_cp_date              DATETIME,
    perm_placed_foster_carer_date        DATETIME,
    perm_placement_provider_urn          NVARCHAR(48),  
    perm_decision_reversed_date          DATETIME,                  
    perm_decision_reversed_reason        NVARCHAR(100),
    perm_permanence_order_date           DATETIME,              
    perm_permanence_order_type           NVARCHAR(100),        
    perm_adoption_worker                 NVARCHAR(100),                   -- [TESTING] (datatype changed)
);
 
 
-- Insert data
INSERT INTO ssd_permanence (
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_entered_care_date,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_ffa_cp_date,
    perm_placed_foster_carer_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker
)  
SELECT
    fce.FACT_CARE_EPISODES_ID               AS perm_table_id,
    fce.DIM_PERSON_ID                       AS perm_person_id,
    fce.FACT_CLA_ID                         AS perm_cla_id,
    fc.START_DTTM                           AS perm_entered_care_date,
    CASE
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.DECISION_DTTM
    END                                     AS perm_adm_decision_date,            --Adoption only  
        CASE
        WHEN fa.ADOPTED_BY_CARER_FLAG = 'Y' THEN fa.SIBLING_GROUP
        ELSE NULL
    END                                     AS perm_part_of_sibling_group,        --Adoption only  
    CASE
        WHEN fa.ADOPTED_BY_CARER_FLAG = 'Y' THEN fa.NUMBER_TOGETHER  
        ELSE NULL
    END                                     AS perm_siblings_placed_together,     --Adoption only  
        CASE
        WHEN fa.ADOPTED_BY_CARER_FLAG = 'Y' THEN fa.NUMBER_APART  
        ELSE NULL
    END                                     AS perm_siblings_placed_apart,        --Adoption only                    
    CASE
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fcpl.FFA_IS_PLAN_DATE
    END                                     AS perm_ffa_cp_decision_date,        --ffa/cp cases only
    CASE
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.PLACEMENT_ORDER_DTTM
    END                                     AS perm_placement_order_date,        --Adoption only          
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.MATCHING_DTTM
    END                                     AS perm_matched_date,                --Adoption only
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fcpl.START_DTTM
    END                                     AS perm_placed_for_adoption_date,    --Adoption only  
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.ADOPTED_BY_CARER_FLAG
    END                                     AS perm_adopted_by_carer_flag,       --Adoption only
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.FOSTER_TO_ADOPT_DTTM
    END                                     AS perm_placed_ffa_cp_date,          --ffa/cp cases only
    CASE
        WHEN fa.ADOPTED_BY_CARER_FLAG = 'Y'
        THEN fcpl.START_DTTM
    END                                     AS perm_placed_foster_carer_date,     --ffa/cp cases only
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fce.OFSTED_URN
    END                                     AS perm_placement_provider_urn,      --Adoption only  
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.NO_LONGER_PLACED_DTTM
    END                                     AS perm_decision_reversed_date,      --Adoption only                                
        CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE
            IN ('E1','E12','E11')
        THEN fa.DIM_LOOKUP_ADOP_REASON_CEASED_CODE
    END                                     AS perm_decision_reversed_reason,    --Adoption only    
    fce.PLACEND                             AS perm_permanence_order_date,
    CASE                                                                            
        WHEN fce.CARE_REASON_END_CODE IN ('E1','E12','E11') THEN 'Adoption'
        WHEN fce.CARE_REASON_END_CODE IN ('E48','E44','E43','45','E45','E47','E46') THEN 'Special Guardianship Order'
        WHEN fce.CARE_REASON_END_CODE IN ('45','E41') THEN 'Child Arrangements/ Residence Order'
        ELSE NULL
    END                                     AS perm_permanence_order_type,      
 
    fa.ADOPTION_SOCIAL_WORKER_NAME            AS perm_adoption_worker            -- Note that duplicate -1 seen in raw data
 
FROM Child_Social.FACT_CARE_EPISODES fce
 
LEFT JOIN Child_Social.FACT_ADOPTION AS fa
    ON fa.DIM_PERSON_ID = fce.DIM_PERSON_ID
    AND fce.CARE_REASON_END_CODE IN ('E1','E12','E11')
   
LEFT JOIN Child_Social.FACT_CLA AS fc                                
    ON fc.FACT_CLA_ID = fce.FACT_CLA_ID                                          -- towards perm_adm_decision_date
 
LEFT JOIN Child_Social.FACT_CLA_PLACEMENT AS fcpl            
    ON fcpl.FACT_CLA_PLACEMENT_ID = fce.FACT_CLA_PLACEMENT_ID
 
WHERE fce.PLACEND IS NOT NULL
AND CARE_REASON_END_CODE IN ('E48','E1','E44','E12','E11','E43','45','E41','E45','E47','E46');


-- Add constraint(s)
ALTER TABLE ssd_permanence ADD CONSTRAINT FK_perm_person_id
FOREIGN KEY (perm_person_id) REFERENCES ssd_cla_episodes(clae_person_id);



-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
-- WHERE EXISTS 
--      ( -- only ssd relevant records
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
    s251_id                 NVARCHAR(48) PRIMARY KEY, 
    s251_cla_placement_id   NVARCHAR(48), 
    s251_placeholder_1      NVARCHAR(48),
    s251_placeholder_2      NVARCHAR(48),
    s251_placeholder_3      NVARCHAR(48),
    s251_placeholder_4      NVARCHAR(48)
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
-- WHERE EXISTS 
--  ( -- only ssd relevant records
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
    ( -- only ssd relevant records
    SELECT 1 
    FROM ssd_person p
    WHERE p.pers_person_id = cafe.DIM_PERSON_ID
    );

-- Create index(es)
CREATE NONCLUSTERED INDEX IDX_ssd_early_help_episodes_person_id ON ssd_early_help_episodes(earl_person_id);

-- Create constraint(s)
ALTER TABLE ssd_early_help_episodes ADD CONSTRAINT FK_earl_to_person 
FOREIGN KEY (earl_person_id) REFERENCES ssd_person(pers_person_id);




-- [TESTING] Increment /print progress
SET @TestProgress = @TestProgress + 1;
PRINT 'Table created: ' + @TableName;
PRINT 'Test Progress Counter: ' + CAST(@TestProgress AS NVARCHAR(10));



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
Last Modified Date: 12/01/24
DB Compatibility: SQL Server 2014+|...
Version: 0.9
Status: [*Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

- FACT_INVOLVEMENTS
- ssd_person
=============================================================================
*/
ALTER TABLE ssd_person
ADD involvement_history NVARCHAR(4000),  -- Adjust data type as needed
    involvement_type_story_json NVARCHAR(1000);  -- Adjust data type as needed


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
        )) AS involvement_history
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
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
    WHERE fi.rn = 1

    AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
        SELECT 1 FROM #ssd_person p
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
                SELECT 1 FROM #ssd_person p
                WHERE p.pers_person_id = fi3.DIM_PERSON_ID
            )

            ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
            FOR XML PATH('')
        ), 1, 1, '') AS InvolvementTypeStory
    FROM 
        Child_Social.FACT_INVOLVEMENTS fi
    
    WHERE 
        EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
            SELECT 1 FROM #ssd_person p
            WHERE p.pers_person_id = fi.DIM_PERSON_ID
        )
    GROUP BY 
        fi.DIM_PERSON_ID
)


-- Update
UPDATE p
SET
    p.involvement_history = ih.involvement_history,
    p.involvement_type_story_json = CONCAT('[', its.InvolvementTypeStory, ']')
FROM ssd_person p
LEFT JOIN InvolvementHistoryCTE ih ON p.per_person_id = ih.DIM_PERSON_ID
LEFT JOIN InvolvementTypeStoryCTE its ON p.per_person_id = its.DIM_PERSON_ID;
