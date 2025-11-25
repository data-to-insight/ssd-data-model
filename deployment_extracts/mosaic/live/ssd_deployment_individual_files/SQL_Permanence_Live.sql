/*4 duplicates
	2 - adoption placement disrupted then new adoption placement
	2 - adoption placements where carer moved house so new placement recorded with same carer
*/


DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


/*Temporary Table - Create LAC Periods (Get LAC Legal Statuses)*/
IF OBJECT_ID('Tempdb..#LLP','u') IS NOT NULL
BEGIN
    DROP TABLE #LLP
END
CREATE TABLE #LLP
(
    RowID INT IDENTITY, 
    PersonID INT, 
    RecordID INT, 
    StartDate DATE,
    EndDate DATE, 
    LSCode VARCHAR(16),
    Gap SMALLINT,
    MasterRecordID INT
)

CREATE UNIQUE CLUSTERED INDEX ix_LLP
ON #LLP(PersonID,StartDate)

INSERT #LLP
(
    PersonID,
    RecordID, 
    StartDate,
    EndDate, 
    LSCode,
    Gap
)

Select
    l.PERSON_ID PersonID,
    l.ID RecordID,
    l.START_DATE StartDate,
    l.END_DATE EndDate,
    l.LEGAL_STATUS LSCode,
    DATEDIFF(DAY, LAG(l.END_DATE) OVER(PARTITION BY l.PERSON_ID ORDER BY l.START_DATE),l.START_DATE) Gap
from moLive.dbo.PERSON_LEGAL_STATUSES l
where l.LEGAL_STATUS not in ('V1','V3','V4') /*Short Break Placements*/
    and l.START_DATE < COALESCE(l.END_DATE,'99991231')	
order by l.PERSON_ID, l.START_DATE

/*Add 'MasterRecordID'*/
DECLARE @PrevPersonID INT,
        @MasterRecordID INT,
        @Anchor INT;

UPDATE #LLP
SET @MasterRecordID = MasterRecordID = 
            CASE 
                when PersonID <> @PrevPersonID then RecordID
                when PersonID = @PrevPersonID and Gap < 1 then @MasterRecordID
                else RecordID  
            END,
    @PrevPersonID = PersonId,
    @Anchor = RowID

/*Temporary Table - Create LAC Periods*/
IF OBJECT_ID('Tempdb..#LAC','u') IS NOT NULL
BEGIN
    DROP TABLE #LAC
END
CREATE TABLE #LAC
(
    LLPID INT,
    PersonID INT,
    LACStartDate DATE,
    LACEndDate DATE
)

CREATE UNIQUE CLUSTERED INDEX ix_LAC
ON #LAC(PersonID,LACStartDate)

INSERT #LAC
(
    LLPID, 
    PersonID, 
    LACStartDate, 
    LACEndDate
)

Select
    llp.MasterRecordID LLPID,
    llp.PersonID, 
    MIN (llp.StartDate) LACStartDate,
    CASE when MAX(COALESCE(llp.EndDate,'20790606')) = '20790606' then NULL else MAX(COALESCE(llp.EndDate,'20790606')) END LACEndDate
from #LLP llp
group by llp.PersonID, llp.MasterRecordID

/*Output Data*/
/*Select *
from #LAC lac
order by lac.PersonID, lac.LACStartDate*/

/*Temporary Table - Permanence Table*/
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
    PlacementOrderEnd DATE,
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
    PlacementOrderEnd,
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
    a.PERSON_ID perm_person_id,
    NULL perm_adm_decision_date,
    lac.LACStartDate,
    NULL perm_ffa_cp_decision_date,
    CAST(a.START_DATE as date) perm_placement_order_date,
    CAST(a.END_DATE as date) PlacementOrderEnd,
    CAST(p.START_DATE as date) perm_placed_for_adoption_date,
    NULL perm_matched_date,
    NULL perm_placed_ffa_cp_date,
    NULL perm_decision_reversed_date,
    NULL perm_placed_foster_carer_date,
    NULL perm_part_of_sibling_group,
    NULL perm_siblings_placed_together,
    NULL perm_siblings_placed_apart,
    NULL perm_placement_provider_urn,
    NULL perm_decision_reversed_reason,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then CAST(p.END_DATE as date) END perm_permanence_order_date,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then 'Adoption' END perm_permanence_order_type,
    NULL perm_adopted_by_carer_flag,
    lac.LLPID perm_cla_id,
    NULL perm_adoption_worker_id
