USE HDM;
GO


-- Set reporting period in Mths
DECLARE @AA_ReportingPeriod INT;
SET @AA_ReportingPeriod = 6; -- Mths


-- 
-- /**** Obtain extract/csv files ****/
-- Use built in <export as> from console output or
-- bcp "QUERY_HERE" queryout "C:\path\to\myfile.csv" -c -t, -S SERVER_NAME -d DATABASE_NAME -U USERNAME -P PASSWORD





/*
****************************************
SSD AnnexA Returns Queries || SQL Server
****************************************
*/


/* 
=============================================================================
Report Name: Ofsted List 1 - Contacts YYYY
Description: 
            "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for 
            each child in the contact.""

Author: D2I
Last Modified Date: 12/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1
            1.0: PW/Blackpool updates
            0.4: contact_source_desc added
            0.3: apply revised obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_contacts
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_1_contacts') IS NOT NULL DROP TABLE #AA_1_contacts;


SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,	-- temp solution [TESTING] This liquid logic specific
    p.pers_person_id						    AS ChildUniqueID2,	-- temp solution [TESTING] This for compatiblility in non-ll systems
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')		    AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age

    /* List additional AA fields */
    FORMAT(c.cont_contact_date, 'dd/MM/yyyy')   AS DateOfContact,	
	c.cont_contact_source_desc			        AS ContactSource


INTO #AA_1_contacts

FROM
    #ssd_contact c

LEFT JOIN
    #ssd_person p ON c.cont_person_id = p.pers_person_id

WHERE
    c.cont_contact_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	



-- -- [TESTING]
-- select * from #AA_1_contacts;




/* 
=============================================================================
Report Name: Ofsted List 2 - Early Help Assessments YYYY
Description: 
            "All early help assessments in the six months before the date of 
            inspection. Also, current early help interventions that are being 
            coordinated through the local authority."

Author: D2I
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cin_episodes
- ssd_person
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_2_early_help_assessments') IS NOT NULL DROP TABLE #AA_2_early_help_assessments;


SELECT
    /* Common AA fields */
    p.pers_legacy_id                        AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')        AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    
    /* List additional AA fields */

    FORMAT(e.earl_episode_start_date, 'dd/MM/yyyy')     AS EHA_START_DATE,          -- [TESTING] Need a col name change?
    FORMAT(e.earl_episode_end_date, 'dd/MM/yyyy')       AS EHA_END_DATE,            -- [TESTING] Need a col name change?
    e.earl_episode_organisation                         AS EHA_COMPLETED_BY_TEAM    -- [TESTING] Need a col name change?

INTO #AA_2_early_help_assessments

FROM
    #ssd_person p

INNER JOIN
    #ssd_early_help_episodes e ON p.pers_person_id = e.earl_person_id

WHERE
    (
        /* eh_epi_start_date is within the last 6 months, or earl_episode_end_date is within the last 6 months, 
        or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
        e.earl_episode_start_date >= DATEADD(MONTH, -6, GETDATE())
    OR
        (e.earl_episode_end_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR e.earl_episode_end_date IS NULL OR e.earl_episode_end_date = '')
    );



-- -- [TESTING]
-- select * from #AA_2_early_help_assessments;


/* 
=============================================================================
Report Name: Ofsted List 3 - Referrals YYYY
Description:  
            "All referrals received in the six months before the inspection.
            Children may appear multiple times on this list if they have received 
            multiple referrals."

Author: D2I
Last Modified Date: 12/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cin_episodes
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_3_referrals') IS NOT NULL DROP TABLE #AA_3_referrals;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    
    /* List additional AA fields */
    ce.cine_referral_id                         AS REFERRAL_ID,
    FORMAT(ce.cine_referral_date, 'dd/MM/yyyy') AS REFERRAL_DATE,
    ce.cine_referral_source_desc                AS REFERRAL_SOURCE,
    CASE -- indicate if the most recent referral (or individual referral) resulted in 'No Further Action' (NFA)
        WHEN ce.cine_referral_nfa = 'NFA' THEN 'Yes'
        ELSE 'No'
    END                                         AS NFA,
    ce.cine_referral_team                       AS ALLOCATED_TEAM,
    ce.cine_referral_worker_id                  AS ALLOCATED_WORKER, 
    COALESCE(sub.count_12months, 0)             AS NUMBER_REFERRALS_LAST12MTHS

INTO #AA_3_referrals

FROM
    #ssd_cin_episodes ce
INNER JOIN
    #ssd_person p ON ce.cine_person_id = p.pers_person_id
LEFT JOIN
    (
        SELECT 
            cine_person_id,
            CASE -- referrals the child has received within the **12** months prior to their latest referral.
                WHEN COUNT(*) > 0 THEN COUNT(*) - 1
                ELSE 0
            END as count_12months
        FROM 
            #ssd_cin_episodes
        WHERE
            cine_referral_date >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY
            cine_person_id
    ) sub ON ce.cine_person_id = sub.cine_person_id
WHERE
    ce.cine_referral_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- -- [TESTING]
-- select * from #AA_3_referrals;



/* 
=============================================================================
Report Name: Ofsted List 4 - Assessments YYYY
Description: 
            "Young people and children with assessments in previous six months"
Author: D2I
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1 
            1.0 Further edits of source obj referencing, Fixed to working state
            0.3: Removed old obj/item naming. 
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_cin_assessments
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_4_assessments') IS NOT NULL DROP TABLE #AA_4_assessments;


SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    

    /* List additional AA fields */

    d.disa_disability_code                              AS Disability, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)

    FORMAT(a.cina_assessment_start_date, 'dd/MM/yyyy')  AS ASMT_START_DATE,
    a.cina_assessment_child_seen                        AS CONT_ASMT, -- ('Child Seen During Continuous Assessment')
    FORMAT(a.cina_assessment_auth_date, 'dd/MM/yyyy')   AS ASMT_AUTH_DATE,

    -- [TESTING][NEED TO CONFIRM THESE FIELDS]   
    cina_assessment_outcome_json                        AS REQU_SOCIAL_CARE_SUPPORT, 
    cina_assessment_outcome_nfa                         AS ASMT_OUTCOME_NFA, 

    -- Step type (SEE ALSO CONTACTS)
    a.cina_assessment_team                              AS ALLOCATED_TEAM,
    a.cina_assessment_worker_id                         AS ALLOCATED_WORKER


