from graphviz import Digraph
import yaml

# define the path where your yml files are
path = '/workspaces/ssd-data-model/data/structure/'


# Load YAML files
with open(path+'identity.yml', 'r') as f:
    identity = yaml.safe_load(f)
with open(path+'contacts.yml', 'r') as f:
    contacts = yaml.safe_load(f)
with open(path+'assessments.yml', 'r') as f:
    assessments = yaml.safe_load(f)

# Create a new directed graph
dot = Digraph()

# Add nodes for each entity in the schema, with subnodes for each field
for entity_name, entity in {'Identity': identity, 'Contacts': contacts, 'Assessments': assessments}.items():
    # Start a new cluster for this entity
    with dot.subgraph(name='cluster_' + entity_name) as c:
        c.attr(style='filled', color='lightgrey')
        c.node_attr.update(style='filled', color='white', shape='record')
        # Create a label with the entity name and all field names
        label = '{' + entity_name + '|'
        for field in entity:
            label += field + '\\l'
        label += '}'
        # Add the node to the graph
        c.node(entity_name, label=label)

# Add edges for the foreign keys
dot.edge('Contacts', 'Identity', label='FK')
dot.edge('Assessments', 'Identity', label='FK')

# Render the graph to a file
dot.format = 'png'
dot.render('output.gv', view=False)  # Generates 'output.gv.png
