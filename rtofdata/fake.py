import argparse

from faker import Faker
from random import randrange
import yaml

fake = Faker()

def create_person_data(num_records):
    person_data = {}
    with open("data/categories/gender.yml") as f:
        genders = yaml.load(f.read())
    with open ("data/records/person.yml") as f:
        date_of_birth = yaml.load(f.read())
        date_of_birth_start = date_of_birth['fields']['date_of_birth']['sample_generator']['args']['start_date']
        date_of_birth_end = date_of_birth['fields']['date_of_birth']['sample_generator']['args']['end_date']
    for i in range(0, num_records):
        person_data[i] = {}
        person_data[i]['NiNo'] = fake.bothify('?? ######')
        person_data[i]['date_of_birth'] = fake.date_between(start_date = date_of_birth_start, end_date = date_of_birth_end)
        person_data[i]['gender'] = fake.random.choice(genders)
        person_data[i]['dispersal_area'] = fake.postcode()
        person_data[i]['date_started_service'] = fake.date_this_month(before_today=False, after_today=True)
    return person_data


def create_baseline_data(num_records):
    baseline_data ={}
    with open("data/categories/nationality.yml") as f:
        nationalities = yaml.load(f.read())
        nationalities = [n['value'] for n in nationalities]
    with open("data/categories/language_level_on_entry.yml") as f:
        language_level = yaml.load(f.read())  
    with open("data/categories/transgender.yml") as f:
        gender_follow_up = yaml.load(f.read())  
    with open("data/categories/living_status.yml") as f:
        living_status = yaml.load(f.read())
    with open("data/categories/current_family_composition.yml") as f:
        current_family_composition = yaml.load(f.read())
    with open("data/categories/current_dependents_uk.yml") as f:
        current_dependents_uk = yaml.load(f.read())
    with open("data/records/baseline.yml") as f:
        arrived_uk = yaml.load(f.read())
        arrived_uk_start = arrived_uk['fields']['date_arrived_in_uk']['sample_generator']['args']['start_date']
        arrived_uk_end = arrived_uk['fields']['date_arrived_in_uk']['sample_generator']['args']['end_date']
    with open("data/records/baseline.yml") as f:
        asylum_granted = yaml.load(f.read())
        asylum_granted_start = asylum_granted['fields']['date_asylum_status_granted']['sample_generator']['args']['start_date']
        asylum_granted_end = asylum_granted['fields']['date_asylum_status_granted']['sample_generator']['args']['end_date']
    with open("data/categories/highest_qualification_achieved.yml") as f:
        highest_qualification_achieved = yaml.load(f.read())
    with open("data/categories/employed_in_home_country.yml") as f:
        employed_in_home_country = yaml.load(f.read())
    with open("data/categories/economic_status.yml") as f:
        economic_status = yaml.load(f.read())
    with open("data/categories/housing_baseline_accommodation.yml") as f:
        housing_baseline_accommodation = yaml.load(f.read())
    for i in range(0, num_records):
        baseline_data[i] = {}
        baseline_data[i]['person_ni_number'] = fake.bothify('?? ######')
        baseline_data[i]['Nationality'] = fake.random.choice(nationalities)
        baseline_data[i]['language_level_on_entry'] = fake.random.choice(language_level)  
        baseline_data[i]['gender_follow_up'] = fake.random.choice(gender_follow_up)
        baseline_data[i]['living_status'] = fake.random.choice(living_status)
        baseline_data[i]['current_family_composition'] = fake.random.choice(current_family_composition)
        baseline_data[i]['current_dependents_uk'] = fake.random.choice(current_dependents_uk, randrange(3))
        baseline_data[i]['date_arrived_in_uk'] = fake.date_between(start_date = arrived_uk_start, end_date = arrived_uk_end)
        baseline_data[i]['date_asylum_status_granted'] = fake.date_between(start_date = asylum_granted_start, end_date = asylum_granted_end)
        baseline_data[i]['highest_qualification_achieved'] = fake.random.choice(highest_qualification_achieved)
        baseline_data[i]['employed_in_home_country'] = fake.random.choice(employed_in_home_country)
        baseline_data[i]['occupation_type'] = fake.words(2)
        baseline_data[i]['occupation_sector'] = fake.words(2)
        baseline_data[i]['occupation_goal'] = fake.words(2)
        baseline_data[i]['economic_status'] = fake.random.choice(economic_status)
        baseline_data[i]['housing_baseline_accommodation'] = fake.random.choice(housing_baseline_accommodation)
    return baseline_data


