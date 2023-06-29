

import glob
import yaml
import pygraphviz as pgv
import os
from admin.admin_tools import get_paths # get project defined file paths


# output filenames (non-dynamic)
erd_overview_fname = 'ssd_erd.png'




def generate_individual_images(yml_data_path, output_path):
    """
    Generate individual images for each yml file.

    :param yml_data_path: str, path to the directory containing yml files.
    :param output_path: str, path to the directory where images will be saved.
    """


    os.makedirs(output_path, exist_ok=True)

    for file_path in glob.glob(yml_data_path + '*.yml'):
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
                    field_name = field['name'] if field['name'] is not None else ""
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
        image_path = os.path.join(output_path, f"{file_name}.png")
        G.draw(image_path, prog='dot', format='png')



def generate_full_erd(yml_data_path, assets_path, erd_publish_path):
    """
    Generate an object/entity diagram (ERD like) from yml files.

    :param yml_data_path: str, path to the directory containing yml files.
    :param assets_path: str, path to the assets directory.
    :param erd_publish_path: str, path to the directory where ERD will be saved.
    """



    G = pgv.AGraph(directed=True)

    # Note: These size defs appear NOT to be reducing the resultant files sizing
    G.graph_attr['size'] = '1280,'  # Set page size to 1280x800 pixels (common screen), A4 dimensions == (595x842 pixels)

    G.graph_attr['rankdir'] = 'TB'  # Set the graph direction from left to right (or use TB)
    G.edge_attr['splines'] = 'ortho'  # Use orthogonal edges for a more compact layout


    # Load and combine YAML files
    for file_path in glob.glob(yml_data_path + '*.yml'):
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
                    
                    # Removed whilst use of seperate relations file tested
                    # # Check if the field has a foreign key
                    # if 'foreign_key' in field:
                    #     fk = field['foreign_key']
                    #     # Add edge to connect the entities
                    #     G.add_edge(fk, node['name'], label='FK')

                # Add nodes to the graph
                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}'
                G.add_node(node['name'], shape='record', label=label)

            # Load relationships from the relationships.yml file
            relationships_file = yml_data_path + 'relationships.yml'
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
    G.draw(assets_path + erd_overview_fname, prog='dot', format='png')
        
    # 1
    # Render copy of the main graph to be web published
    G.layout(prog='sfdp', args='-Goverlap=false -Gsplines=line') 
    G.draw(erd_publish_path + erd_overview_fname, format='png')

    # 2
    # Render an additional copy(alternative layout) of the main graph as local web published copy
    G.draw(erd_publish_path + erd_overview_fname + "_dot", prog='dot', format='png')


    # Alternative render options for ref
    # 
    # G.graph_attr['overlap'] = 'scale'  # Adjust overlap attribute (options: 'scale', 'compress', 'vpsc', or 'ortho')
    # G.graph_attr['scale'] = 0.1  # Adjust scale attribute 
    # G.draw('docs/ssd_erd_twopi.png', prog='twopi', format='png')



paths = get_paths()
    
generate_full_erd(paths['yml_data'], paths['assets'], paths['erd_publish'])
generate_individual_images(paths['yml_data'], paths['erd_objects_publish'])
