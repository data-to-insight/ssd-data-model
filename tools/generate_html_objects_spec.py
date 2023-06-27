import glob
import yaml
import base64
import subprocess
import datetime
from PIL import Image
import os


def resize_images(folder_path, target_width, quality=90):
    for file_path in glob.glob(os.path.join(folder_path, '*.png')):
        img = Image.open(file_path)
        current_width, current_height = img.size
        target_height = int((current_height / current_width) * target_width)
        resized_img = img.resize((target_width, target_height), resample=Image.LANCZOS)
        resized_img.save(file_path, format='PNG', optimize=True, quality=quality)



# location of 
erd_folder = 'docs/erd_images/'
site_root_folder = 'docs/'

# Calculate main image width
main_image_width = "calc(100% - 40px)"  # Adjust the padding as needed

# Sub-Image width (adjust as needed)
image_width = "300px"

# Define page title and intro text
page_title_str = "SSD Data Model Documentation"
page_intro_str = "Data Item and Entity Definitions published for iterative review. Objects/data fields capturing LA Childrens Services data towards 1a SSD."



# Generate HTML content
html_content = "<html><head><style>"
html_content += "table { border-collapse: collapse; width: 80%; margin: auto; }"
html_content += "th, td { text-align: left; padding: 8px; word-wrap: break-word; border: 1px solid #ddd; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "th.image-column { width: " + str(image_width) + "; }"
html_content += "th.field-ref-column { width: 100px; }"
html_content += "th.data-item-column { width: 30%; }"
html_content += "th.field-column { width: 20%; }"
html_content += "th.cms-column { width: 15%; }"
html_content += "th.categories-column { width: 15%; }"
html_content += "th.returns-column { width: 20%; }"
html_content += "</style></head><body>"
html_content += f"<h1>{page_title_str}</h1>"
html_content += f"<p>{page_intro_str}</p>"
html_content += f"<h3>Last updated: {datetime.datetime.now().strftime('%d-%m-%Y')}</h3>"

# Add Objects Overview section
html_content += "<h2>Objects Overview</h2>"
html_content += "<div style='padding: 20px;'>"
html_content += f'<img src="ssd_erd.png" alt="Objects Overview" style="width: {main_image_width};">'
html_content += "</div>"

# Add Object Data Points Overview section
html_content += "<h2>Object Data Points Overview</h2>"

# Read the YAML files
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        if nodes:
            entity_name = nodes[0]['name']
            html_content += "<div>"
            html_content += f"<h2>Object name: {entity_name}</h2>"
            html_content += "<div style='display: flex;'>"
            html_content += f'<img src="erd_images/{entity_name}.png" alt="{entity_name}" style="width: {image_width}; margin-right: 20px;">'
            html_content += "<table>"
            html_content += "<tr><th class='field-ref-column'>Field Ref</th><th class='data-item-column'>Data Item Name / Field</th><th class='field-column'>Field</th><th class='cms-column'>CMS</th><th class='categories-column'>Categories</th><th class='returns-column'>Returns</th></tr>"
            for field in nodes[0]['fields']:
                field_ref = field.get('field_ref', '')
                field_name = field['name']
                cms_data = ', '.join(field.get('cms', []))
                categories_data = ', '.join(field.get('categories', []))
                returns_data = ', '.join(field.get('returns', []))
                html_content += f"<tr><td>{field_ref}</td><td>{field_name}</td><td>{field_name}</td><td>{cms_data}</td><td>{categories_data}</td><td>{returns_data}</td></tr>"
            html_content += "</table>"
            html_content += "</div>"
            html_content += "</div>"

# Write HTML content to file
with open('docs/index.html', 'w') as f:
    f.write(html_content)

# Run create_erd.py script to re-create the individual object diagram images
subprocess.run(['python3', 'tools/create_erd.py'])


# Resize the images specifically for web publishing. 
# Other/above methods only reduce to size of longest text data on row(s)
resize_images(erd_folder, target_width=300, quality=80)
resize_images(site_root_folder, target_width=1000, quality=80)
