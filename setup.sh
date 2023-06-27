#!/bin/bash

# Install Python dependencies
pip install -r requirements.txt

# Install additional packages for create_erd_from_yml.py
sudo apt-get update
sudo apt-get install graphviz libgraphviz-dev pkg-config
pip install pygraphviz


# Install the Python extension for Visual Studio Code
code --install-extension ms-python.python