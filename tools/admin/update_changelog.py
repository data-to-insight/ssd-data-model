import pandas as pd
from tabulate import tabulate

# Read the CSV data file
df = pd.read_csv('/workspaces/ssd-data-model/docs/admin/ssd_change_log.csv')

# Convert the DataFrame to Markdown Table and add it to CHANGELOG
with open('CHANGELOG.md', 'w') as f:
    f.write("# Changelog\n")
    f.write("SSD Data Item Change History:\n")
    f.write(tabulate(df, headers='keys', tablefmt='pipe', showindex=False))

print("CHANGELOG.md has been updated.")
