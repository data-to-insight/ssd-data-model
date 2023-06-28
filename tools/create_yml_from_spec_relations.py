from admin.admin_tools import get_paths # get project defined file paths


# File handling input/output

paths = get_paths()

# Data Structure spec
data_spec_csv = paths['data_specification']
output_directory = paths['yml_data']



import csv
import os
import yaml
import re

# Full list of field names
field_names = ['field_ref','object_name', 'categories', 'constraints', 'type', 'name', 'description', 'returns', 'cms','required_enabled','unique_enabled','primary_key','foreign_key']

# Those that are multi-part/list fields
multi_part_fields = ['categories', 'constraints', 'returns', 'cms']


# Creating a new dictionary to store relationships
relationships = {}


def clean_fieldname_data(value, is_name=False):
    """
    Cleans the given value.
    Processes include removing special characters ('/ \'), replacing spaces with underscores.

    Args:
        value (str): Input string to be cleaned.
        is_name (bool): Whether the input value is a name. If True, additional processing is done.

    Returns:
        str: The cleaned string.
    """
    # Replace tab characters with spaces
    value = value.replace('\t', ' ')

    # Remove special characters
    value = re.sub(r'[\\/]', '', value)

    
    # (towards avoiding '' values in output yml)
    if not value.strip():  # Check if the value is an empty string or consists only of whitespace
        return None  # Return None if the value is empty 

    if not value:  # Check if the value is an empty string
        return None  # Return None if the value is empty 

    if value.lower() == 'null':
        value = None  # Return None if the value is empty 


    if is_name:
        value = value.lower()  # Force name element to lowercase
        value = value.replace(' ', '_')  # Replace spaces with underscores

    return value




def process_csv_file(csv_file, output_directory):
    with open(csv_file, 'r', newline='', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        nodes = []

        for row in reader:
            object_name = row['object_name']
            field = {}

            for name in field_names:
                value = row[name].strip('"')
                value = clean_fieldname_data(value, is_name=(name == 'name'))
                field[name] = value

            for name in multi_part_fields:
                value = field[name]
                field[name] = [v.strip().replace(' ', '') for v in value.split('|')] if value else []

            node_index = next((i for i, node in enumerate(nodes) if node['name'] == object_name), None)

            if node_index is None:
                nodes.append({'name': object_name, 'fields': [field]})
            else:
                nodes[node_index]['fields'].append(field)

            # Parse the foreign_key relationship and add to the dictionary
            if field['foreign_key']:
                # Split the relationship string into parent object and key
                parent_object, parent_key = field['foreign_key'].split('.')
                if parent_object not in relationships:
                    relationships[parent_object] = []
                relationships[parent_object].append({
                    'child_object': object_name,
                    'parent_key': parent_key,
                    'child_key': field['name']
                })

        for node in nodes:
            save_node_yaml(node, output_directory)

        save_relationships_yaml(relationships, output_directory)

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

                data['relationships'].append(relationship_data)

        yaml.dump(data, file, sort_keys=False, default_flow_style=False, explicit_start=True, default_style='')



def save_node_yaml(node, output_directory):
    """
    Saves a YAML file for a specific node with its associated fields.

    Args:
        node (dict): Dictionary representing the node with 'name' and 'fields' keys.
        output_directory (str): Directory to save the generated YAML files.
    """

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
                'name': field['name'],
                'type': None if field['type'] == 'null' else field['type'],
                'description': field['description'],
                'field_ref': field['field_ref'],
            }


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

            # Remove the 'type' key if the value is None
            if field['type'] is not None:
                field_data['type'] = field['type']


            for name in multi_part_fields:
                if field.get(name):
                    field_data[name] = field[name]

            # Include the field data only if it has any non-empty value
            if any(field_data.values()):
                data['nodes'][0]['fields'].append(field_data)

        yaml.dump(data, file, sort_keys=False, default_flow_style=False, explicit_start=True, default_style='')



process_csv_file(data_spec_csv, output_directory)



