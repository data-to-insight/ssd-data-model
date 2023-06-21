import glob
import yaml
import base64
import pygraphviz as pgv
from PIL import Image

# Generate HTML content
html_content = "<html>\n<head>\n<title>SSD Data Model</title>\n</head>\n<body>\n"

# Iterate over each entity definition
for entity_file in glob.glob("data/objects/*.yml"):
    with open(entity_file, 'r') as f:
        entity = yaml.safe_load(f)
        entity_name = entity['name']
        html_content += f"<h2>{entity_name}</h2>\n"

        # Create a new directed graph
        G = pgv.AGraph(directed=True)

        # Add the entity node to the graph
        label = f"{{<b>{entity_name}</b>}}"
        G.add_node(entity_name, shape='plaintext', label=label)

        # Check for fields in the entity definition
        if 'fields' in entity:
            for field in entity['fields']:
                field_name = field['name']
                constraints = field.get('constraints', '')
                cms = field.get('cms', '')
                categories = field.get('categories', '')

                # Create the field label
                label = f"<b>{field_name}</b><br/>Constraints: {constraints}<br/>CMS: {cms}<br/>Categories: {categories}"

                # Add the field node to the graph
                G.add_node(field_name, shape='plaintext', label=label)

                # Add an edge between the entity and the field
                G.add_edge(entity_name, field_name)

        # Render the graph to a file
        erd_file = f"assets/{entity_name}_erd.png"
        G.draw(erd_file, prog='dot', format='png')

        # Resize the image to fit the browser window
        img = Image.open(erd_file)
        img.thumbnail((1280, 1280))  # Set the maximum size
        img.save(erd_file)

        # Encode the image as base64
        with open(erd_file, "rb") as image_file:
            erd_image_data = image_file.read()
        erd_image_base64 = base64.b64encode(erd_image_data).decode("utf-8")

        # Add the image to the HTML content
        html_content += f'<img src="data:image/png;base64,{erd_image_base64}">\n'

# Finish generating the HTML content
html_content += "</body>\n</html>"

# Write the HTML content to a file
# Write HTML content to file
with open('docs/index.html', 'w') as f:
    f.write(html_content)



print("HTML file generated successfully.")
