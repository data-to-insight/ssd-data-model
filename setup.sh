#!/bin/bash


# Install Python dependencies
pip install -r requirements.txt

# Install additional system-level dependencies/packages
sudo apt-get update                                         # requ' to run the below
sudo apt-get install graphviz libgraphviz-dev pkg-config    # creating ERD/graphviz diagrams/images
pip install pygraphviz                                      # creating ERD/graphviz diagrams/images


# Install or update Poetry
if ! command -v poetry &>/dev/null; then
    pip install poetry
else
    pip install --upgrade poetry
fi


# Install the Python extension for Visual Studio Code
code --install-extension ms-python.python