-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_ehcp_named_plan;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_ehcp_named_plan (
    ehcn_named_plan_id            VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"EHCN001A"}
    ehcn_ehcp_asmt_id             VARCHAR(48),              -- metadata={"item_ref":"EHCN002A"}
    ehcn_named_plan_start_date    TIMESTAMP,                -- metadata={"item_ref":"EHCN003A"}
    ehcn_named_plan_ceased_date   TIMESTAMP,                -- metadata={"item_ref":"EHCN004A"}
    ehcn_named_plan_ceased_reason VARCHAR(100)              -- metadata={"item_ref":"EHCN005A"}
);

TRUNCATE TABLE ssd_ehcp_named_plan;

INSERT INTO ssd_ehcp_named_plan (
    ehcn_named_plan_id,
    ehcn_ehcp_asmt_id,
    ehcn_named_plan_start_date,
    ehcn_named_plan_ceased_date,
    ehcn_named_plan_ceased_reason
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development
       EHCP named plan unique ID from system or auto generated as part of export.
       This module collects information on the content of the EHC plan, that is what is in Section I. 
       It should be completed for all existing active EHC plans.
       It is possible that multiple plans may be recorded for a single person. For example, if an EHC plan has 
       previously ceased and a further plan has later been issued following a new needs assessment. Changes may 
       occur to this section from one year to the next for the same person, for example where an establishment 
       named on the EHC plan is changed. */
    NULL AS "ehcn_named_plan_id",            --metadata={"item_ref":"EHCN001A"}

    /* currently PLACEHOLDER_DATA pending further development
       EHCP assessment record unique ID from system or auto generated as part of export. */
    NULL AS "ehcn_ehcp_asmt_id",             --metadata={"item_ref":"EHCN002A"}

    /* currently PLACEHOLDER_DATA pending further development
       Date of current EHC plan. */
    NULL AS "ehcn_named_plan_start_date",    --metadata={"item_ref":"EHCN003A"}

    /* currently PLACEHOLDER_DATA pending further development
       Please provide the date the EHC plan ended or the date the EHC plan was transferred to another local authority.
       Do not record the date of the decision to cease. Local authorities must continue to maintain the EHC plan until 
       the time has passed for bringing an appeal or, when an appeal has been registered, until it has been concluded. */
    NULL AS "ehcn_named_plan_ceased_date",   --metadata={"item_ref":"EHCN004A"}

    /* currently PLACEHOLDER_DATA pending further development
       Please provide the reason the EHC plan ended from the list below
       1  Reached maximum age this is the end of the academic year during which the young person turned 25
       2  Ongoing educational or training needs being met without an EHC plan
       3  Moved on to higher education
       4  Moved on to paid employment, excluding apprenticeships
       5  Transferred to another LA
       6  Young person no longer wishes to engage in education or training
       7  Child or young person has moved outside England
       8  Child or young person deceased
       9  Other */
    NULL AS "ehcn_named_plan_ceased_reason"; --metadata={"item_ref":"EHCN005A"}
