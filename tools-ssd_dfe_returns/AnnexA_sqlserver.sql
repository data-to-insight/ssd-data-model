-- LA specific vars
USE HDM_local;
GO

-- Set reporting period in Mths
DECLARE @AA_ReportingPeriod INT;
SET @AA_ReportingPeriod = 6; -- Mths



/*
****************************************
SSD AnnexA Returns Queries || SQL Server
****************************************
*/

-- Note: Script is currently set to point to #TMP SSD table names. Remove # prefix as 
-- required if running from persistant table version. 


/* 
=============================================================================
Report Name: Ofsted List 1 - Contacts YYYY
Description: 
            "All contacts received in the six months before the date of inspection. 
            Where a contact refers to multiple children, include an entry for 
            each child in the contact.""

Author: D2I
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.4: contact_source_desc added
            0.3: apply revised obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_contacts
- ssd_person
- @AA_ReportingPeriod
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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

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
		ELSE 'u) 10: Unknown' --'Catch All' for any other Contact/Referral Sources not in above list
	END											AS ContactSource


INTO #AA_1_contacts

FROM
    ssd_development.ssd_contacts c

LEFT JOIN
    ssd_person p ON c.cont_person_id = p.pers_person_id

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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cin_episodes
- ssd_person
- ssd_early_help_episodes
- @AA_ReportingPeriod
=============================================================================
*/

/*
[TESTING]
11/02/2024 - PW Comment
Possible disconnect between SSDS Dataset and Annex A.
Annex A refers to Early Help Assessments whereas SSDS interpreted (perhaps incorrectly) as Early Help Episodes
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_2_early_help_assessments') IS NOT NULL DROP TABLE #AA_2_early_help_assessments;


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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

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
    ssd_development.ssd_early_help_episodes e	

LEFT JOIN
    ssd_person p ON e.earl_person_id = p.pers_person_id	

WHERE

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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
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
    p.pers_person_id							AS ChildUniqueID,	
    CASE
        WHEN p.pers_sex = 'M' THEN 'a) Male'
        WHEN p.pers_sex = 'F' THEN 'b) Female'
        WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
        WHEN p.pers_sex = 'I' THEN 'd) Neither'
    END											AS Gender,
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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

    DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                THEN 1
                ELSE 0
            END									AS Age,

    /* List additional AA fields */

    FORMAT(ce.cine_referral_date, 'dd/MM/yyyy')	AS ReferralDate,
	CASE
		WHEN ce.cine_referral_source_code = '1A' THEN 'a) 1A: Individual'
		WHEN ce.cine_referral_source_code = '1B' THEN 'b) 1B: Individual'
		WHEN ce.cine_referral_source_code = '1C' THEN 'c) 1C: Individual'
		WHEN ce.cine_referral_source_code = '1D' THEN 'd) 1D: Individual'
		WHEN ce.cine_referral_source_code = '2A' THEN 'e) 2A: Schools'
		WHEN ce.cine_referral_source_code = '2B' THEN 'f) 2B: Education services'
		WHEN ce.cine_referral_source_code = '3A' THEN 'g) 3A: Health services'
		WHEN ce.cine_referral_source_code = '3B' THEN 'h) 3B: Health services'
		WHEN ce.cine_referral_source_code = '3C' THEN 'i) 3C: Health services'
		WHEN ce.cine_referral_source_code = '3D' THEN 'j) 3D: Health services'
		WHEN ce.cine_referral_source_code = '3E' THEN 'k) 3E: Health services'
		WHEN ce.cine_referral_source_code = '3F' THEN 'l) 3F: Health services'
		WHEN ce.cine_referral_source_code = '4' THEN 'm) 4: Housing'
		WHEN ce.cine_referral_source_code = '5A' THEN 'n) 5A: LA services'
		WHEN ce.cine_referral_source_code = '5B' THEN 'o) 5B: LA services'
		WHEN ce.cine_referral_source_code = '5C' THEN 'p) 5C: LA services'
		WHEN ce.cine_referral_source_code = '5D' THEN 'p1) 5D: LA services'
		WHEN ce.cine_referral_source_code = '6' THEN 'q) 6: Police'
		WHEN ce.cine_referral_source_code = '7' THEN 'r) 7: Other legal agency'
		WHEN ce.cine_referral_source_code = '8' THEN 's) 8: Other'
		WHEN ce.cine_referral_source_code = '9' THEN 't) 9: Anonymous'
		WHEN ce.cine_referral_source_code = '10' THEN 'u) 10: Unknown'
		ELSE 'u) 10: Unknown' -- 'Catch All' for any other Contact/Referral Sources not in above list
	END											AS ReferralSource,
	CASE -- indicate if the most recent referral (or individual referral) resulted in 'No Further Action' (NFA)
        WHEN ce.cine_referral_nfa in ('Y','Yes','1') THEN 'a) Yes'		
        ELSE 'b) No'
    END											AS ReferralNFA,
    COALESCE(sub.count_12months, 0)				AS ReferralsLast12Months,	
	
	-- [TESTING]
	/*PW Note - Have used Team and Worker that Referral was assinged to as per Annex A guidance
					However in Blackpool, all Contact/Referral WorkflowSteps are processed by the 'Front Door' (Request for Support Hub) with generic worker 'Referral Coordinator'
					Therefore Current / Latest Worker may provide better information (as with Annex A Lists 6-8).  This is the approach used in Blackpool*/
	ce.cine_referral_team_name					AS AllocatedTeam,
    ce.cine_referral_worker_name				AS AllocatedWorker

INTO #AA_3_referrals

FROM
    ssd_development.ssd_cin_episodes ce

LEFT JOIN
    ssd_person p ON ce.cine_person_id = p.pers_person_id

