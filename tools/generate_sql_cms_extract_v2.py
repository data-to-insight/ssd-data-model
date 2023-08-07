import yaml
import os
from admin.admin_tools import db_variants # i.e. ,/admin/admin_tools.py


def generate_sql(cms_db, db_name, table_name, field_names, date_field, date_threshold, join_tables=None, join_keys=None, join_types=None):
    """
    Generates SQL query to select from a given table and fields, with optional multiple joins and date filter.
    Uses/requires a dict of db specifics held in the admin file(s)

    Args:
        cms_db (str): Database type. Supports MySQL, Oracle, SQL Server, PostgreSQL, SQLite.
        db_name (str): Name of the database.
        table_name (str): Name of the table to select from.
        field_names (list): List of fields to select. If empty, selects all.
        date_field (str): Name of the date field for filtering.
        date_threshold (int): Year threshold for date filtering.
        join_tables (list, optional): Names of the tables to join. Defaults to None.
        join_keys (list, optional): Keys to join on. Defaults to None.
        join_types (list, optional): Types of joins. Defaults to None.

    Returns:
        str: Generated SQL query.

    Raises:
        ValueError: If the database type is unsupported, or if join_tables, join_keys, join_types are not the same length.
    """
    # Remove all white spaces from cms_db and convert to lowercase
    cms_db = cms_db.replace(" ", "").lower()

    if cms_db not in db_variants:
        raise ValueError(f"Unsupported database variant: {cms_db}")

    # If field_names is empty, select all columns
    if not field_names:
        fields = "*"
    else:
        fields = ", ".join(field_names)

    sql_query = f"SELECT {fields} FROM {table_name}"

    # If join_tables, join_keys and join_types are provided, add the join clauses
    if join_tables and join_keys and join_types:
        if len(join_tables) != len(join_keys) or len(join_keys) != len(join_types):
            raise ValueError("join_tables, join_keys, join_types must be the same length.")
        for join_table, join_key, join_type in zip(join_tables, join_keys, join_types):
            sql_query += f" {join_type} {join_table} ON {table_name}.{join_key} = {join_table}.{join_key}"

    # Add the date filter from the dictionary
    sql_query += db_variants[cms_db]["date_filter"](date_field, date_threshold)

    sql_query += ";"

    # Adapt the query for the specific database variant
    if db_variants[cms_db]["use_db"]:
        sql_query = f"USE {db_name};\n" + sql_query

    return sql_query



def get_la_config(la_code):
    """
    Extracts and cleans LA config from 'la_config/la_cms_config_v2.yml' using LA code. 
    Raises FileNotFoundError if file is missing, and ValueError if LA code is missing.
    Strips spaces and converts strings to lowercase in the resulting config.
    Args:
        la_code (int): The LA code to search for in the configuration.

    Returns:
        dict: The cleaned LA configuration.

    Raises:
        FileNotFoundError: If the YAML configuration file is not found.
        ValueError: If the LA code is not found in the configuration.
    """

    # Check if file exists
    file_path = 'la_config/la_cms_config_v2.yml'
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The configuration file {file_path} was not found.")

    # Load CMS configuration from YAML file
    with open(file_path, 'r') as f:
        original_la_config = yaml.safe_load(f)

    # Extract la_configs from the original dictionary
    la_configs = original_la_config['la_configs']

    # Find the dictionary that matches the provided LA number
    for la_config in la_configs:
        if la_config['la_code'] == la_code:
            # Create a new dictionary where all string values are stripped and lowered
            cleaned_la_config = {k: v.strip().lower() if isinstance(v, str) else v for k, v in la_config.items()}
            return cleaned_la_config

    raise ValueError(f"The LA number {la_code} was not found in the configuration.")


def write_sql_to_file(la_config, sql_query):
    """
    Writes SQL query to a file with a specific name based on the LA configuration.

    Args:
        la_config (dict): LA configuration dictionary containing 'la_name', 'cms_db', and 'la_code'.
        sql_query (str): SQL query to be written to the file.

    Creates a directory named 'sql' if it does not exist. Constructs a filename using 'la_code', sanitized 'la_name' and 'cms_db' from the LA configuration. Writes the SQL query to the created file and prints the name of the file.

    No explicit returns. Raises IOError if the file cannot be written.
    """
    # Create the directory if it does not exist
    os.makedirs('sql', exist_ok=True)

    # Sanitize the la_name and cms_db to be suitable for a filename
    safe_la_name = "".join(x for x in la_config['la_name'] if x.isalnum())
    safe_cms_db = "".join(x for x in la_config['cms_db'] if x.isalnum())
    safe_cms = "".join(x for x in la_config['cms'] if x.isalnum())

    # Create the filename
    filename = f"sql/{la_config['la_code']}_{safe_la_name}_{safe_cms}_{safe_cms_db}.sql"

    # Write the SQL query to the file
    with open(filename, 'w') as f:
        f.write(sql_query)

    print(f"SQL query written to file: {filename}")




