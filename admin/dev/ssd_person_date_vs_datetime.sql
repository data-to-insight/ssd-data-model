INSERT INTO ssd_development.ssd_person (
    pers_legacy_id,
    pers_person_id,
    pers_upn,
    pers_forename,
    pers_surname,
    pers_sex,       -- as used in stat-returns
    pers_gender,    -- Placeholder for those LAs that store sex and gender independently
    pers_ethnicity,
    pers_dob,
    pers_single_unique_id,                               
    pers_upn_unknown,                                  
    pers_send_flag,
    pers_expected_dob,
    pers_death_date,
    pers_is_mother,
    pers_nationality
)
SELECT 
    -- TOP 100                              -- Limit returned rows to speed up run-time tests [TESTING|LA DEBUG]
    p.LEGACY_ID,
    CAST(p.DIM_PERSON_ID AS NVARCHAR(48)),  -- Ensure DIM_PERSON_ID is cast to NVARCHAR(48)
    LEFT(LTRIM(RTRIM(p.UPN)), 13),           -- Coerce data to expected 13+strip, to avoid downstream fallover     
    p.FORENAME, 
    p.SURNAME,
    p.GENDER_MAIN_CODE AS pers_sex,         -- Sex/Gender as used in stat-returns
    p.GENDER_MAIN_CODE,                     -- Placeholder for those LAs that store sex and gender independently
    p.ETHNICITY_MAIN_CODE,                  -- [REVIEW] LEFT(p.ETHNICITY_MAIN_CODE, 4)

    CASE WHEN (p.DOB_ESTIMATED) = 'N'
        THEN dt.birth_date                  -- date parse, prefer UK dd/mm/yyyy (103), fallback ISO (23)
        ELSE NULL                           -- or NULL
    END,

    NULL AS pers_single_unique_id,           -- Set to NULL as default(dev) / or set to NHS num / or set to Single Unique Identifier(SUI)
    -- COALESCE(f903.NO_UPN_CODE, 'SSD_PH') AS NO_UPN_CODE, -- Use NO_UPN_CODE from f903 or 'SSD_PH' as placeholder
    f903.NO_UPN_CODE AS pers_upn_unknown, 
    p.EHM_SEN_FLAG,

    CASE WHEN (p.DOB_ESTIMATED) = 'Y'
        THEN dt.birth_date                  -- date parse, prefer UK dd/mm/yyyy (103), fallback ISO (23)
        ELSE NULL                           -- or NULL
    END,

    dt.death_date,                          -- date parse, prefer UK dd/mm/yyyy (103), fallback ISO (23)

    CASE
        WHEN p.GENDER_MAIN_CODE <> 'M' AND  -- Assumption that if male is not mother
             EXISTS (SELECT 1 FROM HDM.Child_Social.FACT_PERSON_RELATION fpr
                     WHERE fpr.DIM_PERSON_ID = p.DIM_PERSON_ID AND
                           fpr.DIM_LOOKUP_RELTN_TYPE_CODE = 'CHI') -- check for child relation only
        THEN 'Y'
        ELSE NULL                           -- No child relation found
    END,
    p.NATNL_CODE                            -- [REVIEW] LEFT(p.NATNL_CODE, 2)
FROM
    HDM.Child_Social.DIM_PERSON AS p

OUTER APPLY (
    SELECT
        birth_date =
            COALESCE(
                TRY_CONVERT(date, p.BIRTH_DTTM, 103),  -- UK dd/mm/yyyy
                TRY_CONVERT(date, p.BIRTH_DTTM, 23),   -- ISO yyyy-mm-dd
                TRY_CONVERT(date, p.BIRTH_DTTM)        -- final fallback if source is already datetime/date
            ),
        death_date =
            COALESCE(
                TRY_CONVERT(date, p.DEATH_DTTM, 103),  -- UK dd/mm/yyyy
                TRY_CONVERT(date, p.DEATH_DTTM, 23),   -- ISO yyyy-mm-dd
                TRY_CONVERT(date, p.DEATH_DTTM)        -- final fallback if source is already datetime/date
            )
) AS dt

-- [TESTING] 903 table refresh only in reporting period?
LEFT JOIN (
    -- ??other accessible location for NO_UPN data than 903 table?? -- [TESTING|LA DEBUG]
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

WHERE 
    /* EXCLUSIONS */

    -- p.DIM_PERSON_ID IN (1, 2, 3) AND --  -- hard filter on CMS person ids for LA reduced cohort testing

    p.DIM_PERSON_ID IS NOT NULL
    AND p.DIM_PERSON_ID <> -1
    -- AND YEAR(p.BIRTH_DTTM) != 1900 -- Remove admin records hard-filter -- #DtoI-1814 

    /* INCLUSIONS */
    AND (
        p.IS_CLIENT = 'Y'

        OR (
            -- Contacts in SSD window
            EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_CONTACTS fc
                WHERE fc.DIM_PERSON_ID = p.DIM_PERSON_ID
                  AND fc.CONTACT_DTTM >= @ssd_window_start  -- assumes *_DTTM are true datetime types, not text
                  -- Optional upper bound, if needing a closed window
                  -- AND fc.CONTACT_DTTM < DATEADD(day, 1, @ssd_window_end)
            )

            -- Referrals that touch the SSD window
            OR EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_REFERRALS fr
                WHERE fr.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND (
                       fr.REFRL_START_DTTM >= @ssd_window_start
                    OR fr.REFRL_END_DTTM   >= @ssd_window_start
                    OR fr.REFRL_END_DTTM IS NULL
                )
            )

            -- Care leaver in touch in SSD window
            OR EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_CLA_CARE_LEAVERS fccl
                WHERE fccl.DIM_PERSON_ID = p.DIM_PERSON_ID
                  AND fccl.IN_TOUCH_DTTM >= @ssd_window_start
                  -- Optional upper bound
                  -- AND fccl.IN_TOUCH_DTTM < DATEADD(day, 1, @ssd_window_end)
            )

            -- Eligibility flag 
            OR EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.DIM_CLA_ELIGIBILITY dce
                WHERE dce.DIM_PERSON_ID = p.DIM_PERSON_ID
                  AND dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
            )

            -- Involvements
            OR EXISTS (
                SELECT 1 
                FROM HDM.Child_Social.FACT_INVOLVEMENTS fi
                WHERE (fi.DIM_PERSON_ID = p.DIM_PERSON_ID
                AND (fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE 'KA%' --Key Agencies (External)
				     OR fi.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL 
                     OR fi.IS_ALLOCATED_CW_FLAG = 'Y')
				-- AND START_DTTM > '2009-12-04 00:54:49.947' -- #DtoI-1830 care leavers who were aged 22-25 and may not have had Allocated Case Worker relationship for years+
				AND DIM_WORKER_ID <> '-1' 
                
                AND (fi.END_DTTM IS NULL OR fi.END_DTTM > @ssd_window_start))
            )
        )
    );
