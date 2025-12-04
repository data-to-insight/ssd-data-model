IF OBJECT_ID(N'proc_ssd_cohort', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_cohort AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_cohort
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: Test deployment to avoid EXISTS hits on ssd_person + enable source checks 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: This is an in-dev table in order to better optimise the process of getting SSD cohort 
--          details into other related tables and help flag why they are included. 
--          Provides stable join pattern everywhere, shift from ssd_person
--          for WHERE EXISTS to reduce scan loads during ssd deployment. Provide 
--          flags for record(s) source visibility.   
-- Dependencies:

-- =============================================================================



-- -- Use-case: We''re rolling this out to (new)ssd tables 
-- INNER JOIN ssd_cohort co
--   ON co.dim_person_id = TRY_CONVERT(nvarchar(48), p.DIM_PERSON_ID)
-- -- WHERE co.has_contact = 1 -- e.g. filter on 

-- -- Sanity check (date threshold == today’s date(midnight) - SSDyrs )
-- SELECT DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE()))) AS current_cutoff_local;

SET NOCOUNT ON;

IF OBJECT_ID(''tempdb..#ssd_cohort'', ''U'') IS NOT NULL DROP TABLE #ssd_cohort;

-- IF OBJECT_ID(N''ssd_cohort'', N''U'') IS NOT NULL
-- DROP TABLE ssd_cohort;

IF OBJECT_ID(''ssd_cohort'', ''U'') IS NOT NULL
BEGIN
  IF EXISTS (SELECT 1 FROM ssd_cohort)
    TRUNCATE TABLE ssd_cohort;
END
ELSE

BEGIN
  CREATE TABLE ssd_cohort(
    dim_person_id         nvarchar(48)  NOT NULL PRIMARY KEY,
    legacy_id             nvarchar(48)  NULL,

    has_contact           bit           NOT NULL DEFAULT(0),
    has_referral          bit           NOT NULL DEFAULT(0),
    has_903               bit           NOT NULL DEFAULT(0),
    is_care_leaver        bit           NOT NULL DEFAULT(0),
    has_eligibility       bit           NOT NULL DEFAULT(0),
    has_client_flag       bit           NOT NULL DEFAULT(0),
    has_involvement       bit           NOT NULL DEFAULT(0),

    first_activity_dttm   datetime      NULL,   -- min of contact/referral dates
    last_activity_dttm    datetime      NULL    -- max of contact/referral dates
  );
END


/* Build 3-part prefix once */
DECLARE @dbq  nvarchar(260) = QUOTENAME(@src_db);
DECLARE @scq  nvarchar(260) = QUOTENAME(@src_schema);
DECLARE @src3 nvarchar(600) = @dbq + N''.'' + @scq + N''.'';

/* Template with placeholder for 3-part name: __SRC__ */
DECLARE @tpl nvarchar(max) = N''
;WITH contacts AS (
  SELECT
    TRY_CONVERT(nvarchar(48), c.DIM_PERSON_ID) AS dim_person_id,
    MAX(TRY_CONVERT(datetime, c.CONTACT_DTTM)) AS last_contact_dttm,
    MIN(TRY_CONVERT(datetime, c.CONTACT_DTTM)) AS first_contact_dttm
  FROM __SRC__FACT_CONTACTS AS c
  WHERE (@ssd_timeframe_years IS NULL
         OR c.CONTACT_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE()))))
    AND c.DIM_PERSON_ID <> -1
  GROUP BY c.DIM_PERSON_ID
),
a903 AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), f.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_903_DATA AS f
  WHERE f.DIM_PERSON_ID <> -1
),
clients AS (
  SELECT TRY_CONVERT(nvarchar(48), p.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__DIM_PERSON p
  WHERE p.DIM_PERSON_ID <> -1
    AND p.IS_CLIENT = ''''Y''''
),
refs AS (
  SELECT
    TRY_CONVERT(nvarchar(48), r.DIM_PERSON_ID) AS dim_person_id,
    MAX(TRY_CONVERT(datetime, r.REFRL_START_DTTM)) AS last_ref_dttm,
    MIN(TRY_CONVERT(datetime, r.REFRL_START_DTTM)) AS first_ref_dttm
  FROM __SRC__FACT_REFERRALS r
  WHERE r.DIM_PERSON_ID <> -1
    AND (
         r.REFRL_START_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
      OR r.REFRL_END_DTTM   >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
      OR r.REFRL_END_DTTM IS NULL
    )
  GROUP BY r.DIM_PERSON_ID
),
careleaver AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), cl.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_CLA_CARE_LEAVERS cl
  WHERE cl.DIM_PERSON_ID <> -1
    AND cl.IN_TOUCH_DTTM >= DATEADD(year, -@ssd_timeframe_years, CONVERT(datetime, CONVERT(date, GETDATE())))
),
elig AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), e.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__DIM_CLA_ELIGIBILITY e
  WHERE e.DIM_PERSON_ID <> -1
    AND e.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NOT NULL
),
involvements AS (
  SELECT DISTINCT TRY_CONVERT(nvarchar(48), i.DIM_PERSON_ID) AS dim_person_id
  FROM __SRC__FACT_INVOLVEMENTS i
  WHERE i.DIM_PERSON_ID <> -1
    AND (i.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE NOT LIKE ''''KA%'''' 
         OR i.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IS NOT NULL
         OR i.IS_ALLOCATED_CW_FLAG = ''''Y'''')
    AND i.DIM_WORKER_ID <> ''''-1''''
    AND (i.END_DTTM IS NULL OR i.END_DTTM > GETDATE())
),
unioned AS (
  SELECT dim_person_id, 1 AS has_contact, 0 AS has_referral, 0 AS has_903, 0 AS is_care_leaver, 0 AS has_eligibility, 1 AS has_client_flag, 0 AS has_involvement, first_contact_dttm AS first_dttm, last_contact_dttm AS last_dttm FROM contacts
  UNION ALL SELECT dim_person_id, 0,1,0,0,0,0,0, first_ref_dttm,  last_ref_dttm  FROM refs
  UNION ALL SELECT dim_person_id, 0,0,1,0,0,0,0, NULL,            NULL           FROM a903
  UNION ALL SELECT dim_person_id, 0,0,0,1,0,0,0, NULL,            NULL           FROM careleaver
  UNION ALL SELECT dim_person_id, 0,0,0,0,1,0,0, NULL,            NULL           FROM elig
  UNION ALL SELECT dim_person_id, 0,0,0,0,0,1,0, NULL,            NULL           FROM clients
  UNION ALL SELECT dim_person_id, 0,0,0,0,0,0,1, NULL,            NULL           FROM involvements
),
rollup AS (
  SELECT
    u.dim_person_id,
    CAST(MAX(CASE WHEN has_contact           = 1 THEN 1 ELSE 0 END) AS bit) AS has_contact,
    CAST(MAX(CASE WHEN has_referral          = 1 THEN 1 ELSE 0 END) AS bit) AS has_referral,
    CAST(MAX(CASE WHEN has_903               = 1 THEN 1 ELSE 0 END) AS bit) AS has_903,
    CAST(MAX(CASE WHEN is_care_leaver        = 1 THEN 1 ELSE 0 END) AS bit) AS is_care_leaver,
    CAST(MAX(CASE WHEN has_eligibility       = 1 THEN 1 ELSE 0 END) AS bit) AS has_eligibility,
    CAST(MAX(CASE WHEN has_client_flag       = 1 THEN 1 ELSE 0 END) AS bit) AS has_client_flag,
    CAST(MAX(CASE WHEN has_involvement       = 1 THEN 1 ELSE 0 END) AS bit) AS has_involvement,
    MIN(first_dttm) AS first_activity_dttm,
    MAX(last_dttm)  AS last_activity_dttm
  FROM unioned u
  GROUP BY u.dim_person_id
)
INSERT ssd_cohort(
  dim_person_id, legacy_id,
  has_contact, has_referral, has_903, is_care_leaver, has_eligibility,
  has_client_flag, has_involvement,            
  first_activity_dttm, last_activity_dttm
)
SELECT
  r.dim_person_id,
  MAX(dp.LEGACY_ID) AS legacy_id,
  r.has_contact, r.has_referral, r.has_903, r.is_care_leaver, r.has_eligibility,
  r.has_client_flag, r.has_involvement,        
  r.first_activity_dttm, r.last_activity_dttm
FROM rollup AS r
LEFT JOIN __SRC__DIM_PERSON AS dp
  ON dp.DIM_PERSON_ID = TRY_CONVERT(int, r.dim_person_id)
GROUP BY r.dim_person_id, r.has_contact, r.has_referral, r.has_903, r.is_care_leaver,
         r.has_eligibility, r.has_client_flag, r.has_involvement,  -- <<< keep in GROUP BY too
         r.first_activity_dttm, r.last_activity_dttm;
'';

/* Swap in 3-part prefix once */
DECLARE @sql nvarchar(max) = REPLACE(@tpl, N''__SRC__'', @src3);

-- Optional: inspect generated SQL around contacts CTE if needed
-- PRINT LEFT(@sql, 2000);


-- passing just scalar needed
EXEC sp_executesql
    @sql,
    N''@ssd_timeframe_years int'',
    @ssd_timeframe_years = @ssd_timeframe_years;

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE INDEX IX_ssd_cohort_has_referral ON ssd_cohort(dim_person_id) WHERE has_referral = 1;
-- CREATE INDEX IX_ssd_cohort_has_involvement ON ssd_cohort(dim_person_id) WHERE has_involvement = 1;




/* SSD summary 
Show breakdown of why/source of records included in ssd cohort */
SELECT
  COUNT(*) AS ssd_cohort_rows,
  SUM(CASE WHEN has_contact=1      THEN 1 ELSE 0 END) AS with_contacts,
  SUM(CASE WHEN has_referral=1     THEN 1 ELSE 0 END) AS with_referrals,
  SUM(CASE WHEN has_903=1          THEN 1 ELSE 0 END) AS in_903,
  SUM(CASE WHEN is_care_leaver=1   THEN 1 ELSE 0 END) AS care_leavers,
  SUM(CASE WHEN has_eligibility=1  THEN 1 ELSE 0 END) AS with_eligibility,
  SUM(CASE WHEN has_client_flag=1  THEN 1 ELSE 0 END) AS has_client_flag,
  SUM(CASE WHEN has_involvement=1  THEN 1 ELSE 0 END) AS with_involvement
FROM ssd_cohort;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
