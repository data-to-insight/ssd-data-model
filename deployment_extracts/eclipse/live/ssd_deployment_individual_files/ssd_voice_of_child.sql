-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_voice_of_child;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_voice_of_child (
    voch_table_id              VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"VOCH007A"}
    voch_person_id             VARCHAR(48),              -- metadata={"item_ref":"VOCH001A"}
    voch_explained_worries     CHAR(1),                  -- metadata={"item_ref":"VOCH002A"}
    voch_story_help_understand CHAR(1),                  -- metadata={"item_ref":"VOCH003A"}
    voch_agree_worker          CHAR(1),                  -- metadata={"item_ref":"VOCH004A"}
    voch_plan_safe             CHAR(1),                  -- metadata={"item_ref":"VOCH005A"}
    voch_tablet_help_explain   CHAR(1)                   -- metadata={"item_ref":"VOCH006A"}
);

TRUNCATE TABLE ssd_voice_of_child;

INSERT INTO ssd_voice_of_child (
    voch_table_id,
    voch_person_id,
    voch_explained_worries,
    voch_story_help_understand,
    voch_agree_worker,
    voch_plan_safe,
    voch_tablet_help_explain
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development 
       Row identifier for the ssd_voice_of_child table */
    NULL AS "voch_table_id",              --metadata={"item_ref:"VOCH007A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Person's ID generated in CMS Database  */
    NULL AS "voch_person_id",             --metadata={"item_ref:"VOCH001A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Child answer from questionnaire  */
    NULL AS "voch_explained_worries",     --metadata={"item_ref:"VOCH002A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Child answer from questionnaire  */
    NULL AS "voch_story_help_understand", --metadata={"item_ref:"VOCH003A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Child answer from questionnaire  */
    NULL AS "voch_agree_worker",          --metadata={"item_ref:"VOCH004A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Child answer from questionnaire  */
    NULL AS "voch_plan_safe",             --metadata={"item_ref:"VOCH005A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Child answer from questionnaire  */
    NULL AS "voch_tablet_help_explain";   --metadata={"item_ref:"VOCH006A"}
