IF OBJECT_ID(N'proc_ssd_care_leavers', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_care_leavers AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_care_leavers
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description:
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks:    Dev: Note that <multiple> refs to ssd_person need changing when porting code to tempdb.. versions.
--             Dev: Ensure index on ssd_person.pers_person_id is intact to ensure performance on <FROM ssd_person> references in the CTEs(added for performance)
--             Dev: Revised V3/4 to aid performance on large involvements table aggr

--             This table the cohort of children who are preparing to leave care, typically 15/16/17yrs+; 
--             Not those who are finishing a period of care. 
--             clea_care_leaver_eligibility == LAC for 13wks+(since 14yrs)+LAC since 16yrs 

-- Dependencies:
-- - ssd_person
-- - HDM.Child_Social.FACT_INVOLVEMENTS
-- - HDM.Child_Social.FACT_CLA_CARE_LEAVERS
-- - HDM.Child_Social.DIM_CLA_ELIGIBILITY
-- - HDM.Child_Social.FACT_CARE_PLANS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_care_leavers'', ''U'') IS NOT NULL DROP TABLE #ssd_care_leavers;
 
IF OBJECT_ID(''ssd_care_leavers'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_care_leavers)
        TRUNCATE TABLE ssd_care_leavers;
END

ELSE
BEGIN
    CREATE TABLE ssd_care_leavers
    (
        clea_table_id                           NVARCHAR(48) PRIMARY KEY,               -- metadata={"item_ref":"CLEA001A"}
        clea_person_id                          NVARCHAR(48),               -- metadata={"item_ref":"CLEA002A"}
        clea_care_leaver_eligibility            NVARCHAR(100),              -- metadata={"item_ref":"CLEA003A", "info":"LAC for 13wks(since 14yrs)+LAC since 16yrs"}
        clea_care_leaver_in_touch               NVARCHAR(100),              -- metadata={"item_ref":"CLEA004A"}
        clea_care_leaver_latest_contact         DATETIME,                   -- metadata={"item_ref":"CLEA005A"}
        clea_care_leaver_accommodation          NVARCHAR(100),              -- metadata={"item_ref":"CLEA006A"}
        clea_care_leaver_accom_suitable         NVARCHAR(100),              -- metadata={"item_ref":"CLEA007A"}
        clea_care_leaver_activity               NVARCHAR(100),              -- metadata={"item_ref":"CLEA008A"}
        clea_pathway_plan_review_date           DATETIME,                   -- metadata={"item_ref":"CLEA009A"}
        clea_care_leaver_personal_advisor       NVARCHAR(100),              -- metadata={"item_ref":"CLEA010A"}
        clea_care_leaver_allocated_team         NVARCHAR(48),              -- metadata={"item_ref":"CLEA011A"}
        clea_care_leaver_worker_id              NVARCHAR(100)               -- metadata={"item_ref":"CLEA012A"}
    );
END

-- CTE for involvement history incl. worker data
-- aggregate/extract current worker infos, allocated team, and p.advisor ID
;WITH InvolvementHistoryCTE AS (
    SELECT
        fi.DIM_PERSON_ID,
        -- worker, alloc team, and p.advisor dets <<per involvement type>>
        MAX(CASE WHEN fi.RecentInvolvement = ''CW'' THEN NULLIF(fi.DIM_WORKER_ID, 0) ELSE NULL END)   AS CurrentWorker,       -- c.w name for the ''CW'' inv type
        MAX(CASE WHEN fi.RecentInvolvement = ''CW'' THEN NULLIF(NULLIF(fi.FACT_WORKER_HISTORY_DEPARTMENT_ID, -1), 0) ELSE NULL END) AS AllocatedTeam, -- team desc for the ''CW'' inv type
        MAX(CASE WHEN fi.RecentInvolvement = ''16PLUS'' THEN fi.DIM_WORKER_ID ELSE NULL END)          AS PersonalAdvisor      -- p.a. for the ''16PLUS'' inv type
        -- was fi.FACT_WORKER_HISTORY_DEPARTMENT_DESC & fi.FACT_WORKER_NAME. fi.DIM_DEPARTMENT_ID also available
    
    FROM (
        SELECT *,
            -- Assign a row number, partition by p + inv type
            ROW_NUMBER() OVER (
                PARTITION BY DIM_PERSON_ID, DIM_LOOKUP_INVOLVEMENT_TYPE_CODE
                ORDER BY FACT_INVOLVEMENTS_ID DESC
            ) AS rn,
            -- Mark the involvement type (''CW'' or ''16PLUS'')
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE AS RecentInvolvement
        FROM HDM.Child_Social.FACT_INVOLVEMENTS
        WHERE
            -- Filter records to just ''CW'' and ''16PLUS'' inv types
            DIM_LOOKUP_INVOLVEMENT_TYPE_CODE IN (''CW'', ''16PLUS'')
                                                    -- Switched off in v1.6 [TESTING]
            -- AND END_DTTM IS NULL                 -- Switch on if certainty exists that we will always find a ''current'' ''open'' record for both types
            -- AND DIM_WORKER_ID IS NOT NULL        -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
            AND DIM_WORKER_ID <> -1                 -- Suggests missing data|other non-caseworker record / cannot be associated CW or +16 CW
 
            -- where the inv type is ''CW'' + flagged as allocated
            AND (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE <> ''CW'' OR (DIM_LOOKUP_INVOLVEMENT_TYPE_CODE = ''CW'' AND IS_ALLOCATED_CW_FLAG = ''Y''))
                                                    -- Leaving only involvement records <with> worker data that are CW+Allocated and/or 16PLUS
    ) fi
 
    -- aggregate the result(s)
    GROUP BY
        fi.DIM_PERSON_ID
)
 
INSERT INTO ssd_care_leavers
(
    clea_table_id,
    clea_person_id,
    clea_care_leaver_eligibility,
    clea_care_leaver_in_touch,
    clea_care_leaver_latest_contact,
    clea_care_leaver_accommodation,
    clea_care_leaver_accom_suitable,
    clea_care_leaver_activity,
    clea_pathway_plan_review_date,
    clea_care_leaver_personal_advisor,                  
    clea_care_leaver_allocated_team,
    clea_care_leaver_worker_id            
)
 
SELECT
    NEWID() AS clea_table_id, -- [TESTING] #DtoI-1821 CONCAT(dce.DIM_CLA_ELIGIBILITY_ID, fccl.FACT_CLA_CARE_LEAVERS_ID) AS clea_table_id,
    dce.DIM_PERSON_ID                                       AS clea_person_id,
    CASE WHEN
        dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC IS NULL
        THEN ''No Current Eligibility''
        ELSE dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC END     AS clea_care_leaver_eligibility,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE                      AS clea_care_leaver_in_touch,
    fccl.IN_TOUCH_DTTM                                      AS clea_care_leaver_latest_contact,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC                 AS clea_care_leaver_accommodation,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC             AS clea_care_leaver_accom_suitable,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC                      AS clea_care_leaver_activity,
 
    -- MAX(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID
    --     AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = ''PATH''
    --     THEN fcp.MODIF_DTTM END)                            AS clea_pathway_plan_review_date,

 MAX(ISNULL(CASE WHEN fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID 
    AND fcp.DIM_LOOKUP_PLAN_TYPE_ID_CODE = ''PATH'' 
    THEN fcp.MODIF_DTTM END, ''1900-01-01''))                 AS clea_pathway_plan_review_date,

    ih.PersonalAdvisor                                      AS clea_care_leaver_personal_advisor,
    ih.AllocatedTeam                                        AS clea_care_leaver_allocated_team,
    ih.CurrentWorker                                        AS clea_care_leaver_worker_id
 
FROM
    HDM.Child_Social.DIM_CLA_ELIGIBILITY AS dce
 
LEFT JOIN HDM.Child_Social.FACT_CLA_CARE_LEAVERS AS fccl ON dce.DIM_PERSON_ID = fccl.DIM_PERSON_ID    -- towards clea_care_leaver_in_touch, _latest_contact, _accommodation, _accom_suitable and _activity
 
LEFT JOIN HDM.Child_Social.FACT_CARE_PLANS AS fcp ON fccl.DIM_PERSON_ID = fcp.DIM_PERSON_ID           -- towards clea_pathway_plan_review_date
               
LEFT JOIN HDM.Child_Social.DIM_PERSON p ON dce.DIM_PERSON_ID = p.DIM_PERSON_ID                        -- towards LEGACY_ID for testing only
 
LEFT JOIN InvolvementHistoryCTE AS ih ON dce.DIM_PERSON_ID = ih.DIM_PERSON_ID                     -- connect with CTE aggr data      
 
WHERE EXISTS ( -- only ssd relevant records
    SELECT 1
    FROM ssd_person p
    WHERE TRY_CAST(p.pers_person_id AS INT) = dce.DIM_PERSON_ID -- #DtoI-1799
    )
 
GROUP BY
    dce.DIM_CLA_ELIGIBILITY_ID,
    fccl.FACT_CLA_CARE_LEAVERS_ID,
    p.LEGACY_ID,  
    dce.DIM_PERSON_ID,
    dce.DIM_LOOKUP_ELIGIBILITY_STATUS_DESC,
    fccl.DIM_LOOKUP_IN_TOUCH_CODE_CODE,
    fccl.IN_TOUCH_DTTM,
    fccl.DIM_LOOKUP_ACCOMMODATION_CODE_DESC,
    fccl.DIM_LOOKUP_ACCOMMODATION_SUITABLE_DESC,
    fccl.DIM_LOOKUP_MAIN_ACTIVITY_DESC,
    ih.PersonalAdvisor,
    ih.CurrentWorker,
    ih.AllocatedTeam          
    ;




-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_care_leavers ADD CONSTRAINT FK_ssd_care_leavers_person
-- FOREIGN KEY (clea_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_person_id                    ON ssd_care_leavers(clea_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_care_leaver_latest_contact   ON ssd_care_leavers(clea_care_leaver_latest_contact);
-- CREATE NONCLUSTERED INDEX IX_ssd_clea_pathway_plan_review_date     ON ssd_care_leavers(clea_pathway_plan_review_date);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
