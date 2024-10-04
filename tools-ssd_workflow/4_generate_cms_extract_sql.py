import yaml
import json 
import os
import re
import glob # used only on yml/script access



def process_dbschema_block(block_lines, dbschema_settings):
    """
    Process db schema block to replace database and schema names using yml config settings.
    """
    processed_lines = []
    
    # Get database and schema names from yaml config
    database_name = dbschema_settings.get('deployment_database_name')
    schema_name = dbschema_settings.get('deployment_schema_name')

    print(f"dbschema_settings: {dbschema_settings}")  # Debugging the config data

    # Ensure yml falsy value set as an empty string 
    if not schema_name: 
        schema_name = ""  

    # Collapse multiple spaces
    whitespace_normaliser = re.compile(r"\s+")

    # Track replacements to avoid duplicate output
    db_name_replaced = False
    schema_name_replaced = False

    for line in block_lines:
        normalised_line = whitespace_normaliser.sub(" ", line.strip().lower())

        
        # print(f"Processing line: {line.strip()}") # Debugging 

        # Locate and set database name from yml, but only replace once
        if "use " in normalised_line and database_name and not db_name_replaced:
            print(f"Replacing DB/TABLE_CATALOG with : {database_name}") # Debugging 
            line = f"USE {database_name};\n"
            db_name_replaced = True

        elif "declare @schema_name" in normalised_line and not schema_name_replaced:
            if schema_name:
                print(f"Replacing schema_name with : '{schema_name}'") # debugging
            else:
                # print("No schema_name provided, using default or empty schema.") # debugging
                pass

            line = f"DECLARE @schema_name NVARCHAR(128) = '{schema_name}';\n"
            schema_name_replaced = True

        elif "declare @tablename" in normalised_line:
            # Keep original @TableName line intact
            processed_lines.append(line)
            continue

        processed_lines.append(line)

    # print(f"Processed dbschema block: {processed_lines}")  # Final # Debugging output of processed block
    return processed_lines



def remove_named_sql_containers(sql_lines, containers_to_remove):
    """
    Remove blocks of SQL between -- META-CONTAINER and -- META-END for specified container names.
    """
    processed_lines = []
    in_container_block = False
    container_name = ""
    container_pattern = re.compile(r'-- META-CONTAINER: {.*"name": "(.*?)".*}')  # Regex to find container name
    end_pattern = re.compile(r'-- META-END')

    for line in sql_lines:
        # Check if current line is META-CONTAINER line with name
        container_match = container_pattern.match(line)
        if container_match:
            container_name = container_match.group(1)
            # If container name is in remove list, skip block until -- META-END
            if container_name in containers_to_remove:
                in_container_block = True
                processed_lines.append(line)  # Keep the container start tag
                continue  # Move to the next line

        # If in container block, check if it's end of block
        if in_container_block:
            if end_pattern.match(line):
                in_container_block = False
                processed_lines.append(line)  # Keep -- META-END tag
            continue  # Skip lines in between start and end tags

        # If not in a block to remove, keep line
        processed_lines.append(line)

    return processed_lines



def process_config_metadata_block(config_metadata):
    """
    process config metadata block, add metadata dets from yml config settings.
    """
    processed_lines = []

    # get metadata from yaml config
    last_updated = config_metadata.get('last_updated', 'unknown date')
    version = config_metadata.get('version', 'unknown version')
    updated_by = config_metadata.get('updated_by', 'unknown author')
    change_description = config_metadata.get('change_description', 'no description provided')
    documentation_link = config_metadata.get('documentation_link', 'no documentation link')

    # build readable statement with /* ... */ comment block
    metadata_statement = (
        f"/*\n"
        f"Config metadata last updated on {last_updated} (version {version}) by {updated_by}.\n"
        f"Change description: {change_description}\n"
        f"Project and submit change request link: {documentation_link}\n"
        f"*********************************************************************************************************\n"
        f"*/\n"
    )

    # add formatting line breaks before re-adding meta-element tag
    processed_lines.append("\n\n-- META-ELEMENT: {\"type\": \"config_metadata\"}\n")
    processed_lines.append(metadata_statement)

    return processed_lines



