DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
p.PERSON_ID disa_person_id,
d.ID disa_table_id,
COALESCE(dt.CIN_DISABILITY_CATEGORY_CODE,'NONE') disa_disability_code

from moLive.dbo.MO_PERSONS p
left join moLive.dbo.PERSON_CONDITIONS_DISABILITIES d on p.PERSON_ID = d.PERSON_ID
left join moLive.dbo.DM_DISABILITY_TYPES dt on d.CODE = dt.DISABILITY_TYPE
	and dt.CIN_DISABILITY_CATEGORY_CODE <> 'NONE'

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

/*Remove spurious 'NONE'*/	/*PW - would run quicker if deleting from a temporary table*/
and not
(
	p.PERSON_ID in
	(
		Select
		d.PERSON_ID

		from
		(
			Select
			d.PERSON_ID,
			COALESCE(dt.CIN_DISABILITY_CATEGORY_CODE,'NONE') CINCode

			from moLive.dbo.PERSON_CONDITIONS_DISABILITIES d
			left join moLive.dbo.DM_DISABILITY_TYPES dt on d.CODE = dt.DISABILITY_TYPE
				and dt.CIN_DISABILITY_CATEGORY_CODE <> 'NONE'
		)
		d

		group by d.PERSON_ID

		having SUM(CASE WHEN CINCode <> 'NONE' THEN 1 ELSE 0 END) >= 1
		and SUM(CASE WHEN CINCode = 'NONE' THEN 1 ELSE 0 END) >= 1
	)
	and COALESCE(dt.CIN_DISABILITY_CATEGORY_CODE,'NONE') = 'NONE'
)

order by p.PERSON_ID