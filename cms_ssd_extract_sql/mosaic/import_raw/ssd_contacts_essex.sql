declare @contact_sources table (
	value_from_form			varchar(500),
	category				varchar(500)
)
insert into @contact_sources (
	value_from_form,
	category
)
values
	('Anonymous', '9'),
	('Behaviour support worker', '8'),
	('Children''s centre', '8'),
	('CAFCASS', '7'),
	('Education – College', '2A'),
	('Education – Primary', '2A'),
	('Education – Secondary', '2A'),
	('Education services', '2B'),
	('Education welfare officer', '2B'),
	('Health services - A&E (emergency department)', '3E'),
	('Health services - Other', '3F'),
	('Health services - Adult mental health', '3F'),
	('Health services - Ambulance', '3F'),
	('Health services - Childrens mental health', '3F'),
	('Health services – Community Midwife', '3F'),
	('Health services - Drug and alcohol teams', '3F'),
	('Health services - GP', '3A'),
	('Health services - Health visitor', '3B'),
	('Health services - Hospital (non emergency)', '3D'),
	('Health services - Other primary health services', '3D'),
	('Home Office', '3D'),
	('Housing', '4'),
	('Individual - Family member/relative/carer', '1A'),
	('Individual - Friend / neighbour', '1B'),
	('Individual - Other', '1D'),
	('Individual - Self', '1C'),
	('Inspection unit', '8'),
	('Internal SSD worker', '5A'),
	('LA Service MARAC', '5A'),
	('LA services - Early Help', '5A'),
	('LA services - External', '5C'),
	('LA Services - External to state LA Services - external, from another local authority''s services, for example social care or early help', '5C'),
	('LA services - Family solutions', '5B'),
	('LA services - Internal', '5B'),
	('LA services - Other internal', '5B'),
	('LA services - Social care', '5A'),
	('Legal agency', '7'),
	('MP / Councillor', '1D'),
	('NSPCC', '8'),
	('Other', '8'),
	('Other legal agency', '7'),
	('Other professional worker', '8'),
	('Police', '6'),
	('Police – Essex Police', '6'),
	('Police - Other', '6'),
	('Pre-school', '1B'),
	('Probation', '7'),
	('School', '2A'),
	('YOT', '5B'),
	('Youth Offending Team', '5B'),
	('Youth Service', '5B')
select
	con.WORKFLOW_STEP_ID cont_contact_id,
	con.PERSON_ID cont_person_id,
	convert(datetime, convert(varchar, con.CONTACT_DATE_TIME, 103), 103) cont_contact_date,
	(
		select
			x.category
		from
			@contact_sources x
		where
			x.value_from_form = con.CONTACT_SOURCE_TYPE
	) cont_contact_source_code,
	con.CONTACT_SOURCE_TYPE cont_contact_source_desc,
	con.OUTCOME cont_contact_outcome_json
from
	SCF.Contacts con
