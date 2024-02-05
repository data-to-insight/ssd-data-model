/* interogate Azeus DB */

-- Obtain available schemas in case tables cross schemas
SELECT DISTINCT OWNER
FROM ALL_OBJECTS
WHERE OWNER IS NOT NULL;


-- List of tables derived from the stat-returns Azeus spec supplied
DECLARE
    schema_name VARCHAR2(100) := 'YourSchema'; -- Replace 'YourSchema' with your schema name

-- List of table names
WITH TableNames AS (
SELECT 'ADOPTER_APP' AS TableName FROM DUAL
UNION ALL
SELECT 'PLCMT' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_COMM' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_DISAB' AS TableName FROM DUAL
UNION ALL
SELECT 'ADOPTER_APP_ACT' AS TableName FROM DUAL
UNION ALL
SELECT 'ADOPTER_REL' AS TableName FROM DUAL
UNION ALL
SELECT 'ASMT' AS TableName FROM DUAL
UNION ALL
SELECT 'CASE_ACT' AS TableName FROM DUAL
UNION ALL
SELECT 'CASE_RVW' AS TableName FROM DUAL
UNION ALL
SELECT 'CASE_EPISODE' AS TableName FROM DUAL
UNION ALL
SELECT 'CASEWORKER' AS TableName FROM DUAL
UNION ALL
SELECT 'CP_STATUS' AS TableName FROM DUAL
UNION ALL
SELECT 'EMP_ID' AS TableName FROM DUAL
UNION ALL
SELECT 'INIT_CONT' AS TableName FROM DUAL
UNION ALL
SELECT 'REFERRAL' AS TableName FROM DUAL
UNION ALL
SELECT 'KEYWORKER_HIST' AS TableName FROM DUAL
UNION ALL
SELECT 'MISSING_EP' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LA_STATUS' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LA_LGL_STATUS' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_PROV_ID' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_ADDR' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_PROV_ADDR' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_EDUC_NEED' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_ID' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_IMMIG_STATUS' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_IMMUNISATION_DT' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LAC_MED' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LC_ACCOMM' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LC_ACT' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LC_CAT' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_LC_CONT' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_OFFN' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_PLAN' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_REL' AS TableName FROM DUAL
UNION ALL
SELECT 'SVC_USR_SUBSTANCE_MISUSE' AS TableName FROM DUAL

)

-- retrieve column names for each table
SELECT tn.TableName, COLUMN_NAME
FROM TableNames tn
JOIN ALL_TAB_COLUMNS tc ON tn.TableName = tc.TABLE_NAME
WHERE tc.OWNER = schema_name
ORDER BY tn.TableName, COLUMN_ID;







/*
=============================================================================
Object Name: ssd_person
Description: person/child details
Author: D2I
Last Modified Date: 17/01/24 RH
DB Compatibility: Oracle |...
Version: 0.1
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]

Remarks:    
Dependencies: 
- 
=============================================================================
*/

-- Check if the specified columns exist in the SVC_USR table
SELECT
    CASE 
        WHEN COUNT(*) = 10 THEN 'All columns exist'
        ELSE 'Column not found: ' || 
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'SVC_USR_REF_NO') 
            THEN 'SVC_USR_REF_NO, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'CURRENT_GENDER') 
            THEN 'CURRENT_GENDER, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'ETHNIC_ORIGIN') 
            THEN 'ETHNIC_ORIGIN, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DOB_DAY') 
            THEN 'DOB_DAY, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DOB_MTH') 
            THEN 'DOB_MTH, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DOB_YR') 
            THEN 'DOB_YR, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'ID_NO') 
            THEN 'ID_NO, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DT_OF_DEATH_DAY') 
            THEN 'DT_OF_DEATH_DAY, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DT_OF_DEATH_MTH') 
            THEN 'DT_OF_DEATH_MTH, ' ELSE '' END ||
            CASE WHEN NOT EXISTS (SELECT 1 FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'SVC_USR' AND COLUMN_NAME = 'DT_OF_DEATH_YR') 
            THEN 'DT_OF_DEATH_YR, ' ELSE '' END
    END AS ColumnExistenceCheck
FROM DUAL;


-- CREATE GLOBAL TEMPORARY TABLE temp_table_name (
--     pers_person_id          NUMBER,
--     pers_sex                VARCHAR2(255),
--     pers_gender             VARCHAR2(255),
--     pers_ethnicity          VARCHAR2(255),
--     pers_dob                DATE,
--     pers_common_child_id    VARCHAR2(255),
--     pers_legacy_id          VARCHAR2(255),
--     pers_upn_unknown        NUMBER,
--     pers_send               VARCHAR2(255),
--     pers_expected_dob       DATE,
--     pers_death_date         DATE,
--     pers_is_mother          VARCHAR2(255),
--     pers_nationality        VARCHAR2(255)
-- );

-- INSERT INTO temp_table_name

SELECT
    usr.SVC_USR_REF_NO                  AS pers_person_id,
    PLACEHOLDER_DATA                    AS pers_sex,
    usr.CURRENT_GENDER                  AS pers_gender,
    usr.ETHNIC_ORIGIN                   AS pers_ethnicity,
    TO_DATE(usr.DOB_DAY || '/' || usr.DOB_MTH || '/' || usr.DOB_YR, 'DD/MM/YYYY') AS pers_dob,
    PLACEHOLDER_DATA                    AS pers_common_child_id,
    PLACEHOLDER_DATA                    AS pers_legacy_id,
    usr_id.ID_NO                        AS pers_upn_unknown,
    PLACEHOLDER_DATA                    AS pers_send,
    TO_DATE(usr.DOB_DAY || '/' || usr.DOB_MTH || '/' || usr.DOB_YR, 'DD/MM/YYYY') AS pers_expected_dob,
    TO_DATE(usr.DT_OF_DEATH_DAY || '/' || usr.DT_OF_DEATH_MTH || '/' || usr.DT_OF_DEATH_YR, 'DD/MM/YYYY') AS pers_death_date,
    --rel.unknown_field_name              AS pers_is_mother,
    PLACEHOLDER_DATA                    AS pers_nationality
FROM
    SVC_USR usr

-- LEFT JOIN
--     SVC_USR_REL rel ON usr.SVC_USR_REF_NO = rel.SVC_USR_REF_NO

LEFT JOIN
    SVC_USR_ID usr_id ON usr.SVC_USR_REF_NO = usr_id.SVC_USR_REF_NO;