def create_date_last_seen_data(num_records):
    date_last_seen_data = {}
    for i in range(0, num_records):
        date_last_seen_data[i] = {}
        date_last_seen_data[i]['unqiue_id'] = fake.bothify('?? ######')
        date_last_seen_data[i]['date_last_seen'] = fake.date_between()
    return date_last_seen_data


def create_employment_entry_data(num_records):
    employment_entry__data = {}
    with open("data/categories/employment_entry_outcome_type.yml") as f:
        employment_entry_outcome_type = yaml.load(f.read())
    with open("data/categories/employment_entry_details.yml") as f:
        employment_entry_details = yaml.load(f.read())
    for i in range(0, num_records):
        employment_entry__data[i] = {}
        employment_entry__data[i]['unique_id'] = fake.bothify('?? ######')
        employment_entry__data[i]['employment_entry_outcome_type'] = fake.random.choice(employment_entry_outcome_type)
        employment_entry__data[i]['date_employment_entry'] = fake.date_between()
        employment_entry__data[i]['employment_entry_details'] = fake.random.choice(employment_entry_details)
        employment_entry__data[i]['employment_entry_occupation'] = fake.words(2)
        employment_entry__data[i]['employment_entry_sector'] = fake.words(2)
    return employment_entry__data


def create_employment_intermediate_data(num_records):
    employment_intermediate_data = {}
    with open("data/records/employment_intermediate.yml") as f:
        intermediate_employment_outcome = yaml.load(f.read())
        intermediate_employment_outcome_start = intermediate_employment_outcome['fields']['date_intermediate_employment_outcome']['sample_generator']['args']['start_date']
        intermediate_employment_outcome_end = intermediate_employment_outcome['fields']['date_intermediate_employment_outcome']['sample_generator']['args']['end_date']
    with open("data/categories/intermediate_employment_outcome_type") as f:
        intermediate_employment_outcome_type = yaml.load(f.read())
    for i in range(0, num_records):
        employment_intermediate_data[i] = {}
        employment_intermediate_data[i]['unique_id'] = fake.bothify('?? ######')
        employment_intermediate_data[i]['date_intermediate_employment_outcome'] = fake.date_between(start_date = intermediate_employment_outcome_start, end_date= intermediate_employment_outcome_end)
        employment_intermediate_data[i]['intermediate_employment_outcome_type'] = fake.random.choice(intermediate_employment_outcome_type, 3)
    return employment_intermediate_data

def create_employment_sustain_data(num_records):
    employment_sustain_data = {}
    with open("data/records/employment_sustain.yml") as f:
        employment_sustain_date = yaml.load(f.read())
        employment_sustain_date_start = employment_sustain_date['fields']['employment_sustainment_date']['sample_generator']['args']['start_date']
        employment_sustain_date_end = employment_sustain_date['fields']['employment_sustainment_date']['sample_generator']['args']['end_date']
    for i in range(0, num_records):
        employment_sustain_data[i] = {}
        employment_sustain_data[i]['unique_id'] = fake.bothify('?? ######')
        employment_sustain_data[i]['employment_sustain_date'] = fake.date_between(start_date= employment_sustain_date_start, end_date = employment_sustain_date_end)
    return employment_sustain_data

