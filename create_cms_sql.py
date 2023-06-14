import yaml

cms_type = 'liquid_logic'  # set this to the CMS you want to include
# cms_type = 'mosaic'  # set this to the CMS you want to include

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
file_path = f"sql_scripts/ssd_extract_{cms_type}.sql"
with open(file_path, 'w') as f:
    f.write(sql_script)