-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_ehcp_active_plans;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_ehcp_active_plans (
    ehcp_active_ehcp_id               VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"EHCP001A"}
    ehcp_ehcp_request_id              VARCHAR(48),              -- metadata={"item_ref":"EHCP002A"}
    ehcp_active_ehcp_last_review_date TIMESTAMP                -- metadata={"item_ref":"EHCP003A"}
);

TRUNCATE TABLE ssd_ehcp_active_plans;

INSERT INTO ssd_ehcp_active_plans (
    ehcp_active_ehcp_id,
    ehcp_ehcp_request_id,
    ehcp_active_ehcp_last_review_date
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development
       EHCP active plan unique ID from system or auto generated as part of export. */
    NULL AS "ehcp_active_ehcp_id",               --metadata={"item_ref":"EHCP001A"}

    /* currently PLACEHOLDER_DATA pending further development
       EHCP request record unique ID from system or auto generated as part of export. */
    NULL AS "ehcp_ehcp_request_id",              --metadata={"item_ref":"EHCP002A"}

    /* currently PLACEHOLDER_DATA pending further development
       Please enter the date when the local authority wrote to the parent or young person with the notification of 
       the decision as to whether to retain, cease or amend the plan following the annual review meeting. Note that 
       this date will not be the same as the date of the review meeting. */
    NULL AS "ehcp_active_ehcp_last_review_date"; --metadata={"item_ref":"EHCP003A"}