def process_deployment_system_block(block_lines, deployment_system_settings, la_code, la_name):
    """
    process deployment system block to format deployment settings for provided config.
    """
    processed_lines = []

    # get deployment system settings from yaml config, default to empty string if none
    cms = deployment_system_settings.get('cms', '')
    cms_db = deployment_system_settings.get('cms_db', '')
    db_vers = deployment_system_settings.get('db_vers', '')
    ics_universe_vers = deployment_system_settings.get('ics_universe_vers', '')
    data_warehouse_vers = deployment_system_settings.get('data_warehouse_vers', '')
    front_end_vers = deployment_system_settings.get('front_end_vers', '')

    # list of values, print output skips over possible 'None' vals
    deployment_values = [cms, cms_db, db_vers, ics_universe_vers, data_warehouse_vers, front_end_vers]
    filtered_values = [value for value in deployment_values if value]  # only keep non-empty values
    deployment_system_info = ' | '.join(filtered_values)

    # build readable statement with /* ... */ comment block
    deployment_statement = (
        f"/*\n"
        f"Bespoke SSD extract script for {la_name} ({la_code}).\n"
        f"Expected deployment system: {deployment_system_info}.\n"
        f"*********************************************************************************************************\n"
        f"*/\n"
    )

    # add output formatting
    processed_lines.append("\n\n-- META-ELEMENT: {\"type\": \"deployment_system\"}\n")

    # add new deployment system info within comment block
    processed_lines.append(deployment_statement)

    return processed_lines



def process_header_block(block_lines, header_settings):
    """
    process header block updating or replacing header text in provided config.
    """
    processed_lines = []
    
    # get header_text from header_settings if present
    header_text = header_settings.get('header_text', None)

    # assuming not inside comment block
    inside_comment_block = False
    found_meta_element = False

    # if header_text set, construct new header block
    if header_text:
        new_header_block = (
            f"/*\n"
            f"{header_text}"
            f"*/\n"
        )

    # process block_lines removing existing header text
    for line in block_lines:
        # skip header replacement for meta-container, only process m-element
        if "-- META-ELEMENT" in line and "header" in line:
            found_meta_element = True
            processed_lines.append(line)
            continue

        # detect start of comment block
        if "/*" in line:
            inside_comment_block = True
            continue  # skip line (remove old header)

        # detect end of comment block
        if "*/" in line and inside_comment_block:
            inside_comment_block = False
            continue  # skip line (remove old header)

        # append remaining lines if not inside comment block
        if not inside_comment_block:
            processed_lines.append(line)

    # if new header provided, append it below meta-element tag
    if header_text and found_meta_element:
        processed_lines.append(new_header_block)

    return processed_lines




def process_settings_block(block_lines, la_config):
    """
    process settings block from provided config without modifications.
    """
    processed_lines = []

    # currently not performing specific processing, can be extended
    processed_lines.extend(block_lines)

    return processed_lines


