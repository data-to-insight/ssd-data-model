/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_previous_permanence;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_previous_permanence (
    lapp_table_id                      VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"LAPP001A"}
    lapp_person_id                     VARCHAR(48),               -- metadata={"item_ref":"LAPP002A"}
    lapp_previous_permanence_option    VARCHAR(200),              -- metadata={"item_ref":"LAPP003A"}
    lapp_previous_permanence_la        VARCHAR(100),              -- metadata={"item_ref":"LAPP004A"}
    lapp_previous_permanence_order_date VARCHAR(10)               -- metadata={"item_ref":"LAPP005A"}
);

TRUNCATE TABLE ssd_cla_previous_permanence;

INSERT INTO ssd_cla_previous_permanence (
    lapp_table_id,
    lapp_person_id,
    lapp_previous_permanence_option,
    lapp_previous_permanence_la,
    lapp_previous_permanence_order_date
)
SELECT
    /* Row identifier for the ssd_previous_permanence table */
    NULL AS lapp_table_id,                      -- metadata={"item_ref":"LAPP001A"}
    /* Person's ID generated in CMS Database */
    NULL AS lapp_person_id,                     -- metadata={"item_ref":"LAPP002A"}
    /* This should be completed for all children who start to be looked after.
       Information is collected for children who previously ceased to be looked after
       due to the granting of an adoption order, a special guardianship order,
       residence order (until 22 April 2014) or a child arrangement order. */
    NULL AS lapp_previous_permanence_option,    -- metadata={"item_ref":"LAPP003A"}
    /* The name of the local authority who arranged the previous permanence option. */
    NULL AS lapp_previous_permanence_la,        -- metadata={"item_ref":"LAPP004A"}
    /* Date of the previous permanence order, if known.
       Encoded per SSDA903 as zz/MM/YYYY or zz/zz/YYYY or zz/zz/zzzz when parts are unknown. */
    NULL AS lapp_previous_permanence_order_date -- metadata={"item_ref":"LAPP005A"};
