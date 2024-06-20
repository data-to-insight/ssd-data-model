
-- This is running, but a safety copy before re-working with unique checks within sub query blocks.



/*
ANNEX A

tool provided as part of the
STANDARD SAFEGUARDING DATASET EXTRACT 
https://data-to-insight.github.io/ssd-data-model/

Script creates DfE AnnexA outputs list 1->10 from the SSD structure. 
Prerequisit(s): The SSD extract must have been run/set up before running this tool.
List queries L1-10 might need to be run seperately, or output to a file(not provided) in order to view the outputs. 
Each list populates a temporary table of the extracted data to enable additional peocessing/monitoring to be 
undertaken. 
*/


/* **********************************************************************************************************

Notes: 
-

There remain some [TESTING] [REVIEW] notes as the project iterates wider testing results. 

/*
Dev Objact & Item Status Flags (~in this order):
Status:     [B]acklog,          -- To do|for review but not current priority
            [D]ev,              -- Currently being developed 
            [T]est,             -- Dev work being tested/run time script tests
            [DT]ataTesting,     -- Sense checking of extract data ongoing
            [AR]waitingReview,   -- Hand-over to SSD project team for review
            [R]elease,          -- Ready for wider release and secondary data testing
            [Bl]ocked,          -- Data is not held in CMS/accessible, or other stoppage reason
            [P]laceholder       -- Data not held by any LA, new data, - Future structure added as placeholder
*/

Development notes:
Currently in [REVIEW]
- 
********************************************************************************************************** */

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
Report Name: Ofsted List 8 - Children in Care YYYY
Description:
            "All children in care at the point of inspection. Include all
            those children who ceased to be looked after in the six months
            before the inspection."
 
Author: D2I
DB Compatibility: SQL Server 2014+|...
Version: 1.0
            0.9: PW/Blackpool major edits/reworked PW 030324
            0.3: Removed old obj/item naming.
