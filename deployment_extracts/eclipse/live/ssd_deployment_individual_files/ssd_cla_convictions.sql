-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_cla_convictions;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_cla_convictions (
    clac_cla_conviction_id      VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAC001A"}
    clac_person_id              VARCHAR(48),               -- metadata={"item_ref":"CLAC002A"}
    clac_cla_conviction_date    TIMESTAMP,                 -- metadata={"item_ref":"CLAC003A"}
    clac_cla_conviction_offence VARCHAR(1000)              -- metadata={"item_ref":"CLAC004A"}
);

TRUNCATE TABLE ssd_cla_convictions;

INSERT INTO ssd_cla_convictions (
    clac_cla_conviction_id,
    clac_person_id,
    clac_cla_conviction_date,
    clac_cla_conviction_offence
)
SELECT
    /* Row identifier for the ssd_cla_convictions table */
    NULL::VARCHAR(48)   AS "clac_cla_conviction_id",      --metadata={"item_ref:"CLAC001A"}
    /* Person's ID generated in CMS Database */
    NULL::VARCHAR(48)   AS "clac_person_id",              --metadata={"item_ref:"CLAC002A"}
    /* Date of Offence */
    NULL::TIMESTAMP     AS "clac_cla_conviction_date",    --metadata={"item_ref:"CLAC003A"}
    /* Details of offence committed. */
    NULL::VARCHAR(1000) AS "clac_cla_conviction_offence"; --metadata={"item_ref:"CLAC004A"}

