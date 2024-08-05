DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select distinct
p.PERSON_ID pers_person_id,
p.GENDER pers_sex,
pg.GENDER_CODE pers_gender,
--p.SUB_ETHNICITY pers_ethnicity,
e.CIN_ETHNICITY_DESCRIPTION pers_ethnicity,
CAST(DATE_OF_BIRTH as date) pers_dob,
r1.REFERENCE pers_common_child_id,
-- r2.REFERENCE pers_upn, -- [depreciated] [REVIEW]
NULL pers_upn_unknown,
NULL pers_send_flag,	/*PW - Information held in Education System*/
p.AGE_ESTIMATED pers_expected_dob,
p.DATE_OF_DEATH pers_death_date,
CASE when rel.PERSON_RELATIONSHIP_ID is not null then 'Y' END pers_is_mother,
p.COUNTRY_OF_BIRTH pers_nationality

from moLive.dbo.MO_PERSONS p
left join moLive.dbo.MO_PERSON_GENDER_IDENTITIES pg on p.PERSON_ID = pg.PERSON_ID
	and pg.END_DATE is null
left join moLive.dbo.DM_ETHNICITIES e on p.SUB_ETHNICITY = RIGHT(e.ETHNICITY_CODE,LEN(e.ETHNICITY_CODE) - 2)
	and e.CIN_ETHNICITY_CODE is not null
left join moLive.dbo.MO_SUBJECT_REFERENCES r1 on p.PERSON_ID = r1.SUBJECT_COMPOUND_ID
	and r1.REFERENCE_TYPE_CODE = 'NHS'
left join moLive.dbo.MO_SUBJECT_REFERENCES r2 on p.PERSON_ID = r2.SUBJECT_COMPOUND_ID
	and r2.REFERENCE_TYPE_CODE = 'UPN'
--left join EMS.D.INVOLVEMENTS_EHCP ehcp on p.PEMSNumber = ehcp.PersonID
--	and EHCPCompleteDate is not null /*PW - Will give EHCP / SEN Statement ever, may need to add date criteria to show current or within reporting period*/
left join moLive.dbo.MO_PERSON_RELATIONSHIPS rel on p.PERSON_ID = rel.PERSON_ID /*PW - will return 'Y' if any 'Mother - Child Relationship, may need to add criterea to show if child born while LAC or open to CSC*/
	and rel.RELATIONSHIP_TYPE_ID in
	(
		Select rt.RELATIONSHIP_TYPE_ID
		from moLive.dbo.MO_RELATIONSHIP_TYPES rt
		where rt.RELATIONSHIP_CODE = 'MOTHER'
	)

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

order by p.PERSON_ID