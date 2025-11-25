-- META-ELEMENT: {"type": "create_table"}
CREATE TABLE IF NOT EXISTS ssd_linked_identifiers (
    link_table_id          VARCHAR(48) PRIMARY KEY,  -- metadata={"item_ref":"LINK001A"}
    link_person_id         VARCHAR(48),              -- metadata={"item_ref":"LINK002A"} 
    link_identifier_type   VARCHAR(100),             -- metadata={"item_ref":"LINK003A"}
    link_identifier_value  VARCHAR(100),             -- metadata={"item_ref":"LINK004A"}
    link_valid_from_date   TIMESTAMP,                -- metadata={"item_ref":"LINK005A"}
    link_valid_to_date     TIMESTAMP                 -- metadata={"item_ref":"LINK006A"}
);

SELECT
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Row identifier for the ssd_linked_identifiers table */
    NULL AS "link_table_id",         --metadata={"item_ref:"LINK001A"}
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Person's ID generated in CMS Database */
    NULL AS "link_person_id",        --metadata={"item_ref:"LINK002A"}
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Linked Identifier Type e.g. ['Case Number', 'Unique Pupil Number', 'NHS Number',
       'Home Office Registration', 'National Insurance Number', 'YOT Number',
       'Court Case Number', 'RAA ID', 'Incident ID'] */
    NULL AS "link_identifier_type",  --metadata={"item_ref:"LINK003A"}
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Identifier value */
    NULL AS "link_identifier_value", --metadata={"item_ref:"LINK004A"}
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Date the identifier is known or valid from */
    NULL AS "link_valid_from_date",  --metadata={"item_ref:"LINK005A"}
    /* (currently 'PLACEHOLDER_DATA' pending further development) 
       Date the identifier ceases to be known or valid */
    NULL AS "link_valid_to_date";    --metadata={"item_ref:"LINK006A"}
