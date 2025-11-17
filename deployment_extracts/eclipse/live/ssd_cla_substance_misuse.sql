/* =============================================================================
   META-ELEMENT: {"type": "drop_table"}
   Note: uncomment only if dropping to apply new structural update(s)
   ============================================================================= */
-- DROP TABLE IF EXISTS ssd_cla_substance_misuse;

/* =============================================================================
   META-ELEMENT: {"type": "create_table"}
   ============================================================================= */
CREATE TABLE IF NOT EXISTS ssd_cla_substance_misuse (
    clas_substance_misuse_id   VARCHAR(48)  PRIMARY KEY,  -- metadata={"item_ref":"CLAS001A"}
    clas_person_id             VARCHAR(48),               -- metadata={"item_ref":"CLAS002A"}
    clas_substance_misuse_date TIMESTAMP,                 -- metadata={"item_ref":"CLAS003A"}
    clas_substance_misused     VARCHAR(100),              -- metadata={"item_ref":"CLAS004A"}
    clas_intervention_received CHAR(1)                    -- metadata={"item_ref":"CLAS005A"}
);

TRUNCATE TABLE ssd_cla_substance_misuse;

/* Placeholder rows only
   Currently there is no implemented mapping from source forms
   This insert seeds table with single NULL record to satisfy
   downstream expectations that the table is non-empty.
*/
INSERT INTO ssd_cla_substance_misuse (
    clas_substance_misuse_id,
    clas_person_id,
    clas_substance_misuse_date,
    clas_substance_misused,
    clas_intervention_received
)
SELECT
    NULL::VARCHAR(48)  AS clas_substance_misuse_id,   -- metadata={"item_ref":"CLAS001A"}
    NULL::VARCHAR(48)  AS clas_person_id,             -- metadata={"item_ref":"CLAS002A"}
    NULL::TIMESTAMP    AS clas_substance_misuse_date, -- metadata={"item_ref":"CLAS003A"}
    NULL::VARCHAR(100) AS clas_substance_misused,     -- metadata={"item_ref":"CLAS004A"}
    NULL::CHAR(1)      AS clas_intervention_received; -- metadata={"item_ref":"CLAS005A"}