def get_field_names_for_tables(tables, cms_type, exception_fields=[]):
    table_field_dict = {}

    for table in tables:
        # Read the YAML file for the table
        with open(f'data/objects/{table}.yml', 'r') as stream:
            try:
                schema = yaml.safe_load(stream)
            except yaml.YAMLError as exc:
                print(exc)
                continue  # Skip to the next file if there's an error

        nodes = schema.get('nodes', [])
        for node in nodes:
            field_names = []
            for field in node['fields']:
                # If field is in exception_fields, skip it
                if field['name'] not in exception_fields:
                    field_names.append(field['name'])

            table_field_dict[table] = field_names  # Store field names for this table

    return table_field_dict





cms_type = 'liquid logic'
db_name = "PLACEHOLDER_DB_NAME"

### TEST - extract the relations
with open('data/objects/relationships.yml', 'r') as file:
    relationships_data = yaml.safe_load(file)

table_name = "person"
join_tables = ["family", "address", "disability"] # Define a list of tables you want to join

# Filter out relationships where parent_object is 'person' and child_object is in join_tables
person_relationships = [relationship for relationship in relationships_data['relationships']
                        if relationship['parent_object'].lower() == 'person' and relationship['child_object'] in join_tables]

join_keys = [relationship['child_key'] for relationship in person_relationships]

# Get the table(s) list
tables = [table_name] + join_tables  # 'table_name' is your main table

exception_fields = ['person_upn_unknown']
table_field_dict = get_field_names_for_tables(tables, cms_type, exception_fields) # Get the field names for each table

field_names = [f"{table}.{field}" for table, fields in table_field_dict.items() for field in fields]


date_field = "entry_date"
date_threshold = 6  # years

# Assume INNER JOIN for all relationships
join_types = ["INNER JOIN" for _ in person_relationships]

# Get the LA configuration before calling generate_sql
la_number = 340
la_config = get_la_config(la_number) # Obtain the specifics of this LAs DB setup/config incl. what type of DB architecture in use.

# Pass the CMS DB variant to generate_sql
sql_query = generate_sql(la_config['cms_db'], db_name, table_name, field_names, date_field, date_threshold, join_tables, join_keys, join_types)


# Write the SQL query to a file
write_sql_to_file(la_config, sql_query)



# import os
# import csv
# import yaml


# def check_file_exists(file_path):
#     if not os.path.exists(file_path):
#         raise FileNotFoundError(f"The file {file_path} does not exist. Please ensure the path is correct.")


# def process_csv(file_path):
#     tables = {}
#     with open(file_path, newline='', encoding='utf-8') as csvfile:
#         reader = csv.reader(csvfile)
#         for row in reader:
#             table_name, column_name, data_type, max_length, nullable, column_key, ref_table, ref_column = row
#             if table_name not in tables:
#                 tables[table_name] = {'columns': {}}
#             tables[table_name]['columns'][column_name] = {
#                 'type': data_type,
#                 'nullable': nullable == 'YES'
#             }
#             if max_length:
#                 tables[table_name]['columns'][column_name]['max_length'] = int(max_length)
#             if column_key == 'PRI':
#                 tables[table_name]['primary_key'] = column_name
#             if ref_table and column_key == 'MUL':
#                 tables[table_name]['foreign_keys'] = {
#                     column_name: {
#                         'references': ref_table,
#                         'on_column': ref_column
#                     }
#                 }
#     return tables


# def save_to_yaml(data, file_name):
#     with open(file_name, 'w') as file:
#         yaml.dump(data, file, default_flow_style=False)
#     print(f"{file_name} created successfully!")


# # Define the local authority name
# la_name = 'Essex'

# # CSV file path
# csv_file_path = 'result.csv'

# # Check if the file exists
# check_file_exists(csv_file_path)

# # Process the CSV
# tables = process_csv(csv_file_path)

# # Format as YAML and save
# yaml_file_name = f'{la_name.lower()}.yml'
# yaml_data = {'tables': tables}
# save_to_yaml(yaml_data, yaml_file_name)
