-- META-CONTAINER: {"type": "table", "name": "ssd_cla_previous_permanence"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_previous_permanence', 'U') IS NOT NULL DROP TABLE #ssd_cla_previous_permanence;

IF OBJECT_ID('ssd_cla_previous_permanence', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_previous_permanence)
        TRUNCATE TABLE ssd_cla_previous_permanence;
END
ELSE
BEGIN
    CREATE TABLE ssd_cla_previous_permanence (
        lapp_table_id                       NVARCHAR(48)  NOT NULL PRIMARY KEY,  -- metadata={"item_ref":"LAPP001A"}
        lapp_person_id                      NVARCHAR(48)  NULL,                  -- metadata={"item_ref":"LAPP002A"}
        lapp_previous_permanence_option     NVARCHAR(200) NULL,                  -- metadata={"item_ref":"LAPP003A"}
        lapp_previous_permanence_la         NVARCHAR(100) NULL,                  -- metadata={"item_ref":"LAPP004A"}
        lapp_previous_permanence_order_date NVARCHAR(10)  NULL                   -- metadata={"item_ref":"LAPP005A"}
    );
END;

INSERT INTO ssd_cla_previous_permanence (
    lapp_table_id,
    lapp_person_id,
    lapp_previous_permanence_option,
    lapp_previous_permanence_la,
    lapp_previous_permanence_order_date
)
SELECT
    NULL AS lapp_table_id,
    NULL AS lapp_person_id,
    NULL AS lapp_previous_permanence_option,
    NULL AS lapp_previous_permanence_la,
    NULL AS lapp_previous_permanence_order_date
FROM ssd_person sp
WHERE 1 = 0;