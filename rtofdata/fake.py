from faker import Faker
import pandas as pd
from datetime import datetime
import numpy as np
fake = Faker()

def create_data(x):
    person_data = {}
    genders = ["Male", "Female", "Non-binary", "Transgender", "Other"]
    gender_weights = [0.2, 0.2, 0.2, 0.2, 0.2]
    for i in range(0, x):
        person_data[i] = {}
        person_data[i]['NiNo'] = fake.bothify('?? ######')
        person_data[i]['date_of_birth'] = fake.date_between(start_date = '-65y', end_date = ('-18y'))
        person_data[i]['gender'] = np.random.choice(genders, p=gender_weights)
        person_data[i]['dispersal_area'] = fake.postcode()
        person_data[i]['date_started_service'] = fake.date_between(start_date = '-1y')
    return person_data

test_fake = create_data(10)
person_df = pd.DataFrame.from_dict(test_fake) 
print(person_df)

