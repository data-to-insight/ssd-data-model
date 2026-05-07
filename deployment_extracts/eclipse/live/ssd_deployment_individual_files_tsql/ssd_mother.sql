-- META-ELEMENT: {"type": "create_table"}
IF OBJECT_ID('tempdb..#ssd_mother', 'U') IS NOT NULL DROP TABLE #ssd_mother;

IF OBJECT_ID('[eclipseDelta].[dbo].[ssd_mother]', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [eclipseDelta].[dbo].[ssd_mother])
        TRUNCATE TABLE [eclipseDelta].[dbo].[ssd_mother];
END
ELSE
BEGIN
    CREATE TABLE [eclipseDelta].[dbo].[ssd_mother] (
        moth_table_id           NVARCHAR(48) NOT NULL PRIMARY KEY, -- metadata={"item_ref":"MOTH004A"}
        moth_person_id          NVARCHAR(48) NULL,               -- metadata={"item_ref":"MOTH002A"}
        moth_childs_person_id   NVARCHAR(48) NULL,               -- metadata={"item_ref":"MOTH001A"}
        moth_childs_dob         DATETIME     NULL                -- metadata={"item_ref":"MOTH003A"}
    );
END;

TRUNCATE TABLE [eclipseDelta].[dbo].[ssd_mother];

INSERT INTO [eclipseDelta].[dbo].[ssd_mother] (
    moth_table_id,
    moth_person_id,
    moth_childs_person_id,
    moth_childs_dob
)
SELECT
    CONVERT(NVARCHAR(48), PPR.PERSONRELATIONSHIPRECORDID) AS moth_table_id,          -- metadata={"item_ref":"MOTH004A"}
    CONVERT(NVARCHAR(48), PPR.ROLEAPERSONID)              AS moth_person_id,         -- metadata={"item_ref":"MOTH002A"}
    CONVERT(NVARCHAR(48), PPR.ROLEBPERSONID)              AS moth_childs_person_id,  -- metadata={"item_ref":"MOTH001A"}
    CAST(PDV.DATEOFBIRTH AS DATETIME)                     AS moth_childs_dob         -- metadata={"item_ref":"MOTH003A"}
FROM [eclipseDelta].[dbo].[RELATIONSHIPPERSONVIEW] PPR
LEFT JOIN [eclipseDelta].[dbo].[PERSONDEMOGRAPHICSVIEW] PDV
       ON PDV.PERSONID = PPR.ROLEBPERSONID
WHERE PPR.RELATIONSHIP = 'Mother'
  -- mother in SSD cohort
  AND EXISTS (
        SELECT 1
        FROM [eclipseDelta].[dbo].[ssd_person] sp_mother
        WHERE sp_mother.pers_person_id =
              CONVERT(VARCHAR(48), PPR.ROLEAPERSONID)
      )
  -- child in SSD cohort 
  AND EXISTS (
        SELECT 1
        FROM [eclipseDelta].[dbo].[ssd_person] sp_child
        WHERE sp_child.pers_person_id =
              CONVERT(VARCHAR(48), PPR.ROLEBPERSONID)
      );