INTO #AA_4_assessments

FROM
    #ssd_cin_assessments a

INNER JOIN
    #ssd_person p ON a.cina_person_id = p.pers_person_id

LEFT JOIN   -- ensure we get all records even if there's no matching Disability
    #ssd_disability d ON p.pers_person_id = d.disa_person_id

WHERE
    a.cina_assessment_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- -- [TESTING]
-- select * from #AA_4_assessments;










/* 
=============================================================================
Report Name: Ofsted List 5 - Section 47 Enquiries and ICPC OC
Description: 
            "All section 47 enquiries in the six months before the inspection.
            This includes open S47 enquiries yet to reach a decision where possible.
            Where a child has been the subject of multiple section 47 enquiries within 
            the period, please provide one row for each enquiry."

Author: D2I
Last Modified Date: 06/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1
            1.0: syntax/fieldname fixes JH
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cp_plans
- ssd_disability
- ssd_immigration_status
- ssd_person
=============================================================================
*/

-- 
-- ??? - StartDate	NoCPConference	CPDate	CPPlan	CountS47s12m1	CountICPCs12m	EndDate	StepOutcomeDesc	FinalOutcome1

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_5_s47_enquiries') IS NOT NULL DROP TABLE #AA_5_s47_enquiries ;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    CONVERT(VARCHAR, p.pers_dob, 103)           AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    

    /* List additional AA fields */

    d.disa_disability_code                                                  AS Disability,        -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    /* Returns fields */
    s47e.s47e_s47_enquiry_id                                                AS ENQUIRY_ID,
    CONVERT(VARCHAR, s47e.s47e_s47_start_date, 103)                         AS S47_ENQUIRY_START_DATE,  -- Strategy discussion initiating Section 47 Enquiry Start Date

    JSON_VALUE(s47e.s47e_s47_outcome_json, '$.OUTCOME_CP_CONFERENCE_FLAG')  AS CP_CONF_NEEDED,   -- Was an Initial Child Protection Conference deemed unnecessary?,
    CONVERT(VARCHAR, icpc.icpc_icpc_date, 103)                              AS CP_CONF_DATE,     -- Date of Initial Child Protection Conference

    -- [TESTING] 
    -- THESE FIELDS NEED CONFIRMNING
    -- CP_CONF FORMAT(s47e.icpc_date, 'dd/MM/yyyy') AS formatted_icpc_date,     -- 
    icpc.icpc_icpc_outcome_cp_flag                  AS CP_CONF_OUTCOME_CP,      -- Did the Initial Child Protection Conference Result in a Child Protection Plan

    /* Aggregate fields */
    agg.CountS47s12m,               -- Sum of Number of Section 47 Enquiries in the last 12 months (NOT INCL. CURRENT)
    agg_icpc.CountICPCs12m,         -- Sum of Number of ICPCs in the last 12 months  (NOT INCL. CURRENT)


    -- [TESTING]
    -- check/update icpc table extract, 
    -- if have icpc then take that data, else s47 dets.
    s47e.s47e_s47_completed_by_team                 AS ALLOCATED_TEAM,
    s47e.s47e_s47_completed_by_worker               AS ALLOCATED_WORKER
    
    -- -- or is it... 
    -- -- [TESTING]
    -- icpc.icpc_icpc_team                             AS ALLOCATED_TEAM,        
    -- icpc.icpc_icpc_worker_id                        AS ALLOCATED_WORKER
 
INTO #AA_5_s47_enquiries 

FROM
    #ssd_s47_enquiry s47e

