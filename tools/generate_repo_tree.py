import os
from openpyxl import Workbook

IGNORE_FOLDERS = ["z_clean_up_tmp", ".git"]

def generate_file_tree(root_directory):
    file_tree = []

    stack = [(root_directory, 0)]
    while stack:
        directory, depth = stack.pop()

        if any(directory.endswith(folder) for folder in IGNORE_FOLDERS):
            continue

        for dir_name, sub_dirs, filenames in os.walk(directory):
            sub_dirs[:] = [sub_dir for sub_dir in sub_dirs if not sub_dir.startswith(".git")]

            indent = "\t" * depth
            file_tree.append((indent + dir_name, filenames))

            for sub_dir in sub_dirs:
                stack.append((os.path.join(dir_name, sub_dir), depth + 1))

    return file_tree

# Specify the root directory for the file tree
root_directory = '/workspaces/ssd-data-model/'

# Generate the file tree
file_tree = generate_file_tree(root_directory)

# Create a new workbook
workbook = Workbook()
sheet = workbook.active

# Write the file tree data
for folder, files in file_tree:
    row = [folder] + files if files else [folder]
    sheet.append(row)

# Save the workbook as an Excel file
output_file = "docs/file_tree.xlsx"
workbook.save(output_file)
