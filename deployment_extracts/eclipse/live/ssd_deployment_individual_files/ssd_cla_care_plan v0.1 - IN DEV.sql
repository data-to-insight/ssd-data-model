
/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_care_plan;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_care_plan (
    lacp_table_id                  VARCHAR(48)   PRIMARY KEY,  -- metadata={"item_ref":"LACP001A"}
    lacp_person_id                 VARCHAR(48),                -- metadata={"item_ref":"LACP007A"}
    lacp_cla_care_plan_start_date  TIMESTAMP,                  -- metadata={"item_ref":"LACP004A"}
    lacp_cla_care_plan_end_date    TIMESTAMP,                  -- metadata={"item_ref":"LACP005A"}
    lacp_cla_care_plan_json        VARCHAR(1000)               -- metadata={"item_ref":"LACP003A"}
);

TRUNCATE TABLE ssd_cla_care_plan;

INSERT INTO ssd_cla_care_plan (
    lacp_table_id,
    lacp_person_id,
    lacp_cla_care_plan_start_date,
    lacp_cla_care_plan_end_date,
    lacp_cla_care_plan_json
)

SELECT
    /* Row identifier for the ssd_cla_care_plan table */
    NULL AS lacp_table_id,                  -- metadata={"item_ref":"LACP001A"}
    /* Person's ID generated in CMS Database */
    NULL AS lacp_person_id,                 -- metadata={"item_ref":"LACP007A"}
    /* Care plan start date */
    NULL::TIMESTAMP AS lacp_cla_care_plan_start_date,  -- metadata={"item_ref":"LACP004A"}
    /* Care plan end date */
    NULL::TIMESTAMP AS lacp_cla_care_plan_end_date,    -- metadata={"item_ref":"LACP005A"}
    /* Encoded care plan details payload */
    NULL AS lacp_cla_care_plan_json;        -- metadata={"item_ref":"LACP003A"}
