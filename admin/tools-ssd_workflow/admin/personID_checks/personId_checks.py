import pandas as pd

## build a matrix with flags to enable comparisons/checks of which exports contain which person or legacy ids
# Used for analysis/testing of ssd_person filters for example, and over different db clients for comparison like output. 

# Load the main data and unique IDs CSV files
# # unique_ids is used as the complete list of ids to build the matrix around. 
# unique_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_workflow/admin/personID_checks/ssd_person_escc_unique_id_list.csv')
# main_data = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_workflow/admin/personID_checks/ssd_person_escc_person_id_data.csv')

unique_ids = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_workflow/admin/personID_checks/run2_unique_id_list.csv')
main_data = pd.read_csv('/workspaces/ssd-data-model/tools-ssd_workflow/admin/personID_checks/run2_main_data_ids.csv')


# Initialize the result DataFrame with the unique IDs
result = unique_ids.copy()

# Add columns to the result DataFrame corresponding to each column in the main data file
for col in main_data.columns:
    result[col] = ''



# without legacy id
# Populate the result DataFrame
for index, row in unique_ids.iterrows():
    pers_person_id = row['pers_person_id']
    
    for col in main_data.columns:
        # Check if the ID is in the current column

        if (main_data[col] == pers_person_id).any():
            result.at[index, col] = 'Y'

# Save the result to a new CSV file
result.to_csv('/workspaces/ssd-data-model/tools-ssd_workflow/admin/personID_checks/run2_result_matrix.csv', index=False)


# # with legacy_id
# # Populate the result DataFrame
# for index, row in unique_ids.iterrows():
#     pers_legacy_id = row['pers_legacy_id']
#     pers_person_id = row['pers_person_id']
    
#     for col in main_data.columns:
#         # Check if the ID is in the current column
#         if (main_data[col] == pers_legacy_id).any():
#             result.at[index, col] = 'Y'
#         if (main_data[col] == pers_person_id).any():
#             result.at[index, col] = 'Y'

# # Save the result to a new CSV file
# result.to_csv('result_matrix.csv', index=False)