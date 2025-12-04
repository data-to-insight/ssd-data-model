IF OBJECT_ID(N'proc_ssd_contacts', N'P') IS NULL
BEGIN
    EXEC(N'CREATE PROCEDURE proc_ssd_contacts AS BEGIN SET NOCOUNT ON; RETURN; END');
END;
EXEC(N'CREATE OR ALTER PROCEDURE proc_ssd_contacts
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
-- =============================================================================
-- Description: 
-- Author: D2I
-- Version: 1.0
-- Status: [D]ev-
-- Remarks:Inclusion in contacts might differ between LAs. 
--         Baseline definition:
--         Contains safeguarding and referral to early help data.
--         Requires #LEGACY-PRE2016 changes
-- Dependencies: 
-- - ssd_person
-- - HDM.Child_Social.FACT_CONTACTS
-- =============================================================================

IF OBJECT_ID(''tempdb..#ssd_contacts'', ''U'') IS NOT NULL DROP TABLE #ssd_contacts;

IF OBJECT_ID(''ssd_contacts'',''U'') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_contacts)
        TRUNCATE TABLE ssd_contacts;
END

ELSE
BEGIN
    CREATE TABLE ssd_contacts (
        cont_contact_id                 NVARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"CONT001A"}
        cont_person_id                  NVARCHAR(48),               -- metadata={"item_ref":"CONT002A"}
        cont_contact_date               DATETIME,                   -- metadata={"item_ref":"CONT003A"}
        cont_contact_source_code        NVARCHAR(48),               -- metadata={"item_ref":"CONT004A"} 
        cont_contact_source_desc        NVARCHAR(255),              -- metadata={"item_ref":"CONT006A"} 
        cont_contact_outcome_json       NVARCHAR(4000)              -- metadata={"item_ref":"CONT005A"}
    );
END

INSERT INTO ssd_contacts (
    cont_contact_id, 
    cont_person_id, 
    cont_contact_date,
    cont_contact_source_code,
    cont_contact_source_desc,
    cont_contact_outcome_json
)

-- #LEGACY-PRE2016
-- SQL compatible versions <2016
SELECT 
    fc.FACT_CONTACT_ID,
    fc.DIM_PERSON_ID, 
    fc.CONTACT_DTTM,
    fc.DIM_LOOKUP_CONT_SORC_ID,
    fc.DIM_LOOKUP_CONT_SORC_ID_DESC, --4
    (
        -- Manual JSON-like concatenation for cont_contact_outcome_json
        ''{'' +
        ''"NEW_REFERRAL_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_NEW_REFERRAL_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"EXISTING_REFERRAL_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_EXISTING_REFERRAL_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"CP_ENQUIRY_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_CP_ENQUIRY_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NFA_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_NFA_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NON_AGENCY_ADOPTION_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"PRIVATE_FOSTERING_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_PRIVATE_FOSTERING_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"ADVICE_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_ADVICE_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"MISSING_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_MISSING_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"OLA_CP_FLAG": "'' + ISNULL(TRY_CAST(fc.OUTCOME_OLA_CP_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"OTHER_OUTCOMES_EXIST_FLAG": "'' + ISNULL(TRY_CAST(fc.OTHER_OUTCOMES_EXIST_FLAG AS NVARCHAR(3)), '''') + ''", '' +
        ''"NUMBER_OF_OUTCOMES": '' + 
            ISNULL(TRY_CAST(CASE 
                WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL
                ELSE fc.TOTAL_NO_OF_OUTCOMES 
            END AS NVARCHAR(4)), ''null'') + '', '' +
        ''"COMMENTS": "'' + ISNULL(TRY_CAST(fc.OUTCOME_COMMENTS AS NVARCHAR(900)), '''') + ''"'' +
        ''}''
    ) AS cont_contact_outcome_json
FROM 
    HDM.Child_Social.FACT_CONTACTS AS fc
WHERE
    (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
    AND fc.DIM_PERSON_ID <> -1
    AND EXISTS ( -- only ssd relevant records
        SELECT 1
        FROM ssd_person p
        WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID
    );



-- -- #LEGACY-PRE2016
-- -- SQL compatible versions >=2016+
-- SELECT 
--     fc.FACT_CONTACT_ID,
--     fc.DIM_PERSON_ID, 
--     fc.CONTACT_DTTM,
--     fc.DIM_LOOKUP_CONT_SORC_ID,
--     fc.DIM_LOOKUP_CONT_SORC_ID_DESC, -- 3
--     (   -- Create JSON string for outcomes
--         SELECT 
--             -- SSD standard 
--             -- all keys in structure regardless of data presence
--             ISNULL(fc.OUTCOME_NEW_REFERRAL_FLAG, '''')         AS NEW_REFERRAL_FLAG,
--             ISNULL(fc.OUTCOME_EXISTING_REFERRAL_FLAG, '''')    AS EXISTING_REFERRAL_FLAG,
--             ISNULL(fc.OUTCOME_CP_ENQUIRY_FLAG, '''')           AS CP_ENQUIRY_FLAG,
--             ISNULL(fc.OUTCOME_NFA_FLAG, '''')                  AS NFA_FLAG,
--             ISNULL(fc.OUTCOME_NON_AGENCY_ADOPTION_FLAG, '''')  AS NON_AGENCY_ADOPTION_FLAG,
--             ISNULL(fc.OUTCOME_PRIVATE_FOSTERING_FLAG, '''')    AS PRIVATE_FOSTERING_FLAG,
--             ISNULL(fc.OUTCOME_ADVICE_FLAG, '''')               AS ADVICE_FLAG,
--             ISNULL(fc.OUTCOME_MISSING_FLAG, '''')              AS MISSING_FLAG,
--             ISNULL(fc.OUTCOME_OLA_CP_FLAG, '''')               AS OLA_CP_FLAG,
--             ISNULL(fc.OTHER_OUTCOMES_EXIST_FLAG, '''')         AS OTHER_OUTCOMES_EXIST_FLAG,
--             CASE 
--                 WHEN fc.TOTAL_NO_OF_OUTCOMES < 0 THEN NULL  -- to counter -1 values
--                 ELSE fc.TOTAL_NO_OF_OUTCOMES 
--             END                                              AS NUMBER_OF_OUTCOMES,
--             ISNULL(fc.OUTCOME_COMMENTS, '''')                  AS COMMENTS
--         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
--         ) AS cont_contact_outcome_json
-- FROM 
--     HDM.Child_Social.FACT_CONTACTS AS fc

-- WHERE
--     (fc.CONTACT_DTTM >= DATEADD(YEAR, -@ssd_timeframe_years, GETDATE())) -- #DtoI-1806
--     AND fc.DIM_PERSON_ID <> -1
--     AND EXISTS ( -- only ssd relevant records
--         SELECT 1
--         FROM ssd_person p
--         WHERE TRY_CAST(p.pers_person_id AS INT) = fc.DIM_PERSON_ID
--     );




-- -- META-ELEMENT: {"type": "create_fk"}
-- ALTER TABLE ssd_contacts ADD CONSTRAINT FK_ssd_contact_person 
-- FOREIGN KEY (cont_person_id) REFERENCES ssd_person(pers_person_id);

-- -- META-ELEMENT: {"type": "create_idx"}
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_person_id     ON ssd_contacts(cont_person_id);
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_date          ON ssd_contacts(cont_contact_date);
-- CREATE NONCLUSTERED INDEX IX_ssd_contact_source_code   ON ssd_contacts(cont_contact_source_code);

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrSev int = ERROR_SEVERITY();
        DECLARE @ErrState int = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END');
