import yaml
import json
import os
import re


# load yaml configuration
def load_yaml_config(yaml_file):
    with open(yaml_file, 'r') as file:
        return yaml.safe_load(file)

# function to extract meta blocks from sql
def extract_meta_blocks(lines):
    blocks = []
    current_block = []
    current_meta_info = None
    in_meta_block = False
    in_sql_block = False

    for line in lines:
        # detect start of a meta block using -- meta-object
        if '-- META-CONTAINER:' in line:
            if in_meta_block or in_sql_block:  # save previous block
                blocks.append((current_meta_info, current_block))
            current_block = []
            # extract json meta information
            meta_str = re.search(r'-- META-CONTAINER: ({.*})', line).group(1)
            current_meta_info = json.loads(meta_str)
            in_meta_block = True
            in_sql_block = False  # switch to meta block
            current_block.append(line)  # keep meta-object line intact

        # keep comment blocks after -- meta-object intact (do not treat as meta block)
        elif in_meta_block and line.startswith('--'):
            # preserve all comment lines following meta-object tag
            current_block.append(line)

        # handle other meta tags (like drop_table, create_table, etc.)
        elif '-- META-ELEMENT:' in line:
            if in_meta_block or in_sql_block:
                blocks.append((current_meta_info, current_block))
            current_block = []
            # extract json meta information for other meta tags
            meta_str = re.search(r'-- META-ELEMENT: ({.*})', line).group(1)
            current_meta_info = json.loads(meta_str)
            in_meta_block = True
            in_sql_block = False
            current_block.append(line)

        # capture sql lines following meta blocks
        elif not line.startswith('--'):
            if in_meta_block:
                blocks.append((current_meta_info, current_block))
                current_block = []
                in_meta_block = False
            current_block.append(line)
            in_sql_block = True

        else:
            # capture any remaining sql lines or comments not part of meta
            if in_sql_block or in_meta_block:
                current_block.append(line)

    # append any remaining block
    if current_meta_info and current_block:
        blocks.append((current_meta_info, current_block))

    return blocks



def process_parent_block(parent_name, blocks, remove_sql_objects, global_remove_flags, la_config):
    processed_lines = []


    # extract relevant configs from yaml
    # root settings/params/flags (at yml root level)
    deployment_system_settings = la_config.get('deployment_system', {})
    config_metadata = la_config.get('config_metadata', {})
    header_settings = la_config.get('header', {})
                                    
    # root-node settings/params/flags (at yml node level)
    
    extract_parameters = la_config.get('settings', {}).get('extract_parameters', {})
    temp_table_settings = la_config.get('settings', {}).get('persistent_ssd', {})
    dbschema_settings = la_config.get('settings', {}).get('dbschema', {})
    dev_setup_settings = la_config.get('settings', {}).get('dev_setup', {})


    global_sql_tag_remove = la_config.get('global_sql_tag_remove', {})
    named_sql_tag_remove = la_config.get('named_sql_tag_remove', {})  # added named remove list

    # process each block within parent block
    for meta_info, block_lines in blocks:
        block_type = meta_info.get("type", "")
        block_name = meta_info.get("name", None)  # check for block name

        # debugging: print block type and name being processed
        print(f"processing child block: {block_type}, within parent block name: {block_name}")

        # normalise block type
        normalised_block_type = block_type.lower()

        # process blocks based on type
        if normalised_block_type == "header":
            processed_block = process_header_block(block_lines, extract_parameters)
        
        elif normalised_block_type == "ssd_timeframe":
            processed_block = process_timeframe_block(block_lines, extract_parameters)

        elif normalised_block_type == "persistent_ssd":
            processed_block = process_persistent_ssd_block(block_lines, temp_table_settings)

        elif normalised_block_type == "dbschema":
            processed_block = process_dbschema_block(block_lines, dbschema_settings)

        elif normalised_block_type == "config_metadata":
            processed_block = process_config_metadata_block(block_lines, config_metadata)

        elif normalised_block_type == "deployment_system":
            processed_block = process_deployment_system_block(block_lines, deployment_system_settings)

        elif normalised_block_type == "dev_set_up":
            processed_block = process_dev_setup_block(block_lines, dev_setup_settings)  

        elif normalised_block_type == "settings":
            processed_block = process_settings_block(block_lines, la_config)  # handle settings block

        else:
            processed_block = process_remove_blocks(block_lines, normalised_block_type, remove_sql_objects, global_sql_tag_remove, block_name)

        processed_lines.extend(processed_block)

    return processed_lines