LEFT JOIN
    (
        SELECT 
            cine_person_id,
            CASE -- referrals the child has received within the **12** months prior to their latest referral.
                WHEN COUNT(*) > 0 THEN COUNT(*) - 1
                ELSE 0
            END as count_12months
        FROM 
            ssd_development.ssd_cin_episodes
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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.5 Further edits of source obj referencing, Fixed to working state
            0.3: Removed old obj/item naming. 
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_disability
- ssd_cin_assessments
- @AA_ReportingPeriod
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_4_assessments') IS NOT NULL DROP TABLE #AA_4_assessments;


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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

    DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                THEN 1
                ELSE 0
            END									AS Age,

		/* List additional AA fields */
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
    a.cina_assessment_team_name							AS AllocatedTeam,
    a.cina_assessment_worker_name						AS AllocatedWorker

INTO #AA_4_assessments

FROM
    ssd_development.ssd_cin_assessments a

INNER JOIN
    ssd_person p ON a.cina_person_id = p.pers_person_id

/*PW - Amended as #ssd_disability table can have multiple records for a single child*/
LEFT JOIN   -- ensure we get all records even if there's no matching disability
    (
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			ssd_development.ssd_disability dis
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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_cp_plans
- ssd_disability
- ssd_immigration_status
- 
- @AA_ReportingPeriod
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_5_s47_enquiries') IS NOT NULL DROP TABLE #AA_5_s47_enquiries;


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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

    DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
            CASE 
                WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                THEN 1
                ELSE 0
            END									AS Age,

		/* List additional AA fields */
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END												AS HasDisability,
    
    /* Returns fields */
    FORMAT(s47e.s47e_s47_start_date, 'dd/MM/yyyy')	AS StratDiscussionDate,	-- Strategy discussion initiating Section 47 Enquiry Start Date	
    CASE																	-- Was an Initial Child Protection Conference deemed unnecessary?	
		WHEN s47e.s47e_s47_end_date is null then NULL
		WHEN s47e.s47e_s47_nfa = 'Yes' THEN 'a) Yes'
		WHEN s47e.s47e_s47_nfa = 'No' THEN 'b) No'
	END												AS InitialCPConfUnnecessary,
    FORMAT(icpc.icpc_icpc_date, 'dd/MM/yyyy')		AS InitialCPConfDate,	-- Date of Initial Child Protection Conference	

    -- [TESTING] 
    -- THESE FIELDS NEED CONFIRMNING
    -- CP_CONF FORMAT(s47e.icpc_date, 'dd/MM/yyyy')	AS formatted_icpc_date,     -- 
	CASE																			-- Did the Initial Child Protection Conference Result in a Child Protection Plan
		WHEN icpc.icpc_icpc_outcome_cp_flag = 'Y' THEN 'a) Yes'
		WHEN icpc.icpc_icpc_outcome_cp_flag = 'N' THEN 'b) No'
	END												AS CPConfResultInCPPlan,

    /* Aggregate fields */
    agg.CountS47s12m								AS NumberS47s12m,		-- Sum of Section 47 Enquiries in the last 12 months (NOT INCL. CURRENT)
    agg_icpc.CountICPCs12m							AS NumberICPCs12m,		-- Sum of ICPCs in the last 12 months  (NOT INCL. CURRENT)
	
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

LEFT JOIN  
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
			#ssd_s47_enquiry s47e
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
			#ssd_s47_enquiry s47e
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
	-- S47 open in last 6 months (includes those starting more that 6 months ago that were completed in last 6 months)
	COALESCE(s47e.s47e_s47_end_date,'99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE());	


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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming RH 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_disability
- ssd_legal_status
- ssd_care_leavers
- ssd_person
- ssd_cla_episodes
- ssd_cin_plans
- ssd_cp_plans
- ssd_cin_episodes 
- ssd_assessment_factors
- @AA_ReportingPeriod
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
        p.pers_person_id							AS ChildUniqueID,	
        CASE
            WHEN p.pers_sex = 'M' THEN 'a) Male'
            WHEN p.pers_sex = 'F' THEN 'b) Female'
            WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
            WHEN p.pers_sex = 'I' THEN 'd) Neither'
        END											AS Gender,
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
            ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
        END                                                 AS Ethnicity,
		FORMAT(p.pers_dob, 'dd/MM/yyyy')			AS DateOfBirth,

		DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
				CASE 
					WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
					THEN 1
					ELSE 0
				END									AS Age,

		/* List additional AA fields */
 
		CASE
			WHEN d.disa_person_id is not null THEN 'a) Yes'
			ELSE 'b) No'
		END											AS HasDisability,
		
		FORMAT(ce.cine_referral_date, 'dd/MM/yyyy')	AS CINStartDate,
		CASE
			WHEN ce.cine_cin_primary_need_code = 'N1' THEN 'N1 - Abuse or neglect'
			WHEN ce.cine_cin_primary_need_code = 'N2' THEN 'N2 - Child’s disability'
			WHEN ce.cine_cin_primary_need_code = 'N3' THEN 'N3 - Parental disability or illness'
			WHEN ce.cine_cin_primary_need_code = 'N4' THEN 'N4 - Family in acute stress'
			WHEN ce.cine_cin_primary_need_code = 'N5' THEN 'N5 - Family dysfunction'
			WHEN ce.cine_cin_primary_need_code = 'N6' THEN 'N6 - Socially unacceptable behaviour'
			WHEN ce.cine_cin_primary_need_code = 'N7' THEN 'N7 - Low income'
			WHEN ce.cine_cin_primary_need_code = 'N8' THEN 'N8 - Absent parenting'
			WHEN ce.cine_cin_primary_need_code = 'N9' THEN 'N9 - Cases other than children in need'
			WHEN ce.cine_cin_primary_need_code = 'N0' THEN 'N0 - Not stated'
		END											AS PrimaryNeedCode,		
		FORMAT(v.LatestVisit, 'dd/MM/yyyy')			AS DateChildLastSeen,		
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
		END											AS ReasonForClosure,		
		-- Case Status
		CASE
			WHEN ce.cine_close_date is not null THEN 	'e) Closed episode'
			WHEN lac.lega_person_id is not null THEN 	'a) Looked after child'
			WHEN cp.cppl_person_id is not null THEN 	'b) Child Protection plan'
			WHEN cin.cinp_person_id is not null THEN 	'c) Child in need plan'
			WHEN cl.clea_person_id is not null THEN 	'c) Child in need plan'
			WHEN ass.cina_person_id is not null THEN 	'd) Open assessment'
			ELSE 'c) Child in need plan'	-- Catch-all for any remaining cases not allocated a Case Status
		END											AS CaseStatus,
    
		inv.Team									AS AllocatedTeam, -- [TESTING] Should this be coming from cine.....
		inv.WorkerName								AS AllocatedWorker, -- [TESTING] Should this be coming from cine.....
		DENSE_RANK() OVER(PARTITION BY p.pers_person_id ORDER BY ce.cine_referral_date DESC, COALESCE(ce.cine_close_date,'99991231') DESC) Rnk

	FROM
		#ssd_cin_episodes ce

	INNER JOIN
		#ssd_person p ON ce.cine_person_id = p.pers_person_id	

	LEFT JOIN 
		(
			SELECT DISTINCT
				dis.disa_person_id 
			FROM
				#ssd_disability dis
			WHERE
				COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
		) AS d ON p.pers_person_id = d.disa_person_id

	-- added to get date child last seen (latest visit date - CIN, CP or CLA)
	-- Note - Blackpool ChAT also pulls information from certain Mosaic Case Note Types, Mosaic Visits Screen and Care Leaver Contact WorkflowSteps but these aren't in SSDS*/
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

	LEFT JOIN	-- Identify Children Looked After - note #ssd_legal_status used so children subject to Short Breaks can be excluded
		(
			SELECT DISTINCT
				ls.lega_person_id
			FROM
				#ssd_legal_status ls
			INNER JOIN
				#ssd_person p ON ls.lega_person_id = p.pers_person_id
			WHERE
				ls.lega_legal_status not in ('V1','V3','V4')	--Exclude children subject to Short Breaks
				AND ls.lega_legal_status_start_date <= GETDATE()
				AND COALESCE(ls.lega_legal_status_end_date,'99991231') > GETDATE()
				AND p.pers_dob > DATEADD(YEAR, -18, GETDATE())	--Exclude young people who have reached their 18th Birthday but LAC Episodes not ended
		) AS lac ON ce.cine_person_id = lac.lega_person_id

	LEFT JOIN	-- Identify Children subject to CP Plan
		(
			SELECT DISTINCT
				cp.cppl_person_id
			FROM
				#ssd_cp_plans cp
			WHERE
				cp.cppl_cp_plan_start_date <= GETDATE()
				AND COALESCE(cp.cppl_cp_plan_end_date,'99991231') > GETDATE()
		) AS cp ON ce.cine_person_id = cp.cppl_person_id

	LEFT JOIN	-- Identify Children subject to CIN Plan
		(
			SELECT DISTINCT
				cin.cinp_person_id
			FROM
				#ssd_cin_plans cin
			WHERE
				cin.cinp_cin_plan_start <= GETDATE()
				AND COALESCE(cin.cinp_cin_plan_end,'99991231') > GETDATE()
		) AS cin ON ce.cine_person_id = cin.cinp_person_id

	LEFT JOIN	-- Identify Children with open Assessment
		(
			SELECT DISTINCT
				ass.cina_person_id
			FROM
				#ssd_cin_assessments ass
			WHERE
				ass.cina_assessment_start_date <= GETDATE()
				AND COALESCE(ass.cina_assessment_auth_date,'99991231') > GETDATE()
		) AS ass ON ce.cine_person_id = ass.cina_person_id

	LEFT JOIN	-- Identify Care Leavers
		(
			SELECT DISTINCT
				cl.clea_person_id
			FROM
				#ssd_care_leavers cl
		) AS cl ON ce.cine_person_id = cl.clea_person_id

	-- Added to get latest allocatd Team and Worker
	LEFT JOIN
		(
			SELECT
				cine.cine_person_id PersonID,
				cine.cine_referral_id CINReferralID,

				-- cine.cine_referral_team_name -- [TESTING] Swap to this field
				-- cine.cine_referral_worker_name -- [TESTING] Swap to this field

				inv.invo_professional_team Team, -- 
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

	WHERE
	-- CIN Episodes open in last 6 months (includes those starting more that 6 months ago that were open in last 6 months)
		COALESCE(ce.cine_close_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())	
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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.9 JH excluded temporary OLA plans
            0.8 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming.
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:
Dependencies:
- ssd_person
- ssd_cp_plans
- ssd_disability
- ssd_cin_episodes
- ssd_professionals
- ssd_cp_visits
- @AA_ReportingPeriod
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
		p.pers_person_id											AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
        CASE
            WHEN p.pers_sex = 'M' THEN 'a) Male'
            WHEN p.pers_sex = 'F' THEN 'b) Female'
            WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
            WHEN p.pers_sex = 'I' THEN 'd) Neither'
        END                                                 AS Gender,
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
            ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
        END                                                 AS Ethnicity,
        FORMAT(p.pers_dob, 'dd/MM/yyyy')                    AS DateOfBirth,
 
        DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
                CASE
                    WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                    THEN 1
                    ELSE 0
                END                                         AS Age,
 
        /* List additional AA fields */
        CASE
            WHEN d.disa_person_id is not null THEN 'a) Yes'
            ELSE 'b) No'
        END                                                 AS HasDisability,
   
        /* Returns fields */    
        FORMAT(cp.cppl_cp_plan_start_date, 'dd/MM/yyyy')    AS ChildProtectionPlanStartDate,
        CASE
            WHEN cp.cppl_cp_plan_initial_category in ('NEG','Neglect') THEN 'a) Neglect'
            WHEN cp.cppl_cp_plan_initial_category in ('PHY','Physical abuse') THEN 'b) Physical abuse'
            WHEN cp.cppl_cp_plan_initial_category in ('SAB','Sexual abuse') THEN 'c) Sexual abuse'
            WHEN cp.cppl_cp_plan_initial_category in ('EMO','Emotional abuse') THEN 'd) Emotional abuse'
            WHEN cp.cppl_cp_plan_initial_category in ('MUL','Multiple/not recommended') THEN 'e) Multiple/not recommended'
        END                                                 AS InitialCategoryOfAbuse,
        CASE
            WHEN cp.cppl_cp_plan_latest_category in ('NEG','Neglect') THEN 'a) Neglect'
            WHEN cp.cppl_cp_plan_latest_category in ('PHY','Physical abuse') THEN 'b) Physical abuse'
            WHEN cp.cppl_cp_plan_latest_category in ('SAB','Sexual abuse') THEN 'c) Sexual abuse'
            WHEN cp.cppl_cp_plan_latest_category in ('EMO','Emotional abuse') THEN 'd) Emotional abuse'
            WHEN cp.cppl_cp_plan_latest_category in ('MUL','Multiple/not recommended') THEN 'e) Multiple/not recommended'
        END                                                 AS LatestCategoryOfAbuse,
        FORMAT(vis.VisitDate, 'dd/MM/yyyy')                 AS DateOfLastStatutoryVisit,
        CASE
            WHEN vis.VisitDate IS NULL then NULL
            WHEN vis.ChildSeenAlone in ('Yes','Y') THEN 'a) Yes'
            WHEN vis.ChildSeenAlone in ('No','N') THEN 'b) No'
            ELSE 'c) Unknown'
        END                                                 AS ChildSeenAlone,
        FORMAT(rev.ReviewDate, 'dd/MM/yyyy')                AS DateOfLatestReviewConf,
        FORMAT(cp.cppl_cp_plan_end_date, 'dd/MM/yyyy')      AS ChildProtectionPlanEndDate,
        CASE
            WHEN pr.lega_person_id is not null THEN 'a) Yes'
            ELSE 'b) No'
        END                                                 AS ProtectionLastSixMonths,
        aggcpp.CountPrevCPPlans                             AS NumberOfPreviousChildProtectionPlans,
        inv.Team                                            AS AllocatedTeam,
        inv.WorkerName                                      AS AllocatedWorker,
        DENSE_RANK() OVER(PARTITION BY p.pers_person_id ORDER BY cp.cppl_cp_plan_start_date DESC, COALESCE(cp.cppl_cp_plan_end_date,'99991231') DESC) Rnk
 
       
    FROM
        #ssd_cp_plans cp
 
    INNER JOIN
        #ssd_person p ON cp.cppl_person_id = p.pers_person_id  
 
    LEFT JOIN
        (
            SELECT DISTINCT
                dis.disa_person_id
            FROM
                #ssd_disability dis
            WHERE
                COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
        ) AS d ON p.pers_person_id = d.disa_person_id
 
    -- get latest visit and whether child was seen alone
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
                #ssd_cp_visits vis ON cp.cppl_person_id = vis.cppv_person_id
                AND cp.cppl_cp_plan_id = vis.cppv_cp_plan_id
                AND vis.cppv_cp_visit_date between cp.cppl_cp_plan_start_date and COALESCE(cp.cppl_cp_plan_end_date, GETDATE())
            WHERE
                COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        ) AS vis on cp.cppl_person_id = vis.PersonID
            AND cp.cppl_cp_plan_id = vis.CPRegID
            AND vis.Rnk = 1
 
    -- get latest review
    LEFT JOIN
        (
            SELECT
                cp.cppl_person_id PersonID,
                cp.cppl_cp_plan_id CPRegID,
                MAX(rev.cppr_cp_review_date) ReviewDate
            FROM
                #ssd_cp_plans cp
            INNER JOIN
                #ssd_cp_reviews rev ON cp.cppl_person_id = rev.cppr_person_id
                AND cp.cppl_cp_plan_id = rev.cppr_cp_plan_id
                AND rev.cppr_cp_review_date between cp.cppl_cp_plan_start_date and COALESCE(cp.cppl_cp_plan_end_date, GETDATE())
            WHERE
                COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            GROUP BY
                cp.cppl_person_id,
                cp.cppl_cp_plan_id
        ) AS rev on cp.cppl_person_id = rev.PersonID
            AND cp.cppl_cp_plan_id = rev.CPRegID
 
    -- get whether child subject to Emergency Protection Order or Protected Under Police Powers in Last Six Months
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
 
    -- get number of previous CP Plans.  NOTE - because this uses #ssd_cp_plans, only has details of CP Plans open in the last 6 years
    LEFT JOIN
        (
            SELECT
            -- Plans a child was previously subject to
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
 
    -- get latest allocatd Team and Worker
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
                #ssd_involvements inv ON cine.cine_person_id = inv.invo_person_id
                AND inv.invo_involvement_start_date <= COALESCE(cine.cine_close_date,'99991231')
                AND COALESCE(inv.invo_involvement_end_date,'99991231') > cine.cine_referral_date
            INNER JOIN
                #ssd_professionals pro ON inv.invo_professional_id = pro.prof_professional_id
            WHERE
                COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        ) AS inv on cp.cppl_person_id = inv.PersonID
            AND cp.cppl_cp_plan_id = inv.CPRegID
            AND inv.Rnk = 1
 
    WHERE
        -- CP Plans open in last 6 months (includes those starting more that 6 months ago that were open in last 6 months)
        COALESCE(cp.cppl_cp_plan_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        AND cp.cppl_cp_plan_ola <> 'Y'
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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.9 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming.
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks:
Dependencies:
- ssd_cp_plans
- ssd_disability
- ssd_immigration_status
- ssd_person
- cla_episode
- @AA_ReportingPeriod
=============================================================================
*/
-- Set reporting period in Mths
-- Set reporting period in Mths
 
--DECLARE @AA_ReportingPeriod INT;
--SET @AA_ReportingPeriod = 6; -- Mths
 
 
 
-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_8_children_in_care') IS NOT NULL DROP TABLE #AA_8_children_in_care;
 
 
SELECT
    /* Common AA fields */
    p.pers_person_id                                            AS ChildUniqueID,  
    CASE
        WHEN p.pers_sex = 'M' THEN 'a) Male'
        WHEN p.pers_sex = 'F' THEN 'b) Female'
        WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
        WHEN p.pers_sex = 'I' THEN 'd) Neither'
    END                                                         AS Gender,
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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')                            AS DateOfBirth,
 
    DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
            CASE
                WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                THEN 1
                ELSE 0
            END                                                 AS Age,
 
    /* List additional AA fields */
    CASE
        WHEN uasc.immi_person_id is not null THEN 'a) Yes'
        ELSE 'b) No'
    END                                                         AS UASC,
    CASE
        WHEN d.disa_person_id is not null THEN 'a) Yes'
        ELSE 'b) No'
    END                                                         AS HasDisability,
    FORMAT(clapl.LACStart, 'dd/MM/yyyy')                        AS LoookedAfterStartDate,
    claepi.CategoryOfNeed                                       AS ChildCategoryOfNeed,
    CASE
        WHEN subs.clae_person_id is not null THEN 'a) Yes'
        ELSE 'b) No'
    END                                                         AS SubsequentLACEpisodeLast12Months,
    FORMAT(clals.LSStartDate, 'dd/MM/yyyy')                     AS MostRecentLegalStatusStart,
    clals.LSCode                                                AS LegalStatus,
    rev.ReviewDate                                              AS LatestStatutoryReviewDate,
    vis.VisitDate                                               AS LastSocialWorkVisitDate,
    perm.CarePlan                                               AS PermanencePlan,
    /*
    CASE
        WHEN perm.lacp_cla_care_plan = 'Return to family' THEN 'a) Return to family'
        WHEN perm.lacp_cla_care_plan = 'Adoption' THEN 'b) Adoption'
        WHEN perm.lacp_cla_care_plan = 'SGO/CAO' THEN 'c) SGO/CAO'
        WHEN perm.lacp_cla_care_plan = 'Supported living in the community' THEN 'd) Supported living in the community'
        WHEN perm.lacp_cla_care_plan = 'Long-term residential placement' THEN 'e) Long-term residential placement'
        WHEN perm.lacp_cla_care_plan = 'Long-term fostering' THEN 'f) Long-term fostering'
        WHEN perm.lacp_cla_care_plan = 'other' THEN 'g) other'
    END                                                         AS PermanencePlan,
    */
    FORMAT(claepi.LatestIROVisit, 'dd/MM/yyyy')                 AS LastIROVisitDate,
    ha.HealthAssessmentDate                                     AS LastHealthAssessmentDate,
    dc.DentalCheckDate                                          AS LastDentalCheckDate,
    COALESCE(agglacp.CountCLAPlacements,1)                      AS PlacementsLast12Months,      /*PW - COALESCE because if latest episode is change of Legal Status or change of placement with same carer, and this is the only episode in last 12 months, would otherwise return NULL*/
    FORMAT(claepi.DateEpisodeCeased, 'dd/MM/yyyy')              AS CeasedLookedAfterDate,
    claepi.ReasonEpisodeCeased                                  AS ReasonCeasedLookedAfter,
    FORMAT(clapl.clap_cla_placement_start_date, 'dd/MM/yyyy')   AS MostRecentPlacementStartDate,
    clapl.clap_cla_placement_type                               AS PlacementType,
    clapl.clap_cla_placement_provider                           AS PlacementProvider,
    clapl.clap_cla_placement_postcode                           AS PlacementPostcode,
    clapl.clap_cla_placement_urn                                AS PlacementURN,
    /*CASE
        WHEN clapl.clap_cla_placement_la = 'BLACKPOOL' THEN 'a) In'
        ELSE 'b) Out'
    END                                                         AS PlacementLocation, /*PW - check v Annex A regarding Blank Placement LA*/
    clapl.clap_cla_placement_la                                 AS PlacementLA,
    */
    COALESCE(mis.MissingEpi,0)                                  AS EpisodesChildMissingFromPlacement,
    COALESCE(ab.AbsenceEpi,0)                                   AS EpisodesChildAbsentFromPlacement,    /*PW - COALESCE so 0 is reported if no Absent Episodes*/
    CASE
        WHEN rhi.PersonID is null then NULL
        WHEN rhi.miss_missing_rhi_offered in ('Y','Yes') THEN 'a) Yes'
        WHEN rhi.miss_missing_rhi_offered in ('N','No') THEN 'b) No'
        ELSE 'c) Unknown'
    END                                                         AS ChildOfferedReturnInterviewAfterLastMFH,
    CASE
        WHEN rhi.PersonID is null then NULL
        WHEN rhi.miss_missing_rhi_accepted in ('Y','Yes') THEN 'a) Yes'
        WHEN rhi.miss_missing_rhi_accepted in ('N','No') THEN 'b) No'
        ELSE 'c) Unknown'
    END                                                         AS ChildAcceptedReturnInterviewAfterLastMFH,
    inv.Team                                                    AS AllocatedTeam,
    inv.WorkerName                                              AS AllocatedWorker
 
 
INTO #AA_8_children_in_care
 
FROM
    -- get distinct Child IDs with latest LAC Placement details
    (
        SELECT
            clapl2.PersonID,
            clapl2.LACStart,
            clapl2.clap_cla_placement_start_date,
            clapl2.clap_cla_placement_end_date,
            clapl2.clap_cla_placement_type,
            clapl2.clap_cla_placement_provider,
            clapl2.clap_cla_placement_postcode,
            clapl2.clap_cla_placement_urn
        FROM
            (
                SELECT
                    clap.clap_person_id PersonID,
                    clae.clae_entered_care_date LACStart,
                    clap.clap_cla_placement_start_date,
                    clap.clap_cla_placement_end_date,
                    clap.clap_cla_placement_type,
                    clap.clap_cla_placement_provider,
                    clap.clap_cla_placement_postcode,
                    clap.clap_cla_placement_urn,
                    DENSE_RANK() OVER(PARTITION BY clap.clap_person_id
                                    ORDER BY clap.clap_cla_placement_start_date DESC,
                                        COALESCE(clap.clap_cla_placement_end_date,'99991231') DESC) Rnk
                FROM
                    #ssd_cla_placement clap
 
                LEFT JOIN #ssd_cla_episodes clae on clap.clap_cla_placement_id = clae.clae_cla_placement_id
 
                WHERE
                    COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            ) clapl2
        WHERE
            clapl2.Rnk = 1
    )
    clapl
INNER JOIN
    #ssd_person p ON clapl.PersonID = p.pers_person_id
 
LEFT JOIN  
    (
        SELECT DISTINCT
            dis.disa_person_id
        FROM
            #ssd_disability dis
        WHERE
            COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
    ) AS d ON p.pers_person_id = d.disa_person_id
 
-- added to get UASC
LEFT JOIN
    (
        SELECT DISTINCT
            uasc.immi_person_id
        FROM
            #ssd_immigration_status uasc
        WHERE
            uasc.immi_immigration_status = 'UASC'
            -- [TESTING]7174251
            --AND COALESCE(uasc.immi_immigration_status_end_date,'99991231') >= DATEADD(MONTH, -12 , GETDATE()) /*PW - Row commented out as giving error 'Arithmetic overflow error converting expression to data type datetime' (possibly because no records have end date)*/
    ) AS uasc ON p.pers_person_id = uasc.immi_person_id
 
-- get CIN Category of Need, Reason Ceased Looked After and Latest IRO Visit Date
LEFT JOIN
    (
        SELECT
            clae.clae_person_id PersonID,
            clae.clae_cla_episode_start CLAEpiStart,    /*PW - included as used in join later on to get Worker and Team*/
            clae.clae_cla_primary_need CategoryOfNeed,
            clae.clae_cla_episode_ceased DateEpisodeCeased,
            clae.clae_cla_episode_cease_reason ReasonEpisodeCeased,
            clae.clae_cla_last_iro_contact_date LatestIROVisit,
            DENSE_RANK() OVER(PARTITION BY clae.clae_person_id
                            ORDER BY clap.clap_cla_placement_start_date DESC,
                                        clae.clae_cla_episode_start DESC) Rnk
        FROM
            #ssd_cla_placement clap
        INNER JOIN
            #ssd_cla_episodes clae ON clap.clap_cla_id = clae.clae_cla_id
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            AND COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
    ) AS claepi on clapl.PersonID = claepi.PersonID
        AND claepi.Rnk = 1
 
-- get whether 2nd or subsequent period of LAC in previous 12 months.
LEFT JOIN
    (
        SELECT
            clae.clae_person_id,
            MIN(clae.clae_cla_episode_start) FirstLACStartDate
        FROM
            #ssd_cla_episodes clae
        INNER JOIN
            #ssd_legal_status leg on clae.clae_person_id = leg.lega_person_id
            AND clae.clae_cla_episode_start = leg.lega_legal_status_start_date
        WHERE
            clae.clae_cla_episode_start_reason = 'S'
            AND COALESCE(leg.lega_legal_status,'zzz') not in ('V1','V3','V4')   -- Exclude Short Breaks
            AND clae.clae_cla_episode_start >= DATEADD(MONTH, -12, GETDATE())
        GROUP BY
            clae.clae_person_id
    ) AS subs ON clapl.PersonID = subs.clae_person_id
        AND subs.FirstLACStartDate < clapl.LACStart
 
-- get Latest Legal Status and Latest Legal Status Start Date
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            clals.lega_legal_status LSCode,
            clap.clap_cla_placement_start_date PLstart,
            CAST(clals.lega_legal_status_start_date as date) LSStartDate,
            DENSE_RANK() OVER(PARTITION BY clap.clap_person_id
            ORDER BY clap.clap_cla_placement_start_date DESC, clals.lega_legal_status_start_date DESC) Rnk
        FROM
            #ssd_cla_placement clap
       
        LEFT JOIN
            #ssd_legal_status clals ON clap.clap_person_id = clals.lega_person_id
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            AND COALESCE(clals.lega_legal_status_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            AND clals.lega_legal_status IN (
                                    'Interim care order Sec. 38(1)',
                                    'Care Order Sec. 31(a)',
                                    'Wardship',
                                    'Child freed for adoption',
                                    'Placement Order (Sec. 21)',
                                    'Care Order Sec.31(a) & Placement Order (Sec. 21)',
                                    'Single placement acc. by LA S20(1) CA under 16',
                                    'Single placement acc. by LA S20(3) CA 16 & over',
                                    'Police protection power Sec.38(1)',
                                    'Emergency protection order - LA',
                                    'Child assessment order Sec. 43(1)',
                                    'Remanded to LA accommodation S20',
                                    'P.A.C.E Interview (CYP)',
                                    'S.43 CJA 91 Post-sent Und 22',
                                    'Regular occ. acc by LA S20(3) CA 16 & over',
                                    'regular occ. acc. by LA S.20(1) CA under 16') OR
                                    clals.lega_legal_status LIKE 'C.O. Extended S40(5) CA'
    ) AS clals on clapl.PersonID = clals.PersonID              
        AND clals.Rnk = 1
 
-- get latest Review
LEFT JOIN
    (  
        SELECT
            clap.clap_person_id PersonID,
            MAX(rev.clar_cla_review_date) ReviewDate
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_cla_episodes clae ON clap.clap_cla_placement_id = clae.clae_cla_placement_id
 
        INNER JOIN
            #ssd_cla_reviews rev ON clae.clae_cla_id = rev.clar_cla_id
 
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
            AND rev.clar_cla_review_date between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE())           --PW - Comment out if LAC Start Date not added to #ssd_cla_placement
            AND rev.clar_cla_review_cancelled not in ('Y','Yes')    /*Exclude Cancelled Reviews - note if clar_cla_review_cancelled field isn't populated in #ssd_cla_placement, this line will need to be commented out*/
        GROUP BY
            clap.clap_person_id
    ) AS rev on clapl.PersonID = rev.PersonID
 
-- get latest Visit
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            MAX(vis.clav_cla_visit_date) VisitDate
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_cla_visits vis ON clap.clap_person_id = vis.clav_person_id           ------- Invalid column name 'PersonID'
            AND vis.clav_cla_visit_date between clap.clap_cla_placement_start_date                   ------- Invalid column name 'LACStart'
             and COALESCE(clap.clap_cla_placement_end_date, GETDATE())
             /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
   
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        GROUP BY
            clap.clap_person_id                                                       ------- Invalid column name 'PersonID'
    ) AS vis on clapl.PersonID = vis.PersonID
 
-- get latest Permanence Plan
LEFT JOIN
    (
        SELECT
            lacp.lacp_person_id PersonID,                                             ------ Invalid column name 'PersonID'
            clap.clap_cla_placement_start_date,
            lacp.lacp_cla_care_plan_json CarePlan,                                              ------ Invalid column name 'lacp_cla_care_plan'
            DENSE_RANK() OVER(PARTITION BY lacp.lacp_person_id ORDER BY clap.clap_cla_placement_start_date DESC, lacp.lacp_cla_care_plan_start_date DESC, lacp.lacp_table_id DESC) Rnk
        FROM                                ------ Invalid column name 'PersonID' -----Invalid column name 'lacp_cla_care_plan'
            #ssd_cla_placement clap
       
        INNER JOIN
            #ssd_cla_episodes clae ON clap.clap_cla_placement_id = clae.clae_cla_placement_id
 
        INNER JOIN
            #ssd_cla_care_plan lacp ON clae.clae_person_id = lacp.lacp_person_id             ------- Invalid column name 'PersonID'
            AND lacp.lacp_cla_care_plan_start_date between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE                                                   ------ Invalid column name 'LACStart'
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
    ) AS perm on clapl.PersonID = perm.PersonID
        AND perm.Rnk = 1
 
-- get latest Health Assessment
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            MAX(h.clah_health_check_date) HealthAssessmentDate
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_cla_episodes clae ON clae.clae_cla_placement_id = clap.clap_cla_placement_id
 
        INNER JOIN
            #ssd_cla_health h ON clae.clae_person_id = h.clah_person_id
            AND h.clah_health_check_type in ('HEALTH', 'Health Assessment')
            AND h.clah_health_check_date between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE                                        
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        GROUP BY
            clap.clap_person_id                                                  
    ) AS ha on clapl.PersonID = ha.PersonID
 
-- get latest Dental Check
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,                                        
            MAX(h.clah_health_check_date) DentalCheckDate
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_cla_episodes clae ON clap.clap_cla_placement_id = clae.clae_cla_placement_id
 
        INNER JOIN
            #ssd_cla_health h ON clae.clae_person_id = h.clah_person_id          
            AND h.clah_health_check_type in ('DENTAL', 'Dental Check')
            AND h.clah_health_check_date between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE                                      
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        GROUP BY
            clap.clap_person_id
    ) AS dc on clapl.PersonID = dc.PersonID
 
