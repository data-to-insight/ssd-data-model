USE HDM;
GO


-- Set reporting period in Mths
DECLARE @903_ReportingPeriod INT;
SET @903_ReportingPeriod = 12; -- Mths





/*
****************************************
SSD 903 Returns Queries || SQL Server
****************************************
*/

-- The extract has been based on the specification available at:
-- https://assets.publishing.service.gov.uk/media/644a929bfaf4aa000ce12fd9/CLA_SSDA903_2023-24_Technical_specification_Version_1.1.pdf

/* 
=============================================================================
Report Name: 903 [1] - header
Description: 
            ""

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_person
- ssd_mother
- ssd_send (this temporary. SSD route for UPN is via ssd_linked_identifiers)
=============================================================================
*/

-- Check if exists & drop
IF OBJECT_ID('SSDA903_1_header') IS NOT NULL DROP TABLE SSDA903_1_header;
IF OBJECT_ID('tempdb..#SSDA903_header') IS NOT NULL DROP TABLE #SSDA903_1_header;

-- Ref default file headers from guidance
-- CHILD,SEX,DOB,ETHNIC,UPN,MOTHER,MC_DOB


SELECT
    p.pers_legacy_id                            AS CHILD,
    p.pers_sex                                  AS SEX,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DOB, -- if date not available assume that it was the 15th of the month.
    p.pers_ethnicity                            AS ETHNIC,
    sen.send_upn                                AS UPN,
    p.pers_is_mother                            AS MOTHER,
    FORMAT(moth.moth_childs_dob , 'dd/MM/yyyy') AS MC_DOB

INTO SSDA903_header

FROM
    ssd_person p

LEFT JOIN 
    ssd_send sen ON p.pers_person_id = sen.send_person_id 

LEFT JOIN 
    ssd_mother moth ON p.pers_person_id = moth.moth_person_id;

-- Dev notes: How/on what date field are we filtering this back to 31st march? 

-- -- [TESTING]
-- select * from SSDA903_header;






