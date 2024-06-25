import pandas as pd

# Define file paths relative to the script's directory
file1_path = '/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/SSD.csv'
file2_path = '/workspaces/ssd-data-model/tools-ssd_dfe_returns/BAK/CiN-Test/data/CiN.csv'


# Read the CSV files into DataFrames without headers and then assign a header name
df1 = pd.read_csv(file1_path, header=None, names=['code'])
df2 = pd.read_csv(file2_path, header=None, names=['code'])

# Print the first few rows to verify data
print("First few rows of file1:")
print(df1.head())
print("\nFirst few rows of file2:")
print(df2.head())

# Convert the 'code' columns to sets
codes1 = set(df1['code'])
codes2 = set(df2['code'])

# Print the size of the sets to verify
print(f"\nNumber of unique codes in file1: {len(codes1)}")
print(f"Number of unique codes in file2: {len(codes2)}")

# Find codes that appear in file 1 but not in file 2
codes_only_in_file1 = codes1 - codes2

# Find codes that appear in file 2 but not in file 1
codes_only_in_file2 = codes2 - codes1

# Find codes that are common between both files
common_codes = codes1 & codes2

# Print the size of the resulting sets to verify
print(f"\nNumber of codes only in file1: {len(codes_only_in_file1)}")
print(f"Number of codes only in file2: {len(codes_only_in_file2)}")
print(f"Number of common codes: {len(common_codes)}")

# Output results to CSV files
pd.DataFrame({'code': list(codes_only_in_file1)}).to_csv('codes_only_in_file1.csv', index=False)
pd.DataFrame({'code': list(codes_only_in_file2)}).to_csv('codes_only_in_file2.csv', index=False)
pd.DataFrame({'code': list(common_codes)}).to_csv('common_codes.csv', index=False)

print("Output files created: codes_only_in_file1.csv, codes_only_in_file2.csv, common_codes.csv")
