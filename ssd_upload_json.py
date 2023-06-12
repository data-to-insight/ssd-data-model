import os
import sys
import streamlit as st
import pandas as pd
import json  # use Python's built-in json module


def main():
    st.title('File Upload Tutorial')

    df_names = ["identity", "assessments"]
    multiple_files = st.file_uploader(
        "Multiple File Uploader", 
        accept_multiple_files=True
    )
    if multiple_files:
        dataframes = {}
        for i, file in enumerate(multiple_files):
            file.seek(0)
            # skip the first 3 rows, so the data reading starts from row 4
            df = pd.read_csv(file, skiprows=3)
            # change column names to lowercase
            df.rename(str.lower, axis='columns', inplace=True)
            # load corresponding json file
            with open(f"data/records/{df_names[i]}.json", 'r') as stream:
                config = json.load(stream)
            # select only the columns defined in json file
            df = df[config["columns"]]
            dataframes[df_names[i]] = df
            
        for df_name, dataframe in dataframes.items():
            st.write(f'{df_name}:')
            st.write(dataframe)

if __name__ == '__main__':
    main()
