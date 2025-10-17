/*
ANNEX A [SEND] List 1 & 2

tool provided as part of the
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

Script creates DfE AnnexA SEND outputs list 1->2 from the SSD structure. 
Prerequisit(s): The SSD extract must have been run/set up before running this tool.
List queries might need to be run seperately, or output to a file(not provided) in order to view the outputs. 
Each list populates a temporary table of the extracted data to enable additional preprocessing/monitoring to be 
undertaken. 
*/


/* **********************************************************************************************************

Notes: 
- There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results. 
********************************************************************************************************** */

-- LA specific vars
USE HDM_local;

GO -- also reset previously defined vars

-- Set reporting period in months
DECLARE @AA_ReportingPeriod INT;
SET @AA_ReportingPeriod = 6; -- Months

/*
*********************************************
SSD AnnexA SEND Returns Queries || SQL Server
*********************************************
*/

/*
=============================================================================
Report Name: Ofsted List 1 - EHC plan
Description: 
            "All children and young people with an EHC plan for whom your 
            local authority is responsible."

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.9 
Status: [R]elease
Remarks: 
Dependencies: 
- ssd_contacts
- ssd_person
- @AA_ReportingPeriod
=============================================================================
*/


-- Check if exists & drop
IF OBJECT_ID('AA_SEND_1_EHC') IS NOT NULL DROP TABLE AA_SEND_1_EHC;
IF OBJECT_ID('tempdb..#AA_SEND_1_EHC') IS NOT NULL DROP TABLE #AA_SEND_1_EHC;

SELECT
    /* Common AA fields */
    p.pers_person_id AS ChildUniqueID,
    CASE
        WHEN p.pers_gender = 'M' THEN 'a) Male'
        WHEN p.pers_gender = 'F' THEN 'b) Female'
		WHEN p.pers_gender = 'U' THEN 'c) Not known'
		WHEN p.pers_gender = 'I' THEN 'd) Not specified'
    END AS Gender,
    CASE
        WHEN p.pers_ethnicity IN ('WBRI', 'A1') THEN 'a) WBRI'
        WHEN p.pers_ethnicity IN ('WIRI', 'A2') THEN 'b) WIRI'
        WHEN p.pers_ethnicity IN ('WIRT', 'A4') THEN 'c) WIRT'
        WHEN p.pers_ethnicity IN ('WOTH', 'A3') THEN 'd) WOTH'
        WHEN p.pers_ethnicity IN ('WROM', 'A5') THEN 'e) WROM'
        WHEN p.pers_ethnicity IN ('MWBC', 'B1') THEN 'f) MWBC'
        WHEN p.pers_ethnicity IN ('MWBA', 'B2') THEN 'g) MWBA'
        WHEN p.pers_ethnicity IN ('MWAS', 'B3') THEN 'h) MWAS'
        WHEN p.pers_ethnicity IN ('MOTH', 'B4') THEN 'i) MOTH'
        WHEN p.pers_ethnicity IN ('AIND', 'C1') THEN 'j) AIND'
        WHEN p.pers_ethnicity IN ('APKN', 'C2') THEN 'k) APKN'
        WHEN p.pers_ethnicity IN ('ABAN', 'C3') THEN 'l) ABAN'
        WHEN p.pers_ethnicity IN ('AOTH', 'C4') THEN 'm) AOTH'
        WHEN p.pers_ethnicity IN ('BCRB', 'D1') THEN 'n) BCRB'
        WHEN p.pers_ethnicity IN ('BAFR', 'D2') THEN 'o) BAFR'
        WHEN p.pers_ethnicity IN ('BOTH', 'D3') THEN 'p) BOTH'
        WHEN p.pers_ethnicity IN ('CHNE', 'E1') THEN 'q) CHNE'
        WHEN p.pers_ethnicity IN ('OOTH', 'E2') THEN 'r) OOTH'
        WHEN p.pers_ethnicity IN ('REFU', 'E3') THEN 's) REFU'
        WHEN p.pers_ethnicity IN ('NOBT', 'E4') THEN 't) NOBT'
        WHEN p.pers_ethnicity IN ('UNKNOWN', 'E5') THEN 'u) UNKNOWN'
        ELSE 'u) UNKNOWN' -- 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'
    END AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy') AS DateOfBirth, -- If no date of birth, leave blank
    CONVERT(VARCHAR, p.pers_dob, 103) AS DateOfBirth, -- [TESTING] Review export formats and Excel date handling #DtoI-1731

    /* List additional AA fields */
    UPN	-- Unique Pupil Number for each child or young person.
    ULN	-- Unique Learner Number for each young person.
    -- FORMAT(c.cont_contact_date, 'dd/MM/yyyy') AS DateOfContact,


