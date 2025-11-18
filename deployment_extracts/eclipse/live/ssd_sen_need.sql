-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_sen_need;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_sen_need (
    senn_table_id              VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"SENN001A"}
    senn_active_ehcp_id        VARCHAR(48),             -- metadata={"item_ref":"SENN002A"}
    senn_active_ehcp_need_type VARCHAR(100),            -- metadata={"item_ref":"SENN003A"}
    senn_active_ehcp_need_rank CHAR(1)                  -- metadata={"item_ref":"SENN004A"}
);

TRUNCATE TABLE ssd_sen_need;

INSERT INTO ssd_sen_need (
    senn_table_id,
    senn_active_ehcp_id,
    senn_active_ehcp_need_type,
    senn_active_ehcp_need_rank
)
SELECT
    /* currently PLACEHOLDER_DATA pending further development 
       SEN need record unique ID from system or auto generated as part of export. */
    NULL AS "senn_table_id",              --metadata={"item_ref":"SENN001A"}
    /* currently PLACEHOLDER_DATA pending further development 
       EHCP active plan unique ID from system or auto generated as part of export. */
    NULL AS "senn_active_ehcp_id",        --metadata={"item_ref":"SENN002A"}
    /* currently PLACEHOLDER_DATA pending further development 
       Please record the nature of the person’s special educational need. These options are consistent with those collected within the spring term school census. Where multiple types of need are recorded and ranked, the primary type of need should be ranked 1 under Type of need rank, and if applicable a secondary type of need should be ranked 2. 
       SPLD  Specific learning difficulty 
       MLD   Moderate learning difficulty 
       SLD   Severe learning difficulty 
       PMLD  Profound and multiple learning difficulty 
       SEMH  Social, emotional and mental health 
       SLCN  Speech, language and communication needs 
       HI    Hearing impairment 
       VI    Vision impairment 
       MSI   Multi sensory impairment 
       PD    Physical disability 
       ASD   Autistic spectrum disorder 
       OTH   Other difficulty */
    NULL AS "senn_active_ehcp_need_type", --metadata={"item_ref":"SENN003A"}
    /* currently PLACEHOLDER_DATA pending further development 
       If only one type of need is recorded, this should be recorded as rank 1. If multiple types of need are recorded, then the primary type of need should be recorded as rank 1 and the secondary type of need should be recorded as rank 2. Up to two types of need can be recorded. */
    NULL AS "senn_active_ehcp_need_rank"; --metadata={"item_ref":"SENN004A"}
