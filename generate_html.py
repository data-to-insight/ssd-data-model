import glob
import yaml
import base64
import subprocess

# Generate HTML content
html_content = "<html><head><style>"
html_content += "table { border-collapse: collapse; width: 80%; margin: auto; }"
html_content += "th, td { text-align: left; padding: 8px; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "</style></head><body>"
html_content += "<h1>SSD Data Model Documentation</h1>"

# Read the YAML files
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        if nodes:
            entity_name = nodes[0]['name']
            html_content += f'<h2>{entity_name}</h2>'
            html_content += "<table>"
            html_content += "<tr><th>Field</th><th>Constraints</th><th>CMS</th><th>Categories</th></tr>"
            for field in nodes[0]['fields']:
                field_name = field['name']
                constraints = field.get('constraints', '')
                cms = field.get('cms', '')
                categories = field.get('categories', '')
                html_content += f"<tr><td>{field_name}</td><td>{constraints}</td><td>{cms}</td><td>{categories}</td></tr>"
            html_content += "</table>"

# Add ERD image to the HTML content
with open('/workspaces/ssd-data-model/assets/ssd_erd_yml.png', 'rb') as f:
    erd_image_data = f.read()
erd_image_base64 = base64.b64encode(erd_image_data).decode('utf-8')
html_content += f'<div style="text-align: center; margin-top: 50px;">'
html_content += f'<img src="data:image/png;base64,{erd_image_base64}" alt="SSD ERD Diagram">'
html_content += "</div>"

html_content += "</body></html>"

# Write HTML content to file
with open('/workspaces/ssd-data-model/docs/index.html', 'w') as f:
    f.write(html_content)

# Run create_erd_from_yml.py script
subprocess.run(['python3', '/workspaces/ssd-data-model/create_erd_from_yml.py'])