-- AS Date initial EHC plan issued	"Provide the date the child or young person's initial EHC plan was issued. DD/MM/YYYY format
-- AS Date updated EHC plan issued	"Provide the date the child or young person's EHC plan was last updated, where applicable. DD/MM/YYYY format
-- If the EHC plan has not been updated, leave blank."
-- AS Date EHC plan last reviewed	"Provide the date the EHC plan was last reviewed, i.e. the date of the last annual review.DD/MM/YYYY formatIf the EHC plan has not yet been reviewed, leave blank."
-- AS SEN primary need	"Provide the child or young person's primary type of need.
-- If a child or young person has been identified with multiple needs, please provide the need recorded as rank 1 in the SEN2 return.

-- Please use codes (from SEN2):
-- a) SPLD
-- b) MLD
-- c) SLD
-- d) PMLD
-- e) SEMH
-- f) SLCN
-- g) HI
-- h) VI
-- i) MSI
-- j) PD
-- k) ASD
-- l) OTH
-- "
-- AS Main education establishment – URN	"Provide the six digit Unique Reference Number (URN) of the child or young person's main educational establishment.
-- This should be the phase of the establishment at which the enrolment status of the child or young person is recorded as 'C' (current single) or 'M' (current main) or equivalent.

-- Please refer to Get information about schools (GIAS) to obtain the URN."
-- AS Main education establishment – phase	"Provide the school phase of the child or young person's main education establishment.
-- This should be the phase of the establishment at which the enrolment status of the child or young person is recorded as 'C' (current single) or 'M' (current main) or equivalent.
-- a) Nursery
-- b) Primary
-- c) Middle (deemed primary)
-- d) Middle (deemed secondary)
-- e) Secondary
-- f) All-through
-- g) Special
-- h) Pupil referral unit/Alternative provision
-- i) FE college"
-- Subsidiary education establishment – phase (dual registration)	"If the child or young person is dual registered, provide the phase of the subsidiary education establishment.
-- This should be the phase of the establishment at which the enrolment status of the child or young person is recorded as 'S' (current subsidiary) or equivalent.
-- a) Nursery
-- b) Primary
-- c) Middle (deemed primary)
-- d) Middle (deemed secondary)
-- e) Secondary
-- f) All-through
-- g) Special
-- h) Pupil referral unit/Alternative provision
-- i) FE college"

-- AS Elective home education	
-- a) Yes
-- b) No

-- AS Suspensions (INT)	"Provide the number of suspensions the child or young person has had in the last 6 months.
-- If this is not available, provide your most recent data, even if this is from the most recent school census.

-- AS Permanent exclusions	(INT) "Provide the number of permanent exclusions the child or young person has had in the last 6 months.
-- If this is not available, provide your most recent data, even if this is from the most recent school census.

-- AS Absence	(%) "Provide the percentage of sessions missed by the child or young person in the last 6 months due to overall absence.
-- If this is not available, provide your most recent data, even if this is from the most recent school census.

-- AS Pupil Premium
-- a) Yes
-- b) No"

-- AS Known to children's social care?	"Indicate whether the child or young person is known to children's social care.
-- a) Yes
-- b) No"
-- AS Which children's social care team?	"If known, indicate the social care team that has the most involvement with the child or young person.
-- For example, this could be: children in care; children in need; child protection; family support service; looked after children; targeted early help. This list is not exhaustive.
-- If the child or young person is not known to children's social care, please leave blank."

INTO AA_SEND_1_EHC

FROM
    ssd_ XXXX as x

LEFT JOIN
    ssd_person p ON x.XXXX_person_id = p.pers_person_id

WHERE
    x.XXXX_XXXXX_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());

-- [TESTING]
SELECT * FROM AA_SEND_1_EHCs;



