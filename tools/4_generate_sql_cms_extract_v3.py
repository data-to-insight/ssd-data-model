import yaml
import os
from admin.admin_tools import db_variants           # i.e. ,/admin/admin_tools.py - this picks up known localised LA config settings

# print(os.getcwd())
# print(os.listdir('la_config_files/'))

# Get the LA configuration before calling generate_sql
la_number = 340 # 208 - Lambeth(mosaic) # 340 - Knowsley(LL)
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


import os
import yaml

def get_la_config(la_code):
    """
    Extracts and cleans LA config from individual YAML files in 'la_config_files/' directory using LA code. 
    Raises FileNotFoundError if file is missing, and ValueError if LA code is missing.
    Strips spaces and converts strings to lowercase in the resulting config.
    
    Args:
        la_code (int or str): The LA code to search for in the configuration.

    Returns:
        dict: The cleaned LA configuration.

    Raises:
        FileNotFoundError: If the YAML configuration file is not found.
        ValueError: If the LA code is not found in the configuration.
    """

    # Construct the file path based on the provided la_code
    file_path = f'la_config_files/{la_code}.yml'
    
    # Check if file exists
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The configuration file {file_path} was not found.")

    # Load CMS configuration from YAML file
    with open(file_path, 'r') as f:
        original_la_config = yaml.safe_load(f)

    # root key in the YAML file is the LA code
    la_config_data = original_la_config[la_code]


    # Validate that we successfully extracted the configuration
    if not la_config_data:
        raise ValueError(f"The LA number {la_code} was not found in the configuration.")

    # Create a new dictionary where all string values are stripped and lowered
    cleaned_la_config = {k: v.strip().lower() if isinstance(v, str) else v for k, v in la_config_data.items()}
    
    print(cleaned_la_config)

    return cleaned_la_config



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
                if field['name'] not in exception_fields:  # Skip if field is in exception fields

                    field_names.append(field['name'])   # Assume field should be included by default
                                                            
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


def adjust_bespoke_la_config(la_config, table_field_dict):
    """
    Adjusts the configuration of a Local Authority (LA) based on its bespoke table and field names.

    This function replaces both field and table names in a given dictionary based on the provided LA configuration. 
    It first adjusts the field names within each table, then adjusts the table names themselves. If a replacement 
    is not found in the LA configuration, the original name remains unchanged.

    Args:
        la_config (dict): The configuration dictionary for the LA containing 'db_schema' with the desired table 
                          and field names.
            Expected structure: {'db_schema': {'tables': {'table_name': {'name': 'replacement_table_name', 
                                                    'fields': {'original_field': 'replacement_field', ...}}}}}
        table_field_dict (dict): Dictionary containing table names as keys and a list of field names as values 
                                 that need adjustments.
    Returns:
        dict: A new dictionary with adjusted table and field names.
    """
    db_schema = la_config.get('db_schema', {}).get('tables', {})
    
    # Step 1: Replace field names
    for table, fields in table_field_dict.items():
        # Check if table exists in db_schema, if not move to next iteration
        if table not in db_schema:
            continue
        replacement_fields = db_schema[table].get('fields', {})
        # Replace fields in table_field_dict using the replacement_fields
        table_field_dict[table] = [replacement_fields.get(field, field) for field in fields]
    
    # Step 2: Replace table names
    custom_la_table_field_dict = {}
    for table, fields in table_field_dict.items():
        replacement_table_name = db_schema.get(table, {}).get('name', table)
        custom_la_table_field_dict[replacement_table_name] = fields
    
    return custom_la_table_field_dict


#
#  Obtain the specifics of this LAs DB setup/config
# 
la_config = get_la_config(la_number) # Entire LA configuration
cms_type = la_config['cms'] # which cms


#
# GEt the relationships data from yaml (used in SQL gen later)
# 
person_relationships, join_keys = extract_relationships('data/objects/relationships.yml', 'person', join_tables)
tables_list = [primary_table_name] + join_tables  # Full list of in-use table(s)


#
# Build table:fields dict 
#
exception_fields = ['guidance'] # list of <fields> NOT to include in the resultant SQL extract
table_field_dict = get_field_names_for_tables(tables_list, cms_type, exception_fields) # Collect field names for each data object/table from YAML defs

#
# Adjust table:fields to conform with LA bespoke fit/LA config
#
la_table_field_dict = adjust_bespoke_la_config(la_config, table_field_dict)


## TEMP TESTING
# 
print(f"\nTESTING\nTable+fields spec(compare differences if any)\nPRE-bespoke-la changes:\n - {table_field_dict} \nPOST-bespoke-la changes:\n - {la_table_field_dict}")
## END

#
# Create SQL notation on fields
#
field_names = [f"{table}.{field}" for table, fields in la_table_field_dict.items() for field in fields] # Create the dot notation/qualified table.fieldnames syntax


#
# Generate sql
#
join_types = ["INNER JOIN" for _ in person_relationships] # Assumed INNER JOIN for all relationships
# alternative join options for ref ["LEFT JOIN" for _ in person_relationships]
# ["INNER JOIN", "LEFT JOIN", "INNER JOIN"] # The number of join_types should be equal to the number of join_tables and join_keys

sql_query = generate_sql(la_config['cms_db'], db_name, primary_table_name, field_names, date_field, date_threshold, join_tables, join_keys, join_types)

# Write the SQL query to a file
write_sql_to_file(la_config, sql_query)



