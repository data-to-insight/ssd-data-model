
-- META-CONTAINER: {"type": "table", "name": "ssd_vw_current_time_windows"}
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
--          This is an in Development inclusion for the SSD and as such is being phased in. 
--          Added here for both visibility and LA feedback, but not yet fully integrated.
--          VIEW currently commented as use of GO mid-single-script resets var declarations, 
--          and VIEW definitions required to be first running object. *LA's can run seperately as needed* 
--          The table set to replace declarations within: META-ELEMENT: {"type": "ssd_timeframe"}
-- Dependencies:
-- 
-- =============================================================================

-- CREATE OR ALTER VIEW ssd_development.ssd_vw_current_time_windows
-- AS
-- WITH x AS
-- (
--     SELECT CONVERT(date, GETDATE()) AS run_date
-- ),
-- p AS
-- (
--     /* Centralised params */
--     SELECT
--         CAST(24 AS int) AS ea_months_back,          -- Early Adopters
--         CAST(6  AS int) AS ssd_timeframe_years      -- SSD main
-- )
-- SELECT
--     x.run_date AS ssd_run_date,

--     /* SSD main timeframe (start and end exclusive) */
--     DATEADD(year, -p.ssd_timeframe_years, x.run_date) AS ssd_window_start,
--     DATEADD(day, 1, x.run_date) AS ssd_window_end,

--     /* EA window (24 months back, then FY start for that anchor date) */
--     p.ea_months_back AS ea_months_back,
--     DATEADD(month, -p.ea_months_back, x.run_date) AS ea_anchor_date,
--     ea.fiscal_year_start_date AS ea_window_start,
--     DATEADD(day, 1, x.run_date) AS ea_window_end,

--     /* Caseload anchor (last Sept 30 on or before run_date) */
--     p.ssd_timeframe_years AS ssd_timeframe_years,
--     caseload.last_sept30 AS sw_caseload_anchor,
--     DATEADD(year, -p.ssd_timeframe_years, caseload.last_sept30) AS sw_caseload_window_start
-- FROM x
-- CROSS JOIN p
-- JOIN ssd_development.ssd_dim_date ea
--   ON ea.full_date = DATEADD(month, -p.ea_months_back, x.run_date)
-- CROSS APPLY
-- (
--     SELECT MAX(d.full_date) AS last_sept30
--     FROM ssd_development.ssd_dim_date d
--     WHERE d.month_number = 9
--       AND d.day_of_month = 30
--       AND d.full_date <= x.run_date
-- ) caseload;


-- select * from ssd_development.ssd_vw_current_time_windows;

-- -- META-END