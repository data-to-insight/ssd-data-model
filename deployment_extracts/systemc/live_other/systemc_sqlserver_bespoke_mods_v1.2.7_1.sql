
/* Start

        Non-SDD Bespoke extract mods
        
        Examples of how to build on the ssd with bespoke additional fields. These can be 
        refreshed|incl. within the rebuild script and rebuilt at the same time as the SSD
        Changes should be limited to additional, non-destructive enhancements that do not
        alter the core structure of the SSD. 
        */




-- META-CONTAINER: {"type": "table", "name": "involvements_history"}
-- =============================================================================
-- ssd_non_core_modification
-- MOD Name: involvements history, involvements type history
-- Description: 
-- Author: D2I
-- Version: 0.2
--             0.1: involvement_history_json size change from 4000 to max fix trunc err 040724 RH
-- Status: [DT]ataTesting
-- Remarks: The addition of these MOD columns is overhead heavy. This is <especially> noticable 
--          on larger dimension versions of ssd_person (i.e. > 40k).
--          Recommend that this MOD is switched off during any test runs|peak-time extract runs
-- Dependencies: 
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- - ssd_person
-- =============================================================================

-- META-ELEMENT: {"type": "test"}
SET @TableName = N' Involvement History';
PRINT 'Adding MOD: ' + @TableName;

-- drop in case they already exist
-- ALTER TABLE ssd_person
-- DROP COLUMN pers_involvement_history_json, pers_involvement_type_story;
-- GO

ALTER TABLE ssd_development.ssd_person
ADD pers_involvement_history_json NVARCHAR(max),  -- Adjust data type as needed
    pers_involvement_type_story NVARCHAR(1000);   -- Adjust data type as needed

GO -- ensure new cols ALTER TABLE completed prior to onward processing
-- All variables now reset, will require redeclaring if testing below in isolation


-- version for SQL compatible versions 2016+
-- see below for #LEGACY-PRE2016
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
                ISNULL(fi2.FACT_INVOLVEMENTS_ID, '')              AS INVOLVEMENT_ID,
                ISNULL(fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '')  AS INVOLVEMENT_TYPE_CODE,
                ISNULL(fi2.START_DTTM, '')                        AS START_DATE,    -- or for yyyy-m-dd use -- ISNULL(CONVERT(VARCHAR(10), fi2.START_DTTM, 23), '') AS START_DATE,
                ISNULL(fi2.END_DTTM, '')                          AS END_DATE,      -- or for yyyy-m-dd use -- ISNULL(CONVERT(VARCHAR(10), fi2.END_DTTM, 23), '') AS END_DATE,
                ISNULL(fi2.DIM_WORKER_ID, '')                     AS WORKER_ID, 
                ISNULL(fi2.DIM_DEPARTMENT_ID, '')                 AS DEPARTMENT_ID
            FROM 
                HDM.Child_Social.FACT_INVOLVEMENTS fi2
            WHERE 
                fi2.DIM_PERSON_ID = fi.DIM_PERSON_ID

            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            -- rem WITHOUT_ARRAY_WRAPPER if restricting FULL contact history in _json (involvement_history_json)
        )) AS involvement_history
    FROM (

        -- commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
        SELECT *,
            -- ROW_NUMBER() OVER (
            --     PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
            --     ORDER BY FACT_INVOLVEMENTS_ID DESC
            -- ) AS rn,
            -- only applied if the following fi.rn = 1 is uncommented

            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE 
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
            -- AND END_DTTM IS NULL -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
            AND DIM_WORKER_ID IS NOT NULL       -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND DIM_WORKER_ID <> -1             -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
                                                -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
    ) fi

WHERE 
    -- -- Commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
    -- fi.rn = 1
    -- AND

    EXISTS (    -- Remove filter IF wishing to extract records beyond scope of SSD timeframe
        SELECT 1 FROM ssd_development.ssd_person p
         WHERE TRY_CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799

    )

    GROUP BY 
        fi.DIM_PERSON_ID
), -- end of block to replace if running pre-2016 sql versions (see below)
-- CTE for involvement type story
InvolvementTypeStoryCTE AS (
    SELECT 
        fi.DIM_PERSON_ID,
        STUFF((
            -- Concat involvement type codes into string
            -- cannot use STRING AGG as appears to not work (Needs v2017+)
            SELECT CONCAT(',', '"', fi3.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE, '"')
            FROM HDM.Child_Social.FACT_INVOLVEMENTS fi3
            WHERE fi3.DIM_PERSON_ID = fi.DIM_PERSON_ID

            AND EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
                SELECT 1 FROM ssd_development.ssd_person p
             WHERE TRY_CAST(p.pers_person_id AS INT) = fi3.DIM_PERSON_ID -- #DtoI-1799

            )

            ORDER BY fi3.FACT_INVOLVEMENTS_ID DESC
            FOR XML PATH('')
        ), 1, 1, '') AS InvolvementTypeStory
    FROM 
        HDM.Child_Social.FACT_INVOLVEMENTS fi
    
    WHERE 
        EXISTS (    -- Remove this filter IF wishing to extract records beyond scope of SSD timeframe
            SELECT 1 FROM ssd_development.ssd_person p
             WHERE TRY_CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799
             
        )
    GROUP BY 
        fi.DIM_PERSON_ID
)


-- Update
UPDATE p
SET
    p.pers_involvement_history_json = ih.involvement_history,
    p.pers_involvement_type_story = CONCAT('[', its.InvolvementTypeStory, ']')
