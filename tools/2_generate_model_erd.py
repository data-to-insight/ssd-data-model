





import glob
import yaml
import pygraphviz as pgv
import os
from admin.admin_tools import get_paths # get project defined file paths
from admin.admin_tools import returns_categories # Colour bandings to highlight data item categories for easier ref on visual outputs


# output filenames (non-dynamic)
output_filetype = 'png'
erd_overview_fname = 'ssd_erd_diagram'




def generate_individual_images(yml_data_path, output_path, output_filetype, returns_categories):
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
                node_colour = returns_categories['Existing']['colour']  # default colour
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


                    if field.get('returns'):  # is there any returns data?
                        returns_data = field['returns'] 
                        # returns_data = ', '.join(field['returns']) # Removed to reduce dup data & requ column width on resultant image
                        # field_name += f" [{returns_data}]"
                        for item in returns_data:  
                            if item in returns_categories: 
                                node_colour = returns_categories[item]['colour']
                                break
                            else:
                                node_colour = returns_categories['Existing']['colour']
  

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


def generate_full_erd(yml_data_path, erd_publish_path, returns_categories, filename, node_list=None):
    """
    Generate an entity relationship diagram (ERD) from a collection of yml files.
    Each yml file represents an entity or an object in the ERD.
    The ERD gives an overview of how different entities relate to each other in the system.

    :param yml_data_path: str, path to the directory containing yml files.
    :param erd_publish_path: str, path to the directory where ERD will be published for web access.
    :param returns_categories: dict, information about return categories.
    :param node_list: list, list of nodes to be included in the diagram. If None, all nodes will be included.
    """

    G = pgv.AGraph(directed=True)  # Initialise the graph
    G.graph_attr['size'] = '1280,'
    G.graph_attr['rankdir'] = 'TB'
    G.edge_attr['splines'] = 'ortho'

    for file_path in glob.glob(yml_data_path + '*.yml'):  # Iterating through each yaml file in directory
        node_name = os.path.basename(file_path).replace(".yml", "")
        if node_list and node_name not in node_list:  # Only skip if the list is non-empty and the node is not in it
            continue

        with open(file_path) as f:
            data = yaml.safe_load(f)  # Loading the yaml data into a python dict
            nodes = data.get('nodes', [])
            for node in nodes:  # For each node in the yaml file
                field_labels = []

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
                        returns_data = field.get('returns')  
                        for item in returns_data:  
                            if item in returns_categories:
                                node_colour = returns_categories[item]['colour']  
                                break
                            else:
                                node_colour = returns_categories['Existing']['colour']  
       

                    field_labels.append(field_name)


                label = '{' + node['name'] + '|' + '|'.join(field_labels) + '}'
                G.add_node(node['name'], shape='record', label=f"<{label}>", fillcolor=node_colour, style='filled')  # Add node to the graph

            relationships_file = yml_data_path + 'relationships.yml'
            with open(relationships_file) as rf:  # Loading the relationships yaml file
                relationships_data = yaml.safe_load(rf)
            for relation in relationships_data['relationships']:  # For each relationship in the yaml file
                from_node = relation['parent_object']
                to_node = relation['child_object']
                if node_list and (from_node not in node_list or to_node not in node_list):
                    continue
                relation_type = relation['relation']
                G.add_edge(from_node, to_node, label=relation_type)  # Add edge to the graph to represent the relationship


    # Render the graph to a file
    # 1
    # Render main graph to be web published
    G.layout(prog='sfdp', args='-Goverlap=false -Gsplines=line') 
    G.draw(erd_publish_path + filename + "." + output_filetype, format=output_filetype)



paths = get_paths()
    
generate_full_erd(paths['yml_data'], paths['erd_publish'], returns_categories, 'ssd_full_diagram', node_list=[])

RIIA = ['person', 'legal_status', 'immigration_status', 'social_worker', 'contacts', 'early_help_episodes', 'cin_episodes', 'cin_plans', 'assessments', 's47_enquiry_icpc', 'cp_plans', 'cla_episodes', 'care_leavers', 'send', 'ehcp_requests', 'ehcp_assessment']
generate_full_erd(paths['yml_data'], paths['erd_publish'], returns_categories, 'ssd_riia_diagram', node_list=RIIA)

CLA = ['person', 'legal_status', 'immigration_status', 'disability','mother', 'social_worker', 'cla_episodes','placement', 'cla_immunisations','missing','cla_health', 'cla_substance_misuse','cla_care_plan','cla_visits','cla_convictions']
generate_full_erd(paths['yml_data'], paths['erd_publish'], returns_categories, 'ssd_cla_diagram', node_list=CLA)

ANNEXA = ['person', 'legal_status', 'immigration_status', 'disability',
          'contacts', 'early_help_episodes', 'cin_episodes', 'cin_plans', 'cin_visits',
          'assessments', 's47_enquiry_icpc', 
          'cp_plans', 'cp_reviews', 'category_of_abuse', 'cp_visits',
          'cla_episodes', 'cla_visits', 'cla_reviews', 'missing', 'permanence', 'care_leavers', 'social_worker']
generate_full_erd(paths['yml_data'], paths['erd_publish'], returns_categories, 'ssd_annexa_diagram', node_list=ANNEXA)




generate_individual_images(paths['yml_data'], paths['erd_objects_publish'], output_filetype, returns_categories)





# FULL
# RIIA = [person, legal_status, immigration_status, social_worker, contacts, early_help_episodes, cin_episodes, cin_plans, assessments, s47_enquiry_icpc, cp_plans, cla_episodes, care_leavers, send, ehcp_requests, ehcp_assessment]
# ANNEXA
# CLA'