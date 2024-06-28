# notes: 
# Take in LCS CiN ids, and SSD CiN version. Check for matches/commonality


import pandas as pd

# Define paths
ssd_path = '/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN_SSD.csv'
cin_path = '/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN.csv'

# Read CSV files (as a single string)
with open(ssd_path, 'r') as file:
    ssd_data = file.read()

with open(cin_path, 'r') as file:
    cin_data = file.read()

# Split the string by commas to get codes
ssd_codes = ssd_data.split(',')
cin_codes = cin_data.split(',')

# Convert lists to dfs
df1 = pd.DataFrame(ssd_codes, columns=['code'])
df2 = pd.DataFrame(cin_codes, columns=['code'])

# # verify data
# print("First few rows of ssd:")
# print(df1.head())
# print("\nFirst few rows of cin:")
# print(df2.head())

# Strip whitespace, force case to ensre matches
df1['code'] = df1['code'].astype(str).str.strip().str.lower()
df2['code'] = df2['code'].astype(str).str.strip().str.lower()

# Convert columns to sets
ssdcodes1 = set(df1['code'])
cincodes2 = set(df2['code'])

print(f"\nNumber of unique codes in ssd: {len(ssdcodes1)}")
print(f"Number of unique codes in cin: {len(cincodes2)}")

# Find codes that appear in ssd not in cin
codes_only_in_ssd = ssdcodes1 - cincodes2

# Find codes that appear in cin not in ssd
codes_only_in_cin = cincodes2 - ssdcodes1

# Find common between both files
common_codes = ssdcodes1 & cincodes2

print(f"\nNumber of codes only in ssd: {len(codes_only_in_ssd)}")
print(f"Number of codes only in cin: {len(codes_only_in_cin)}")
print(f"Number of common codes: {len(common_codes)}")

# Print a sample of the common codes to manually verify
print(f"\nSample common codes: {list(common_codes)[:10]}")

# # Output results to CSV files
# pd.DataFrame({'code': list(codes_only_in_ssd)}).to_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/codes_only_in_ssd.csv', index=False)
# pd.DataFrame({'code': list(codes_only_in_cin)}).to_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/codes_only_in_cin.csv', index=False)
# pd.DataFrame({'code': list(common_codes)}).to_csv('/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/common_codes.csv', index=False)

# print("Output files created: codes_only_in_ssd.csv, codes_only_in_cin.csv, common_codes.csv")
