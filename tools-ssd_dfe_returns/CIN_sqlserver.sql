-- Ensure the XML structure includes the header and child records from the ssd_person table
SELECT 
    (
        SELECT
            'CIN' AS 'Collection',
            '2021' AS 'Year',
            '2021-03-31' AS 'ReferenceDate'
        FOR XML PATH('CollectionDetails'), TYPE
    ),
    (
        SELECT
            'L' AS 'SourceLevel',
            '845' AS 'LEA',
            'Local Authority' AS 'SoftwareCode',
            '16' AS 'SerialNo',
            '2021-06-09 09:42:32' AS 'DateTime'
        FOR XML PATH('Source'), TYPE
    ),
    (
        SELECT
            (
                SELECT
                    'Child' AS 'CBDSLevel'
                FOR XML PATH('CBDSLevels'), TYPE
            )
        FOR XML PATH('Content'), TYPE
    )
FOR XML PATH('Header'), TYPE,
(
    SELECT
        (
            SELECT
                pers_legacy_id AS 'LAchildID',
                pers_common_child_id AS 'UPN',
                pers_dob AS 'PersonBirthDate',
                CASE 
                    WHEN pers_gender = 'M' THEN '1'
                    WHEN pers_gender = 'F' THEN '2'
                    ELSE '0'
                END AS 'GenderCurrent'
            FOR XML PATH('ChildIdentifiers'), TYPE
        ),
        (
            SELECT
                pers_ethnicity AS 'Ethnicity',
                (
                    SELECT
                        'NONE' AS 'Disability'
                    FOR XML PATH('Disabilities'), TYPE
                )
            FOR XML PATH('ChildCharacteristics'), TYPE
        )
    FROM 
        ssd_development.ssd_person
    FOR XML PATH('Child'), TYPE
) AS Children
FOR XML PATH('Message');
