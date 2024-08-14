
-- 
GO 

DECLARE @sql NVARCHAR(MAX) = N'';

DECLARE @Run_SSD_As_Temporary_Tables BIT;
SET     @Run_SSD_As_Temporary_Tables = 0;  -- 1==Single use SSD extract uses tempdb..# | 0==Persistent SSD table set up



-- Point to correct DB/TABLE_CATALOG if required
USE HDM_Local; 
-- ALTER USER user_name WITH DEFAULT_SCHEMA = ssd_development; -- Commented due to permissions issues



/* [TESTING] 
Set up (to be removed from live v2+)
*/
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




/* Start 

        Non-Core Liquid Logic elements extracts (E.g. SEND/EH Module data)
        
        */



/*
=============================================================================
Object Name: ssd_person NON-CORE UPDATE
Version: 0.1
Status: [DT]esting
Remarks: Back-filling ssd_person table with non-core SSD records. 
        This process appends ALL records from DIM_PERSON for further data testing
Dependencies:
- As ssd_person
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_person-ADDITIONAL_TESTING_DATA';
PRINT 'Updating table: ' + @TableName;

-- add ssd_flag column (identify core and non-core records for testing)
-- ALTER TABLE ssd_development.ssd_person ADD ssd_flag INT; -- 1==filtered core record, via initial filtered insert 
                                                            -- 0==non-core record brought through as part of update

-- existing records set ssd_flag to 1 (core/filtered ssd records)
-- UPDATE ssd_development.ssd_person SET ssd_flag = 1;


-- Insert new records into ssd_person with ssd_flag set to 0

-- CTE to get a no_upn_code 
-- (assumption here is that all codes will be the same/current)
WITH f903_data_CTE AS (
    SELECT 
        -- get the most recent no_upn_code if exists
        dim_person_id, 
        no_upn_code,
        ROW_NUMBER() OVER (PARTITION BY dim_person_id ORDER BY no_upn_code DESC) AS rn
    FROM 
        HDM.Child_Social.fact_903_data
    WHERE
        no_upn_code IS NOT NULL -- sparse data in this field, filter for performance
)
INSERT INTO ssd_development.ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_sex,       -- sex and gender currently extracted as one
    pers_gender,    -- 
    pers_ethnicity,
    pers_dob,
    pers_common_child_id,                               
    pers_upn_unknown,                                  
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality,
    ssd_flag
)
SELECT
    p.LEGACY_ID,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    'SSD_PH' AS pers_sex,                   -- Placeholder for those LAs that store sex and gender independently
    p.GENDER_MAIN_CODE,                     -- Gender as used in stat-returns
    p.ETHNICITY_MAIN_CODE,
    CASE WHEN (p.DOB_ESTIMATED) = 'N'              
        THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'N'
        ELSE NULL 
    END, -- or NULL
    NULL AS pers_common_child_id, -- Set to NULL as default(dev) / or set to NHS num
    COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
    p.EHM_SEN_FLAG,
    CASE WHEN (p.DOB_ESTIMATED) = 'Y'              
        THEN p.BIRTH_DTTM -- Set to BIRTH_DTTM when DOB_ESTIMATED = 'Y'
        ELSE NULL 
    END, -- or NULL
    p.DEATH_DTTM,
    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI') -- check for child relation only
        THEN 'Y'
        ELSE NULL -- No child relation found
    END,
    p.NATNL_CODE,
    0 AS ssd_flag -- Non-core data flag for D2I filter testing [TESTING]
FROM
    HDM.Child_Social.DIM_PERSON AS p

-- [TESTING][PLACEHOLDER] 903 table refresh only in reporting period?
LEFT JOIN (
    -- no other accessible location for UPN data than 903 table
    SELECT 
        dim_person_id, 
        no_upn_code
    FROM 
        f903_data_CTE
    WHERE 
        rn = 1
) AS f903 
ON 
    p.DIM_PERSON_ID = f903.dim_person_id


-- Only select records that are not already in ssd_person 
-- (these become our non-core 0 flag records)
WHERE 
    -- ignore the admin/false records
    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    -- AND YEAR(p.BIRTH_DTTM) != 1900 -- #DtoI-1814

    -- don't re-import those that are already in ssd_person
    AND p.DIM_PERSON_ID NOT IN (SELECT pers_person_id FROM ssd_development.ssd_person);
   

-- [TESTING] Table added
PRINT 'Table UPDATED: ' + @TableName;



/*
=============================================================================
Object Name: ssd_involvements NON-CORE UPDATE
Version: 0.2
            0.1: apply CAST(p.pers_person_id AS INT) #DtoI-1799 170724 RH
Status: [DT]esting
Remarks: Back-filling ssd_involvements table with non-core SSD records. 
        This process appends ALL involvements records for further data testing
Dependencies:
- As ssd_involvements
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_involvements-ADDITIONAL_TESTING_DATA';
PRINT 'Updating table: ' + @TableName;


-- Clear all data from the table
TRUNCATE TABLE ssd_development.ssd_involvements;

-- RE-Insert data (now for larger unfiltered ssd_person cohort)
INSERT INTO ssd_development.ssd_involvements (
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
    CASE 
        -- replace admin -1 values for when no worker associated
        WHEN fi.DIM_WORKER_ID IN ('-1', -1) THEN NULL    -- THEN '' (alternative null replacement)
        ELSE fi.DIM_WORKER_ID 
    END                                           AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    
    CASE 
        WHEN fi.DIM_DEPARTMENT_ID IS NOT NULL AND fi.DIM_DEPARTMENT_ID != -1 THEN fi.DIM_DEPARTMENT_ID
        ELSE CASE 
            -- replace system -1 values for when no worker associated [TESTING] #DtoI-1762
            WHEN fi.FACT_WORKER_HISTORY_DEPARTMENT_ID = -1 THEN NULL
            ELSE fi.FACT_WORKER_HISTORY_DEPARTMENT_ID 
        END 
    END                                           AS invo_professional_team, 
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
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799
    );

-- [TESTING] Table added
PRINT 'Table UPDATED: ' + @TableName;



/*
=============================================================================
Object Name: ssd_cla_care_plan NON-CORE UPDATE
Version: 0.1
Status: [DT]esting
Remarks: Back-filling ssd_cla_care_plan table with non-core SSD records. 
        This process appends ALL care plan records for further data testing
Dependencies:
- As ssd_cla_care_plan
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cla_care_plan-ADDITIONAL_TESTING_DATA';
PRINT 'Updating table: ' + @TableName;



-- Clear all data from the table
TRUNCATE TABLE ssd_development.ssd_cla_care_plan;


-- We can't be 100% if this pre-processing table was already dropped or not
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
               WHERE TABLE_SCHEMA = 'ssd_development' 
               AND TABLE_NAME = 'ssd_pre_cla_care_plan')
BEGIN
    CREATE TABLE ssd_development.ssd_pre_cla_care_plan (
        FACT_FORM_ID        NVARCHAR(48),
        DIM_PERSON_ID       NVARCHAR(48),
        ANSWER_NO           NVARCHAR(10),
        ANSWER              NVARCHAR(255),
        LatestResponseDate  DATETIME
    );
END
ELSE
BEGIN
    -- Clear all data from the table
    TRUNCATE TABLE ssd_development.ssd_pre_cla_care_plan;
    -- We drop this table later, after processing is complete 
END


WITH MostRecentQuestionResponse AS (
    SELECT  -- Return the most recent response for each question for each persons
        ff.DIM_PERSON_ID,
        ffa.ANSWER_NO,
        MAX(ffa.FACT_FORM_ID) AS MaxFormID
    FROM
        HDM.Child_Social.FACT_FORM_ANSWERS ffa
    JOIN
        HDM.Child_Social.FACT_FORMS ff ON ffa.FACT_FORM_ID = ff.FACT_FORM_ID    -- obtain the relevant person_id
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
        mrqr.MaxFormID      AS FACT_FORM_ID,
        ffa.ANSWER,
        ffa.ANSWERED_DTTM   AS LatestResponseDate
    FROM
        MostRecentQuestionResponse mrqr
    JOIN
        HDM.Child_Social.FACT_FORM_ANSWERS ffa ON mrqr.MaxFormID = ffa.FACT_FORM_ID AND mrqr.ANSWER_NO = ffa.ANSWER_NO
)
 
INSERT INTO ssd_development.ssd_pre_cla_care_plan (
    FACT_FORM_ID,
    DIM_PERSON_ID,
    ANSWER_NO,
    ANSWER,
    LatestResponseDate
)
SELECT
    lr.FACT_FORM_ID,
    lr.DIM_PERSON_ID,
    lr.ANSWER_NO,
    lr.ANSWER,
    lr.LatestResponseDate
FROM
    LatestResponses lr
ORDER BY lr.DIM_PERSON_ID DESC, lr.ANSWER_NO;



-- Insert data
INSERT INTO ssd_development.ssd_cla_care_plan (
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
            -- SSD standard 
            -- all keys in structure regardless of data presence ISNULL() not NULLIF()
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP1'  THEN tmp_cpl.ANSWER END, '')), NULL) AS REMAINSUP,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP2'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN1M,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP3'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURN6M,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP4'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RETURNEV,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP5'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTRELFR,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP6'  THEN tmp_cpl.ANSWER END, '')), NULL) AS LTFOST18,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP7'  THEN tmp_cpl.ANSWER END, '')), NULL) AS RESPLMT,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP8'  THEN tmp_cpl.ANSWER END, '')), NULL) AS SUPPLIV,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP9'  THEN tmp_cpl.ANSWER END, '')), NULL) AS ADOPTION,
            COALESCE(MAX(ISNULL(CASE WHEN tmp_cpl.ANSWER_NO = 'CPFUP10' THEN tmp_cpl.ANSWER END, '')), NULL) AS OTHERPLN
        FROM
            -- #ssd_TMP_PRE_cla_care_plan tmp_cpl
            ssd_development.ssd_pre_cla_care_plan tmp_cpl

        WHERE
            tmp_cpl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
 
        GROUP BY tmp_cpl.DIM_PERSON_ID
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    ) AS lacp_cla_care_plan_json
 
FROM
    HDM.Child_Social.FACT_CARE_PLANS AS fcp


WHERE fcp.DIM_LOOKUP_PLAN_STATUS_ID_CODE = 'A'
    AND EXISTS (
        SELECT 1
        FROM ssd_development.ssd_person p
        WHERE CAST(p.pers_person_id AS INT) = fcp.DIM_PERSON_ID -- #DtoI-1799
    );




-- clean up tmp/pre-processing table
DROP TABLE ssd_development.ssd_pre_cla_care_plan;
 


-- [TESTING] Table added
PRINT 'Table UPDATED: ' + @TableName;








/*
=============================================================================
Object Name: ssd_cp_plans NON-CORE UPDATE
Version: 0.1
Status: [DT]esting
Remarks: Back-filling ssd_cp_plans table with non-core SSD records. 
        This process appends ALL cp records for further data testing
Dependencies:
- As ssd_cp_plans
=============================================================================
*/
-- [TESTING] Create marker
SET @TableName = N'ssd_cp_plans-ADDITIONAL_TESTING_DATA';
PRINT 'Updating table: ' + @TableName;


