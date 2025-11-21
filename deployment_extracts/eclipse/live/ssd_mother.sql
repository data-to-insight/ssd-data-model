-- =============================================================================
-- META-ELEMENT: {"type": "drop_table"}
-- Note: uncomment only if dropping to apply new structural update(s)
-- =============================================================================
-- DROP TABLE IF EXISTS ssd_mother;

-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_mother (
    moth_table_id           VARCHAR(48) PRIMARY KEY,   -- metadata={"item_ref":"MOTH004A"}
    moth_person_id          VARCHAR(48),               -- metadata={"item_ref":"MOTH002A"}
    moth_childs_person_id   VARCHAR(48),               -- metadata={"item_ref":"MOTH001A"}
    moth_childs_dob         TIMESTAMP                  -- metadata={"item_ref":"MOTH003A"}
);

TRUNCATE TABLE ssd_mother;

INSERT INTO ssd_mother (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)
SELECT
    PPR.PERSONRELATIONSHIPRECORDID  AS moth_table_id,          -- metadata={"item_ref":"MOTH004A"}
    PPR.ROLEAPERSONID               AS moth_person_id,         -- metadata={"item_ref":"MOTH002A"}
    PPR.ROLEBPERSONID               AS moth_childs_person_id,  -- metadata={"item_ref":"MOTH001A"}
    PDV.DATEOFBIRTH                 AS moth_childs_dob         -- metadata={"item_ref":"MOTH003A"}
FROM RELATIONSHIPPERSONVIEW PPR
LEFT JOIN PERSONDEMOGRAPHICSVIEW PDV 
       ON PDV.PERSONID = PPR.ROLEBPERSONID
WHERE PPR.RELATIONSHIP = 'Mother'
  -- mother in SSD cohort
  AND EXISTS (
        SELECT 1
        FROM ssd_person sp_mother
        WHERE sp_mother.pers_person_id = PPR.ROLEAPERSONID
      )
  -- child in SSD cohort 
  AND EXISTS (
        SELECT 1
        FROM ssd_person sp_child
        WHERE sp_child.pers_person_id = PPR.ROLEBPERSONID
      );
