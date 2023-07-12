import pandas as pd
from tabulate import tabulate
from datetime import datetime

print("TEST: Script located...")

# Read the CSV data file
df = pd.read_csv('docs/admin/ssd_change_log.csv')

# Get current datetime
now = datetime.now()

# Format datetime string
date_time_str = now.strftime("%d/%m/%Y %H:%M")

# Convert the DataFrame to Markdown Table and add it to CHANGELOG
with open('CHANGELOG.md', 'w') as f:
    f.write("# Changelog\n")
    f.write("SSD Data Item Change History:\n")
    f.write("Last updated: " + date_time_str + "\n\n")
    f.write(tabulate(df, headers='keys', tablefmt='pipe', showindex=False))

print("CHANGELOG.md has been updated.")
