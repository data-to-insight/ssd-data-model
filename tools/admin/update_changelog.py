import pandas as pd
from tabulate import tabulate
from datetime import datetime

# Read the CSV data file
df = pd.read_csv('docs/admin/ssd_change_log.csv')

# Convert 'release_datetime' to datetime, blanks become NaT
df['release_datetime'] = pd.to_datetime(df['release_datetime'], format='%d/%m/%Y %H:%M', errors='coerce')
# Sort by 'release_datetime', NaT values first as these are unreleased|pending
df = df.sort_values(by='release_datetime', ascending=False, na_position='first')

# Replace 'nan' with an empty string
df = df.fillna('')

# Get current datetime
now = datetime.now()

# Format datetime string
date_time_str = now.strftime("%d/%m/%Y %H:%M")

# Convert the DataFrame to Markdown Table and add it to CHANGELOG
with open('CHANGELOG.md', 'w') as f:
    f.write("# Change log\n")
    f.write("SSD Data Item Changes:\n")
    f.write("The complete change history for SSD data items in reverse chronological order, with pending|expected changes showing first.")
    f.write("Agreed data item-level changes are assigned an identifier. A sub-set of the change details for the most recent change (if any) also appears within each objects metadata block(YAML).") 
    f.write("The current change log contains only sample data until we deploy the first pilot release.")
    f.write("Note: Object-level change tracking is not yet available/in progress; feedback/suggestions welcomed.")
    f.write("Last updated: " + date_time_str + "\n\n")
    f.write(tabulate(df, headers='keys', tablefmt='pipe', showindex=False))

print("CHANGELOG.md has been updated.")