def process_remove_blocks(block_lines, block_type, remove_objects, global_remove_flags, block_name=None):
    """
    Process and remove blocks based on global and named removal flags from config.
    Handles cases where multiple blocks of the same type exist.
    """
    processed_lines = []
    remove_block = False

    # Ensure remove_objects is a dictionary, even if None
    if remove_objects is None:
        remove_objects = {}

    # Debug: Print block type, block name, and global removal flag status
    # print(f"Checking block: type = '{block_type}', name = '{block_name}'")
    # print(f"Global removal flag for '{block_type}': {global_remove_flags.get(f'remove_{block_type}', False)}")

    # Check if block type is set for global removal
    # this being flags set to true within yml global_sql_tag_remove: 
    if global_remove_flags.get(f'remove_{block_type}', False):
        remove_block = True
        # print(f"Globally removing all {block_type} blocks.")

    # Check for named object removal based on YAML config
    remove_list = remove_objects.get(f'remove_{block_type}', [])
    remove_list = [item for item in remove_list if item]  # Remove empty values
    # print(f"Remove list for block type {block_type}: {remove_list}")

    # Check for local (named) removal
    if not remove_block and block_name and isinstance(remove_list, list):
        if block_name in remove_list:
            remove_block = True
            # print(f"Locally removing {block_type} block for: {block_name}")

    # Retain or remove the entire block (multi-line)
    if not remove_block:
        processed_lines.extend(block_lines)
    else:
        # print(f"Block '{block_type}' for {block_name} is being removed.")
        pass


    # Handle the specific case of console_output
    if block_type == 'console_output':
        if global_remove_flags.get('remove_console', False):
            print(f"Removing console_output block globally.")
            return []  # If flagged for removal, skip the entire console block

        # If the global flag is False, ensure no console_output blocks are removed
        else:
            processed_lines.extend(block_lines)

    return processed_lines




def search_and_replace_in_sql(block_lines, search_string, replace_string):
    """
    helper function to search for a specific string in SQL block and replace globally
    """
    modified_lines = [line.replace(search_string, replace_string) for line in block_lines]
    return modified_lines





def process_timeframe_block(block_lines, extract_parameters):
    """
    process and modify timeframe block based on config settings.
    """
    processed_lines = []

    # get params from yaml file
    ssd_timeframe_years = extract_parameters.get('ssd_timeframe_years')
    ssd_sub1_range_years = extract_parameters.get('ssd_sub1_range_years')

    for line in block_lines:
        if "DECLARE @ssd_timeframe_years" in line and ssd_timeframe_years is not None:
            line = f"DECLARE @ssd_timeframe_years INT = {ssd_timeframe_years};\n"
        elif "DECLARE @ssd_sub1_range_years" in line and ssd_sub1_range_years is not None:
            line = f"DECLARE @ssd_sub1_range_years INT = {ssd_sub1_range_years};\n"

        processed_lines.append(line)

    return processed_lines



def process_dev_setup_block(block_lines, dev_setup_settings):
    """
    process and modify dev setup block based on config settings.
    """
    no_count_on = dev_setup_settings.get('no_count_on', True)  # default True if not provided
    nocount_line = "SET NOCOUNT ON;\n" if no_count_on else "SET NOCOUNT OFF;\n"

    # replace existing nocount setting
    processed_lines = [line for line in block_lines if "SET NOCOUNT" not in line]
    processed_lines.append(nocount_line)

    return processed_lines


def extract_meta_blocks(lines):
    """
    extract meta-container and meta-element blocks from sql lines.
    """
    blocks = []
    current_block = []
    current_meta_info = None
    in_meta_block = False
    in_sql_block = False

    for line in lines:
        # detect start of meta-container using -- meta-object
        if '-- META-CONTAINER:' in line:
            if in_meta_block or in_sql_block:
                blocks.append((current_meta_info, current_block))
            current_block = []
            # get json meta info
            meta_str = re.search(r'-- META-CONTAINER: ({.*})', line).group(1)
            current_meta_info = json.loads(meta_str)
            in_meta_block = True
            in_sql_block = False
            current_block.append(line)

        # preserve comment blocks after meta-object tag
        elif in_meta_block and line.startswith('--'):
            current_block.append(line)

        # handle meta-element blocks like drop_table, create_table, etc.
        elif '-- META-ELEMENT:' in line:
            if in_meta_block or in_sql_block:
                blocks.append((current_meta_info, current_block))
            current_block = []
            # get json meta info for meta-element blocks
            meta_str = re.search(r'-- META-ELEMENT: ({.*})', line).group(1)
            current_meta_info = json.loads(meta_str)
            in_meta_block = True
            in_sql_block = False
            current_block.append(line)

        # capture sql lines after meta blocks
        elif not line.startswith('--'):
            if in_meta_block:
                blocks.append((current_meta_info, current_block))
                current_block = []
                in_meta_block = False
            current_block.append(line)
            in_sql_block = True

        else:
            if in_sql_block or in_meta_block:
                current_block.append(line)

    # append any remaining block
    if current_meta_info and current_block:
        blocks.append((current_meta_info, current_block))

    return blocks