def process_remove_blocks(block_lines, block_type, remove_objects, global_remove_flags, block_name=None):
    processed_lines = []
    remove_block = False

    # # Debug: Print global removal flags and block type
    # print(f"Checking global flag for block_type '{block_type}': {global_remove_flags.get(f'remove_{block_type}', False)}")

    # Check if this block type is set for global removal
    if global_remove_flags.get(f'remove_{block_type}', False):
        remove_block = True
        print(f"Globally removing all {block_type} blocks.")  # This should trigger if the global flag is True

    # Check for named object removal based on YAML config
    remove_list = remove_objects.get(f'remove_{block_type}', [])
    if not remove_block and block_name and isinstance(remove_list, list):
        if block_name in remove_list:
            remove_block = True
            print(f"Locally removing {block_type} block for: {block_name}")

    # Retain block if not marked for removal
    if not remove_block:
        processed_lines.extend(block_lines)
    else:
        print(f"Block '{block_type}' is being removed.")

    return processed_lines




def extract_meta_blocks_with_children(lines):
    parent_blocks = []
    current_block = []
    current_meta_info = None
    current_parent_name = None
    child_blocks = []
    in_meta_block = False

    for line in lines:
        # detect start of a meta-object block using -- meta-object
        if '-- META-CONTAINER:' in line:
            if current_block:  # save previous parent block
                parent_blocks.append((current_parent_name, child_blocks))
            current_block = []
            child_blocks = []
            # extract json meta information
            meta_str = re.search(r'-- META-CONTAINER: ({.*?})', line).group(1)
            current_meta_info = json.loads(meta_str)
            current_parent_name = current_meta_info.get("name", "")
            in_meta_block = True
            current_block.append(line)  # keep meta-object line intact

        # detect start of meta tags within parent block (e.g., -- meta-elemet: {"type": "create_table"})
        elif '-- META-ELEMENT:' in line:
            if current_block:
                child_blocks.append((current_meta_info, current_block))
            current_block = []
            # extract json meta information for other meta tags
            meta_str = re.search(r'-- META-ELEMENT: ({.*?})', line).group(1)
            current_meta_info = json.loads(meta_str)
            in_meta_block = True
            current_block.append(line)

        # continue capturing sql lines for current block, including "GO" command
        elif not line.startswith('--') or line.strip().upper() == 'GO':
            if in_meta_block:
                current_block.append(line)

        else:
            if current_block:
                current_block.append(line)

    # append any remaining parent block
    if current_block:
        child_blocks.append((current_meta_info, current_block))
        parent_blocks.append((current_parent_name, child_blocks))

    return parent_blocks



def process_persistent_ssd_block(block_lines, persistent_ssd_settings):
    processed_lines = []

    # get settings from yaml config, default to true if not provided or none
    use_temp_tables = persistent_ssd_settings.get('deploy_temp_tables')

    # convert string values 
    # failsafe ('true', 'True', 'false', 'False') to bool
    if isinstance(use_temp_tables, str):
        use_temp_tables = use_temp_tables.lower() == 'true'

    # default to true/deploy as temp tbls if key is not provided 
    # failsafe to avoid 'accidental' persistant tables
    if use_temp_tables is None:
        use_temp_tables = True

    # regular expression to normalise whitespace (collapse spaces and tabs(especially tabs))
    whitespace_normaliser = re.compile(r"\s+")

    for line in block_lines:
        # normalise line by collapsing all sql spaces/tabs
        # ensure improved match/line identification
        normalised_line = whitespace_normaliser.sub(" ", line.strip())

        # check if normalised line contains target string
        if "SET @Run_SSD_As_Temporary_Tables" in normalised_line:
            temp_value = 1 if use_temp_tables else 0
            line = f"SET     @Run_SSD_As_Temporary_Tables = {temp_value};\n"
            # print(f"updated line to: {line}")  # debugging: extract to temp tables OR persistent 

        processed_lines.append(line)

    return processed_lines


def process_timeframe_block(block_lines, extract_parameters):
    processed_lines = []

    # Get params from YAML file 
    ssd_timeframe_years = extract_parameters.get('ssd_timeframe_years')
    ssd_sub1_range_years = extract_parameters.get('ssd_sub1_range_years')
    # last_sept_30th = extract_parameters.get('CaseloadLastSept30th') # ref: currently set in sql script

    for line in block_lines:
        if "DECLARE @ssd_timeframe_years" in line and ssd_timeframe_years is not None:
            # Replace the timeframe years with the value from the YAML file
            line = f"DECLARE @ssd_timeframe_years INT = {ssd_timeframe_years};\n"
        elif "DECLARE @ssd_sub1_range_years" in line and ssd_sub1_range_years is not None:
            # Replace the sub1 range years with the value from the YAML file
            line = f"DECLARE @ssd_sub1_range_years INT = {ssd_sub1_range_years};\n"

        # ref: currently set in sql script  
        # elif "DECLARE @CaseloadLastSept30th" in line and last_sept_30th:
        #     # Replace LastSept30th with the value from the YAML file (if provided)
        #     line = f"DECLARE @CaseloadLastSept30th DATE = '{last_sept_30th}';\n"

        processed_lines.append(line)

    return processed_lines





