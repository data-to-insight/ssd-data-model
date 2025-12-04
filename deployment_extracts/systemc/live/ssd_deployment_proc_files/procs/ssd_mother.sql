IF OBJECT_ID(N'proc_ssd_mother', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_mother AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_mother
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: Contains parent-child relations between mother-child 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks: LAC/ CLA for stat return purposes but also useful to know any children who are parents 
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_PERSON_RELATION
-- - Gender codes are populated/stored as single char M|F|... 
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_mother'', ''U'') IS NOT NULL DROP TABLE #ssd_mother;

IF OBJECT_ID(''ssd_mother'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_mother)
        TRUNCATE TABLE ssd_mother;
END

ELSE
BEGIN
    CREATE TABLE ssd_mother (
        moth_table_id           NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
        moth_person_id          NVARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
        moth_childs_person_id   NVARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
        moth_childs_dob         DATETIME                    -- metadata={"item_ref":"MOTH003A"}
    );
END

INSERT INTO ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)
SELECT
    fpr.FACT_PERSON_RELATION_ID         AS moth_table_id,
    fpr.DIM_PERSON_ID                   AS moth_person_id,
    fpr.DIM_RELATED_PERSON_ID           AS moth_childs_person_id,
    fpr.DIM_RELATED_PERSON_DOB          AS moth_childs_dob
 
FROM
    HDM.Child_Social.FACT_PERSON_RELATION AS fpr
JOIN
    HDM.Child_Social.DIM_PERSON AS p ON fpr.DIM_PERSON_ID = p.DIM_PERSON_ID
WHERE
    p.GENDER_MAIN_CODE <> ''M'' 
    AND
    fpr.DIM_LOOKUP_RELTN_TYPE_CODE = ''CHI'' -- only interested in parent/child relations
    AND
    fpr.END_DTTM IS NULL
 
    AND (
        EXISTS ( -- only ssd relevant records
            SELECT 1
            FROM ssd_person p
            WHERE TRY_CAST(p.pers_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1799
        ) OR EXISTS ( 
            SELECT 1 
            FROM ssd_cin_episodes ce
            WHERE TRY_CAST(ce.cine_person_id AS INT) = fpr.DIM_PERSON_ID -- #DtoI-1806
        )
    );



-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_mother ADD CONSTRAINT FK_ssd_moth_to_person 
-- FOREIGN KEY (moth_person_id) REFERENCES ssd_person(pers_person_id);

-- -- [TESTING] deployment issues remain
-- ALTER TABLE ssd_mother ADD CONSTRAINT FK_ssd_child_to_person 
-- FOREIGN KEY (moth_childs_person_id) REFERENCES ssd_person(pers_person_id);

-- -- [TESTING] Comment this out until further notice (incl. for ESCC)
-- ALTER TABLE ssd_mother ADD CONSTRAINT CHK_ssd_no_self_parenting -- Ensure person cannot be their own mother
-- CHECK (moth_person_id <> moth_childs_person_id);


-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_moth_person_id ON ssd_mother(moth_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_childs_person_id ON ssd_mother(moth_childs_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_mother_childs_dob ON ssd_mother(moth_childs_dob);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
