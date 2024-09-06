import yaml
import json
import os
import glob
import re

current_extract_ver_filename = 'liquidlogic_sqlserver_v1.2.1_1_20240830.sql'

def load_yaml_config(yaml_file):
    with open(yaml_file, 'r') as file:
        return yaml.safe_load(file)

def process_sql(la_config, master_sql_path, output_sql_path):
    with open(master_sql_path, 'r') as file:
        lines = file.readlines()

    processed_lines = []
    in_block = False
    block_meta = None

    # get la_name in uppercase for comment
    la_name_upper = la_config.get('la_name', '').upper()

    # extract configuration details from la_config
    extract_sql_customisations = la_config.get('extract_sql_customisations', {})
    remove_tables = extract_sql_customisations.get('remove_tables', [])
    remove_table_idx = extract_sql_customisations.get('remove_table_idx', [])

    for line in lines:
        # check start of a meta block
        if line.strip().startswith('-- META:'):
            # extract metadata
            meta_str = line.strip()[len('-- META:'):].strip()
            block_meta = json.loads(meta_str)
            block_type = block_meta.get('type', '')
            block_name = block_meta.get('name', '')

            # handle block types for tables and indexes
            if block_type == 'create_table' and block_name in remove_tables:
                in_block = True  # skip entire table block
                processed_lines.append(f"\n\n/***************** {la_name_upper} CONFIG REMOVED SQL BLOCK : {block_type} *****************/\n\n")
            elif block_type == 'create_idx' and block_name in remove_table_idx:
                in_block = True  # skip index block
                processed_lines.append(f"\n\n/***************** {la_name_upper} CONFIG REMOVED SQL BLOCK : {block_type} *****************/\n\n")
            else:
                in_block = False

        # check end of a meta block
        elif line.strip() == '-- META-END':
            in_block = False
            continue

        # if not in a block to remove, append line to output
        if not in_block:
            processed_lines.append(line)

    # write modified sql to a new file
    with open(output_sql_path, 'w') as file:
        file.writelines(processed_lines)

def generate_sql_file_name(la_config):
    # get la_code, la_name, cms, and cms_db from la_config and convert to lowercase
    la_code = str(la_config.get('la_code', '')).lower()
    la_name = la_config.get('la_name', '').lower()
    cms = la_config.get('cms', '').lower()
    cms_db = la_config.get('cms_db', '').lower()

    # generate file name using convention
    return f"{la_code}_{la_name}_{cms}_{cms_db}.sql"

def process_all_yaml_files(yaml_directory, master_sql_path, output_directory):
    # find all .yml files in specified directory
    yaml_files = glob.glob(os.path.join(yaml_directory, "*.yml"))

    for yaml_file in yaml_files:
        # load yaml config
        yaml_config = load_yaml_config(yaml_file)

        # since yaml has a top-level key (e.g., '208'), extract it
        la_code_str = next(iter(yaml_config))
        la_config = yaml_config[la_code_str]

        # check if 'cms' is 'systemc', otherwise skip
        cms_value = la_config.get('cms', '').lower()
        if cms_value != 'systemc':
            continue  # skip processing this yaml file

        # generate sql file name based on la_config's la_code, la_name, cms, and cms_db
        output_file_name = generate_sql_file_name(la_config)

        # define full output path for new sql file
        output_sql_path = os.path.join(output_directory, output_file_name)

        # process sql file, applying changes based on la_config
        process_sql(la_config, master_sql_path, output_sql_path)

        print(f"generated sql file: {output_sql_path}")

# define paths
yaml_directory = '/workspaces/ssd-data-model/la_config_files__future_release/'
master_sql_path = '/workspaces/ssd-data-model/deployment_extracts/systemc/live/' + current_extract_ver_filename
output_directory = '/workspaces/ssd-data-model/deployment_extracts__future_release/'

# process all yaml files and generate corresponding sql files
process_all_yaml_files(yaml_directory, master_sql_path, output_directory)
