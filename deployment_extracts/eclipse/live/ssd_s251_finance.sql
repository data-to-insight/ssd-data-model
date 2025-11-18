-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_s251_finance;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_s251_finance (
    s251_table_id         VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"S251001A"}
    s251_cla_placement_id VARCHAR(48),              -- metadata={"item_ref":"S251002A"} 
    s251_placeholder_1    VARCHAR(48),              -- metadata={"item_ref":"S251003A"}
    s251_placeholder_2    VARCHAR(48),              -- metadata={"item_ref":"S251004A"}
    s251_placeholder_3    VARCHAR(48),              -- metadata={"item_ref":"S251005A"}
    s251_placeholder_4    VARCHAR(48)               -- metadata={"item_ref":"S251006A"}
);

TRUNCATE TABLE ssd_s251_finance;

INSERT INTO ssd_s251_finance (
    s251_table_id,
    s251_cla_placement_id,
    s251_placeholder_1,
    s251_placeholder_2,
    s251_placeholder_3,
    s251_placeholder_4
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development 
       Row identifier for the ssd_s251_finance table */
    NULL AS "s251_table_id",         --metadata={"item_ref:"S251001A"}
    /* currently PLACEHOLDER_DATA pending further development 
       ID for linking to CLA Placement */
    NULL AS "s251_cla_placement_id", --metadata={"item_ref:"S251002A"}
    /* currently PLACEHOLDER_DATA pending further development 
       No guidance available yet */
    NULL AS "s251_placeholder_1",    --metadata={"item_ref:"S251003A"}
    /* currently PLACEHOLDER_DATA pending further development 
       No guidance available yet */
    NULL AS "s251_placeholder_2",    --metadata={"item_ref:"S251004A"}
    /* currently PLACEHOLDER_DATA pending further development 
       No guidance available yet */
    NULL AS "s251_placeholder_3",    --metadata={"item_ref:"S251005A"}
    /* currently PLACEHOLDER_DATA pending further development 
       No guidance available yet */
    NULL AS "s251_placeholder_4";    --metadata={"item_ref:"S251006A"}
