import os
import glob
import re
import csv

# Multi dir support
directories = [
    'cms_ssd_extract_sql/mosaic/import_raw/',    # Mosaic scripts
    'cms_ssd_extract_sql/systemc_liquidlogic/'  # Liquid Logic scripts
]

csv_path = 'docs/admin/data_objects_specification.csv'  # Path to spec data/csv LIVE

# List of item_ref codes to ignore
item_ref_ignore_list = [
    "S251001A", "S251002A", "S251003A", "S251004A", "S251005A", "S251006A",
    "VOCH001A", "VOCH002A", "VOCH003A", "VOCH004A", "VOCH005A", "VOCH006A", "VOCH007A",
    "PREP001A", "PREP002A", "PREP003A", "PREP004A", "PREP005A", "PREP006A", "PREP007A", "PREP008A", "PREP009A", "PREP010A",
    "PREP011A", "PREP012A", "PREP013A", "PREP014A", "PREP015A", "PREP016A", "PREP017A", "PREP018A", "PREP019A", "PREP020A",
    "PREP021A", "PREP022A", "PREP023A", "PREP024A"
]

def load_field_data_from_csv(csv_path):
    field_data = []
    with open(csv_path, mode='r', newline='', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        for row in reader:
            item_ref = row['item_ref'].strip()
            field_name = row['field_name'].strip()
            if item_ref not in item_ref_ignore_list:
                field_data.append((item_ref, field_name))
    return field_data

def extract_variables_from_sql(content):
    pattern = re.compile(r'\b[a-z0-9]{4}_[a-z0-9_]*\b')
    return set(pattern.findall(content))

def find_consistency_in_sql_files(directories, field_data):
    all_not_found = []
    extra_fields = set()
    files_checked = 0

    for directory in directories:
        file_pattern = os.path.join(directory, '*.sql')
        sql_files = glob.glob(file_pattern)

        for file_path in sql_files:
            files_checked += 1
            try:
                with open(file_path, 'r', encoding='utf-8') as file:
                    file_content = file.read()
                    sql_variables = extract_variables_from_sql(file_content)
                    found_fields = set()
                    for item_ref, field_name in field_data:
                        if field_name in sql_variables:
                            found_fields.add(field_name)
                    # Gather fields not found in current file
                    for item_ref, field_name in field_data:
                        if field_name not in found_fields and item_ref not in item_ref_ignore_list:
                            all_not_found.append((item_ref, field_name))
            except UnicodeDecodeError:
                with open(file_path, 'r', encoding='iso-8859-1') as file:
                    file_content = file.read()
                    sql_variables = extract_variables_from_sql(file_content)
                    found_fields = set()
                    for item_ref, field_name in field_data:
                        if field_name in sql_variables:
                            found_fields.add(field_name)
                    for item_ref, field_name in field_data:
                        if field_name not in found_fields and item_ref not in item_ref_ignore_list:
                            all_not_found.append((item_ref, field_name))
            extra_fields.update(sql_variables)

    return all_not_found, extra_fields, files_checked

field_data = load_field_data_from_csv(csv_path)
all_not_found, extra_fields, files_checked = find_consistency_in_sql_files(directories, field_data)

# Output to CSV
output_dir = os.path.dirname(__file__)  # Current directory
not_found_csv_path = os.path.join(output_dir, 'item_refs_not_found.csv')
missing_fields_csv_path = os.path.join(output_dir, 'missing_fields.csv')
extra_fields_csv_path = os.path.join(output_dir, 'extra_fields.csv')

with open(not_found_csv_path, mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerow(['item_ref', 'field_name'])
    for item_ref, field_name in all_not_found:
        writer.writerow([item_ref, field_name])

with open(missing_fields_csv_path, mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerow(['item_ref', 'field_name'])
    for item_ref, field_name in all_not_found:
        writer.writerow([item_ref, field_name])

with open(extra_fields_csv_path, mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerow(['Extra Variables Not in Spec'])
    for field in extra_fields:
        writer.writerow([field])

print(f"Results written to {missing_fields_csv_path}, {extra_fields_csv_path}, and {not_found_csv_path}.")
