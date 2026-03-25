-- META-CONTAINER: {"type": "table", "name": "ssd_permanence"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - CLAADOPTIONSVIEW
-- - CLAPERIODOFCAREVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_permanence', 'U') IS NOT NULL DROP TABLE #ssd_permanence;

IF OBJECT_ID('ssd_permanence', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_permanence)
        TRUNCATE TABLE ssd_permanence;
END
ELSE
BEGIN
    CREATE TABLE ssd_permanence (
        perm_table_id                 NVARCHAR(48)  NOT NULL PRIMARY KEY, -- metadata={"item_ref":"PERM001A"}
        perm_person_id                NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"PERM002A"}
        perm_cla_id                   NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"PERM022A"}
        perm_adm_decision_date        DATETIME      NULL,                 -- metadata={"item_ref":"PERM003A"}
        perm_part_of_sibling_group    NCHAR(1)       NULL,                 -- metadata={"item_ref":"PERM012A"}
        perm_siblings_placed_together INT           NULL,                 -- metadata={"item_ref":"PERM013A"}
        perm_siblings_placed_apart    INT           NULL,                 -- metadata={"item_ref":"PERM014A"}
        perm_ffa_cp_decision_date     DATETIME      NULL,                 -- metadata={"item_ref":"PERM004A"}
        perm_placement_order_date     DATETIME      NULL,                 -- metadata={"item_ref":"PERM006A"}
        perm_matched_date             DATETIME      NULL,                 -- metadata={"item_ref":"PERM008A"}
        perm_adopter_sex              NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"PERM025A"}
        perm_adopter_legal_status     NVARCHAR(100) NULL,                 -- metadata={"item_ref":"PERM026A"}
        perm_number_of_adopters       INT           NULL,                 -- metadata={"item_ref":"PERM027A"}
        perm_placed_for_adoption_date DATETIME      NULL,                 -- metadata={"item_ref":"PERM007A"}
        perm_adopted_by_carer_flag    NCHAR(1)       NULL,                 -- metadata={"item_ref":"PERM021A"}
        perm_placed_foster_carer_date DATETIME      NULL,                 -- metadata={"item_ref":"PERM011A"}
        perm_placed_ffa_cp_date       DATETIME      NULL,                 -- metadata={"item_ref":"PERM009A"}
        perm_placement_provider_urn   NVARCHAR(48)  NULL,                 -- metadata={"item_ref":"PERM015A"}
        perm_decision_reversed_date   DATETIME      NULL,                 -- metadata={"item_ref":"PERM010A"}
        perm_decision_reversed_reason NVARCHAR(100) NULL,                 -- metadata={"item_ref":"PERM016A"}
        perm_permanence_order_date    DATETIME      NULL,                 -- metadata={"item_ref":"PERM017A"}
        perm_permanence_order_type    NVARCHAR(100) NULL,                 -- metadata={"item_ref":"PERM018A"}
        perm_adoption_worker_id       NVARCHAR(100) NULL                  -- metadata={"item_ref":"PERM023A"}
    );
END;

INSERT INTO ssd_permanence (
    perm_table_id,
    perm_person_id,
    perm_cla_id,
    perm_adm_decision_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_matched_date,
    perm_adopter_sex,
    perm_adopter_legal_status,
    perm_number_of_adopters,
    perm_placed_for_adoption_date,
    perm_adopted_by_carer_flag,
    perm_placed_foster_carer_date,
    perm_placed_ffa_cp_date,
    perm_placement_provider_urn,
    perm_decision_reversed_date,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adoption_worker_id
)
SELECT
    CONVERT(NVARCHAR(48), ADOP.ADOPTIONID)              AS perm_table_id,
    CONVERT(NVARCHAR(48), ADOP.PERSONID)                AS perm_person_id,
    CONVERT(NVARCHAR(48), CLA.PERIODOFCAREID)           AS perm_cla_id,

    NULL                                                AS perm_adm_decision_date,
    NULL                                                AS perm_part_of_sibling_group,
    NULL                                                AS perm_siblings_placed_together,
    NULL                                                AS perm_siblings_placed_apart,
    NULL                                                AS perm_ffa_cp_decision_date,
    NULL                                                AS perm_placement_order_date,
    NULL                                                AS perm_matched_date,

    CONVERT(NVARCHAR(48), ADOP.GENDEROFADOPTERSCODE)     AS perm_adopter_sex,
    CONVERT(NVARCHAR(100), ADOP.ADOPTERSLEGALSTATUSCODE) AS perm_adopter_legal_status,

    NULL                                                AS perm_number_of_adopters,
    NULL                                                AS perm_placed_for_adoption_date,
    NULL                                                AS perm_adopted_by_carer_flag,
    NULL                                                AS perm_placed_foster_carer_date,
    NULL                                                AS perm_placed_ffa_cp_date,
    NULL                                                AS perm_placement_provider_urn,
    NULL                                                AS perm_decision_reversed_date,

    CONVERT(NVARCHAR(100), ADOP.REASONNOLONGERPLANNEDCODE) AS perm_decision_reversed_reason,

    NULL                                                AS perm_permanence_order_date,
    NULL                                                AS perm_permanence_order_type,
    NULL                                                AS perm_adoption_worker_id
FROM CLAADOPTIONSVIEW ADOP
OUTER APPLY (
    SELECT TOP (1)
        CLA2.PERSONID,
        CLA2.PERIODOFCAREID,
        CLA2.ADMISSIONDATE,
        CLA2.DISCHARGEDATE
    FROM CLAPERIODOFCAREVIEW CLA2
    WHERE CLA2.PERSONID = ADOP.PERSONID
      AND CLA2.ADMISSIONDATE <= ADOP.DATESHOULDBEPLACED
    ORDER BY CLA2.ADMISSIONDATE DESC
) CLA
WHERE EXISTS (
    SELECT 1
    FROM ssd_person sp
    WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), ADOP.PERSONID)
);