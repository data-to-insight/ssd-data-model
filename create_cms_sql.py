import yaml

liquid_logic_flag = True  # set this flag to False if you don't want to include liquid_logic fields

# Read the YAML file
with open("schema.yaml", 'r') as stream:
    try:
        schema = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

# Start generating the SQL script
sql_script = f"CREATE DATABASE {schema['database']['name']};\nUSE {schema['database']['name']};\n"

for table in schema['database']['tables']:
    sql_script += f"CREATE TABLE {table['name']} ("
    field_lines = []
    for field in table['fields']:
        # If we have a "cms" metadata field and "liquid_logic" is not in it, skip this field if liquid_logic_flag is False
        if 'cms' in field and 'liquid_logic' not in field['cms'] and not liquid_logic_flag:
            continue
        field_lines.append(f"{field['name']} {field['type']}")
    sql_script += ", ".join(field_lines)
    sql_script += ");\n"

# Print the generated SQL script
print(sql_script)


# Write the generated SQL script to a file
with open("/sql_scripts/ssd_extract.sql", 'w') as f:
    f.write(sql_script)