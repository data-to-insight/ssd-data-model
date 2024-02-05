


/* =============================================================================
SSD_PERSON
*/

/* COMMON VAR SET UP */ 

DECLARE
    STARTTIME DATE := SYSDATE;
    ENDTIME DATE;
    ssd_timeframe_years INT := 6;
    ssd_sub1_range_years INT := 1;

/* 
=============================================================================
Object Name: ssd_person (DataWarehouse)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/
-- [TESTING]
BEGIN
    FOR rec IN (
        SELECT DISTINCT
            p.PersonID pers_person_id,
            p.Sex pers_sex,
            p.pGender pers_gender,
            COALESCE(ec.CINCode, 'NOBT') pers_ethnicity,
            p.PDoB pers_dob,
            p.PNHSNumber pers_common_child_id,
            p.PUniquePupilNumber pers_upn,
            NULL pers_upn_unknown,
            CASE WHEN ehcp.PersonID IS NOT NULL THEN 'Y' END pers_send,
            p.PDoBEstimated pers_expected_dob,
            p.PDoD pers_death_date,
            CASE WHEN r.RelSourcePerson IS NOT NULL THEN 'Y' END pers_is_mother,
            NULL pers_nationality
        FROM
            Mosaic.D.PersonData p
            LEFT JOIN Mosaic.DS.EthnicityConversion ec ON p.pEthnicityCode = ec.SubEthnicityCode
            LEFT JOIN EMS.D.INVOLVEMENTS_EHCP ehcp ON p.PEMSNumber = ehcp.PersonID
                AND EHCPCompleteDate IS NOT NULL
            LEFT JOIN Mosaic.D.Relationships r ON p.PersonID = r.RelSourcePerson
                AND r.RelRelationship = 'is the mother of'
                AND r.RelTo IS NULL
        WHERE (
            EXISTS (
                SELECT
                    a.PersonID
                FROM
                    ChildrensReports.ICS.Contacts a
                WHERE
                    a.PersonID = p.PersonID
                    AND a.StartDate >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
            )
            OR EXISTS (
                SELECT
                    a.PERSON_ID
                FROM
                    Mosaic.M.PERSON_LEGAL_STATUSES a
                WHERE
                    a.PERSON_ID = p.PersonID
                    AND COALESCE(a.END_DATE, TO_DATE('99991231', 'YYYYMMDD')) >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
            )
            OR EXISTS (
                SELECT
                    a.PersonID
                FROM
                    ChildrensReports.D.CINPeriods a
                WHERE
                    a.PersonID = p.PersonID
                    AND a.CINPeriodEnd >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
            )
        )
        ORDER BY
            p.PersonID
    ) LOOP
        -- Process records here, for example:
        -- DBMS_OUTPUT.PUT_LINE('Person ID: ' || rec.pers_person_id);
    END LOOP;
END;
/



/* 
=============================================================================
Object Name: ssd_person (LIVE)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/
-- [TESTING]
BEGIN
    FOR rec IN (
        SELECT DISTINCT
            p.PERSON_ID pers_person_id,
            p.GENDER pers_sex,
            pg.GENDER_CODE pers_gender,
            -- p.SUB_ETHNICITY pers_ethnicity,
            e.CIN_ETHNICITY_DESCRIPTION pers_ethnicity,
            CAST(p.DATE_OF_BIRTH AS DATE) pers_dob,
            r1.REFERENCE pers_common_child_id,
            r2.REFERENCE pers_upn,
            NULL pers_upn_unknown,
            NULL pers_send,  -- Information held in Education System
            p.AGE_ESTIMATED pers_expected_dob,
            p.DATE_OF_DEATH pers_death_date,
            CASE WHEN rel.PERSON_RELATIONSHIP_ID IS NOT NULL THEN 'Y' END pers_is_mother,
            p.COUNTRY_OF_BIRTH pers_nationality
        FROM
            moLive.dbo.MO_PERSONS p
            LEFT JOIN moLive.dbo.MO_PERSON_GENDER_IDENTITIES pg ON p.PERSON_ID = pg.PERSON_ID
                AND pg.END_DATE IS NULL
            LEFT JOIN moLive.dbo.DM_ETHNICITIES e ON p.SUB_ETHNICITY = SUBSTR(e.ETHNICITY_CODE, 3)
                AND e.CIN_ETHNICITY_CODE IS NOT NULL
            LEFT JOIN moLive.dbo.MO_SUBJECT_REFERENCES r1 ON p.PERSON_ID = r1.SUBJECT_COMPOUND_ID
                AND r1.REFERENCE_TYPE_CODE = 'NHS'
            LEFT JOIN moLive.dbo.MO_SUBJECT_REFERENCES r2 ON p.PERSON_ID = r2.SUBJECT_COMPOUND_ID
                AND r2.REFERENCE_TYPE_CODE = 'UPN'
            -- LEFT JOIN EMS.D.INVOLVEMENTS_EHCP ehcp ON p.PEMSNumber = ehcp.PersonID
            -- AND EHCPCompleteDate IS NOT NULL  -- Will give EHCP / SEN Statement ever, may need to add date criteria to show current or within reporting period
            LEFT JOIN moLive.dbo.MO_PERSON_RELATIONSHIPS rel ON p.PERSON_ID = rel.PERSON_ID  -- Will return 'Y' if any 'Mother - Child Relationship, may need to add criteria to show if child born while LAC or open to CSC
                AND rel.RELATIONSHIP_TYPE_ID IN (
                    SELECT rt.RELATIONSHIP_TYPE_ID
                    FROM moLive.dbo.MO_RELATIONSHIP_TYPES rt
                    WHERE rt.RELATIONSHIP_CODE = 'MOTHER'
                )
        WHERE (
            EXISTS (
                -- Contact in last x years
                SELECT s.SUBJECT_COMPOUND_ID
                FROM MoLive.dbo.MO_WORKFLOW_STEPS ws
                INNER JOIN moLive.dbo.MO_SUBGROUP_SUBJECTS s ON ws.SUBGROUP_ID = s.SUBGROUP_ID
                INNER JOIN moLive.dbo.MO_FORMS f ON ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
                INNER JOIN moLive.dbo.MO_FORM_DATE_ANSWERS fa ON f.FORM_ID = fa.FORM_ID
                WHERE s.SUBJECT_COMPOUND_ID = p.PERSON_ID
                AND ws.WORKFLOW_STEP_TYPE_ID IN (335, 344) -- 335 - Contact/Referral; 344 - EDT Contact/Referral
                AND CAST(fa.DATE_ANSWER AS DATE) >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
            )
            OR EXISTS (
                -- LAC Legal Status in last x years
                SELECT a.PERSON_ID
                FROM moLive.dbo.PERSON_LEGAL_STATUSES a
                WHERE a.PERSON_ID = p.PERSON_ID
                AND COALESCE(a.END_DATE, TO_DATE('99991231', 'YYYYMMDD')) >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
            )
        )
        -- Remove Duplicate People  -- Not currently included in code as Data Warehouse moves work on a duplicate record to the master record, therefore numbers are different by more if this section included
        -- AND NOT EXISTS (
        --     SELECT a.PERSON_ID
        --     FROM moLive.dbo.MO_PERSON_RELATIONSHIPS a
        --     INNER JOIN moLive.DBO.MO_RELATIONSHIP_TYPES b ON a.RELATIONSHIP_TYPE_ID = b.RELATIONSHIP_TYPE_ID
        --     WHERE a.PERSON_ID = p.PERSON_ID
        --     AND b.RELATIONSHIP_CODE = 'DUPLICATE'
        -- )
        ORDER BY p.PERSON_ID
/



/* 
=============================================================================
Object Name: ssd_person (ESSEX)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/
-- [TESTING]
SELECT
    per.PERSON_ID per_person_id,
    per.GENDER pers_gender,
    per.FULL_ETHNICITY_CODE pers_ethnicity,
    CASE
        WHEN per.date_of_birth <= TRUNC(SYSDATE) THEN
            per.date_of_birth
    END pers_dob,
    per.NHS_ID pers_common_child_id,
    per.UPN_ID pers_upn,
    NULL pers_upn_unknown,
    NULL pers_send,
    CASE
        WHEN per.date_of_birth > TRUNC(SYSDATE) THEN
            per.date_of_birth
    END pers_expected_dob,
    per.date_of_death,
    CASE
        WHEN per.GENDER = 'F' THEN
            (
                SELECT
                    MAX('Y')
                FROM
                    SCF.Personal_Relationships rel
                WHERE
                    rel.PERSON_ID = per.PERSON_ID
                    AND
                    rel."RELATIONSHIP_TYPE: PERSON_ID - OTHER_PERSON_ID" IN (
                        'Mother : Child',
                        'Mother : Daughter',
                        'Mother : Son',
                        'Parent : Child',
                        'Parent : Daughter',
                        'Parent : Son'
                    )
            )
    END pers_is_mother,
    per.country_of_birth_code,
    (
        SELECT
            rd.REF_DESCRIPTION
        FROM
            raw.mosaic_fw_reference_data rd
        WHERE
            rd.REF_CODE = per.country_of_birth_code
            AND
            rd.REF_DOMAIN = 'COUNTRY'
    ) pers_nationality
FROM
    raw.mosaic_fw_dm_persons per;
/




/* =============================================================================
SSD_LEGAL_STATUS
*/

