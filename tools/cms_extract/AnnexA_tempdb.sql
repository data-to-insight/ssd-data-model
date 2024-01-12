USE HDM_Local;
GO

-- var naming needs re-think for stat returns reporting, 
-- this atm carried over from... ssd time-frames (YRS)
DECLARE @ssd_timeframe_years INT = 1;

/* 
=============================================================================
Object Name: Ofsted List 1 - Contacts YYYY
Description: 
            List 1: 
            Contacts "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for each child in the contact.

Author: D2I
Last Modified Date: 11/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 0.3
Status: [Dev, *Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: script modified to reflect new|revised obj/item naming. 
Dependencies: 
- @ssd_timeframe_years
- ssd_contacts
- ssd_person
=============================================================================
*/

-- CREATE TEMPORARY TABLE `AA_1_contacts` AS 
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_1_contacts') IS NOT NULL DROP TABLE #AA_1_contacts;


-- Create stat-return structure
SELECT
    p.pers_person_id                        AS CHILD_ID,
    p.pers_sex                              AS GENDER,
    p.pers_ethnicity                        AS ETHNICITY,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')        AS DATE_OF_BIRTH,
    CASE
        -- If DoB is in the future, set age as -1 (unborn)
        WHEN p.pers_dob > GETDATE() THEN -1

        -- Special case for leap year babies (born Feb 29)
        WHEN MONTH(p.pers_dob) = 2 AND DAY(p.pers_dob) = 29 AND
            MONTH(GETDATE()) <= 2 AND DAY(GETDATE()) < 28 AND
            -- Check if current year is not a leap year
            (YEAR(GETDATE()) % 4 != 0 OR (YEAR(GETDATE()) % 100 = 0 AND YEAR(GETDATE()) % 400 != 0))
        THEN YEAR(GETDATE()) - YEAR(p.pers_dob) - 2

        ELSE 
            -- Calc age normally
            YEAR(GETDATE()) - YEAR(p.pers_dob) - 
            CASE 
                -- Subtract extra year if current date is before birthday this year
                WHEN MONTH(GETDATE()) < MONTH(p.pers_dob) OR 
                    (MONTH(GETDATE()) = MONTH(p.pers_dob) AND DAY(GETDATE()) < DAY(p.pers_dob))
                THEN 1 
                ELSE 0
            END
    END                                         AS AGE,


    FORMAT(c.cont_contact_start, 'dd/MM/yyyy')  AS DATE_OF_CONTACT,
    c.cont_contact_source                       AS CONTACT_SOURCE

INTO #AA_1_contacts
FROM
    #ssd_contact c

LEFT JOIN
    #ssd_person p ON c.cont_person_id = p.pers_person_id
WHERE
    c.cont_contact_start >= DATEADD(MONTH, -@ssd_timeframe_years * 12, GETDATE());


select * from #AA_1_contacts;