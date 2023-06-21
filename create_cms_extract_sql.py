import glob
import yaml

# Generate SQL for which CMS?
cms_type = 'mosaic'
db_name = 'PLACEHOLDER_DB_NAME'  # replace this with your database name

# Read the YAML schema files
schema_files = glob.glob('data/objects/*.yml')

# Start generating the SQL script
sql_script = f"USE {db_name};\n"

# Iterate over each schema file
for schema_file in schema_files:
    with open(schema_file, 'r') as stream:
        try:
            schema = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)
            continue  # Skip to the next file if there's an error

        nodes = schema.get('nodes', [])
        for node in nodes:
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