INNER JOIN
    #ssd_person p ON s47e.s47e_person_id = p.pers_person_id

-- [TESTING]
-- towards icpc.icpc_icpc_outcome_cp_flag 
LEFT JOIN #ssd_initial_cp_conference icpc ON s47e.s47e_s47_enquiry_id = icpc.icpc_s47_enquiry_id

LEFT JOIN   -- ensure we get all records even if there's no matching Disability
    #ssd_disability d ON p.pers_person_id = d.disa_person_id

LEFT JOIN (
    SELECT
    /* section 47 enquiries the child has been the subject of within 
    the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
        s47e_person_id,
        COUNT(s47e_s47_enquiry_id) - 1 as CountS47s12m
    FROM
        #ssd_s47_enquiry 
    WHERE
        s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE())
        
    GROUP BY
        s47e_person_id
) as agg ON s47e.s47e_person_id = agg.s47e_person_id

LEFT JOIN (
    SELECT
    /*initial child protection conferences the child has been the subject of 
    in the 12 months before their latest Section 47 enquiry.*/
        icpc.icpc_person_id,
        COUNT(icpc.icpc_s47_enquiry_id) as CountICPCs12m
    FROM
        #ssd_initial_cp_conference icpc

    INNER JOIN #ssd_s47_enquiry s47e ON icpc.icpc_s47_enquiry_id = s47e.s47e_s47_enquiry_id
    WHERE
        s47e.s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE()) -- [TESTING] is this s47_start_date OR icpc_icpc_transfer_in
        AND (icpc.icpc_icpc_date IS NOT NULL AND icpc.icpc_icpc_date <> '')
    GROUP BY
        icpc.icpc_person_id
        
) agg_icpc ON s47e.s47e_person_id = agg_icpc.icpc_person_id


WHERE
    s47e.s47e_s47_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- join the ssd S47 and ICPC tables using Referral_ID you will get the ICPC information related to each S47 Enquiry 


-- -- [TESTING]
-- select * from #AA_5_s47_enquiries;






/* 
=============================================================================
Report Name: Ofsted List 6 - Children in Need YYYY
Description: 
            "All those in receipt of services as a child in need at the point 
            of inspection or in the six months before the inspection.
            This list does not include care leavers or children who are only 
            the subject of a referral."

Author: D2I
Last Modified Date: 06/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1
            1.0 chges to use of cin episodes over cp.cinp_cin.... JH
            0.3: Removed old obj/item naming. RH
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cin_episodes
- ssd_disability
- ssd_person
- ssd_cla_episodes
- ssd_cin_plans
- ssd_cp_plans
- ssd_assessments
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_6_children_in_need') IS NOT NULL DROP TABLE #AA_6_children_in_need;


SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    
    /* List additional AA fields */
    d.disa_disability_code                      AS Disability, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    -- Removed 060224 
    -- cp.cinp_cin_plan_id,
    -- cp.cinp_cin_plan_start,
    -- cp.cinp_cin_plan_end,

    -- Replace with
    ce.cine_referral_id             AS REFERRAL_ID,
    ce.cine_referral_date           AS CIN_START_DATE,
    ce.cine_close_date,             AS CIN_CLOSE_DATE,
    ce.cine_close_reason            AS CIN_CLOSE_REASON,

    cp.cinp_cin_plan_team           AS ALLOCATED_TEAM,  -- most recent case worker|team. List incl. children with various types of plan, not just CIN plans
    cp.cinp_cin_plan_worker_id      AS ALLOCATED_WORKER,

    /* case_status */
    CASE 
        WHEN ce.cla_epi_start < GETDATE() AND (ce.cla_epi_ceased IS NULL OR ce.cla_epi_ceased = '') 
        THEN 'Looked after child'
        WHEN cpp.cpp_start_date < GETDATE() AND cpp.cpp_end_date IS NULL
        THEN 'Child Protection plan'
        WHEN cp.cinp_cin_plan_start < GETDATE() AND cp.cin_plan_end IS NULL
        THEN 'Child in need plan'
        WHEN asm.cina_assessment_start_date < GETDATE() AND asm.asmt_auth_date IS NULL
        THEN 'Open Assessment'
        WHEN ce.clae_cla_episode_ceased     > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR -- chk db handling of empty strings and nulls is consistent
             cpp.cppl_cp_plan_end_date      > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR 
             cp.cinp_cin_plan_end           > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE()) OR
             asm.cina_assessment_auth_date  > DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE())
        THEN 'Closed episode'
        ELSE NULL 
    END                               AS CASE_STATUS

INTO #AA_6_children_in_need

FROM
    #ssd_cin_plans cp

INNER JOIN
    #ssd_person p ON cp.cinp_person_id = p.pers_person_id

LEFT JOIN   -- with Disability
    #ssd_disability d ON cp.cinp_person_id = d.disa_person_id

