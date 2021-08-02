from faker import Faker
from numpy.core.fromnumeric import transpose
import pandas as pd
from datetime import datetime
import numpy as np
from pandas.core import base
import yaml

fake = Faker()


def create_person_data(x):
    person_data = {}
    with open("data/categories/gender.yml") as f:
        genders = yaml.load(f.read())
    for i in range(0, x):
        person_data[i] = {}
        person_data[i]['NiNo'] = fake.bothify('?? ######')
        person_data[i]['date_of_birth'] = fake.date_between(start_date = '-65y', end_date = ('-18y'))
        person_data[i]['gender'] = np.random.choice(genders)
        person_data[i]['dispersal_area'] = fake.postcode()
        person_data[i]['date_started_service'] = fake.date_between(start_date = '-1y')
    return person_data

person_fake = create_person_data(10)
person_df = pd.DataFrame.from_dict(person_fake) 
print(transpose(person_df))

def create_baseline_data(x):
    baseline_data ={}
    with open("data/categories/nationality.yml") as f:
        nationalities = yaml.load(f.read())
        nationalities = [n['value'] for n in nationalities]
    with open("data/categories/language_level_on_entry.yml") as f:
        language_level = yaml.load(f.read())  
    with open("data/categories/gender_follow_up.yml") as f:
        gender_follow_up = yaml.load(f.read())  
    with open("data/categories/living_status.yml") as f:
        living_status = yaml.load(f.read())
    with open("data/categories/current_family_composition.yml") as f:
        current_family_composition = yaml.load(f.read())
    with open("data/categories/highest_qualification_achieved.yml") as f:
        highest_qualification_achieved = yaml.load(f.read())
    with open("data/categories/employed_in_home_country.yml") as f:
        employed_in_home_country = yaml.load(f.read())
    with open("data/categories/economic_status.yml") as f:
        economic_status = yaml.load(f.read())
    with open("data/categories/housing_baseline_accommodation.yml") as f:
        housing_baseline_accommodation = yaml.load(f.read())
    for i in range(0, x):
        baseline_data[i] = {}
        baseline_data[i]['person_ni_number'] = fake.bothify('?? ######')
        baseline_data[i]['Nationality'] = np.random.choice(nationalities)
        baseline_data[i]['language_level_on_entry'] = np.random.choice(language_level)  
        baseline_data[i]['gender_follow_up'] = np.random.choice(gender_follow_up)
        baseline_data[i]['living_status'] = np.random.choice(living_status)
        baseline_data[i]['current_family_composition'] = np.random.choice(current_family_composition)
        baseline_data[i]['date_arrived_in_uk'] = fake.date_between(start_date = '-2y', end_date = ('-1y'))
        baseline_data[i]['date_asylum_status_granted'] = fake.date_between(start_date = '-1y')
        baseline_data[i]['highest_qualification_achieved'] = np.random.choice(highest_qualification_achieved)
        baseline_data[i]['employed_in_home_country'] = np.random.choice(employed_in_home_country)
        baseline_data[i]['occupation_type'] = fake.words(2)
        baseline_data[i]['occupation_goal'] = fake.words(2)
        baseline_data[i]['economic_status'] = np.random.choice(economic_status)
        baseline_data[i]['housing_baseline_accommodation'] = np.random.choice(housing_baseline_accommodation)
    return baseline_data

baseline_fake = create_baseline_data(20)
baseline_df = pd.DataFrame.from_dict(baseline_fake)
print(transpose(baseline_df))