def create_housing_entry_data(num_records):
    housing_entry_data = {}
    with open("data/records/housing_entry.yml") as f:
        housing_entry_date = yaml.load(f.read())
        housing_entry_start = housing_entry_date['fields']['housing_entry_date']['sample_generator']['args']['start_date']
        housing_entry_end = housing_entry_date['fields']['housing_entry_date']['sample_generator']['args']['end_date']
    with open("data\categories\housing_entry_accomodation.yml") as f:
        housing_entry_type = yaml.load(f.read())        
    for i in range(0, num_records):
        housing_entry_data[i] = {}
        housing_entry_data[i]['unique_id'] = fake.bothify('?? ######')
        housing_entry_data[i]['housing_entry_date'] = fake.date_between(start_date = housing_entry_start, end_date = housing_entry_end)
        housing_entry_data[i]['housing_entry_accomodation'] = fake.random.choice(housing_entry_type)
    return housing_entry_data

def create_housing_sustain_data(num_records):
    housing_sustain_data = {}
    with open("data/records/housing_sustain.yml") as f:
        housing_sustain_date = yaml.load(f.read())
        housing_sustain_start = housing_sustain_date['fields']['housing_sustainment_date']['sample_generator']['args']['start_date']
        housing_sustain_end = housing_sustain_date['fields']['housing_sustainment_date']['sample_generator']['args']['end_date']
    for i in range(0, num_records):
        housing_sustain_data[i] = {}
        housing_sustain_data[i]['unique_id'] = fake.bothify('?? ######')
        housing_sustain_data[i]['housing_sustainment_date'] = fake.date_between(start_date = housing_sustain_start, end_date= housing_sustain_end)
    return housing_sustain_data

def create_integration_data(num_records):
    integration_data = {}
    with open("data/categories/integration_outcome_type.yml") as f:
        integration_outcome_type = yaml.load(f.read())
    with open("data/records/integration_plan.yml") as f:
        integration_outcome_date = yaml.load(f.read())
        integration_outcome_start = integration_outcome_date['fields']['integration_outcome_achieved_date']['sample_generator']['args']['start_date']
        integration_outcome_end = integration_outcome_date['fields']['integration_outcome_achieved_date']['sample_generator']['args']['end_date']
    with open("data/categories/integration_comms_language.yml") as f:
        integration_comms_language = yaml.load(f.read())
    with open("data/categories/integration_digital.yml") as f:
        integration_digital = yaml.load(f.read())
    with open("data/categories/integration_social.yml") as f:
        integration_social = yaml.load(f.read())

    for i in range(0, num_records):
        integration_data[i] = {}
        integration_data[i]['unique_id'] = fake.bothify('?? ######')
        integration_data[i]['integration_outcome_type'] = fake.random.choice(integration_outcome_type)
        integration_data[i]['integration_outcome_achieved_date'] = fake.date_between(start_date = integration_outcome_start, end_date = integration_outcome_end)
        integration_data[i]['integration_comms_language'] = fake.random.choice(integration_comms_language)
        integration_data[i]['integration_digital'] = fake.random.choice(integration_digital)
        integration_data[i]['integration_social'] = fake.random.choice(integration_social)
    return integration_data


def create_all_data(num_records):
    """
    By removing the "top-level" code, we can run individual generators without running all the code inbetween
    """
    person_fake = create_person_data(num_records)
    baseline_fake = create_baseline_data(num_records)
    date_last_seen_fake = create_date_last_seen_data(num_records)
    employment_entry_fake = create_employment_entry_data(num_records)
    employment_intermediate_fake = create_employment_intermediate_data(num_records)
    employment_sustain_fake = create_employment_sustain_data(num_records)
    housing_entry_fake = create_housing_entry_data(num_records)
    housing_sustain_fake = create_housing_sustain_data(num_records)
    integration_data_fake = create_integration_data(num_records)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Create fake data'
    )
    parser.add_argument("num_records", type=int, nargs='?', default=10, help="The number of records to generate")
    args = parser.parse_args()
    create_all_data(args.num_records)
