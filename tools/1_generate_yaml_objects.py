

import os
import yaml
import pandas as pd
import glob


from admin.admin_tools import get_paths # get project defined file paths
from admin.admin_tools import clean_fieldname_data # get field cleaner func


# File handling input/output

paths = get_paths()

# Data Structure spec
data_spec_csv = paths['data_specification']
change_log_file = paths['change_log']
output_directory_yaml = paths['yml_data']
output_directory_erd = paths['erd_objects_publish']


# Full list of field names
# If there are non-required fields in the spec csv, just dont include them here
field_names = ['item_ref','object_name', 'categories', 'constraints', 'type', 'field_name', 'description', 'returns', 
               'cms', 'cms_field','cms_table',
               'required_enabled','unique_enabled','primary_key','foreign_key', 
               'guidance', 
               'item_ref', 'release_datetime', 'change_id', 'change_impact_title', 'change_status', 'change_type', 'change_source','change_impact_notes', 'change_versions_count'] # meta data fields

# Those that are multi-part/list fields
multi_part_fields = ['categories', 'constraints', 'returns', 'cms', 'cms_field', 'cms_table']


# Creating a new dictionary to store relationships
relationships = {}




def save_relationships_yaml(relationships, output_directory):
    """
    Saves the relationships of data objects into a YAML file.
    
    Args:
        relationships (dict): A dictionary of relationships.
        output_directory (str): The directory to save the YAML file.
    
    Returns:
        None. Writes to 'relationships_test.yml' in the specified directory.
    """
    yaml_file = os.path.join(output_directory, 'relationships.yml')

    with open(yaml_file, 'w') as file:
        data = {
            'relationships': []
        }

        for parent_object, relations in relationships.items():
            for relation in relations:
                relationship_data = {
                    'parent_object': parent_object,
                    'parent_key': relation['parent_key'],
                    'child_object': relation['child_object'],
                    'child_key': relation['child_key'],
                    'relation': '1:M'  # Hardcoded relationship type
                }

                #print(relationship_data)

                data['relationships'].append(relationship_data)

        yaml.dump(data, file, sort_keys=False, default_flow_style=False, explicit_start=True, default_style='')



def process_csv_file(csv_file, change_log_file, output_directory):
    """
    Processes a CSV file, extracting and storing data nodes and their relationships in YAML format.
    
    Args:
        csv_file (str): Path to the input CSV file.
        change_log_file (str): Path to the input change log CSV file.
        output_directory (str): Path to the output directory to store the YAML files.
    
    Returns:
        None. Writes nodes and relationships to separate YAML files in the specified directory.
    """

    # Load csv data 
    data_df = pd.read_csv(csv_file, quotechar='"')          # Load main data 
    change_df = pd.read_csv(change_log_file, quotechar='"') # Load change log 


    # Convert to datetime, sort by 'item_ref' and 'release_datetime'
    change_df['release_datetime'] = pd.to_datetime(change_df['release_datetime'], format='%d/%m/%Y %H:%M', errors='coerce') # unreleased blanks become NaT
    change_df = change_df.sort_values(['item_ref', 'release_datetime'], ascending=[True, False]) # Use , na_position='first') if wanting NaT/unreleased changes
    
    # Get an int count of how many historic changes occured
    change_df ['change_versions_count'] = change_df .groupby('item_ref')['item_ref'].transform('count').astype(int)

    # Keep only the most recent change log entry per 'item_ref'
    change_df = change_df.drop_duplicates(subset='item_ref', keep='first')

    
    # Merge the change log data into main data based on 'item_ref'
    data_df = pd.merge(data_df, change_df, on='item_ref', how='left')
    

    data_df = data_df.fillna('') # nan's cause str processing issues down the line

    # Convert the merged DataFrame back to list of dictionaries for processing
    data = data_df.to_dict('records')

    nodes = []  # Initialize nodes here

    for row in data:

        # # TESTING
        #print("DtoI-1606 - Row output test - object_name")
        #print(row)
        

        object_name = row['object_name']
        print(object_name)
        field = {}

        for name in field_names:
            try:
                value = row[name].strip('"') if isinstance(row[name], str) else row[name]
                field[name] = value
            except KeyError:
                print(f"KeyError for key '{name}' in row: {row}")
                raise  # re-raise the exception to see the traceback and stop execution
            
        for name in field_names:
            value = row[name].strip('"') if isinstance(row[name], str) else row[name]
            if value is not None and pd.notnull(value):
                value = clean_fieldname_data(str(value), is_name=(name == 'name'))
            field[name] = value

        for name in multi_part_fields:
            value = field[name]
            # field[name] = [v.strip().replace(' ', '') for v in value.split('|')] if value else []
            if isinstance(value, str):
                field[name] = [v.strip().replace(' ', '') for v in value.split('|')] if value else []
            else:
                field[name] = []  # or handle this case appropriately

        node_index = next((i for i, node in enumerate(nodes) if node['name'] == object_name), None)

        if node_index is None:
            nodes.append({'name': object_name, 'fields': [field]})
        else:
            nodes[node_index]['fields'].append(field)


        # Parse the foreign_key relationship and add to the dictionary
        if pd.notna(field['foreign_key']): 
            # Split the relationship string into parent object and key
            field['foreign_key'] = str(field['foreign_key'])
            parent_object, parent_key = field['foreign_key'].split('.')
            if parent_object not in relationships:
                relationships[parent_object] = []
            relationships[parent_object].append({
                'child_object': object_name,
                'parent_key': parent_key,
                'child_key': field['field_name']
            })

    for node in nodes:
        save_node_yaml(node, output_directory)

    save_relationships_yaml(relationships, output_directory)




