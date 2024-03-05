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
Last Modified Date: 29/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
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
    p.pers_person_id							AS ChildUniqueID,
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
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END									AS Age,

    /* List additional AA fields */
    FORMAT(c.cont_contact_date, 'dd/MM/yyyy')  AS DateOfContact,
	CASE
		WHEN c.cont_contact_source_code = '1A' THEN 'a) 1A: Individual'
		WHEN c.cont_contact_source_code = '1B' THEN 'b) 1B: Individual'
		WHEN c.cont_contact_source_code = '1C' THEN 'c) 1C: Individual'
		WHEN c.cont_contact_source_code = '1D' THEN 'd) 1D: Individual'
		WHEN c.cont_contact_source_code = '2A' THEN 'e) 2A: Schools'
		WHEN c.cont_contact_source_code = '2B' THEN 'f) 2B: Education services'
		WHEN c.cont_contact_source_code = '3A' THEN 'g) 3A: Health services'
		WHEN c.cont_contact_source_code = '3B' THEN 'h) 3B: Health services'
		WHEN c.cont_contact_source_code = '3C' THEN 'i) 3C: Health services'
		WHEN c.cont_contact_source_code = '3D' THEN 'j) 3D: Health services'
		WHEN c.cont_contact_source_code = '3E' THEN 'k) 3E: Health services'
		WHEN c.cont_contact_source_code = '3F' THEN 'l) 3F: Health services'
		WHEN c.cont_contact_source_code = '4' THEN 'm) 4: Housing'
		WHEN c.cont_contact_source_code = '5A' THEN 'n) 5A: LA services'
		WHEN c.cont_contact_source_code = '5B' THEN 'o) 5B: LA services'
		WHEN c.cont_contact_source_code = '5C' THEN 'p) 5C: LA services'
		WHEN c.cont_contact_source_code = '5D' THEN 'p1) 5D: LA services'
		WHEN c.cont_contact_source_code = '6' THEN 'q) 6: Police'
		WHEN c.cont_contact_source_code = '7' THEN 'r) 7: Other legal agency'
		WHEN c.cont_contact_source_code = '8' THEN 's) 8: Other'
		WHEN c.cont_contact_source_code = '9' THEN 't) 9: Anonymous'
		WHEN c.cont_contact_source_code = '10' THEN 'u) 10: Unknown'
		ELSE 'u) 10: Unknown' /*PW - 'Catch All' for any other Contact/Referral Sources not in above list*/
	END											AS ContactSource

    -- Step type (or is that abaove source?) (SEE ALSO ASSESSMENTS L4)
    -- Responsible Team
    -- Assigned Worker

INTO #AA_1_contacts

FROM
    #ssd_contact c

LEFT JOIN
    #ssd_person p ON c.cont_person_id = p.pers_person_id

WHERE
    c.cont_contact_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());



-- [TESTING]
select * from #AA_1_contacts;




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

/*
11/02/2024 - PW Comment
Possible disconnect between SSDS Dataset and Annex A.
Annex A refers to Early Help Assessments whereas SSDS interpreted (perhaps incorrectly) as Early Help Episodes
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_2_early_help_assessments') IS NOT NULL DROP TABLE #AA_2_early_help_assessments;


SELECT
    /* Common AA fields */
    p.pers_person_id							AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
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
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END									AS Age,
    
    /* List additional AA fields */
    FORMAT(e.earl_episode_start_date, 'dd/MM/yyyy')	AS AssessmentStartDate,          -- [TESTING] Need a col name change?
    FORMAT(e.earl_episode_end_date, 'dd/MM/yyyy')	AS AssessmentCompletionDate,            -- [TESTING] Need a col name change?
    e.earl_episode_organisation						AS OrganisationCompletingAssessment    -- [TESTING] Need a col name change?

INTO #AA_2_early_help_assessments

FROM
    #ssd_early_help_episodes e	/*PW # added to start of table name*/

LEFT JOIN
    #ssd_person p ON e.earl_person_id = p.pers_person_id	/*PW # added to start of table name*/

WHERE
    /*PW - previous selection criteria commented out*/
	--(
    --    /* eh_epi_start_date is within the last 6 months, or earl_episode_end_date is within the last 6 months, 
    --    or eh_epi_end_date is null, or eh_epi_end_date is an empty string*/
    --    e.earl_episode_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())	/*PW - changed '6' to '@AA_ReportingPeriod'*/
    --OR
    --    (e.earl_episode_end_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR e.earl_episode_end_date IS NULL OR e.earl_episode_end_date = '')
    --);

	/*PW - suggested amendment to selection criteria - produces same results*/
	COALESCE(e.earl_episode_end_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- [TESTING]
select * from #AA_2_early_help_assessments;




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
    p.pers_person_id							AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
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
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END									AS Age,
    
    /* List additional AA fields */
    --ce.cine_referral_id						AS REFERRAL_ID,	/*PW - commented out as not in Annex A Specification*/
    FORMAT(ce.cine_referral_date, 'dd/MM/yyyy')	AS ReferralDate,
	CASE
		WHEN ce.cine_referral_source = '1A' THEN 'a) 1A: Individual'
		WHEN ce.cine_referral_source = '1B' THEN 'b) 1B: Individual'
		WHEN ce.cine_referral_source = '1C' THEN 'c) 1C: Individual'
		WHEN ce.cine_referral_source = '1D' THEN 'd) 1D: Individual'
		WHEN ce.cine_referral_source = '2A' THEN 'e) 2A: Schools'
		WHEN ce.cine_referral_source = '2B' THEN 'f) 2B: Education services'
		WHEN ce.cine_referral_source = '3A' THEN 'g) 3A: Health services'
		WHEN ce.cine_referral_source = '3B' THEN 'h) 3B: Health services'
		WHEN ce.cine_referral_source = '3C' THEN 'i) 3C: Health services'
		WHEN ce.cine_referral_source = '3D' THEN 'j) 3D: Health services'
		WHEN ce.cine_referral_source = '3E' THEN 'k) 3E: Health services'
		WHEN ce.cine_referral_source = '3F' THEN 'l) 3F: Health services'
		WHEN ce.cine_referral_source = '4' THEN 'm) 4: Housing'
		WHEN ce.cine_referral_source = '5A' THEN 'n) 5A: LA services'
		WHEN ce.cine_referral_source = '5B' THEN 'o) 5B: LA services'
		WHEN ce.cine_referral_source = '5C' THEN 'p) 5C: LA services'
		WHEN ce.cine_referral_source = '5D' THEN 'p1) 5D: LA services'
		WHEN ce.cine_referral_source = '6' THEN 'q) 6: Police'
		WHEN ce.cine_referral_source = '7' THEN 'r) 7: Other legal agency'
		WHEN ce.cine_referral_source = '8' THEN 's) 8: Other'
		WHEN ce.cine_referral_source = '9' THEN 't) 9: Anonymous'
		WHEN ce.cine_referral_source = '10' THEN 'u) 10: Unknown'
		ELSE 'u) 10: Unknown' /*PW - 'Catch All' for any other Contact/Referral Sources not in above list*/
	END											AS ReferralSource,
	CASE -- indicate if the most recent referral (or individual referral) resulted in 'No Further Action' (NFA)
        WHEN ce.cine_referral_nfa in ('Y','Yes','1') THEN 'a) Yes'		/*PW - changed 'NFA' to 'Y' and equivalents*/
        ELSE 'b) No'
    END											AS ReferralNFA,
    COALESCE(sub.count_12months, 0)				AS ReferralsLast12Months,	/*PW - field order changed to align with Annex A Specification*/
	
	/*PW Note - Have used Team and Worker that Referral was assinged to as per Annex A guidance
					However in Blackpool, all Contact/Referral WorkflowSteps are processed by the 'Front Door' (Request for Support Hub) with generic worker 'Referral Coordinator'
					Therefore Current / Latest Worker may provide better information (as with Annex A Lists 6-8).  This is the approach used in Blackpool*/
	ce.cine_referral_team						AS AllocatedTeam,
    ce.cine_referral_worker_name				AS AllocatedWorker

INTO #AA_3_referrals

FROM
    #ssd_cin_episodes ce

LEFT JOIN
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
    ) AS sub ON ce.cine_person_id = sub.cine_person_id

-- LEFT JOIN -- Removed as can access worker name on cin_episodes object
--     #ssd_professionals pro ON ce.cine_referral_worker_id = pro.prof_professional_id

WHERE
    ce.cine_referral_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());


