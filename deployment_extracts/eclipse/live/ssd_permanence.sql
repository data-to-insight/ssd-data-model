/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_permanence;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_permanence (
    perm_table_id                   VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"PERM001A"}
    perm_person_id                  VARCHAR(48),               -- metadata={"item_ref":"PERM002A"}
    perm_cla_id                     VARCHAR(48),               -- metadata={"item_ref":"PERM022A"}
    perm_adm_decision_date          TIMESTAMP,                 -- metadata={"item_ref":"PERM003A"}
    perm_part_of_sibling_group      CHAR(1),                   -- metadata={"item_ref":"PERM012A"}
    perm_siblings_placed_together   INTEGER,                   -- metadata={"item_ref":"PERM013A"}
    perm_siblings_placed_apart      INTEGER,                   -- metadata={"item_ref":"PERM014A"}
    perm_ffa_cp_decision_date       TIMESTAMP,                 -- metadata={"item_ref":"PERM004A"}
    perm_placement_order_date       TIMESTAMP,                 -- metadata={"item_ref":"PERM006A"}
    perm_matched_date               TIMESTAMP,                 -- metadata={"item_ref":"PERM008A"}
    perm_adopter_sex                VARCHAR(48),               -- metadata={"item_ref":"PERM025A"}
    perm_adopter_legal_status       VARCHAR(100),              -- metadata={"item_ref":"PERM026A"}
    perm_number_of_adopters         INTEGER,                   -- metadata={"item_ref":"PERM027A"}
    perm_placed_for_adoption_date   TIMESTAMP,                 -- metadata={"item_ref":"PERM007A"}
    perm_adopted_by_carer_flag      CHAR(1),                   -- metadata={"item_ref":"PERM021A"}
    perm_placed_foster_carer_date   TIMESTAMP,                 -- metadata={"item_ref":"PERM011A"}
    perm_placed_ffa_cp_date         TIMESTAMP,                 -- metadata={"item_ref":"PERM009A"}
    perm_placement_provider_urn     VARCHAR(48),               -- metadata={"item_ref":"PERM015A"}
    perm_decision_reversed_date     TIMESTAMP,                 -- metadata={"item_ref":"PERM010A"}
    perm_decision_reversed_reason   VARCHAR(100),              -- metadata={"item_ref":"PERM016A"}
    perm_permanence_order_date      TIMESTAMP,                 -- metadata={"item_ref":"PERM017A"}
    perm_permanence_order_type      VARCHAR(100),              -- metadata={"item_ref":"PERM018A"}
    perm_adoption_worker_id         VARCHAR(100)               -- metadata={"item_ref":"PERM023A"}
);

TRUNCATE TABLE ssd_permanence;

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
    ADOP.ADOPTIONID           AS perm_table_id,                 -- metadata={"item_ref":"PERM001A"}
    ADOP.PERSONID             AS perm_person_id,                -- metadata={"item_ref":"PERM002A"}
    CLA.PERIODOFCAREID        AS perm_cla_id,                   -- metadata={"item_ref":"PERM022A"}

    /* The date of the decision that the child should be placed for adoption
       Agency decision maker endorses the adoption plan */
    NULL                      AS perm_adm_decision_date,        -- metadata={"item_ref":"PERM003A"}

    /* Part of sibling group, 0 or 1 per SSDA903 code set */
    NULL                      AS perm_part_of_sibling_group,    -- metadata={"item_ref":"PERM012A"}

    /* Number placed or planned together including this child */
    NULL                      AS perm_siblings_placed_together, -- metadata={"item_ref":"PERM013A"}

    /* Number of siblings placed, or planned, apart from this child */
    NULL                      AS perm_siblings_placed_apart,    -- metadata={"item_ref":"PERM014A"}

    /* Date of decision for FFA or concurrent planning placement */
    NULL                      AS perm_ffa_cp_decision_date,     -- metadata={"item_ref":"PERM004A"}

    /* Date placement order or freeing order granted */
    NULL                      AS perm_placement_order_date,     -- metadata={"item_ref":"PERM006A"}

    /* Date matched to specific prospective adopters or carers */
    NULL                      AS perm_matched_date,             -- metadata={"item_ref":"PERM008A"}

    ADOP.GENDEROFADOPTERSCODE      AS perm_adopter_sex,         -- metadata={"item_ref":"PERM025A"}
    ADOP.ADOPTERSLEGALSTATUSCODE   AS perm_adopter_legal_status,-- metadata={"item_ref":"PERM026A"}

    /* Number of adopters or prospective adopters */
    NULL                      AS perm_number_of_adopters,       -- metadata={"item_ref":"PERM027A"}

    /* Date child placed for adoption with particular adopters
       or when foster placement becomes adoption placement */
    NULL                      AS perm_placed_for_adoption_date, -- metadata={"item_ref":"PERM007A"}

    /* Flag if child adopted by former carer, Y or N */
    NULL                      AS perm_adopted_by_carer_flag,    -- metadata={"item_ref":"PERM021A"}

    /* Date originally placed with foster carer(s) if adopted by them
       placeholder for future development */
    NULL                      AS perm_placed_foster_carer_date, -- metadata={"item_ref":"PERM011A"}

    /* Date child placed in FFA or CP placement */
    NULL                      AS perm_placed_ffa_cp_date,       -- metadata={"item_ref":"PERM009A"}

    /* URN of placement provider agency */
    NULL                      AS perm_placement_provider_urn,   -- metadata={"item_ref":"PERM015A"}

    /* Date local authority decides child should no longer be placed for adoption */
    NULL                      AS perm_decision_reversed_date,   -- metadata={"item_ref":"PERM010A"}

    ADOP.REASONNOLONGERPLANNEDCODE AS perm_decision_reversed_reason, -- metadata={"item_ref":"PERM016A"}

    /* Date permanence order granted, typically CLA placement end date */
    NULL                      AS perm_permanence_order_date,    -- metadata={"item_ref":"PERM017A"}

    /* Type of permanence order, for example Adoption, SGO, CAO or RO */
    NULL                      AS perm_permanence_order_type,    -- metadata={"item_ref":"PERM018A"}

    /* Adoption social worker identifier */
    NULL                      AS perm_adoption_worker_id        -- metadata={"item_ref":"PERM023A"}

FROM CLAADOPTIONSVIEW ADOP
LEFT JOIN LATERAL (
    SELECT
        PERSONID,
        PERIODOFCAREID,
        ADMISSIONDATE,
        DISCHARGEDATE
    FROM CLAPERIODOFCAREVIEW CLA
    WHERE CLA.PERSONID = ADOP.PERSONID
      AND CLA.ADMISSIONDATE <= ADOP.DATESHOULDBEPLACED
    ORDER BY CLA.ADMISSIONDATE DESC
    FETCH FIRST 1 ROW ONLY
) CLA ON TRUE;