-- get number of LAC Placements in previous 12 months.  Note #ssd_cla_episodes used so placements with same carer can be excluded
LEFT JOIN
    (
        SELECT
            clae.clae_person_id,
            COUNT(clae.clae_person_id) as CountCLAPlacements
        FROM
            #ssd_cla_episodes clae
        WHERE
            COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -12, GETDATE())
            AND (clae.clae_cla_episode_start_reason in ('S','P','B')
                OR (clae.clae_cla_episode_start <= DATEADD(MONTH, -12, GETDATE())   /*PW Additional clause to ensure initial placement from 12 months ago is counted if with same carer*/
                    AND clae.clae_cla_episode_ceased > DATEADD(MONTH, -12, GETDATE())
                    AND clae.clae_cla_episode_start_reason in ('T','U')))
        GROUP BY
            clae.clae_person_id
    ) AS agglacp ON clapl.PersonID = agglacp.clae_person_id
 
-- get number of Missing from Placement Episodes
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            clap.clap_cla_placement_start_date,
            COUNT(m.miss_table_id) MissingEpi,
            DENSE_RANK() OVER(PARTITION BY clap.clap_person_id, clap.clap_cla_placement_id ORDER BY clap.clap_cla_placement_start_date DESC, clap.clap_cla_placement_id DESC) Rnk
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_missing m ON clap.clap_person_id = m.miss_person_id
            AND m.miss_missing_episode_type in ('M', 'Missing')
            AND m.miss_missing_episode_start >= DATEADD(MONTH, -12, GETDATE())
            --AND m.miss_missing_episode_start between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        GROUP BY
            clap.clap_person_id, clap.clap_cla_placement_id, clap.clap_cla_placement_start_date
    ) AS mis ON clapl.PersonID = mis.PersonID
        AND clapl.clap_cla_placement_start_date = mis.clap_cla_placement_start_date
        AND mis.Rnk = 1
 
 
