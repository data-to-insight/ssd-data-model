IF OBJECT_ID(N'proc_ssd_involvements', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_involvements AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_involvements
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: [EA_API_PRIORITY_TABLE]

--             [TESTING] The below towards v1.0 for ref. only
--             Regarding the increased size/len on invo_professional_team
--             The (truncated)COMMENTS field is only used if:
--                 WORKER_HISTORY_DEPARTMENT_DESC is NULL.
--                 DEPARTMENT_NAME is NULL.
--                 GROUP_NAME is NULL.
--                 COMMENTS contains the keyword %WORKER% or %ALLOC%.
-- Dependencies:
-- - ssd_person
-- - ssd_departments (if obtaining team_name)
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_involvements'', ''U'') IS NOT NULL DROP TABLE #ssd_involvements;
 
IF OBJECT_ID(''ssd_involvements'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_involvements)
        TRUNCATE TABLE ssd_involvements;
END

ELSE
BEGIN
    CREATE TABLE ssd_involvements (
        invo_involvements_id        NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"INVO005A"}
        invo_professional_id        NVARCHAR(48),               -- metadata={"item_ref":"INVO006A"}
        invo_professional_role_id   NVARCHAR(200),              -- metadata={"item_ref":"INVO007A"}
        invo_professional_team      NVARCHAR(48),               -- metadata={"item_ref":"INVO009A", "info":"This is a truncated field at 255"}
        invo_person_id              NVARCHAR(48),               -- metadata={"item_ref":"INVO011A"}
        invo_involvement_start_date DATETIME,                   -- metadata={"item_ref":"INVO002A"}
        invo_involvement_end_date   DATETIME,                   -- metadata={"item_ref":"INVO003A"}
        invo_worker_change_reason   NVARCHAR(200),              -- metadata={"item_ref":"INVO004A"}
        invo_referral_id            NVARCHAR(48)                -- metadata={"item_ref":"INVO010A"}
    );
END

INSERT INTO ssd_involvements (
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
        WHEN fi.DIM_WORKER_ID IN (''-1'', -1) THEN NULL    -- THEN '''' (alternative null replacement)
        ELSE fi.DIM_WORKER_ID 
    END                                           AS invo_professional_id,
    fi.DIM_LOOKUP_INVOLVEMENT_TYPE_DESC           AS invo_professional_role_id,
    
    -- -- use first non-NULL value for prof team, in order of : i)dept, ii)grp, or iii)relevant comment
    -- LEFT(
    --     COALESCE(
    --     fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC,   -- prev/relevant dept name if available
    --     fi.DIM_DEPARTMENT_NAME,                   -- otherwise, use existing dept name
    --     fi.DIM_GROUP_NAME,                        -- then, use wider grp name if the above are NULL

    --     CASE -- if still NULL, refer into comments data but only when...
    --         WHEN fi.COMMENTS LIKE ''%WORKER%'' OR fi.COMMENTS LIKE ''%ALLOC%'' -- refer to comments for specific keywords
    --         THEN fi.COMMENTS 
    --     END -- if fi.COMMENTS is NULL, results in NULL
    -- ), 255)                                       AS invo_professional_team,
   
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
    HDM.Child_Social.FACT_INVOLVEMENTS AS fi

WHERE
    (fi.END_DTTM  >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE()) -- #DtoI-1806
    OR fi.END_DTTM  IS NULL)


AND EXISTS
    (
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = fi.DIM_PERSON_ID -- #DtoI-1799

    );



-- -- META-ELEMENT: {"type": "create_fk"} 


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_professional_id          ON ssd_involvements(invo_professional_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_person_id                ON ssd_involvements(invo_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_professional_role_id     ON ssd_involvements(invo_professional_role_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_involvement_start_date   ON ssd_involvements(invo_involvement_start_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_involvement_end_date     ON ssd_involvements(invo_involvement_end_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_invo_referral_id              ON ssd_involvements(invo_referral_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