def extract_meta_blocks_with_children(lines):
    """
    Extract meta-container (parent) and m-element (child/sub) blocks from SQL lines.
    """
    parent_blocks = []
    current_block = []
    current_meta_info = None
    current_parent_name = None
    child_blocks = []
    in_meta_block = False

    for line in lines:
        # Detect start of meta-container using -- META-CONTAINER
        if '-- META-CONTAINER:' in line:
            # Save the previous parent and its child blocks, if any
            if current_block:
                child_blocks.append((current_meta_info, current_block))
                parent_blocks.append((current_parent_name, child_blocks))
                print(f"Appending parent block: {current_parent_name} with children: {len(child_blocks)}")  # Debug

            # Reset the current block and child blocks
            current_block = []
            child_blocks = []
            
            # Get JSON meta info for the container
            meta_str = re.search(r'-- META-CONTAINER: ({.*?})', line).group(1)
            current_meta_info = json.loads(meta_str)
            current_parent_name = current_meta_info.get("name", "")
            in_meta_block = True
            current_block.append(line)
            print(f"Detected META-CONTAINER: {current_meta_info}")  # Debugging the detected container

        # Detect start of meta-elements (e.g., -- META-ELEMENT: {"type": "create_table"} or dbschema)
        elif '-- META-ELEMENT:' in line:
            if current_block:
                # Append the previous element to the child blocks
                child_blocks.append((current_meta_info, current_block))
                # print(f"Appending child block: {current_meta_info}")  # Debugging child block append
                current_block = []

            # Get JSON meta info for the meta-element
            meta_str = re.search(r'-- META-ELEMENT: ({.*?})', line).group(1)
            current_meta_info = json.loads(meta_str)
            # print(f"Detected META-ELEMENT: {current_meta_info}")  # Debugging the detected meta-element
            in_meta_block = True
            current_block.append(line)

        # Continue capturing SQL lines for the current block, including the "GO" command
        elif not line.startswith('--') or line.strip().upper() == 'GO':
            if in_meta_block:
                current_block.append(line)

        else:
            if current_block:
                current_block.append(line)

    # Append any remaining meta-container block at the end of the file
    if current_block:
        child_blocks.append((current_meta_info, current_block))
        parent_blocks.append((current_parent_name, child_blocks))
        # print(f"Final append parent block: {current_parent_name} with children: {len(child_blocks)}")  # Debugging

    return parent_blocks



