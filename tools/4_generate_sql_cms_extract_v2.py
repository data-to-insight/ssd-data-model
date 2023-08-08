import yaml
import os
from admin.admin_tools import db_variants           # i.e. ,/admin/admin_tools.py - this picks up known localised LA config settings



# Get the LA configuration before calling generate_sql
la_number = 208 # 208 - Lambeth(mosaic) # 340 - Knowsley(LL)
db_name = "PLACEHOLDER_DB_NAME"                     # Used only on some db specific processing (could also be moved into db_variants config)

primary_table_name = "person"                       # main/base table
join_tables = ["family", "address", "disability"]   # list of requ join tables
date_field = "entry_date"                           # which field is the date, need as db specific processing required(this date on base table?)
date_threshold = 6  # years                         # historic data threshold




def generate_sql(cms_db, db_name, table_name, field_names, date_field, date_threshold, join_tables=None, join_keys=None, join_types=None):
    """
    Generates SQL query to select from a given table and fields, with optional multiple joins and date filter.
    Uses/requires a dict of db specifics held in the admin file(s)

    Args:
        cms_db (str): Database type. Supports MySQL, Oracle, SQL Server, PostgreSQL, SQLite.
        db_name (str): Name of the database (not required by some).
        table_name (str): Name of the primary table to select from.
        field_names (list): List of fields to select. If empty, selects all.
        date_field (str): Name of the date field for filtering.
        date_threshold (int): Year threshold for date filtering.
        join_tables (list, optional): Names of the related tables to join. Defaults to None.
        join_keys (list, optional): Keys to join on. Defaults to None.
        join_types (list, optional): Types of joins (INNER/LEFT....). Defaults to None.

    Returns:
        str: Generated SQL query.

    Raises:
        ValueError: If the database type unsupported, or join_tables + join_keys + join_types are not the same length.
    """
    # Remove all white spaces from cms_db and convert to lowercase
    cms_db = cms_db.replace(" ", "").lower()

    if cms_db not in db_variants:
        raise ValueError(f"Unsupported database variant: {cms_db}")

    # If field_names is empty, default to select all cols
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

    # Add the date filter from admin tools dictionary
    sql_query += db_variants[cms_db]["date_filter"](date_field, date_threshold)

    sql_query += ";"

    # Adapt the query if specific database variant requ' use of 'use dbname...' pre extract sql statment(s)
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


# def get_field_names_for_tables(tables, cms_type, exception_fields=[]):
#     """
#     Extracts the field names for each given table from corresponding YAML files, excluding any fields listed in `exception_fields`.

#     Args:
#         tables (list): A list of table names for which to extract field names. The function will look for a YAML file with the same name for each table.
#         cms_type (str): The type of the CMS (Content Management System). Currently unused in this function but could be useful in the future if different CMSs require different handling.
#         exception_fields (list, optional): A list of field names to exclude. If a field name in a YAML file matches a name in `exception_fields`, it will not be included in the output (default is an empty list).

#     Returns:
#         dict: A dictionary where each key is a table name from `tables`, and each value is a list of field names for that table, excluding any fields listed in `exception_fields`.

#     Raises:
#         YAMLError: If a YAML file cannot be found for a table in `tables`, or if the file cannot be parsed, this function will print an error message and skip to the next table.
#     """
#     table_field_dict = {}

#     for table in tables:
#         # Read the YAML file for the table
#         with open(f'data/objects/{table}.yml', 'r') as stream:
#             try:
#                 schema = yaml.safe_load(stream)
#             except yaml.YAMLError as exc:
#                 print(exc)
#                 continue  # Skip to the next file if there's an error

#         nodes = schema.get('nodes', [])
#         for node in nodes:
#             field_names = []
#             for field in node['fields']:
#                 # If field is in exception_fields, skip it
#                 if field['name'] not in exception_fields:
#                     field_names.append(field['name'])

#             for field in node['fields']:
#                 # If field is in exception_fields, skip it
#                 if field['name'] not in exception_fields:
#                     field_names.append(field['name'])
                    
