"""
This script generates an SQL script based on a YAML schema file for extracting data from a database.

The script does:

- Define the CMS type and database name for the SQL script.
- Read the YAML schema file.
- Initialize the SQL script.
- Iterate over each node in the schema:
    - Extract relevant field names.
    - Append a SELECT statement to the SQL script.
- Write the generated SQL script to a file.

Note: The script assumes specific file paths and output file name. 
It also needs the correct database name adding.
"""


import yaml


# Generate SQL for which CMS? 
# cms_type = 'liquid_logic' 
cms_type = 'mosaic'  

db_name = 'PLACEHOLDER_DB_NAME'  # replace this with your database name





# Read the YAML file
with open("structure_grouped_objects/schema.yaml", 'r') as stream:
    try:
        schema = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

# Start generating the SQL script
sql_script = f"USE {db_name};\n"

for node in schema['nodes']:
    field_names = []
    for field in node['fields']:
        # If we have a "cms" metadata field and cms_type is not in it, skip this field
        if 'cms' in field and cms_type not in field['cms']:
            continue
        field_names.append(field['name'])
    fields_str = ', '.join(field_names)
    sql_script += f"SELECT {fields_str} FROM {node['name']};\n"

# Write the generated SQL script to a file
file_path = f"sql_generated_scripts/ssd_extract_{cms_type}.sql"
with open(file_path, 'w') as f:
    f.write(sql_script)