Status: [DT]DataTesting
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
 
 ;WITH CTE AS ( -- [TESTING] Added to remove dups in output alongside CTE
    SELECT
        p.pers_person_id AS ChildUniqueID,  
        CASE
            WHEN p.pers_sex = 'M' THEN 'a) Male'
            WHEN p.pers_sex = 'F' THEN 'b) Female'
            WHEN p.pers_sex = 'U' THEN 'c) Not stated/recorded'
            WHEN p.pers_sex = 'I' THEN 'd) Neither'
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
            ELSE 'u) UNKNOWN' /*PW - 'Catch All' for any other Ethnicities not in above list; updated to 'u) UNKNOWN'*/
        END AS Ethnicity,
        FORMAT(p.pers_dob, 'dd/MM/yyyy') AS DateOfBirth,
        DATEDIFF(YEAR, p.pers_dob, GETDATE()) -
            CASE
                WHEN GETDATE() < DATEADD(YEAR,DATEDIFF(YEAR,p.pers_dob,GETDATE()), p.pers_dob)
                THEN 1
                ELSE 0
            END AS Age,
        CASE
            WHEN uasc.immi_person_id is not null THEN 'a) Yes'
            ELSE 'b) No'
        END AS UASC,
        CASE
            WHEN d.disa_person_id is not null THEN 'a) Yes'
            ELSE 'b) No'
        END AS HasDisability,
        FORMAT(clapl.LACStart, 'dd/MM/yyyy') AS LoookedAfterStartDate,
        claepi.CategoryOfNeed AS ChildCategoryOfNeed,
        CASE
            WHEN subs.clae_person_id is not null THEN 'a) Yes'
            ELSE 'b) No'
        END AS SubsequentLACEpisodeLast12Months,
        FORMAT(clals.LSStartDate, 'dd/MM/yyyy') AS MostRecentLegalStatusStart,
        clals.LSCode AS LegalStatus,
        rev.ReviewDate AS LatestStatutoryReviewDate,
        vis.VisitDate AS LastSocialWorkVisitDate,
        perm.CarePlan AS PermanencePlan,
        FORMAT(claepi.LatestIROVisit, 'dd/MM/yyyy') AS LastIROVisitDate,
        ha.HealthAssessmentDate AS LastHealthAssessmentDate,
        dc.DentalCheckDate AS LastDentalCheckDate,
        COALESCE(agglacp.CountCLAPlacements,1) AS PlacementsLast12Months,
        FORMAT(claepi.DateEpisodeCeased, 'dd/MM/yyyy') AS CeasedLookedAfterDate,
        claepi.ReasonEpisodeCeased AS ReasonCeasedLookedAfter,
        FORMAT(clapl.clap_cla_placement_start_date, 'dd/MM/yyyy') AS MostRecentPlacementStartDate,
        clapl.clap_cla_placement_type AS PlacementType,
        clapl.clap_cla_placement_provider AS PlacementProvider,
        clapl.clap_cla_placement_postcode AS PlacementPostcode,
        clapl.clap_cla_placement_urn AS PlacementURN,
        COALESCE(mis.MissingEpi,0) AS EpisodesChildMissingFromPlacement,
        COALESCE(ab.AbsenceEpi,0) AS EpisodesChildAbsentFromPlacement,
        CASE
            WHEN rhi.PersonID is null then NULL
            WHEN rhi.miss_missing_rhi_offered in ('Y','Yes') THEN 'a) Yes'
            WHEN rhi.miss_missing_rhi_offered in ('N','No') THEN 'b) No'
            ELSE 'c) Unknown'
        END AS ChildOfferedReturnInterviewAfterLastMFH,
        CASE
            WHEN rhi.PersonID is null then NULL
            WHEN rhi.miss_missing_rhi_accepted in ('Y','Yes') THEN 'a) Yes'
            WHEN rhi.miss_missing_rhi_accepted in ('N','No') THEN 'b) No'
            ELSE 'c) Unknown'
        END AS ChildAcceptedReturnInterviewAfterLastMFH,
        inv.Team AS AllocatedTeam,
        inv.WorkerName AS AllocatedWorker,
        ROW_NUMBER() OVER (PARTITION BY p.pers_person_id ORDER BY (SELECT NULL)) AS RowNum  -- [TESTING] Added to remove dups in output alongside CTE
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
                clae.clae_cla_episode_start_date CLAEpiStart,    /*PW - included as used in join later on to get Worker and Team*/
                clae.clae_cla_primary_need_code CategoryOfNeed,
                clae.clae_cla_episode_ceased DateEpisodeCeased,
                clae.clae_cla_episode_ceased_reason ReasonEpisodeCeased,
                clae.clae_cla_last_iro_contact_date LatestIROVisit,
                DENSE_RANK() OVER(PARTITION BY clae.clae_person_id
                                ORDER BY clap.clap_cla_placement_start_date DESC,
                                            clae.clae_cla_episode_start_date DESC) Rnk
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
                MIN(clae.clae_cla_episode_start_date) FirstLACStartDate
            FROM
                #ssd_cla_episodes clae
            INNER JOIN
                #ssd_legal_status leg on clae.clae_person_id = leg.lega_person_id
                AND clae.clae_cla_episode_start_date = leg.lega_legal_status_start_date
            WHERE
                clae.clae_cla_episode_start_reason = 'S'
                AND COALESCE(leg.lega_legal_status,'zzz') not in ('V1','V3','V4')   -- Exclude Short Breaks
                AND clae.clae_cla_episode_start_date >= DATEADD(MONTH, -12, GETDATE())
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
                    OR (clae.clae_cla_episode_start_date <= DATEADD(MONTH, -12, GETDATE())   /*PW Additional clause to ensure initial placement from 12 months ago is counted if with same carer*/
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
                AND m.miss_missing_episode_start_date >= DATEADD(MONTH, -12, GETDATE())
                --AND m.miss_missing_episode_start_date between clae.clae_entered_care_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
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
                AND m.miss_missing_episode_start_date >= DATEADD(MONTH, -12, GETDATE())
                AND m.miss_missing_episode_start_date between clap.clap_cla_placement_start_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
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
                DENSE_RANK() OVER(PARTITION BY clap.clap_person_id ORDER BY CASE WHEN m.miss_missing_episode_end_date is not null then 1 else 2 END, /*Gives priority to Completed Missing Episodes over Ongoing Missing Episodes so Return Interview Details are available*/
                                                        clap.clap_cla_placement_start_date DESC, m.miss_missing_episode_start_date DESC, m.miss_table_id DESC) Rnk
            FROM
                #ssd_cla_placement clap
    
            INNER JOIN
                #ssd_missing m ON clap.clap_person_id = m.miss_person_id
                AND m.miss_missing_episode_type in ('M', 'Missing')
                AND m.miss_missing_episode_start_date >= DATEADD(MONTH, -12, GETDATE())
                AND m.miss_missing_episode_start_date between clap.clap_cla_placement_start_date and COALESCE(clap.clap_cla_placement_end_date, GETDATE()) /*PW - Comment out if LAC Start Date not added to #ssd_cla_placement*/
            WHERE
                COALESCE(clap.clap_cla_placement_end_date, '99991231') >= DATEADD(MONTH, -@AA_ReportingPeriod, GETDATE())
        ) AS rhi ON clapl.PersonID = rhi.PersonID
            AND rhi.Rnk = 1
    
    -- get latest allocatd Team and Worker
    LEFT JOIN
        (
            SELECT
                clae.clae_person_id PersonID,
                clae.clae_cla_episode_start_date CLAEpiStart,
                inv.invo_professional_team Team,
                pro.prof_professional_name WorkerName,
                DENSE_RANK() OVER(PARTITION BY clae.clae_person_id, clae.clae_cla_episode_start_date
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
        clals.LSCode not in ('V1','V3','V4')   -- Exclude children subject to Short Breaks

)
SELECT * -- [TESTING] Added to remove dups in output alongside CTE
FROM CTE
WHERE RowNum = 1;
-- -- [TESTING]
-- select * from #AA_8_children_in_care;