-- [TESTING]
select * from #AA_3_referrals;




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
    p.pers_person_id										AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END														AS Gender,
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
	END													AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')					AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END											AS Age,

    /* List additional AA fields */
	--d.disa_disability_code							AS DISABILITY,	/*PW - Commented out at values changed to those in Annex A Specification*/ 
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END													AS HasDisability,
    FORMAT(a.cina_assessment_start_date, 'dd/MM/yyyy')	AS ContinuousAssessmentStart,
    CASE
		WHEN a.cina_assessment_child_seen = 'Yes' then 'a) Yes'
		ELSE 'b) No'
	END													AS ContinuousAssessmentChildSeen,
    FORMAT(a.cina_assessment_auth_date, 'dd/MM/yyyy')	AS ContinuousAssessmentAuthDate,
    --cina_assessment_outcome_json						AS REQU_SOCIAL_CARE_SUPPORT,	/*PW - Commented out as not in Annex A Specification*/ 
    --cina_assessment_outcome_nfa						AS ASMT_OUTCOME_NFA,	/*Commented out at values changed to those in Annex A Specification*/
	CASE
		WHEN a.cina_assessment_auth_date is NULL THEN NULL
		WHEN a.cina_assessment_outcome_nfa = 'No' THEN 'a) Yes'
		ELSE 'b) No'
	END													AS CSCSupportRequired,	/*PW - will depend on each Local Authority's interpretation of cina_assessment_outcome_nfa*/

    -- Step type (SEE ALSO CONTACTS)
    a.cina_assessment_team								AS AllocatedTeam,
    a.cina_assessment_worker_name						AS AllocatedWorker

INTO #AA_4_assessments

FROM
    #ssd_cin_assessments a

INNER JOIN
    #ssd_person p ON a.cina_person_id = p.pers_person_id

