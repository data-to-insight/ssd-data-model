
"""
This script processes a CSV file containing node information and generates separate YAML files for each node.

The script performs the following steps:

- Define the necessary field names, including multi-part fields.
- Read the CSV file using the `csv.DictReader` to parse each row.
- Create a list of nodes, where each node is represented by a dictionary with a name and fields.
- Iterate over each row in the CSV file:
    - Extract the node name and field values from the row.
    - Append the field information to the corresponding node in the list of nodes.
- Save YAML files for each node, using the node name as the file name.
- The output YAML file includes the node name, fields, and their respective properties.
"""



# File handling input/output

# Data Structure spec
csv_file = 'docs/data_objects_specification.csv'     #  import from repo
output_directory = 'data/objects/'


import csv
import os
import yaml

# Full list of field names
field_names = ['object_name', 'categories', 'constraints', 'type', 'name', 'description', 'returns', 'cms']

# Those that are multi-part/list fields
multi_part_fields = ['categories', 'constraints', 'returns', 'cms']

def process_csv_file(csv_file, output_directory):
    """
    Processes the CSV file and generates separate YAML files for each node.

    Args:
        csv_file (str): Path to the input CSV file.
        output_directory (str): Directory to save the generated YAML files.
    """
    with open(csv_file, 'r', newline='', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        nodes = []

        for row in reader:
            object_name = row['object_name']
            field = {}

            for name in field_names:
                value = row[name].strip('"')
                if name == 'name':
                    value = value.lower()  # Force name element to lowercase
                    value = value.replace(' ', '_')  # Replace spaces with underscores in the name field
                else:
                    value = value.replace('\t', ' ')  # Replace tab characters with spaces in lead/trail positions

                field[name] = value

            # Append multi-part fields to the field dictionary
            for name in multi_part_fields:
                value = field[name]
                field[name] = [v.strip().replace(' ', '') for v in value.split('|')] if value else []

            node_index = next((i for i, node in enumerate(nodes) if node['name'] == object_name), None)

            if node_index is None:
                nodes.append({'name': object_name, 'fields': [field]})
            else:
                nodes[node_index]['fields'].append(field)

        # Save YAML files for each node
        for node in nodes:
            save_node_yaml(node, output_directory)

def save_node_yaml(node, output_directory):
    """
    Saves a YAML file for a specific node with its associated fields.

    Args:
        node (dict): Dictionary representing the node with 'name' and 'fields' keys.
        output_directory (str): Directory to save the generated YAML files.
    """
    yaml_file = os.path.join(output_directory, f"{node['name']}.yml")

    with open(yaml_file, 'w') as file:
        file.write("nodes:\n")
        file.write("  - name: " + node['name'] + "\n")
        file.write("    fields:\n")

        for field in node['fields']:
            file.write("      - name: " + field['name'] + "\n")
            file.write("        type: " + field['type'] + "\n")
            file.write("        description: " + field['description'] + "\n")

            for name in multi_part_fields:
                if field[name]:
                    file.write("        " + name + ":\n")
                    for value in field[name]:
                        file.write("          - " + value + "\n")


process_csv_file(csv_file, output_directory)












# import csv
# import os
# import yaml

# # Define the list of field names
# field_names = ['object_name', 'categories', 'constraints', 'type', 'name', 'description', 'returns', 'cms']

# # Define the multi-part fields
# multi_part_fields = ['categories', 'constraints', 'on_returns', 'cms']

# def process_csv_file(csv_file, output_directory):
#     """
#     Processes the CSV file and generates separate YAML files for each node.

#     Args:
#         csv_file (str): Path to the input CSV file.
#         output_directory (str): Directory to save the generated YAML files.
#     """
#     with open(csv_file, 'r') as file:
#         reader = csv.reader(file)
#         next(reader)  # Skip header row
#         nodes = []

#         for row in reader:
#             if len(row) >= len(field_names) + 1:
#                 object_name = row[0]
#                 field = {}

#                 for i, name in enumerate(field_names):
#                     value = row[i + 1].strip('"')  # Remove surrounding double quotes
#                     field[name] = value

#                 # Append multi-part fields to the field dictionary
#                 for name in multi_part_fields:
#                     value = field[name]
#                     field[name] = [v.strip() for v in value.split('|')] if value else []

#                 node_index = next((i for i, node in enumerate(nodes) if node['name'] == object_name), None)

#                 if node_index is None:
#                     nodes.append({'name': object_name, 'fields': [field]})
#                 else:
#                     nodes[node_index]['fields'].append(field)

#         # Save YAML files for each node
#         for node in nodes:
#             save_node_yaml(node, output_directory)

# def save_node_yaml(node, output_directory):
#     """
#     Saves a YAML file for a specific node with its associated fields.

#     Args:
#         node (dict): Dictionary representing the node with 'name' and 'fields' keys.
#         output_directory (str): Directory to save the generated YAML files.
#     """
#     yaml_file = os.path.join(output_directory, f"{node['name']}.yml")

#     print(yaml_file)

#     with open(yaml_file, 'w') as file:
#         file.write("nodes:\n")
#         file.write("  - name: " + node['name'] + "\n")
#         file.write("    fields:\n")

#         for field in node['fields']:
#             file.write("      - name: " + field['name'] + "\n")
#             file.write("        type: " + field['type'] + "\n")
#             file.write("        description: " + field['description'] + "\n")

#             for name in multi_part_fields:
#                 if field[name]:
#                     file.write("        " + name + ":\n")
#                     for value in field[name]:
#                         file.write("          - " + value + "\n")



# process_csv_file(csv_file, output_directory)




