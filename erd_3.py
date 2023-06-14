import yaml
import pygraphviz as pgv
from PIL import Image

# Load the data from the YAML file
with open('structure/schema.yaml') as f:
    data = yaml.safe_load(f)

# Create a new directed graph
G = pgv.AGraph(directed=True)

# Add nodes to the graph
for node in data['nodes']:
    # Extract the 'name' attribute from each field and join them together
    field_names = [field['name'] for field in node['fields']]
    label = '{' + node['name'] + '|' + '|'.join(field_names) + '}'
    G.add_node(node['name'], shape='record', label=label)

# Add edges to the graph
for edge in data['edges']:
    G.add_edge(edge['from'], edge['to'], label=edge['relation'])

# Render the graph to a file
G.draw('assets/ssd_erd.png', prog='dot', format='png')
