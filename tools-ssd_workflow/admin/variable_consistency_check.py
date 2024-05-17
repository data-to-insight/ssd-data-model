import os
import glob
import re
import csv

# Search in the following locations
directories = [
    'cms_ssd_extract_sql/mosaic/',    # Mosaic scripts
    'cms_ssd_extract_sql/systemc/'    # SystemC scripts
    # 'cms_ssd_extract_sql/azeus/',     # Azeus scripts
    # 'cms_ssd_extract_sql/caredirector/', # Care Director scripts
    # 'cms_ssd_extract_sql/eclipse/' # Eclipse scripts
]

# main spec input date to compare against (needs item_ref, field_name as cols)
csv_path = 'docs/admin/data_objects_specification.csv'  # Path to spec data/csv LIVE
# csv_path = 'docs/admin/spec_consistency_check_data.csv' # TESTING

# output_dir = os.path.dirname(__file__)  # Find current location as default
output_dir = 'tools-ssd_workflow/admin/'  # Used as output dir

def load_field_data_from_csv(csv_path):
    field_names = set()
    field_data = []
    with open(csv_path, mode='r', newline='', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        for row in reader:
            try:
                item_ref = row['item_ref']
                field_name = row['field_name']
                if item_ref is None or field_name is None:
                    raise ValueError(f"Missing value in row: {row}")
                item_ref = item_ref.strip()
                field_name = field_name.strip()
                if item_ref and field_name:  # Only add if both are not empty
                    field_names.add(field_name)
                    field_data.append((item_ref, field_name))
            except KeyError as e:
                print(f"Missing expected column in row: {row}. Error: {e}")
            except ValueError as e:
                print(f"Data error: {e}")
    return field_names, field_data

def extract_variables_from_sql(content):
    content = re.sub(r'\s+', ' ', content)  # clean up whitespace (helps with improved/accurate var search hits)
    pattern = re.compile(r'\b[a-zA-Z0-9]{4}_[a-zA-Z0-9_]+\b')
    found_variables = set(pattern.findall(content))

    # filter to remove variables starting with known prefixes
    prefixes_to_ignore = {'CARE_', 'ROOM_', 'LAST_', 'FACT_', 'SEEN_', 'date_', 'prev_', 'text_', 'step_', 'days_', 'form_', 'MSRS_', 'full_', 'calc_'} 
    
    # rem cms data-point refs so they dont dilute the search outputs
    filtered_variables = {var for var in found_variables if not var.isupper() and not any(var.startswith(prefix) for prefix in prefixes_to_ignore)} # filter + all-uppercase variables
    
    return filtered_variables


def initialise_not_found_files(directory, field_data):
    directory_label = os.path.basename(os.path.normpath(directory))
    not_found_csv_path = os.path.join(output_dir, f'{directory_label}_not_found.csv')
    with open(not_found_csv_path, mode='w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['item_ref', 'field_name'])
        writer.writerows(field_data)
    return not_found_csv_path

def update_not_found_file(not_found_csv_path, sql_variables):
    with open(not_found_csv_path, mode='r', newline='', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        remaining_fields = [row for row in reader if row['field_name'] not in sql_variables]

    with open(not_found_csv_path, mode='w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=['item_ref', 'field_name'])
        writer.writeheader()
        writer.writerows(remaining_fields)

def find_extra_variables(directory, field_names):
    extra_variables = set()
    file_pattern = os.path.join(directory, '*.sql')
    sql_files = glob.glob(file_pattern)

    for file_path in sql_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                file_content = file.read()
                sql_variables = extract_variables_from_sql(file_content)
                extra_variables.update(sql_variables - field_names)
        except UnicodeDecodeError:
            continue  # Skip files that can't be decoded

    return extra_variables

field_names, field_data = load_field_data_from_csv(csv_path)

for directory in directories:
    cms_label = os.path.basename(os.path.normpath(directory)) # get dir name from path for use as filename
    not_found_csv_path = initialise_not_found_files(directory, field_data)
    extra_variables_csv_path = os.path.join(output_dir, f'{cms_label}_extra_variables.csv')

    # Find 'extra' variables before processing individual files
    # i.e. those that appear in scripts, but not in the spec (chk backwards compatibility)
    extra_variables = find_extra_variables(directory, field_names)

    sql_files = glob.glob(os.path.join(directory, '*.sql'))
    for file_path in sql_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                file_content = file.read()
                sql_variables = extract_variables_from_sql(file_content)
                update_not_found_file(not_found_csv_path, sql_variables)
        except UnicodeDecodeError:
            continue  # Skip files that can't be decoded

    # Write 'extra' variables after processing all SQL files
    with open(extra_variables_csv_path, mode='w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['Extra Variables Not in Spec'])
        for variable in extra_variables:
            writer.writerow([variable])

    print(f"Variables <not-found> list for {cms_label} saved as: {not_found_csv_path}")
    print(f"Variables <non-compliant> list for {cms_label} saved as: {extra_variables_csv_path}")