from moLive.dbo.PERSON_LEGAL_STATUSES a
inner join #LAC lac on a.PERSON_ID = lac.PersonID
    and COALESCE(CAST(a.END_DATE as date),'99991231') between lac.LACStartDate and COALESCE(lac.LACEndDate,'99991231')
left join moLive.dbo.LOOKED_AFTER_PLACEMENTS p on a.PERSON_ID = p.PERSON_ID	
    and p.PLACEMENT_CODE like 'A%'
    and p.START_DATE >= a.START_DATE
where a.LEGAL_STATUS in ('D1','E1')
    and COALESCE(CAST(a.END_DATE as date),'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)

UNION

/*Adoption Cases - Relinquished Child - No Placement Order*/
Select
    NULL perm_table_id,
    p.PERSON_ID perm_person_id,
    NULL perm_adm_decision_date,
    lac.LACStartDate,
    NULL perm_ffa_cp_decision_date,
    NULL perm_placement_order_date,
    NULL PlacementOrderEnd,
    CAST(p.START_DATE as date) perm_placed_for_adoption_date,
    NULL perm_matched_date,
    NULL perm_placed_ffa_cp_date,
    NULL perm_decision_reversed_date,
    NULL perm_placed_foster_carer_date,
    NULL perm_part_of_sibling_group,
    NULL perm_siblings_placed_together,
    NULL perm_siblings_placed_apart,
    NULL perm_placement_provider_urn,
    NULL perm_decision_reversed_reason,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then CAST(p.END_DATE as date) END perm_permanence_order_date,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then 'Adoption' END perm_permanence_order_type,
    NULL perm_adopted_by_carer_flag,
    lac.LLPID perm_cla_id,
    NULL perm_adoption_worker_id
from moLive.dbo.LOOKED_AFTER_PLACEMENTS p
inner join #LAC lac on p.PERSON_ID = lac.PersonID
    and COALESCE(CAST(p.END_DATE as date),'99991231') between lac.LACStartDate and COALESCE(lac.LACEndDate,'99991231')
left join moLive.dbo.PERSON_LEGAL_STATUSES a on p.PERSON_ID = a.PERSON_ID	
    and a.LEGAL_STATUS in ('D1','E1')
    and a.START_DATE <= p.START_DATE
where p.PLACEMENT_CODE like 'A%'
    and COALESCE(CAST(p.END_DATE as date),'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
    and a.PERSON_ID is null
/*Exclude children already included*/
    and p.PERSON_ID not in
    (
        Select a.PERSON_ID
        from moLive.dbo.PERSON_LEGAL_STATUSES a
        left join moLive.dbo.LOOKED_AFTER_PLACEMENTS p on a.PERSON_ID = p.PERSON_ID	
            and p.PLACEMENT_CODE like 'A%'
            and p.START_DATE >= a.START_DATE
        where a.LEGAL_STATUS in ('D1','E1')
            and COALESCE(CAST(a.END_DATE as date),'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
    )

UNION

/*Adoption Cases - Private Adoption by Foster Carer*/
Select
    NULL perm_table_id,
    p.PERSON_ID perm_person_id,
    NULL perm_adm_decision_date,
    lac.LACStartDate,
    NULL perm_ffa_cp_decision_date,
    CAST(a.START_DATE as date) perm_placement_order_date,
    CAST(a.END_DATE as date) PlacementOrderEnd,
    CAST(p.START_DATE as date) perm_placed_for_adoption_date,
    NULL perm_matched_date,
    NULL perm_placed_ffa_cp_date,
    NULL perm_decision_reversed_date,
    NULL perm_placed_foster_carer_date,
    NULL perm_part_of_sibling_group,
    NULL perm_siblings_placed_together,
    NULL perm_siblings_placed_apart,
    NULL perm_placement_provider_urn,
    NULL perm_decision_reversed_reason,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then CAST(p.END_DATE as date) END perm_permanence_order_date,
    CASE when p.REASON_EPISODE_CEASED in ('E11','E12') then 'Adoption' END perm_permanence_order_type,
    NULL perm_adopted_by_carer_flag,
    lac.LLPID perm_cla_id,
    NULL perm_adoption_worker_id
from moLive.dbo.LOOKED_AFTER_PLACEMENTS p
inner join #LAC lac on p.PERSON_ID = lac.PersonID
    and COALESCE(CAST(p.END_DATE as date),'99991231') between lac.LACStartDate and COALESCE(lac.LACEndDate,'99991231')
left join moLive.dbo.PERSON_LEGAL_STATUSES a on p.PERSON_ID = a.PERSON_ID	
    and a.LEGAL_STATUS in ('D1','E1')
    and a.START_DATE <= p.START_DATE
where p.REASON_EPISODE_CEASED in ('E11','E12')
    and p.PLACEMENT_CODE not like 'A%'
    and COALESCE(CAST(p.END_DATE as date),'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
/*Exclude children already included*/
    and p.PERSON_ID not in
    (
        Select a.PERSON_ID
        from moLive.dbo.PERSON_LEGAL_STATUSES a
        left join moLive.dbo.LOOKED_AFTER_PLACEMENTS p on a.PERSON_ID = p.PERSON_ID	
            and p.PLACEMENT_CODE like 'A%'
            and p.START_DATE >= a.START_DATE
        where a.LEGAL_STATUS in ('D1','E1')
            and COALESCE(CAST(a.END_DATE as date),'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
    )

UNION

/*SGO / CAO Cases
    Note only SGO / CAO from Care recorded, for all SGO / CAO also use Mosaic.M.PERSON_NON_LA_LEGAL_STATUSES (LEGAL_STATUS in ('SGO','CAO'))*/
Select
    NULL perm_table_id,
    a.PERSON_ID perm_person_id,
    NULL perm_adm_decision_date,
    lac.LACStartDate,
    NULL perm_ffa_cp_decision_date, /*PW - to be added to Adoption Tracking Spreadsheet*/
    NULL perm_placement_order_date,
    NULL PlacementOrderDate,
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
    lac.LLPID perm_cla_id,
    NULL perm_adoption_worker_id
from moLive.dbo.LOOKED_AFTER_PLACEMENTS a
inner join #LAC lac on a.PERSON_ID = lac.PersonID
    and CAST(a.END_DATE as date) between lac.LACStartDate and COALESCE(lac.LACEndDate,'99991231')
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
        COALESCE(t.perm_permanence_order_date, t.PlacementOrderEnd, '99991231') PermEndDate,
        pw.WORKER_ID perm_adoption_worker_id,
        DENSE_RANK() OVER(PARTITION BY t.perm_person_id, COALESCE(t.perm_permanence_order_date, t.PlacementOrderEnd, '99991231') ORDER BY pw.END_DATE DESC, pw.ID DESC) Rnk
    from #t t
    inner join moLive.dbo.PEOPLE_WORKERS pw on t.perm_person_id = pw.PERSON_ID	
        and CAST(pw.START_DATE as date) <= COALESCE(t.perm_permanence_order_date, t.PlacementOrderEnd, '99991231')
    where pw.TYPE = 'FAMFINDSOC'
) d on t.perm_person_id = d.perm_person_id
    and COALESCE(t.perm_permanence_order_date, t.PlacementOrderEnd, '99991231') = d.PermEndDate
where d.Rnk = 1
    and COALESCE(t.perm_permanence_order_type, 'Adoption') = 'Adoption'

/*Output Data*/
Select
    t.perm_table_id,
    t.perm_person_id,
    t.perm_adm_decision_date,
    t.perm_ffa_cp_decision_date,
    t.perm_placement_order_date,
    --t.PlacementOrderEnd,
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
