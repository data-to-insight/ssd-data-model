DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


IF OBJECT_ID('Tempdb..#t','u') IS NOT NULL
BEGIN
    DROP TABLE #t
END
CREATE TABLE #t
(
    perm_table_id INT, -- [REVIEW]
    perm_person_id INT,
    perm_adm_decision_date DATE,
    perm_ffa_cp_decision_date DATE,
    perm_placement_order_date DATE,
    perm_placed_for_adoption_date DATE,
    perm_matched_date DATE,
    perm_placed_ffa_cp_date DATE,
    perm_decision_reversed_date DATE,
    perm_placed_foster_carer_date DATE,
    perm_part_of_sibling_group VARCHAR(1),
    perm_siblings_placed_together INT,
    perm_siblings_placed_apart INT,
    perm_placement_provider_urn VARCHAR(10),
    perm_decision_reversed_reason VARCHAR(3),
    perm_permanence_order_date DATE,
    perm_permanence_order_type VARCHAR(10),
    perm_adopted_by_carer_flag VARCHAR(1),
    perm_cla_id INT,
    perm_adoption_worker_id INT -- [REVIEW] 310524 RH
)

INSERT #t
(
    perm_table_id,
    perm_person_id,
    perm_adm_decision_date,
    perm_ffa_cp_decision_date,
    perm_placement_order_date,
    perm_placed_for_adoption_date,
    perm_matched_date,
    perm_placed_ffa_cp_date,
    perm_decision_reversed_date,
    perm_placed_foster_carer_date,
    perm_part_of_sibling_group,
    perm_siblings_placed_together,
    perm_siblings_placed_apart,
    perm_placement_provider_urn,
    perm_decision_reversed_reason,
    perm_permanence_order_date,
    perm_permanence_order_type,
    perm_adopted_by_carer_flag,
    perm_cla_id,
    perm_adoption_worker_id
)

/*Adoption Cases*/
Select
    NULL perm_table_id,
    a.[Person ID] perm_person_id,
    a.[Best Interest Decision (SHODPA)] perm_adm_decision_date,
    NULL perm_ffa_cp_decision_date, /*PW - to be added to Adoption Tracking Spreadsheet*/
    a.[Placement Order Granted] perm_placement_order_date,
    a.[Date Placed for Adoption] perm_placed_for_adoption_date,
    a.[Date Matched (Panel ADM)] perm_matched_date,
    a.[Date of Fostering For Adoption (FFA) / Concurrency Placement] perm_placed_ffa_cp_date,
    a.[Date Placed Ceased] perm_decision_reversed_date,
    a.[Date Moved in with Foster Carer] perm_placed_foster_carer_date,
    CASE when a.[Sibling Group] is not null then 1 else 0 END perm_part_of_sibling_group,
    a.[Children Placed Together] perm_siblings_placed_together,
    a.[Children Placed Apart] perm_siblings_placed_apart,
    a.[Ofsted URN of LA or Agency Providing Placement] perm_placement_provider_urn,
    NULL perm_decision_reversed_reason,
    a.[Date of Adoption Order (Date Adopted)] perm_permanence_order_date,
    CASE when a.[Date of Adoption Order (Date Adopted)] is not null then 'Adoption' END perm_permanence_order_type,
    a.[Adoption by Existing Foster Carer] perm_adopted_by_carer_flag,
    b.LLPID perm_cla_id,
    NULL perm_adoption_worker_id

from ChildrensReports.Temp.OfstedInspList10RawData a
inner join Mosaic.D.LACLegalPeriods b on a.[Person ID] = b.LLPPersonID
    and a.[Best Interest Decision (SHODPA)] between b.LLPStartDate and COALESCE(b.LLPEndDate,'99991231')

where (a.[Best Interest Decision (SHODPA)] >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
or a.[Placement Order Granted] >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
or a.[Date Matched (Panel ADM)] >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
or a.[Date Placed for Adoption] >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
or a.[Date of Adoption Order (Date Adopted)] >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME))

UNION

