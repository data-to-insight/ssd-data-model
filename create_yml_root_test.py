import csv
import os
import yaml

# Define the list of field names
field_names = ['name', 'type', 'description']

# Define the multi-part fields
multi_part_fields = ['returns', 'cms']

def process_csv_file(csv_file, output_directory):
    """
    Processes the CSV file and generates a YAML file for each object.

    Args:
        csv_file (str): Path to the input CSV file.
        output_directory (str): Directory to save the generated YAML files.
    """
    with open(csv_file, 'r') as file:
        reader = csv.DictReader(file)
        object_data = {}

        for row in reader:
            object_name = row['object_name']
            if object_name not in object_data:
                object_data[object_name] = []
            field = {}

            for name in field_names:
                value = row[name]
                if name == 'type' and not value:
                    continue  # Skip empty type column
                field[name] = value.strip('"')

            for name in multi_part_fields:
                value = row[name]
                if value:
                    field[name] = [v.strip() for v in value.split('|')]
                else:
                    field[name] = []

            object_data[object_name].append(field)

        # Save YAML files for each object
        for object_name, fields in object_data.items():
            save_object_yaml(object_name, fields, output_directory)

def save_object_yaml(object_name, fields, output_directory):
    """
    Saves a YAML file for a specific object with its associated fields.

    Args:
        object_name (str): Name of the object.
        fields (list): List of fields for the object.
        output_directory (str): Directory to save the generated YAML files.
    """
    yaml_file = os.path.join(output_directory, f"{object_name}.yml")

    with open(yaml_file, 'w') as file:
        file.write("nodes:\n")
        file.write(f"  - name: {object_name}\n")
        file.write("    fields:\n")

        for field in fields:
            file.write("      - name: " + field['name'] + "\n")
            if 'type' in field:
                file.write("        type: " + field['type'] + "\n")
            file.write("        description: " + field['description'] + "\n")

            for name in multi_part_fields:
                if field[name]:
                    file.write(f"        {name}:\n")
                    for value in field[name]:
                        file.write("          - " + value + "\n")




# Data Structure spec
csv_file = 'docs/struct_test.csv'     #  import from repo
output_directory = 'data/structure_objects_test/'

process_csv_file(csv_file, output_directory)
