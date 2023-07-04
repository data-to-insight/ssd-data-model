

import glob
import yaml
import pygraphviz as pgv
import os
from admin.admin_tools import get_paths # get project defined file paths


# output filenames (non-dynamic)
output_filetype = 'png'
erd_overview_fname = 'ssd_erd_sfdp'

# Colour bandings to highlight data item categories for easier ref on visual outputs
colour_dict = {                     # Note: colour names are taken from the X11 colour scheme and SVG colour scheme
    "Local": "#C5E625",            # Recorded locally but not currently included in any data collections
    "1aDraft": "#1CFCF2",          # Suggested new item for SSD
    "1bDraft" : "#F57C1D",         # Suggested new item for one of the 1b projects
    "1bSpecified": "#FFC91E"       # Final specified item for one of the 1b projects

}

def generate_individual_images(yml_data_path, output_path, output_filetype):
    """
    Generate individual images for each yml file. Each image is a graphical representation 
    of the information inside a yml file using pygraphviz.

    :param yml_data_path: str, path to directory containing yml files.
    :param output_path: str, path to directory where images saved.
    :param output_filetype: str, the format images will be saved. eg, 'png'.
    """

    os.makedirs(output_path, exist_ok=True)

    for file_path in glob.glob(yml_data_path + '*.yml'):
        G = pgv.AGraph(directed=True)
        G.graph_attr['size'] = '300,'
        G.graph_attr['rankdir'] = 'TB'
        G.edge_attr['splines'] = 'ortho'

        with open(file_path) as f:
            data = yaml.safe_load(f)  # load the content of yaml file into a python dictionary
            nodes = data.get('nodes', [])
            for node in nodes:
                node_colour = 'lightgrey'  # default colour
                field_labels = []
                for field in node['fields']:
                    field_name = field['name'] if field['name'] is not None else ""
                    if 'group' in field:
                        group_labels = ', '.join(field['group'])  # joining all group labels with comma
                        field_name = f"{field_name} [{group_labels}]"  # adding group labels to the field name
                    if field.get('primary_key'):
                        field_name = f"[PK] {field_name}"  # indicating if the field is a primary key
                    if field.get('foreign_key'):
                        field_name = f"[FK] {field_name}"  # indicating if the field is a foreign key
                    if field.get('item_ref'):
                        field_name += f" [{field['item_ref']}]"  # adding item reference to the field name if it exists

                    # Removed to reduce dup data & requ column width on resultant image
                    # The returns data appears in the table next to the object image instead
                    # if field.get('returns'):
                    #     returns_data = ', '.join(field['returns'])
                    #     field_name += f" [{returns_data}]"

                    if field.get('returns'):  # is there any returns data?
                        returns_data = field['returns']  
                        for item in returns_data:  
                            if item in colour_dict:  # If the item is present in the colour_dict
                                node_colour = colour_dict[item]  # Set node_colour to the corresponding colour in the colour_dict


                    field_labels.append(field_name)
                    
                    if 'foreign_key' in field:
                        fk = field['foreign_key']
                        G.add_edge(fk, node['name'], label='FK')

                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}' 

                # G.add_node(node['name'], shape='record', label=label) # creates the node with NO colour applied to output
                G.add_node(node['name'], shape='record', label=label, fillcolor=node_colour, style='filled') # applies colour banding to output node

        file_name = os.path.splitext(os.path.basename(file_path))[0]
        image_path = os.path.join(output_path, f"{file_name}.{output_filetype}")
        G.draw(image_path, prog='dot', format=output_filetype)


def generate_full_erd(yml_data_path, assets_path, erd_publish_path):
    """
    Generate an entity relationship diagram (ERD) from a collection of yml files.
    Each yml file represents an entity or an object in the ERD.
    The ERD gives an overview of how different entities relate to each other in the system.

    :param yml_data_path: str, path to the directory containing yml files.
    :param assets_path: str, path to the assets directory where ERD will be saved.
    :param erd_publish_path: str, path to the directory where ERD will be published for web access.
    """

    G = pgv.AGraph(directed=True)  # Initialise the graph
    G.graph_attr['size'] = '1280,'
    G.graph_attr['rankdir'] = 'TB'
    G.edge_attr['splines'] = 'ortho'

    for file_path in glob.glob(yml_data_path + '*.yml'):  # Iterating through each yaml file in directory
        with open(file_path) as f:
            data = yaml.safe_load(f)  # Loading the yaml data into a python dict
            nodes = data.get('nodes', [])
            for node in nodes:  # For each node in the yaml file
                field_labels = []
                node_colour = 'lightgrey'  # default colour
                for field in node['fields']:  # For each field in the node
                    field_name = field['name'] if field['name'] is not None else ""
                    if 'group' in field:
                        group_labels = ', '.join(field['group'])  # joining all group labels with comma
                        field_name = f"{field_name} [{group_labels}]"  # adding group labels to the field name
                    if field.get('primary_key'):
                        field_name = f"[PK] {field_name}"  # indicating if the field is a primary key
                    if field.get('foreign_key'):
                        field_name = f"[FK] {field_name}"  # indicating if the field is a foreign key
                    if field.get('item_ref'):
                        field_name += f" [{field['item_ref']}]"  # adding item reference to the field name if it exists

                    if field.get('returns'):  # is there any returns data?
                        returns_data = field['returns']  
                        for item in returns_data:  
                            if item in colour_dict:  # If the item is present in the colour_dict
                                node_colour = colour_dict[item]  # Set node_colour to the corresponding colour in the colour_dict

                    field_labels.append(field_name)


                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}'
                G.add_node(node['name'], shape='record', label=f"<{label}>", fillcolor=node_colour, style='filled')  # Add node to the graph

            relationships_file = yml_data_path + 'relationships.yml'
            with open(relationships_file) as rf:  # Loading the relationships yaml file
                relationships_data = yaml.safe_load(rf)
            for relation in relationships_data['relationships']:  # For each relationship in the yaml file
                from_node = relation['parent_object']
                to_node = relation['child_object']
                relation_type = relation['relation']
                G.add_edge(from_node, to_node, label=relation_type)  # Add edge to the graph to represent the relationship


    # Render the main graph to a file
    G.draw(assets_path + erd_overview_fname + "." + output_filetype, prog='dot', format=output_filetype)
        
    # 1
    # Render copy of the main graph to be web published
    G.layout(prog='sfdp', args='-Goverlap=false -Gsplines=line') 
    G.draw(erd_publish_path + erd_overview_fname + "." + output_filetype, format=output_filetype)

    # 2
    # Render an additional copy(alternative layout) of the main graph as local web published copy
    G.draw(erd_publish_path + erd_overview_fname + "_dot" + "." + output_filetype, prog='dot', format=output_filetype)


    # Alternative render options for ref
    # 
    # G.graph_attr['overlap'] = 'scale'  # Adjust overlap attribute (options: 'scale', 'compress', 'vpsc', or 'ortho')
    # G.graph_attr['scale'] = 0.1  # Adjust scale attribute 
    # G.draw('docs/ssd_erd_twopi.png', prog='twopi', format='png')



paths = get_paths()
    
generate_full_erd(paths['yml_data'], paths['assets'], paths['erd_publish'])
generate_individual_images(paths['yml_data'], paths['erd_objects_publish'], output_filetype)
