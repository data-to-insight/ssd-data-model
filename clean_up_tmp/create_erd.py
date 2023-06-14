
# sudo apt-get update
# sudo apt-get install graphviz
# pip install graphviz
# which dot
# export PATH=$PATH:/usr/bin

import os
import yaml
from graphviz import Digraph

# initialize the graph
dot = Digraph(format='png')


# define the path where your yml files are
path = '/workspaces/ssd-data-model/data/structure/'

# # iterate over the files
# for filename in os.listdir(path):
#     if filename.endswith(".yml"): 
#         with open(os.path.join(path, filename), 'r') as stream:
#             try:
#                 # load yaml file
#                 data = yaml.safe_load(stream)
#                 # add a node for each key in the yaml file
#                 for key in data.keys():
#                     dot.node(key)
#                 # add an edge for each relationship you want to represent
#                 # you need to define the logic according to your data structure
#                 for key, value in data.items():
#                     if isinstance(value, dict):  # if the value is another dict
#                         for inner_key in value.keys():
#                             dot.edge(key, inner_key)
#             except yaml.YAMLError as exc:
#                 print(exc)

# # render the graph to a file (this will create 'output.gv.pdf')

# dot.format = 'png'
# dot.render('output.gv', view=False)