-- Clear all data from the table
TRUNCATE TABLE ssd_development.ssd_cp_plans


-- RE-Insert data (now for larger unfiltered ssd_person cohort)
INSERT INTO ssd_development.ssd_cp_plans (
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
    CASE 
        WHEN cpp.FACT_REFERRAL_ID = -1 THEN NULL
        ELSE cpp.FACT_REFERRAL_ID
    END                                 AS cppl_referral_id,
    CASE 
        WHEN cpp.FACT_INITIAL_CP_CONFERENCE_ID = -1 THEN NULL
        ELSE cpp.FACT_INITIAL_CP_CONFERENCE_ID
    END                                 AS cppl_icpc_id,
    cpp.DIM_PERSON_ID                   AS cppl_person_id,
    cpp.START_DTTM                      AS cppl_cp_plan_start_date,
    cpp.END_DTTM                        AS cppl_cp_plan_end_date,
    cpp.IS_OLA                          AS cppl_cp_plan_ola,
    cpp.INIT_CATEGORY_DESC              AS cppl_cp_plan_initial_category,
    cpp.CP_CATEGORY_DESC                AS cppl_cp_plan_latest_category
 
FROM
    HDM.Child_Social.FACT_CP_PLAN cpp
 
WHERE
    (cpp.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR cpp.END_DTTM IS NULL)

AND EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_development.ssd_person p
    WHERE CAST(p.pers_person_id AS INT) = cpp.DIM_PERSON_ID -- #DtoI-1799
    );
