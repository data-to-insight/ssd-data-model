import pygraphviz as pgv
import yaml
import streamlit as st
from PIL import Image


# Function to add nodes
def add_nodes(graph, nodes):
    for node in nodes:
        label_str = "{name}\n".format(name=node['name'])
        label_str += "\n".join(node['fields'])
        graph.add_node(node['name'], shape='record', label=label_str)

# Function to add edges
def add_edges(graph, edges):
    for edge in edges:
        graph.add_edge(edge['from'], edge['to'])

# Load yaml file
with open('structure/structure.yml') as file:
    data = yaml.full_load(file)

# Create a new directed graph
G = pgv.AGraph(directed=True)

# Add nodes and edges to the graph
add_nodes(G, data['nodes'])
add_edges(G, data['edges'])

# Save the graph to a file
G.layout(prog='dot')
G.draw('assets/graph.png')

# Display the image in streamlit
st.image(Image.open('assets/graph.png'))