def process_parent_block(parent_name, child_blocks, named_sql_tag_remove, global_sql_tag_remove, la_config):
    """
    process m-elements (child/sub) within a meta-container (parent), applying global and named object/table removals.
    """
    processed_lines = []

    # get relevant configs from yaml

    # root yml blocks
    la_code = la_config.get('la_code', {})
    la_name = la_config.get('la_name', {})
    deployment_system_settings = la_config.get('deployment_system', {})
    config_metadata = la_config.get('config_metadata', {})
    header_settings = la_config.get('header', {})

    # sub yml elements
    extract_parameters = la_config.get('settings', {}).get('extract_parameters', {})
    temp_table_settings = la_config.get('settings', {}).get('persistent_ssd', {})
    dbschema_settings = la_config.get('settings', {}).get('dbschema', {})
    dev_setup_settings = la_config.get('settings', {}).get('dev_setup', {})


    # process each m-element within meta-container
    for meta_info, block_lines in child_blocks:
        block_type = meta_info.get("type", "")
        block_name = meta_info.get("name", parent_name)  # inherit meta-container name if block_name is None

        # print(f"Processing m-element: {block_type}, within meta-container name: {block_name}") # debugging

        # normalise block type
        normalised_block_type = block_type.lower().strip()

        # call process_remove_blocks to handle global and named removals for all block types
        processed_block = process_remove_blocks(block_lines, normalised_block_type, named_sql_tag_remove, global_sql_tag_remove, block_name)

        # print(f"Block type before normalisation: '{block_type}', after normalization: '{normalised_block_type}'") # debugging

        if not processed_block:
            # if block was removed (globally or locally), skip further processing
            # print(f"Block {block_type} within {block_name} was removed.") # debugging
            continue
        

        # process core (settings) blocks based on type
        if normalised_block_type == "header":
            processed_block = process_header_block(block_lines, header_settings)

        elif normalised_block_type == "ssd_timeframe":
            # defines ssd timeframe params agreed by la, default 5yrs
            processed_block = process_timeframe_block(block_lines, extract_parameters)

        elif normalised_block_type == "persistent_ssd":
            # checks if la requested persistent ssd implementation or temp tables
            processed_block = process_persistent_ssd_block(block_lines, temp_table_settings)

        elif normalised_block_type == "dbschema":
            processed_block = process_dbschema_block(block_lines, dbschema_settings)

        elif normalised_block_type == "config_metadata":
            # includes details like config version, last updated. replaces full block
            processed_block = process_config_metadata_block(config_metadata)

        elif normalised_block_type == "deployment_system":
            processed_block = process_deployment_system_block(block_lines, deployment_system_settings, la_code, la_name)

        elif normalised_block_type == "dev_setup":
            processed_block = process_dev_setup_block(block_lines, dev_setup_settings)

        elif normalised_block_type == "settings":
            processed_block = process_settings_block(block_lines, la_config)  # handle settings block bespoke changes

        # Append the (possibly modified) block to the final processed lines
        processed_lines.extend(processed_block)

    return processed_lines



