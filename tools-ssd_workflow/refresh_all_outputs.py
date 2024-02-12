'''
Script updates all the required files to enable front-end publishing. 
It does not run scripts that are not relevant to this, e.g. SQL generation
Changes/updates should be pushed/pulled back to main, at which point 
Git Actions Workflow will pick up and publish the changes for GitPages.
'''


import subprocess
from admin.admin_tools import get_paths # get project defined file paths
import re

paths = get_paths()

# creating base objects and essential admin

# Run script to refresh changelog in case workflow action run not recent
subprocess.run(['python3', paths['ssd_tools'] + 'admin/update_changelog.py'])

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['ssd_tools'] + '1_generate_yaml_objects.py'])



# diagrams and visuals

# Run script to re-create object diagram image (main)
subprocess.run(['python3', paths['ssd_tools'] + '2_generate_model_conceptual.py'])

# Run script to re-create the object diagram image (alternative table view)
subprocess.run(['python3', paths['ssd_tools'] + '2_generate_model_erd.py'])


# Generate/refresh front facing web pages

# Run script to re-create the main conceptual model page (shows main concept diagram)
subprocess.run(['python3', paths['ssd_tools'] + '3_generate_html_conceptual.py'])

# Run script to re-create wider guidance page (shows variation of concept diagram)
subprocess.run(['python3', paths['ssd_tools'] + '3_generate_html_guidance.py'])

# Run script to re-create the existing returns page (subset diagrams for reduced views inc. stat returns)
subprocess.run(['python3', paths['ssd_tools'] + '3_generate_html_datamapping.py'])

# Run script to re-create public copy/instance of the README.md 
subprocess.run(['python3', paths['ssd_tools'] + '3_generate_html_readme.py'])


# Downloadable item generation

# Run script to re-create object spec pdf download report
subprocess.run(['python3', paths['ssd_tools'] + '3_generate_dataset_pdf_report.py'])