#                 # If we have a "cms" metadata field and cms_type ....
#                 if 'cms' in field:
#                     cms_fields = field.get('cms_field', [])
#                     cms_tables = field.get('cms_table', [])
#                     for cms_field, cms_table in zip(cms_fields, cms_tables):
#                         cms_key_field, cms_fieldname = cms_field.split(':')
#                         if cms_key_field == cms_type:
#                             field_names.append(cms_fieldname)
#                 else:
#                     field_names.append(field['name'])



#             table_field_dict[table] = field_names  # Store field names for this table

#     return table_field_dict

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
                if field['name'] not in exception_fields:  # Skip if field is in exception fields

                    if 'cms' in field:  # Check if field contains 'cms' key
                        cms_fields = field.get('cms_field', [])  # Get all cms options/fieldnames
                        cms_tables = field.get('cms_table', [])  # Get all cms tables

                        for cms_field, cms_table in zip(cms_fields, cms_tables):    # Iterate over all cms fields and tables
                            cms_key_field, cms_fieldname = cms_field.split(':')     # Split cms_field into key and value
                            cms_key_table, cms_tablename = cms_table.split(':')     # Split cms_table into key and value

                            if cms_key_field == cms_type and cms_key_table == cms_type: # If the keys for field and table match the required cms type
                                field_names.append(cms_fieldname)                       # Append field name to list
                                table = cms_tablename                                   # Update table name
                                break  # Break loop as soon as the matching field is found

                    else:  # If no 'cms' key was found in object definition yaml file
                        field_names.append(field['name'])   # Assume field should be included by default
                                                            # Assume object is also named correctly as-is


            table_field_dict[table] = field_names  # Store field names for this table

    return table_field_dict


def extract_relationships(file_path, parent_object, join_tables):
    """
    Extracts relationships from a YAML file where the parent object and child object meet certain criteria.

    Args:
        file_path (str): The path to the YAML file containing relationships.
        parent_object (str): The parent object to filter relationships by.
        join_tables (list): A list of child objects to filter relationships by.

    Returns:
        tuple: A tuple of two elements. The first element is a list of relationships 
        where the parent object is 'person' and the child object is in 'join_tables'.
        The second element is a list of corresponding 'child_key' values from these relationships.

    Raises:
        FileNotFoundError: If the YAML file cannot be found at the given path.
        YAMLError: If there is an error loading the YAML file.
    """
    with open(file_path, 'r') as file:
        try:
            relationships_data = yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(f"Error loading YAML file: {exc}")
            raise

    person_relationships = [relationship for relationship in relationships_data['relationships']
                            if relationship['parent_object'].lower() == parent_object.lower() and relationship['child_object'] in join_tables]

    join_keys = [relationship['child_key'] for relationship in person_relationships]

    return person_relationships, join_keys



la_config = get_la_config(la_number) # Obtain the specifics of this LAs DB setup/config incl. what type of DB architecture in use.
cms_type = la_config['cms']



# GEt the relationships data from yaml, in order to use in later SQL generation
person_relationships, join_keys = extract_relationships('data/objects/relationships.yml', 'person', join_tables)

# Piece together the full table(s) list
tables = [primary_table_name] + join_tables  # 'table_name' is your main/primary table


exception_fields = ['guidance'] # list of fields NOT to include in the resultant SQL extract
table_field_dict = get_field_names_for_tables(tables, cms_type, exception_fields) # Get the field names for each table
field_names = [f"{table}.{field}" for table, fields in table_field_dict.items() for field in fields] # Create the dot notation/qualified table.fieldnames syntax


# Assume INNER JOIN for all relationships
join_types = ["INNER JOIN" for _ in person_relationships]

# alternative join options for ref
# join_types = ["LEFT JOIN" for _ in person_relationships]
# join_types = ["INNER JOIN", "LEFT JOIN", "INNER JOIN"] # The number of join_types should be equal to the number of join_tables and join_keys



# Pass the CMS DB variant to generate_sql
sql_query = generate_sql(la_config['cms_db'], db_name, primary_table_name, field_names, date_field, date_threshold, join_tables, join_keys, join_types)

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
