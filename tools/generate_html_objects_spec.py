import glob
import yaml
import base64
import subprocess
import datetime

# Image width (adjust as needed)
image_width = 300

# Generate HTML content
html_content = "<html><head><style>"
html_content += "table { border-collapse: collapse; width: 80%; margin: auto; }"
html_content += "th, td { text-align: left; padding: 8px; word-wrap: break-word; border: 1px solid #ddd; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "th.field-ref-column { width: 100px; }"
html_content += "th.data-item-column { width: 30%; }"
html_content += "th.field-column { width: 20%; }"
html_content += "th.cms-column { width: 15%; }"
html_content += "th.categories-column { width: 15%; }"
html_content += "th.returns-column { width: 20%; }"
html_content += "</style></head><body>"
html_content += f"<h1>SSD Data Model Documentation</h1>"
html_content += f"<h3>Last updated: {datetime.datetime.now().strftime('%Y-%m-%d')}</h3>"
html_content += "<p>Intro paragraph placeholder text.</p>"

# Read the YAML files
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        if nodes:
            entity_name = nodes[0]['name']
            html_content += f"<h2>Object name: {entity_name}</h2>"
            html_content += f'<img src="erd_images/{entity_name}.png" alt="{entity_name}" style="float: left; width: {image_width}px; margin-right: 20px;">'
            html_content += "<table>"
            html_content += "<tr><th></th><th class='field-ref-column'>Field Ref</th><th class='data-item-column'>Data Item Name / Field</th><th class='field-column'>Field</th><th class='cms-column'>CMS</th><th class='categories-column'>Categories</th><th class='returns-column'>Returns</th></tr>"
            for field in nodes[0]['fields']:
                field_ref = field.get('field_ref', '')
                field_name = field['name']
                cms = ', '.join(field.get('cms', []))
                categories = ', '.join(field.get('categories', []))
                returns_data = ', '.join(field.get('returns', []))
                html_content += f"<tr><td></td><td>{field_ref}</td><td>{field_name}</td><td>{field_name}</td><td>{cms}</td><td>{categories}</td><td>{returns_data}</td></tr>"
            html_content += "</table>"
            html_content += "<div style='clear: both;'></div>"

# Write HTML content to file
with open('docs/index.html', 'w') as f:
    f.write(html_content)

# Run create_erd_from_yml.py script
subprocess.run(['python3', 'tools/create_erd.py'])
