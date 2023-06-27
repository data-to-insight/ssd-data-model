

import glob
import yaml
import pygraphviz as pgv
import os
import html
import re


def generate_individual_images():
    erd_folder = 'docs/erd_images/'
    os.makedirs(erd_folder, exist_ok=True)

    for file_path in glob.glob('data/objects/*.yml'):
        G = pgv.AGraph(directed=True)
        G.graph_attr['size'] = '300,'
        G.graph_attr['rankdir'] = 'TB'
        G.edge_attr['splines'] = 'ortho'

        with open(file_path) as f:
            data = yaml.safe_load(f)
            nodes = data.get('nodes', [])
            for node in nodes:
                field_labels = []
                for field in node['fields']:
                    field_name = field['name']
                    if 'group' in field:
                        group_labels = ', '.join(field['group'])
                        field_name = f"{field_name} [{group_labels}]"
                    if field.get('primary_key'):
                        field_name = f"[PK] {field_name}"
                    if field.get('foreign_key'):
                        field_name = f"[FK] {field_name}"
                    if field.get('field_ref'):
                        field_name += f" [{field['field_ref']}]"
                    # Removed to reduce dup data & requ column width on resultant image
                    # if field.get('returns'):
                    #     returns_data = ', '.join(field['returns'])
                    #     field_name += f" [{returns_data}]"

                    field_labels.append(field_name)
                    
                    if 'foreign_key' in field:
                        fk = field['foreign_key']
                        G.add_edge(fk, node['name'], label='FK')

                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}' # Original / functional version

                G.add_node(node['name'], shape='record', label=label)

        file_name = os.path.splitext(os.path.basename(file_path))[0]
        image_path = os.path.join(erd_folder, f"{file_name}.png")
        G.draw(image_path, prog='dot', format='png')



def generate_full_erd():
    # Output size options
    G = pgv.AGraph(directed=True)
    G.graph_attr['size'] = '1280,'  # Set page size to 1280x800 pixels (common screen)
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
                    # Check if the field is a primary key or foreign key
                    if field.get('primary_key'):
                        field_name = f"[PK] {field_name}"
                    if field.get('foreign_key'):
                        field_name = f"[FK] {field_name}"
                    # Append field_ref to the field name
                    if field.get('field_ref'):
                        field_name += f" [{field['field_ref']}]"
                    # Append returns data to the field name
                    if field.get('returns'):
                        returns_data = ', '.join(field['returns'])
                        field_name += f" [{returns_data}]"
                    field_labels.append(field_name)
                    
                    # Check if the field has a foreign key
                    if 'foreign_key' in field:
                        fk = field['foreign_key']
                        # Add edge to connect the entities
                        G.add_edge(fk, node['name'], label='FK')

                # Add nodes to the graph
                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}'
                G.add_node(node['name'], shape='record', label=label)

            # Load relationships from the relationships.yml file
            relationships_file = 'data/objects/relationships.yml'
            with open(relationships_file) as rf:
                relationships_data = yaml.safe_load(rf)

            # Process the relationships
            for relation in relationships_data['relationships']:
                from_node = relation['parent_object']
                to_node = relation['child_object']
                relation_type = relation['relation']
                # Add edges to the graph with the relation type as the label
                G.add_edge(from_node, to_node, label=relation_type)



    # Render the main graph to a file
    G.draw('assets/ssd_erd.png', prog='dot', format='png')
        
    # Render a copy of the main graph as local web published copy
    G.draw('docs/ssd_erd.png', prog='dot', format='png')


    # Other / In progress / Testing

    # Render an additional copy of the main graph to be web published
    # G.layout(prog='sfdp', args='-Goverlap=scale -Gsplines=ortho -Gsep=0.1') # Not great
    G.layout(prog='sfdp', args='-Goverlap=false -Gsplines=line') # Current preference

    G.draw('docs/ssd_erd_sfdp.png', format='png')

    # Working but nodes too far apart
    # Render an additional copy of the main graph to be web published
    # G.graph_attr['overlap'] = 'scale'  # Adjust overlap attribute (options: 'scale', 'compress', 'vpsc', or 'ortho')
    # G.graph_attr['scale'] = 0.1  # Adjust scale attribute 
    # G.draw('docs/ssd_erd_twopi.png', prog='twopi', format='png')


generate_full_erd()
generate_individual_images()