/*SGO / CAO Cases
    Note only SGO / CAO from Care recorded, for all SGO / CAO also use Mosaic.M.PERSON_NON_LA_LEGAL_STATUSES (LEGAL_STATUS in ('SGO','CAO'))*/
Select
    NULL perm_table_id, -- [REVIEW]
    a.PERSON_ID perm_person_id,
    NULL perm_adm_decision_date,
    NULL perm_ffa_cp_decision_date, /*PW - to be added to Adoption Tracking Spreadsheet*/
    NULL perm_placement_order_date,
    NULL perm_placed_for_adoption_date,
    NULL perm_matched_date,
    NULL perm_placed_ffa_cp_date,
    NULL perm_decision_reversed_date,
    NULL perm_placed_foster_carer_date,
    NULL perm_part_of_sibling_group,
    NULL perm_siblings_placed_together,
    NULL perm_siblings_placed_apart,
    NULL perm_placement_provider_urn,
    NULL perm_decision_reversed_reason,
    a.END_DATE perm_permanence_order_date,
    CASE 
        when a.REASON_EPISODE_CEASED = 'E41' then 'CAO'
        when a.REASON_EPISODE_CEASED between 'E42' and 'E48' then 'SGO'
    END perm_permanence_order_type,
    NULL perm_adopted_by_carer_flag,
    b.LLPID perm_cla_id,
    NULL perm_adoption_worker_id

from Mosaic.M.LOOKED_AFTER_PLACEMENTS a
inner join Mosaic.D.LACLegalPeriods b on a.PERSON_ID = b.LLPPersonID
    and CAST(a.END_DATE as date) between b.LLPStartDate and COALESCE(b.LLPEndDate,'99991231')

where CAST(a.END_DATE as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
and a.REASON_EPISODE_CEASED between 'E41' and 'E48'


/*Latest Adoption Worker*/
UPDATE #t
SET perm_adoption_worker_id = d.perm_adoption_worker_id

from #t t
inner join
(
    Select
        t.perm_person_id,
        COALESCE(t.perm_permanence_order_date, t.perm_decision_reversed_date, '99991231') PermEndDate,
        pw.WORKER_ID perm_adoption_worker_id,
        DENSE_RANK() OVER(PARTITION BY t.perm_person_id, COALESCE(t.perm_permanence_order_date, t.perm_decision_reversed_date, '99991231') ORDER BY pw.END_DATE DESC, pw.ID DESC) Rnk

    from #t t
    inner join Mosaic.M.PEOPLE_WORKERS pw on t.perm_person_id = pw.PERSON_ID    
        and CAST(pw.START_DATE as date) <= COALESCE(t.perm_permanence_order_date, t.perm_decision_reversed_date, '99991231')
        and COALESCE(CAST(pw.END_DATE as date),'99991231') >= t.perm_decision_reversed_date

    where pw.TYPE = 'FAMFINDSOC'
) d on t.perm_person_id = d.perm_person_id
    and COALESCE(t.perm_permanence_order_date, t.perm_decision_reversed_date, '99991231') = d.PermEndDate

where d.Rnk = 1
and COALESCE(t.perm_permanence_order_type, 'Adoption') = 'Adoption'


/*Output Data*/
Select
    t.perm_table_id,
    t.perm_person_id,
    t.perm_adm_decision_date,
    t.perm_ffa_cp_decision_date,
    t.perm_placement_order_date,
    t.perm_placed_for_adoption_date,
    t.perm_matched_date,
    t.perm_placed_ffa_cp_date,
    t.perm_decision_reversed_date,
    t.perm_placed_foster_carer_date,
    t.perm_part_of_sibling_group,
    t.perm_siblings_placed_together,
    t.perm_siblings_placed_apart,
    t.perm_placement_provider_urn,
    t.perm_decision_reversed_reason,
    t.perm_permanence_order_date,
    t.perm_permanence_order_type,
    t.perm_adopted_by_carer_flag,
    t.perm_cla_id,
    t.perm_adoption_worker_id

from #t t
