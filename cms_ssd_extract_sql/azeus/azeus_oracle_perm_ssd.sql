


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