/* 
=============================================================================
Report Name: 903 [2] - adoption AD1
Description: 
            "Children adopted from care during the year only.
            This comprises of the ‘AD1’ file. To be completed in respect of 
            children for whom the decision is made, either during the current 
            year, or in a previous year where the decision is still valid, 
            that the child should be placed for adoption or for whom the 
            decision is made during the year that the child should no longer 
            be placed for adoption"

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 
- ssd_permanance
- ssd_person
=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('SSDA903_adoption') IS NOT NULL DROP TABLE SSDA903_adoption;
IF OBJECT_ID('tempdb..#SSDA903_adoption') IS NOT NULL DROP TABLE #SSDA903_adoption;

-- Ref default file headers from guidance
-- CHILD,DOB,DATE_INT,DATE_MATCH,FOSTER_CARE,NB_ADOPTR,SEX_ADOPTR,LS_ADOPTR

SELECT
    perm.perm_person_id                 AS CHILD,
    p.pers_dob                          AS DOB,
    perm.perm_placement_order_date      AS DATE_INT,    -- Date of decision child should be placed for adoption
    perm.perm_matched_date              AS DATE_MATCH,
    perm.perm_placed_foster_carer_date  AS FOSTER_CARE, -- (perm_placed_ffa_cp_date?)
    perm.perm_number_of_adopters        AS NB_ADOPTR,   -- Number of adopters
    perm.perm_adopter_sex               AS SEX_ADOPTR,
    perm.perm_adopter_legal_status      AS LS_ADOPTR

INTO SSDA903_adoption

FROM 
    ssd_permanence perm


LEFT JOIN   -- person table for core dets
    ssd_person p ON perm.perm_person_id = p.pers_person_id

WHERE
    -- Filter on last 12 months
    perm.perm_placement_order_date          >= DATEADD(MONTH, -12, GETDATE())
    OR perm.perm_placed_for_adoption_date   >= DATEADD(MONTH, -12, GETDATE())
    OR perm.perm_decision_reversed_date     >= DATEADD(MONTH, -12, GETDATE());

-- -- [TESTING]
-- select * from SSDA903_adoption;





/* 
=============================================================================
Report Name: 903 [3] - children_ceased_care_during_year
Description: 
            ""
Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('SSDA903_children_ceased_care_during_year') IS NOT NULL DROP TABLE SSDA903_children_ceased_care_during_year;
IF OBJECT_ID('tempdb..#SSDA903_children_ceased_care_during_year') IS NOT NULL DROP TABLE #SSDA903_children_ceased_care_during_year;

-- Ref default file headers from guidance
-- CHILD_LA_CODE	SEX	ETHNIC_CODE	DOB	LEGAL_STATUS	DATE_PERIOD_OF_CARE_CEASED	PLACEMENT_TYPE


-- -- [TESTING]
-- select * from SSDA903_children_ceased_care_during_year;




/* 
=============================================================================
Report Name: 903 [4] - children_ceasing_to_be_looked_after_for_other_reasons
Description: 
            ""

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('SSDA903_children_ceasing_to_be_looked_after_for_other_reasons') IS NOT NULL DROP TABLE SSDA903_children_ceasing_to_be_looked_after_for_other_reasons;
IF OBJECT_ID('tempdb..#SSDA903_children_ceasing_to_be_looked_after_for_other_reasons') IS NOT NULL DROP TABLE #SSDA903_children_ceasing_to_be_looked_after_for_other_reasons;

-- Ref default file headers from example file
-- CHILD	DOB	SDQ_SCORE	SDQ_REASON	CONVICTED	HEALTH_CHECK	IMMUNISATIONS	TEETH_CHECK	HEALTH_ASSESSMENT	SUBSTANCE_MISUSE	INTERVENTION_RECEIVED	INTERVENTION_OFFERED

-- Sample:
-- P4047769	28/12/2004	14		0		1	0	1	0
-- P4056573	31/12/2004		SDQ1	0		1	0	0	0
-- P4096636	22/05/2006	18		0		1	0	1	1




-- -- [TESTING]
-- select * from SSDA903_children_ceasing_to_be_looked_after_for_other_reasons;




/* 
=============================================================================
Report Name: 903 [5] - children_looked_after_on_31st_March
Description: 
            ""

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('SSDA903_children_looked_after_on_31st_March') IS NOT NULL DROP TABLE SSDA903_children_looked_after_on_31st_March;
IF OBJECT_ID('tempdb..#SSDA903_children_looked_after_on_31st_March') IS NOT NULL DROP TABLE #SSDA903_children_looked_after_on_31st_March;

-- Ref default file headers from example file
-- CHILD_LA_CODE	DECOM	SEX	LEGAL_STATUS	CIN	PLACEMENT_TYPE	DOB	ETHNIC_CODE

-- -- [TESTING]
-- select * from SSDA903_children_looked_after_on_31st_March;





/* 
=============================================================================
Report Name: 903 [6] - children_started_care_during_year
Description: 
            ""

Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('SSDA903_children_started_care_during_year') IS NOT NULL DROP TABLE SSDA903_children_started_care_during_year;
IF OBJECT_ID('tempdb..#SSDA903_children_started_care_during_year') IS NOT NULL DROP TABLE #SSDA903_children_started_care_during_year;

-- Ref default file headers from example file
-- CHILD_LA_CODE	SEX	ETHNIC_CODE	DOB	LEGAL_STATUS	POC_START	PLACEMENT_TYPE

-- -- [TESTING]
-- select * from SSDA903_children_started_care_during_year;






/* 
=============================================================================
Report Name: 903 [7] - distance_and_Placement_Extended
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [**Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_distance_and_Placement_Extended') IS NOT NULL DROP TABLE #SSDA903_distance_and_Placement_Extended;

-- Ref default file headers from example file
-- CHILD_LA_CODE	SEX	ETHNIC_CODE	UASC_STATUS	DOB	PL_DISTANCE	LA_PLACEMENT	row_id	D_LAST_POC	D_DEC	REC

SELECT
    p.pers_legacy_id                            AS CHILD,
    p.pers_sex                                  AS SEX,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')            AS DOB, -- if date not available assume that it was the 15th of the month.
    p.pers_ethnicity                            AS ETHNIC,
    ims.immi_immigration_status                 AS UASC_STATUS,
    clap.clap_cla_placement_distance            AS PL_DISTANCE,
    clap.clap_cla_placement_la                  AS LA_PLACEMENT,
    clap.clap_cla_placement_postcode            AS D_LAST_POC,
    --                                            AS D_DEC,
    --                                            AS REC

INTO #SSDA903_header

FROM
-- in progress
    #ssd_cla_placement clap
    #ssd_immigration_status ims  (ssd_immigration_status.immi_person_id)
    #ssd_person p
    #ssd_cla_episodes (clae_cla_episode_id, clae_person_id,clae_cla_id)

LEFT JOIN #ssd_send sen ON p.pers_person_id = sen.send_person_id 



-- -- [TESTING]
-- select * from #SSDA903_distance_and_Placement_Extended;



/* 
=============================================================================
Report Name: 903 [8] - episodes
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_episodes') IS NOT NULL DROP TABLE #SSDA903_episodes;

-- Ref default file headers from example file
-- CHILD	DECOM	RNE	LS	CIN	PLACE	PLACE_PROVIDER	DEC	REC	REASON_PLACE_CHANGE	HOME_POST	PL_POST	URN




-- -- [TESTING]
-- select * from #SSDA903_episodes;



/* 
=============================================================================
Report Name: 903 [9] - extended_adoption
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_extended_adoption') IS NOT NULL DROP TABLE #SSDA903_extended_adoption;

-- Ref default file headers from example file
-- CHILD_LA_CODE	SEX	ETHNIC_CODE	UASC_STATUS	DOB	Date_LA_Decision	Date_placement_order	Date_adoptive_placement	PLACEMENT	DATE_MATCHED	FORMER_FOSTER_ID	Number_Adopter	SEX_ADOPTER	LS_ADOPTER	Date_last_POC	DEC	REC

-- -- [TESTING]
-- select * from #SSDA903_extended_adoption;





/* 
=============================================================================
Report Name: 903 [10] - extended_review
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_extended_review') IS NOT NULL DROP TABLE #SSDA903_extended_review;

-- Ref default file headers from example file
-- CHILD_LA_CODE	SEX	ETHNIC_CODE	UASC_STATUS	DOB	REVIEW_DATE	PARTICIPATION	D_LAST_POC	D_DEC	REC


-- -- [TESTING]
-- select * from #SSDA903_extended_review;




/* 
=============================================================================
Report Name: 903 [11] - leaving care
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_leaving_care') IS NOT NULL DROP TABLE #SSDA903_leaving_care;

-- Ref default file headers from example file
-- CHILD	DOB	IN_TOUCH	ACTIV	ACCOM



-- -- [TESTING]
-- select * from #SSDA903_leaving_care;


/* 
=============================================================================
Report Name: 903 [12] - missing_away_from_placement
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_missing_away_from_placement') IS NOT NULL DROP TABLE #SSDA903_missing_away_from_placement;

-- Ref default file headers from example file
-- CHILD	DOB	MISSING	MIS_START	MIS_END


-- -- [TESTING]
-- select * from #SSDA903_missing_away_from_placement;



/* 
=============================================================================
Report Name: 903 [13] - Outcomes (‘OC2’) load
Description: 
            "To be completed in respect of children who were looked after 
at 31 March and had been looked after continuously for at least the previous 
twelve months only."

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_oc2') IS NOT NULL DROP TABLE #SSDA903_oc2;

-- Ref default file headers from example file
-- CHILD	DOB	SDQ_SCORE	SDQ_REASON	CONVICTED	HEALTH_CHECK	IMMUNISATIONS	TEETH_CHECK	HEALTH_ASSESSMENT	SUBSTANCE_MISUSE	INTERVENTION_RECEIVED	INTERVENTION_OFFERED


-- INTO #SSDA903_



-- -- [TESTING]
-- select * from #SSDA903_oc2;



/* 
=============================================================================
Report Name: 903 [14] - previous_permamence
Description: 
            ""

Author: D2I
Last Modified Date: 12/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_previous_permamence') IS NOT NULL DROP TABLE #SSDA903_previous_permamence;

-- Ref default file headers from example file
-- CHILD	DOB	PREV_PERM	LA_PERM	DATE_PERM
	
SELECT
    pp.lapp_person_id                     AS CHILD,
    FORMAT(p.pers_dob, 'dd/MM/yyyy')      AS DOB,
    pp.lapp_previous_permanence_option    AS PREV_PERM,
    pp.lapp_previous_permanence_la        AS LA_PERM,
    FORMAT(
        CAST(   -- unpack and format the stored json date(Str vals)
                -- initially as as a standard, unambiguous date format
            JSON_VALUE(pp.lapp_previous_permanence_order_date_json, '$.ORDERYEAR') 
            + '-' 
            + JSON_VALUE(pp.lapp_previous_permanence_order_date_json, '$.ORDERMONTH') 
            + '-' 
            + JSON_VALUE(pp.lapp_previous_permanence_order_date_json, '$.ORDERDATE') 
            AS DATE
        ), 
        'dd/MM/yyyy'    -- into requ reporting format
    ) AS DATE_PERM

INTO #SSDA903_previous_permamence

FROM ssd_cla_previous_permanence pp

LEFT JOIN ssd_person p ON pp.lapp_person_id = p.person_id;



-- -- [TESTING]
-- select * from #SSDA903_previous_permamence;






/* 
=============================================================================
Report Name: 903 [15] - pupil_premium_children
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_pupil_premium_children') IS NOT NULL DROP TABLE #SSDA903_pupil_premium_children;

-- Ref default file headers from example file
-- CHILD_LA_ID	SEX	DOB	ETHNIC	UPN	AGE_31AUG


-- -- [TESTING]
-- select * from #SSDA903_pupil_premium_children;






/* 
=============================================================================
Report Name: 903 [16] - reviews
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_reviews') IS NOT NULL DROP TABLE #SSDA903_reviews;

-- CHILD	DOB	REVIEW	REVIEW_CODE

-- Create structure
CREATE TABLE ssd_cp_reviews
(
    cppr_cp_review_id                   NVARCHAR(48) PRIMARY KEY,
    cppr_person_id                      NVARCHAR(48),
    cppr_cp_plan_id                     NVARCHAR(48),    
    cppr_cp_review_due                  DATETIME NULL,
    cppr_cp_review_date                 DATETIME NULL,
    cppr_cp_review_meeting_id           NVARCHAR(48),      
    cppr_cp_review_outcome_continue_cp  NCHAR(1),
    cppr_cp_review_quorate              NVARCHAR(18),      
    cppr_cp_review_participation        NVARCHAR(18)        -- ['PLACEHOLDER_DATA'][TESTING] - ON HOLD/Not included in SSD Ver/Iteration 1
);

LEFT JOIN   -- person table for core dets
    #ssd_person p ON cppr.cppr_person_id = p.pers_person_id


-- -- [TESTING]
-- select * from #SSDA903_reviews;






/* 
=============================================================================
Report Name: 903 [17] - should_be_placed_for_adoption
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_should_be_placed_for_adoption') IS NOT NULL DROP TABLE #SSDA903_should_be_placed_for_adoption;


-- CHILD	DOB	DATE_PLACED	DATE_PLACED_CEASED	REASON_PLACED_CEASED

-- scaffolding in progress RH

    perm_person_id  AS CHILD,
    FORMAT(p.pers_dob, 'dd/MM/yyyy') AS DOB, -- dd/mm/yyyy      
            
    -- perm_cla_id                   
    -- perm_entered_care_date                     
    -- perm_adm_decision_date              
    -- perm_ffa_cp_decision_date                      
    -- perm_placement_order_date         
    -- perm_matched_date                   
    -- perm_placed_for_adoption_date                   

    -- perm_placed_ffa_cp_date           
  
    -- perm_decision_reversed_date                       
    -- perm_decision_reversed_reason        
    -- perm_permanence_order_date                      
    -- perm_permanence_order_type               

FROM 
    ssd_permanence

LEFT JOIN   -- person table for core dets
    #ssd_person p ON perm.perm_person_id = p.pers_person_id

-- -- [TESTING]
-- select * from #SSDA903_should_be_placed_for_adoption;





/* 
=============================================================================
Report Name: 903 [18] - uasc
Description: 
            ""

Author: D2I
Last Modified Date: 09/02/24 RH
DB Compatibility: SQL Server 2014+|...
Version: 1.0
Status: [*Dev, Testing, Release, Blocked, AwaitingReview, Backlog]
Remarks: 
Dependencies: 

=============================================================================
*/
-- Check if exists & drop
IF OBJECT_ID('tempdb..#SSDA903_uasc') IS NOT NULL DROP TABLE #SSDA903_uasc;