LEFT JOIN   -- cla_episodes to get the most recent cla_epi_start
    (
        SELECT clae_person_id, MAX(clae_cla_episode_start) as clae_cla_episode_start, clae_cla_episode_ceased
        FROM #ssd_cla_episodes
        GROUP BY clae_person_id, clae_cla_episode_ceased
    ) AS ce ON p.pers_person_id = ce.clae_person_id

LEFT JOIN   -- cp_plans to get the cpp_start_date and cpp_end_date
    (
        SELECT cppl_person_id , MAX(cppl_cp_plan_start_date) as cppl_cp_plan_start_date, cppl_cp_plan_end_date
        FROM #ssd_cp_plans
        GROUP BY cppl_person_id, cppl_cp_plan_end_date
    ) AS cpp ON p.pers_person_id = cpp.cppl_person_id 

LEFT JOIN   -- joining with assessments to get the cina_assessment_start_date and cina_assessment_auth_date
    #ssd_cin_assessments asm ON p.pers_person_id = asm.cina_person_id 

WHERE
    ce.cine_referral_date >= DATEADD(MONTH, -@AA_ReportingPeriod , GETDATE());


-- -- [TESTING]
-- select * from #AA_6_children_in_need;





/* 
=============================================================================
Report Name: Ofsted List 7: Child protection
Description: 
            "All those who are the subject of a child protection plan at the 
            point of inspection. Include those who ceased to be the subject of 
            a child protection plan in the six months before the inspection."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_7_child_protection') IS NOT NULL DROP TABLE #AA_7_child_protection;

/* AA headings from sample for dev ref only
Does the Child have a Disability
Child Protection Plan Start Date
Initial Category of Abuse
Latest Category of Abuse
Date of the Last Statutory Visit
Was the Child Seen Alone?
Date of latest review conference
Child Protection Plan End Date
Subject to Emergency Protection Order or Protected Under Police Powers in Last Six Months (Y/N)
Sum of Number of Previous Child Protection Plans
Allocated Team
Allocated Worker

*/


SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth,
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age
    

    /* List additional AA fields */
    d.disa_disability_code                      AS Disability, -- (Have seen data such as : a)Yes/b)No but also Y/N (*should we chk&clean this to just Y/N*)
    
    /* Returns fields */   
    -- Replaced 060224 JH
    cpp.cppl_cp_plan_start_date	        AS	CP_START_DATE,		--Child Protection Plan Start Date
    cpp.cppv_cp_visit_date	            AS	CP_VISIT_DATE,		--Date of the Last Statutory Visit
    cpp.cppv_cp_visit_seen_alone	    AS	CP_SEEN_ALONE,		--Was the Child Seen Alone?
    cpp.cppr_cp_review_date	            AS	CP_REVIEW_DATE,		--Date of latest review conference
    cpp.cppl_cp_plan_end_date	        AS	CP_PLAN_END_DATE,	--Child Protection Plan End Date


    /* Check if Emergency Protection Order exists within last 6 months */
    CASE WHEN ls.legal_status_id IS NOT NULL THEN 'Y' ELSE 'N' END AS emergency_protection_order,

    /* New fields for category of abuse */
    -- MIN(CASE WHEN cpp.cpp_start_date = coa_early.cpp_earliest_date THEN coa_early.cpp_category END) AS INIT_ABUSE_CAT,
    -- MIN(CASE WHEN cpp.cpp_start_date = coa_latest.cpp_latest_date THEN coa_latest.cpp_category END) AS LATEST_ABUSE_CAT
    -- OR is it
    cpp.cppl_cp_plan_initial_category	AS	INIT_ABUSE_CAT		--Initial Category of Abuse
    cpp.cppl_cp_plan_latest_category	    AS	LATEST_ABUSE_CAT	--Latest Category of Abuse

    -- allocated team -- Use ssd_Involvements table for latest allocated team
    -- allocated worker -- Use ssd_Involvements table for latest allocated case worker
    


INTO #AA_7_child_protection

FROM
    #ssd_cin_visits cv

-- dev notes:
-- Some/all of these joins (might)need redoing since the release 2 changes/ object renaming (ssd_ xxx )
-- some of these joins potentially no longer required
-- ssd_cin_visits now has cinv_person_id field back in the object (prev spec had removed it)
INNER JOIN
    #ssd_person p ON cv.cinv_person_id = p.pers_person_id

LEFT JOIN   -- with Disability
    #ssd_disability d ON cv.cinv_person_id = d.disa_person_id

INNER JOIN
    #ssd_cin_episodes ce ON cv.cinv_person_id = ce.cine_person_id

LEFT JOIN
    #ssd_legal_status ls ON cv.cinv_person_id = ls.pers_person_id 
        AND ls.legal_status_start >= DATEADD(MONTH, -6, GETDATE())	/*PW - amended from '>= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH)'*/

LEFT JOIN
    #ssd_cp_plans cpp ON cv.cinv_person_id = cpp.cppl_person_id