/* COMMON VAR SET UP */ 

DECLARE
    STARTTIME DATE := SYSDATE;
    ENDTIME DATE;
    ssd_timeframe_years INT := 6;
    ssd_sub1_range_years INT := 1;

/* 
=============================================================================
Object Name: ssd_legal_status (DataWarehouse)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/

BEGIN
    FOR rec IN (
        SELECT
            a.ID lega_legal_status_id,
            a.PERSON_ID lega_person_id,
            a.LEGAL_STATUS lega_legal_status,
            a.START_DATE lega_legal_status_start_date,
            a.END_DATE lega_legal_status_end_date
        FROM
            Mosaic.M.PERSON_LEGAL_STATUSES a
        WHERE
            COALESCE(a.END_DATE, TO_DATE('99991231', 'YYYYMMDD')) >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
        ORDER BY
            a.START_DATE, a.PERSON_ID
    ) LOOP
        -- Process your records here, for example:
        -- DBMS_OUTPUT.PUT_LINE('Legal Status ID: ' || rec.lega_legal_status_id);
    END LOOP;
END;
/


/* 
=============================================================================
Object Name: ssd_legal_status  (LIVE)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/

BEGIN
    FOR rec IN (
        SELECT
            a.ID lega_legal_status_id,
            a.PERSON_ID lega_person_id,
            a.LEGAL_STATUS lega_legal_status,
            a.START_DATE lega_legal_status_start_date,
            a.END_DATE lega_legal_status_end_date
        FROM
            moLive.PERSON_LEGAL_STATUSES a
        WHERE
            NVL(a.END_DATE, TO_DATE('99991231', 'YYYYMMDD')) >= ADD_MONTHS(STARTTIME, -ssd_timeframe_years * 12)
        ORDER BY
            a.START_DATE, a.PERSON_ID
    ) LOOP
        -- Process your records here, for example:
        -- DBMS_OUTPUT.PUT_LINE('Legal Status ID: ' || rec.lega_legal_status_id);
    END LOOP;
END;
/



/* 
=============================================================================
Object Name: ssd_legal_status  (ESSEX)
Description: 
Author: D2I
Last Modified Date: 
DB Compatibility: Oracle 11g+|...
=============================================================================
*/
SELECT
    DISTINCT
    cla.LEGAL_STATUS_ID lega_legal_status_id,
    cla.PERSON_ID lega_person_id,
    cla.LEGAL_STATUS lega_legal_status,
    cla.LEGAL_STATUS_START lega_legal_status_start_date,
    cla.LEGAL_STATUS_END lega_legal_status_end_date
FROM
    SCF.Children_In_Care cla;
/