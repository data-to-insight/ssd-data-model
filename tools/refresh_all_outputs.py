import subprocess
from admin.admin_tools import get_paths # get project defined file paths
import re

paths = get_paths()

# creating base objects and essentials

# Run script to refresh changelog in case workflow action run not recent
subprocess.run(['python3', paths['tools'] + 'update_changelog.py'])

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '1_generate_yaml_objects.py'])



# diagrams and visuals

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '2_generate_model_conceptual.py'])

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '2_generate_model_erd.py'])


# Front facing pages

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '3_generate_html_conceptual.py'])

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '3_generate_html_guidance.py'])

# Run script to re-create the individual object diagram images
subprocess.run(['python3', paths['tools'] + '3_generate_html_datamapping.py'])

