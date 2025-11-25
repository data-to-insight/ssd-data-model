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
prep_table_id INT,
prep_person_id INT,
prep_plo_family_id INT,
prep_pre_pro_decision_date DATE,
prep_initial_pre_pro_meeting_date DATE,
prep_pre_pro_outcome VARCHAR(50),
prep_agree_stepdown_issue_date DATE,
prep_cp_plans_referral_period INT DEFAULT 0,
prep_legal_gateway_outcome VARCHAR(50),
prep_prev_pre_proc_child INT DEFAULT 0,
prep_prev_care_proc_child INT DEFAULT 0,
prep_pre_pro_letter_date DATE,
prep_care_pro_letter_date DATE,
prep_pre_pro_meetings_num INT,
prep_pre_pro_parents_legal_rep VARCHAR(10),
prep_parents_legal_rep_point_of_issue VARCHAR(50),
prep_court_reference VARCHAR(50),
prep_care_proc_court_hearings INT,
prep_care_proc_short_notice VARCHAR(50),
prep_proc_short_notice_reason VARCHAR(200),
prep_la_inital_plan_approved VARCHAR(10),
prep_la_initial_care_plan VARCHAR(50),
prep_la_final_plan_approved VARCHAR(10),
prep_la_final_care_plan VARCHAR(50),
CINPeriodStart DATE,
CINPeriodEnd DATE
)

INSERT #t
(
prep_table_id,
prep_person_id,
prep_initial_pre_pro_meeting_date,
prep_agree_stepdown_issue_date
)

Select
a.ID prep_table_id,
a.PERSON_ID prep_person_id,
a.START_DATE prep_initial_pre_pro_meeting_date,
a.END_DATE prep_agree_stepdown_issue_date

from moLive.dbo.PERSON_NON_LA_LEGAL_STATUSES a

