import os
from openpyxl import Workbook

IGNORE_FOLDERS = ["z_clean_up_tmp", ".git", ".vscode"]

def generate_file_tree(root_directory):
    """
    Generates a list representing the file tree of a root directory.
    
    Args:
        root_directory (str): Path to the root directory.
    
    Returns:
        list: A list of tuples, each containing the relative path of a directory 
        and a list of filenames in that directory.
    
    Note:
        This function skips directories listed in the global IGNORE_FOLDERS and ".git" directories.
    """
    file_tree = []

    stack = [(root_directory, 0)]
    while stack:
        directory, depth = stack.pop()

        if any(folder.lower() in directory.lower() for folder in IGNORE_FOLDERS):
            print("Excluded folder:", directory)  # Print the excluded folders for debugging
            continue

        for dir_name, sub_dirs, filenames in os.walk(directory):
            sub_dirs[:] = [sub_dir for sub_dir in sub_dirs if not sub_dir.startswith(".git")]

            indent = "\t" * depth
            relative_dir = dir_name.replace(root_directory, "")

            file_tree.append((indent + relative_dir, filenames))

            for sub_dir in sub_dirs:
                stack.append((os.path.join(dir_name, sub_dir), depth + 1))

    return file_tree

# Specify the root directory for the file tree
root_directory = '/workspaces/ssd-data-model/'

# Generate the file tree
file_tree = generate_file_tree(root_directory)

# Exclude the excluded folders from the file tree
file_tree = [(folder, files) for folder, files in file_tree if all(folder.lower().startswith(excluded_folder.lower()) == False for excluded_folder in IGNORE_FOLDERS)]

# Create a new workbook
workbook = Workbook()
sheet = workbook.active

# Write the file tree data
for folder, files in file_tree:
    row = [folder] + files if files else [folder]
    sheet.append(row)

# Save the workbook as an Excel file
output_file = "docs/admin/ssd_repo_tree.xlsx"
workbook.save(output_file)
