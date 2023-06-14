

# await pyodide.loadPackage("micropip")
# import micropip
# await micropip.install("pyyaml") 


import yaml
import pygraphviz as pgv
import streamlit as st
from PIL import Image

# Title of the page
st.title("sdd initial structure definition / erd")

# Load the data from the YAML file
with open('structure/structure.yml') as f:
    data = yaml.safe_load(f)

# Create a new directed graph
G = pgv.AGraph(directed=True)

# Add nodes to the graph
for node in data['nodes']:
    label = '{' + node['name'] + '|' + '|'.join(node['fields']) + '}'
    G.add_node(node['name'], shape='record', label=label)

# Add edges to the graph
for edge in data['edges']:
    G.add_edge(edge['from'], edge['to'], label=edge['relation'])

# Render the graph to a file
G.draw('assets/ssd_erd.png', prog='dot', format='png')

# Load and display image
image = Image.open('assets/ssd_erd.png')
st.image(image, caption='ssd initial erd')

# Markdown text
st.markdown("""
### SSD
A work ***in progress*** erd-mapping

Primary repo [🔗 here](https://github.com/data-to-insight/ssd-data-model/).
""")
