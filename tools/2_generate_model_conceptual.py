import glob
import yaml
import os
from graphviz import Digraph
from admin.admin_tools import get_paths

# output filenames (non-dynamic)
output_filetype = 'png'
erd_overview_fname = 'ssd_conceptual_diagram'

# Colour bandings to highlight data item categories for easier ref on visual outputs
returns_categories = {
    "Existing": {
        "colour": "#CCCCCC",
        "description": "Current returned data",
    },
    "Local": {
        "colour": "#C5E625",
        "description": "Recorded locally but not currently included in any data collections",
    },
    "1aDraft": {
        "colour": "#1CFCF2",
        "description": "Suggested new item for SSD",
    },
    "1bDraft": {
        "colour": "#F57C1D",
        "description": "Suggested new item for one of the 1b projects",
    },
    "1bSpecified": {
        "colour": "#FFC91E",
        "description": "Final specified item for one of the 1b projects",
    },
}


def generate_full_erd(yml_data_path, assets_path, erd_publish_path, legend_data):
    G = Digraph(engine='sfdp', format='png')
    G.attr('node', shape='box', style='filled')
    G.attr('graph', overlap='false', splines='line', sep='+20', outputorder='edgesfirst')

    relationships_file = yml_data_path + 'relationships.yml'
    with open(relationships_file) as rf:
        relationships_data = yaml.safe_load(rf)

    # Create a dictionary to store the nodes and their corresponding node objects
    node_objects = {}

    for file_path in glob.glob(yml_data_path + '*.yml'):
        with open(file_path) as f:
            data = yaml.safe_load(f)
            nodes = data.get('nodes', [])
            for node in nodes:
                node_name = node['name']
                node_color = legend_data['Existing']['colour']

                for field in node['fields']:
                    returns_data = field.get('returns')
                    if returns_data:
                        for item in returns_data:
                            if item in returns_categories:
                                node_color = returns_categories[item]['colour']  # apply new color
                                break  # Can only do it once

                # Store the node object in the dictionary
                node_object = G.node(node_name, shape='box', style='filled,rounded', label=node_name, fillcolor=node_color)


                node_objects[node_name] = node_object

    # Create the edges based on the relationships
    for relation in relationships_data['relationships']:
        parent_object = relation['parent_object']
        child_object = relation['child_object']
        relation_type = relation['relation']

        if relation_type == '1:M':
            G.edge(parent_object, child_object, label='1:M', arrowhead='crow', arrowtail='none')
        elif relation_type == 'M:1':
            G.edge(parent_object, child_object, label='M:1', arrowhead='none', arrowtail='crow')
        elif relation_type == 'M:M':
            G.edge(parent_object, child_object, label='M:M', arrowhead='crow', arrowtail='crow')

    G.render(filename=erd_overview_fname, directory=erd_publish_path, format='png', cleanup=True)


paths = get_paths()

generate_full_erd(paths['yml_data'], paths['assets'], paths['erd_publish'], returns_categories)
