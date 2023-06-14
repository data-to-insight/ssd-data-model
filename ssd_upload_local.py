# sudo apt-get install graphviz-dev # needed to install the below
# pip install erd-python
# erd-python -i diagram.txt -o diagram.png # e.g. use

# pip install streamlit
# sudo apt-get install libyaml-dev
# streamlit run my_app.py --server.headless=true

await pyodide.loadPackage("micropip")

# const micropip = pyodide.pyimport("micropip")

await micropip.install("pyyaml") 
# await pyodide.loadPackage("pyyaml")

# import micropip
import os
import sys
import streamlit as st
import pandas as pd
import json
import yaml



# This function will handle the data file uploads and return a dictionary of dataframes
def upload_data_files(df_names):
    data_files = st.file_uploader(
        "Data File Uploader",
        accept_multiple_files=True,
        key="data-uploader"  # make sure this key is unique
    )
    if not data_files:
        return {}

    dataframes = {}
    for i, file in enumerate(data_files):
        file.seek(0)
        df = pd.read_csv(file, skiprows=3)
        df.rename(str.lower, axis='columns', inplace=True)
        df_name = df_names[i]
        dataframes[df_name] = df

    return dataframes

# This function will handle the yaml file uploads and return a dictionary of yaml configurations
def upload_yaml_files(df_names):
    yaml_files = st.file_uploader(
        "YAML File Uploader",
        accept_multiple_files=True,
        type=["yaml", "yml"],
        key="yaml-uploader"  # make sure this key is unique
    )
    if not yaml_files:
        return {}

    configs = {}
    for i, file in enumerate(yaml_files):
        file.seek(0)
        config = yaml.safe_load(file)
        df_name = df_names[i]
        configs[df_name] = config

    return configs


def main():
    st.title('File Upload Tutorial')

    df_names = ["assessments"]

    dataframes = upload_data_files(df_names)
    configs = upload_yaml_files(df_names)

    for df_name in df_names:
        if df_name in dataframes:
            st.write(f'Columns in dataframe {df_name}:')
            st.write(dataframes[df_name].columns)
        
        if df_name in configs:
            st.write(f'Columns in config {df_name}:')
            columns_from_config = list(configs[df_name]['fields'].keys())
            st.write(columns_from_config)

        # if df_name in dataframes and df_name in configs:
        #     columns = list(configs[df_name]["fields"].keys())
        #     df = dataframes[df_name][columns]  # subset dataframe to include only these columns
        #     st.write(f'{df_name}:')
        #     st.write(df)



if __name__ == '__main__':
    main()