-- get number of Absence from Placement Episodes
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            clap.clap_cla_placement_start_date,
            COUNT(m.miss_table_id) AbsenceEpi,
            DENSE_RANK() OVER(PARTITION BY clap.clap_person_id, clap.clap_cla_placement_id ORDER BY clap.clap_cla_placement_start_date DESC, clap.clap_cla_placement_id DESC) Rnk
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_missing m ON clap.clap_person_id = m.miss_person_id
            AND m.miss_missing_episode_type in ('A', 'Absent','Away')
            AND m.miss_missing_episode_start >= DATEADD(MONTH, -12, GETDATE())
            AND m.miss_missing_episode_start between clap.clap_cla_placement_start_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        GROUP BY
            clap.clap_person_id, clap.clap_cla_placement_id, clap.clap_cla_placement_start_date
    ) AS ab ON clapl.PersonID = ab.PersonID
        AND clapl.clap_cla_placement_start_date = ab.clap_cla_placement_start_date
        AND ab.Rnk = 1
 
-- get latest Missing Episode Date and Return Interview details
LEFT JOIN
    (
        SELECT
            clap.clap_person_id PersonID,
            m.miss_missing_rhi_offered,
            m.miss_missing_rhi_accepted,
            DENSE_RANK() OVER(PARTITION BY clap.clap_person_id ORDER BY CASE WHEN m.miss_missing_episode_end is not null then 1 else 2 END, /*Gives priority to Completed Missing Episodes over Ongoing Missing Episodes so Return Interview Details are available*/
                                                    clap.clap_cla_placement_start_date DESC, m.miss_missing_episode_start DESC, m.miss_table_id DESC) Rnk
        FROM
            #ssd_cla_placement clap
 
        INNER JOIN
            #ssd_missing m ON clap.clap_person_id = m.miss_person_id
            AND m.miss_missing_episode_type in ('M', 'Missing')
            AND m.miss_missing_episode_start >= DATEADD(MONTH, -12, GETDATE())
            AND m.miss_missing_episode_start between clap.clap_cla_placement_start_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
        WHERE
            COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
    ) AS rhi ON clapl.PersonID = rhi.PersonID
        AND rhi.Rnk = 1
 
