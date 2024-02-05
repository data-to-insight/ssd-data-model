-- ALTER SESSION SET CURRENT_SCHEMA = HDM;


/*
******************************************
SSD AnnexA Returns Queries || Oracle/PLSQL
******************************************
*/


/* 
=============================================================================
Report Name: Ofsted List 1 - Contacts YYYY
Description: 
            List 1: 
            Contacts "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for each child in the contact.

Author: D2I
Last Modified Date: 12/01/24 RH
DB Compatibility: Oracle 8i+|...
Version: 1.0
            0.4: contact_source_desc added
            0.3: apply revised obj/item naming. 
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- @ssd_timeframe_years
- ssd_contacts
- ssd_person
=============================================================================
*/

DECLARE
    v_ssd_timeframe_years INT := 1;
    v_today DATE := SYSDATE; -- Current date
BEGIN
    -- if exists, drop (adjust for global temporary tbl)
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE AA_1_contacts';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;
    
    -- create structure
    EXECUTE IMMEDIATE 'CREATE TABLE AA_1_contacts (
        CHILD_ID NVARCHAR2(48),
        GENDER NVARCHAR2(48),
        ETHNICITY NVARCHAR2(38),
        DATE_OF_BIRTH NVARCHAR2(10),
        AGE INT,
        DATE_OF_CONTACT NVARCHAR2(10),
        CONTACT_SOURCE NVARCHAR2(1000)
    )';

    -- insert data
    INSERT INTO AA_1_contacts (CHILD_ID, GENDER, ETHNICITY, DATE_OF_BIRTH, AGE, DATE_OF_CONTACT, CONTACT_SOURCE)
    SELECT
        p.pers_legacy_id                        AS CHILD_ID,
        p.pers_sex                              AS GENDER,
        p.pers_ethnicity                        AS ETHNICITY,
        TO_CHAR(p.pers_dob, 'dd/MM/yyyy')       AS DATE_OF_BIRTH,
        CASE
            WHEN p.pers_dob > v_today THEN -1
            WHEN TO_CHAR(p.pers_dob, 'MMDD') = '0229' AND TO_CHAR(v_today, 'MMDD') < '0228' AND
                (MOD(TO_NUMBER(TO_CHAR(v_today, 'YYYY')), 4) != 0 OR
                (MOD(TO_NUMBER(TO_CHAR(v_today, 'YYYY')), 100) = 0 AND MOD(TO_NUMBER(TO_CHAR(v_today, 'YYYY')), 400) != 0))
            THEN TO_NUMBER(TO_CHAR(v_today, 'YYYY')) - TO_NUMBER(TO_CHAR(p.pers_dob, 'YYYY')) - 2
            ELSE
                TO_NUMBER(TO_CHAR(v_today, 'YYYY')) - TO_NUMBER(TO_CHAR(p.pers_dob, 'YYYY')) -
                CASE
                    WHEN TO_CHAR(v_today, 'MMDD') < TO_CHAR(p.pers_dob, 'MMDD') THEN 1
                    ELSE 0
                END
        END                                     AS AGE,
        TO_CHAR(c.cont_contact_start, 'dd/MM/yyyy') AS DATE_OF_CONTACT,
        c.cont_contact_source_desc              AS CONTACT_SOURCE
    FROM
        ssd_contact c
    LEFT JOIN
        ssd_person p ON c.cont_person_id = p.pers_person_id
    WHERE
        c.cont_contact_start >= ADD_MONTHS(v_today, -v_ssd_timeframe_years * 12);

    -- [TESTING]
    -- FOR rec IN (SELECT * FROM AA_1_contacts) LOOP
    --     DBMS_OUTPUT.PUT_LINE('Child ID: ' || rec.CHILD_ID || ', Date of Contact: ' || rec.DATE_OF_CONTACT || ', Age: ' || rec.AGE);
    -- END LOOP;
END;
/

-- [TESTING]
-- SELECT * FROM AA_1_contacts;