-- CHILD	SEX	DOB	DUC

--
-- scaffolding in progress RH
SELECT
    imms.immi_person_id  AS CHILD,
    CASE -- shows as 1,2,... in return
		WHEN p.pers_sex = 'M' THEN 1
		WHEN p.pers_sex = 'F' THEN 2
		ELSE NULL
	END	AS SEX,
    FORMAT(p.pers_dob, 'dd/MM/yyyy') AS DOB, -- dd/mm/yyyy

    FORMAT(imms.immi_immigration_status_end) AS DUC, -- ceased uasc (or >18yrs)


from ssd_immigration_status imms

LEFT JOIN   -- person table for core dets
    #ssd_person p ON imms.immi_person_id = p.pers_person_id

-- where child is LAC within 31st MArch


-- -- [TESTING]
-- select * from #SSDA903_uasc;



-- https://assets.publishing.service.gov.uk/media/642d3bb6ddf8ad0013ac0dfc/CLA_SSDA903_2022-23_Guide_Version_1.2.pdf
-- The aim of the SSDA903 return is to collect information about children who are lookedafter by local authorities during the year ending 31 March 2023; and activity and 
-- accommodation for those who have recently left care (aged 17-25).
-- An SSDA903 return is required for two groups of children:
-- • Every child who is looked-after by your local authority at any time during the year
-- ending 31 March 2023
-- • Relevant and former relevant young people whose 17th to 25th birthday falls within
-- the collection period. For the 2022 to 2023 collection, this therefore covers young
-- people whose date of birth fell between 1 April 1997 and 31 March 2006