LEFT JOIN
    #category_of_abuse coa_early ON cpp.cp_plan_id = coa_early.cp_plan_id

    AND coa_early.cpp_start_date = (
        SELECT MIN(cpp_start_date) FROM cp_plans WHERE cppl_person_id = cv.cinv_person_id
    )
LEFT JOIN
    #category_of_abuse coa_latest ON cpp.cp_plan_id = coa_latest.cp_plan_id

    AND coa_latest.cpp_start_date = (
        SELECT MAX(cpp_start_date) FROM cp_plans WHERE cppl_person_id = cv.la_person_id
    )

WHERE
    cv.cinv_cin_visit_date >= DATEADD(MONTH, -12, GETDATE()) -- /*PW - Amended from 'DATE_ADD(CURRENT_DATE, INTERVAL -12 MONTH)'*/

GROUP BY
    p.pers_person_id,
    p.pers_sex,
    p.pers_gender,

    -- to do
    p.pers_ethnicity,
    p.pers_dob,
    d.person_disability,
    cv.cinv_cin_visit_id,
    cv.cinv_cin_plan_id,
    cv.cinv_cin_visit_date,
    cv.cinv_cin_visit_seen,
    cv.cinv_cin_visit_seen_alone,
    cp.cin_team,
    cp.cin_worker_id,
    ce.cin_ref_team,
    ce.cin_ref_worker_id,
    ls.legal_status_id;




/* 
=============================================================================
Report Name: Ofsted List 8 - Children in Care YYYY
Description: 
            "All children in care at the point of inspection. Include all 
            those children who ceased to be looked after in the six months 
            before the inspection."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cp_plans
- ssd_disability
- ssd_immigration_status
- ssd_person
- cla_episode
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_8_children_in_care') IS NOT NULL DROP TABLE #AA_8_children_in_care;


SELECT
    /* Common AA fields */

    p.pers_legacy_id                            AS ChildUniqueID,
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth, --  note: returns string representation of the date
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age

    /* List additional AA fields */

    d.disa_disability_code                  AS Disability,          -- Disability1
    i.immi_immigration_status               AS UASC12mth ,          -- UASC12mth (if had imm.status 'Unaccompanied Asylum Seeking Child' active in prev 12 months)

-- in progress (comment headings direct from AA guidance)
clae.clae.clae_cla_episode_start            AS StartDateRecentCareEpisode,   -- StartDateRecentCareEpisode??
clae.clae_cla_primary_need                  AS CategoryOfNeed,               -- CategoryOfNeed
-- SecondOrSubsequentEpisodeStart
i.immi_immigration_status_start_date        AS LegalStatusStart             -- LegalStatusStart
i.immi_immigration_status                   AS LegalStatus                  -- LegalStatus
-- DateOfLastReview
-- DateOfLastVisit
-- PermanencePlan

clae.clae_cla_review_last_iro_contact_date  AS DateOfLastVisit,             -- DateOfLastIROVisit
clah.clah_health_check_date                 AS LastHealthAssessment,        -- LastHealthAssessment (most recent date regardless of type)
clah.clah_health_check_date                 AS LastDentalAssessment,        -- LastDentalAssessment (most recent where clah_health_check_type==dentist)
clap_cla_placement_start_date               AS NumberOfPlacements12Mths,    -- NumberOfPlacements12Mths (assumed that return to same provider still==placementCount+1)
clae.clae_cla_episode_cease_reason          AS DateCeasedLAC,               -- DateCeasedLAC
clae.clae_cla_episode_ceased                AS ReasonCeasedLAC,             -- ReasonCeasedLAC
clap.clap_cla_placement_start_date          AS LatestPlacementStartDate,    -- LatestPlacementStartDate
clap.clap_cla_placement_type                AS PlacementType,               -- PlacementType
clap.clap_cla_placement_provider            AS PlacementProvider,           -- PlacementProvider
clap.clap_cla_placement_postcode            AS PlacementPostcode,           -- PlacementPostcode
clap.clap_cla_placement_urn                 AS URN,                         -- OfstedURN
                                            -- AS PlacementLocation,-- PlacementLocation
lapp.lapp_previous_permanence_la            AS LocalAuthorityOfPlacement,   -- LocalAuthorityOfPlacement
                                            -- AS NumberOfMissingEpisodes12M, -- NumberOfMissingEpisodes12M
                                            -- AS NumberOfAbsentEpisodes12M -- NumberOfAbsentEpisodes12M
miss.miss_missing_rhi_offered               AS ReturnInterviewOffered,      -- ReturnInterviewOffered
miss.miss_missing_rhi_accepted              AS ReturnInterviewCompleted,    -- ReturnInterviewCompleted
-- AllocatedTeam
-- AllocatedWorker


 -- dev notes
    -- open cla_episiode, or episode ceased in last 6mths
    -- overall lac episode, ... ? 

-- -- Ref. additional fields available on ssd_cla_episodes
--     clae_cla_episode_id                 NVARCHAR(48) PRIMARY KEY,
--     clae_person_id                      NVARCHAR(48),
--     clae_cla_id                         NVARCHAR(48),
--     clae_referral_id                    NVARCHAR(48),