/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
    (
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

-- LEFT JOIN -- Removed as worker name available on ssd_cin_assessments
--     #ssd_professionals pro ON a.cina_assessment_worker_id = pro.prof_professional_id

WHERE
    --a.cina_assessment_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	/*Original criteria - Assessments starting in last 6 months*/
	COALESCE(a.cina_assessment_auth_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	/*PW amended criteria - Assessments open in last 6 months (includes those starting more that 6 months ago that were completed in last 6 months)*/


-- [TESTING]
select * from #AA_4_assessments;




/* 
=============================================================================
Report Name: Ofsted List 5 - Section 47 Enquiries and ICPC OC
Description: 
            "All section 47 enquiries in the six months before the inspection.
            This includes open S47 enquiries yet to reach a decision where possible.
            Where a child has been the subject of multiple section 47 enquiries within 
            the period, please provide one row for each enquiry."

Author: D2I
Last Modified Date: 30/01/24 RH
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
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_5_s47_enquiries') IS NOT NULL DROP TABLE #AA_5_s47_enquiries;


SELECT
    /* Common AA fields */
    p.pers_person_id								AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
    CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END												AS Gender,
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
	END												AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')				AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END										AS Age,

    /* List additional AA fields */
	--d.disa_disability_code						AS DISABILITY,	/*PW - Commented out at values changed to those in Annex A Specification*/ 
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END												AS HasDisability,
    
    /* Returns fields */
    --s47e.s47e_s47_enquiry_id						AS ENQUIRY_ID,	/*PW - Commented out as not in Annex A Specification*/
    FORMAT(s47e.s47e_s47_start_date, 'dd/MM/yyyy')	AS StratDiscussionDate,	-- Strategy discussion initiating Section 47 Enquiry Start Date		/*PW - field name changed from se.s47_start_date*/
    CASE																	-- Was an Initial Child Protection Conference deemed unnecessary?		/*PW - field changed from s47e.s47outcome*/
		WHEN s47e.s47e_s47_end_date is null then NULL
		WHEN s47e.s47e_s47_nfa = 'Yes' THEN 'a) Yes'
		WHEN s47e.s47e_s47_nfa = 'No' THEN 'b) No'
	END												AS InitialCPConfUnnecessary,
    FORMAT(icpc.icpc_icpc_date, 'dd/MM/yyyy')		AS InitialCPConfDate,	-- Date of Initial Child Protection Conference		/*PW - field name changed from se.s47_authorised_date*/

    -- [TESTING] 
    -- THESE FIELDS NEED CONFIRMNING
    -- CP_CONF FORMAT(s47e.icpc_date, 'dd/MM/yyyy')	AS formatted_icpc_date,     -- 
	CASE																			-- Did the Initial Child Protection Conference Result in a Child Protection Plan
		WHEN icpc.icpc_icpc_outcome_cp_flag = 'Y' THEN 'a) Yes'
		WHEN icpc.icpc_icpc_outcome_cp_flag = 'N' THEN 'b) No'
	END												AS CPConfResultInCPPlan,

    /* Aggregate fields */
    agg.CountS47s12m								AS NumberS47s12m,		-- Sum of Number of Section 47 Enquiries in the last 12 months (NOT INCL. CURRENT)
    agg_icpc.CountICPCs12m							AS NumberICPCs12m,		-- Sum of Number of ICPCs in the last 12 months  (NOT INCL. CURRENT)
	
   -- [TESTING]
    -- taking from s47 object in case the child has a Section 47 enquiry that <doesn't> lead to an ICPC
    s47e.s47e_s47_completed_by_team_name			AS AllocatedTeam,
    s47e.s47e_s47_completed_by_worker_name			AS AllocatedWorker
    -- -- the alternative exists as 
    -- icpc.icpc_icpc_team_name						AS AllocatedTeam,        
    -- icpc.icpc_icpc_worker_name					AS AllocatedWorker
 

INTO #AA_5_s47_enquiries 

FROM
    #ssd_s47_enquiry s47e	/*PW - # added to start of table name*/

INNER JOIN
    #ssd_person p ON s47e.s47e_person_id = p.pers_person_id		/*PW - # added to start of table name*/

/*PW - Added as #ssd_disability table not inmcluded; sub query as can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
    (
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

-- [TESTING]
-- towards icpc.icpc_icpc_outcome_cp_flag 
LEFT JOIN
	#ssd_initial_cp_conference icpc ON s47e.s47e_s47_enquiry_id = icpc.icpc_s47_enquiry_id	/*PW - # added to start of table name*/
										AND s47e.s47e_person_id = icpc.icpc_person_id		/*PW - additional join added because WorkflowStepID used as enquiry_id and this isn't unique due to group working*/

/*PW - Original Code commented out as calculates number of S47s in last 12 months, not number of S47s in 12 months before latest Section 47*/
/*
LEFT JOIN (
    SELECT
    /* section 47 enquiries the child has been the subject of within 
    the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
        s47e_person_id,
        COUNT(s47e_s47_enquiry_id) - 1 as CountS47s12m
    FROM
        ssd_s47_enquiry 
    WHERE
        s47e_s47_start_date >= DATEADD(MONTH, -12, GETDATE())
        
    GROUP BY
        s47e_person_id
) as agg ON s47e.s47e_person_id = agg.s47e_person_id
*/

LEFT JOIN 
	(
		SELECT
		/*section 47 enquiries the child has been the subject of within 
		the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
			s47e.s47e_person_id,
			s47e.s47e_s47_enquiry_id,
			COUNT(s47e2.s47e_s47_enquiry_id) as CountS47s12m,
			DENSE_RANK() OVER(PARTITION BY s47e.s47e_person_id ORDER BY s47e.s47e_s47_start_date DESC, s47e.s47e_s47_enquiry_id DESC) Rnk
		FROM
			#ssd_s47_enquiry s47e	/*PW - # added to start of table name*/
		LEFT JOIN
			#ssd_s47_enquiry s47e2 ON s47e.s47e_person_id = s47e2.s47e_person_id
				AND (s47e2.s47e_s47_start_date between DATEADD(MONTH, -12, s47e.s47e_s47_start_date) and DATEADD(DAY, -1, s47e.s47e_s47_start_date)
				OR (s47e2.s47e_s47_start_date = s47e.s47e_s47_start_date and s47e2.s47e_s47_enquiry_id < s47e.s47e_s47_enquiry_id))	/*PW - allows for cases where 2 S47s start on same day*/
		WHERE
			COALESCE(s47e.s47e_s47_end_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		GROUP BY
			s47e.s47e_person_id, s47e.s47e_s47_enquiry_id, s47e.s47e_s47_start_date
	) AS agg ON s47e.s47e_person_id = agg.s47e_person_id
		AND agg.Rnk = 1

/*PW - Original Code commented out as calculates number of ICPCs in last 12 months, not number of ICPCs in 12 months before latest Section 47*/
/*
LEFT JOIN (
    SELECT
    /*initial child protection conferences the child has been the subject of 
    in the 12 months before their latest Section 47 enquiry.*/
        icpc.icpc_person_id,
        COUNT(icpc.icpc_s47_enquiry_id) as CountICPCs12m
    FROM
        ssd_initial_cp_conference icpc

    INNER JOIN ssd_s47_enquiry s47e ON icpc.icpc_s47_enquiry_id = s47e.s47e_s47_enquiry_id
    WHERE
        s47e.s47_start_date >= DATEADD(MONTH, -12, GETDATE()) -- [TESTING] is this s47_start_date OR icpc_icpc_transfer_in
        AND (icpc.icpc_date IS NOT NULL AND icpc.icpc_date <> '')
    GROUP BY
        icpc.icpc_person_id
) agg_icpc ON s47e.s47e_person_id = agg_icpc.icpc_person_id
*/

LEFT JOIN 
	(
		SELECT
		/*section 47 enquiries the child has been the subject of within 
		the 12 months PRIOR(hence the -1) to their latest section 47 enquiry*/
			s47e.s47e_person_id,
			s47e.s47e_s47_enquiry_id,
			COUNT(icpc_icpc_date) as CountICPCs12m,
			DENSE_RANK() OVER(PARTITION BY s47e.s47e_person_id ORDER BY s47e.s47e_s47_start_date DESC, s47e.s47e_s47_enquiry_id DESC) Rnk
		FROM
			#ssd_s47_enquiry s47e	/*PW - # added to start of table name*/
		LEFT JOIN
			#ssd_initial_cp_conference icpc on s47e.s47e_person_id = icpc.icpc_person_id
			AND icpc_icpc_date between DATEADD(MONTH, -12, s47e.s47e_s47_start_date) and DATEADD(DAY, -1, s47e.s47e_s47_start_date)
		WHERE
			COALESCE(s47e.s47e_s47_end_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		GROUP BY
			s47e.s47e_person_id, s47e.s47e_s47_enquiry_id, s47e.s47e_s47_start_date
	) AS agg_icpc ON s47e.s47e_person_id = agg_icpc.s47e_person_id
		AND agg_icpc.Rnk = 1

WHERE
    --s47e.s47e_s47_start_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	/*Original criteria - S47 starting in last 6 months*/
	COALESCE(s47e.s47e_s47_end_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	/*PW amended criteria - S47 open in last 6 months (includes those starting more that 6 months ago that were completed in last 6 months)*/


-- [TESTING]
select * from #AA_5_s47_enquiries;




/* 
=============================================================================
Report Name: Ofsted List 6 - Children in Need YYYY
Description: 
            "All those in receipt of services as a child in need at the point 
            of inspection or in the six months before the inspection.
            This list does not include care leavers or children who are only 
            the subject of a referral."

Author: D2I
Last Modified Date: 31/01/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
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
	d.ChildUniqueID,
	d.Gender,
	d.Ethnicity,
	d.DateOfBirth,
	d.Age,
	d.HasDisability,
	d.CINStartDate,
	d.PrimaryNeedCode,
	d.DateChildLastSeen,
	d.CINClosureDate,
	d.ReasonForClosure,
	d.CaseStatus,
	d.AllocatedTeam,
	d.AllocatedWorker

INTO #AA_6_children_in_need

FROM
(
	SELECT
		/* Common AA fields */
		p.pers_person_id							AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
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
		FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

		/*PW - Blackpool Age Function*/
		DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
				CASE 
					WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
					THEN 1
					ELSE 0
				END									AS Age,

		/* List additional AA fields */
		--d.disa_disability_code					AS DISABILITY,	/*PW - Commented out at values changed to those in Annex A Specification*/ 
		CASE
			WHEN d.disa_person_id is not null THEN 'a) Yes'
			ELSE 'b) No'
		END											AS HasDisability,
		--cp.cinp_cin_plan_id,		/*PW - Commented out as not in Annex A Specification*/
		FORMAT(ce.cine_referral_date, 'dd/MM/yyyy')	AS CINStartDate,
		CASE
			WHEN ce.cine_cin_primary_need = 'N1' THEN 'N1 - Abuse or neglect'
			WHEN ce.cine_cin_primary_need = 'N2' THEN 'N2 - Child’s disability'
			WHEN ce.cine_cin_primary_need = 'N3' THEN 'N3 - Parental disability or illness'
			WHEN ce.cine_cin_primary_need = 'N4' THEN 'N4 - Family in acute stress'
			WHEN ce.cine_cin_primary_need = 'N5' THEN 'N5 - Family dysfunction'
			WHEN ce.cine_cin_primary_need = 'N6' THEN 'N6 - Socially unacceptable behaviour'
			WHEN ce.cine_cin_primary_need = 'N7' THEN 'N7 - Low income'
			WHEN ce.cine_cin_primary_need = 'N8' THEN 'N8 - Absent parenting'
			WHEN ce.cine_cin_primary_need = 'N9' THEN 'N9 - Cases other than children in need'
			WHEN ce.cine_cin_primary_need = 'N0' THEN 'N0 - Not stated'
		END											AS PrimaryNeedCode,		/*PW - field added*/
		FORMAT(v.LatestVisit, 'dd/MM/yyyy')			AS DateChildLastSeen,		/*PW - field added*/
		FORMAT(ce.cine_close_date, 'dd/MM/yyyy')	AS CINClosureDate,
		CASE
			WHEN ce.cine_close_reason = 'RC1' THEN 'RC1 - Adopted'
			WHEN ce.cine_close_reason = 'RC2' THEN 'RC2 - Died'
			WHEN ce.cine_close_reason = 'RC3' THEN 'RC3 - Child arrangements order'
			WHEN ce.cine_close_reason = 'RC4' THEN 'RC4 - Special guardianship order'
			WHEN ce.cine_close_reason = 'RC5' THEN 'RC5 - Transferred to services of another local authority'
			WHEN ce.cine_close_reason = 'RC6' THEN 'RC6 - Transferred to adult social care services'
			WHEN ce.cine_close_reason = 'RC7' THEN 'RC7 - Services ceased for any other reason, including child no longer in need'
			WHEN ce.cine_close_reason = 'RC8' THEN 'RC8 - Case closed after assessment, no further action'
			WHEN ce.cine_close_reason = 'RC9' THEN 'RC9 - Case closed after assessment, referred to early help'
		END											AS ReasonForClosure,		/*PW - field added*/
		/*Case Status*/
		CASE
			WHEN ce.cine_close_date is not null THEN 'e) Closed episode'
			WHEN lac.lega_person_id is not null THEN 'a) Looked after child'
			WHEN cp.cppl_person_id is not null THEN 'b) Child Protection plan'
			WHEN cin.cinp_person_id is not null THEN 'c) Child in need plan'
			WHEN cl.clea_person_id is not null THEN 'c) Child in need plan'
			WHEN ass.cina_person_id is not null THEN 'd) Open assessment'
			ELSE 'c) Child in need plan'	/*Catch-all for any remaining cases not allocated a Case Status*/
		END											AS CaseStatus,
    
		/*PW - Previous code commented out*/
		/* case_status */
		--CASE 
		--    WHEN ce.cla_epi_start < GETDATE() AND (ce.cla_epi_ceased IS NULL OR ce.cla_epi_ceased = '') 
		--    THEN 'Looked after child'
		--    WHEN cpp.cpp_start_date < GETDATE() AND cpp.cpp_end_date IS NULL
		--    THEN 'Child Protection plan'
		--    WHEN cp.cinp_cin_plan_start < GETDATE() AND cp.cin_plan_end IS NULL
		--    THEN 'Child in need plan'
		--    WHEN asm.cina_assessment_start_date < GETDATE() AND asm.asmt_auth_date IS NULL
		--    THEN 'Open Assessment'
		--    WHEN ce.clae_cla_episode_ceased     > DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR -- chk db handling of empty strings and nulls is consistent
		--         cpp.cppl_cp_plan_end_date      > DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR 
		--         cp.cinp_cin_plan_end           > DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE()) OR
		--         asm.cina_assessment_auth_date  > DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		--    THEN 'Closed episode'
		--    ELSE NULL 
		--END as case_status,
		inv.Team									AS AllocatedTeam,
		inv.WorkerName								AS AllocatedWorker,
		DENSE_RANK() OVER(PARTITION BY p.pers_person_id ORDER BY ce.cine_referral_date DESC, COALESCE(ce.cine_close_date,'99991231') DESC) Rnk

	FROM
		#ssd_cin_episodes ce	/*PW - think that previous base table of #ssd_cin_plans is incorrect, should be #ssd_cin_episodes not #ssd_cin_plans which is only a sub-category of CIN Episodes (similar to CP or CLA)*/

	INNER JOIN
		#ssd_person p ON ce.cine_person_id = p.pers_person_id	/*PW - # added to start of table name*/

	/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
	LEFT JOIN   -- ensure we get all records even if there's no matching disability
		(
			SELECT DISTINCT
				dis.disa_person_id 
			FROM
				#ssd_disability dis
			WHERE
				COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
		) AS d ON p.pers_person_id = d.disa_person_id

	/*PW - Table added to get date child last seen (latest visit date - CIN, CP or CLA)
		Note - Blackpool ChAT also pulls information from certain Mosaic Case Note Types, Mosaic Visits Screen and Care Leaver Contact WorkflowSteps but these aren't in SSDS*/
	LEFT JOIN
		(
			SELECT
				v2.PersonID,
				v2.CINStartDate,
				v2.CINClosureDate,
				MAX(v2.VisitDate) LatestVisit
			FROM
				(
					SELECT
						ce.cine_person_id PersonID,
						ce.cine_referral_date CINStartDate,
						ce.cine_close_date CINClosureDate,
						v.cinv_cin_visit_date VisitDate
					FROM
						#ssd_cin_episodes ce
					INNER JOIN
						#ssd_cin_visits v ON ce.cine_person_id = v.PersonID
						AND v.cinv_cin_visit_date between ce.cine_referral_date and COALESCE(ce.cine_close_date, GETDATE())

					UNION

					SELECT
						ce.cine_person_id PersonID,
						ce.cine_referral_date CINStartDate,
						ce.cine_close_date CINClosureDate,
						v.cppv_cp_visit_date VisitDate
					FROM
						#ssd_cin_episodes ce
					INNER JOIN
						#ssd_cp_visits v ON ce.cine_person_id = v.PersonID
						AND v.cppv_cp_visit_date between ce.cine_referral_date and COALESCE(ce.cine_close_date, GETDATE())

					UNION

					SELECT
						ce.cine_person_id PersonID,
						ce.cine_referral_date CINStartDate,
						ce.cine_close_date CINClosureDate,
						v.clav_cla_visit_date VisitDate
					FROM
						#ssd_cin_episodes ce
					INNER JOIN
						#ssd_cla_visits v ON ce.cine_person_id = v.clav_person_id
						AND v.clav_cla_visit_date between ce.cine_referral_date and COALESCE(ce.cine_close_date, GETDATE())
				) AS v2

			GROUP BY
				v2.PersonID,
				v2.CINStartDate,
				v2.CINClosureDate
		) AS v ON ce.cine_person_id = v.PersonID
			AND ce.cine_referral_date = v.CINStartDate
			AND COALESCE(ce.cine_close_date,'99991231') = COALESCE(v.CINClosureDate,'99991231')

	LEFT JOIN	/*Identify Children Looked After - note #ssd_legal_status used so children subject to Short Breaks can be excluded*/
		(
			SELECT DISTINCT
				ls.lega_person_id
			FROM
				#ssd_legal_status ls
			INNER JOIN
				#ssd_person p ON ls.lega_person_id = p.pers_person_id
			WHERE
				ls.lega_legal_status not in ('V1','V3','V4')	/*Exclude children subject to Short Breaks*/
				AND ls.lega_legal_status_start_date <= GETDATE()
				AND COALESCE(ls.lega_legal_status_end_date,'99991231') > GETDATE()
				AND p.pers_dob > DATEADD(YEAR, -18, GETDATE())	/*Exclude young people who have reached their 18th Birthday but LAC Episodes not ended*/
		) AS lac ON ce.cine_person_id = lac.lega_person_id

	LEFT JOIN	/*Identify Children subject to CP Plan*/
		(
			SELECT DISTINCT
				cp.cppl_person_id
			FROM
				#ssd_cp_plans cp
			WHERE
				cp.cppl_cp_plan_start_date <= GETDATE()
				AND COALESCE(cp.cppl_cp_plan_end_date,'99991231') > GETDATE()
		) AS cp ON ce.cine_person_id = cp.cppl_person_id

	LEFT JOIN	/*Identify Children subject to CIN Plan*/
		(
			SELECT DISTINCT
				cin.cinp_person_id
			FROM
				#ssd_cin_plans cin
			WHERE
				cin.cinp_cin_plan_start <= GETDATE()
				AND COALESCE(cin.cinp_cin_plan_end,'99991231') > GETDATE()
		) AS cin ON ce.cine_person_id = cin.cinp_person_id

	LEFT JOIN	/*Identify Children with open Assessment*/
		(
			SELECT DISTINCT
				ass.cina_person_id
			FROM
				#ssd_cin_assessments ass
			WHERE
				ass.cina_assessment_start_date <= GETDATE()
				AND COALESCE(ass.cina_assessment_auth_date,'99991231') > GETDATE()
		) AS ass ON ce.cine_person_id = ass.cina_person_id

	LEFT JOIN	/*Identify Care Leavers*/
		(
			SELECT DISTINCT
				cl.clea_person_id
			FROM
				#ssd_care_leavers cl
		) AS cl ON ce.cine_person_id = cl.clea_person_id

	/*PW - Added to get latest allocatd Team and Worker*/
	LEFT JOIN
		(
			SELECT
				cine.cine_person_id PersonID,
				cine.cine_referral_id CINReferralID,
				inv.invo_professional_team Team,
				pro.prof_professional_name WorkerName,
				DENSE_RANK() OVER(PARTITION BY cine.cine_person_id, cine.cine_referral_id 
									ORDER BY COALESCE(inv.invo_involvement_end_date,'99991231') DESC, inv.invo_involvement_start_date DESC, inv.invo_involvements_id DESC) Rnk
			FROM
				#ssd_cin_episodes cine
			INNER JOIN
				#ssd_involvements inv ON cine.cine_person_id = inv.PersonID
				AND inv.invo_involvement_start_date <= COALESCE(cine.cine_close_date,'99991231')
				AND COALESCE(inv.invo_involvement_end_date,'99991231') > cine.cine_referral_date
			INNER JOIN
				#ssd_professionals pro ON inv.invo_professional_id = pro.prof_professional_id
			WHERE
				COALESCE(cine.cine_close_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		) AS inv ON ce.cine_person_id = inv.PersonID
			AND ce.cine_referral_id = inv.CINReferralID
			AND inv.Rnk = 1

	/*PW - Previous code commented out*/
	--LEFT JOIN   -- cla_episodes to get the most recent cla_epi_start
	--    (
	--        SELECT clae_person_id, MAX(clae_cla_episode_start) as clae_cla_episode_start, clae_cla_episode_ceased
	--        FROM ssd_cla_episodes
	--        GROUP BY clae_person_id, clae_cla_episode_ceased
	--    ) AS ce ON p.pers_person_id = ce.clae_person_id

	--LEFT JOIN   -- cp_plans to get the cpp_start_date and cpp_end_date
	--    (
	--        SELECT cppl_person_id , MAX(cppl_cp_plan_start_date) as cppl_cp_plan_start_date, cppl_cp_plan_end_date
	--        FROM ssd_cp_plans
	--        GROUP BY cppl_person_id, cppl_cp_plan_end_date
	--    ) AS cpp ON p.pers_person_id = cpp.cppl_person_id 

	--LEFT JOIN   -- joining with assessments to get the cina_assessment_start_date and cina_assessment_auth_date
	--    ssd_cin_assessments asm ON p.pers_person_id = asm.cina_person_id 

	WHERE
		--ce.cine_referral_date >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	/*Original criteria - CIN Episodes starting in last 6 months*/
		COALESCE(ce.cine_close_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())	/*PW amended criteria - CIN Episodes open in last 6 months (includes those starting more that 6 months ago that were open in last 6 months)*/
)
d

where d.rnk = 1;


-- [TESTING]
select * from #AA_6_children_in_need;




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


SELECT
	d.ChildUniqueID,
	d.Gender,
	d.Ethnicity,
	d.DateOfBirth,
	d.Age,
	d.HasDisability,
	d.ChildProtectionPlanStartDate,
	d.InitialCategoryOfAbuse,
	d.LatestCategoryOfAbuse,
	d.DateOfLastStatutoryVisit,
	d.ChildSeenAlone,
	d.DateOfLatestReviewConf,
	d.ChildProtectionPlanEndDate,
	d.ProtectionLastSixMonths,
	d.NumberOfPreviousChildProtectionPlans,
	d.AllocatedTeam,
	d.AllocatedWorker

INTO #AA_7_child_protection

FROM
(
	SELECT
		/* Common AA fields */
		p.pers_person_id									AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
		CASE
			WHEN p.pers_sex = 'M' THEN 'a) Male'
			WHEN p.pers_sex = 'F' THEN 'b) Female'
			WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
			WHEN p.pers_sex = 'I' THEN 'd) Neither'
		END													AS Gender,
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
		END													AS Ethnicity,
		FORMAT(p.pers_dob, 'dd/MM/yyyy')					AS DateOfBirth,

		/*PW - Blackpool Age Function*/
		DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
				CASE 
					WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
					THEN 1
					ELSE 0
				END											AS Age,

		/* List additional AA fields */
		--d.disa_disability_code							AS DISABILITY,	/*PW - Commented out at values changed to those in Annex A Specification*/ 
		CASE
			WHEN d.disa_person_id is not null THEN 'a) Yes'
			ELSE 'b) No'
		END													AS HasDisability,
    
		/* Returns fields */    
		FORMAT(cp.cppl_cp_plan_start_date, 'dd/MM/yyyy')	AS ChildProtectionPlanStartDate,
		CASE
			WHEN cp.cppl_cp_plan_initial_category in ('NEG','Neglect') THEN 'a) Neglect'
			WHEN cp.cppl_cp_plan_initial_category in ('PHY','Physical abuse') THEN 'b) Physical abuse'
			WHEN cp.cppl_cp_plan_initial_category in ('SAB','Sexual abuse') THEN 'c) Sexual abuse'
			WHEN cp.cppl_cp_plan_initial_category in ('EMO','Emotional abuse') THEN 'd) Emotional abuse'
			WHEN cp.cppl_cp_plan_initial_category in ('MUL','Multiple/not recommended') THEN 'e) Multiple/not recommended'
		END													AS InitialCategoryOfAbuse,
		CASE
			WHEN cp.cppl_cp_plan_latest_category in ('NEG','Neglect') THEN 'a) Neglect'
			WHEN cp.cppl_cp_plan_latest_category in ('PHY','Physical abuse') THEN 'b) Physical abuse'
			WHEN cp.cppl_cp_plan_latest_category in ('SAB','Sexual abuse') THEN 'c) Sexual abuse'
			WHEN cp.cppl_cp_plan_latest_category in ('EMO','Emotional abuse') THEN 'd) Emotional abuse'
			WHEN cp.cppl_cp_plan_latest_category in ('MUL','Multiple/not recommended') THEN 'e) Multiple/not recommended'
		END													AS LatestCategoryOfAbuse,
		FORMAT(vis.VisitDate, 'dd/MM/yyyy')					AS DateOfLastStatutoryVisit,
		CASE
			WHEN vis.VisitDate IS NULL then NULL
			WHEN vis.ChildSeenAlone in ('Yes','Y') THEN 'a) Yes'
			WHEN vis.ChildSeenAlone in ('No','N') THEN 'b) No'
			ELSE 'c) Unknown'
		END													AS ChildSeenAlone,
		FORMAT(rev.ReviewDate, 'dd/MM/yyyy')				AS DateOfLatestReviewConf,
		FORMAT(cp.cppl_cp_plan_end_date, 'dd/MM/yyyy')		AS ChildProtectionPlanEndDate,
		CASE
			WHEN pr.lega_person_id is not null THEN 'a) Yes'
			ELSE 'b) No'
		END													AS ProtectionLastSixMonths,
		aggcpp.CountPrevCPPlans								AS NumberOfPreviousChildProtectionPlans,
		inv.Team											AS AllocatedTeam,
		inv.WorkerName										AS AllocatedWorker,
		DENSE_RANK() OVER(PARTITION BY p.pers_person_id ORDER BY cp.cppl_cp_plan_start_date DESC, COALESCE(cp.cppl_cp_plan_end_date,'99991231') DESC) Rnk

		/*PW - previous code commented out (fields relate to CIN Visits not CP Plans)*/
		/*
		cv.cinv_cin_visit_id,
		cv.cin_plan_id, -- [TESTING] Do we still have access to plan id on cin_visits??? 
		cv.cinv_cin_visit_date,
		cv.cinv_cin_visit_seen,
		cv.cinv_cin_visit_seen_alone,
		*/

		/*PW - previous code commented out*/
		/*
		/* Check if Emergency Protection Order exists within last 6 months */
		CASE WHEN ls.legal_status_id IS NOT NULL THEN 'Y' ELSE 'N' END AS emergency_protection_order,

		/* Which is it??? */
		cp.cin_team,
		cp.cin_worker_id,
		ce.cin_ref_team,
		ce.cin_ref_worker_id as cin_ref_worker,
		*/

		/*PW - previous code commented out*/
		/*
		/* New fields for category of abuse */
		MIN(CASE WHEN cpp.cpp_start_date = coa_early.cpp_earliest_date THEN coa_early.cpp_category END) AS "Initial cat of abuse",
		MIN(CASE WHEN cpp.cpp_start_date = coa_latest.cpp_latest_date THEN coa_latest.cpp_category END) AS "latest cat of abuse"
		*/

	FROM 
		#ssd_cp_plans cp	/*PW - think that base table is incorrect, should be #ssd_cp_plans not #ssd_cin_visits*/

	INNER JOIN
		#ssd_person p ON cp.cppl_person_id = p.pers_person_id	/*PW - # added to start of table name*/

	/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
	LEFT JOIN   -- ensure we get all records even if there's no matching disability
		(
			SELECT DISTINCT
				dis.disa_person_id 
			FROM
				#ssd_disability dis
			WHERE
				COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
		) AS d ON p.pers_person_id = d.disa_person_id

	/*PW - Added to get latest visit and whether child was seen alone*/
	LEFT JOIN
		(
			SELECT
				cp.cppl_person_id PersonID,
				cp.cppl_cp_plan_id CPRegID,
				vis.cppv_cp_visit_date VisitDate,
				vis.cppv_cp_visit_seen_alone ChildSeenAlone,
				DENSE_RANK() OVER(PARTITION BY cp.cppl_person_id, cp.cppl_cp_plan_id ORDER BY vis.cppv_cp_visit_date DESC, vis.cppv_cp_visit_seen_alone DESC, vis.cppv_cp_visit_id) Rnk
			FROM
				#ssd_cp_plans cp

			INNER JOIN
				#ssd_cp_visits vis ON cp.cppl_person_id = vis.PersonID
				AND cp.cppl_cp_plan_id = vis.cppv_cp_plan_id
				AND vis.cppv_cp_visit_date between cp.cppl_cp_plan_start_date and COALESCE(cp.cppl_cp_plan_end_date, GETDATE())
			WHERE
				COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		) AS vis on cp.cppl_person_id = vis.PersonID
			AND cp.cppl_cp_plan_id = vis.CPRegID
			AND vis.Rnk = 1

	/*PW - Added to get latest review*/
	LEFT JOIN
		(
			SELECT
				cp.cppl_person_id PersonID,
				cp.cppl_cp_plan_id CPRegID,
				MAX(rev.cppr_cp_review_date) ReviewDate
			FROM
				#ssd_cp_plans cp

			INNER JOIN
				#ssd_cp_reviews rev ON cp.cppl_person_id = rev.PersonID
				AND cp.cppl_cp_plan_id = rev.cppr_cp_plan_id
				AND rev.cppr_cp_review_date between cp.cppl_cp_plan_start_date and COALESCE(cp.cppl_cp_plan_end_date, GETDATE())
			WHERE
				COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
			GROUP BY
				cp.cppl_person_id,
				cp.cppl_cp_plan_id
		) AS rev on cp.cppl_person_id = rev.PersonID
			AND cp.cppl_cp_plan_id = rev.CPRegID

	/*PW - Added to get whether child subject to Emergency Protection Order or Protected Under Police Powers in Last Six Months*/
	LEFT JOIN
		(
			SELECT DISTINCT
				ls.lega_person_id
			FROM
				#ssd_legal_status ls
			WHERE
				ls.lega_legal_status in ('L1','L2')
				AND COALESCE(ls.lega_legal_status_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		) AS pr ON p.pers_person_id = pr.lega_person_id

	/*PW - Added to get number of previous CP Plans.  NOTE - because this uses #ssd_cp_plans, only has details of CP Plans open in the last 6 years*/
	LEFT JOIN 
		(
			SELECT
			/*CP Plans a child was previously subject to*/
				cp.cppl_person_id,
				cp.cppl_cp_plan_id,
				COUNT(cp2.cppl_cp_plan_id) as CountPrevCPPlans
			FROM
				#ssd_cp_plans cp
			LEFT JOIN
				#ssd_cp_plans cp2 ON cp.cppl_person_id = cp2.cppl_person_id
				AND cp2.cppl_cp_plan_start_date < cp.cppl_cp_plan_start_date
			WHERE
				COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
			GROUP BY
				cp.cppl_person_id,
				cp.cppl_cp_plan_id
		) AS aggcpp ON cp.cppl_person_id = aggcpp.cppl_person_id
			AND cp.cppl_cp_plan_id = aggcpp.cppl_cp_plan_id

	/*PW - Added to get latest allocatd Team and Worker*/
	LEFT JOIN
		(
			SELECT
				cp.cppl_person_id PersonID,
				cp.cppl_cp_plan_id CPRegID,
				inv.invo_professional_team Team,
				pro.prof_professional_name WorkerName,
				DENSE_RANK() OVER(PARTITION BY cp.cppl_person_id, cp.cppl_cp_plan_id 
									ORDER BY COALESCE(inv.invo_involvement_end_date,'99991231') DESC, inv.invo_involvement_start_date DESC, inv.invo_involvements_id DESC) Rnk
			FROM
				#ssd_cp_plans cp
			INNER JOIN
				#ssd_cin_episodes cine ON cp.cppl_person_id = cine.cine_person_id
				AND cp.cppl_referral_id = cine.cine_referral_id
			INNER JOIN
				#ssd_involvements inv ON cine.cine_person_id = inv.PersonID
				AND inv.invo_involvement_start_date <= COALESCE(cine.cine_close_date,'99991231')
				AND COALESCE(inv.invo_involvement_end_date,'99991231') > cine.cine_referral_date
			INNER JOIN
				#ssd_professionals pro ON inv.invo_professional_id = pro.prof_professional_id
			WHERE
				COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
		) AS inv on cp.cppl_person_id = inv.PersonID
			AND cp.cppl_cp_plan_id = inv.CPRegID
			AND inv.Rnk = 1

	/*PW - previous code commented out*/
	/*		
	--INNER JOIN
	--    cin_episodes ce ON cv.la_person_id = ce.la_person_id
	--LEFT JOIN
	--    legal_status ls ON cv.la_person_id = ls.la_person_id 
	--        AND ls.legal_status_start >= DATEADD(MONTH, -6, GETDATE())	/*PW - amended from '>= DATE_ADD(CURRENT_DATE, INTERVAL -6 MONTH)'*/

	LEFT JOIN
		cp_plans cpp ON cv.la_person_id = cpp.la_person_id
	LEFT JOIN
		category_of_abuse coa_early ON cpp.cp_plan_id = coa_early.cp_plan_id
		AND coa_early.cpp_start_date = (
			SELECT MIN(cpp_start_date) FROM cp_plans WHERE la_person_id = cv.la_person_id
		)
	LEFT JOIN
		category_of_abuse coa_latest ON cpp.cp_plan_id = coa_latest.cp_plan_id
		AND coa_latest.cpp_start_date = (
			SELECT MAX(cpp_start_date) FROM cp_plans WHERE la_person_id = cv.la_person_id
		)
	*/

	WHERE
		--cp.cin_visit_date >= DATEADD(MONTH, -12, GETDATE()) -- [TESTING] check time period, 12mths or 6?	/*Original criteria - CP Plans starting in last 12 months*/
		COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())	/*PW amended criteria - CP Plans open in last 6 months (includes those starting more that 6 months ago that were open in last 6 months)*/

	/*PW - previous code commented out (grouping no longer required)*/
	/*
	GROUP BY
		p.la_person_id,
		p.person_sex,
		p.person_gender,
		p.person_ethnicity,
		p.person_dob,
		d.person_disability,
		cv.cin_visit_id,
		cv.cin_plan_id,
		cv.cin_visit_date,
		cv.cin_visit_seen,
		cv.cin_visit_seen_alone,
		cp.cin_team,
		cp.cin_worker_id,
		ce.cin_ref_team,
		ce.cin_ref_worker_id,
		ls.legal_status_id;
	*/

	/* AA headings from sample
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

	-- Are these needed? Not in list 7
	--     /* New fields from cin_episodes table */
	--     ce.cin_primary_need, -- available in more than one place
	--     ce.cin_ref_outcome, -- is this case status? 
	--     ce.cin_close_reason,
	--     ce.cin_ref_team,
	--     ce.cin_ref_worker_id as cin_ref_worker  -- Renamed for clarity
	-- INNER JOIN  -- with cin_episodes
	--     cin_episodes ce ON cp.la_person_id = ce.la_person_id
)
d

where d.rnk = 1;


-- [TESTING]
select * from #AA_7_child_protection;




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
	p.pers_person_id											AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
	CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END															AS Gender,
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
	END															AS Ethnicity,
	FORMAT(p.pers_dob, 'dd/MM/yyyy')							AS DateOfBirth,

	/*PW - Blackpool Age Function*/
	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END													AS Age,
 
    /* List additional AA fields */
	CASE
		WHEN uasc.immi_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS UASC,
	--d.disa_disability_code									AS DISABILITY,	/*PW - Commented out at values changed to those in Annex A Specification*/ 
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS HasDisability,
	FORMAT(clapl.LACStart, 'dd/MM/yyyy')						AS LoookedAfterStartDate,
	claepi.CategoryOfNeed										AS ChildCategoryOfNeed,
	NULL														AS SubsequentLACEpisodeLast12Months,
	FORMAT(clals.LSStartDate, 'dd/MM/yyyy')						AS MostRecentLegalStatusStart,
	clals.LSCode												AS LegalStatus,
	NULL														AS LatestStatutoryReviewDate,
	NULL														AS LastSocialWorkVisitDate,
	NULL														AS PermanencePlan,
	FORMAT(claepi.LatestIROVisit, 'dd/MM/yyyy')					AS LastIROVisitDate,
	NULL														AS LastHealthAssessmentDate,
	NULL														AS LastDentalCheckDate,
	COALESCE(agglacp.CountCLAPlacements,1)						AS PlacementsLast12Months,		/*PW - COALESCE because if latest episode is change of Legal Status or change of placement with same carer, and this is the only episode in last 12 months, would otherwise return NULL*/
	FORMAT(claepi.DateEpisodeCeased, 'dd/MM/yyyy')				AS CeasedLookedAfterDate,
	claepi.ReasonEpisodeCeased									AS ReasonCeasedLookedAfter,
	FORMAT(clapl.clap_cla_placement_start_date, 'dd/MM/yyyy')	AS MostRecentPlacementStartDate,
	clapl.clap_cla_placement_type								AS PlacementType,
	clapl.clap_cla_placement_provider							AS PlacementProvider,
	clapl.clap_cla_placement_postcode							AS PlacementPostcode,
	clapl.clap_cla_placement_urn								AS PlacementURN,
	CASE
		WHEN clapl.clap_cla_placement_la = 'BLACKPOOL' THEN 'a) In'
		ELSE 'b) Out'
	END															AS PlacementLocation, /*PW - check v Annex A regarding Blank Placement LA*/
	clapl.clap_cla_placement_la									AS PlacementLA,
	NULL														AS EpisodesChildMissingFromPlacement,
	NULL														AS EpisodesChildAbsentFromPlacement,
	NULL														AS ChildOfferedReturnInterviewAfterLastMFH,
	NULL														AS ChildAcceptedReturnInterviewAfterLastMFH,
	inv.Team													AS AllocatedTeam,
	inv.WorkerName												AS AllocatedWorker

/*PW - previous code commented out*/
/*
    i.immi_immigration_status					AS UASC,                -- UASC12mth (if had imm.status 'Unaccompanied Asylum Seeking Child' active in prev 12 months)
 
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
*/
 
INTO #AA_8_children_in_care

FROM
	/*PW - get distinct Child IDs with latest LAC Placement details*/
	(
		SELECT
			clapl2.PersonID,
			clapl2.LACStart,
			clapl2.clap_cla_placement_start_date,
			clapl2.clap_cla_placement_end_date,
			clapl2.clap_cla_placement_type,
			clapl2.clap_cla_placement_provider,
			clapl2.clap_cla_placement_postcode,
			clapl2.clap_cla_placement_urn,
			clapl2.clap_cla_placement_la
		FROM
			(
				SELECT
					clap.PersonID,
					clap.LACStart,
					clap.clap_cla_placement_start_date,
					clap.clap_cla_placement_end_date,
					clap.clap_cla_placement_type,
					clap.clap_cla_placement_provider,
					clap.clap_cla_placement_postcode,
					clap.clap_cla_placement_urn,
					clap.clap_cla_placement_la,
					DENSE_RANK() OVER(PARTITION BY clap.PersonID ORDER BY clap.clap_cla_placement_start_date DESC, COALESCE(clap.clap_cla_placement_end_date,'99991231') DESC) Rnk
				FROM
					#ssd_cla_placement clap
				WHERE
					COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
			) clapl2
		WHERE
			clapl2.Rnk = 1
	)
	clapl

INNER JOIN
	#ssd_person p ON clapl.PersonID = p.pers_person_id

/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

/*PW - added to get UASC*/
LEFT JOIN
	(
		SELECT DISTINCT
			uasc.immi_person_id 
		FROM
			#ssd_immigration_status uasc
		WHERE
			uasc.immi_immigration_status = 'UASC'
			--AND COALESCE(uasc.immi_immigration_status_end_date,'99991231') >= DATEADD(MONTH, -12 , GETDATE())	/*PW - Row commented out as giving error 'Arithmetic overflow error converting expression to data type datetime' (possibly because no records have end date)*/
	) AS uasc ON p.pers_person_id = uasc.immi_person_id

/*PW - Added to get CIN Category of Need and Reason Ceased Looked After*/
LEFT JOIN
	(
		SELECT
			clap.PersonID PersonID,
			clae.clae_cla_episode_start CLAEpiStart,	/*PW - included as used in join later on to get Worker and Team*/
			clae.clae_cla_primary_need CategoryOfNeed,
			clae.clae_cla_episode_ceased DateEpisodeCeased,
			clae.clae_cla_episode_cease_reason ReasonEpisodeCeased,
			clae.clae_cla_last_iro_contact_date LatestIROVisit,
			DENSE_RANK() OVER(PARTITION BY clap.PersonID ORDER BY clap.clap_cla_placement_start_date DESC, clae.clae_cla_episode_start DESC) Rnk
		FROM
			#ssd_cla_placement clap
		INNER JOIN
			#ssd_cla_episodes clae ON clap.PersonID = clae.clae_person_id
		WHERE
			COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
			AND COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
	) AS claepi on clapl.PersonID = claepi.PersonID
		AND claepi.Rnk = 1

/*PW - Added to get Latest Legal Status and Latest Legal Status Start Date*/
LEFT JOIN
	(
		SELECT
			clap.PersonID PersonID,
			clals.lega_legal_status LSCode,
			CAST(clals.lega_legal_status_start_date as date) LSStartDate,
			DENSE_RANK() OVER(PARTITION BY clap.PersonID ORDER BY clap.clap_cla_placement_start_date DESC, clals.lega_legal_status_start_date DESC) Rnk
		FROM
			#ssd_cla_placement clap
		INNER JOIN
			#ssd_legal_status clals ON clap.PersonID = clals.lega_person_id
		WHERE
			COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
			AND COALESCE(clals.lega_legal_status_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
	) AS clals on clapl.PersonID = clals.PersonID
		AND clals.Rnk = 1

/*PW - Added to get number of LAC Placements in previous 12 months.  Note #ssd_cla_episodes used so placements with same carer can be excluded*/
LEFT JOIN
	(
		SELECT
			clae.clae_person_id,
			COUNT(clae.clae_person_id) as CountCLAPlacements
		FROM
			#ssd_cla_episodes clae
		WHERE
			COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -12 , GETDATE())
			AND (clae.clae_cla_episode_start_reason in ('S','P','B')
				OR (clae.clae_cla_episode_start <= DATEADD(MONTH, -12 , GETDATE())	/*PW Additional clause to ensure initial placement from 12 months ago is counted if with same carer*/
					AND clae.clae_cla_episode_ceased > DATEADD(MONTH, -12 , GETDATE())
					AND clae.clae_cla_episode_start_reason in ('T','U')))
		GROUP BY
			clae.clae_person_id
	) AS agglacp ON clapl.PersonID = agglacp.clae_person_id

/*PW - Added to get latest allocatd Team and Worker*/
LEFT JOIN
	(
		SELECT
			clae.clae_person_id PersonID,
			clae.clae_cla_episode_start CLAEpiStart,
			inv.invo_professional_team Team,
			pro.prof_professional_name WorkerName,
			DENSE_RANK() OVER(PARTITION BY clae.clae_person_id, clae.clae_cla_episode_start 
								ORDER BY COALESCE(inv.invo_involvement_end_date,'99991231') DESC, inv.invo_involvement_start_date DESC, inv.invo_involvements_id DESC) Rnk
		FROM
			#ssd_cla_episodes clae
		INNER JOIN
			#ssd_cin_episodes cine ON clae.clae_person_id = cine.cine_person_id
			AND clae.clae_referral_id = cine.cine_referral_id
		INNER JOIN
			#ssd_involvements inv ON cine.cine_person_id = inv.PersonID
			AND inv.invo_involvement_start_date <= COALESCE(cine.cine_close_date,'99991231')
			AND COALESCE(inv.invo_involvement_end_date,'99991231') > cine.cine_referral_date
		INNER JOIN
			#ssd_professionals pro ON inv.invo_professional_id = pro.prof_professional_id
		WHERE
			COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
	) AS inv on claepi.PersonID = inv.PersonID
		AND claepi.CLAEpiStart = inv.CLAEpiStart
		AND inv.Rnk = 1

/*PW - previous code commented out*/
/*
FROM
    #ssd_cla_episodes   clae
    #ssd_cla_health     clah
    #ssd_cla_placement  clap
    #ssd_cla_previous_permanence    lapp
 
INNER JOIN
    ssd_person p ON clae.clae_person_id = p.pers_person_id
 
LEFT JOIN   -- disability table
    ssd_disability d ON clae.clae_person_id = d.disa_person_id
 
LEFT JOIN   -- immigration_status table (UASC)
    ssd_immigration_status i ON clae.clae_person_id = i.immi_person_id
*/

WHERE
	clals.LSCode not in ('V1','V3','V4');	/*Exclude children subject to Short Breaks*/


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

    -- clea.clea_care_leaver_allocated_team_name   AS AllocatedTeam,       -- Allocated Team
    -- clea.clea_care_leaver_worker_name           AS AllocatedWorker,     -- Allocated Worker
    -- clea.clea_care_leaver_personal_advisor      AS AllocatedPA,         -- Allocated Personal Advisor
    -- clea.clea_care_leaver_eligibility           AS EligibilityCategory, -- Eligibility Category
    -- clea.clea_care_leaver_in_touch              AS InTouch,             -- LA In Touch 
    -- clea.clea_pathway_plan_review_date          AS ReviewDate,          -- Latest Pathway Plan Review Date
    -- clea.clea_care_leaver_latest_contact        AS LatestContactDate,   -- Latest Date of Contact
    -- clea.clea_care_leaver_accommodation         AS AccomodationType,    -- Type of Accommodation
    -- clea.clea_care_leaver_accom_suitable        AS AccommodationSuitability, -- Suitability of Accommodation
    -- clea.clea_care_leaver_activity              AS ActivityStatus       -- Activity Status
	CASE
		WHEN uasc.immi_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS UASC,
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS HasDisability,
    	clea.clea_care_leaver_allocated_team					AS AllocatedTeam,
	pro.prof_professional_name									AS AllocatedWorker,
	clea.clea_care_leaver_personal_advisor						AS AllocatedPersonalAdvisor,	-- Allocated Personal Advisor
	CASE
		WHEN clea.clea_care_leaver_eligibility in ('Relevant','Relevant child') 				then 'a) Relevant child'
		WHEN clea.clea_care_leaver_eligibility in ('Former Relevant','Former relevant child') 	then 'b) Former relevant child'
		WHEN clea.clea_care_leaver_eligibility in ('Qualifying','Qualifying care leaver') 		then 'c) Qualifying care leaver'
		WHEN clea.clea_care_leaver_eligibility in ('Eligible','Eligible child') 				then 'd) Eligible child'
	END															AS EligibilityCategory,			-- Eligibility Category
	FORMAT(clea.clea_pathway_plan_review_date, 'dd/MM/yyyy')	AS LatestPathwayPlan,			-- Latest Pathway Plan Review Date
	CASE
		WHEN clea.clea_care_leaver_in_touch in ('YES', 'Y') THEN 'a) Yes'
		WHEN clea.clea_care_leaver_in_touch in ('NO', 'N') 	THEN 'b) No'
		WHEN clea.clea_care_leaver_in_touch in ('DIED') 	THEN 'c) Died'
		WHEN clea.clea_care_leaver_in_touch in ('REFU', 'Refused') 			THEN 'd) Refu'
		WHEN clea.clea_care_leaver_in_touch in ('NREQ', 'Not Required') 	THEN 'e) NREQ'
		WHEN clea.clea_care_leaver_in_touch in ('RHOM', 'Returned Home') 	THEN 'f) Rhom'
	END															AS LAInTouch,
	FORMAT(clea.clea_care_leaver_latest_contact, 'dd/MM/yyyy')	AS LatestContact,
	CASE
		WHEN clea.clea_care_leaver_accommodation = 'B' THEN 'B: Parents/relatives'
		WHEN clea.clea_care_leaver_accommodation = 'C' THEN 'C: Community home / residential care'
		WHEN clea.clea_care_leaver_accommodation = 'D' THEN 'D: Semi-independent, transitional accommodation and self-contained accommodation'
		WHEN clea.clea_care_leaver_accommodation = 'E' THEN 'E: Supported lodgings'
		WHEN clea.clea_care_leaver_accommodation = 'G' THEN 'G: Abroad'
		WHEN clea.clea_care_leaver_accommodation = 'H' THEN 'H: Deported'
		WHEN clea.clea_care_leaver_accommodation = 'K' THEN 'K: Ordinary lodgings, without formal support'
		WHEN clea.clea_care_leaver_accommodation = 'R' THEN 'R: Residence not known'
		WHEN clea.clea_care_leaver_accommodation = 'S' THEN 'S: No fixed abode / homeless'
		WHEN clea.clea_care_leaver_accommodation = 'T' THEN 'T: Foyers and similar supported accommodation'
		WHEN clea.clea_care_leaver_accommodation = 'U' THEN 'U: Independent living'
		WHEN clea.clea_care_leaver_accommodation = 'V' THEN 'V: Emergency accommodation'
		WHEN clea.clea_care_leaver_accommodation = 'W' THEN 'W: Bed and breakfast'
		WHEN clea.clea_care_leaver_accommodation = 'X' THEN 'X: In custody'
		WHEN clea.clea_care_leaver_accommodation = 'Y' THEN 'Y: Other accommodation'
		WHEN clea.clea_care_leaver_accommodation = 'Z' THEN 'Z: With former foster carers'
	END															AS TypeOfAccommodation,				-- Type of Accommodation
	CASE
		WHEN clea.clea_care_leaver_accom_suitable in ('1', 'Yes', 'Y', 'Suitable') THEN 'a) Suitable'
		WHEN clea.clea_care_leaver_accom_suitable in ('2', 'No', 'N', 'Not Suitable', 'Unsuitable') THEN 'b) Unsuitable'
	END															AS SuitabilityOfAccommodation,		-- Suitability of Accommodation
	CASE
		WHEN clea.clea_care_leaver_activity = 'F1' THEN 'F1: Full time in higher education'
		WHEN clea.clea_care_leaver_activity = 'P1' THEN 'P1: Part time in higher education'
		WHEN clea.clea_care_leaver_activity = 'F2' THEN 'F2: Full time in education other than higher'
		WHEN clea.clea_care_leaver_activity = 'P2' THEN 'P2: Part time in education other than higher'
		WHEN clea.clea_care_leaver_activity = 'F4' THEN 'F4: Young person engaged full time in an apprenticeship'
		WHEN clea.clea_care_leaver_activity = 'P4' THEN 'P4: Young person engaged part time in an apprenticeship'
		WHEN clea.clea_care_leaver_activity = 'F5' THEN 'F5: Young person engaged full time in training or employment (not apprenticeship)'
		WHEN clea.clea_care_leaver_activity = 'P5' THEN 'P5: Young person engaged part time in training or employment (not apprenticeship)'
		WHEN clea.clea_care_leaver_activity = 'G4' THEN 'G4: Not in education, employment or training - illness or disability'
		WHEN clea.clea_care_leaver_activity = 'G5' THEN 'G5: Not in education, employment or training - other'
		WHEN clea.clea_care_leaver_activity = 'G6' THEN 'G6: Not in education, employment or training - pregnancy or parenting'
	END															AS ActivityStatus       			-- Activity Status		

INTO #AA_9_care_leavers

FROM
    #ssd_care_leavers clea
 
INNER JOIN -- person table for core dets
	#ssd_person p ON clea.clea_person_id = p.pers_person_id

/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id


LEFT JOIN   -- join but with subquery as need most recent immigration status
    (
        SELECT 
            immi_person_id,
            immi_immigration_status,
            -- partitioning by immi_person_id (group by each person) 
            ROW_NUMBER() OVER (PARTITION BY immi_person_id -- assign unique row num (most recent rn ===1)
            -- get latest status based on end date, (using start date as a secondary order in case of ties or NULL end dates)
            ORDER BY immi_immigration_status_end_date DESC, immi_immigration_status_start_date DESC) AS rn
        FROM 
            ssd_immigration_status
    ) latest_status ON clea.clea_person_id = latest_status.immi_person_id AND latest_status.rn = 1

-- /*PW - added to get UASC*/
-- LEFT JOIN
-- 	(
-- 		SELECT DISTINCT
-- 			uasc.immi_person_id 
-- 		FROM
-- 			#ssd_immigration_status uasc
-- 		WHERE
-- 			uasc.immi_immigration_status = 'UASC'
-- 			--AND COALESCE(uasc.immi_immigration_status_end_date,'99991231') >= DATEADD(MONTH, -12 , GETDATE())	/*PW - Row commented out as giving error 'Arithmetic overflow error converting expression to data type datetime' (possibly because no records have end date)*/
-- 	) AS uasc ON p.pers_person_id = uasc.immi_person_id

LEFT JOIN
	#ssd_professionals pro on clea.clea_care_leaver_worker_id = pro.prof_professional_id;

/* 
=============================================================================
Report Name: Ofsted List 10 - Adoption YYYY
Description: 
            "All those children who, in the 12 months before the inspection, 
            have: been adopted, had the decision that they should be placed 
            for adoption but they have not yet been adopted, had an adoption 
            decision reversed during the 12 months."

Author: D2I
Last Modified Date: 04/03/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.1
]			1.0: PW changes integrated
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_immigration_status
- ssd_permanence 
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_10_adoption', 'U') IS NOT NULL DROP TABLE #AA_10_adoption;

SELECT
    /* Common AA fields */
    p.pers_legacy_id                        AS ChildUniqueID,       -- temp solution [TESTING] This liquid logic specific
    p.pers_person_id                        AS ChildUniqueID2,      -- temp solution [TESTING] This for compatiblility in non-ll systems
    NULL                      				AS FamilyIdentifier,    -- Family identifier (Local adoptive family ID for the adoptive family the child is matched or placed with)       
    CASE
        WHEN p.pers_sex = 'M' THEN 'a) Male'
        WHEN p.pers_sex = 'F' THEN 'b) Female'
        WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
        WHEN p.pers_sex = 'I' THEN 'd) Neither'
    END                                    	AS Gender,
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
    END                                      AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')         AS DateOfBirth, --  note: returns string representation of the date
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
    END                                      AS Age,
 
    /* List additional AA fields */
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS HasDisability,
	FORMAT(perm.perm_entered_care_date, 'dd/MM/yyyy')			AS EnteredCareDate,				-- Date the Child Entered Care
	FORMAT(perm.perm_adm_decision_date, 'dd/MM/yyyy')			AS ADMSHOBPADecisionDate,		-- Date the child was placed for fostering in FostingForAdoption or concurrent planning placement 
	FORMAT(perm.perm_placement_order_date, 'dd/MM/yyyy')		AS PlacementOrderDate,			-- Date of Decision that Child Should be Placed for Adoption
	FORMAT(perm.perm_matched_date, 'dd/MM/yyyy')				AS MatchedForAdoptionDate,		-- Date of Matching Child and Prospective Adopters
	FORMAT(perm.perm_placed_for_adoption_date, 'dd/MM/yyyy')	AS PlacedForAdoptionDate,		-- Date Placed for Adoption
	FORMAT(perm.perm_permanence_order_date, 'dd/MM/yyyy')		AS AdoptionOrderDate,			-- Date of Placement Order? [TESTING]
	FORMAT(perm.perm_decision_reversed_date, 'dd/MM/yyyy')		AS DecisionReversedDate,		-- Date of Decision that Child Should No Longer be Placed for Adoption
	CASE
		WHEN perm.perm_decision_reversed_reason = 'RD1' THEN 'RD1 - The child’s needs changed subsequent to the decision'
		WHEN perm.perm_decision_reversed_reason = 'RD2' THEN 'RD2 - The Court did not make a placement order'
		WHEN perm.perm_decision_reversed_reason = 'RD3' THEN 'RD3 - Prospective adopters could not be found'
		WHEN perm.perm_decision_reversed_reason = 'RD4' THEN 'RD4 - Any other reason'
	END															AS DecisionReversedReason,		-- Reason Why Child No Longer Placed for Adoption
	FORMAT(perm.perm_placed_ffa_cp_date, 'dd/MM/yyyy')			AS DateFFAConsurrencyPlacement
	-- FORMAT(perm.perm_ffa_cp_decision_date, 'dd/MM/yyyy')        AS FfaDecisionDate,        	-- [TESTING]

 
INTO #AA_10_adoption
 
FROM
    #ssd_permanence perm
 
LEFT JOIN   -- person table for core dets
    #ssd_person p ON perm.perm_person_id = p.pers_person_id
 
/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id
 
WHERE
	perm.perm_adm_decision_date is not null		/*PW - Restricts to Adoption Cases and ignores other Legal Orders*/
	AND 
		(
			/*Note - list 10 uses a 12 month period as opposed to the 6 month period used in other lists*/
			perm.perm_permanence_order_date >= DATEADD(MONTH, -12, GETDATE()) OR	/*Adopted in previous 12 months*/
			perm.perm_decision_reversed_date >= DATEADD(MONTH, -12, GETDATE()) OR	/*Decision Reversed in previous 12 months*/
			(perm.perm_permanence_order_date is null and perm.perm_decision_reversed_date is null)	/*Current Adoption Cases*/
		)



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
    'PLACEHOLDER_DATA'                          AS AdopterIdentifier,   -- Individual adopter identifier (Unavailable in SSD V1)
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
    '1900-01-01'                                AS EnquiryDate,         -- Date enquiry received		[PLACEHOLDER_DATA]
    '1900-01-01'                                AS Stage1StartDate,     -- Date Stage 1 started			[PLACEHOLDER_DATA]
    '1900-01-01'                                AS Stage1EndDate,       -- Date Stage 1 ended			[PLACEHOLDER_DATA]
    '1900-01-01'                                AS Stage2StartDate,     -- Date Stage 2 started			[PLACEHOLDER_DATA]
    '1900-01-01'                                AS Stage2EndDate,       -- Date Stage 2 ended			[PLACEHOLDER_DATA]
    '1900-01-01'                                AS ApplicationDate,     -- Date application submitted	[PLACEHOLDER_DATA]
    '1900-01-01'                                AS ApplicationApprDate, -- Date application approved	[PLACEHOLDER_DATA]
    perm.perm_matched_date                      AS MatchedDate,         -- Date adopter matched with child(ren)
    perm.perm_placed_for_adoption_date          AS PlacedDate,          -- Date child/children placed with adopter(s)
    perm.perm_siblings_placed_together          AS NumSiblingsPlaced,   -- No. of children placed
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

-- LEFT JOIN   -- family table
--     #ssd_family fam ON perm.perm_person_id = fam.fami_person_id

WHERE
    c.cont_contact_start >= DATEADD(MONTH, -12, GETDATE()) -- Filter on last 12 months
	-- SHOULD THIS BE cont_contact_date??