
# running in codespace
# sud apt-get update
# sudo apt-get install graphviz libgraphviz-dev
# pip install pygraphviz

# might also need to 
# pip install --install-option="--include-path=/usr/include/graphviz" --install-option="--library-path=/usr/lib/graphviz/" pygraphviz
# locate cgraph.h # find out where cgraph.h is located
# sudo updatedb # update its database first:



# await pyodide.loadPackage("micropip")
# import micropip
# await micropip.install("pyyaml") 

import yaml
import pygraphviz as pgv
# import streamlit as st
from PIL import Image

# # Title of the page
# st.title("sdd initial structure definition / erd")

# Load the data from the YAML file
with open('structure/structure_fieldlists.yml') as f:
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
G.draw('assets/ssd_erd_fromlists.png', prog='dot', format='png')