-- -- Ref. additional fields available on ssd_cla_placement
    -- -- do we also need to consider cp in this list? 
-- clap_cla_placement_id
-- clap_cla_episode_id
-- clap_cla_placement_start_date
-- clap_cla_placement_type
-- clap_cla_placement_urn
-- clap_cla_placement_distance
-- clap_cla_id (fk to ssd_cla_episodes.clae_cla_id)
-- clap_cla_placement_provider
-- clap_cla_placement_postcode
-- clap_cla_placement_end_date
-- clap_cla_placement_change_reason

-- -- Ref. additional fields available on ssd_cla_health
-- clah_person_id (fk to ssd_cla_episodes.clae_person_id)
-- clah_health_check_type
-- clah_health_check_date
-- clah_health_check_status

-- -- Ref. additional fields available on ssd_cla_previous_permanence
-- lapp_person_id (fk to ssd_cla_episodes.clae_person_id)
-- lapp_previous_permanence_order_date
-- lapp_previous_permanence_option
-- lapp_previous_permanence_la

-- -- Ref. additional fields available on ssd_missing
-- miss_missing_rhi_offered
-- miss_missing_rhi_accepted

-- -- Ref. additional fields available on ssd_immigration_status
-- immi_person_id (fk to ssd_person.pers_person_id)
-- immi_Immigration_status_id
-- immi_immigration_status
-- immi_immigration_status_start_date
-- immi_immigration_status_end_date


INTO #AA_8_children_in_care

FROM
    #ssd_cla_episodes   clae
    #ssd_cla_health     clah
    #ssd_cla_placement  clap
    #ssd_cla_previous_permanence    lapp

INNER JOIN
    ssd_person p ON clae.clae_person_id = p.pers_person_id

LEFT JOIN   -- Disability table
    ssd_disability d ON clae.clae_person_id = d.disa_person_id

LEFT JOIN   -- immigration_status table (UASC)
    ssd_immigration_status i ON clae.clae_person_id = i.immi_person_id


-- [TESTING]
select * from #AA_8_children_in_care;




/* 
=============================================================================
Report Name: Ofsted List 9 -  Leaving Care Services YYYY
Description: 
            "All those who have reached the threshold for receiving leaving 
            care services at the point of inspection (entitled children).Includes:
            Relevant children, Former relevant children, Qualifying care leaver
            Eligible children"

Author: D2I
Last Modified Date: 13/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_immigration_status
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_9_care_leavers') IS NOT NULL DROP TABLE #AA_9_care_leavers;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                            AS ChildUniqueID,	-- temp solution [TESTING] This liquid logic specific
    p.pers_person_id						    AS ChildUniqueID2,	-- temp solution [TESTING] This for compatiblility in non-ll systems
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth, --  note: returns string representation of the date
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age

    /* List additional AA fields */

    d.disa_disability_code                      AS Disability           -- Does the Child have a Disability
    CASE         
        -- Unaccompanied Asylum Seeking Child (UASC), or formerly UASC if 18 or over (Y/N)                                               
        WHEN latest_status.immi_immigration_status = 'Unaccompanied Asylum Seeking Child (UASC)' THEN 'Y'
        ELSE 'N'
    END                                         AS LegalStatus,         

    clea.clea_care_leaver_allocated_team_name   AS AllocatedTeam,       -- Allocated Team
    clea.clea_care_leaver_worker_name           AS AllocatedWorker,     -- Allocated Worker
    clea.clea_care_leaver_personal_advisor      AS AllocatedPA,         -- Allocated Personal Advisor
    clea.clea_care_leaver_eligibility           AS EligibilityCategory, -- Eligibility Category
    clea.clea_care_leaver_in_touch              AS InTouch,             -- LA In Touch 
    clea.clea_pathway_plan_review_date          AS ReviewDate,          -- Latest Pathway Plan Review Date
    clea.clea_care_leaver_latest_contact        AS LatestContactDate,   -- Latest Date of Contact
    clea.clea_care_leaver_accommodation         AS AccomodationType,    -- Type of Accommodation
    clea.clea_care_leaver_accom_suitable        AS AccommodationSuitability, -- Suitability of Accommodation
    clea.clea_care_leaver_activity              AS ActivityStatus       -- Activity Status


INTO #AA_9_care_leavers

FROM
    #ssd_care_leavers clea

LEFT JOIN   -- person table for core dets
    ssd_person p ON clea.clea_person_id = p.pers_person_id

LEFT JOIN   -- Disability table
    ssd_disability d ON clea.clea_person_id = d.disa_person_id