-- get latest allocatd Team and Worker
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
            #ssd_involvements inv ON cine.cine_person_id = inv.invo_person_id
            AND inv.invo_involvement_start_date <= COALESCE(cine.cine_close_date,'99991231')
            AND COALESCE(inv.invo_involvement_end_date,'99991231') > cine.cine_referral_date
        INNER JOIN
            #ssd_professionals pro ON inv.invo_professional_id = pro.prof_professional_id
        WHERE
            COALESCE(clae.clae_cla_episode_ceased, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
    ) AS inv on claepi.PersonID = inv.PersonID
        AND claepi.CLAEpiStart = inv.CLAEpiStart
        AND inv.Rnk = 1
 
 
WHERE
    clals.LSCode not in ('V1','V3','V4');   -- Exclude children subject to Short Breaks

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
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
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
	p.pers_person_id											AS ChildUniqueID,	/*PW - Field Name changed from p.pers_legacy_id as that doesn't match SSDS Spec*/
	CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END															AS Gender,
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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
	FORMAT(p.pers_dob, 'dd/MM/yyyy')							AS DateOfBirth,

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
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS HasDisability,

    clea.clea_care_leaver_allocated_team_name					AS AllocatedTeam, -- [TESTING]
	pro.prof_professional_name									AS AllocatedWorker, -- [TESTING]
	clea.clea_care_leaver_personal_advisor						AS AllocatedPersonalAdvisor,

	CASE
		WHEN clea.clea_care_leaver_eligibility in ('Relevant','Relevant child') then 'a) Relevant child'
		WHEN clea.clea_care_leaver_eligibility in ('Former Relevant','Former relevant child') then 'b) Former relevant child'
		WHEN clea.clea_care_leaver_eligibility in ('Qualifying','Qualifying care leaver') then 'c) Qualifying care leaver'
		WHEN clea.clea_care_leaver_eligibility in ('Eligible','Eligible child') then 'd) Eligible child'
	END															AS EligibilityCategory,
	FORMAT(clea.clea_pathway_plan_review_date, 'dd/MM/yyyy')	AS LatestPathwayPlan,
	CASE
		WHEN clea.clea_care_leaver_in_touch in ('YES', 'Y') THEN 'a) Yes'
		WHEN clea.clea_care_leaver_in_touch in ('NO', 'N') THEN 'b) No'
		WHEN clea.clea_care_leaver_in_touch in ('DIED') THEN 'c) Died'
		WHEN clea.clea_care_leaver_in_touch in ('REFU', 'Refused') THEN 'd) Refu'
		WHEN clea.clea_care_leaver_in_touch in ('NREQ', 'Not Required') THEN 'e) NREQ'
		WHEN clea.clea_care_leaver_in_touch in ('RHOM', 'Returned Home') THEN 'f) Rhom'
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
	END															AS TypeOfAccommodation,
	CASE
		WHEN clea.clea_care_leaver_accom_suitable in ('1', 'Yes', 'Y', 'Suitable') THEN 'a) Suitable'
		WHEN clea.clea_care_leaver_accom_suitable in ('2', 'No', 'N', 'Not Suitable', 'Unsuitable') THEN 'b) Unsuitable'
	END															AS SuitabilityOfAccommodation,
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
	END															AS ActivityStatus

