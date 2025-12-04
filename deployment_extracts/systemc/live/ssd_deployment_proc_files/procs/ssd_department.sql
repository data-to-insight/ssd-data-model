IF OBJECT_ID(N'proc_ssd_department', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_department AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_department
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: 
-- Dependencies: 
-- - HDM.Child_Social.DIM_DEPARTMENT
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_department'', ''U'') IS NOT NULL DROP TABLE #ssd_department;

IF OBJECT_ID(''ssd_department'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_department)
        TRUNCATE TABLE ssd_department;
END

ELSE
BEGIN
    CREATE TABLE ssd_department (
        dept_team_id           NVARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"DEPT1001A"}
        dept_team_name         NVARCHAR(255), -- metadata={"item_ref":"DEPT1002A"}
        dept_team_parent_id    NVARCHAR(48),  -- metadata={"item_ref":"DEPT1003A", "info":"references ssd_department.dept_team_id"}
        dept_team_parent_name  NVARCHAR(255)  -- metadata={"item_ref":"DEPT1004A"}
    );
END

INSERT INTO ssd_department (
    dept_team_id,
    dept_team_name,
    dept_team_parent_id,
    dept_team_parent_name
)
SELECT 
    dpt.DIM_DEPARTMENT_ID       AS dept_team_id,
    dpt.NAME                    AS dept_team_name,
    dpt.DEPT_ID                 AS dept_team_parent_id,
    dpt.DEPT_TYPE_DESCRIPTION   AS dept_team_parent_name

FROM HDM.Child_Social.DIM_DEPARTMENT dpt

WHERE dpt.dim_department_id <> -1;

-- Dev note: 
-- Can/should  dept data be reduced by matching back to objects to ensure only in-use dept data is retrieved



-- -- META-ELEMENT: {"type": "create_fk"} 
-- ALTER TABLE ssd_department ADD CONSTRAINT FK_ssd_dept_team_parent_id 
-- FOREIGN KEY (dept_team_parent_id) REFERENCES ssd_department(dept_team_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE INDEX IX_ssd_dept_team_id ON ssd_department (dept_team_id);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
