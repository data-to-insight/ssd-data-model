#!/bin/bash

# Note:
# pip-tools 7.5.x currently requires pip < 26
# If regenerating requirements files with pip-compile:
#
#   pip install "pip<26"
#   pip-compile requirements.in
#   pip-compile requirements_dev.in
#


set -e

# System packages
sudo apt-get update
sudo apt-get install -y \
    graphviz \
    libgraphviz-dev \
    pkg-config \
    libjpeg-dev \
    zlib1g-dev

# # if not in requirements.txt
# pip install pygraphviz


# Python dependencies 
python -m pip install -r requirements.txt

# Poetry (not yet migrated over to poetry)
if ! command -v poetry >/dev/null 2>&1; then
    pip -m install poetry
else
    pip -m install --upgrade poetry
fi

# # Install project dependencies
# poetry install

# VS Code extension
code --install-extension ms-python.python --force || true