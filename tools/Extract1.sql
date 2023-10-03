/* Transact-SQL version */


-- ESCC 
USE HDM; -- Set DB name
GO

/ * person details */
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

    CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END as person_is_mother -- couldnt find relevant field

INTO Child_Social.person
FROM 
    Child_Social.DIM_PERSON AS p
LEFT JOIN
    Child_Social.FACT_CPIS_UPLOAD AS fc
ON 
    p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
ORDER BY
    p.[EXTERNAL_ID] ASC;



/ * person details */
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
    p.[IS_DISABLED] as person_disability,

    CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END as person_is_mother, -- couldnt find relevant field

    p.[IMMIGRATION_STATUS_DESC] as immigration_status


INTO Child_Social.person
FROM 
    Child_Social.DIM_PERSON AS p
LEFT JOIN
    Child_Social.FACT_CPIS_UPLOAD AS fc
ON 
    p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
ORDER BY
    p.[EXTERNAL_ID] ASC;

--WHERE
--    tbl.[START_DTTM] IS NULL OR tbl.[START_DTTM] >= DATEADD(YEAR, -6, GETDATE())




/* This version of the above but includes (most recent) legal_status */
WITH LatestLegalStatus AS (
    SELECT 
        fls.[DIM_PERSON_ID], 
        fls.[DIM_LOOKUP_LGL_STATUS_CODE]
    FROM
        (SELECT 
            [DIM_PERSON_ID], 
            [DIM_LOOKUP_LGL_STATUS_CODE], 
            [END_DTTM],
            ROW_NUMBER() OVER(PARTITION BY [DIM_PERSON_ID] ORDER BY [END_DTTM] DESC) as rn
         FROM Child_Social.FACT_LEGAL_STATUS) as fls
    WHERE 
        fls.rn = 1
)

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
    p.[IS_DISABLED] as person_disability,
    CASE WHEN fc.[DIM_PERSON_ID] IS NOT NULL THEN 'Y' ELSE 'N' END as person_is_mother,
    p.[IMMIGRATION_STATUS_DESC] as immigration_status,
    lls.[DIM_LOOKUP_LGL_STATUS_CODE] as legal_status_code -- fetched from the CTE

INTO Child_Social.person
FROM 
    Child_Social.DIM_PERSON AS p
LEFT JOIN
    Child_Social.FACT_CPIS_UPLOAD AS fc
ON 
    p.[EXTERNAL_ID] = fc.[EXTERNAL_ID]
LEFT JOIN 
    LatestLegalStatus AS lls
ON 
    p.[EXTERNAL_ID] = lls.[DIM_PERSON_ID]

ORDER BY
    p.[EXTERNAL_ID] ASC;
