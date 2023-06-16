# import glob
# import yaml
# import pygraphviz as pgv


# # Create a new directed graph
# G = pgv.AGraph(directed=True)

# # Load and combine YAML files
# for file_path in glob.glob('structure_split_objects/*.yml'):
#     with open(file_path) as f:
#         data = yaml.safe_load(f)
#         nodes = data.get('nodes', [])
#         relations = data.get('relations', [])  # Updated key name
#         for node in nodes:
#             # Extract field names from the 'fields' list
#             fields = [field['name'] for field in node['fields']]
#             # Add nodes to the graph
#             label = '{' + node['name'] + '|' + '|'.join(fields) + '}'
#             G.add_node(node['name'], shape='record', label=label)
#         for relation in relations:  # Updated variable name
#             # Add edges to the graph
#             G.add_edge(relation['from'], relation['to'], label=relation['relation'])

# # Render the graph to a file
# G.draw('assets/ssd_erd_multiyaml.png', prog='dot', format='png')


# # including the new 'return' group info
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
            # Extract field names and group labels from the 'fields' list
            field_labels = []
            for field in node['fields']:
                field_name = field['name']
                if 'group' in field:
                    group_labels = ', '.join(field['group'])
                    field_name = f"{field_name} [{group_labels}]"
                field_labels.append(field_name)
            # Add nodes to the graph
            label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}'
            G.add_node(node['name'], shape='record', label=label)
        for relation in relations:  # Updated variable name
            # Add edges to the graph
            G.add_edge(relation['from'], relation['to'], label=relation['relation'])

# Render the graph to a file
G.draw('assets/ssd_erd_multiyaml_testing.png', prog='dot', format='png')
