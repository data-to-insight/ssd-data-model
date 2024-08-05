select
	cl.PERSON_ID clea_table_id, -- [REVIEW]
	cl.PERSON_ID clea_person_id,
	cl.ELIGIBILITY_STATUS,
	cl.IN_TOUCH_ON_BIRTHDAY clea_care_leaver_in_touch,
	cl.LATEST_CONTACT_DATE clea_care_leaver_latest_contact,
	cl.ACCOMMODATION_DESCRIPTION clea_care_leaver_accommodation,
	cl.ACCOMMODATION_SUITABLE clea_care_leaver_accom_suitable,
	cl.ACTIVITY_DESCRIPTION clea_care_leaver_activity,
	cl.LATEST_PATHWAY_PLAN_DATE clea_pathway_plan_review_date,
	cl.PERSONAL_ADVISOR clea_care_leaver_personal_advisor,
	cl.TEAM_NAME clea_care_leaver_allocated_team,
	cl.WORKER_NAME clea_care_leaver_worker_id
from
	SCF.Care_Leavers cl
where
	cl.OPEN_CASE = 'Y'
	and
	coalesce(cl.IN_TOUCH_ORDER,1) = (
		select
			max(coalesce(cl1.IN_TOUCH_ORDER,1))
		from
			SCF.Care_Leavers cl1
		where
			cl1.OPEN_CASE = 'Y'
			and
			cl1.PERSON_ID = cl.PERSON_ID
	)
	and
	coalesce(cl.WORKER_ORDER_FROM_LATEST,1) = (
		select
			max(coalesce(cl1.WORKER_ORDER_FROM_LATEST,1))
		from
			SCF.Care_Leavers cl1
		where
			cl1.OPEN_CASE = 'Y'
			and
			cl1.PERSON_ID = cl.PERSON_ID
	)