def save_node_yaml(node, output_directory):
    """
    Saves a YAML file for a specific node with its associated fields.

    Args:
        node (dict): Dictionary representing the node with 'name' and 'fields' keys.
        output_directory (str): Directory to save the generated YAML files.
    """
    if not node.get('fields'):
        print(f"No fields found for node {node['name']}. Skipping...")
        return
    
    yaml_file = os.path.join(output_directory, f"{node['name']}.yml")


    with open(yaml_file, 'w') as file:
        data = {
            'nodes': [{
                'name': node['name'],
                'fields': []
            }]
        }


        for field in node['fields']:
            field_data = {
                'name': field['field_name'], # consider renaming this throughout to field_name (RH 31/10/23)
                'description': field['description'],
                'item_ref': field['item_ref']
            }

            # Dev note: 
            # Due to revisions in spec 31/10/23, further clean-up work here required. 
            # check spec col/field naming on spec, inclusion of max_field_size? Remove depreciated(unique_enabled,..)? 

            # Can be integrated into the above structure once all definitions in the spec are set
            # WE only requ the null checks due to in progress developement 
            if field.get('type') and field['type'].lower() != 'null':
                field_data['type'] = field['type']


            if field.get('primary_key'):
                field_data['primary_key'] = bool(field['primary_key'])

            if field.get('foreign_key'):
                field_data['foreign_key'] = field['foreign_key']

            if field.get('required_enabled') or field.get('unique_enabled'):
                field_data['validators'] = []

                if field.get('required_enabled'):
                    field_data['validators'].append({
                        'required': {
                            'enabled': bool(field['required_enabled'])
                        }
                    })

                if field.get('unique_enabled'):
                    field_data['validators'].append({
                        'unique': {
                            'enabled': bool(field['unique_enabled'])
                        }
                    })


            for name in multi_part_fields:
                if field.get(name):
                    field_data[name] = field[name]


            # Add guidance field last due to data length
            field_data['guidance'] = field['guidance']


            #
            # Add metadata Incl item-level change tracking
               
            if 'change_id' in field and pd.notnull(field['change_id']):
                # If release_datetime is a non-empty string, try converting it to datetime
                if isinstance(field['release_datetime'], str) and field['release_datetime'].strip():
                    field['release_datetime'] = pd.to_datetime(field['release_datetime'])
                else:
                    field['release_datetime'] = None

                # Format release_datetime if it's valid and not NaT, else set to "N/A"
                release = field['release_datetime'].strftime('%d/%m/%Y %H:%M') if field['release_datetime'] and not pd.isna(field['release_datetime']) else "In review|pending"

                field_data['metadata'] = {
                    'release': release,
                    'change_id': field['change_id'],                                 # unique change identifier
                    'change_source': field['change_source'],                         # source/origin of change request
                    'versions_count': int(float(field['change_versions_count'])),    # calculated count, num of changes
                    'impact_title': field['change_impact_title'],                    # short change description
                    'type': field['change_type']                                     # what type of change [bug|new|...]
                }

            # Include the field data only if it has any non-empty value
            if any(field_data.values()):
                data['nodes'][0]['fields'].append(field_data)

        yaml.dump(data, file, sort_keys=False, default_flow_style=False, explicit_start=True, default_style='')



def delete_yml_objects(output_directory):
    """
    Delete all *.yml files from a directory.
    Clean-up everything before re-creating to avoid removed/depreciated items being left behind during re-creation.

    :param output_directory: str, path to the directory to clean
    """

    # Get list of all .yml files in the directory
    files = glob.glob(os.path.join(output_directory, "*.yml"))

    # Iterate over the list of filepaths & remove each file.
    for file in files:
        try:
            os.remove(file)
        except OSError as e:
            print("Error: %s : %s" % (file, e.strerror))
            


def delete_png_images(output_directory):
    """
    Delete all *.png files from a directory.
    Clean-up everything before re-creating to avoid removed/depreciated items being left behind during re-creation.

    :param output_directory: str, path to the directory to clean
    """

    # Get list of all .png files in the directory
    files = glob.glob(os.path.join(output_directory, "*.png"))

    # Iterate over the list of filepaths & remove each file.
    for file in files:
        try:
            os.remove(file)
        except OSError as e:
            print("Error: %s : %s" % (file, e.strerror))



delete_png_images(output_directory_erd)     # remove existing to prevent obsolete being left
delete_yml_objects(output_directory_yaml)    # remove existing to prevent obsolete being left

process_csv_file(data_spec_csv, change_log_file, output_directory_yaml) # create all new yml objects



