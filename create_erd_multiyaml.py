import glob
import yaml
import pygraphviz as pgv


# Create a new directed graph
G = pgv.AGraph(directed=True)

# Load and combine YAML files
for file_path in glob.glob('structure_split_objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
        relations = data.get('relations', [])  # Updated key name
        for node in nodes:
            # Extract field names from the 'fields' list
            fields = [field['name'] for field in node['fields']]
            # Add nodes to the graph
            label = '{' + node['name'] + '|' + '|'.join(fields) + '}'
            G.add_node(node['name'], shape='record', label=label)
        for relation in relations:  # Updated variable name
            # Add edges to the graph
            G.add_edge(relation['from'], relation['to'], label=relation['relation'])

# Render the graph to a file
G.draw('assets/ssd_erd_multiyaml.png', prog='dot', format='png')


# # including the new 'return' group info
# import glob
# import yaml
# import pydot

# # Create a new directed graph
# G = pydot.Dot(graph_type='digraph')

# # Load and combine YAML files
# for file_path in glob.glob('structure_split_objects/*.yml'):
#     with open(file_path) as f:
#         data = yaml.safe_load(f)
#         if 'fields' in data:
#             node_name = data['name']
#             fields = data['fields']
#             field_labels = [field['name'] + (' [' + ', '.join(field.get('group', [])) + ']' if 'group' in field else '') for field in fields]
#             # Create the label string for the entity/object
#             label = '{' + node_name + '|' + '|'.join(field_labels) + '}'
#             # Add node with custom shape and label
#             node = pydot.Node(node_name, shape='record', label=label)
#             G.add_node(node)
#         elif 'edges' in data:
#             edges = data['edges']
#             for edge in edges:
#                 G.add_edge(pydot.Edge(edge['from'], edge['to'], label=edge['relation']))

# # Render the graph to a file
# G.write_svg('assets/ssd_erd_multiyaml.svg')