LEFT JOIN   -- join but with subquery as need most recent immigration status
    (
        SELECT 
            immi_person_id,
            immi_immigration_status,
            -- partitioning by immi_person_id (group by each person) 
            ROW_NUMBER() OVER (PARTITION BY immi_person_id -- assign unique row num (most recent rn ===1)
            -- get latest status based on end date, (using start date as a secondary order in case of ties or NULL end dates)
            ORDER BY immi_immigration_status_end DESC, immi_immigration_status_start DESC) AS rn
        FROM 
            ssd_immigration_status
    ) latest_status ON clea.clea_person_id = latest_status.immi_person_id AND latest_status.rn = 1;



/* 
=============================================================================
Report Name: Ofsted List 10 - Adoption YYYY
Description: 
            "All those children who, in the 12 months before the inspection, 
            have: been adopted, had the decision that they should be placed 
            for adoption but they have not yet been adopted, had an adoption 
            decision reversed during the 12 months."

Author: D2I
Last Modified Date: 13/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_immigration_status
- ssd_permanence 
- ssd_family
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_10_adoption') IS NOT NULL DROP TABLE #AA_10_adoption;


-- -- AA headers guidance notes:
-- Child Unique ID
-- Family identifier
-- Gender
-- Ethnicity
-- Date of Birth
-- Age of Child (Years)
-- Does the Child have a Disability
-- Date the Child Entered Care
-- Date of Decision that Child Should be Placed for Adoption
-- Date of Placement Order
-- Date of Matching Child and Prospective Adopters
-- Date Placed for Adoption
-- Date of Adoption Order 
-- Date of Decision that Child Should No Longer be Placed for Adoption
-- Reason Why Child No Longer Placed for Adoption
-- Date the child was placed for fostering in FostingForAdoption or concurrent planning placement


SELECT
    /* Common AA fields */

    p.pers_legacy_id                            AS ChildUniqueID,	    -- temp solution [TESTING] This liquid logic specific
    p.pers_person_id						    AS ChildUniqueID2,	    -- temp solution [TESTING] This for compatiblility in non-ll systems
    fam.fami_family_id                          AS FamilyIdentifier,    -- Family identifier        
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth, --  note: returns string representation of the date
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age

    /* List additional AA fields */

    d.disa_disability_code                      AS Disability 

    perm.perm_entered_care_date              AS EnteredCareDate,        -- Date the Child Entered Care
    perm.perm_ffa_cp_decision_date           AS FfaDecisionDate,        -- Date the child was placed for fostering in FostingForAdoption or concurrent planning placement 
    perm.perm_placement_order_date           AS PlacementDecisionDate,  -- Date of Decision that Child Should be Placed for Adoption
    perm.perm_placed_for_adoption_date       AS PlacedForAdoptionDate,  -- Date Placed for Adoption
    perm.perm_matched_date                   AS MatchedForAdoptionDate, -- Date of Matching Child and Prospective Adopters
    perm.perm_decision_reversed_date         AS DecisionReversedDate,   -- Date of Decision that Child Should No Longer be Placed for Adoption
    perm.perm_placed_foster_carer_date       AS PlacedWithFosterCarer,  -- Date of Adoption Order ?  
    perm.perm_decision_reversed_reason       AS DecisionReversedReason, -- Reason Why Child No Longer Placed for Adoption
    perm.perm_permanence_order_date          AS PlacementOrderDate      -- Date of Placement Order?


INTO #AA_10_adoption

FROM
    #ssd_permanence perm

LEFT JOIN   -- person table for core dets
    #ssd_person p ON perm.perm_person_id = p.pers_person_id

LEFT JOIN   -- disability table
    #ssd_disability d ON perm.perm_person_id = d.disa_person_id

LEFT JOIN   -- family table
    #ssd_family fam ON perm.perm_person_id = fam.fami_person_id

WHERE
    -- Filter on last 12 months
    perm.perm_placement_order_date          >= DATEADD(MONTH, -12, GETDATE())
    OR perm.perm_placed_for_adoption_date   >= DATEADD(MONTH, -12, GETDATE())
    OR perm.perm_decision_reversed_date     >= DATEADD(MONTH, -12, GETDATE());


    -- not required in return? Other available fields for ref:
    -- perm.perm_table_id
    -- perm.perm_person_id
    -- perm.perm_cla_id
    -- perm.perm_adm_decision_date         AS ,
    -- perm.perm_permanence_order_type     AS ,
    -- perm.perm_adoption_worker           AS ,
    -- perm.perm_adopter_sex               AS ,
    -- perm.perm_adopter_legal_status      AS ,
    -- perm.perm_part_of_sibling_group     AS ,
    -- perm.perm_siblings_placed_together  AS ,
    -- perm.perm_siblings_placed_apart     AS ,
    -- perm.perm_placement_provider_urn    AS ,
    -- perm.perm_adopted_by_carer_flag     AS ,
    -- perm.perm_placed_ffa_cp_date        AS ,




