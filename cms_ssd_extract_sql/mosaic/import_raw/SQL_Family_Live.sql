DECLARE @STARTTIME DATE = GETDATE()
DECLARE @ENDTIME DATE


DECLARE
@ssd_timeframe_years INT = 6,
@ssd_sub1_range_years INT = 1


Select
d.fami_family_id,
d.fami_person_id
--d.GroupName,
--d.GroupDesc

From

(
	Select
	g.GROUP_ID fami_family_id,
	gs.SUBJECT_COMPOUND_ID fami_person_id,
	--CASE
		--when g.GROUP_NAME is not null then g.GROUP_NAME
		--when g.GROUP_NAME is null then pn.FIRST_NAMES + ' ' + pn.LAST_NAME
	--END GroupName,
	--g.GROUP_DESCRIPTION GroupDesc,
	DENSE_RANK() OVER(PARTITION BY gs.SUBJECT_COMPOUND_ID ORDER BY (CASE when g.GROUP_NAME is not null then 1 else 2 END), g.GROUP_ID DESC, pn.START_DATE DESC, pn.PERSON_NAME_ID DESC) Rnk

	from moLive.dbo.MO_GROUP_SUBJECTS gs
	inner join moLive.dbo.MO_GROUPS g on gs.GROUP_ID = g.GROUP_ID
	inner join moLive.dbo.MO_PERSONS p on gs.SUBJECT_COMPOUND_ID = p.PERSON_ID
	left join moLive.dbo.MO_PERSON_NAMES pn on p.PERSON_ID = pn.PERSON_ID
		and pn.NAME_TYPE_ID = 'DISPLAY'

	where COALESCE(g.GROUP_NAME,'zzz') not like '%Duplicate%'
	and COALESCE(g.GROUP_NAME,'zzz') not like '%Do not use%'
)
d

where d.Rnk = 1
and (EXISTS
(
	/*Contact in last x@yrs*/
	Select a.PERSON_ID from moLive.dbo.MO_PERSONS a
	where a.PERSON_ID = d.fami_person_id
	and a.PERSON_ID in (1019656,1021254,1022028,1022049,1025446,1025674,1026426,1027023,1027600,1027924) /*PW - Placeholder until have established how to link WorkflowSteps to People*/
))

order by d.fami_family_id, d.fami_person_id