def process_bespoke_sql_for_la(sql_lines, la_config):
    """
    Process the SQL script for LA-specific bespoke settings based on the YAML config.
    Only processes SQL lines that match the ssd_item_ref and ssd_table mentioned in the YAML config.
    Handles cases where YAML fields are null or placeholders.
    """
    bespoke_config = la_config.get('extract_sql_custom_la', {}).get('customise_db_schema', [])
    la_name = la_config.get('la_name', 'Unknown')  # get la_name or set 'Unknown' if not available
    la_id = la_config.get('la_id', 'Unknown')  # get la_id or set 'Unknown' if not available

    # Build a map of ssd_item_ref to list of fields from YAML config
    ssd_item_ref_map = {}
    for field in bespoke_config:
        ssd_item_ref = field.get('ssd_item_ref')
        if ssd_item_ref:
            if ssd_item_ref not in ssd_item_ref_map:
                ssd_item_ref_map[ssd_item_ref] = []
            ssd_item_ref_map[ssd_item_ref].append(field)

   
    # print(f"Bespoke Config Loaded: {bespoke_config}") # debugging
    # print(f"Item Ref Map: {ssd_item_ref_map}") # debugging

    # Updated regex to match the ssd_item_ref in the metadata of the SQL
    ssd_item_ref_regex = re.compile(r'-- metadata=\{.*?"item_ref":"(.*?)".*?\}')
    table_regex = re.compile(r'-- META-CONTAINER: \{"type": "table", "name": "(.*?)"\}')

    current_table = None
    processed_lines = []

    for line in sql_lines:
        # Detect parent|named table block (meta-container block)
        table_match = table_regex.search(line)
        if table_match:
            current_table = table_match.group(1)
            # print(f"Processing table: {current_table}")

        # Detect ssd_item_ref in the metadata
        ssd_item_ref_match = ssd_item_ref_regex.search(line)

        if ssd_item_ref_match:
            ssd_item_ref_in_sql = ssd_item_ref_match.group(1)
            # print(f"Found ssd_item_ref in SQL: {ssd_item_ref_in_sql}")

            # Check if the ssd_item_ref from SQL is present in the YAML config map
            if ssd_item_ref_in_sql in ssd_item_ref_map:
                for field_info in ssd_item_ref_map[ssd_item_ref_in_sql]:
                    # print(f"Field level change for ssd_item_ref {ssd_item_ref_in_sql}: {field_info}") # debug
                    
                    # Ensure that we're modifying the right table (ssd_table matches current table)
                    if current_table == field_info.get('ssd_table', ''):
                        la_field_name = field_info.get('la_field_name')
                        la_datatype = field_info.get('la_datatype')
                        la_datatype_size = field_info.get('la_datatype_size')

                        # Ensure la_datatype and la_datatype_size are valid before modifying
                        if la_datatype and la_datatype_size:
                            new_datatype = f"{la_datatype}({la_datatype_size})"
                            # Replace datatype in the SQL line
                            line = re.sub(r'NVARCHAR\(\d+\)', new_datatype, line)
                            print(f"{la_name}: Updated {ssd_item_ref_in_sql} with datatype {new_datatype}")

                        # Optionally replace the field name if `la_field_name` is provided and valid
                        if la_field_name:
                            original_field = field_info.get('ssd_field_name', '')
                            if original_field:
                                line = line.replace(original_field, la_field_name)
                                print(f"{la_name}: Replaced field name {original_field} with {la_field_name}")

                        # Optionally replace the table name if `la_table_name` is valid and different
                        la_table_name = field_info.get('la_table_name', '')
                        if la_table_name and la_table_name != field_info['ssd_table']:
                            line = line.replace(field_info['ssd_table'], la_table_name)
                            print(f"{la_name}: Replaced table {field_info['ssd_table']} with {la_table_name}")

        # Append the (possibly modified) line to the processed lines
        processed_lines.append(line)

    return processed_lines



def remove_primary_key_in_table(sql_lines, la_config):
    """
    This a work-around as pk defs are not implemented in the same way as fk (ALTER TABLE) due to SQL related problems on SQL Server
    Removes PRIMARY KEY from specified table (meta-container) defined in the YAML config's remove_create_pk section.
    """

    # get tables from yml config to remove_create_pk section
    tables_to_remove_pk = la_config.get('named_sql_tag_remove', {}).get('remove_create_pk', [])
    la_name = la_config.get('la_name', 'Unknown')  # get la_name or set 'Unknown' if not available
    la_id = la_config.get('la_id', 'Unknown')  # get la_id or set 'Unknown' if not available
    
    # regex to detect start of meta-container + corresponding create_table element
    table_container_regex = re.compile(r'-- META-CONTAINER: \{"type": "table", "name": "(.*?)"\}')
    create_table_regex = re.compile(r'-- META-ELEMENT: \{"type": "create_table"\}')
    
    current_table = None
    inside_create_table = False
    processed_lines = []
    
    for line in sql_lines:
        # Detect start of meta-container for tables 
        # this so the search+replace is fully contained|restricted
        table_container_match = table_container_regex.search(line)
        if table_container_match:
            current_table = table_container_match.group(1)
            inside_create_table = False  # Reset when a new table starts
            # print(f"Detected table: {current_table}") # debugging
        
        # Detect start of create_table block
        create_table_match = create_table_regex.search(line)
        if create_table_match and current_table in tables_to_remove_pk:
            inside_create_table = True  #  inside create_table block of specified table
            # print(f"Removing primary key for table: {current_table}")  # debugging
        
        # If inside create_table block of specified table, remove PK line
        if inside_create_table and 'PRIMARY KEY' in line:
            line = re.sub(r'\s+PRIMARY\s+KEY', '', line)  # Remove PRIMARY KEY def
            cleaned_line = re.sub(r'\s+', '', line.strip()) 
            print(f"Removed primary key from table/line: {cleaned_line} for local authority {la_name}({la_id}).")  # debugging
        
        # If create_table block ends (closing parenthesis), stop processing for block
        if inside_create_table and line.strip() == ');':
            inside_create_table = False
        
        processed_lines.append(line)
    
    return processed_lines