/* 
=============================================================================
Report Name: Ofsted List 11 - Adopters YYYY
Description: 
            "All those individuals who in the 12 months before the inspection 
            have had contact with the local authority adoption agency"

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Incomplete as required data not held within the SSD. Placeholders used
         in place of data points considered beyond project scope. 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_permanence 
- ssd_family
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_11_adopters') IS NOT NULL DROP TABLE #AA_11_adopters;

SELECT
    /* Common AA fields */
    'PLACEHOLDER_DATA'                          AS AdopterIdentifier,          -- Individual adopter identifier (Unavailable in SSD V1)
    fam.fami_family_id                          AS FamilyIdentifier,    -- Family identifier        
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END											AS Gender,
    CASE
		WHEN p.pers_ethnicity = 'WBRI' THEN 'a) WBRI'
		WHEN p.pers_ethnicity = 'WIRI' THEN 'b) WIRI'
		WHEN p.pers_ethnicity = 'WIRT' THEN 'c) WIRT'
		WHEN p.pers_ethnicity = 'WOTH' THEN 'd) WOTH'
		WHEN p.pers_ethnicity = 'WROM' THEN 'e) WROM'
		WHEN p.pers_ethnicity = 'MWBC' THEN 'f) MWBC'
		WHEN p.pers_ethnicity = 'MWBA' THEN 'g) MWBA'
		WHEN p.pers_ethnicity = 'MWAS' THEN 'h) MWAS'
		WHEN p.pers_ethnicity = 'MOTH' THEN 'i) MOTH'
		WHEN p.pers_ethnicity = 'AIND' THEN 'j) AIND'
		WHEN p.pers_ethnicity = 'APKN' THEN 'k) APKN'
		WHEN p.pers_ethnicity = 'ABAN' THEN 'l) ABAN'
		WHEN p.pers_ethnicity = 'AOTH' THEN 'm) AOTH'
		WHEN p.pers_ethnicity = 'BCRB' THEN 'n) BCRB'
		WHEN p.pers_ethnicity = 'BAFR' THEN 'o) BAFR'
		WHEN p.pers_ethnicity = 'BOTH' THEN 'p) BOTH'
		WHEN p.pers_ethnicity = 'CHNE' THEN 'q) CHNE'
		WHEN p.pers_ethnicity = 'OOTH' THEN 'r) OOTH'
		WHEN p.pers_ethnicity = 'REFU' THEN 's) REFU'
		WHEN p.pers_ethnicity = 'NOBT' THEN 't) NOBT'
		ELSE 't) NOBT' /*PW - 'Catch All' for any other Ethnicities not in above list; could also be 'r) OOTH'*/
	END											AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth, --  note: returns string representation of the date
    CASE 
        WHEN p.pers_dob IS NULL OR p.pers_dob > GETDATE() THEN -1 -- no dob? unborn dob? assign default val
                                            
        ELSE DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
        -- if a dob is available and not in the future 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR, DATEDIFF(YEAR, p.pers_dob, GETDATE()), p.pers_dob)
                -- use DATEDIFF get diff(yrs) btwn dob & curr date, adjust down by 1 if today is before this year's b-day
                THEN 1
                ELSE 0
            END
    END                                         AS Age

    /* List additional AA fields */
    d.disa_disability_code                      AS Disability,     

    perm.perm_adopted_by_carer_flag             AS AdoptedByCarer,      -- Is the (prospective) adopter fostering for adoption?
    '1900-01-01'                                AS EnquiryDate,         -- Date enquiry received
    '1900-01-01'                                AS Stage1StartDate,     -- Date Stage 1 started
    '1900-01-01'                                AS Stage1EndDate,       -- Date Stage 1 ended
    '1900-01-01'                                AS Stage2StartDate,     -- Date Stage 2 started
    '1900-01-01'                                AS Stage2EndDate,       -- Date Stage 2 ended
    '1900-01-01'                                AS ApplicationDate,     -- Date application submitted
    '1900-01-01'                                AS ApplicationApprDate, -- Date application approved
    perm.perm_matched_date                      AS MatchedDate,         -- Date adopter matched with child(ren)
    perm.perm_placed_for_adoption_date          AS PlacedDate,          -- Date child/children placed with adopter(s)
    'PLACEHOLDER_DATA'                          AS NumSiblingsPlaced,   -- No. of children placed
    perm.perm_permanence_order_date             AS AdoptionOrderDate,   -- Date of Adoption Order
    perm.perm_decision_reversed_date            AS AdoptionLeaveDate,   -- Date of leaving adoption process
    perm.perm_decision_reversed_reason          AS AdoptingLeaveReason  -- Reason for leaving adoption process

INTO #AA_11_adopters

FROM
    #ssd_permanence perm

INNER JOIN
    #ssd_person p ON perm.perm_person_id = p.pers_person_id

LEFT JOIN   -- Disability table
    #ssd_disability d ON perm.perm_person_id = d.disa_person_id

LEFT JOIN
    #ssd_contacts c ON perm.perm_person_id = c.cont_person_id 

LEFT JOIN   -- family table
    #ssd_family fam ON perm.perm_person_id = fam.fami_person_id

WHERE
    c.cont_contact_start >= DATEADD(MONTH, -12, GETDATE()) -- Filter on last 12 months
