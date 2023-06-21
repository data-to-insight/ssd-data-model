


import glob
import yaml
import pandas as pd


# from subprocess import run
# # Run create_yml_files_from_spec.py
# run(['/usr/bin/python3', 'create_yml_files_from_spec.py'])
# # Run create_erd_from_yml.py
# run(['/usr/bin/python3', 'create_erd_from_yml.py'])

# Install dependencies using Micropip
# run(['/usr/bin/python3', '-m', 'micropip', 'install', '-r', 'requirements.txt'])

# Install dependencies using pip
# run(['micropip', 'install', '-r', 'requirements.txt'])
# run(['pip', 'install', '-r', 'requirements.txt'])



# Directory to collect YAML files
directory = '/data/objects'

# Collect YAML files
yml_files = glob.glob(f'{directory}/*.yml')

# Remove relationships.yml from the list
yml_files = [f for f in yml_files if 'relationships.yml' not in f]

# Dictionary to store DataFrames
dfs = {}

# Convert YAML files to DataFrames
for file_path in yml_files:
    with open(file_path) as f:
        data = yaml.safe_load(f)
        node = data['nodes'][0]  # Assuming only one node per YAML file
        df = pd.DataFrame(node['fields'])
        dfs[node['name']] = df

# Output the DataFrames
for key, df in dfs.items():
    print(f"DataFrame for {key}:")
    print(df)
    print()