def process_sql(la_config, master_sql_path, output_sql_path):
    """
    processes the sql file based on la-specific config, applying global and named tag removals.
    """
    with open(master_sql_path, 'r') as file:
        sql_lines = file.readlines()

    # get relevant config from yaml
    # custom_la = la_config.get('extract_sql_custom_la', {})  # bespoke schema changes defined in yaml extract_sql_custom_la
    named_sql_tag_remove = la_config.get('named_sql_tag_remove', {})  # handles named object changes defined in yaml named_sql_tag_remove
    global_sql_tag_remove = la_config.get('global_sql_tag_remove', {})  # handles global removals
    
    containers_to_remove = la_config.get('named_sql_container_remove', []) # any complete containers flagged for removal in yml config

    # determine if temporary(not persistent) tables are defined in config/to be implemented in extract
    persistent_ssd_settings = la_config.get('settings', {}).get('persistent_ssd', {})
    use_temp_tables = persistent_ssd_settings.get('deploy_temp_tables', True)  # default to True if not provided as failsafe.

    # get config supplied schema (i.e. where the ssd tables created, if not temp# tables)
    schema_settings = la_config.get('settings', {}).get('dbschema', {})
    schema_name = schema_settings.get('deployment_schema_name')

    # treat any falsy value (None, "None", or "") as an empty string
    if not schema_name or schema_name == "None":
        schema_name = ""  # ensure schema_name is an empty string if None or "None"


    # Perform global search and replace only if deploy_temp_tables is set to True
    if use_temp_tables:
        search_string = "ssd_development.ssd_" # look for table name def instances
        replace_string = "#ssd_"
        sql_lines = search_and_replace_in_sql(sql_lines, search_string, replace_string)
        
        search_string = "ssd_development.ssd_" # look for table name def instances
        replace_string = "#ssd_"    
        sql_lines = search_and_replace_in_sql(sql_lines, search_string, replace_string)

    else:
        search_string = "ssd_development.ssd_"  # look for table name def instances
        if schema_name:  # if schema_name exists, prepend it
            replace_string = f"{schema_name}.ssd_"
        else:  # otherwise, just remove the schema part, leaving 'ssd_'
            replace_string = "ssd_"

        sql_lines = search_and_replace_in_sql(sql_lines, search_string, replace_string)




    # remove any complete containers flagged for removal in yml config
    sql_lines = remove_named_sql_containers(sql_lines, containers_to_remove)

    # Remove primary keys from tables in the config
    sql_lines = remove_primary_key_in_table(sql_lines, la_config)

    # extract all meta-container blocks and their m-elements (grouped by meta-container)
    parent_blocks = extract_meta_blocks_with_children(sql_lines)

    processed_lines = []

    # print(f"testing blocks:{parent_blocks}")  # debugging

    # process each meta-container block and its m-elements
    for parent_name, child_blocks in parent_blocks:
        # pass la_config to process_parent_block function
        processed_parent = process_parent_block(parent_name, child_blocks, named_sql_tag_remove, global_sql_tag_remove, la_config)
        processed_lines.extend(processed_parent)


    # Call bespoke processing function before final output
    processed_lines = process_bespoke_sql_for_la(processed_lines, la_config)  



    # generate bespoke extract
    with open(output_sql_path, 'w') as file:
        file.writelines(processed_lines)


