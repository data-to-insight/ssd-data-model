import os
import glob
import re


"""
This script ....

chmod +x locate_variables_in_files.py
"""

# Multiple directories support
directories = [
    'cms_ssd_extract_sql/mosaic/',              # Mosaic scripts
    'cms_ssd_extract_sql/systemc_liquidlogic/'  # Liquid Logic scripts
]


variable_name = 'post_code'                  # var name to search
variable_stem = ''                  # stem to search 
variable_suffix = ''           # suffix to search
search_file_type = '.sql'           # or .py or .txt 

def find_variables_in_sql_files(directories, variable_name, variable_stem, variable_suffix, search_file_type):
    print(f"Searching in: {search_file_type} files.") 

    if variable_name:
        print(f"Searching for variable: {variable_name}")
        exact_pattern = re.compile(r'\b' + re.escape(variable_name) + r'\b')
    else:
        exact_pattern = None

    if variable_stem:
        print(f"Searching for any variable prefix of: {variable_stem}")
        stem_pattern = re.compile(r'\b' + re.escape(variable_stem) + r'\w*\b')
    else:
        stem_pattern = None

    if variable_suffix:
        print(f"Searching for any variable suffix of: {variable_suffix}")
        suffix_pattern = re.compile(r'\w+' + re.escape(variable_suffix) + r'\b')
    else:
        suffix_pattern = None

    exact_matched_files = []    # Store matches
    stem_matches = {}           # Store stem matches with filenames
    suffix_matches = {}         # Store suffix matches with filenames

    # Iterate over each directory
    for directory in directories:
        # print(f"Checking directory: {directory}")           # Diagnostic print
        file_pattern = os.path.join(directory, '*' + search_file_type)
        files = glob.glob(file_pattern)
        # print(f"Found {len(files)} files in {directory}")   # Diagnostic print

        # Search files for the var, stem, and suffix
        for file_path in files:
            try:
                with open(file_path, 'r', encoding='utf-8') as file:
                    file_content = file.read()
            except UnicodeDecodeError:
                # If UTF-8 fails, try Latin-1
                with open(file_path, 'r', encoding='iso-8859-1') as file:
                    file_content = file.read()

            # Check for exact variable name match
            if exact_pattern and exact_pattern.search(file_content):
                exact_matched_files.append(file_path)

            # Find all stem matches
            if stem_pattern:
                for match in stem_pattern.finditer(file_content):
                    match_str = match.group()
                    if match_str in stem_matches:
                        stem_matches[match_str].add(file_path)
                    else:
                        stem_matches[match_str] = {file_path}

            # Find all suffix matches
            if suffix_pattern:
                for match in suffix_pattern.finditer(file_content):
                    match_str = match.group()
                    if match_str in suffix_matches:
                        suffix_matches[match_str].add(file_path)
                    else:
                        suffix_matches[match_str] = {file_path}

    return exact_matched_files, stem_matches, suffix_matches

# Results output
exact_matched_files, stem_matches, suffix_matches = find_variables_in_sql_files(directories, variable_name, variable_stem, variable_suffix, search_file_type)

if variable_name:
    if exact_matched_files:
        print("Found the variable in the following files:")
        for file in exact_matched_files:
            print(file)
    else:
        print("No files found containing the exact variable.")

if variable_stem:
    if stem_matches:
        print("Variable stem matches found:")
        for match, files in stem_matches.items():
            print(f"{match} found in:")
            for file in files:
                print(f"  {file}")
    else:
        print("No variable stem matches found.")

if variable_suffix:
    if suffix_matches:
        print("Variable suffix matches found:")
        for match, files in suffix_matches.items():
            print(f"{match} found in:")
            for file in files:
                print(f"  {file}")
    else:
        print("No variable suffix matches found.")