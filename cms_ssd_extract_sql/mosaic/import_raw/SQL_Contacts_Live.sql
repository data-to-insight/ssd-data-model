DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1;


/*CTE - Outcome SC*/
WITH CTEOutcomeSC as
(
Select
ws.WORKFLOW_STEP_ID cont_contact_id,
fa.FORM_ID,
ss.value cont_person_id

from MoLive.dbo.MO_WORKFLOW_STEPS ws
inner join moLive.dbo.MO_FORMS f on ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
inner join moLive.dbo.MO_FORM_DATE_ANSWERS fa on f.FORM_ID = fa.FORM_ID

--/*Contact Outcome - 'Social Care Referral'*/
inner join moLive.dbo.MO_FORM_BOOLEAN_ANSWERS fa2 on f.FORM_ID = fa2.FORM_ID
	and fa2.QUESTION_ID in
	(
		Select a.QUESTION_ID
		from moLive.dbo.MO_QUESTIONS a
		where a.QUESTION_USER_CODE in ('chkMCON_CAFARequired')
	)
inner join moLive.dbo.MO_FORM_SHORT_TEXT_ANSWERS fa3 on fa2.FORM_ANSWER_ROW_ID = fa3.FORM_ANSWER_ROW_ID
	and fa3.QUESTION_ID in
	(
		Select a.QUESTION_ID
		from moLive.dbo.MO_QUESTIONS a
		where a.QUESTION_USER_CODE in ('MSRS_OutcomeSubjects')
	)
CROSS APPLY string_split(fa3.SHORT_TEXT_ANSWER,',') ss

where ws.WORKFLOW_STEP_TYPE_ID in (335,344) /*335 - Contact/Referral; 344 - EDT Contact/Referral*/
	and CAST(fa.DATE_ANSWER as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)

and fa.QUESTION_ID in	
(	
	Select a.QUESTION_ID
	from moLive.dbo.MO_QUESTIONS a
	where a.QUESTION_USER_CODE in ('datMCON_DateTimeOfContact','contact.record.contact.date','s3i1')
)	
),

/*CTE - Outcome EH*/
CTEOutcomeEH as
(
Select
ws.WORKFLOW_STEP_ID cont_contact_id,
fa.FORM_ID,
ss.value cont_person_id

from MoLive.dbo.MO_WORKFLOW_STEPS ws
inner join moLive.dbo.MO_FORMS f on ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
inner join moLive.dbo.MO_FORM_DATE_ANSWERS fa on f.FORM_ID = fa.FORM_ID

--/*Contact Outcome - 'Early Help Referral'*/
inner join moLive.dbo.MO_FORM_BOOLEAN_ANSWERS fa2 on f.FORM_ID = fa2.FORM_ID
	and fa2.QUESTION_ID in
	(
		Select a.QUESTION_ID
		from moLive.dbo.MO_QUESTIONS a
		where a.QUESTION_USER_CODE in ('chkMCON_ReferEHH')
	)
inner join moLive.dbo.MO_FORM_SHORT_TEXT_ANSWERS fa3 on fa2.FORM_ANSWER_ROW_ID = fa3.FORM_ANSWER_ROW_ID
	and fa3.QUESTION_ID in
	(
		Select a.QUESTION_ID
		from moLive.dbo.MO_QUESTIONS a
		where a.QUESTION_USER_CODE in ('MSRS_OutcomeSubjects')
	)
CROSS APPLY string_split(fa3.SHORT_TEXT_ANSWER,',') ss

where ws.WORKFLOW_STEP_TYPE_ID in (335,344) /*335 - Contact/Referral; 344 - EDT Contact/Referral*/
	and CAST(fa.DATE_ANSWER as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)

and fa.QUESTION_ID in	
(	
	Select a.QUESTION_ID
	from moLive.dbo.MO_QUESTIONS a
	where a.QUESTION_USER_CODE in ('datMCON_DateTimeOfContact','contact.record.contact.date','s3i1')
)	
)


/*Output Data*/
Select
ws.WORKFLOW_STEP_ID cont_contact_id,
s.SUBJECT_COMPOUND_ID cont_person_id,
CAST(fa.DATE_ANSWER as date) cont_contact_date,
ql2.ANSWER cont_contact_source,
CASE
	when sc.cont_contact_id is not null then 'CIN Referral'
	when eh.cont_contact_id is not null then 'EH Referral'
END cont_contact_outcome_json

from MoLive.dbo.MO_WORKFLOW_STEPS ws
inner join moLive.dbo.MO_SUBGROUP_SUBJECTS s on ws.SUBGROUP_ID = s.SUBGROUP_ID
	--and s.SUBJECT_TYPE_CODE = 'PER' /*PW - addition of this doesn't appear to make any difference*/
inner join moLive.dbo.MO_FORMS f on ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
inner join moLive.dbo.MO_FORM_DATE_ANSWERS fa on f.FORM_ID = fa.FORM_ID
left join moLive.dbo.MO_FORM_LOOKUP_ANSWERS fa2 on f.FORM_ID = fa2.FORM_ID
	and fa2.QUESTION_ID in
	(
		Select a.QUESTION_ID
		from moLive.dbo.MO_QUESTIONS a
		where a.QUESTION_USER_CODE in ('contact.record.contact.details.agency','cmbMCON_ContactSource')
	)
left join moLive.dbo.MO_QUESTION_LOOKUPS ql2 on fa2.QUESTION_LOOKUP_ID = ql2.QUESTION_LOOKUP_ID
left join CTEOutcomeSC sc on ws.WORKFLOW_STEP_ID = sc.cont_contact_id
	and s.SUBJECT_COMPOUND_ID = sc.cont_person_id
	and fa.FORM_ID = sc.FORM_ID
left join CTEOutcomeEH eh on ws.WORKFLOW_STEP_ID = eh.cont_contact_id
	and s.SUBJECT_COMPOUND_ID = eh.cont_person_id
	and fa.FORM_ID = eh.FORM_ID

where ws.WORKFLOW_STEP_TYPE_ID in (335,344) /*335 - Contact/Referral; 344 - EDT Contact/Referral*/
	and CAST(fa.DATE_ANSWER as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)

and fa.QUESTION_ID in	
(	
	Select a.QUESTION_ID
	from moLive.dbo.MO_QUESTIONS a
	where a.QUESTION_USER_CODE in ('datMCON_DateTimeOfContact','contact.record.contact.date','s3i1')
)	

order by CAST(fa.DATE_ANSWER as date), ws.WORKFLOW_STEP_ID, s.SUBJECT_COMPOUND_ID