IF OBJECT_ID(N'proc_ssd_involvements', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE proc_ssd_involvements AS BEGIN SET NOCOUNT ON; RETURN; END');
GO
CREATE OR ALTER PROCEDURE proc_ssd_involvements
    @src_db sysname = NULL,
    @src_schema sysname = NULL,
    @ssd_timeframe_years int = NULL,
    @ssd_sub1_range_years int = NULL,
    @today_date date = NULL,
    @today_dt datetime = NULL,
    @ssd_window_start date = NULL,
    @ssd_window_end date = NULL,
    @CaseloadLastSept30th date = NULL,
    @CaseloadTimeframeStartDate date = NULL

AS
BEGIN
    SET NOCOUNT ON;
    -- normalise defaults if not provided
    IF @src_db IS NULL SET @src_db = DB_NAME();
    IF @src_schema IS NULL SET @src_schema = SCHEMA_NAME();
    IF @ssd_timeframe_years IS NULL SET @ssd_timeframe_years = 6;
    IF @ssd_sub1_range_years IS NULL SET @ssd_sub1_range_years = 1;
    IF @today_date IS NULL SET @today_date = CONVERT(date, GETDATE());
    IF @today_dt   IS NULL SET @today_dt   = CONVERT(datetime, @today_date);
    IF @ssd_window_end   IS NULL SET @ssd_window_end   = @today_date;
    IF @ssd_window_start IS NULL SET @ssd_window_start = DATEADD(year, -@ssd_timeframe_years, @ssd_window_end);
    IF @CaseloadLastSept30th IS NULL SET @CaseloadLastSept30th = CASE
        WHEN @today_date > DATEFROMPARTS(YEAR(@today_date), 9, 30) THEN DATEFROMPARTS(YEAR(@today_date), 9, 30)
        ELSE DATEFROMPARTS(YEAR(@today_date) - 1, 9, 30) END;
    IF @CaseloadTimeframeStartDate IS NULL SET @CaseloadTimeframeStartDate = DATEADD(year, -@ssd_timeframe_years, @CaseloadLastSept30th);

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

IF OBJECT_ID('tempdb..#ssd_involvements', 'U') IS NOT NULL DROP TABLE #ssd_involvements;
 
IF OBJECT_ID('ssd_involvements','U') IS NOT NULL
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
        WHEN fi.DIM_WORKER_ID IN ('-1', -1) THEN NULL    -- THEN '' (alternative null replacement)
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
    --         WHEN fi.COMMENTS LIKE '%WORKER%' OR fi.COMMENTS LIKE '%ALLOC%' -- refer to comments for specific keywords
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
END
GO
