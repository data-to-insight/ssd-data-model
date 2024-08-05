DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
NEWID() moth_table_id, -- [REVIEW] Gen new GUID, this in-lieu of a known key value (added 290424)
p.PERSON_ID moth_person_id,
rel.PERSON_RELATED_TO_ID moth_childs_person_id,
CAST(p2.DATE_OF_BIRTH as date) moth_childs_dob

from moLive.dbo.MO_PERSONS p
left join moLive.dbo.MO_PERSON_RELATIONSHIPS rel on p.PERSON_ID = rel.PERSON_ID /*PW - will return 'Y' if any 'Mother - Child Relationship, may need to add criterea to show if child born while LAC or open to CSC*/
	and rel.RELATIONSHIP_TYPE_ID in
	(
		Select rt.RELATIONSHIP_TYPE_ID
		from moLive.dbo.MO_RELATIONSHIP_TYPES rt
		where rt.RELATIONSHIP_CODE = 'MOTHER'
	)
left join moLive.dbo.MO_PERSONS p2 on rel.PERSON_RELATED_TO_ID = p2.PERSON_ID

where (EXISTS
(
	/*Contact in last x@yrs*/
	Select s.SUBJECT_COMPOUND_ID 
	from MoLive.dbo.MO_WORKFLOW_STEPS ws
	inner join moLive.dbo.MO_SUBGROUP_SUBJECTS s on ws.SUBGROUP_ID = s.SUBGROUP_ID
	inner join moLive.dbo.MO_FORMS f on ws.WORKFLOW_STEP_ID = f.WORKFLOW_STEP_ID
	inner join moLive.dbo.MO_FORM_DATE_ANSWERS fa on f.FORM_ID = fa.FORM_ID
	where s.SUBJECT_COMPOUND_ID = p.PERSON_ID
	and ws.WORKFLOW_STEP_TYPE_ID in (335,344) /*335 - Contact/Referral; 344 - EDT Contact/Referral*/
	and CAST(fa.DATE_ANSWER as date) >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
)
or EXISTS
(
	/*LAC Legal Status in last x@yrs*/
	Select a.PERSON_ID from moLive.dbo.PERSON_LEGAL_STATUSES a
	where a.PERSON_ID = p.PERSON_ID
	and COALESCE(a.END_DATE,'99991231') >= DATEADD(YYYY, -@ssd_timeframe_years, @STARTTIME)
)
)
/*Remove Duplicate People*/ /*PW - Not currently included in code as Data Warehouse moves work on a duplicate record to the master record, therefore numbers are different by more if this section included*/
--and NOT EXISTS
--(
--	Select
--	a.PERSON_ID

--	from moLive.dbo.MO_PERSON_RELATIONSHIPS a
--	inner join moLive.DBO.MO_RELATIONSHIP_TYPES b on a.RELATIONSHIP_TYPE_ID = b.RELATIONSHIP_TYPE_ID

--	where a.PERSON_ID = p.PERSON_ID
--	and b.RELATIONSHIP_CODE = 'DUPLICATE'
--)

order by p.PERSON_ID, p2.PERSON_ID