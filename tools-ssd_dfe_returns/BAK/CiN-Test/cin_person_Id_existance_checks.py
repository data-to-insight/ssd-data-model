import pandas as pd

# Load person_ids from CiN reporting, + person_ids found in SSD
cin_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN.csv', header=None, names=['cin_id'])
ssd_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/SSD_all.csv', header=None, names=['ssd_id'])


# Load person_ids from CiN reporting, + person_ids found in SSD CiN
cin_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN.csv', header=None, names=['cin_id'])
ssd_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN_SSD.csv', header=None, names=['ssd_id'])



# Find the IDs in (CiN)cin_ids that are/are not in (SSD)ssd_ids
not_in_ssd = cin_ids[~cin_ids['cin_id'].isin(ssd_ids['ssd_id'])] # person_ids from the CiN but not found in SSD

# Find the IDs in cin_ids that are in ssd_ids
found_in_ssd = cin_ids[cin_ids['cin_id'].isin(ssd_ids['ssd_id'])]  # person_ids from CiN that are also found in SSD

# Output the count of IDs not found
print(f'Number of cin_ids not found in ssd_ids: {len(not_in_ssd)}')
print(f'Number of cin_ids found in ssd_ids: {len(found_in_ssd)}')

# Save the result to a new CSV file
not_in_ssd.to_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/results_cin_person_ids_not_in_ssd.csv', index=False, header=False)
