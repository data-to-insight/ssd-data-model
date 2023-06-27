import glob
import yaml
import base64
import subprocess
import datetime

# Generate HTML content
html_content = "<html><head><style>"
html_content += "table { border-collapse: collapse; width: 80%; margin: auto; float: right; }"
html_content += "th, td { text-align: left; padding: 8px; word-wrap: break-word; }"
html_content += "th { background-color: #f2f2f2; }"
html_content += "th.field-column { width: 40%; }"
html_content += "th.cms-column { width: 30%; }"
html_content += "th.categories-column { width: 30%; }"
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
            html_content += f'<img src="erd_images/{entity_name}.png" alt="{entity_name}" style="float: left; margin-right: 20px;">'
            html_content += "<table>"
            html_content += "<tr><th class='field-column'>Field</th><th class='cms-column'>CMS</th><th class='categories-column'>Categories</th></tr>"
            for field in nodes[0]['fields']:
                field_name = field['name']
                cms = field.get('cms', '')
                categories = field.get('categories', '')
                html_content += f"<tr><td>{field_name}</td><td>{cms}</td><td>{categories}</td></tr>"
            html_content += "</table>"
            html_content += "<div style='clear: both;'></div>"

# Write HTML content to file
with open('docs/index.html', 'w') as f:
    f.write(html_content)

# Run create_erd_from_yml.py script
subprocess.run(['python3', 'tools/create_erd.py'])
