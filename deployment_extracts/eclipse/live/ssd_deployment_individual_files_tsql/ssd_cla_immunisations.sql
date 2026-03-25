-- META-CONTAINER: {"type": "table", "name": "ssd_cla_immunisations"}
-- =============================================================================
-- Description:
-- Author:
-- Version: 0.1
-- Status: [D]ev
-- Remarks: [EA_API_PRIORITY_TABLE]
-- Dependencies:
-- - FORMANSWERPERSONVIEW
-- - ssd_person
--
-- =============================================================================

IF OBJECT_ID('tempdb..#ssd_cla_immunisations', 'U') IS NOT NULL DROP TABLE #ssd_cla_immunisations;

IF OBJECT_ID('ssd_cla_immunisations', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM ssd_cla_immunisations)
        TRUNCATE TABLE ssd_cla_immunisations;
END
ELSE
BEGIN
    CREATE TABLE ssd_cla_immunisations (
        clai_person_id                 NVARCHAR(48) NOT NULL PRIMARY KEY,  -- metadata={"item_ref":"CLAI002A"}
        clai_immunisations_status      NCHAR(1)     NULL,                  -- metadata={"item_ref":"CLAI004A"}
        clai_immunisations_status_date DATETIME     NULL                   -- metadata={"item_ref":"CLAI005A"}
    );
END;

INSERT INTO ssd_cla_immunisations (
    clai_person_id,
    clai_immunisations_status,
    clai_immunisations_status_date
)
SELECT
    CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID) AS clai_person_id,  -- metadata={"item_ref":"CLAI002A"}
    MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('903Return_ImmunisationsComplete')
                THEN LEFT(CONVERT(NVARCHAR(255), FAPV.ANSWERVALUE), 1)
        END) AS clai_immunisations_status,  -- metadata={"item_ref":"CLAI004A"}
    MAX(CASE
            WHEN FAPV.CONTROLNAME IN ('903Return_dateOfCheckImm')
                THEN TRY_CONVERT(DATETIME, FAPV.ANSWERVALUE)
        END) AS clai_immunisations_status_date  -- metadata={"item_ref":"CLAI005A"}
FROM FORMANSWERPERSONVIEW FAPV
WHERE FAPV.DESIGNGUID = '0438ab4f-0d93-40d3-ab73-f97455646041'
  AND FAPV.INSTANCESTATE IN ('COMPLETE')
  AND FAPV.DESIGNSUBNAME IN ('Immunisation check ')
  AND EXISTS (
        SELECT 1
        FROM ssd_person sp
        WHERE sp.pers_person_id = CONVERT(NVARCHAR(48), FAPV.ANSWERFORSUBJECTID)
  )
GROUP BY
    FAPV.ANSWERFORSUBJECTID;