FROM ssd_development.ssd_person p
LEFT JOIN InvolvementHistoryCTE ih ON TRY_CAST(p.pers_person_id AS INT) = ih.DIM_PERSON_ID -- #DtoI-1799
LEFT JOIN InvolvementTypeStoryCTE its ON TRY_CAST(p.pers_person_id AS INT) = its.DIM_PERSON_ID; -- #DtoI-1799

-- -- #LEGACY-PRE2016
-- -- version for SQL compatible versions <2016
-- -- CTE for involvement history incl. worker data
-- WITH RecursiveJSONCTE AS (
--     -- Anchor query: Start with the first row for each DIM_PERSON_ID
--     SELECT 
--         fi2.DIM_PERSON_ID,
--         '{' +
--         '"INVOLVEMENT_ID": "' + ISNULL(TRY_CAST(fi2.FACT_INVOLVEMENTS_ID AS NVARCHAR(50)), '') + '", ' +
--         '"INVOLVEMENT_TYPE_CODE": "' + ISNULL(TRY_CAST(fi2.DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS NVARCHAR(50)), '') + '", ' +
--         '"START_DATE": "' + ISNULL(CONVERT(VARCHAR(10), fi2.START_DTTM, 23), '') + '", ' + -- or for yyyy-m-dd use
--         '"END_DATE": "' + ISNULL(CONVERT(VARCHAR(10), fi2.END_DTTM, 23), '') + '", ' +     -- or for yyyy-m-dd use
--         '"WORKER_ID": "' + ISNULL(TRY_CAST(fi2.DIM_WORKER_ID AS NVARCHAR(50)), '') + '", ' +
--         '"DEPARTMENT_ID": "' + ISNULL(TRY_CAST(fi2.DIM_DEPARTMENT_ID AS NVARCHAR(50)), '') + '"' +
--         '}' AS JSONFragment,
--         ROW_NUMBER() OVER (PARTITION BY fi2.DIM_PERSON_ID ORDER BY fi2.FACT_INVOLVEMENTS_ID ASC) AS RowNum
--     FROM 
--         HDM.Child_Social.FACT_INVOLVEMENTS fi2
-- ),
-- RecursiveBuild AS (
--     -- Recursive step: Concatenate JSON fragments row by row
--     SELECT 
--         r.DIM_PERSON_ID,
--         '[' + r.JSONFragment AS JSONResult,
--         r.RowNum
--     FROM 
--         RecursiveJSONCTE r
--     WHERE 
--         r.RowNum = 1

--     UNION ALL

--     SELECT 
--         r.DIM_PERSON_ID,
--         rb.JSONResult + ', ' + r.JSONFragment AS JSONResult,
--         r.RowNum
--     FROM 
--         RecursiveBuild rb
--     JOIN 
--         RecursiveJSONCTE r
--         ON rb.DIM_PERSON_ID = r.DIM_PERSON_ID
--         AND rb.RowNum + 1 = r.RowNum
-- ),
-- FinalJSON AS (
--     -- Finalise the JSON array by closing the brackets
--     SELECT 
--         DIM_PERSON_ID,
--         JSONResult + ']' AS InvolvementHistory
--     FROM 
--         RecursiveBuild
--     WHERE 
--         RowNum = (SELECT MAX(RowNum) FROM RecursiveJSONCTE r WHERE r.DIM_PERSON_ID = RecursiveBuild.DIM_PERSON_ID)
-- ),
-- InvolvementHistoryCTE AS (
--     SELECT 
--         fi.DIM_PERSON_ID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.DIM_WORKER_ID END)                          AS CurrentWorkerID,
--         MAX(CASE WHEN fi.RecentInvolvement = 'CW' THEN fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC END)    AS AllocatedTeam,
--         MAX(CASE WHEN fi.RecentInvolvement = '16PLUS' THEN fi.DIM_WORKER_ID END)                      AS PersonalAdvisorID,
--         f.InvolvementHistory AS involvement_history
--     FROM (
--         -- commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
--         SELECT *,
--             -- ROW_NUMBER() OVER (
--             --     PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE 
--             --     ORDER BY FACT_INVOLVEMENTS_ID DESC
--             -- ) AS rn,
--             -- only applied if the following fi.rn = 1 is uncommented

--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
--         FROM HDM.Child_Social.FACT_INVOLVEMENTS
--         WHERE 
--             DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN ('CW', '16PLUS') 
--             -- AND END_DTTM IS NULL -- Switch on if certainty exists that we will always find a 'current' 'open' record for both types
--             AND DIM_WORKER_ID IS NOT NULL       -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND DIM_WORKER_ID <> -1             -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
--             AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> 'CW' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = 'CW' AND IS_ALLOCATED_CW_FLAG = 'Y'))
--                                                 -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
--     ) fi
--     LEFT JOIN 
--         FinalJSON f ON fi.DIM_PERSON_ID = f.DIM_PERSON_ID
--     WHERE 
--         -- -- Commented out to enable FULL contact history in _json (involvement_history_json). Re-enable if wanting only most recent/1
--         -- fi.rn = 1
--         -- AND

--         EXISTS (    -- Remove filter IF wishing to extract records beyond scope of SSD timeframe
--             SELECT 1 FROM ssd_development.ssd_person p
--             WHERE TRY_CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799
--         )
--     GROUP BY 
--         fi.DIM_PERSON_ID, f.InvolvementHistory
-- ),



-- META-END

