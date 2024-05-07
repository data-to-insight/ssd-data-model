select 
	sg.group_id fami_family_id
	,sgs.subject_compound_id fami_person_id
from 
	dm_subgroups sg
inner join dm_subgroup_subjects sgs
on sgs.subgroup_id = sg.subgroup_id
	and 
	sgs.subject_type_code = 'PER'
where 
	sg.only_subject_type_code is null
