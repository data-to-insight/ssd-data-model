DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
a.WorkflowStepID cont_contact_id,
a.PersonID cont_person_id,
a.StartDate cont_contact_date,
a.ContactSource cont_contact_source,
CASE
	when a.Outcome = 'Social Care' then 'CIN Referral'
	when a.Outcome = 'Early Help' then 'EH Referral'
	--else 'Other'
END	cont_contact_outcome_json

from ChildrensReports.ICS.Contacts a

where a.StartDate >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
--and a.WorkflowStepID in (3320049, 3319949)

order by a.StartDate, a.WorkflowStepID, a.PersonID