def process_yaml_files(yaml_directory):
    """
    Processes all LA YAML files returns list of valid configs
    """
    yaml_files = [f for f in os.listdir(yaml_directory) if f.endswith('.yml')]
    valid_configs = []

    for yaml_file in yaml_files:
        # debug
        # print(f"Processing file: {yaml_file}") # debugging

        try:
            yaml_config = load_yaml_config(os.path.join(yaml_directory, yaml_file))
            # print(f"Loaded YAML config: {yaml_config}") # debugging
        except Exception as e:
            print(f"Error loading {yaml_file}: {e}")
            continue

        la_code_str = next(iter(yaml_config))
        la_config = yaml_config[la_code_str]

        cms_value = la_config.get('deployment_system', {}).get('cms', {}).lower()

        # atm we are only processing bespoke extract sql for systemC LAs. [#CMS]
        if cms_value != 'systemc':
            print(f"Skipping {yaml_file} due to mismatched CMS: {cms_value}") # debugging
            continue

        if not all(k in la_config for k in ['la_code', 'la_name']):
            print(f"Missing data in YAML file {yaml_file}") # debugging
            continue

        valid_configs.append(la_config)

    return valid_configs


def generate_sql_files(valid_configs, master_sql_path, output_directory, vers):
    """
    Generate bespoke SQL extract(s) using LA config defs 
    This is 1 sql file per LA, each being based on LA yml config file. 
    """
    for la_config in valid_configs:
        la_code = la_config.get('la_code', '')
        la_name = la_config.get('la_name', '').lower()
        cms = la_config.get('deployment_system', {}).get('cms', {}).lower()
        cms_db = la_config.get('deployment_system', {}).get('cms_db', {}).lower()

        output_file_name = f"{la_code}_{la_name}_{cms}_{cms_db}_{vers}.sql"
        output_sql_path = os.path.join(output_directory, output_file_name)
        print(f"\n\n ************************Processing SQL file for: {la_name}|{la_code} ************************") # debugging
        process_sql( la_config, master_sql_path, output_sql_path)
        print(f" ************************ Generated SQL file: {output_file_name} ************************") # debugging



def load_yaml_config(yaml_file):
    """
    loads yaml config from file.
    """
    with open(yaml_file, 'r') as file:
        return yaml.safe_load(file)

    

# Main execution block
if __name__ == "__main__":
    yaml_directory = '/workspaces/ssd-data-model/la_config_files__future_release/'
    

    # live extract filename(s)/paths stub
    # cms1 - LiquidLogic | SystemC
    cms1_file_pattern = 'systemc_sqlserver_*.sql'
    cms1_sql_extract_dir = '/workspaces/ssd-data-model/deployment_extracts/systemc/live/'
    
    # cms2 - Mosaic (not yet implemented)
    # See script tags [#CMS]



    # <all> sql extract files matching stub name
    matching_files = glob.glob(os.path.join(cms1_sql_extract_dir, cms1_file_pattern))
    
    if not matching_files:
        raise FileNotFoundError(f"No files found matching pattern: {cms1_file_pattern}")
    
    # sort and get most recent
    latest_file = max(matching_files, key=os.path.getmtime)
    print(latest_file)
    
    # use latest file as the master_sql_path
    output_directory = '/workspaces/ssd-data-model/deployment_extracts__future_release/'

    # get most recent version num (subsequently added to bespoke extract filename)
    # regex extract live version (from 'v' to '.sql')
    version_pattern = re.search(r'_v[\d.]+_\d+', latest_file)

    if version_pattern:
        extract_version = version_pattern.group(0)[1:]  # strip leading underscore
    else:
        raise ValueError("No version found in filename.")


    print(f"Current file version set as: {latest_file}")

    # process LA config YAML files (1 per LA)
    valid_configs = process_yaml_files(yaml_directory)
    
    # generate bespoke SQL extract(s)
    generate_sql_files(valid_configs, latest_file, output_directory, extract_version)


