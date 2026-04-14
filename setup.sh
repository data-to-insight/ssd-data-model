#!/bin/bash
set -e

# Sys packages
sudo apt-get update
sudo apt-get install -y graphviz libgraphviz-dev pkg-config libjpeg-dev zlib1g-dev

# Py dependencies
pip install -r requirements.txt
pip install openpyxl
pip install tabulate
pip install reportlab
pip install markdown
pip install sqlparse

# if not in requirements.txt
pip install pygraphviz
pip install graphviz

# Install|update Poetry
if ! command -v poetry &>/dev/null; then
    pip install poetry
else
    pip install --upgrade poetry
fi

# VS Code ext
code --install-extension ms-python.python --force || true