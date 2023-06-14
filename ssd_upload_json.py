import os
import sys
import streamlit as st
import pandas as pd
import json  # use Python's built-in json module

def main():
    st.title('File Upload Tutorial')

    # get the current working directory
    cwd = os.getcwd()
    st.write(f'Current working directory: {cwd}')

    # list all files in the current working directory
    filenames = os.listdir(cwd)
    st.write('Files in the current working directory:')
    for filename in filenames:
        st.write(filename)

    df_names = ["assessments"]
    multiple_files = st.file_uploader(
        "Multiple File Uploader", 
        accept_multiple_files=True,
        key="123456"  # make sure this is unique
    )
    if multiple_files:
        dataframes = {}
        for i, file in enumerate(multiple_files):
            file.seek(0)
            # skip the first 3 rows, so the data reading starts from row 4
            df = pd.read_csv(file, skiprows=3)
            # change column names to lowercase
            df.rename(str.lower, axis='columns', inplace=True)
            
            # get the script's directory
            script_dir = os.path.dirname(os.path.abspath(__file__))
            # create the full path to the json file
            json_file_path = os.path.join(script_dir, f"{df_names[i]}.json")

            # load corresponding json file
            with open(json_file_path, 'r') as stream:
                config = json.load(stream)
            
            # select only the columns defined in json file
            df = df[config["columns"]]
            dataframes[df_names[i]] = df
            
        for df_name, dataframe in dataframes.items():
            st.write(f'{df_name}:')
            st.write(dataframe)

if __name__ == '__main__':
    main()
