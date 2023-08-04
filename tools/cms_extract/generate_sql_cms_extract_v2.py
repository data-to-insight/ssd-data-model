
import os
import csv
import yaml


def check_file_exists(file_path):
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"The file {file_path} does not exist. Please ensure the path is correct.")


def process_csv(file_path):
    tables = {}
    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            table_name, column_name, data_type, max_length, nullable, column_key, ref_table, ref_column = row
            if table_name not in tables:
                tables[table_name] = {'columns': {}}
            tables[table_name]['columns'][column_name] = {
                'type': data_type,
                'nullable': nullable == 'YES'
            }
            if max_length:
                tables[table_name]['columns'][column_name]['max_length'] = int(max_length)
            if column_key == 'PRI':
                tables[table_name]['primary_key'] = column_name
            if ref_table and column_key == 'MUL':
                tables[table_name]['foreign_keys'] = {
                    column_name: {
                        'references': ref_table,
                        'on_column': ref_column
                    }
                }
    return tables


def save_to_yaml(data, file_name):
    with open(file_name, 'w') as file:
        yaml.dump(data, file, default_flow_style=False)
    print(f"{file_name} created successfully!")


# Define the local authority name
la_name = 'Essex'

# CSV file path
csv_file_path = 'result.csv'

# Check if the file exists
check_file_exists(csv_file_path)

# Process the CSV
tables = process_csv(csv_file_path)

# Format as YAML and save
yaml_file_name = f'{la_name.lower()}.yml'
yaml_data = {'tables': tables}
save_to_yaml(yaml_data, yaml_file_name)
