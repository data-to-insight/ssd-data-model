-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_send;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_send (
    send_table_id   VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"SEND001A"}
    send_person_id  VARCHAR(48),             -- metadata={"item_ref":"SEND005A"}
    send_upn        VARCHAR(48),             -- metadata={"item_ref":"SEND002A"}
    send_uln        VARCHAR(48),             -- metadata={"item_ref":"SEND003A"}
    send_upn_unknown VARCHAR(6)              -- metadata={"item_ref":"SEND004A"}
);

TRUNCATE TABLE ssd_send;

INSERT INTO ssd_send (
    send_table_id,
    send_person_id,
    send_upn,
    send_uln,
    send_upn_unknown
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development 
       Row identifier for the ssd_send table */
    NULL AS "send_table_id",      --metadata={"item_ref:"SEND001A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Person's ID generated in CMS Database */
    NULL AS "send_person_id",     --metadata={"item_ref:"SEND005A"}
    /* currently PLACEHOLDER_DATA pending further development 
       The Child's Unique Pupil Number */
    NULL AS "send_upn",           --metadata={"item_ref:"SEND002A"}
    /* currently PLACEHOLDER_DATA pending further development 
       The young person’s unique learner number (ULN) as used in the Individualised Learner Record. */
    NULL AS "send_uln",           --metadata={"item_ref:"SEND003A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Where no identifier is available, please record one of the following options:
       -UN1   Child is aged under 6 years old and is not yet assigned a UPN
       -UN2   Child has never attended a state-funded school in England and has not been assigned a UPN
       -UN3   Child is educated outside of England and has not been assigned a UPN
       -UN5   Sources collating UPNs reflect discrepancy/ies for the child’s name and/or surname and/or date of birth therefore prevent reliable matching (for example duplicated UPN)
       -UN8   Person is new to LA and the UPN or ULN is not yet known
       -UN9   Young person has never attended a state-funded school or further education setting in England and has not been assigned a UPN or ULN
       -UN10  Request for assessment resulted in no further action before UPN or ULN known */
    NULL AS "send_upn_unknown";   --metadata={"item_ref:"SEND004A"}
