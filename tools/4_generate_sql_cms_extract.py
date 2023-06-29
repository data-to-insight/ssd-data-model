import glob
import yaml

# Generate SQL for which CMS?
cms_type = 'mosaic'  # Specify the CMS type for SQL generation

db_name = 'PLACEHOLDER_DB_NAME'  # Replace this with your database name

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
            table_names = []
            for field in node['fields']:
                # If we have a "cms" metadata field and cms_type is not in it, skip this field
                if 'cms' in field:
                    cms_fields = field.get('cms_field', [])
                    cms_tables = field.get('cms_table', [])
                    for cms_field, cms_table in zip(cms_fields, cms_tables):
                        cms_key_field, cms_fieldname = cms_field.split(':')
                        cms_key_table, cms_tablename = cms_table.split(':')
                        if cms_key_field == cms_type and cms_key_table == cms_type:
                            field_names.append(cms_fieldname)
                            table_names.append(cms_tablename)
                else:
                    field_names.append(field['name'])
                    table_names.append(node['name'])

            fields_str = ', '.join(field_names)
            table_str = table_names[0] if len(set(table_names)) == 1 else ', '.join(set(table_names))
            sql_script += f"SELECT {fields_str} FROM {table_str};\n"

# Write the generated SQL script to a file
file_path = f"sql/ssd_extract_{cms_type}.sql"
with open(file_path, 'w') as f:
    f.write(sql_script)