INTO #AA_9_care_leavers

FROM
    #ssd_care_leavers clea

INNER JOIN
	#ssd_person p ON clea.clea_person_id = p.pers_person_id

LEFT JOIN  
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

-- get UASC
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

LEFT JOIN
-- [TESTING] field is renamed to _name, but is actually the ID field? 
	#ssd_professionals pro on clea.clea_care_leaver_worker_name = pro.prof_professional_id


-- [TESTING]
select * from #AA_9_care_leavers;




/* 
=============================================================================
Report Name: Ofsted List 10 - Adoption YYYY
Description: 
            "All those children who, in the 12 months before the inspection, 
            have: been adopted, had the decision that they should be placed 
            for adoption but they have not yet been adopted, had an adoption 
            decision reversed during the 12 months."

Author: D2I
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
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


SELECT
	/* Common AA fields */
	p.pers_person_id											AS ChildUniqueID,	
	NULL														AS FamilyID,	/*PW - Field Added (only in List 10).  Don't think Family ID is present in SSDS (Local adoptive family identifier for the adoptive family the child is matched or placed with)*/
	CASE
		WHEN p.pers_sex = 'M' THEN 'a) Male'
		WHEN p.pers_sex = 'F' THEN 'b) Female'
		WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
		WHEN p.pers_sex = 'I' THEN 'd) Neither'
	END															AS Gender,
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
        ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
    END                                                 AS Ethnicity,
	FORMAT(p.pers_dob, 'dd/MM/yyyy')							AS DateOfBirth,

	DATEDIFF(YEAR, p.pers_dob, GETDATE()) - 
			CASE 
				WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
				THEN 1
				ELSE 0
			END													AS Age,
 
    /* List additional AA fields */
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END															AS HasDisability,
	FORMAT(perm.perm_entered_care_date, 'dd/MM/yyyy')			AS EnteredCareDate,
	FORMAT(perm.perm_adm_decision_date, 'dd/MM/yyyy')			AS ADMSHOBPADecisionDate,
	FORMAT(perm.perm_placement_order_date, 'dd/MM/yyyy')		AS PlacementOrderDate,
	FORMAT(perm.perm_matched_date, 'dd/MM/yyyy')				AS MatchedForAdoptionDate,
	FORMAT(perm.perm_placed_for_adoption_date, 'dd/MM/yyyy')	AS PlacedForAdoptionDate,
	FORMAT(perm.perm_permanence_order_date, 'dd/MM/yyyy')		AS AdoptionOrderDate,
	FORMAT(perm.perm_decision_reversed_date, 'dd/MM/yyyy')		AS DecisionReversedDate,
	CASE
		WHEN perm.perm_decision_reversed_reason = 'RD1' THEN 'RD1 - The child’s needs changed subsequent to the decision'
		WHEN perm.perm_decision_reversed_reason = 'RD2' THEN 'RD2 - The Court did not make a placement order'
		WHEN perm.perm_decision_reversed_reason = 'RD3' THEN 'RD3 - Prospective adopters could not be found'
		WHEN perm.perm_decision_reversed_reason = 'RD4' THEN 'RD4 - Any other reason'
	END															AS DecisionReversedReason,
	FORMAT(perm.perm_placed_ffa_cp_date, 'dd/MM/yyyy')			AS DateFFAConsurrencyPlacement
	