where COALESCE(a.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
and a.LEGAL_STATUS = 'PLOPRE'


/*Get Family ID*/
UPDATE #t
SET prep_plo_family_id = d.prep_plo_family_id

from #t t
inner join
(
	Select
	t.prep_person_id,
	g.GROUP_ID prep_plo_family_id,
	DENSE_RANK() OVER(PARTITION BY gs.SUBJECT_COMPOUND_ID ORDER BY (CASE when g.GROUP_NAME is not null then 1 else 2 END), g.GROUP_ID DESC) Rnk

	from #t t
	inner join moLive.dbo.MO_GROUP_SUBJECTS gs on t.prep_person_id = gs.SUBJECT_COMPOUND_ID
	inner join moLive.dbo.MO_GROUPS g on gs.GROUP_ID = g.GROUP_ID
			and COALESCE(g.GROUP_NAME,'zzz') not like '%Duplicate%'
			and COALESCE(g.GROUP_NAME,'zzz') not like '%Do not use%'
)
d on t.prep_person_id = d.prep_person_id

where d.Rnk = 1


/*Date decision made to enter Pre Proceedings*/
/*Information not held in Mosaic
	For PLO Project, date of decision to enter Pre-Proceedings was manually looked up from 'Legal Gateway' Case Notes*/


/*Get CIN Period Start Date (PW - need to establish way of deriving this from Live Database)*/
--UPDATE #t
--SET CINPeriodStart = d.CINPeriodStart

--from #t t
--inner join
--(
--	Select
--	t.prep_table_id,
--	t.prep_person_id,
--	--t.prep_initial_pre_pro_meeting_date,
--	MAX(a.CINPeriodStart) CINPeriodStart

--	from #t t
--	inner join ChildrensReports.D.CINPeriods a on t.prep_person_id = a.PersonID
--		and a.CINPeriodStart <= prep_initial_pre_pro_meeting_date
--		and COALESCE(a.CINPeriodEnd,'99991231') > prep_initial_pre_pro_meeting_date

--	group by
--	t.prep_person_id, t.prep_table_id
--)
--d on t.prep_person_id = d.prep_person_id
--	and t.prep_table_id = d.prep_table_id


/*CIN Period End Date (PW - need to establish way of deriving this from Live Database)*/
--UPDATE #t
--SET CINPeriodEnd = d.CINPeriodEnd

--from #t t
--inner join
--(
--	Select
--	t.prep_person_id,
--	t.CINPeriodStart,
--	MAX(a.CINPeriodEnd) CINPeriodEnd

--	from #t t
--	inner join ChildrensReports.D.CINPeriods a on t.prep_person_id = a.PersonID
--		and a.CINPeriodStart = t.CINPeriodStart

--	group by
--	t.prep_person_id, t.CINPeriodStart
--)
--d on t.prep_person_id = d.prep_person_id
--	and t.CINPeriodStart = d.CINPeriodStart


/*Pre Proceedings Outcome - Care Proceedings*/
UPDATE #t
SET prep_pre_pro_outcome =	'a) Decision to Issue Care Proceedings'

from #t t
inner join moLive.dbo.PERSON_LEGAL_STATUSES a on t.prep_person_id = a.PERSON_ID
		and a.LEGAL_STATUS in ('C1','C2')
		and CAST(a.START_DATE as date) between t.prep_initial_pre_pro_meeting_date and DATEADD(D, 31, t.prep_agree_stepdown_issue_date)
		and COALESCE(CAST(a.END_DATE as date),'99991231') > t.prep_agree_stepdown_issue_date

/*Pre Proceedings Outcome - Step Down*/
UPDATE #t
SET prep_pre_pro_outcome =	'b) Decision to step down'

from #t t

where t.prep_agree_stepdown_issue_date is not null
and t.prep_pre_pro_outcome is null


/*Number of CP Plans during referral period (PW - need to establish way of deriving referral period Live Database; 'CP Plans Ever' used as interim)*/
UPDATE #t
SET prep_cp_plans_referral_period = d.NoOfCPPlans

from #t t
inner join
(
	Select
	t.prep_table_id,
	t.prep_person_id,
	COUNT(a.PERSON_REGISTRATION_ID) NoOfCPPlans

	from #t t
	inner join moLive.dbo.MO_PERSON_REGISTRATIONS a on t.prep_person_id = a.PERSON_ID
	inner join moLive.dbo.MO_REGISTERS r on a.REGISTER_ID = r.REGISTER_ID

	where r.IS_CHILD_PROTECTION_FLAG = 'Y'
	and a.FROM_ORG_ID is null /*Exclude Temporary CP Plans*/

	group by t.prep_person_id, t.prep_table_id
)
d on t.prep_person_id = d.prep_person_id
	and t.prep_table_id = d.prep_table_id


/*Outcome of legal gateway / panel / meeting after panel*/
/*Not available in Mosaic
	For PLO Project, outcome of legal gateway / panel / meeting after panel was manually looked up from 'Legal Gateway' Case Notes*/


/*No of Previous Pre-Proceedings*/
UPDATE #t
SET prep_prev_pre_proc_child = d.prep_prev_pre_proc_child

from #t t
inner join
(
	Select
	t.prep_table_id,
	t.prep_person_id,
	COUNT(a.ID) prep_prev_pre_proc_child

	from #t t
	inner join moLive.dbo.PERSON_NON_LA_LEGAL_STATUSES a on t.prep_person_id = a.PERSON_ID
		and a.LEGAL_STATUS = 'PLOPRE'
		and CAST(a.START_DATE as date) < t.prep_initial_pre_pro_meeting_date

	group by t.prep_table_id, t.prep_person_id
)
d on t.prep_person_id = d.prep_person_id
	and t.prep_table_id = d.prep_table_id


/*No of Previous Care Proceedings*/
UPDATE #t
SET prep_prev_care_proc_child = d.prep_prev_care_proc_child

from #t t
inner join
(
	Select
	t.prep_table_id,
	t.prep_person_id,
	COUNT(a.ID) prep_prev_care_proc_child

	from #t t
	inner join moLive.dbo.PERSON_LEGAL_STATUSES a on t.prep_person_id = a.PERSON_ID
		and a.LEGAL_STATUS = 'C1'
		and CAST(a.START_DATE as date) < t.prep_initial_pre_pro_meeting_date

	group by t.prep_table_id, t.prep_person_id
)
d on t.prep_person_id = d.prep_person_id
	and t.prep_table_id = d.prep_table_id


/*What is the date that the letter to issue care proceedings was sent to parents*/
/*Not available in Mosaic
	For PLO Project, date that the pre-proceedings letter and plan was sent to parents was manually looked up from Documents uploaded to Mosaic (with limited success)*/


/*What is the date that the letter to issue care proceedings was sent to parents*/
/*Not available in Mosaic
	For PLO Project, date that the letter to issue care proceedings was sent to parents was manually looked up from Documents uploaded to Mosaic (with limited success)*/


/*How many review pre-proceeding meetings have been held with parents following the initial meeting*/
/*Not available in Mosaic
	For PLO Project, number of review pre-proceeding meetings have been held with parents following the initial meeting was manually looked up from spreadsheet that tracks these meetings*/


/*Did parents have legal representation during pre-proceedings*/
/*Not available in Mosaic
	For PLO Project, whether or not parents had legal representation during pre-proceedings was manually looked up from Mosaic Case File (with limited success)*/


/*Did parents have legal representation at the point of issue*/
/*Not available in Mosaic
	For PLO Project, whether or not parents had legal representation at the point of issue was manually looked up from Mosaic Case File (with limited success)*/


/*If in Care Proceedings, what is the Court reference number*/
/*Not available in Mosaic
	For PLO Project, Court reference number was manaully looked up from Documents uploaded to Mosaic*/


/*How many Court hearings have taken place whilst in care proceedings*/
/*Not available in Mosaic
	For PLO Project, number of Court hearings that have taken place whilst in care proceedings was manually looked up from Mosaic Case File*/


/*Were Care Proceedings issued on a short notice application*/
/*Not available in Mosaic
	For PLO Project, whether Care Proceedings issued on a short notice application was manually looked up from Mosaic Case File (with limited success)*/


/*What was the reason for any short notice applications*/
/*Not available in Mosaic and not submitted in PLO Project*/


/*Was the LA’s initial plan approved at the initial hearing*/
/*Not available in Mosaic
	For PLO Project, whether the LA’s initial was plan approved at the initial hearing was looked up from Mosaic Case File*/


/*What was the LA’s initial care plan for the child at the initial hearing*/
/*Not available in Mosaic
	For PLO Project, the LA’s initial care plan for the child at the initial hearing was looked up from Mosaic Case File
	Note it is possible that this information could be derived from Permanence Plans the same as Ofsted List 8*/


/*Was the LA’s final plan approved at the final hearing*/
/*Not available in Mosaic
	For PLO Project, whether the LA’s final was plan approved at the final hearing was looked up from Mosaic Case File*/


/*What was the LA’s final care plan for the child at the final hearing*/
/*Not available in Mosaic
	For PLO Project, the LA’s final care plan for the child at the final hearing was looked up from Mosaic Case File
	Note it is possible that this information could be derived from Permanence Plans the same as Ofsted List 8*/


/*Output Data*/
Select
t.prep_table_id,
t.prep_person_id,
t.prep_plo_family_id,
t.prep_pre_pro_decision_date,
t.prep_initial_pre_pro_meeting_date,
t.prep_pre_pro_outcome,
t.prep_agree_stepdown_issue_date,
t.prep_cp_plans_referral_period,
t.prep_legal_gateway_outcome,
t.prep_prev_pre_proc_child,
t.prep_prev_care_proc_child,
t.prep_pre_pro_letter_date,
t.prep_care_pro_letter_date,
t.prep_pre_pro_meetings_num,
t.prep_pre_pro_parents_legal_rep,
t.prep_parents_legal_rep_point_of_issue,
t.prep_court_reference,
t.prep_care_proc_court_hearings,
t.prep_care_proc_short_notice,
t.prep_proc_short_notice_reason,
t.prep_la_inital_plan_approved,
t.prep_la_initial_care_plan,
t.prep_la_final_plan_approved,
t.prep_la_final_care_plan
--t.CINPeriodStart,
--t.CINPeriodEnd

from #t t