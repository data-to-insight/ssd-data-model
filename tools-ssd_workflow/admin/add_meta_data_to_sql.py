import os
import re
import csv

def load_field_data_from_csv(csv_path):
    specification = {}
    with open(csv_path, mode='r', newline='', encoding='utf-8-sig') as file:
        reader = csv.DictReader(file)
        for row in reader:
            item_ref = row['item_ref'].strip()
            field_name = row['field_name'].strip().lower()  # Ensure case insensitivity
            field_type = row['type'].strip()
            max_field_size = row['max_field_size'].strip()
            specification[field_name] = {
                'item_ref': item_ref,
                'type': field_type,
                'max_field_size': max_field_size
            }
    return specification

def add_metadata_to_sql(sql_text, specification):
    table_pattern = re.compile(r'CREATE TABLE\s+\w+\s*\((.*?)\);', re.DOTALL)
    # Regex matches the entire field definition including trailing comma if present
    field_pattern = re.compile(r'(\w+)\s+([\w()]+(?:\(\d+\))?)(.*?)(,|$)', re.MULTILINE)

    modified_sql = sql_text
    tables = table_pattern.findall(sql_text)

    for table_content in tables:
        original_table_content = table_content
        modified_table_content = original_table_content

        for match in field_pattern.finditer(table_content):
            field_name, field_type, sql_suffix, comma = match.groups()
            field_key = field_name.lower()  # Ensure case insensitivity
            if field_key in specification:
                spec = specification[field_key]
                metadata_comment = f" -- item_ref={spec['item_ref']}, type={spec['type']}, max_field_size={spec['max_field_size']}"
                # Insert metadata comment before any SQL suffix and after the type or size, include comma if it was part of the match
                new_field_text = f"{field_name} {field_type}{sql_suffix}{metadata_comment}{comma}"
                modified_table_content = modified_table_content.replace(match.group(0), new_field_text, 1)

        # Replace the original table content with the modified one in the final SQL
        modified_sql = modified_sql.replace(original_table_content, modified_table_content)

    return modified_sql

def process_single_sql_file(sql_dir, sql_filename, spec_path, output_filename):
    specification = load_field_data_from_csv(spec_path)
    full_path = os.path.join(sql_dir, sql_filename)
    with open(full_path, 'r', encoding='utf-8') as file:
        sql_text = file.read()
    modified_sql = add_metadata_to_sql(sql_text, specification)
    with open(output_filename, 'w', encoding='utf-8') as file:
        file.write(modified_sql)
    print(f"Modified SQL saved to {output_filename}")


# Configuration
sql_source_dir = 'cms_ssd_extract_sql/systemc/'
sql_filename = 'liquidlogic_sqlserver_perm_ssd.sql'  # Adjust the filename as necessary
csv_path = 'docs/admin/data_objects_specification.csv'
output_filename = 'modified_liquidlogic_sqlserver_perm_ssd.sql'




# Execute the function
process_single_sql_file(sql_source_dir, sql_filename, csv_path, output_filename)