INTO #AA_10_adoption

FROM
	#ssd_permanence perm

INNER JOIN
	#ssd_person p ON perm.perm_person_id = p.pers_person_id

LEFT JOIN  
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

/*PW - Commented out as FamilyID in Ofsted List 10 isn't the same FamilyID as #ssd_family - List 10 is 'Local adoptive family identifier for the adoptive family the child is matched or placed with’ i.e. an identifier for the adopter, which allows for cross-matching with List 11*/
/*
LEFT JOIN   -- family table
    #ssd_family fam ON perm.perm_person_id = fam.fami_person_id
*/

WHERE
	perm.perm_adm_decision_date is not null		-- restricts to Adoption Cases and ignores other Legal Orders
	AND 
		(
			-- 12 month period as opposed to the 6 month period used in other lists
			perm.perm_permanence_order_date >= DATEADD(MONTH, -12, GETDATE()) OR					-- Adopted in previous 12 months
			perm.perm_decision_reversed_date >= DATEADD(MONTH, -12, GETDATE()) OR					-- Decision Reversed in previous 12 months
			(perm.perm_permanence_order_date is null and perm.perm_decision_reversed_date is null)	-- Current Adoption Cases
		)


-- [TESTING]
select * from #AA_10_adoption;




/* 
=============================================================================
Report Name: Ofsted List 11 - Adopters YYYY
Description: 
            "All those individuals who in the 12 months before the inspection 
            have had contact with the local authority adoption agency"

Author: D2I
Last Modified Date: 030324 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
			0.9 PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming. 
Status: [Dev, Testing, Release, Blocked, *AwaitingReview, Backlog]
Remarks: Incomplete as required data not held within the ssd and beyond 
            project scope. 
Dependencies: 
- ssd_person
- ssd_permanence
- ssd_disability
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('tempdb..#AA_11_adopters') IS NOT NULL DROP TABLE #AA_11_adopters;


SELECT
    /* Common AA fields */
    p.pers_person_id                            AS AdopterID,      -- Individual adopter identifier  Field Name changed from p.pers_legacy_id
    --  fam.fami_person_id            -- IS this coming from fc.DIM_PERSON_ID AS fami_person_id, as doesnt seem valid context
    p.pers_sex                                  AS Gender,
    p.pers_ethnicity                            AS Ethnicity,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DateOfBirth, --  note: returns string representation of the date
    
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
    END                                         AS Age, 

    /* List additional AA fields */
	CASE
		WHEN d.disa_person_id is not null THEN 'a) Yes'
		ELSE 'b) No'
	END			  

    perm.perm_adopted_by_carer_flag             AS AdoptedByCarer, -- Is the (prospective) adopter fostering for adoption?
    '1900-01-01'                                AS EnquiryDate,         -- Date enquiry received
    '1900-01-01'                                AS Stage1StartDate,     -- Date Stage 1 started
    '1900-01-01'                                AS Stage1EndDate,       -- Date Stage 1 ended
    '1900-01-01'                                AS Stage2StartDate,     -- Date Stage 2 started
    '1900-01-01'                                AS Stage2EndDate,       -- Date Stage 2 ended
    '1900-01-01'                                AS ApplicationDate,     -- Date application submitted
    '1900-01-01'                                AS ApplicationApprDate, -- Date application approved
    perm.perm_matched_date                      AS MatchedDate, 		-- Date adopter matched with child(ren)
    perm.perm_placed_for_adoption_date          AS PlacedDate, 			-- Date child/children placed with adopter(s)
    perm.perm_siblings_placed_together          AS NumSiblingsPlaced, 	-- No. of children placed
    perm.perm_permanence_order_date             AS AdoptionOrderDate, 	-- Date of Adoption Order
    perm.perm_decision_reversed_date            AS AdoptionLeaveDate, 	-- Date of leaving adoption process
    perm.perm_decision_reversed_reason          AS AdoptingLeaveReason	-- Reason for leaving adoption process

INTO #AA_11_adopters

FROM
    #ssd_permanence perm

INNER JOIN
    #ssd_person p ON perm.perm_person_id = p.pers_person_id

LEFT JOIN  
	(
		SELECT DISTINCT
			dis.disa_person_id 
		FROM
			#ssd_disability dis
		WHERE
			COALESCE(dis.disa_disability_code, 'NONE') <> 'NONE'
	) AS d ON p.pers_person_id = d.disa_person_id

LEFT JOIN
    #ssd_contacts c ON perm.perm_person_id = c.cont_person_id 

WHERE
    c.cont_contact_start >= DATEADD(MONTH, -12, GETDATE()) -- Filter on last 12 months