import os
import glob
import re


"""
This script ....

chmod +x locate_variables_in_files.py
"""

# Multiple directories support
directories = [
    'cms_ssd_extract_sql/mosaic/',    # Mosaic scripts
    'cms_ssd_extract_sql/systemc_liquidlogic/'  # Liquid Logic scripts
]

variable_name = 'cinp_cin_plan_team'  # var name to search
variable_stem = 'cinp_'  # stem to search 
search_file_type = '.sql'  # or .py or .txt 

def find_variables_in_sql_files(directories, variable_name, variable_stem, search_file_type):
    print(f"Searching in: {search_file_type} files.") 
    print(f"Searching for variable: {variable_name}")
    print(f"Searching for any variable prefix of: {variable_stem}")

    # Prep pattern to search for exact var name
    exact_pattern = re.compile(r'\b' + re.escape(variable_name) + r'\b')
    # Do the same for pattern to search for any var starting with stem
    stem_pattern = re.compile(r'\b' + re.escape(variable_stem) + r'\w*\b')

    exact_matched_files = []  # Store matches
    stem_matches = set()

    # Iterate over each directory
    for directory in directories:
        print(f"Checking directory: {directory}")  # Diagnostic print
        file_pattern = os.path.join(directory, '*' + search_file_type)
        files = glob.glob(file_pattern)
        print(f"Found {len(files)} files in {directory}")  # Diagnostic print

        # Search files for the var and stem
        for file_path in files:
            try:
                with open(file_path, 'r', encoding='utf-8') as file:
                    file_content = file.read()
            except UnicodeDecodeError:
                # If UTF-8 fails, try Latin-1
                with open(file_path, 'r', encoding='iso-8859-1') as file:
                    file_content = file.read()

            # Check for exact variable name match
            if exact_pattern.search(file_content):
                exact_matched_files.append(file_path)

            # Find all stem matches
            for match in stem_pattern.finditer(file_content):
                stem_matches.add(match.group())

    return exact_matched_files, stem_matches

# Results output
exact_matched_files, stem_matches = find_variables_in_sql_files(directories, variable_name, variable_stem, search_file_type)
if exact_matched_files:
    print("Found the variable in the following files:")
    for file in exact_matched_files:
        print(file)
else:
    print("No files found containing the exact variable.")

if stem_matches:
    print("Variable stem matches found:")
    print(', '.join(stem_matches))
else:
    print("No variable stem matches found.")