# Placeholder  : processing header
def process_header_block(block_lines, header_settings):
    print(f"processing header block with settings: {header_settings}")
    return block_lines  # 

# Placeholder  : processing dbschema
def process_dbschema_block(block_lines, dbschema_settings):
    print(f"processing dbschema block with settings: {dbschema_settings}")
    return block_lines  # 

# Placeholder  : processing config_metadata
def process_config_metadata_block(block_lines, config_metadata):
    print(f"processing config metadata block with settings: {config_metadata}")
    return block_lines  # 

# Placeholder  : processing deployment_system
def process_deployment_system_block(block_lines, deployment_system_settings):
    print(f"processing deployment system block with settings: {deployment_system_settings}")
    return block_lines  # 

def process_dev_setup_block(block_lines, dev_setup_settings):
    # process dev_set_up block to handle SET NOCOUNT ON/OFF

    no_count_on = dev_setup_settings.get('no_count_on', True)  # default to True if not provided

    # nocount based on config flag
    nocount_line = "SET NOCOUNT ON;\n" if no_count_on else "SET NOCOUNT OFF;\n"

    processed_lines = []

    for line in block_lines:
        if "SET NOCOUNT" in line:  # replace existing NOCOUNT line
            processed_lines.append(nocount_line)
        else:
            processed_lines.append(line)

    # if no NOCOUNT line found, append revised line
    if not any("SET NOCOUNT" in line for line in processed_lines):
        processed_lines.append(nocount_line)

    return processed_lines



# Placeholder  : processing settings
def process_settings_block(block_lines, la_config):
    # process settings block
    print(f"processing settings block")
    return block_lines  # 






def process_sql(la_config, master_sql_path, output_sql_path):
    with open(master_sql_path, 'r') as file:
        lines = file.readlines()

    # Extract relevant config from each YAML
    custom_la = la_config.get('extract_sql_custom_la', {})
    remove_sql_objects = custom_la.get('named_sql_tag_remove', {})
    global_remove_flags = custom_la.get('global_sql_tag_remove', {})

    # Extract all parent blocks and their children (grouped by meta-objects)
    parent_blocks = extract_meta_blocks_with_children(lines)
    
    # at this point parent_blocks contains the raw sql for each meta-object tagged block

    processed_lines = []

    # Process each parent block and its child blocks
    for parent_name, child_blocks in parent_blocks:
        # Pass la_config to the process_parent_block function
        processed_parent = process_parent_block(parent_name, child_blocks, remove_sql_objects, global_remove_flags, la_config)
        processed_lines.extend(processed_parent)

    # Write the modified SQL to a new file
    with open(output_sql_path, 'w') as file:
        file.writelines(processed_lines)




def process_all_yaml_files(yaml_directory, master_sql_path, output_directory):
    yaml_files = [f for f in os.listdir(yaml_directory) if f.endswith('.yml')]

    for yaml_file in yaml_files:
        print(f"Processing file: {yaml_file}")

        try:
            yaml_config = load_yaml_config(os.path.join(yaml_directory, yaml_file))
            print(f"Loaded YAML config: {yaml_config}")
        except Exception as e:
            print(f"Error loading {yaml_file}: {e}")
            continue

        la_code_str = next(iter(yaml_config))
        la_config = yaml_config[la_code_str]

        cms_value = la_config.get('cms', '').lower()
        if cms_value != 'systemc':
            print(f"Skipping {yaml_file} due to mismatched CMS: {cms_value}")
            continue

        la_code = la_config.get('la_code', '')
        la_name = la_config.get('la_name', '').lower()
        cms = la_config.get('cms', '').lower()
        cms_db = la_config.get('cms_db', '').lower()

        if not la_code or not la_name or not cms or not cms_db:
            print(f"Missing data in YAML file {yaml_file}: la_code={la_code}, la_name={la_name}, cms={cms}, cms_db={cms_db}")
            continue

        output_file_name = f"{la_code}_{la_name}_{cms}_{cms_db}.sql"

        output_sql_path = os.path.join(output_directory, output_file_name)
        process_sql(la_config, master_sql_path, output_sql_path)

        print(f"Generated SQL file: {output_file_name}")




# Add the main execution block
if __name__ == "__main__":
    yaml_directory = '/workspaces/ssd-data-model/la_config_files__future_release/'
    current_extract_ver_filename = 'liquidlogic_sqlserver_test.sql' # note test file in use 
    master_sql_path = '/workspaces/ssd-data-model/deployment_extracts/systemc/live/' + current_extract_ver_filename
    output_directory = '/workspaces/ssd-data-model/deployment_extracts__future_release/'

    process_all_yaml_files(yaml_directory, master_sql_path, output_directory)


