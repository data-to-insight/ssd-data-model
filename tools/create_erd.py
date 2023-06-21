import glob
import yaml
import pygraphviz as pgv

# Output size options
G = pgv.AGraph(directed=True)
G.graph_attr['size'] = '1280,800'  # Set page size to 1280x800 pixels (common screen)
# G.graph_attr['size'] = '595,842'  # Set page size to A4 dimensions (595x842 pixels)

G.graph_attr['rankdir'] = 'TB'  # Set the graph direction from left to right (or use TB)
G.edge_attr['splines'] = 'ortho'  # Use orthogonal edges for a more compact layout

# Load and combine YAML files
for file_path in glob.glob('data/objects/*.yml'):
    with open(file_path) as f:
        data = yaml.safe_load(f)
        nodes = data.get('nodes', [])
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

# Load relationships from the relationships.yml file
relationships_file = 'data/objects/relationships.yml'
with open(relationships_file) as rf:
    relationships_data = yaml.safe_load(rf)

# Process the relationships
for relation in relationships_data['relations']:
    from_node = relation['from']
    to_node = relation['to']
    relation_type = relation['relation']
    
    # Add edges to the graph
    G.add_edge(from_node, to_node, label=relation_type)
    edge = G.get_edge(from_node, to_node)
    
    # Set edge attributes for crows feet and regular arrow
    if '1' in relation_type:
        edge.attr['arrowtail'] = 'normal'
        edge.attr['arrowhead'] = 'crow'
    else:
        edge.attr['arrowtail'] = 'crow'
        edge.attr['arrowhead'] = 'normal'

# Render the graph to a file
G.draw('assets/ssd_erd.png', prog='dot', format='png')
