import os
import glob
import yaml
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

# Check if directory exists, if not create it
output_directory = 'docs/'
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# Initialize PDF
pdf_pages = PdfPages('docs/dataset_definitions.pdf')

# Create a title page
fig, ax = plt.subplots(figsize=(8, 11))  # Set figure size to portrait
ax.axis('off')  # Hide axes
ax.text(0.5, 0.5, 'Main Title', fontsize=24, ha='center', va='center', fontweight='bold')
pdf_pages.savefig(fig, bbox_inches='tight')

# Close the figure
plt.close(fig)

# Create an intro text page
fig, ax = plt.subplots(figsize=(8, 11))  # Set figure size to portrait
ax.axis('off')  # Hide axes
intro_text = 'Here is my sample intro text.....'
ax.text(0.5, 0.5, intro_text, fontsize=12, ha='center', va='center')
pdf_pages.savefig(fig, bbox_inches='tight')

# Close the figure
plt.close(fig)

# Collect node names
node_names = []

# Parse each YAML file and convert to DataFrame
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes')
        if nodes is not None:
            for node in nodes:
                node_names.append(node['name'])

# Create DataFrame for objects overview
overview_df = pd.DataFrame(node_names, columns=['Node Names'])

# Create an objects overview page
fig, ax = plt.subplots(figsize=(8, 11))  # Set figure size to portrait
ax.axis('tight')  # Remove empty space
ax.axis('off')  # Hide axes
ax.table(cellText=overview_df.values,
         colLabels=overview_df.columns,
         cellLoc='center', loc='center')

ax.set_title('Objects Overview', fontweight='bold')
pdf_pages.savefig(fig, bbox_inches='tight')

# Close the figure
plt.close(fig)

# Define fields to drop
fields_to_drop = ['primary_key', 'foreign_key', 'type', 'validators']

# Parse each YAML file and convert to DataFrame
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes')
        if nodes is not None:
            for node in nodes:
                table_name = node['name']
                table_data = pd.DataFrame(node['fields'])

                # Drop specified fields
                table_data.drop(fields_to_drop, axis=1, errors='ignore', inplace=True)

                # Convert all DataFrame values to string
                table_data = table_data.astype(str)

                # Plot data
                fig, ax = plt.subplots(figsize=(8, 11))  # Set figure size to portrait
                ax.axis('tight')  # Remove empty space
                ax.axis('off')  # Hide axes
                ax.table(cellText=table_data.values,
                         colLabels=table_data.columns,
                         cellLoc='center', loc='center')

                ax.set_title(table_name, fontweight='bold')
                pdf_pages.savefig(fig, bbox_inches='tight')

                # Close the figure
                plt.close(fig)




# import os
# import glob
# import yaml
# import pandas as pd
# import matplotlib.pyplot as plt
# from matplotlib.backends.backend_pdf import PdfPages

# # Check if directory exists, if not create it
# output_directory = 'docs/'
# if not os.path.exists(output_directory):
#     os.makedirs(output_directory)

# # Initialize PDF
# pdf_pages = PdfPages('docs/dataset_definitions.pdf')

# # Create a title page
# fig, ax = plt.subplots(figsize=(10, 4))  # Set figure size
# ax.axis('off')  # Hide axes
# ax.text(0.5, 0.5, 'Main Title', fontsize=24, ha='center', va='center', fontweight='bold')
# pdf_pages.savefig(fig, bbox_inches='tight')

# # Close the figure
# plt.close(fig)

# # Create an intro text page
# fig, ax = plt.subplots(figsize=(10, 4))  # Set figure size
# ax.axis('off')  # Hide axes
# intro_text = 'Here is my sample intro text.....'
# ax.text(0.5, 0.5, intro_text, fontsize=12, ha='center', va='center')
# pdf_pages.savefig(fig, bbox_inches='tight')

# # Close the figure
# plt.close(fig)

# # Collect node names
# node_names = []

# # Parse each YAML file and convert to DataFrame
# for file_path in glob.glob('data/objects/*.yml'):
#     with open(file_path) as f:
#         data = yaml.safe_load(f)
#         nodes = data.get('nodes')
#         if nodes is not None:
#             for node in nodes:
#                 node_names.append(node['name'])

# # Create DataFrame for objects overview
# overview_df = pd.DataFrame(node_names, columns=['Node Names'])

# # Create an objects overview page
# fig, ax = plt.subplots(figsize=(10, 4))  # Set figure size
# ax.axis('tight')  # Remove empty space
# ax.axis('off')  # Hide axes
# ax.table(cellText=overview_df.values,
#          colLabels=overview_df.columns,
#          cellLoc='center', loc='center')

# ax.set_title('Objects Overview', fontweight='bold')
# pdf_pages.savefig(fig, bbox_inches='tight')

# # Close the figure
# plt.close(fig)

# for file_path in glob.glob('data/objects/*.yml'):
#     with open(file_path) as f:
#         data = yaml.safe_load(f)
#         nodes = data.get('nodes')
#         if nodes is not None:
#             for node in nodes:
#                 table_name = node['name']
#                 table_data = pd.DataFrame(node['fields'])

#                 # Convert all DataFrame values to string
#                 table_data = table_data.astype(str)

#                 # Plot data
#                 fig, ax = plt.subplots(figsize=(10, 4))  # Set figure size
#                 ax.axis('tight')  # Remove empty space
#                 ax.axis('off')  # Hide axes
#                 ax.table(cellText=table_data.values,
#                          colLabels=table_data.columns,
#                          cellLoc='center', loc='center')

#                 ax.set_title(table_name, fontweight='bold')
#                 pdf_pages.savefig(fig, bbox_inches='tight')

#                 # Close the figure
#                 plt.close(fig)

# # Save the PDF
# pdf_pages.close()
